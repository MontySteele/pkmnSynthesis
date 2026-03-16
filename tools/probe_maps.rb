#!/usr/bin/env ruby
# Probe maps to understand tile layout - find buildings by scanning layer 1

require_relative "rpgmaker_stubs"
module RPG; class Tileset; attr_accessor :id,:name,:tileset_name,:autotile_names,:panorama_name,:panorama_hue,:fog_name,:fog_hue,:fog_opacity,:fog_blend_type,:fog_zoom,:fog_sx,:fog_sy,:battleback_name,:passages,:priorities,:terrain_tags; end; end

DATA_DIR = File.join(__dir__, "..", "game_data", "Data")

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
  tiles[x + y * xsize + z * xsize * ysize]
end

# For each map, find contiguous non-zero regions on layer 1
def find_regions(tiles, xsize, ysize)
  visited = Array.new(xsize * ysize, false)
  regions = []

  (0...ysize).each do |y|
    (0...xsize).each do |x|
      next if visited[x + y * xsize]
      t = tile_at(tiles, xsize, ysize, x, y, 1)
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
          nt = tile_at(tiles, xsize, ysize, nx, ny, 1)
          next if nt == 0
          visited[nx + ny * xsize] = true
          queue << [nx, ny]
        end
      end

      # Compute bounding box
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

[1, 79, 95, 78, 380, 472].each do |map_num|
  map = load_map(map_num)
  xsize, ysize, zsize, tiles = get_tiles(map)
  puts "\n=== Map%03d (#{xsize}x#{ysize}, #{zsize} layers) ===" % map_num

  regions = find_regions(tiles, xsize, ysize)

  # Show top regions (likely buildings)
  regions.first(20).each_with_index do |r, i|
    puts "  Region #{i}: pos=(#{r[:min_x]},#{r[:min_y]}) size=#{r[:w]}x#{r[:h]} tiles=#{r[:tile_count]} fill=#{(r[:fill_ratio]*100).round(1)}%"
  end
end
