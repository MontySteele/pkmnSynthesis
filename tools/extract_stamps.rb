#!/usr/bin/env ruby
# Comprehensive stamp extraction from RPG Maker XP maps
# Extracts buildings, structures, and natural features as reusable stamps

require "json"
require "fileutils"
require_relative "rpgmaker_stubs"
module RPG; class Tileset; attr_accessor :id,:name,:tileset_name,:autotile_names,:panorama_name,:panorama_hue,:fog_name,:fog_hue,:fog_opacity,:fog_blend_type,:fog_zoom,:fog_sx,:fog_sy,:battleback_name,:passages,:priorities,:terrain_tags; end; end

DATA_DIR = File.join(__dir__, "..", "game_data", "Data")
STAMPS_DIR = File.join(__dir__, "stamps")
FileUtils.mkdir_p(STAMPS_DIR)

def load_map(num)
  path = File.join(DATA_DIR, "Map%03d.rxdata" % num)
  File.open(path, "rb") { |f| Marshal.load(f) }
end

def get_tiles(map)
  raw = map.data.instance_variable_get(:@raw)
  _, xsize, ysize, zsize, _ = raw.unpack("V5")
  tiles = raw[20..-1].unpack("v*")
  [xsize, ysize, zsize, tiles]
end

def tile_at(tiles, xsize, ysize, x, y, z)
  return 0 if x < 0 || y < 0 || x >= xsize || y >= ysize
  tiles[x + y * xsize + z * xsize * ysize]
end

# Extract a rectangular stamp from a map
def extract_stamp(name, map_num, tiles, xsize, ysize, rx, ry, rw, rh)
  layers = {}
  3.times do |z|
    layer_name = "layer#{z}"
    rows = []
    (ry...ry+rh).each do |y|
      row = []
      (rx...rx+rw).each do |x|
        row << tile_at(tiles, xsize, ysize, x, y, z)
      end
      rows << row
    end
    layers[layer_name] = rows
  end

  stamp = {
    name: name,
    width: rw,
    height: rh,
    source_map: map_num,
    source_rect: { x: rx, y: ry, w: rw, h: rh },
    tiles: layers
  }

  path = File.join(STAMPS_DIR, "#{name}.json")
  File.write(path, JSON.pretty_generate(stamp))
  puts "  Saved #{name} (#{rw}x#{rh}) from Map%03d at (#{rx},#{ry})" % map_num
  stamp
end

# Find contiguous regions on layer 2 (rooftops/overlays) using BFS
def find_layer2_regions(tiles, xsize, ysize, min_tiles: 4)
  visited = Array.new(xsize * ysize, false)
  regions = []

  (0...ysize).each do |y|
    (0...xsize).each do |x|
      next if visited[x + y * xsize]
      t = tile_at(tiles, xsize, ysize, x, y, 2)
      next if t == 0

      # BFS flood fill
      region_tiles = []
      queue = [[x, y]]
      visited[x + y * xsize] = true

      while !queue.empty?
        cx, cy = queue.shift
        region_tiles << [cx, cy]

        [[0,1],[0,-1],[1,0],[-1,0]].each do |dx, dy|
          nx, ny = cx + dx, cy + dy
          next if nx < 0 || ny < 0 || nx >= xsize || ny >= ysize
          next if visited[nx + ny * xsize]
          nt = tile_at(tiles, xsize, ysize, nx, ny, 2)
          next if nt == 0
          visited[nx + ny * xsize] = true
          queue << [nx, ny]
        end
      end

      next if region_tiles.size < min_tiles

      xs = region_tiles.map(&:first)
      ys = region_tiles.map(&:last)
      min_x, max_x = xs.min, xs.max
      min_y, max_y = ys.min, ys.max
      w = max_x - min_x + 1
      h = max_y - min_y + 1
      fill = region_tiles.size.to_f / (w * h)

      regions << {
        min_x: min_x, min_y: min_y,
        max_x: max_x, max_y: max_y,
        w: w, h: h,
        tile_count: region_tiles.size,
        fill_ratio: fill
      }
    end
  end

  regions.sort_by { |r| -r[:tile_count] }
end

# Auto-discover buildings by finding rectangular regions on layers 1+2
def auto_discover_buildings(map_num, tiles, xsize, ysize, prefix, padding: 1)
  regions = find_layer2_regions(tiles, xsize, ysize, min_tiles: 6)

  # Filter: skip regions that cover > 50% of the map (these are background/border patterns)
  map_area = xsize * ysize
  regions = regions.reject { |r| r[:tile_count] > map_area * 0.3 }

  # Filter: skip very low fill ratio (not rectangular buildings)
  buildings = regions.select { |r| r[:fill_ratio] > 0.4 && r[:w] >= 3 && r[:h] >= 3 }

  # Also skip if too large (> 20x20 without padding)
  buildings = buildings.select { |r| r[:w] <= 25 && r[:h] <= 25 }

  stamps = []
  buildings.each_with_index do |r, i|
    # Add padding
    rx = [r[:min_x] - padding, 0].max
    ry = [r[:min_y] - padding, 0].max
    rw = [r[:w] + padding * 2, xsize - rx].min
    rh = [r[:h] + padding * 2, ysize - ry].min

    name = "#{prefix}_building_auto_#{i}"
    stamps << extract_stamp(name, map_num, tiles, xsize, ysize, rx, ry, rw, rh)
  end
  stamps
end

###############################################################################
# MAP 001 - PALLET TOWN (45x30)
###############################################################################
puts "\n=== Map001 - Pallet Town ==="
map = load_map(1)
xsize, ysize, _, tiles = get_tiles(map)

# Player's house (red-roofed) - Layer 2 tiles 3128-3173 area around x=5-10, y=0-5
# With padding for ground context
extract_stamp("pallet_house_red", 1, tiles, xsize, ysize, 3, 0, 10, 8)

# Rival's house (blue-roofed) - Layer 2 tiles 1696-1733 area around x=24-29
extract_stamp("pallet_house_rival", 1, tiles, xsize, ysize, 22, 0, 10, 8)

# Oak's Lab - Layer 2 tiles around x=30-35, y=0-6 (3136-3165 continuing)
extract_stamp("pallet_oak_lab", 1, tiles, xsize, ysize, 29, 0, 9, 8)

# Garden/flowers - look at the area with distinctive ground tiles
# The lab building area x=15-21, y=8-14 has layer2 tiles (4040-4094)
extract_stamp("pallet_lab_pokemon", 1, tiles, xsize, ysize, 14, 8, 9, 8)

# Small garden/flower area near houses
# Looking at the distinctive tiles around y=17-21 area (tile 8998 ground + layer2 buildings)
extract_stamp("pallet_garden_flowers", 1, tiles, xsize, ysize, 8, 17, 6, 5)

# Oak's Pokemon research building (the second one with 2241-2279 tiles)
extract_stamp("pallet_house_south", 1, tiles, xsize, ysize, 16, 16, 8, 7)

# The bigger building at x=22-27 with layer2 3136-3173
extract_stamp("pallet_building_east", 1, tiles, xsize, ysize, 21, 16, 12, 7)

# Fence/wall section at bottom
extract_stamp("pallet_fence_south", 1, tiles, xsize, ysize, 0, 24, 6, 4)

# Sign area in the south-east x=36-43, y=10-14
extract_stamp("pallet_house_se", 1, tiles, xsize, ysize, 35, 10, 10, 7)

###############################################################################
# MAP 079 - VIRIDIAN CITY (51x50)
###############################################################################
puts "\n=== Map079 - Viridian City ==="
map = load_map(79)
xsize, ysize, _, tiles = get_tiles(map)

# First, let's discover building regions
puts "  Layer 2 regions:"
regions = find_layer2_regions(tiles, xsize, ysize, min_tiles: 6)
map_area = xsize * ysize
regions = regions.reject { |r| r[:tile_count] > map_area * 0.3 }
regions.first(15).each_with_index do |r, i|
  puts "    Region #{i}: pos=(#{r[:min_x]},#{r[:min_y]}) size=#{r[:w]}x#{r[:h]} tiles=#{r[:tile_count]} fill=#{(r[:fill_ratio]*100).round(1)}%"
end

# Extract based on the regions found - we need to inspect actual positions
# Let's dump layer2 non-zero positions for coordinate identification
l2_positions = []
(0...ysize).each do |y|
  (0...xsize).each do |x|
    t = tile_at(tiles, xsize, ysize, x, y, 2)
    l2_positions << [x, y, t] if t != 0
  end
end

# Group by proximity to identify buildings
# For now, extract based on common Pokemon city layouts

# Viridian Gym - typically large building, top portion of the map
# Let's scan for it by looking at upper-right area
# We'll extract specific coordinates after seeing the regions

###############################################################################
# MAP 095 - CELADON CITY (77x51)
###############################################################################
puts "\n=== Map095 - Celadon City ==="
map = load_map(95)
xsize, ysize, _, tiles = get_tiles(map)

regions = find_layer2_regions(tiles, xsize, ysize, min_tiles: 6)
map_area = xsize * ysize
regions = regions.reject { |r| r[:tile_count] > map_area * 0.3 }
regions.first(15).each_with_index do |r, i|
  puts "    Region #{i}: pos=(#{r[:min_x]},#{r[:min_y]}) size=#{r[:w]}x#{r[:h]} tiles=#{r[:tile_count]} fill=#{(r[:fill_ratio]*100).round(1)}%"
end

###############################################################################
# MAP 078 - ROUTE 1 (44x50)
###############################################################################
puts "\n=== Map078 - Route 1 ==="
map = load_map(78)
xsize, ysize, _, tiles = get_tiles(map)

regions = find_layer2_regions(tiles, xsize, ysize, min_tiles: 4)
map_area = xsize * ysize
regions = regions.reject { |r| r[:tile_count] > map_area * 0.3 }
regions.first(10).each_with_index do |r, i|
  puts "    Region #{i}: pos=(#{r[:min_x]},#{r[:min_y]}) size=#{r[:w]}x#{r[:h]} tiles=#{r[:tile_count]} fill=#{(r[:fill_ratio]*100).round(1)}%"
end

###############################################################################
# MAP 380 - PEWTER CITY (60x41)
###############################################################################
puts "\n=== Map380 - Pewter City ==="
map = load_map(380)
xsize, ysize, _, tiles = get_tiles(map)

regions = find_layer2_regions(tiles, xsize, ysize, min_tiles: 6)
map_area = xsize * ysize
regions = regions.reject { |r| r[:tile_count] > map_area * 0.3 }
regions.first(15).each_with_index do |r, i|
  puts "    Region #{i}: pos=(#{r[:min_x]},#{r[:min_y]}) size=#{r[:w]}x#{r[:h]} tiles=#{r[:tile_count]} fill=#{(r[:fill_ratio]*100).round(1)}%"
end

###############################################################################
# MAP 472 - FUCHSIA CITY (64x46)
###############################################################################
puts "\n=== Map472 - Fuchsia City ==="
map = load_map(472)
xsize, ysize, _, tiles = get_tiles(map)

regions = find_layer2_regions(tiles, xsize, ysize, min_tiles: 6)
map_area = xsize * ysize
regions = regions.reject { |r| r[:tile_count] > map_area * 0.3 }
regions.first(15).each_with_index do |r, i|
  puts "    Region #{i}: pos=(#{r[:min_x]},#{r[:min_y]}) size=#{r[:w]}x#{r[:h]} tiles=#{r[:tile_count]} fill=#{(r[:fill_ratio]*100).round(1)}%"
end

puts "\nPhase 1 complete - extracted Pallet Town stamps and discovered regions for all maps."
puts "Run phase 2 for targeted extraction."
