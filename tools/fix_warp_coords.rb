#!/usr/bin/env ruby
# fix_warp_coords.rb — Fixes out-of-bounds warp destinations across all maps.
#
# Usage:
#   ruby tools/fix_warp_coords.rb <game_data_dir> [--dry-run]
#
# Scans every map in Data/ for Transfer Player commands (code 201) with direct
# coordinates (designation 0). If the destination x,y is outside the target map's
# bounds, it clamps to the nearest in-bounds position, then BFS-searches for the
# nearest walkable tile from that clamped position.
#
# Walkability is determined from the tileset passages data: a tile is walkable if
# all three layers have passage bits clear (bottom nibble == 0) or are empty (tile 0).

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

# ─── Helpers ─────────────────────────────────────────────────────────────────

def load_map(path)
  Marshal.load(File.binread(path))
end

def save_map(path, map)
  File.open(path, "wb") { |f| f.write(Marshal.dump(map)) }
end

def map_dimensions(map)
  raw = map.data.instance_variable_get(:@raw)
  _ndim, xsize, ysize, _zsize, _total = raw.unpack("V5")
  [xsize, ysize]
end

def map_tiles(map)
  raw = map.data.instance_variable_get(:@raw)
  _ndim, xsize, ysize, zsize, _total = raw.unpack("V5")
  tiles = raw[20..-1].unpack("v*")
  [xsize, ysize, zsize, tiles]
end

def tile_passable?(tile_id, passages)
  return true if tile_id == 0
  return true if !passages || tile_id >= passages.length
  (passages[tile_id] & 0x0F) == 0
end

# Check if position (x,y) is walkable across all layers
def position_walkable?(x, y, xsize, ysize, zsize, tiles, passages)
  return false if x < 0 || x >= xsize || y < 0 || y >= ysize
  # Check all layers — tile is walkable only if every layer is passable
  (0...zsize).each do |z|
    tile_id = tiles[z * xsize * ysize + y * xsize + x]
    next if tile_id.nil? || tile_id == 0
    return false unless tile_passable?(tile_id, passages)
  end
  true
end

# BFS from (start_x, start_y) to find the nearest walkable tile.
# Returns [x, y] of the nearest walkable tile, or the start position if none found.
def bfs_nearest_walkable(start_x, start_y, xsize, ysize, zsize, tiles, passages, max_radius: 50)
  # First check if start is already walkable
  if position_walkable?(start_x, start_y, xsize, ysize, zsize, tiles, passages)
    return [start_x, start_y]
  end

  visited = Set.new
  queue = [[start_x, start_y, 0]]
  visited.add([start_x, start_y])

  directions = [[0, -1], [0, 1], [-1, 0], [1, 0],
                [-1, -1], [-1, 1], [1, -1], [1, 1]]

  while !queue.empty?
    cx, cy, dist = queue.shift
    return [cx, cy] if dist > 0 && position_walkable?(cx, cy, xsize, ysize, zsize, tiles, passages)
    next if dist >= max_radius

    directions.each do |dx, dy|
      nx, ny = cx + dx, cy + dy
      next if nx < 0 || nx >= xsize || ny < 0 || ny >= ysize
      next if visited.include?([nx, ny])
      visited.add([nx, ny])
      queue << [nx, ny, dist + 1]
    end
  end

  # Fallback: no walkable tile found within radius — return clamped position
  [start_x, start_y]
end

# ─── Main ────────────────────────────────────────────────────────────────────

if ARGV.empty?
  $stderr.puts "Usage: ruby tools/fix_warp_coords.rb <game_data_dir> [--dry-run]"
  exit 1
end

game_data_dir = ARGV[0]
data_dir = File.join(game_data_dir, "Data")
dry_run = ARGV.include?("--dry-run")

unless File.directory?(data_dir)
  $stderr.puts "ERROR: Data directory not found: #{data_dir}"
  exit 1
end

# ─── Load tilesets ───────────────────────────────────────────────────────────

tilesets_path = File.join(data_dir, "Tilesets.rxdata")
unless File.exist?(tilesets_path)
  $stderr.puts "ERROR: Tilesets.rxdata not found"
  exit 1
end
tilesets = Marshal.load(File.binread(tilesets_path))

# ─── Load all maps and their dimensions ─────────────────────────────────────

puts "Loading all maps..."

map_files = Dir.glob(File.join(data_dir, "Map[0-9]*.rxdata")).reject { |f| f =~ /MapInfos/ }
maps = {}        # map_id => RPG::Map object
map_dims = {}    # map_id => [width, height]
map_paths = {}   # map_id => file path

map_files.each do |path|
  basename = File.basename(path, ".rxdata")
  map_id = basename.sub(/^Map0*/, "").to_i
  next if map_id == 0

  begin
    map = load_map(path)
    maps[map_id] = map
    map_dims[map_id] = map_dimensions(map)
    map_paths[map_id] = path
  rescue => e
    $stderr.puts "WARNING: Could not load #{basename}: #{e.message}"
  end
end

puts "Loaded #{maps.size} maps."

# ─── Pre-compute tile/passage data for destination maps (lazy cache) ────────

tile_cache = {}  # map_id => [xsize, ysize, zsize, tiles, passages]

def get_tile_data(map_id, maps, tilesets, tile_cache)
  return tile_cache[map_id] if tile_cache.key?(map_id)

  map = maps[map_id]
  return nil unless map

  xsize, ysize, zsize, tiles = map_tiles(map)

  passages = nil
  ts = tilesets[map.tileset_id] if map.tileset_id
  if ts && ts.passages
    praw = ts.passages.instance_variable_get(:@raw)
    passages = praw[20..-1].unpack("v*")
  end

  tile_cache[map_id] = [xsize, ysize, zsize, tiles, passages]
end

# ─── Scan all maps for warp commands ─────────────────────────────────────────

puts "Scanning for out-of-bounds warps..."

fixes = []
maps_to_save = Set.new

maps.each do |src_map_id, src_map|
  next unless src_map.events
  src_map.events.each do |event_id, event|
    next unless event.pages
    event.pages.each_with_index do |page, page_idx|
      next unless page.list
      page.list.each_with_index do |cmd, cmd_idx|
        next unless cmd.code == 201
        next unless cmd.parameters && cmd.parameters.length >= 4

        designation = cmd.parameters[0]
        next unless designation == 0  # Only fix direct warps

        dest_map_id = cmd.parameters[1]
        dest_x = cmd.parameters[2]
        dest_y = cmd.parameters[3]

        # Check if destination map exists
        unless map_dims.key?(dest_map_id)
          # Destination map not found — skip (might be a valid map we couldn't load)
          next
        end

        dest_w, dest_h = map_dims[dest_map_id]

        # Check if coordinates are in bounds
        if dest_x >= 0 && dest_x < dest_w && dest_y >= 0 && dest_y < dest_h
          next  # Already in bounds
        end

        # Out of bounds — clamp first
        clamped_x = [[dest_x, 0].max, dest_w - 1].min
        clamped_y = [[dest_y, 0].max, dest_h - 1].min

        # BFS for nearest walkable tile from clamped position
        td = get_tile_data(dest_map_id, maps, tilesets, tile_cache)
        if td
          xsize, ysize, zsize, tiles, passages = td
          final_x, final_y = bfs_nearest_walkable(
            clamped_x, clamped_y, xsize, ysize, zsize, tiles, passages
          )
        else
          final_x, final_y = clamped_x, clamped_y
        end

        fix = {
          src_map: src_map_id,
          event_id: event_id,
          page: page_idx,
          cmd_idx: cmd_idx,
          dest_map: dest_map_id,
          dest_map_dims: "#{dest_w}x#{dest_h}",
          old_x: dest_x, old_y: dest_y,
          clamped_x: clamped_x, clamped_y: clamped_y,
          final_x: final_x, final_y: final_y,
          walkable: td ? position_walkable?(final_x, final_y, *td) : "unknown"
        }
        fixes << fix

        unless dry_run
          cmd.parameters[2] = final_x
          cmd.parameters[3] = final_y
          maps_to_save.add(src_map_id)
        end
      end
    end
  end
end

# ─── Report ──────────────────────────────────────────────────────────────────

if fixes.empty?
  puts "\nNo out-of-bounds warps found. All warp coordinates are valid."
  exit 0
end

puts "\n#{"=" * 70}"
puts "#{dry_run ? "[DRY RUN] " : ""}Found #{fixes.size} out-of-bounds warp(s):"
puts "=" * 70

fixes.each do |fix|
  puts ""
  puts "  Map#{"%03d" % fix[:src_map]} Event##{fix[:event_id]} Page#{fix[:page]} Cmd##{fix[:cmd_idx]}"
  puts "    Destination: Map#{"%03d" % fix[:dest_map]} (#{fix[:dest_map_dims]})"
  puts "    Old coords:     (#{fix[:old_x]}, #{fix[:old_y]}) — OUT OF BOUNDS"
  puts "    Clamped to:     (#{fix[:clamped_x]}, #{fix[:clamped_y]})"
  puts "    Final (BFS):    (#{fix[:final_x]}, #{fix[:final_y]}) — walkable: #{fix[:walkable]}"
end

# ─── Save modified maps ─────────────────────────────────────────────────────

unless dry_run
  puts "\nSaving #{maps_to_save.size} modified map(s)..."
  maps_to_save.each do |map_id|
    save_map(map_paths[map_id], maps[map_id])
    puts "  Saved Map#{"%03d" % map_id}"
  end
end

puts "\nDone. #{fixes.size} warp(s) #{dry_run ? "would be" : ""} fixed."
