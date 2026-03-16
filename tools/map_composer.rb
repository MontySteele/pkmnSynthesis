#!/usr/bin/env ruby
# map_composer.rb -- Create RPG Maker XP maps by composing tile stamps on a canvas.
#
# Usage:
#   ruby tools/map_composer.rb <game_data_dir> <composition_spec.json> [--dry-run]
#
# The composition spec JSON defines the map canvas, base fill, stamps, paths,
# area fills, and events.  Stamps are loaded from tools/stamps/*.json.
#
# Tile vocabulary maps semantic names (like "grass", "water") to numeric tile IDs
# appropriate for the target tileset.

require_relative "rpgmaker_stubs"
require "json"

# RPG::Tileset needs to be loadable for tileset data inspection
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

class MapComposer
  # ---- Tile vocabulary -------------------------------------------------------
  # Maps semantic tile names to [layer, tile_id] pairs.
  # These are based on analysis of maps using tileset 23 (Outdoor).
  #
  # RPG Maker XP tile ID layout:
  #   0-383:     Autotiles (8 autotiles x 48 patterns each)
  #   384+:      Regular tiles from the tileset graphic
  #              The tileset graphic is 8 tiles wide (256px / 32px).
  #              Row r, column c -> tile_id = 384 + r * 8 + c
  #
  # Autotile base IDs: autotile_index * 48
  #   Autotile 0: 0-47   (usually blank/animating water)
  #   Autotile 1: 48-95
  #   Autotile 2: 96-143
  #   Autotile 3: 144-191
  #   Autotile 4: 192-239
  #   Autotile 5: 240-287
  #   Autotile 6: 288-335
  #   Autotile 7: 336-383

  TILE_VOCAB = {
    # ---- Layer 0 (ground) tiles ----
    # Grass: the base outdoor ground tile (regular tile from tileset)
    "grass"           => { layer: 0, tile_id: 555 },
    "grass_alt"       => { layer: 0, tile_id: 560 },

    # Dirt / road (common path tile from Pallet Town analysis)
    "dirt_path"       => { layer: 0, tile_id: 401 },
    "dirt"            => { layer: 0, tile_id: 401 },
    "road"            => { layer: 0, tile_id: 401 },

    # Sand
    "sand"            => { layer: 0, tile_id: 544 },

    # Cave / indoor floor
    "cave_floor"      => { layer: 0, tile_id: 386 },

    # Water autotile (autotile index 5 -> base 240, pattern 0 = fully surrounded)
    "water"           => { layer: 0, tile_id: 240, autotile: true, autotile_index: 5 },

    # Tall grass for encounters (autotile index 1 -> base 48)
    "tall_grass"      => { layer: 0, tile_id: 48, autotile: true, autotile_index: 1 },

    # Ledge tiles
    "ledge_down"      => { layer: 0, tile_id: 9884 },

    # ---- Layer 1 (objects) tiles ----
    # Trees (placed on layer 1 over ground)
    "tree"            => { layer: 1, tile_id: 409 },
    "tree_top"        => { layer: 2, tile_id: 8987 },
    "tree_base"       => { layer: 1, tile_id: 409 },

    # Fence
    "fence_h"         => { layer: 1, tile_id: 958 },
    "fence"           => { layer: 1, tile_id: 958 },

    # Flowers
    "flowers"         => { layer: 1, tile_id: 1145 },
    "flowers_red"     => { layer: 1, tile_id: 1145 },

    # Signs / small objects
    "sign"            => { layer: 1, tile_id: 1202 },

    # ---- Special: empty ----
    "empty"           => { layer: 0, tile_id: 0 },
    "none"            => { layer: 0, tile_id: 0 },
  }

  # Autotile pattern constants for path drawing
  # These are the 48 patterns within each autotile group.
  # Key patterns for path/fill edges:
  AUTOTILE_FULL         = 0   # Fully surrounded (interior)
  AUTOTILE_ISOLATED     = 46  # No neighbors (standalone)
  AUTOTILE_SINGLE_H     = 42  # Horizontal single-row strip
  AUTOTILE_SINGLE_V     = 44  # Vertical single-column strip

  def initialize(game_dir)
    @game_dir = game_dir
    @data_dir = File.join(game_dir, "Data")
    @stamps_dir = File.join(File.dirname(__FILE__), "stamps")
    @stamp_cache = {}
  end

  def compose(spec, dry_run: false)
    map_id     = spec["map_id"]     || abort("spec must include 'map_id'")
    width      = spec["width"]      || 20
    height     = spec["height"]     || 15
    tileset_id = spec["tileset_id"] || 23

    # Load any custom vocabulary overrides from spec
    custom_vocab = spec["tile_vocab"] || {}

    puts "[COMPOSE] Creating #{width}x#{height} map (ID #{map_id}, tileset #{tileset_id})"

    # Build the map object
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
    map.data = create_table(width, height, 3)

    # 1) Base fill
    if spec["base_fill"]
      tile_info = resolve_tile(spec["base_fill"], custom_vocab)
      puts "  [FILL] Base fill with '#{spec["base_fill"]}' (tile #{tile_info[:tile_id]}, layer #{tile_info[:layer]})"
      fill_layer(map, tile_info[:layer], tile_info[:tile_id])
    end

    # 2) Area fills
    if spec["fills"]
      spec["fills"].each do |fill|
        apply_fill(map, fill, custom_vocab)
      end
    end

    # 3) Paths
    if spec["paths"]
      spec["paths"].each do |path|
        apply_path(map, path, custom_vocab)
      end
    end

    # 4) Stamps
    if spec["stamps"]
      spec["stamps"].each do |stamp_spec|
        apply_stamp(map, stamp_spec)
      end
    end

    # 5) Raw tile placements (for fine-tuning)
    if spec["tiles"]
      spec["tiles"].each do |t|
        set_tile(map, t["x"], t["y"], t["layer"] || 0, t["tile_id"])
      end
    end

    # 6) Audio
    if spec["bgm"]
      map.bgm = make_audio(spec["bgm"])
      map.autoplay_bgm = true
    end
    if spec["bgs"]
      map.bgs = make_audio(spec["bgs"])
      map.autoplay_bgs = true
    end

    # 7) Encounters
    map.encounter_list = spec["encounters"] if spec["encounters"]
    map.encounter_step = spec["encounter_step"] if spec["encounter_step"]

    # 8) Events
    if spec["events"]
      apply_events(map, spec["events"])
    end

    # Write output
    target_file = File.join(@data_dir, "Map%03d.rxdata" % map_id)

    if dry_run
      puts "[DRY RUN] Would write #{target_file}"
      puts "  Map: #{map.width}x#{map.height}, tileset=#{map.tileset_id}"
      puts "  Events: #{map.events.length}"
    else
      File.binwrite(target_file, Marshal.dump(map))
      puts "[OK] Wrote #{target_file} (#{map.width}x#{map.height}, #{map.events.length} events)"
    end

    # Register in MapInfos
    if spec["map_info"]
      register_map_info(map_id, spec["map_info"], dry_run: dry_run)
    end

    map
  end

  private

  # ---- Tile vocabulary resolution -------------------------------------------

  def resolve_tile(name, custom_vocab = {})
    # Check custom vocab first, then built-in
    if custom_vocab[name]
      entry = custom_vocab[name]
      # Custom vocab can be just an integer (tile_id) or a hash
      if entry.is_a?(Integer)
        return { layer: 0, tile_id: entry }
      else
        return { layer: entry["layer"] || 0, tile_id: entry["tile_id"] }
      end
    end

    info = TILE_VOCAB[name]
    abort "Unknown tile name: '#{name}'. Known tiles: #{TILE_VOCAB.keys.join(', ')}" unless info
    info.dup
  end

  # ---- Table operations -----------------------------------------------------

  def create_table(width, height, depth)
    total = width * height * depth
    raw = [depth, width, height, depth, total].pack("V5")
    raw += ([0] * total).pack("v*")
    t = Table.allocate
    t.instance_variable_set(:@raw, raw)
    t
  end

  def get_tile(map, x, y, z)
    raw = map.data.instance_variable_get(:@raw)
    _ndim, xsize, ysize, _zsize, _total = raw.unpack("V5")
    return 0 if x < 0 || y < 0 || x >= xsize || y >= ysize
    tiles = raw[20..-1].unpack("v*")
    tiles[x + y * xsize + z * xsize * ysize]
  end

  def set_tile(map, x, y, z, tile_id)
    raw = map.data.instance_variable_get(:@raw)
    header = raw[0, 20]
    _ndim, xsize, ysize, _zsize, _total = header.unpack("V5")
    return if x < 0 || y < 0 || x >= xsize || y >= ysize
    tiles = raw[20..-1].unpack("v*")
    idx = x + y * xsize + z * xsize * ysize
    tiles[idx] = tile_id
    map.data.instance_variable_set(:@raw, header + tiles.pack("v*"))
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
    map.data.instance_variable_set(:@raw, header + tiles.pack("v*"))
  end

  # ---- Area fills -----------------------------------------------------------

  def apply_fill(map, fill, custom_vocab)
    tile_info = resolve_tile(fill["tile"], custom_vocab)
    layer = fill["layer"] || tile_info[:layer]
    tile_id = tile_info[:tile_id]
    is_autotile = tile_info[:autotile]

    case fill["type"]
    when "rect"
      x0 = fill["x"] || 0
      y0 = fill["y"] || 0
      w  = fill["w"] || 1
      h  = fill["h"] || 1
      puts "  [FILL] Rect #{w}x#{h} at (#{x0},#{y0}) with '#{fill["tile"]}'"

      if is_autotile
        fill_rect_autotile(map, x0, y0, w, h, layer, tile_info)
      else
        (y0...(y0 + h)).each do |y|
          (x0...(x0 + w)).each do |x|
            set_tile(map, x, y, layer, tile_id)
          end
        end
      end

    when "border"
      # Fill only the border of a rectangle
      x0 = fill["x"] || 0
      y0 = fill["y"] || 0
      w  = fill["w"] || 1
      h  = fill["h"] || 1
      puts "  [FILL] Border #{w}x#{h} at (#{x0},#{y0}) with '#{fill["tile"]}'"
      (y0...(y0 + h)).each do |y|
        (x0...(x0 + w)).each do |x|
          if y == y0 || y == y0 + h - 1 || x == x0 || x == x0 + w - 1
            set_tile(map, x, y, layer, tile_id)
          end
        end
      end

    else
      # Default to rect
      apply_fill(map, fill.merge("type" => "rect"), custom_vocab)
    end
  end

  # Fill a rectangular area with autotile, computing edge patterns.
  # RPG Maker XP autotile patterns encode which neighbors are the same tile.
  # For a filled rectangle, we compute the pattern based on position within
  # the rectangle: corners, edges, and interior.
  def fill_rect_autotile(map, x0, y0, w, h, layer, tile_info)
    base_id = tile_info[:autotile_index] * 48

    (0...h).each do |dy|
      (0...w).each do |dx|
        x = x0 + dx
        y = y0 + dy

        # Determine which edges this cell is on
        at_left   = (dx == 0)
        at_right  = (dx == w - 1)
        at_top    = (dy == 0)
        at_bottom = (dy == h - 1)

        # Map edge configuration to autotile pattern index
        pattern = compute_autotile_pattern(at_left, at_right, at_top, at_bottom, w, h)
        set_tile(map, x, y, layer, base_id + pattern)
      end
    end
  end

  # Compute a simplified autotile pattern based on edge position.
  # This maps the 4 edge booleans to one of the 48 RPG Maker XP autotile patterns.
  def compute_autotile_pattern(at_left, at_right, at_top, at_bottom, w, h)
    # Single tile
    return 46 if w == 1 && h == 1

    # Single row
    if h == 1
      return 42 if !at_left && !at_right  # middle of horizontal strip
      return 40 if at_left && !at_right    # left end
      return 41 if !at_left && at_right    # right end
      return 43                            # single tile in 1xN
    end

    # Single column
    if w == 1
      return 44 if !at_top && !at_bottom   # middle of vertical strip
      return 32 if at_top && !at_bottom     # top end
      return 38 if !at_top && at_bottom     # bottom end
      return 46                             # single
    end

    # 2D rectangle
    if at_top && at_left
      return 32     # top-left corner
    elsif at_top && at_right
      return 33     # top-right corner
    elsif at_bottom && at_left
      return 40     # bottom-left corner
    elsif at_bottom && at_right
      return 41     # bottom-right corner
    elsif at_top
      return 16     # top edge
    elsif at_bottom
      return 24     # bottom edge
    elsif at_left
      return 34     # left edge
    elsif at_right
      return 35     # right edge
    else
      return 0      # interior (fully surrounded)
    end
  end

  # ---- Path drawing ---------------------------------------------------------

  def apply_path(map, path, custom_vocab)
    tile_info = resolve_tile(path["tile"], custom_vocab)
    layer = path["layer"] || tile_info[:layer]
    tile_id = tile_info[:tile_id]
    path_width = path["width"] || 1

    case path["type"]
    when "horizontal"
      x1 = path["x1"] || 0
      x2 = path["x2"] || (map.width - 1)
      y  = path["y"]  || 0
      puts "  [PATH] Horizontal from x=#{x1} to x=#{x2} at y=#{y}, width=#{path_width}"
      (x1..x2).each do |x|
        (0...path_width).each do |dy|
          set_tile(map, x, y + dy, layer, tile_id)
        end
      end

    when "vertical"
      x  = path["x"]  || 0
      y1 = path["y1"] || 0
      y2 = path["y2"] || (map.height - 1)
      puts "  [PATH] Vertical from y=#{y1} to y=#{y2} at x=#{x}, width=#{path_width}"
      (y1..y2).each do |y|
        (0...path_width).each do |dx|
          set_tile(map, x + dx, y, layer, tile_id)
        end
      end

    when "line"
      # Bresenham-style line between two points
      x1 = path["x1"] || 0
      y1 = path["y1"] || 0
      x2 = path["x2"] || 0
      y2 = path["y2"] || 0
      puts "  [PATH] Line from (#{x1},#{y1}) to (#{x2},#{y2})"
      draw_line(map, x1, y1, x2, y2, layer, tile_id, path_width)
    end
  end

  def draw_line(map, x1, y1, x2, y2, layer, tile_id, width)
    dx = (x2 - x1).abs
    dy = -(y2 - y1).abs
    sx = x1 < x2 ? 1 : -1
    sy = y1 < y2 ? 1 : -1
    err = dx + dy

    x, y = x1, y1
    loop do
      # Place tile with width
      half = width / 2
      (-half..half).each do |d|
        set_tile(map, x + d, y, layer, tile_id) if dx >= dy.abs
        set_tile(map, x, y + d, layer, tile_id) if dy.abs >= dx
      end

      break if x == x2 && y == y2
      e2 = 2 * err
      if e2 >= dy
        err += dy
        x += sx
      end
      if e2 <= dx
        err += dx
        y += sy
      end
    end
  end

  # ---- Stamp placement ------------------------------------------------------

  def apply_stamp(map, stamp_spec)
    stamp_name = stamp_spec["stamp"]
    ox = stamp_spec["x"] || 0
    oy = stamp_spec["y"] || 0
    flip_h = stamp_spec["flip_h"] || false

    stamp = load_stamp(stamp_name)
    abort "Stamp '#{stamp_name}' not found in #{@stamps_dir}" unless stamp

    sw = stamp["width"]
    sh = stamp["height"]
    puts "  [STAMP] '#{stamp_name}' #{sw}x#{sh} at (#{ox},#{oy})"

    # Place tiles from stamp onto the map canvas
    # Support both formats:
    #   Format A (composer): "layers" => [{"layer"=>0, "tiles"=>[{"x"=>0,"y"=>0,"tile_id"=>N},...]}]
    #   Format B (extractor): "tiles" => {"layer0"=>[[row of ids],...], "layer1"=>...}
    if stamp["layers"]
      stamp["layers"].each do |layer_spec|
        z = layer_spec["layer"] || 0
        tiles = layer_spec["tiles"]
        tiles.each do |t|
          tx = flip_h ? (sw - 1 - t["x"]) : t["x"]
          mx = ox + tx
          my = oy + t["y"]
          set_tile(map, mx, my, z, t["tile_id"]) if t["tile_id"] && t["tile_id"] != 0
        end
      end
    elsif stamp["tiles"]
      3.times do |z|
        key = "layer#{z}"
        rows = stamp["tiles"][key]
        next unless rows
        rows.each_with_index do |row, dy|
          row.each_with_index do |tid, dx|
            next if tid == 0
            tx = flip_h ? (sw - 1 - dx) : dx
            mx = ox + tx
            my = oy + dy
            set_tile(map, mx, my, z, tid)
          end
        end
      end
    end
  end

  def load_stamp(name)
    return @stamp_cache[name] if @stamp_cache.key?(name)

    path = File.join(@stamps_dir, "#{name}.json")
    unless File.exist?(path)
      @stamp_cache[name] = nil
      return nil
    end

    stamp = JSON.parse(File.read(path))
    @stamp_cache[name] = stamp
    stamp
  end

  # ---- Event creation (reuses create_map.rb patterns) -----------------------

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
    page.move_type = spec["move_type"] || 0
    page.move_speed = spec["move_speed"] || 3
    page.move_frequency = spec["move_frequency"] || 3
    page.move_route = build_move_route(spec["move_route"])
    page.walk_anime = spec.fetch("walk_anime", true)
    page.step_anime = spec.fetch("step_anime", false)
    page.direction_fix = spec.fetch("direction_fix", false)
    page.through = spec.fetch("through", false)
    page.always_on_top = spec.fetch("always_on_top", false)
    page.trigger = spec["trigger"] || 0
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
    g.direction = spec["direction"] || 2
    g.pattern = spec["pattern"] || 0
    g.opacity = spec["opacity"] || 255
    g.blend_type = spec["blend_type"] || 0
    g
  end

  def build_move_route(_spec)
    mr = RPG::MoveRoute.new
    mr.repeat = true
    mr.skippable = false
    mc = RPG::MoveCommand.new
    mc.code = 0
    mc.parameters = []
    mr.list = [mc]
    mr
  end

  def build_commands(specs)
    cmds = []
    specs.each do |spec|
      case spec["type"]
      when "text"
        lines = spec["lines"]
        indent = spec["indent"] || 0
        cmds << make_cmd(101, indent, [lines[0]]) if lines && !lines.empty?
        (lines[1..] || []).each { |l| cmds << make_cmd(401, indent, [l]) }
      when "script"
        lines = spec["lines"]
        indent = spec["indent"] || 0
        cmds << make_cmd(355, indent, [lines[0]]) if lines && !lines.empty?
        (lines[1..] || []).each { |l| cmds << make_cmd(655, indent, [l]) }
      when "transfer"
        cmds << make_cmd(201, spec["indent"] || 0,
          [0, spec["map_id"], spec["x"], spec["y"], spec["direction"] || 0, spec.fetch("fade", 1)])
      when "switch"
        cmds << make_cmd(121, spec["indent"] || 0,
          [spec["id"], spec["id"], spec["value"] == "ON" ? 0 : 1])
      when "self_switch"
        cmds << make_cmd(123, spec["indent"] || 0,
          [spec["ch"] || "A", spec["value"] == "ON" ? 0 : 1])
      when "battle"
        trainer_type = spec["trainer_type"] || "POKEMONTRAINER"
        trainer_name = spec["trainer_name"]
        trainer_id = spec["trainer_id"] || 0
        line = "pbTrainerBattle(:#{trainer_type},\"#{trainer_name}\",#{trainer_id})"
        cmds << make_cmd(355, spec["indent"] || 0, [line])
      when "item"
        line = "pbItemBall(:#{spec["item"]})"
        cmds << make_cmd(355, spec["indent"] || 0, [line])
      when "raw"
        cmds << make_cmd(spec["code"], spec["indent"] || 0, spec["parameters"] || [])
      end
    end
    cmds << make_cmd(0, 0, []) if cmds.empty? || cmds.last.code != 0
    cmds
  end

  def make_cmd(code, indent, parameters)
    cmd = RPG::EventCommand.new
    cmd.code = code
    cmd.indent = indent
    cmd.parameters = parameters
    cmd
  end

  # ---- Audio ----------------------------------------------------------------

  def make_audio(spec)
    a = RPG::AudioFile.new
    a.name = spec["name"] || ""
    a.volume = spec["volume"] || 100
    a.pitch = spec["pitch"] || 100
    a
  end

  # ---- MapInfos registration ------------------------------------------------

  def register_map_info(map_id, info_spec, dry_run: false)
    infos_file = File.join(@data_dir, "MapInfos.rxdata")
    unless File.exist?(infos_file)
      puts "[SKIP] MapInfos.rxdata not found, skipping registration"
      return
    end

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

# ---- CLI --------------------------------------------------------------------

if __FILE__ == $0
  if ARGV.length < 2
    STDERR.puts "Usage: ruby tools/map_composer.rb <game_data_dir> <composition_spec.json> [--dry-run]"
    STDERR.puts ""
    STDERR.puts "Creates RPG Maker XP maps by composing tile stamps, paths, and fills"
    STDERR.puts "on a canvas.  Reads stamp definitions from tools/stamps/*.json."
    STDERR.puts ""
    STDERR.puts "See docs for composition spec format."
    exit 1
  end

  game_dir = ARGV[0]
  spec_file = ARGV[1]
  dry_run = ARGV.include?("--dry-run")

  spec = JSON.parse(File.read(spec_file))
  composer = MapComposer.new(game_dir)
  composer.compose(spec, dry_run: dry_run)
end
