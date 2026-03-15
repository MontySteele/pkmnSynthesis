#!/usr/bin/env ruby
# create_map.rb — Create or modify RPG Maker XP maps from JSON specs.
#
# Usage:
#   ruby tools/create_map.rb <game_data_dir> <spec.json> [--dry-run]
#
# The spec JSON defines the map layout, events, trainers, and metadata.
# See docs or the example at the bottom of this file for the spec format.
#
# Modes:
#   - clone:  Clone an existing map, replace its events
#   - new:    Create a blank map from scratch (fill with a base tile)
#   - modify: Add/replace events on an existing map without touching tiles

require_relative "rpgmaker_stubs"
require "json"

module RPG
  class Tileset
    attr_accessor :id, :name, :tileset_name, :autotile_names
    attr_accessor :panorama_name, :panorama_hue
    attr_accessor :fog_name, :fog_hue, :fog_opacity, :fog_blend_type
    attr_accessor :fog_zoom, :fog_sx, :fog_sy
    attr_accessor :battleback_name
    attr_accessor :passages, :priorities, :terrain_tags
  end
end

class MapCreator
  def initialize(game_dir)
    @game_dir = game_dir
    @data_dir = File.join(game_dir, "Data")
  end

  def create_from_spec(spec, dry_run: false)
    mode = spec["mode"] || "clone"
    target_id = spec["map_id"]
    abort "spec must include 'map_id'" unless target_id

    case mode
    when "clone"
      map = clone_map(spec)
    when "new"
      map = new_map(spec)
    when "modify"
      map = modify_map(spec)
    else
      abort "Unknown mode: #{mode}"
    end

    # Apply events from spec
    if spec["events"]
      apply_events(map, spec["events"])
    end

    # Apply tile overrides if present
    if spec["tile_overrides"]
      apply_tile_overrides(map, spec["tile_overrides"])
    end

    # Set map metadata
    if spec["bgm"]
      map.bgm = make_audio(spec["bgm"])
      map.autoplay_bgm = true
    end
    if spec["bgs"]
      map.bgs = make_audio(spec["bgs"])
      map.autoplay_bgs = true
    end
    map.encounter_list = build_encounters(spec["encounters"]) if spec["encounters"]

    target_file = File.join(@data_dir, "Map%03d.rxdata" % target_id)

    if dry_run
      puts "[DRY RUN] Would write #{target_file}"
      puts "  Map: #{map.width}x#{map.height}, tileset=#{map.tileset_id}"
      puts "  Events: #{map.events.length}"
      map.events.each do |id, ev|
        puts "    Event #{id} \"#{ev.name}\" at (#{ev.x},#{ev.y}) — #{ev.pages.length} page(s)"
      end
    else
      File.binwrite(target_file, Marshal.dump(map))
      puts "[OK] Wrote #{target_file} (#{map.width}x#{map.height}, #{map.events.length} events)"
    end

    # Register in MapInfos
    if spec["map_info"]
      register_map_info(target_id, spec["map_info"], dry_run: dry_run)
    end

    map
  end

  private

  # ── Map creation modes ───────────────────────────────────────────────────

  def clone_map(spec)
    source_id = spec["clone_from"]
    abort "clone mode requires 'clone_from' map ID" unless source_id

    source_file = File.join(@data_dir, "Map%03d.rxdata" % source_id)
    abort "Source map not found: #{source_file}" unless File.exist?(source_file)

    map = Marshal.load(File.binread(source_file))

    # Optionally resize
    if spec["width"] && spec["height"]
      map = resize_map(map, spec["width"], spec["height"])
    end

    # Optionally change tileset
    map.tileset_id = spec["tileset_id"] if spec["tileset_id"]

    # Clear events by default when cloning (spec events will replace them)
    if spec.fetch("clear_events", true)
      map.events = {}
    end

    map
  end

  def new_map(spec)
    width = spec["width"] || 20
    height = spec["height"] || 15
    tileset_id = spec["tileset_id"] || 23  # Outdoor by default

    map = RPG::Map.new
    map.width = width
    map.height = height
    map.tileset_id = tileset_id
    map.events = {}
    map.encounter_list = []
    map.encounter_step = 30
    map.autoplay_bgm = false
    map.autoplay_bgs = false
    map.bgm = make_audio({ "name" => "", "volume" => 100 })
    map.bgs = make_audio({ "name" => "", "volume" => 80 })

    # Create blank tile data (3 layers)
    map.data = create_table(width, height, 3)

    # Fill layer 0 with a base tile if specified
    if spec["base_tile"]
      fill_layer(map, 0, spec["base_tile"])
    end

    map
  end

  def modify_map(spec)
    target_file = File.join(@data_dir, "Map%03d.rxdata" % spec["map_id"])
    abort "Map not found: #{target_file}" unless File.exist?(target_file)
    Marshal.load(File.binread(target_file))
  end

  # ── Table handling ──────────────────────────────────────────────────────

  def create_table(width, height, depth)
    total = width * height * depth
    # RPG Maker XP Table format: 5 int32s header + total int16s data
    raw = [depth, width, height, depth, total].pack("V5")
    raw += ([0] * total).pack("v*")
    t = Table.allocate
    t.instance_variable_set(:@raw, raw)
    t
  end

  def get_tile(map, x, y, z)
    raw = map.data.instance_variable_get(:@raw)
    _ndim, xsize, ysize, _zsize, _total = raw.unpack("V5")
    tiles = raw[20..-1].unpack("v*")
    tiles[x + y * xsize + z * xsize * ysize]
  end

  def set_tile(map, x, y, z, tile_id)
    raw = map.data.instance_variable_get(:@raw)
    header = raw[0, 20]
    _ndim, xsize, ysize, _zsize, _total = header.unpack("V5")
    tiles = raw[20..-1].unpack("v*")
    tiles[x + y * xsize + z * xsize * ysize] = tile_id
    new_raw = header + tiles.pack("v*")
    map.data.instance_variable_set(:@raw, new_raw)
  end

  def fill_layer(map, layer, tile_id)
    raw = map.data.instance_variable_get(:@raw)
    header = raw[0, 20]
    _ndim, xsize, ysize, _zsize, _total = header.unpack("V5")
    tiles = raw[20..-1].unpack("v*")
    (0...ysize).each do |y|
      (0...xsize).each do |x|
        tiles[x + y * xsize + layer * xsize * ysize] = tile_id
      end
    end
    new_raw = header + tiles.pack("v*")
    map.data.instance_variable_set(:@raw, new_raw)
  end

  def resize_map(map, new_width, new_height)
    old_raw = map.data.instance_variable_get(:@raw)
    _ndim, old_w, old_h, zsize, _total = old_raw.unpack("V5")
    old_tiles = old_raw[20..-1].unpack("v*")

    new_total = new_width * new_height * zsize
    new_tiles = Array.new(new_total, 0)

    # Copy overlapping region
    copy_w = [old_w, new_width].min
    copy_h = [old_h, new_height].min
    (0...zsize).each do |z|
      (0...copy_h).each do |y|
        (0...copy_w).each do |x|
          old_idx = x + y * old_w + z * old_w * old_h
          new_idx = x + y * new_width + z * new_width * new_height
          new_tiles[new_idx] = old_tiles[old_idx]
        end
      end
    end

    new_raw = [zsize, new_width, new_height, zsize, new_total].pack("V5")
    new_raw += new_tiles.pack("v*")
    map.data.instance_variable_set(:@raw, new_raw)
    map.width = new_width
    map.height = new_height
    map
  end

  # ── Tile overrides ─────────────────────────────────────────────────────

  def apply_tile_overrides(map, overrides)
    overrides.each do |ov|
      if ov["fill_rect"]
        r = ov["fill_rect"]
        layer = ov["layer"] || 0
        tile_id = ov["tile_id"]
        (r["y"]...(r["y"] + r["h"])).each do |y|
          (r["x"]...(r["x"] + r["w"])).each do |x|
            set_tile(map, x, y, layer, tile_id)
          end
        end
      elsif ov["x"] && ov["y"]
        set_tile(map, ov["x"], ov["y"], ov["layer"] || 0, ov["tile_id"])
      end
    end
  end

  # ── Event creation ─────────────────────────────────────────────────────

  def apply_events(map, events_spec)
    events_spec.each do |ev_spec|
      id = ev_spec["id"]
      abort "Event spec missing 'id'" unless id

      event = RPG::Event.new
      event.id = id
      event.name = ev_spec["name"] || "EV%03d" % id
      event.x = ev_spec["x"] || 0
      event.y = ev_spec["y"] || 0
      event.pages = []

      pages = ev_spec["pages"] || [ev_spec]
      pages.each do |page_spec|
        page = build_page(page_spec)
        event.pages << page
      end

      map.events[id] = event
    end
  end

  def build_page(spec)
    page = RPG::Event::Page.new
    page.condition = build_condition(spec["condition"] || {})
    page.graphic = build_graphic(spec["graphic"] || {})
    page.move_type = spec["move_type"] || 0      # 0=fixed, 1=random, 2=approach, 3=custom
    page.move_speed = spec["move_speed"] || 3
    page.move_frequency = spec["move_frequency"] || 3
    page.move_route = build_move_route(spec["move_route"])
    page.walk_anime = spec.fetch("walk_anime", true)
    page.step_anime = spec.fetch("step_anime", false)
    page.direction_fix = spec.fetch("direction_fix", false)
    page.through = spec.fetch("through", false)
    page.always_on_top = spec.fetch("always_on_top", false)
    page.trigger = spec["trigger"] || 0  # 0=action, 1=player_touch, 2=event_touch, 3=autorun, 4=parallel
    page.list = build_commands(spec["commands"] || [])
    page
  end

  def build_condition(spec)
    cond = RPG::Event::Page::Condition.new
    cond.switch1_valid = spec["switch1_valid"] || false
    cond.switch1_id = spec["switch1_id"] || 1
    cond.switch2_valid = spec["switch2_valid"] || false
    cond.switch2_id = spec["switch2_id"] || 1
    cond.variable_valid = spec["variable_valid"] || false
    cond.variable_id = spec["variable_id"] || 1
    cond.variable_value = spec["variable_value"] || 0
    cond.self_switch_valid = spec["self_switch_valid"] || false
    cond.self_switch_ch = spec["self_switch_ch"] || "A"
    cond
  end

  def build_graphic(spec)
    g = RPG::Event::Page::Graphic.new
    g.tile_id = spec["tile_id"] || 0
    g.character_name = spec["character_name"] || ""
    g.character_hue = spec["character_hue"] || 0
    g.direction = spec["direction"] || 2    # 2=down, 4=left, 6=right, 8=up
    g.pattern = spec["pattern"] || 0
    g.opacity = spec["opacity"] || 255
    g.blend_type = spec["blend_type"] || 0
    g
  end

  def build_move_route(spec)
    mr = RPG::MoveRoute.new
    mr.repeat = true
    mr.skippable = false
    mr.list = [build_move_command(0)]  # 0 = blank/end
    mr
  end

  def build_move_command(code, params = [])
    mc = RPG::MoveCommand.new
    mc.code = code
    mc.parameters = params
    mc
  end

  # ── Command builder ────────────────────────────────────────────────────
  # Converts high-level command specs into RPG::EventCommand arrays.

  def build_commands(specs)
    cmds = []
    specs.each do |spec|
      case spec["type"]
      when "text"
        cmds += build_text_commands(spec["lines"], spec["indent"] || 0)
      when "choices"
        cmds += build_choice_commands(spec, spec["indent"] || 0)
      when "script"
        cmds += build_script_commands(spec["lines"], spec["indent"] || 0)
      when "transfer"
        cmds << make_cmd(201, spec["indent"] || 0,
          [0, spec["map_id"], spec["x"], spec["y"], spec["direction"] || 0, spec.fetch("fade", 1)])
      when "switch"
        cmds << make_cmd(121, spec["indent"] || 0,
          [spec["id"], spec["id"], spec["value"] == "ON" ? 0 : 1])
      when "variable"
        # operation: 0=set, 1=add, 2=sub, 3=mul, 4=div, 5=mod
        cmds << make_cmd(122, spec["indent"] || 0,
          [spec["id"], spec["id"], spec["operation"] || 0, 0, spec["value"] || 0])
      when "conditional_switch"
        cmds << make_cmd(111, spec["indent"] || 0, [0, spec["switch_id"], spec["value"] == "ON" ? 0 : 1])
        # Then branch contents go here (handled by nested commands)
        if spec["then"]
          cmds += build_commands(spec["then"].map { |c| c.merge("indent" => (spec["indent"] || 0) + 1) })
        end
        if spec["else"]
          cmds << make_cmd(411, spec["indent"] || 0, [])
          cmds += build_commands(spec["else"].map { |c| c.merge("indent" => (spec["indent"] || 0) + 1) })
        end
        cmds << make_cmd(412, spec["indent"] || 0, [])
      when "self_switch"
        cmds << make_cmd(123, spec["indent"] || 0,
          [spec["ch"] || "A", spec["value"] == "ON" ? 0 : 1])
      when "battle"
        # pbTrainerBattle wrapper
        trainer_type = spec["trainer_type"] || "POKEMONTRAINER"
        trainer_name = spec["trainer_name"]
        trainer_id = spec["trainer_id"] || 0
        line = "pbTrainerBattle(:#{trainer_type},\"#{trainer_name}\",#{trainer_id})"
        cmds += build_script_commands([line], spec["indent"] || 0)
      when "item"
        line = "pbItemBall(:#{spec["item"]})"
        cmds += build_script_commands([line], spec["indent"] || 0)
      when "raw"
        cmds << make_cmd(spec["code"], spec["indent"] || 0, spec["parameters"] || [])
      end
    end

    # Always end with a blank command (code 0)
    if cmds.empty? || cmds.last.code != 0
      cmds << make_cmd(0, 0, [])
    end
    cmds
  end

  def build_text_commands(lines, indent)
    return [] unless lines && !lines.empty?
    cmds = [make_cmd(101, indent, [lines[0]])]
    lines[1..].each do |line|
      cmds << make_cmd(401, indent, [line])
    end
    cmds
  end

  def build_choice_commands(spec, indent)
    choices = spec["choices"]
    cancel_type = spec["cancel_type"] || 0
    cmds = [make_cmd(102, indent, [choices.map { |c| c["label"] }, cancel_type])]

    choices.each_with_index do |choice, i|
      cmds << make_cmd(402, indent, [i, choice["label"]])
      if choice["commands"]
        cmds += build_commands(choice["commands"].map { |c| c.merge("indent" => indent + 1) })
        # Remove trailing 0 since we'll add our own structure
        cmds.pop if cmds.last&.code == 0
      end
      cmds << make_cmd(0, indent + 1, [])
    end
    cmds << make_cmd(404, indent, [])
    cmds
  end

  def build_script_commands(lines, indent)
    return [] unless lines && !lines.empty?
    cmds = [make_cmd(355, indent, [lines[0]])]
    lines[1..].each do |line|
      cmds << make_cmd(655, indent, [line])
    end
    cmds
  end

  def make_cmd(code, indent, parameters)
    cmd = RPG::EventCommand.new
    cmd.code = code
    cmd.indent = indent
    cmd.parameters = parameters
    cmd
  end

  # ── Audio / Encounters ─────────────────────────────────────────────────

  def make_audio(spec)
    a = RPG::AudioFile.new
    a.name = spec["name"] || ""
    a.volume = spec["volume"] || 100
    a.pitch = spec["pitch"] || 100
    a
  end

  def build_encounters(specs)
    specs.map do |s|
      # Encounter format depends on Pokemon Essentials version
      # Typically: [species_id, min_level, max_level]
      s
    end
  end

  # ── MapInfos registration ─────────────────────────────────────────────

  def register_map_info(map_id, info_spec, dry_run: false)
    infos_file = File.join(@data_dir, "MapInfos.rxdata")
    infos = Marshal.load(File.binread(infos_file))

    info = RPG::MapInfo.new
    info.name = info_spec["name"] || "New Map"
    info.parent_id = info_spec["parent_id"] || 0
    info.order = info_spec["order"] || (infos.values.map(&:order).max || 0) + 1
    info.expanded = false
    info.scroll_x = 0
    info.scroll_y = 0

    if dry_run
      puts "[DRY RUN] Would register Map#{"%03d" % map_id}: \"#{info.name}\" parent=#{info.parent_id}"
    else
      infos[map_id] = info
      File.binwrite(infos_file, Marshal.dump(infos))
      puts "[OK] Registered Map#{"%03d" % map_id}: \"#{info.name}\" in MapInfos"
    end
  end
end

# ── CLI ──────────────────────────────────────────────────────────────────────

if __FILE__ == $0
  if ARGV.length < 2
    STDERR.puts "Usage: ruby tools/create_map.rb <game_data_dir> <spec.json> [--dry-run]"
    STDERR.puts ""
    STDERR.puts "Spec format (JSON):"
    STDERR.puts '  {'
    STDERR.puts '    "mode": "clone",           // clone, new, or modify'
    STDERR.puts '    "map_id": 850,             // target map ID to create'
    STDERR.puts '    "clone_from": 1,           // source map ID (clone mode)'
    STDERR.puts '    "width": 20, "height": 15, // dimensions (new mode, or resize in clone)'
    STDERR.puts '    "tileset_id": 23,          // tileset to use'
    STDERR.puts '    "bgm": { "name": "Pallet Town" },'
    STDERR.puts '    "events": [                // event definitions'
    STDERR.puts '      {'
    STDERR.puts '        "id": 1, "name": "NPC", "x": 5, "y": 8,'
    STDERR.puts '        "graphic": { "character_name": "BWClerk_female" },'
    STDERR.puts '        "commands": ['
    STDERR.puts '          { "type": "text", "lines": ["Hello!", "Welcome to town."] }'
    STDERR.puts '        ]'
    STDERR.puts '      }'
    STDERR.puts '    ],'
    STDERR.puts '    "map_info": { "name": "My Town", "parent_id": 0 }'
    STDERR.puts '  }'
    exit 1
  end

  game_dir = ARGV[0]
  spec_file = ARGV[1]
  dry_run = ARGV.include?("--dry-run")

  spec = JSON.parse(File.read(spec_file))
  creator = MapCreator.new(game_dir)
  creator.create_from_spec(spec, dry_run: dry_run)
end
