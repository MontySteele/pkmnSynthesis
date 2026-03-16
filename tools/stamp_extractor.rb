#!/usr/bin/env ruby
# stamp_extractor.rb — Extract reusable multi-tile "stamps" from RPG Maker XP maps.
#
# Usage:
#   ruby tools/stamp_extractor.rb <game_data_dir> <map_file> --rect x,y,w,h --name foo
#   ruby tools/stamp_extractor.rb <game_data_dir> <map_file> --auto [--seed x,y]
#   ruby tools/stamp_extractor.rb <game_data_dir> --catalog
#
# Stamps are saved as JSON files in tools/stamps/

require_relative "rpgmaker_stubs"
require "json"
require "time"
require "fileutils"

STAMPS_DIR = File.join(__dir__, "stamps")

# ── Map helper ───────────────────────────────────────────────────────────────

class MapData
  attr_reader :xsize, :ysize, :zsize, :tiles, :map, :map_id

  def initialize(game_dir, map_path)
    @game_dir = game_dir
    @map = Marshal.load(File.binread(map_path))
    @map_id = File.basename(map_path).scan(/\d+/).first.to_i

    raw = @map.data.instance_variable_get(:@raw)
    _ndim, @xsize, @ysize, @zsize, _total = raw.unpack("V5")
    @tiles = raw[20..-1].unpack("v*")
  end

  def tile(x, y, z)
    return 0 if x < 0 || y < 0 || x >= @xsize || y >= @ysize || z < 0 || z >= @zsize
    @tiles[x + y * @xsize + z * @xsize * @ysize]
  end

  # Extract a rectangular stamp region across all 3 layers.
  def extract_rect(x, y, w, h)
    layers = {}
    (0...[@zsize, 3].min).each do |z|
      layer_key = "layer#{z}"
      rows = []
      (y...(y + h)).each do |row|
        cols = []
        (x...(x + w)).each do |col|
          cols << tile(col, row, z)
        end
        rows << cols
      end
      layers[layer_key] = rows
    end
    layers
  end

  # Return the set of tile IDs that are "grass" (most common ground tiles).
  # Grass in the Outdoor tileset is the repeating 544-571 block.
  GRASS_TILE_IDS = (544..571).to_a.to_set

  # Tree tile IDs (these line roads and connect everything - must be excluded from flood-fill)
  TREE_TILE_IDS = ((8976..9017).to_a + (8992..9017).to_a).to_set

  # Tiles that are purely decorative border / road-lining (trees, fences along roads)
  # that should NOT be followed during building flood-fill.
  SEPARATOR_TILE_IDS = TREE_TILE_IDS

  def grass?(tid)
    GRASS_TILE_IDS.include?(tid)
  end

  def tree?(tid)
    TREE_TILE_IDS.include?(tid)
  end

  # Check if a position is "empty" (grass on L0, nothing on L1/L2).
  def empty_at?(x, y)
    return true if x < 0 || y < 0 || x >= @xsize || y >= @ysize
    l0 = tile(x, y, 0)
    l1 = tile(x, y, 1)
    l2 = tile(x, y, 2)
    grass?(l0) && l1 == 0 && l2 == 0
  end

  # Check if a tile position has "building structure" content (not just trees/grass).
  def building_content?(x, y)
    return false if x < 0 || y < 0 || x >= @xsize || y >= @ysize
    (0...[zsize, 3].min).each do |z|
      t = tile(x, y, z)
      next if t == 0 || grass?(t)
      # Has non-grass, non-zero content. Check if it's a separator tile.
      return true unless SEPARATOR_TILE_IDS.include?(t)
    end
    false
  end

  # Flood-fill from a seed to find the bounding box of building structure tiles.
  # Only follows tiles that have building content (excludes trees that line roads).
  def auto_detect_bounds(seed_x, seed_y, padding: 1)
    visited = {}
    queue = [[seed_x, seed_y]]
    min_x = max_x = seed_x
    min_y = max_y = seed_y

    while (pos = queue.shift)
      cx, cy = pos
      key = (cx << 16) | cy
      next if visited[key]
      next if cx < 0 || cy < 0 || cx >= @xsize || cy >= @ysize
      visited[key] = true

      # Only follow tiles with building structure content
      next unless building_content?(cx, cy)

      min_x = cx if cx < min_x
      max_x = cx if cx > max_x
      min_y = cy if cy < min_y
      max_y = cy if cy > max_y

      # Expand search to neighbors (include diagonals for buildings)
      [[-1, 0], [1, 0], [0, -1], [0, 1],
       [-1, -1], [1, -1], [-1, 1], [1, 1]].each do |dx, dy|
        nx, ny = cx + dx, cy + dy
        nk = (nx << 16) | ny
        queue << [nx, ny] unless visited[nk]
      end
    end

    # Safety: if the detected region is too large, fall back to a reasonable max
    w = max_x - min_x + 1
    h = max_y - min_y + 1
    if w > 30 || h > 30
      STDERR.puts "    WARNING: auto-detect region too large (#{w}x#{h}), clamping to 20x20 around seed"
      half = 10
      min_x = [seed_x - half, 0].max
      min_y = [seed_y - half, 0].max
      max_x = [seed_x + half, @xsize - 1].min
      max_y = [seed_y + half, @ysize - 1].min
    end

    # Apply padding
    x0 = [min_x - padding, 0].max
    y0 = [min_y - padding, 0].max
    x1 = [max_x + padding, @xsize - 1].min
    y1 = [max_y + padding, @ysize - 1].min

    { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }
  end
end

# ── Stamp saving ─────────────────────────────────────────────────────────────

def save_stamp(name:, width:, height:, source_map:, source_rect:, tiles:, category: nil, output_dir: STAMPS_DIR)
  FileUtils.mkdir_p(output_dir)

  stamp = {
    "name" => name,
    "width" => width,
    "height" => height,
    "source_map" => source_map,
    "source_rect" => source_rect,
    "tiles" => tiles
  }
  stamp["category"] = category if category

  path = File.join(output_dir, "#{name}.json")
  File.write(path, JSON.pretty_generate(stamp) + "\n")
  STDERR.puts "  Saved stamp: #{path} (#{width}x#{height})"
  stamp
end

def extract_and_save(md, name:, x:, y:, w:, h:, category: nil)
  layers = md.extract_rect(x, y, w, h)
  save_stamp(
    name: name,
    width: w,
    height: h,
    source_map: md.map_id,
    source_rect: { "x" => x, "y" => y, "w" => w, "h" => h },
    tiles: layers,
    category: category
  )
end

def auto_extract_and_save(md, name:, seed_x:, seed_y:, category: nil, padding: 1)
  bounds = md.auto_detect_bounds(seed_x, seed_y, padding: padding)
  STDERR.puts "  Auto-detected bounds for '#{name}': #{bounds.inspect}"
  extract_and_save(md, name: name, x: bounds[:x], y: bounds[:y], w: bounds[:w], h: bounds[:h], category: category)
end

# ── Catalog definitions ──────────────────────────────────────────────────────
# Known stamps in known maps. Each entry specifies either a rect or a seed
# coordinate for auto-detection.

def catalog_definitions
  # Map001 = Cerulean City (45x30), tileset 23
  # Map079 = Viridian City (51x50), tileset 23
  # Map095 = Celadon City (77x51), tileset 23
  #
  # Coordinates derived from visual analysis of L1+L2 tile maps.
  [
    # ── Map001: Cerulean City ──
    # Large building complex (sign/pokecenter area) around door (18,14)
    { map: 1, name: "cerulean_pokecenter", rect: [14, 8, 12, 8], category: "pokemon_center" },
    # House NW corner with fence (around x=5-12, y=0-6)
    { map: 1, name: "cerulean_house_nw", rect: [5, 0, 8, 7], category: "house" },
    # Building NE area (x=28-36, y=0-6)
    { map: 1, name: "cerulean_building_ne", rect: [28, 0, 9, 7], category: "building" },
    # Eastern tall building (x=34-44, y=8-15)
    { map: 1, name: "cerulean_building_east", rect: [34, 8, 11, 8], category: "building" },
    # Houses south side (x=8-12, y=17-21)
    { map: 1, name: "cerulean_house_s1", rect: [8, 17, 6, 5], category: "house" },
    # Building south center (x=16-26, y=17-22)
    { map: 1, name: "cerulean_building_s2", rect: [16, 16, 11, 7], category: "building" },
    # Trees top-left (L2 area around y=0-5, x=0-4)
    { map: 1, name: "cerulean_tree_cluster_nw", rect: [0, 0, 5, 6], category: "tree" },
    # Fence section south (x=0-5, y=24-25)
    { map: 1, name: "cerulean_fence_south", rect: [0, 24, 6, 2], category: "fence" },
    # Path/bridge area (x=12-14, y=7-9)
    { map: 1, name: "cerulean_path_segment", rect: [3, 7, 5, 3], category: "path" },

    # ── Map079: Viridian City ──
    # Large building at (23-33, y=6-16) - looks like Gym or Pokecenter
    { map: 79, name: "viridian_large_building", rect: [23, 6, 11, 11], category: "gym" },
    # House with door at (13,14): x=8-14, y=8-15
    { map: 79, name: "viridian_house_1", rect: [8, 8, 7, 9], category: "house" },
    # Sign building area (x=11-18, y=17-22)
    { map: 79, name: "viridian_house_2", rect: [11, 17, 8, 6], category: "house" },
    # House with door at (25,28): x=23-29, y=24-29
    { map: 79, name: "viridian_house_3", rect: [23, 23, 8, 7], category: "house" },
    # Building with door at (24,37): x=0-7, y=37-38
    { map: 79, name: "viridian_house_4", rect: [0, 37, 8, 3], category: "house" },
    # Right-side building cluster (x=37-50, y=37-44)
    { map: 79, name: "viridian_building_se", rect: [37, 37, 14, 8], category: "building" },
    # Right-side upper building (x=37-50, y=13-18)
    { map: 79, name: "viridian_building_ne", rect: [37, 13, 14, 8], category: "building" },
    # Trees along top edge
    { map: 79, name: "viridian_tree_row_top", rect: [0, 0, 8, 6], category: "tree" },
    # Trees lower-left cluster (x=0-12, y=30-42)
    { map: 79, name: "viridian_tree_cluster_sw", rect: [0, 30, 8, 6], category: "tree_cluster" },
    # Lamp posts
    { map: 79, name: "viridian_lamppost_1", rect: [10, 12, 3, 3], category: "lamppost" },
    { map: 79, name: "viridian_lamppost_2", rect: [21, 42, 3, 3], category: "lamppost" },
    # Sign area
    { map: 79, name: "viridian_sign_area", rect: [20, 19, 3, 3], category: "sign" },
    # Fence section along road (x=10-17, y=30-31)
    { map: 79, name: "viridian_fence_section", rect: [10, 30, 7, 2], category: "fence" },
    # Pond/water area bottom (x=18-22, y=43-48)
    { map: 79, name: "viridian_water_feature", rect: [18, 43, 5, 5], category: "water" },

    # ── Map095: Celadon City ──
    # Department store (large building, x=15-24, y=2-10)
    { map: 95, name: "celadon_dept_store", rect: [15, 2, 10, 9], category: "building" },
    # Building cluster mid-left (x=27-34, y=2-10)
    { map: 95, name: "celadon_building_2", rect: [27, 2, 8, 9], category: "building" },
    # Building center-top (x=35-43, y=3-7)
    { map: 95, name: "celadon_building_3", rect: [35, 3, 9, 5], category: "building" },
    # Building right-top (x=44-53, y=3-7)
    { map: 95, name: "celadon_building_4", rect: [44, 3, 10, 5], category: "building" },
    # Right-side large building (x=55-65, y=4-7)
    { map: 95, name: "celadon_building_right", rect: [55, 4, 10, 4], category: "building" },
    # Pokecenter area (x=30-40, y=16-23)
    { map: 95, name: "celadon_pokecenter", rect: [30, 16, 11, 8], category: "pokemon_center" },
    # Mart area (x=44-53, y=13-20)
    { map: 95, name: "celadon_mart", rect: [44, 13, 10, 8], category: "mart" },
    # House lower-left (x=17-24, y=30-35)
    { map: 95, name: "celadon_house_1", rect: [14, 30, 11, 6], category: "house" },
    # Gym-like building (x=25-35, y=30-36)
    { map: 95, name: "celadon_gym", rect: [25, 30, 11, 7], category: "gym" },
    # Garden/flower area (x=11-23, y=6-10)
    { map: 95, name: "celadon_garden", rect: [11, 6, 13, 5], category: "flower_bed" },
    # Pond/water bottom (x=36-41, y=41-50)
    { map: 95, name: "celadon_pond", rect: [36, 41, 6, 10], category: "water" },
    # Trees right side (x=59-65, y=2-4)
    { map: 95, name: "celadon_tree_cluster_ne", rect: [59, 2, 7, 3], category: "tree" },
    # Path segment (straight road, x=25-35, y=11-11)
    { map: 95, name: "celadon_path_straight", rect: [25, 11, 11, 1], category: "path" },
    # Path corner (x=14-17, y=28-31)
    { map: 95, name: "celadon_path_corner", rect: [14, 28, 4, 4], category: "path" },
    # Fence area (x=55-60, y=25-27)
    { map: 95, name: "celadon_fence_section", rect: [55, 25, 6, 3], category: "fence" },
    # Large trees bottom-left (x=0-7, y=30-31)
    { map: 95, name: "celadon_tree_row_bottom", rect: [0, 30, 8, 2], category: "tree" },
    # Building with condominiums (x=55-65, y=13-20)
    { map: 95, name: "celadon_condominiums", rect: [55, 13, 11, 8], category: "building" },
  ]
end

# ── Catalog runner ───────────────────────────────────────────────────────────

def run_catalog(game_dir)
  STDERR.puts "Running stamp catalog extraction..."
  FileUtils.mkdir_p(STAMPS_DIR)

  # Cache loaded maps
  map_cache = {}
  all_stamps = []

  catalog_definitions.each do |defn|
    map_id = defn[:map]
    map_file = File.join(game_dir, "Data", "Map%03d.rxdata" % map_id)
    unless File.exist?(map_file)
      STDERR.puts "  SKIP: #{map_file} not found"
      next
    end

    map_cache[map_id] ||= MapData.new(game_dir, map_file)
    md = map_cache[map_id]

    begin
      stamp = if defn[:rect]
        x, y, w, h = defn[:rect]
        extract_and_save(md, name: defn[:name], x: x, y: y, w: w, h: h, category: defn[:category])
      elsif defn[:seed]
        sx, sy = defn[:seed]
        auto_extract_and_save(md, name: defn[:name], seed_x: sx, seed_y: sy,
                              category: defn[:category], padding: defn[:padding] || 1)
      end
      all_stamps << stamp if stamp
    rescue => e
      STDERR.puts "  ERROR extracting '#{defn[:name]}': #{e.message}"
    end
  end

  # Also do a pass to auto-detect additional structures in each map
  map_cache.each do |map_id, md|
    STDERR.puts "  Scanning Map#{"%03d" % map_id} for additional structures..."
    additional = auto_scan_map(md, existing_stamps: all_stamps)
    additional.each do |stamp|
      all_stamps << stamp
    end
  end

  # Write catalog index
  write_catalog(all_stamps)
  STDERR.puts "Catalog extraction complete: #{all_stamps.size} stamps"
end

# Scan a map for building structures not already covered by named stamps.
# Uses building_content? (excludes trees) for flood-fill to isolate buildings.
def auto_scan_map(md, existing_stamps: [])
  visited = Array.new(md.xsize * md.ysize, false)
  regions = []

  # Mark tiles already covered by existing stamps for this map
  existing_stamps.each do |st|
    next unless st && st["source_map"] == md.map_id
    r = st["source_rect"]
    (r["y"]...(r["y"] + r["h"])).each do |y|
      (r["x"]...(r["x"] + r["w"])).each do |x|
        visited[x + y * md.xsize] = true if x >= 0 && x < md.xsize && y >= 0 && y < md.ysize
      end
    end
  end

  (0...md.ysize).each do |y|
    (0...md.xsize).each do |x|
      idx = x + y * md.xsize
      next if visited[idx]
      next unless md.building_content?(x, y)

      # BFS following only building content tiles
      region_tiles = []
      queue = [[x, y]]
      min_x = max_x = x
      min_y = max_y = y

      while (pos = queue.shift)
        cx, cy = pos
        next if cx < 0 || cy < 0 || cx >= md.xsize || cy >= md.ysize
        ci = cx + cy * md.xsize
        next if visited[ci]
        visited[ci] = true
        next unless md.building_content?(cx, cy)

        region_tiles << [cx, cy]
        min_x = cx if cx < min_x
        max_x = cx if cx > max_x
        min_y = cy if cy < min_y
        max_y = cy if cy > max_y

        # Stop expanding if region is already very large
        break if region_tiles.size > 500

        [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]].each do |dx, dy|
          nx, ny = cx + dx, cy + dy
          next if nx < 0 || ny < 0 || nx >= md.xsize || ny >= md.ysize
          queue << [nx, ny] unless visited[nx + ny * md.xsize]
        end
      end

      w = max_x - min_x + 1
      h = max_y - min_y + 1
      tile_count = region_tiles.size
      next if tile_count < 4 || w > 25 || h > 25  # skip tiny or overly large regions

      category = classify_region(md, min_x, min_y, w, h, tile_count)
      name = "map%03d_%s_%d_%d" % [md.map_id, category, min_x, min_y]

      regions << {
        name: name, x: min_x, y: min_y, w: w, h: h,
        category: category, tile_count: tile_count
      }
    end
  end

  stamps = []
  regions.each do |r|
    begin
      stamp = extract_and_save(md, name: r[:name], x: r[:x], y: r[:y], w: r[:w], h: r[:h], category: r[:category])
      stamps << stamp
    rescue => e
      STDERR.puts "    ERROR auto-extracting '#{r[:name]}': #{e.message}"
    end
  end
  stamps
end

def classify_region(md, x, y, w, h, tile_count)
  # Simple heuristics based on size and tile patterns
  area = w * h
  density = tile_count.to_f / area

  # Check for tree tiles (common autotile IDs for trees: 8992-9017 range)
  tree_count = 0
  water_count = 0
  fence_count = 0
  building_count = 0

  (y...(y + h)).each do |cy|
    (x...(x + w)).each do |cx|
      (0..2).each do |z|
        t = md.tile(cx, cy, z)
        next if t == 0

        if t >= 8976 && t <= 9017
          tree_count += 1
        elsif t >= 384 && t < 544  # water autotiles typically in lower ranges
          water_count += 1
        elsif t >= 10280 && t <= 10298  # fence-like tiles
          fence_count += 1
        elsif t >= 9080 && t <= 9101  # building wall tiles
          building_count += 1
        end
      end
    end
  end

  total_interesting = [tree_count, water_count, fence_count, building_count].sum.to_f
  return "misc" if total_interesting == 0

  if tree_count > total_interesting * 0.4
    return w <= 3 && h <= 3 ? "tree" : "tree_cluster"
  end
  return "water" if water_count > total_interesting * 0.4
  return "fence" if fence_count > total_interesting * 0.3
  return "building" if building_count > total_interesting * 0.3

  if w <= 2 && h <= 3
    return "lamppost"
  end
  if w <= 3 && h <= 2
    return "sign"
  end

  "misc"
end

# ── Catalog index ────────────────────────────────────────────────────────────

def write_catalog(stamps)
  catalog = {
    "generated_at" => Time.now.iso8601,
    "total_stamps" => stamps.size,
    "stamps" => stamps.map do |s|
      {
        "name" => s["name"],
        "file" => "#{s["name"]}.json",
        "width" => s["width"],
        "height" => s["height"],
        "source_map" => s["source_map"],
        "category" => s["category"] || "misc"
      }
    end,
    "categories" => stamps.group_by { |s| s["category"] || "misc" }.transform_values(&:size)
  }
  path = File.join(STAMPS_DIR, "catalog.json")
  File.write(path, JSON.pretty_generate(catalog) + "\n")
  STDERR.puts "  Saved catalog: #{path}"
end

# ── CLI ──────────────────────────────────────────────────────────────────────

if __FILE__ == $0
  if ARGV.length < 1
    STDERR.puts <<~USAGE
      Usage:
        ruby tools/stamp_extractor.rb <game_data_dir> <map_file> --rect x,y,w,h --name <name> [--category <cat>]
        ruby tools/stamp_extractor.rb <game_data_dir> <map_file> --auto --seed x,y --name <name> [--category <cat>]
        ruby tools/stamp_extractor.rb <game_data_dir> --catalog

      Examples:
        ruby tools/stamp_extractor.rb game_data game_data/Data/Map001.rxdata --rect 14,8,10,8 --name cerulean_pokecenter
        ruby tools/stamp_extractor.rb game_data game_data/Data/Map079.rxdata --auto --seed 13,12 --name viridian_house
        ruby tools/stamp_extractor.rb game_data --catalog
    USAGE
    exit 1
  end

  game_dir = ARGV[0]

  if ARGV.include?("--catalog")
    run_catalog(game_dir)
    exit 0
  end

  map_file = ARGV[1]
  unless map_file && File.exist?(map_file)
    STDERR.puts "Error: Map file not found: #{map_file}"
    exit 1
  end

  md = MapData.new(game_dir, map_file)
  STDERR.puts "Loaded Map#{"%03d" % md.map_id}: #{md.xsize}x#{md.ysize}x#{md.zsize}"

  name_idx = ARGV.index("--name")
  name = name_idx ? ARGV[name_idx + 1] : nil

  cat_idx = ARGV.index("--category")
  category = cat_idx ? ARGV[cat_idx + 1] : nil

  if ARGV.include?("--auto")
    seed_idx = ARGV.index("--seed")
    if seed_idx
      sx, sy = ARGV[seed_idx + 1].split(",").map(&:to_i)
    else
      STDERR.puts "Error: --auto requires --seed x,y"
      exit 1
    end
    name ||= "stamp_#{md.map_id}_#{sx}_#{sy}"
    auto_extract_and_save(md, name: name, seed_x: sx, seed_y: sy, category: category)

  elsif (rect_idx = ARGV.index("--rect"))
    parts = ARGV[rect_idx + 1].split(",").map(&:to_i)
    x, y, w, h = parts
    name ||= "stamp_#{md.map_id}_#{x}_#{y}"
    extract_and_save(md, name: name, x: x, y: y, w: w, h: h, category: category)

  else
    STDERR.puts "Error: Specify --rect or --auto mode"
    exit 1
  end
end
