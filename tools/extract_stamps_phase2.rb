#!/usr/bin/env ruby
# Phase 2: Targeted extraction from all maps based on region discovery

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

def extract_stamp(name, map_num, tiles, xsize, ysize, rx, ry, rw, rh)
  # Clamp to map bounds
  rx = [rx, 0].max
  ry = [ry, 0].max
  rw = [rw, xsize - rx].min
  rh = [rh, ysize - ry].min

  layers = {}
  3.times do |z|
    rows = []
    (ry...ry+rh).each do |y|
      row = (rx...rx+rw).map { |x| tile_at(tiles, xsize, ysize, x, y, z) }
      rows << row
    end
    layers["layer#{z}"] = rows
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

# Helper: scan for specific tile ID ranges on a given layer to find precise building bounds
def find_tile_bounds(tiles, xsize, ysize, layer, tile_range)
  min_x = xsize; min_y = ysize; max_x = 0; max_y = 0
  found = false
  (0...ysize).each do |y|
    (0...xsize).each do |x|
      t = tile_at(tiles, xsize, ysize, x, y, layer)
      if tile_range.include?(t)
        found = true
        min_x = x if x < min_x
        min_y = y if y < min_y
        max_x = x if x > max_x
        max_y = y if y > max_y
      end
    end
  end
  return nil unless found
  { min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y,
    w: max_x - min_x + 1, h: max_y - min_y + 1 }
end

###############################################################################
# MAP 079 - VIRIDIAN CITY (51x50)
###############################################################################
puts "\n=== Map079 - Viridian City ==="
map = load_map(79)
xsize, ysize, _, tiles = get_tiles(map)

# Region analysis from phase 1:
# Region 5: pos=(23,13) 7x7 100% fill - likely a building (pokecenter or gym?)
# Region 6: pos=(21,31) 7x7 100% fill - another building
# Region 4: pos=(12,24) 9x11 55% fill - building complex
# Region 7: pos=(12,17) 9x6 61% fill - building
# Region 9: pos=(24,23) 5x6 87% fill - building
# Region 8: pos=(0,37) 8x4 100% fill - building
# Region 0: pos=(11,0) 40x24 - large connected area (skip - too big, partial tree border)
# Region 2: pos=(0,0) 9x35 - left border trees

# Viridian Gym - the largest standalone building, likely region 5 at (23,13) 7x7
# With padding
extract_stamp("viridian_gym_building", 79, tiles, xsize, ysize, 22, 12, 9, 9)

# Pokecenter - region 6 at (21,31) 7x7
extract_stamp("viridian_pokecenter", 79, tiles, xsize, ysize, 20, 30, 9, 9)

# Mart - region 7 at (12,17) 9x6
extract_stamp("viridian_mart", 79, tiles, xsize, ysize, 11, 16, 11, 8)

# Building at region 9: (24,23) 5x6
extract_stamp("viridian_house_center", 79, tiles, xsize, ysize, 23, 22, 7, 8)

# Building at region 4: (12,24) 9x11 - larger building complex
extract_stamp("viridian_building_west", 79, tiles, xsize, ysize, 11, 23, 11, 13)

# Small building at region 8: (0,37) 8x4
extract_stamp("viridian_building_south", 79, tiles, xsize, ysize, 0, 36, 10, 6)

# Tree border - left side (region 2: 0,0 9x35)
extract_stamp("viridian_tree_border_left", 79, tiles, xsize, ysize, 0, 0, 10, 12)

# Individual 2x2 tree - find a standalone tree
# Trees are typically on layers 1+2, 2x2 blocks
# Look for isolated 2x2 blocks
# Scan layer 1 for the common tree tiles
tree_found = false
(2...ysize-2).each do |y|
  break if tree_found
  (2...xsize-2).each do |x|
    break if tree_found
    t1 = tile_at(tiles, xsize, ysize, x, y, 1)
    next if t1 == 0
    # Check if it's part of a 2x2 block that looks like a tree
    # Trees typically have trunk tiles on layer 1 and canopy on layer 2
    t2 = tile_at(tiles, xsize, ysize, x, y, 2)
    next if t2 == 0
    # Check surrounding - if isolated enough
    # For a standalone tree, extract a 4x4 with padding
    if tile_at(tiles, xsize, ysize, x+1, y, 2) != 0 &&
       tile_at(tiles, xsize, ysize, x, y+1, 2) != 0 &&
       tile_at(tiles, xsize, ysize, x+1, y+1, 2) != 0
      # Check this 2x2 block is somewhat isolated
      extract_stamp("tree_single", 79, tiles, xsize, ysize, x-1, y-1, 4, 4)
      tree_found = true
    end
  end
end

# Region 10: (27,37) 7x6 - another building area
extract_stamp("viridian_building_se", 79, tiles, xsize, ysize, 26, 36, 9, 8)

###############################################################################
# MAP 095 - CELADON CITY (77x51)
###############################################################################
puts "\n=== Map095 - Celadon City ==="
map = load_map(95)
xsize, ysize, _, tiles = get_tiles(map)

# From phase 1 region analysis:
# Region 0: pos=(11,2) 15x13 159 tiles 81.5% - DEPARTMENT STORE (big building top-left)
# Region 3: pos=(39,10) 10x17 - building on the right side
# Region 4: pos=(30,17) 9x11 65.7% - possible game corner
# Region 7: pos=(53,3) 8x4 - smaller building
# Region 9: pos=(35,2) 5x4 100% - small building
# Region 10: pos=(41,3) 10x2 - long structure
# Region 11: pos=(58,11) 5x4 100% - building
# Region 12: pos=(43,31) 6x4 - building
# Region 13: pos=(28,2) 6x4 - building

# Department Store - region 0 at (11,2) 15x13
extract_stamp("celadon_department_store", 95, tiles, xsize, ysize, 10, 1, 17, 15)

# Game Corner - region 4 at (30,17) 9x11
extract_stamp("celadon_game_corner", 95, tiles, xsize, ysize, 29, 16, 11, 13)

# Pokecenter - need to identify which region
# Typically has distinctive red roof tiles - let's check region 13 at (28,2)
extract_stamp("celadon_pokecenter_new", 95, tiles, xsize, ysize, 27, 1, 8, 6)

# Condos/row of houses on right side - region 3 at (39,10) 10x17
extract_stamp("celadon_condos", 95, tiles, xsize, ysize, 38, 9, 12, 19)

# Gym - check region near the distinctive tiles
# Region 11: (58,11) 5x4 or other candidates
extract_stamp("celadon_gym", 95, tiles, xsize, ysize, 57, 10, 7, 6)

# Additional buildings
extract_stamp("celadon_building_top1", 95, tiles, xsize, ysize, 34, 1, 7, 6)
extract_stamp("celadon_building_top2", 95, tiles, xsize, ysize, 40, 2, 12, 4)
extract_stamp("celadon_building_mid", 95, tiles, xsize, ysize, 52, 2, 10, 6)

# Region 6: (48,30) 21x4 - long row of buildings/structures
extract_stamp("celadon_row_south", 95, tiles, xsize, ysize, 47, 29, 23, 6)

# Region 5: (40,37) 12x14 - large area bottom right
extract_stamp("celadon_building_br", 95, tiles, xsize, ysize, 39, 36, 14, 16)

# Region 12: (43,31) 6x4
extract_stamp("celadon_shop_small", 95, tiles, xsize, ysize, 42, 30, 8, 6)

###############################################################################
# MAP 078 - ROUTE 1 (44x50)
###############################################################################
puts "\n=== Map078 - Route 1 ==="
map = load_map(78)
xsize, ysize, _, tiles = get_tiles(map)

# Route 1 is mostly natural terrain - trees, grass, ledges
# Regions found were mostly tree borders (2-tile tall strips)
# Region 0: (0,48) 18x2 - bottom border
# Region 2: (15,4) 15x2 - top tree line
# Region 4: (0,16) 8x2 - left tree border at y=16
# Region 5: (36,16) 8x2 - right tree border at y=16

# Tall grass patches - scan layer 0 for grass autotile patterns
# Autotile IDs: tiles 48-95 are autotile 1, 96-143 = autotile 2, etc.
# Tall grass is typically one of the autotile patterns
# Let's find grass by looking for autotile ranges on layer 0 that differ from the base terrain

# Look at layer 1 for tall grass indicators
puts "  Scanning for tall grass tiles..."
l1_tile_counts = Hash.new(0)
(0...ysize).each do |y|
  (0...xsize).each do |x|
    t = tile_at(tiles, xsize, ysize, x, y, 1)
    l1_tile_counts[t] += 1 if t != 0
  end
end
l1_tile_counts.sort_by { |_, c| -c }.first(15).each do |t, c|
  puts "    L1 tile=#{t} count=#{c}"
end

# Also check layer 0 unique tiles
l0_tile_counts = Hash.new(0)
(0...ysize).each do |y|
  (0...xsize).each do |x|
    t = tile_at(tiles, xsize, ysize, x, y, 0)
    l0_tile_counts[t] += 1
  end
end
puts "  Layer 0 tiles:"
l0_tile_counts.sort_by { |_, c| -c }.first(15).each do |t, c|
  puts "    L0 tile=#{t} count=#{c}"
end

# Tall grass patch - find a rectangular area of tall grass
# Tall grass is often a specific autotile. Let's look for common grass patterns
# In Pokemon FRLG, tall grass is a distinctive darker green
# Let's extract some representative areas

# Tree borders on sides
extract_stamp("route_tree_border_left", 78, tiles, xsize, ysize, 0, 14, 10, 6)
extract_stamp("route_tree_border_right", 78, tiles, xsize, ysize, 34, 14, 10, 6)
extract_stamp("route_tree_border_top", 78, tiles, xsize, ysize, 13, 2, 17, 5)

# Look for a tall grass area - scan for consecutive tiles on layer 0 that are in autotile range
# Find the most common layer 0 tile (probably base terrain), then find areas of different tiles
base_tile = l0_tile_counts.max_by { |_, c| c }[0]
puts "  Base terrain tile: #{base_tile}"

# Find areas where layer 1 has grass-like tiles (not trees)
# Trees have IDs like 958, 9800-9900 range. Let's look for different patterns
# Let's extract grass patches by looking at non-base-tile areas on layer 0

# Scan for tall grass (typically autotile 2 or 3 - range 96-191)
grass_positions = []
(0...ysize).each do |y|
  (0...xsize).each do |x|
    t0 = tile_at(tiles, xsize, ysize, x, y, 0)
    # Autotile range check - different from base
    if t0 != base_tile && t0 >= 48 && t0 < 384
      grass_positions << [x, y]
    end
  end
end

if grass_positions.any?
  # Find first contiguous grass patch
  gx = grass_positions.map(&:first)
  gy = grass_positions.map(&:last)
  # Find a cluster
  # Simple: take a representative grass area
  min_gx, max_gx = gx.min, [gx.min + 8, gx.max].min
  # Find the vertical range for this x range
  in_range = grass_positions.select { |x, _| x >= min_gx && x <= max_gx }
  if in_range.any?
    min_gy = in_range.map(&:last).min
    max_gy = [min_gy + 6, in_range.map(&:last).max].min
    extract_stamp("route_tall_grass_patch", 78, tiles, xsize, ysize,
                  [min_gx - 1, 0].max, [min_gy - 1, 0].max,
                  max_gx - min_gx + 3, max_gy - min_gy + 3)
  end
end

# Ledge section - ledges are typically horizontal tiles on layer 1
# Look for ledge tiles (usually specific tile IDs representing jump-down ledges)
# Let's extract a middle section of the route that likely has ledges
extract_stamp("route_ledge_section", 78, tiles, xsize, ysize, 8, 20, 28, 6)

# Another ledge section lower
extract_stamp("route_path_section", 78, tiles, xsize, ysize, 8, 30, 28, 8)

###############################################################################
# MAP 380 - PEWTER CITY (60x41)
###############################################################################
puts "\n=== Map380 - Pewter City ==="
map = load_map(380)
xsize, ysize, _, tiles = get_tiles(map)

# Region analysis:
# Region 0: (46,25) 14x16 168 tiles - large building (gym or museum)
# Region 1: (29,1) 31x10 160 tiles - large building complex (museum?)
# Region 2: (47,9) 13x15 145 tiles - another large building
# Region 3: (0,35) 41x6 - bottom border
# Region 4: (20,2) 9x5 40 tiles 89% - pokecenter or shop
# Region 5: (19,8) 3x6 - small structure
# Region 6: (33,30) 4x4 - small building
# Region 7: (31,13) 3x4 - small building

# Pewter Gym - likely region 0 at (46,25) or region 2 at (47,9)
# In Pokemon, Pewter Gym is a distinctive rocky building
extract_stamp("pewter_gym", 380, tiles, xsize, ysize, 45, 8, 15, 17)

# Museum - region 1 at (29,1) 31x10 - the Pewter Museum is large
extract_stamp("pewter_museum", 380, tiles, xsize, ysize, 28, 0, 33, 12)

# Pokecenter - region 4 at (20,2) 9x5
extract_stamp("pewter_pokecenter", 380, tiles, xsize, ysize, 19, 1, 11, 7)

# Mart/building - region 2 at (47,9) but overlapping with gym area
# Let's extract the large building at (46,25)
extract_stamp("pewter_building_south", 380, tiles, xsize, ysize, 45, 24, 15, 17)

# Small buildings
extract_stamp("pewter_house_1", 380, tiles, xsize, ysize, 32, 29, 6, 6)
extract_stamp("pewter_house_2", 380, tiles, xsize, ysize, 30, 12, 5, 6)

# Region 10: (25,14) 4x5 with signs
extract_stamp("pewter_mart", 380, tiles, xsize, ysize, 24, 13, 6, 7)

###############################################################################
# MAP 472 - FUCHSIA CITY (64x46)
###############################################################################
puts "\n=== Map472 - Fuchsia City ==="
map = load_map(472)
xsize, ysize, _, tiles = get_tiles(map)

# Region analysis:
# Region 0: (8,22) 23x8 121 tiles - large area (Safari Zone entrance?)
# Region 1: (36,20) 11x11 76 tiles - large building (gym?)
# Region 3: (5,8) 13x12 60 tiles - building complex
# Region 4: (24,4) 9x7 49 tiles 78% - building
# Region 7: (44,10) 7x5 30 tiles 86% - building
# Region 9: (35,5) 7x4 26 tiles 93% - building
# Region 10: (35,11) 7x4 26 tiles 93% - building
# Region 11: (44,5) 7x4 18 tiles - building
# Region 5: (4,31) 16x4 - structure
# Region 12: (18,16) 8x4 - building

# Safari Zone entrance - region 0 at (8,22) 23x8
extract_stamp("fuchsia_safari_entrance", 472, tiles, xsize, ysize, 7, 21, 25, 10)

# Gym - region 1 at (36,20) 11x11
extract_stamp("fuchsia_gym", 472, tiles, xsize, ysize, 35, 19, 13, 13)

# Pokecenter - check region 4 at (24,4) 9x7
extract_stamp("fuchsia_pokecenter", 472, tiles, xsize, ysize, 23, 3, 11, 9)

# Houses - region 9 and 10 at (35,5) and (35,11)
extract_stamp("fuchsia_house_1", 472, tiles, xsize, ysize, 34, 4, 9, 6)
extract_stamp("fuchsia_house_2", 472, tiles, xsize, ysize, 34, 10, 9, 6)
extract_stamp("fuchsia_house_3", 472, tiles, xsize, ysize, 43, 4, 9, 6)

# Building complex at (5,8)
extract_stamp("fuchsia_building_west", 472, tiles, xsize, ysize, 4, 7, 15, 14)

# Region 7: (44,10) - building
extract_stamp("fuchsia_building_east", 472, tiles, xsize, ysize, 43, 9, 9, 7)

# Region 12: (18,16)
extract_stamp("fuchsia_building_mid", 472, tiles, xsize, ysize, 17, 15, 10, 6)

# Region 5: (4,31)
extract_stamp("fuchsia_structure_south", 472, tiles, xsize, ysize, 3, 30, 18, 6)

###############################################################################
# COMMON SMALL STAMPS
###############################################################################
puts "\n=== Common Small Stamps ==="

# Tree single (2x2) - use the one we already found, or find from Map001
map = load_map(1)
xsize, ysize, _, tiles = get_tiles(map)

# Find a 2x2 tree block by looking for tree-like tiles on layers 1+2
# Common tree tiles on layer 2: 8986, 8987, 8994, 8995 (these appear in pairs)
# Trees typically: L2 top-left/top-right = 8986/8987, bottom-left/bottom-right = 8994/8995
# Find a clean 2x2 tree
(0...ysize-1).each do |y|
  (0...xsize-1).each do |x|
    tl = tile_at(tiles, xsize, ysize, x, y, 2)
    tr = tile_at(tiles, xsize, ysize, x+1, y, 2)
    bl = tile_at(tiles, xsize, ysize, x, y+1, 2)
    br = tile_at(tiles, xsize, ysize, x+1, y+1, 2)
    if tl == 8986 && tr == 8987 && bl == 8994 && br == 8995
      extract_stamp("tree_single", 1, tiles, xsize, ysize, x, y, 2, 2)
      break
    end
  end
  break if File.exist?(File.join(STAMPS_DIR, "tree_single.json"))
end

# If not found with those exact IDs, try alternate pattern
unless File.exist?(File.join(STAMPS_DIR, "tree_single.json"))
  # Try other tree patterns - 8987/8986 swapped
  (0...ysize-1).each do |y|
    found = false
    (0...xsize-1).each do |x|
      tl = tile_at(tiles, xsize, ysize, x, y, 2)
      tr = tile_at(tiles, xsize, ysize, x+1, y, 2)
      bl = tile_at(tiles, xsize, ysize, x, y+1, 2)
      br = tile_at(tiles, xsize, ysize, x+1, y+1, 2)
      if [tl, tr, bl, br].all? { |t| [8986, 8987, 8994, 8995, 9008, 9009, 9016, 9017].include?(t) }
        extract_stamp("tree_single", 1, tiles, xsize, ysize, x, y, 2, 2)
        found = true
        break
      end
    end
    break if found
  end
end

# Lamppost - look for small 1x2 or 2x2 structures on layer 1
# Lamppost tiles are typically specific IDs - let's look for isolated small objects
# From Map079 which had viridian_lamppost already
map = load_map(79)
xsize, ysize, _, tiles = get_tiles(map)

# Find isolated non-zero tiles on layer 1 that are 1x2 (single lamppost)
(1...ysize-1).each do |y|
  found = false
  (1...xsize-1).each do |x|
    t1 = tile_at(tiles, xsize, ysize, x, y, 1)
    next if t1 == 0
    t_below = tile_at(tiles, xsize, ysize, x, y+1, 1)
    next if t_below == 0
    # Check isolation - nothing to left/right
    t_left = tile_at(tiles, xsize, ysize, x-1, y, 1)
    t_right = tile_at(tiles, xsize, ysize, x+1, y, 1)
    if t_left == 0 && t_right == 0
      # Looks like an isolated 1x2 structure
      extract_stamp("lamppost", 79, tiles, xsize, ysize, x-1, y-1, 3, 4)
      found = true
      break
    end
  end
  break if found
end

# Fence horizontal - look for horizontal runs of fence tiles on layer 1
# Fences use specific tile IDs, usually around 409 range
# From Map001 which has fence tiles
map = load_map(1)
xsize, ysize, _, tiles = get_tiles(map)

# Find a horizontal run of tile 409 on layer 1
(0...ysize).each do |y|
  found = false
  (0...xsize-4).each do |x|
    run = (0...5).all? { |dx| tile_at(tiles, xsize, ysize, x+dx, y, 1) == 409 }
    if run
      extract_stamp("fence_horizontal_5", 1, tiles, xsize, ysize, x, y-1, 5, 3)
      found = true
      break
    end
  end
  break if found
end

# Sign post - look for single tiles that are sign-like on layer 1
# Signs are typically tile IDs in the 1202-1203 range (from the probe data)
(0...ysize).each do |y|
  found = false
  (0...xsize).each do |x|
    t = tile_at(tiles, xsize, ysize, x, y, 1)
    if t == 1202 || t == 1203
      # Check it's somewhat isolated
      extract_stamp("sign_post", 1, tiles, xsize, ysize, x-1, y-1, 3, 3)
      found = true
      break
    end
  end
  break if found
end

puts "\nPhase 2 extraction complete!"
