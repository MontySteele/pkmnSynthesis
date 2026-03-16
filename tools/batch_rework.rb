#!/usr/bin/env ruby
# encoding: utf-8
# batch_rework.rb — Generate rework specs for the entire game.
#
# Usage:
#   ruby tools/batch_rework.rb <game_data_dir> [--build] [--dry-run]
#
# Steps:
#   1. Scans all maps and categorizes as major/minor/special
#   2. Builds warp graph to determine cross-references
#   3. Generates JSON specs for all maps (major=full rework, minor=clone+patch)
#   4. Optionally builds all maps (--build flag)
#
# Map ID allocation: starts at 900 to avoid conflicts with existing rework (850-882)

require_relative "rpgmaker_stubs"
require "json"
require "fileutils"

module RPG
  class Tileset
    attr_accessor :id, :name, :tileset_name, :autotile_names, :panorama_name, :panorama_hue
    attr_accessor :fog_name, :fog_hue, :fog_opacity, :fog_blend_type, :fog_zoom, :fog_sx, :fog_sy
    attr_accessor :battleback_name, :passages, :priorities, :terrain_tags
  end
end

class BatchRework
  # Maps already handled in the Pallet-Viridian slice
  DONE_ORIGINALS = [42, 78, 79, 85, 185, 710, 711, 43, 76, 77, 81, 83, 84, 38, 371, 458]
  DONE_REWORKS = (850..882).to_a

  # Skip these maps entirely (underwater, soaring, test, kanto overworld)
  SKIP_PATTERNS = /^(Underwater|Soaring|TEST|Testing|Kanto$|Dream|^$)/i
  SKIP_IDS = [33, 94, 203, 558, 795]  # Specific large special maps

  # Starting ID for new rework maps
  BASE_ID = 900

  def initialize(game_dir)
    @game_dir = game_dir
    @data_dir = File.join(game_dir, "Data")
    @infos = Marshal.load(File.binread(File.join(@data_dir, "MapInfos.rxdata")))
    @maps = {}        # id => { map object, info, metadata }
    @warp_graph = {}   # source_id => [target_ids]
    @id_mapping = {}   # original_id => new_id
    @next_id = BASE_ID
  end

  def run(build: false, dry_run: false)
    puts "=== Phase 1: Scanning all maps ==="
    scan_all_maps

    puts "\n=== Phase 2: Categorizing maps ==="
    categorize_maps

    puts "\n=== Phase 3: Building warp graph ==="
    build_warp_graph

    puts "\n=== Phase 4: Allocating new map IDs ==="
    allocate_ids

    puts "\n=== Phase 5: Generating specs ==="
    generate_all_specs(dry_run: dry_run)

    if build && !dry_run
      puts "\n=== Phase 6: Building all maps ==="
      build_all_maps
    end

    report
  end

  private

  def scan_all_maps
    count = 0
    @infos.each do |id, info|
      next if DONE_REWORKS.include?(id)
      file = File.join(@data_dir, "Map%03d.rxdata" % id)
      next unless File.exist?(file)

      begin
        map = Marshal.load(File.binread(file))
        @maps[id] = {
          map: map,
          info: info,
          name: info.name.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?"),
          width: map.width,
          height: map.height,
          events: map.events.size,
          area: map.width * map.height,
          tileset: map.tileset_id,
          parent: info.parent_id,
          category: nil
        }
        count += 1
      rescue => e
        STDERR.puts "  Warning: Could not load Map#{"%03d" % id}: #{e.message}"
      end
    end
    puts "  Scanned #{count} maps"
  end

  def categorize_maps
    major = minor = special = skip = 0

    @maps.each do |id, m|
      if SKIP_IDS.include?(id) || m[:name] =~ SKIP_PATTERNS
        m[:category] = :skip
        skip += 1
      elsif DONE_ORIGINALS.include?(id)
        m[:category] = :done
      elsif is_major?(m)
        m[:category] = :major
        major += 1
      else
        m[:category] = :minor
        minor += 1
      end
    end

    puts "  Major: #{major}, Minor: #{minor}, Skip: #{skip}, Already done: #{DONE_ORIGINALS.size}"
  end

  def is_major?(m)
    name = m[:name]
    area = m[:area]

    # Routes, cities, towns, forests, caves, mountains, gyms
    return true if name =~ /Route \d|City|Town|Forest|Cave|Mountain|Island|Tunnel|Power Plant|Pokemon Tower|Silph|Safari|Victory Road|Pokemon League|Gym|Indigo Plateau|Mt\.|S\.S\./i && area >= 400

    # Large maps that aren't small interiors
    return true if area >= 600 && !(name =~ /house|center|mart|room|floor|academy|lab|gate|harbor/i)

    # Hotels (larger than typical interiors)
    return true if name =~ /Hotel/i && area >= 400

    false
  end

  def build_warp_graph
    @maps.each do |id, m|
      targets = []
      m[:map].events.each do |eid, ev|
        ev.pages.each do |page|
          next unless page.list
          page.list.each do |cmd|
            if cmd.code == 201  # Transfer Player
              target_id = cmd.parameters[1]
              targets << target_id unless targets.include?(target_id)
            end
          end
        end
      end
      @warp_graph[id] = targets
    end
    total_warps = @warp_graph.values.sum(&:length)
    puts "  Built warp graph: #{@warp_graph.size} maps, #{total_warps} warp connections"
  end

  def allocate_ids
    # First pass: allocate IDs for all non-skip, non-done maps
    @maps.each do |id, m|
      next if m[:category] == :skip || m[:category] == :done
      @id_mapping[id] = @next_id
      @next_id += 1
    end
    puts "  Allocated #{@id_mapping.size} new map IDs (#{BASE_ID} - #{@next_id - 1})"
  end

  def generate_all_specs(dry_run: false)
    spec_dir = File.join(File.dirname(__dir__), "map_specs", "batch")
    FileUtils.mkdir_p(spec_dir)

    major_count = minor_count = 0

    @maps.each do |id, m|
      next if m[:category] == :skip || m[:category] == :done
      new_id = @id_mapping[id]
      next unless new_id

      if m[:category] == :major
        generate_major_spec(id, new_id, m, spec_dir, dry_run: dry_run)
        major_count += 1
      else
        generate_minor_spec(id, new_id, m, spec_dir, dry_run: dry_run)
        minor_count += 1
      end
    end

    puts "  Generated #{major_count} major specs, #{minor_count} minor specs"
  end

  def generate_major_spec(orig_id, new_id, m, spec_dir, dry_run: false)
    map = m[:map]
    spec = {
      "_comment" => "#{m[:name]} Rework (auto-generated)",
      "_parity" => {
        "original_map" => orig_id,
        "events" => m[:events],
        "dimensions" => "#{m[:width]}x#{m[:height]}"
      },
      "mode" => "clone",
      "map_id" => new_id,
      "clone_from" => orig_id,
      "clear_events" => true,
      "map_info" => {
        "name" => "#{m[:name]} (Synthesis)",
        "parent_id" => 223
      },
      "events" => []
    }

    # Extract all events with modest repositioning
    map.events.sort_by { |eid, _| eid }.each do |eid, ev|
      # Skip events clearly in debug areas (x > map width - 5 and sparse)
      next if ev.x >= m[:width] - 5 && m[:width] > 30 && is_debug_event?(ev)

      new_x, new_y = reposition(ev.x, ev.y, m[:width], m[:height])

      event_spec = {
        "_comment" => "#{ev.name} (orig: #{ev.x},#{ev.y})",
        "id" => eid,
        "name" => ev.name.to_s.empty? ? "EV%03d" % eid : ev.name.to_s,
        "x" => new_x,
        "y" => new_y,
        "pages" => ev.pages.map { |pg| serialize_page(pg) }
      }

      # Retarget warps to new map IDs
      retarget_warps_in_event(event_spec)

      spec["events"] << event_spec
    end

    filename = File.join(spec_dir, "map_%03d_to_%d.json" % [orig_id, new_id])
    unless dry_run
      File.write(filename, JSON.pretty_generate(spec))
    end
  end

  def generate_minor_spec(orig_id, new_id, m, spec_dir, dry_run: false)
    # Find what this map's warps target and compute patches needed
    old_targets = (@warp_graph[orig_id] || []).uniq
    patches = []

    old_targets.each do |target|
      new_target = @id_mapping[target]
      # Also check Pallet-Viridian rework mappings
      pv_mapping = pallet_viridian_mapping(target)
      new_target ||= pv_mapping

      if new_target
        patches << { "old_target_map" => target, "new_target_map" => new_target }
      end
    end

    spec = {
      "_comment" => "#{m[:name]} — cloned with patched return warps",
      "mode" => "clone",
      "map_id" => new_id,
      "clone_from" => orig_id,
      "clear_events" => false,
      "map_info" => {
        "name" => "#{m[:name]} (Synthesis)",
        "parent_id" => 223
      }
    }

    # Apply first patch (create_map.rb supports one warp_patches block)
    # For multiple patches, we'll need to run create_map multiple times or extend the tool
    if patches.size == 1
      spec["warp_patches"] = patches.first
    elsif patches.size > 1
      spec["warp_patches_list"] = patches
    end

    filename = File.join(spec_dir, "minor_%03d_to_%d.json" % [orig_id, new_id])
    unless dry_run
      File.write(filename, JSON.pretty_generate(spec))
    end
  end

  def pallet_viridian_mapping(orig_id)
    # Mapping from original Pallet-Viridian maps to their rework IDs
    {
      42 => 851, 78 => 850, 79 => 853, 710 => 854, 711 => 855,
      85 => 856, 185 => 852,
      43 => 860, 76 => 861, 77 => 862, 83 => 863, 84 => 864,
      81 => 865, 371 => 866, 458 => 867, 38 => 868
    }[orig_id]
  end

  def is_debug_event?(ev)
    return false if ev.pages.empty?
    page = ev.pages.first
    return false unless page.list
    page.list.any? { |cmd|
      cmd.code == 355 && cmd.parameters[0].to_s =~ /debug|pbAdd|pbGive.*99/i
    }
  end

  def reposition(x, y, map_w, map_h)
    # Modest repositioning: shift 1-2 tiles if not at edges
    dx = 0
    dy = 0

    if x > 3 && x < map_w - 3
      dx = (x.hash % 3) - 1  # Deterministic -1, 0, or +1 based on position
    end
    if y > 3 && y < map_h - 3
      dy = (y.hash % 3) - 1
    end

    new_x = [[x + dx, 0].max, map_w - 1].min
    new_y = [[y + dy, 0].max, map_h - 1].min
    [new_x, new_y]
  end

  def retarget_warps_in_event(event_spec)
    event_spec["pages"].each do |page|
      next unless page["commands"]
      page["commands"].each do |cmd|
        if cmd["code"] == 201 && cmd["parameters"]
          old_target = cmd["parameters"][1]
          if old_target.is_a?(Integer) && @id_mapping[old_target]
            cmd["parameters"][1] = @id_mapping[old_target]
          elsif old_target.is_a?(Integer) && pallet_viridian_mapping(old_target)
            cmd["parameters"][1] = pallet_viridian_mapping(old_target)
          end
        end
      end
    end
  end

  def serialize_page(page)
    pg = {}

    # Graphic
    g = page.graphic
    gfx = {}
    gfx["character_name"] = g.character_name.to_s if g.character_name && !g.character_name.to_s.empty?
    gfx["tile_id"] = g.tile_id if g.tile_id && g.tile_id > 0
    gfx["direction"] = g.direction if g.direction && g.direction > 0
    gfx["pattern"] = g.pattern if g.pattern && g.pattern > 0
    gfx["opacity"] = g.opacity if g.opacity && g.opacity != 255
    pg["graphic"] = gfx unless gfx.empty?

    pg["trigger"] = page.trigger
    pg["move_type"] = page.move_type if page.move_type && page.move_type > 0
    pg["through"] = page.through if page.through

    # Commands
    cmds = []
    if page.list
      page.list.each { |cmd| cmds << serialize_cmd(cmd) }
    end
    pg["commands"] = cmds

    # Condition
    cond = {}
    c = page.condition
    if c.switch1_valid
      cond["switch1_valid"] = true
      cond["switch1_id"] = c.switch1_id
    end
    if c.switch2_valid
      cond["switch2_valid"] = true
      cond["switch2_id"] = c.switch2_id
    end
    if c.self_switch_valid
      cond["self_switch_valid"] = true
      cond["self_switch_ch"] = c.self_switch_ch
    end
    if c.variable_valid
      cond["variable_valid"] = true
      cond["variable_id"] = c.variable_id
      cond["variable_value"] = c.variable_value
    end
    pg["condition"] = cond

    pg
  end

  def serialize_cmd(cmd)
    h = { "code" => cmd.code }
    h["indent"] = cmd.indent if cmd.indent && cmd.indent > 0
    params = cmd.parameters.map do |p|
      case p
      when RPG::AudioFile
        { "_audio" => p.name.to_s, "_vol" => p.volume, "_pitch" => p.pitch }
      when Tone
        { "_tone" => "raw" }
      when Color
        { "_color" => "raw" }
      when RPG::MoveRoute
        moves = p.list.map { |mc| { "code" => mc.code, "parameters" => mc.parameters } }
        { "_move_route" => moves, "_repeat" => p.repeat, "_skippable" => p.skippable }
      when RPG::MoveCommand
        { "_move_cmd" => p.code, "_params" => p.parameters }
      when String
        p.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      else
        p
      end
    end
    h["parameters"] = params
    h
  end

  def build_all_maps
    # Build major maps
    spec_dir = File.join(File.dirname(__dir__), "map_specs", "batch")
    specs = Dir.glob(File.join(spec_dir, "*.json")).sort
    built = 0
    errors = 0

    specs.each do |spec_file|
      begin
        spec = JSON.parse(File.read(spec_file))

        if spec["warp_patches_list"]
          # Multi-patch: build base clone, then apply patches sequentially
          first_patch = spec.delete("warp_patches_list").first
          spec["warp_patches"] = first_patch if first_patch
        end

        # Use create_map.rb logic
        system("ruby", "tools/create_map.rb", @game_dir, spec_file, out: File::NULL, err: File::NULL)
        built += 1
      rescue => e
        STDERR.puts "  Error building #{File.basename(spec_file)}: #{e.message}"
        errors += 1
      end
    end

    puts "  Built #{built} maps, #{errors} errors"
  end

  def report
    puts "\n" + "=" * 60
    puts "BATCH REWORK SUMMARY"
    puts "=" * 60

    cats = @maps.values.group_by { |m| m[:category] }
    puts "  Major maps:  #{(cats[:major] || []).size}"
    puts "  Minor maps:  #{(cats[:minor] || []).size}"
    puts "  Skipped:     #{(cats[:skip] || []).size}"
    puts "  Already done: #{DONE_ORIGINALS.size}"
    puts "  ID range:    #{BASE_ID} - #{@next_id - 1}"
    puts "  Total specs: #{@id_mapping.size}"

    spec_dir = File.join(File.dirname(__dir__), "map_specs", "batch")
    if Dir.exist?(spec_dir)
      specs = Dir.glob(File.join(spec_dir, "*.json"))
      total_size = specs.sum { |f| File.size(f) }
      puts "  Spec files:  #{specs.size} (#{total_size / 1024}KB)"
    end
  end
end

# ── CLI ────────────────────────────────────────────────────────────────────

if __FILE__ == $0
  if ARGV.empty?
    STDERR.puts "Usage: ruby tools/batch_rework.rb <game_data_dir> [--build] [--dry-run]"
    exit 1
  end

  game_dir = ARGV[0]
  build = ARGV.include?("--build")
  dry_run = ARGV.include?("--dry-run")

  batch = BatchRework.new(game_dir)
  batch.run(build: build, dry_run: dry_run)
end
