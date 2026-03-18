#!/usr/bin/env ruby
# transplant_events.rb — Takes events from one map and places them onto another map's tile layout.
#
# Usage:
#   ruby tools/transplant_events.rb <game_data_dir> <spec.json> [--dry-run]
#
# The spec JSON format:
#   {
#     "transplants": [
#       {
#         "source_map_id": 42,
#         "target_map_id": 275,
#         "output_map_id": 42,
#         "description": "Replace Pallet Town tiles with Johto equivalent, keep events"
#       }
#     ],
#     "warp_retargets": {
#       "275": "42"
#     }
#   }
#
# Each transplant entry:
#   - Takes TILE DATA (layers 0-2) from target_map_id
#   - Takes EVENTS from source_map_id
#   - Writes the result to output_map_id
#
# Events are repositioned using BFS if their original tile is not walkable on the
# target map's layout. A JSON report is written to stdout.

require "json"
require "set"
require_relative "rpgmaker_stubs"

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

# ─── Tile data helpers ────────────────────────────────────────────────────────

def parse_table(table)
  raw = table.instance_variable_get(:@raw)
  _ndim, xsize, ysize, zsize, _total = raw.unpack("V5")
  tiles = raw[20..-1].unpack("v*")
  { xsize: xsize, ysize: ysize, zsize: zsize, tiles: tiles }
end

def create_table(width, height, depth)
  total = width * height * depth
  raw = [depth, width, height, depth, total].pack("V5")
  raw += ([0] * total).pack("v*")
  t = Table.allocate
  t.instance_variable_set(:@raw, raw)
  t
end

def build_table_from_tiles(width, height, depth, tiles)
  total = width * height * depth
  raw = [depth, width, height, depth, total].pack("V5")
  raw += tiles.pack("v*")
  t = Table.allocate
  t.instance_variable_set(:@raw, raw)
  t
end

# ─── Passability helpers ─────────────────────────────────────────────────────

def load_passages(tilesets, tileset_id)
  ts = tilesets[tileset_id]
  return nil unless ts && ts.passages
  praw = ts.passages.instance_variable_get(:@raw)
  praw[20..-1].unpack("v*")
end

def tile_passable?(tile_id, passages)
  return true if tile_id == 0
  return true if !passages || tile_id >= passages.length
  (passages[tile_id] & 0x0F) == 0
end

def cell_walkable?(x, y, tiles, xsize, ysize, zsize, passages)
  (0...zsize).each do |z|
    tid = tiles[x + y * xsize + z * xsize * ysize]
    next if tid == 0
    return false unless tile_passable?(tid, passages)
  end
  true
end

def find_nearest_walkable(x, y, tiles, xsize, ysize, zsize, passages, occupied = nil)
  occupied ||= Set.new

  # Check original position first
  if x >= 0 && x < xsize && y >= 0 && y < ysize &&
     cell_walkable?(x, y, tiles, xsize, ysize, zsize, passages) &&
     !occupied.include?([x, y])
    return [x, y]
  end

  visited = Set.new
  # Clamp starting search to within bounds
  start_x = [[x, 0].max, xsize - 1].min
  start_y = [[y, 0].max, ysize - 1].min
  visited.add([start_x, start_y])
  queue = [[start_x, start_y]]
  head = 0

  # Check the clamped start first
  if cell_walkable?(start_x, start_y, tiles, xsize, ysize, zsize, passages) &&
     !occupied.include?([start_x, start_y])
    return [start_x, start_y]
  end

  while head < queue.length
    cx, cy = queue[head]
    head += 1
    [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
      nx, ny = cx + dx, cy + dy
      next if nx < 0 || ny < 0 || nx >= xsize || ny >= ysize
      next unless visited.add?([nx, ny])
      if cell_walkable?(nx, ny, tiles, xsize, ysize, zsize, passages) &&
         !occupied.include?([nx, ny])
        return [nx, ny]
      end
      queue << [nx, ny]
    end
  end

  # Fallback: no walkable tile found anywhere — allow stacking as last resort
  [start_x, start_y]
end

# ─── Map I/O ─────────────────────────────────────────────────────────────────

def map_path(data_dir, map_id)
  File.join(data_dir, "Data", "Map%03d.rxdata" % map_id)
end

def load_map(data_dir, map_id)
  path = map_path(data_dir, map_id)
  unless File.exist?(path)
    $stderr.puts "Error: Map file not found: #{path}"
    exit 1
  end
  Marshal.load(File.binread(path))
end

def load_tilesets(data_dir)
  path = File.join(data_dir, "Data", "Tilesets.rxdata")
  unless File.exist?(path)
    $stderr.puts "Error: Tilesets.rxdata not found: #{path}"
    exit 1
  end
  Marshal.load(File.binread(path))
end

# ─── Transplant logic ────────────────────────────────────────────────────────

def perform_transplant(data_dir, spec, tilesets, dry_run)
  source_id = spec["source_map_id"]
  target_id = spec["target_map_id"]
  output_id = spec["output_map_id"]
  description = spec["description"] || ""

  $stderr.puts "Transplant: source=Map%03d target=Map%03d output=Map%03d" % [source_id, target_id, output_id]
  $stderr.puts "  #{description}" unless description.empty?

  source_map = load_map(data_dir, source_id)
  target_map = load_map(data_dir, target_id)

  # Parse tile data
  src_td = parse_table(source_map.data)
  tgt_td = parse_table(target_map.data)

  $stderr.puts "  Source dimensions: #{src_td[:xsize]}x#{src_td[:ysize]} (#{src_td[:zsize]} layers)"
  $stderr.puts "  Target dimensions: #{tgt_td[:xsize]}x#{tgt_td[:ysize]} (#{tgt_td[:zsize]} layers)"

  # Load passages for the TARGET map's tileset (events will live on target tiles)
  passages = load_passages(tilesets, target_map.tileset_id)

  # Build the output map as a clone of the target map (tiles, tileset, dimensions)
  # We use the target map as the base so we get its tile data, tileset, BGM, etc.
  output_map = Marshal.load(Marshal.dump(target_map))

  # Now transplant events from the source map
  source_events = source_map.events || {}
  event_count_before = source_events.length

  report = {
    "source_map_id" => source_id,
    "target_map_id" => target_id,
    "output_map_id" => output_id,
    "description" => description,
    "source_dimensions" => { "width" => src_td[:xsize], "height" => src_td[:ysize] },
    "target_dimensions" => { "width" => tgt_td[:xsize], "height" => tgt_td[:ysize] },
    "events_before" => event_count_before,
    "events_kept_in_place" => [],
    "events_relocated" => [],
    "warnings" => []
  }

  new_events = {}
  occupied = Set.new  # Track occupied tiles to prevent event stacking

  # First pass: keep events that are already on walkable tiles (claim their positions)
  source_events.each do |event_id, event|
    orig_x, orig_y = event.x, event.y
    in_bounds = orig_x >= 0 && orig_x < tgt_td[:xsize] &&
                orig_y >= 0 && orig_y < tgt_td[:ysize]

    if in_bounds && cell_walkable?(orig_x, orig_y, tgt_td[:tiles], tgt_td[:xsize], tgt_td[:ysize], tgt_td[:zsize], passages)
      new_events[event_id] = Marshal.load(Marshal.dump(event))
      occupied.add([orig_x, orig_y])
      report["events_kept_in_place"] << {
        "event_id" => event_id,
        "name" => event.name,
        "position" => [orig_x, orig_y]
      }
    end
  end

  # Second pass: relocate events that need new positions (avoiding occupied tiles)
  source_events.each do |event_id, event|
    next if new_events.key?(event_id)  # Already placed in first pass

    orig_x, orig_y = event.x, event.y
    in_bounds = orig_x >= 0 && orig_x < tgt_td[:xsize] &&
                orig_y >= 0 && orig_y < tgt_td[:ysize]
    reason = in_bounds ? "tile not walkable" : "out of bounds"

    new_x, new_y = find_nearest_walkable(
      orig_x, orig_y,
      tgt_td[:tiles], tgt_td[:xsize], tgt_td[:ysize], tgt_td[:zsize],
      passages, occupied
    )

    occupied.add([new_x, new_y])
    relocated_event = Marshal.load(Marshal.dump(event))
    relocated_event.x = new_x
    relocated_event.y = new_y
    new_events[event_id] = relocated_event

    entry = {
      "event_id" => event_id,
      "name" => event.name,
      "from" => [orig_x, orig_y],
      "to" => [new_x, new_y],
      "reason" => reason
    }
    report["events_relocated"] << entry
    $stderr.puts "  Event #{event_id} (#{event.name}): (#{orig_x},#{orig_y}) -> (#{new_x},#{new_y}) [#{reason}]"
  end

  output_map.events = new_events
  report["events_after"] = new_events.length

  # Validate event count
  if new_events.length != event_count_before
    warning = "Event count mismatch: before=#{event_count_before} after=#{new_events.length}"
    report["warnings"] << warning
    $stderr.puts "  WARNING: #{warning}"
  end

  # Validate all events on walkable tiles
  new_events.each do |eid, ev|
    unless cell_walkable?(ev.x, ev.y, tgt_td[:tiles], tgt_td[:xsize], tgt_td[:ysize], tgt_td[:zsize], passages)
      warning = "Event #{eid} (#{ev.name}) at (#{ev.x},#{ev.y}) is NOT on a walkable tile (no walkable tile found nearby)"
      report["warnings"] << warning
      $stderr.puts "  WARNING: #{warning}"
    end
  end

  # Write the output map
  out_path = map_path(data_dir, output_id)
  if dry_run
    $stderr.puts "  [DRY RUN] Would write: #{out_path}"
  else
    File.binwrite(out_path, Marshal.dump(output_map))
    $stderr.puts "  Written: #{out_path}"
  end

  report
end

# ─── Warp retargeting ────────────────────────────────────────────────────────

def retarget_warps(data_dir, warp_retargets, dry_run)
  return [] if warp_retargets.nil? || warp_retargets.empty?

  # Build lookup: old_map_id (int) => new_map_id (int)
  retarget_map = {}
  warp_retargets.each do |from, to|
    retarget_map[from.to_i] = to.to_i
  end

  $stderr.puts "Warp retargeting: #{retarget_map.map { |k, v| "Map%03d -> Map%03d" % [k, v] }.join(", ")}"

  warp_report = []
  data_path = File.join(data_dir, "Data")

  # Scan all map files
  Dir.glob(File.join(data_path, "Map[0-9][0-9][0-9].rxdata")).sort.each do |file|
    map_id = File.basename(file, ".rxdata").sub("Map", "").to_i
    map = Marshal.load(File.binread(file))
    modified = false

    next unless map.events

    map.events.each do |event_id, event|
      next unless event.pages
      event.pages.each_with_index do |page, page_idx|
        next unless page.list
        page.list.each_with_index do |cmd, cmd_idx|
          # Code 201 = Transfer Player
          # parameters[0] = direct(0)/variable(1)
          # parameters[1] = map_id (when direct)
          next unless cmd.code == 201
          next unless cmd.parameters[0] == 0  # direct designation only

          target_map = cmd.parameters[1]
          if retarget_map.key?(target_map)
            new_target = retarget_map[target_map]
            entry = {
              "map_id" => map_id,
              "event_id" => event_id,
              "page" => page_idx,
              "command_index" => cmd_idx,
              "old_target" => target_map,
              "new_target" => new_target
            }
            warp_report << entry

            unless dry_run
              cmd.parameters[1] = new_target
              modified = true
            end

            $stderr.puts "  Map%03d event %d page %d cmd %d: warp %03d -> %03d" %
              [map_id, event_id, page_idx, cmd_idx, target_map, new_target]
          end
        end
      end
    end

    if modified && !dry_run
      File.binwrite(file, Marshal.dump(map))
      $stderr.puts "  Written (warp update): #{file}"
    end
  end

  # Also scan common events for warps
  common_path = File.join(data_path, "CommonEvents.rxdata")
  if File.exist?(common_path)
    common_events = Marshal.load(File.binread(common_path))
    ce_modified = false

    common_events.each do |ce|
      next unless ce && ce.list
      ce.list.each_with_index do |cmd, cmd_idx|
        next unless cmd.code == 201
        next unless cmd.parameters[0] == 0

        target_map = cmd.parameters[1]
        if retarget_map.key?(target_map)
          new_target = retarget_map[target_map]
          entry = {
            "common_event_id" => ce.id,
            "common_event_name" => ce.name,
            "command_index" => cmd_idx,
            "old_target" => target_map,
            "new_target" => new_target
          }
          warp_report << entry

          unless dry_run
            cmd.parameters[1] = new_target
            ce_modified = true
          end

          $stderr.puts "  CommonEvent %d (%s) cmd %d: warp %03d -> %03d" %
            [ce.id, ce.name, cmd_idx, target_map, new_target]
        end
      end
    end

    if ce_modified && !dry_run
      File.binwrite(common_path, Marshal.dump(common_events))
      $stderr.puts "  Written (warp update): #{common_path}"
    end
  end

  warp_report
end

# ─── Main ────────────────────────────────────────────────────────────────────

def main
  game_data_dir = ARGV[0]
  spec_file = ARGV[1]
  dry_run = ARGV.include?("--dry-run")

  unless game_data_dir && spec_file
    $stderr.puts "Usage: ruby tools/transplant_events.rb <game_data_dir> <spec.json> [--dry-run]"
    exit 1
  end

  unless File.directory?(game_data_dir)
    $stderr.puts "Error: Game data directory not found: #{game_data_dir}"
    exit 1
  end

  unless File.exist?(spec_file)
    $stderr.puts "Error: Spec file not found: #{spec_file}"
    exit 1
  end

  spec = JSON.parse(File.read(spec_file))
  transplants = spec["transplants"] || []
  warp_retargets = spec["warp_retargets"] || {}

  if transplants.empty?
    $stderr.puts "Error: No transplants defined in spec."
    exit 1
  end

  $stderr.puts "=== Transplant Events ==="
  $stderr.puts "Mode: #{dry_run ? "DRY RUN" : "LIVE"}"
  $stderr.puts ""

  # Load tilesets once
  tilesets = load_tilesets(game_data_dir)

  # Perform each transplant
  transplant_reports = transplants.map do |t_spec|
    perform_transplant(game_data_dir, t_spec, tilesets, dry_run)
  end

  $stderr.puts ""

  # Retarget warps across all maps
  warp_report = retarget_warps(game_data_dir, warp_retargets, dry_run)

  # Build final report
  total_events = transplant_reports.sum { |r| r["events_before"] }
  total_relocated = transplant_reports.sum { |r| r["events_relocated"].length }
  total_kept = transplant_reports.sum { |r| r["events_kept_in_place"].length }
  all_warnings = transplant_reports.flat_map { |r| r["warnings"] }

  final_report = {
    "mode" => dry_run ? "dry_run" : "live",
    "summary" => {
      "total_transplants" => transplant_reports.length,
      "total_events_processed" => total_events,
      "total_events_kept_in_place" => total_kept,
      "total_events_relocated" => total_relocated,
      "total_warps_retargeted" => warp_report.length,
      "total_warnings" => all_warnings.length
    },
    "transplants" => transplant_reports,
    "warps_retargeted" => warp_report,
    "warnings" => all_warnings
  }

  $stderr.puts ""
  $stderr.puts "=== Summary ==="
  $stderr.puts "Transplants:        #{transplant_reports.length}"
  $stderr.puts "Events processed:   #{total_events}"
  $stderr.puts "Events kept:        #{total_kept}"
  $stderr.puts "Events relocated:   #{total_relocated}"
  $stderr.puts "Warps retargeted:   #{warp_report.length}"
  $stderr.puts "Warnings:           #{all_warnings.length}"
  all_warnings.each { |w| $stderr.puts "  - #{w}" }

  # Output report JSON to stdout
  puts JSON.pretty_generate(final_report)
end

main
