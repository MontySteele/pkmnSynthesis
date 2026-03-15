#!/usr/bin/env ruby
# render_map.rb — Render an RPG Maker XP map (.rxdata) to a PNG image.
#
# Usage:
#   ruby tools/render_map.rb <game_data_dir> <map_file> [output.png]
#   ruby tools/render_map.rb game_data game_data/Data/Map001.rxdata
#   ruby tools/render_map.rb game_data game_data/Data/Map001.rxdata my_map.png
#
# Requires: chunky_png gem (gem install chunky_png)

require_relative "rpgmaker_stubs"
require "chunky_png"

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

TILE_SIZE = 32
HALF_TILE = 16

# RPG Maker XP autotile sub-tile lookup table.
# Sourced from mkxp (src/autotiles.cpp) — maps each of the 48 autotile
# patterns to 4 sub-tile source rectangles (TL, TR, BL, BR) within a
# 96x128 autotile sheet.  Each entry is [x, y] of the 16x16 sub-tile.
AUTOTILE_RECTS = [
  # Pattern 0: fully surrounded
  [[32,64],[48,64],[32,80],[48,80]],
  [[64,0],[48,64],[32,80],[48,80]],
  [[32,64],[80,0],[32,80],[48,80]],
  [[64,0],[80,0],[32,80],[48,80]],
  [[32,64],[48,64],[32,80],[80,16]],
  [[64,0],[48,64],[32,80],[80,16]],
  [[32,64],[80,0],[32,80],[80,16]],
  [[64,0],[80,0],[32,80],[80,16]],
  [[32,64],[48,64],[64,16],[48,80]],
  [[64,0],[48,64],[64,16],[48,80]],
  [[32,64],[80,0],[64,16],[48,80]],
  [[64,0],[80,0],[64,16],[48,80]],
  [[32,64],[48,64],[64,16],[80,16]],
  [[64,0],[48,64],[64,16],[80,16]],
  [[32,64],[80,0],[64,16],[80,16]],
  [[64,0],[80,0],[64,16],[80,16]],
  # Pattern 16: left edge
  [[0,64],[16,64],[0,80],[16,80]],
  [[0,64],[80,0],[0,80],[16,80]],
  [[0,64],[16,64],[0,80],[80,16]],
  [[0,64],[80,0],[0,80],[80,16]],
  # Pattern 20: top edge
  [[32,32],[48,32],[32,48],[48,48]],
  [[32,32],[48,32],[32,48],[80,16]],
  [[32,32],[48,32],[64,16],[48,48]],
  [[32,32],[48,32],[64,16],[80,16]],
  # Pattern 24: right edge
  [[64,64],[80,64],[64,80],[80,80]],
  [[64,64],[80,64],[64,16],[80,80]],
  [[64,0],[80,64],[64,80],[80,80]],
  [[64,0],[80,64],[64,16],[80,80]],
  # Pattern 28: bottom edge
  [[32,96],[48,96],[32,112],[48,112]],
  [[64,0],[48,96],[32,112],[48,112]],
  [[32,96],[80,0],[32,112],[48,112]],
  [[64,0],[80,0],[32,112],[48,112]],
  # Pattern 32: left+right edges
  [[0,64],[80,64],[0,80],[80,80]],
  # Pattern 33: top+bottom edges
  [[32,32],[48,32],[32,112],[48,112]],
  # Pattern 34: top-left corner
  [[0,32],[16,32],[0,48],[16,48]],
  [[0,32],[16,32],[0,48],[80,16]],
  # Pattern 36: top-right corner
  [[64,32],[80,32],[64,48],[80,48]],
  [[64,32],[80,32],[64,16],[80,48]],
  # Pattern 38: bottom-right corner
  [[64,96],[80,96],[64,112],[80,112]],
  [[64,0],[80,96],[64,112],[80,112]],
  # Pattern 40: bottom-left corner
  [[0,96],[16,96],[0,112],[16,112]],
  [[0,96],[80,0],[0,112],[16,112]],
  # Pattern 42: left+right+top+bottom
  [[0,32],[80,32],[0,48],[80,48]],
  [[0,32],[16,32],[0,112],[16,112]],
  [[0,96],[80,96],[0,112],[80,112]],
  [[64,32],[80,32],[64,112],[80,112]],
  [[0,32],[80,32],[0,112],[80,112]],
  # Pattern 47: isolated
  [[0,0],[16,0],[0,16],[16,16]],
]

class MapRenderer
  def initialize(game_dir)
    @game_dir = game_dir
    data_dir = File.join(game_dir, "Data")
    @tilesets = Marshal.load(File.binread(File.join(data_dir, "Tilesets.rxdata")))
    @tileset_cache = {}
    @autotile_cache = {}
  end

  def render(map_file, output_file, opts = {})
    map = Marshal.load(File.binread(map_file))
    ts = @tilesets[map.tileset_id]
    abort "Unknown tileset ID #{map.tileset_id}" unless ts

    STDERR.puts "Rendering #{File.basename(map_file)}: #{map.width}x#{map.height}, tileset=#{ts.tileset_name}"

    tileset_img = load_tileset(ts.tileset_name)
    autotile_imgs = load_autotiles(ts.autotile_names || [])

    raw = map.data.instance_variable_get(:@raw)
    _ndim, xsize, ysize, zsize, _total = raw.unpack("V5")
    tiles = raw[20..-1].unpack("v*")

    canvas = ChunkyPNG::Image.new(xsize * TILE_SIZE, ysize * TILE_SIZE, ChunkyPNG::Color::BLACK)

    # Render tile layers
    (0...zsize).each do |z|
      (0...ysize).each do |y|
        (0...xsize).each do |x|
          tile_id = tiles[x + y * xsize + z * xsize * ysize]
          next if tile_id == 0

          dest_x = x * TILE_SIZE
          dest_y = y * TILE_SIZE

          if tile_id >= 384
            draw_regular_tile(canvas, tileset_img, tile_id, dest_x, dest_y)
          elsif tile_id >= 48
            draw_autotile(canvas, autotile_imgs, tile_id, dest_x, dest_y)
          end
        end
      end
    end

    # Overlay event markers if requested
    unless opts[:no_events]
      draw_events(canvas, map)
    end

    canvas.save(output_file)
    STDERR.puts "Saved #{output_file} (#{canvas.width}x#{canvas.height})"
    output_file
  end

  private

  def load_tileset(name)
    return @tileset_cache[name] if @tileset_cache[name]
    path = find_graphic("Tilesets", name)
    abort "Tileset not found: #{name}" unless path
    @tileset_cache[name] = ChunkyPNG::Image.from_file(path)
  end

  def load_autotiles(names)
    imgs = {}
    names.each_with_index do |name, i|
      next if name.nil? || name.empty?
      cache_key = name
      if @autotile_cache[cache_key]
        imgs[i] = @autotile_cache[cache_key]
        next
      end
      path = find_graphic("Autotiles", name)
      if path
        imgs[i] = ChunkyPNG::Image.from_file(path)
        @autotile_cache[cache_key] = imgs[i]
      end
    end
    imgs
  end

  def find_graphic(subdir, name)
    base = File.join(@game_dir, "Graphics", subdir)
    %w[.png .PNG .jpg .JPG .bmp .BMP].each do |ext|
      path = File.join(base, "#{name}#{ext}")
      return path if File.exist?(path)
    end
    # Try case-insensitive glob
    Dir.glob(File.join(base, "#{name}.*")).first
  end

  def draw_regular_tile(canvas, tileset_img, tile_id, dest_x, dest_y)
    idx = tile_id - 384
    src_x = (idx % 8) * TILE_SIZE
    src_y = (idx / 8) * TILE_SIZE
    return if src_y + TILE_SIZE > tileset_img.height

    blit_tile(canvas, tileset_img, src_x, src_y, TILE_SIZE, TILE_SIZE, dest_x, dest_y)
  end

  def draw_autotile(canvas, autotile_imgs, tile_id, dest_x, dest_y)
    at_index = (tile_id - 48) / 48  # which autotile (0-6)
    sub_index = (tile_id - 48) % 48  # which pattern (0-47)

    at_img = autotile_imgs[at_index]
    return unless at_img

    # For single-tile autotiles (32x32 or 128x32), just draw the tile directly
    if at_img.height <= 32
      # Animated single tile: each frame is 32x32, just use first frame
      blit_tile(canvas, at_img, 0, 0, [TILE_SIZE, at_img.width].min, [TILE_SIZE, at_img.height].min, dest_x, dest_y)
      return
    end

    # For full autotiles (96x128 base, possibly animated with wider images):
    # Each animation frame is 96x128; use first frame only for static render
    rects = AUTOTILE_RECTS[sub_index]
    return unless rects

    # Sub-tile positions on the destination: TL, TR, BL, BR
    dest_positions = [[0, 0], [HALF_TILE, 0], [0, HALF_TILE], [HALF_TILE, HALF_TILE]]

    rects.each_with_index do |src_pos, qi|
      sx, sy = src_pos
      dx = dest_x + dest_positions[qi][0]
      dy = dest_y + dest_positions[qi][1]

      # Bounds check against autotile image
      next if sx + HALF_TILE > at_img.width || sy + HALF_TILE > at_img.height

      blit_tile(canvas, at_img, sx, sy, HALF_TILE, HALF_TILE, dx, dy)
    end
  end

  def blit_tile(canvas, src_img, sx, sy, w, h, dx, dy)
    (0...h).each do |py|
      src_row = sy + py
      dst_row = dy + py
      next if src_row >= src_img.height || dst_row >= canvas.height || dst_row < 0

      (0...w).each do |px|
        src_col = sx + px
        dst_col = dx + px
        next if src_col >= src_img.width || dst_col >= canvas.width || dst_col < 0

        pixel = src_img[src_col, src_row]
        alpha = ChunkyPNG::Color.a(pixel)
        next if alpha == 0

        if alpha == 255
          canvas[dst_col, dst_row] = pixel
        else
          canvas[dst_col, dst_row] = ChunkyPNG::Color.compose(pixel, canvas[dst_col, dst_row])
        end
      end
    end
  end

  def draw_events(canvas, map)
    map.events.each do |_id, event|
      # Determine event type from first page's commands
      type = classify_event(event)
      color = case type
              when :trainer then ChunkyPNG::Color.rgb(255, 50, 50)    # red
              when :npc     then ChunkyPNG::Color.rgb(50, 150, 255)   # blue
              when :warp    then ChunkyPNG::Color.rgb(50, 255, 50)    # green
              when :item    then ChunkyPNG::Color.rgb(255, 255, 50)   # yellow
              when :sign    then ChunkyPNG::Color.rgb(200, 150, 255)  # purple
              else ChunkyPNG::Color.rgb(180, 180, 180)                # gray
              end

      cx = event.x * TILE_SIZE + TILE_SIZE / 2
      cy = event.y * TILE_SIZE + TILE_SIZE / 2

      # Draw a small circle marker
      (-3..3).each do |ddy|
        (-3..3).each do |ddx|
          if ddx * ddx + ddy * ddy <= 9
            px = cx + ddx
            py = cy + ddy
            if px >= 0 && px < canvas.width && py >= 0 && py < canvas.height
              canvas[px, py] = color
            end
          end
        end
      end
    end
  end

  def classify_event(event)
    return :npc if event.pages.nil? || event.pages.empty?

    # Check first page's command list for clues
    cmds = event.pages[0].list
    return :npc unless cmds

    cmds.each do |cmd|
      next unless cmd.parameters
      params_str = cmd.parameters.map(&:to_s).join(" ")

      case cmd.code
      when 355, 655
        return :trainer if params_str =~ /pbTrainerBattle/i
        return :item if params_str =~ /pbItemBall|pbReceiveItem/i
      when 201 # Transfer Player
        return :warp
      when 101, 401
        # Check for sign-like events (single text, no graphic typically)
        if event.pages[0].graphic &&
           (event.pages[0].graphic.character_name.nil? || event.pages[0].graphic.character_name.empty?) &&
           (event.pages[0].graphic.tile_id || 0) > 0
          return :sign
        end
      end
    end

    :npc
  end
end

# ── CLI ──────────────────────────────────────────────────────────────────────

if __FILE__ == $0
  if ARGV.length < 2
    STDERR.puts "Usage: ruby tools/render_map.rb <game_data_dir> <map_file.rxdata> [output.png]"
    STDERR.puts ""
    STDERR.puts "Options:"
    STDERR.puts "  --no-events   Don't draw event markers"
    STDERR.puts ""
    STDERR.puts "Examples:"
    STDERR.puts "  ruby tools/render_map.rb game_data game_data/Data/Map001.rxdata"
    STDERR.puts "  ruby tools/render_map.rb game_data game_data/Data/Map001.rxdata pallet.png"
    exit 1
  end

  game_dir = ARGV[0]
  map_file = ARGV[1]
  output = ARGV[2] || map_file.sub(/\.rxdata$/i, ".png")
  no_events = ARGV.include?("--no-events")

  renderer = MapRenderer.new(game_dir)
  renderer.render(map_file, output, no_events: no_events)
end
