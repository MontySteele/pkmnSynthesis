#!/usr/bin/env ruby
# validate_composition.rb — Post-composition validation for maps built by map_composer.
#
# Usage:
#   ruby tools/validate_composition.rb <game_data_dir> <map_file.rxdata> <composition_spec.json>
#
# Three checks:
#   1. Stamp integrity — every non-zero tile from each stamp landed correctly
#   2. Pathfinding — all exits/warps are reachable from each other
#   3. Edge boundaries — map edges are bounded by impassable tiles (trees, water, buildings)

require_relative "rpgmaker_stubs"
require "json"
require "set"

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

class CompositionValidator
  def initialize(game_dir)
    @game_dir = game_dir
    @data_dir = File.join(game_dir, "Data")
    @stamps_dir = File.join(File.dirname(__FILE__), "stamps")
    @errors = []
    @warnings = []
    @info = []
  end

  def validate(map_file, spec_file)
    @map_file = map_file
    @map = Marshal.load(File.binread(map_file))
    @spec = JSON.parse(File.read(spec_file))

    # Extract tile data once
    raw = @map.data.instance_variable_get(:@raw)
    _ndim, @xsize, @ysize, @zsize, _total = raw.unpack("V5")
    @tiles = raw[20..-1].unpack("v*")

    # Load passability data from tileset
    load_passages

    puts "=== Composition Validation: #{File.basename(map_file)} ==="
    puts "    Map: #{@xsize}x#{@ysize}, tileset #{@map.tileset_id}"
    puts ""

    check_stamp_integrity
    puts ""
    check_pathfinding
    puts ""
    check_edge_boundaries
    puts ""

    report
  end

  private

  # ── Tile access ──────────────────────────────────────────────────────────────

  def get_tile(x, y, z)
    return 0 if x < 0 || y < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @tiles[x + y * @xsize + z * @xsize * @ysize]
  end

  # ── Passability ─────────────────────────────────────────────────────────────

  def load_passages
    @passages = nil
    tilesets_file = File.join(@data_dir, "Tilesets.rxdata")
    return unless File.exist?(tilesets_file)

    begin
      tilesets = Marshal.load(File.binread(tilesets_file))
      ts = tilesets[@map.tileset_id]
      if ts && ts.passages
        raw = ts.passages.instance_variable_get(:@raw)
        _ndim, size, *_ = raw.unpack("V5")
        @passages = raw[20..-1].unpack("v*")
        @passage_size = size
      end
    rescue => e
      warning "Could not load tileset passages: #{e.message}"
    end
  end

  # Check if a tile_id is passable (can walk on it).
  # RPG Maker XP passages: lower 4 bits = directional blocking.
  # 0 = fully passable, 0x0F = fully blocked.
  # Priorities > 0 with passages == 0 are still passable (decorative overlays).
  def tile_passable?(tile_id)
    return true unless @passages  # assume passable if no data
    return true if tile_id == 0   # empty tile = passable

    idx = tile_id
    return true if idx >= @passage_size  # out of range = assume passable
    (@passages[idx] & 0x0F) == 0
  end

  # Check if a map cell is walkable (all layers considered).
  # A cell is blocked if ANY layer has a blocking tile on it.
  def cell_walkable?(x, y)
    (0...@zsize).each do |z|
      tid = get_tile(x, y, z)
      next if tid == 0
      return false unless tile_passable?(tid)
    end
    true
  end

  # Check if a tile_id is an "edge-worthy" blocker (tree, water, building, rock).
  # We check: is it non-zero AND non-passable?
  # Also treat layer1/layer2 non-zero tiles as blockers (buildings, trees).
  def tile_is_boundary?(x, y)
    # If any layer has a blocking tile, it's bounded
    has_blocker = false
    (0...@zsize).each do |z|
      tid = get_tile(x, y, z)
      next if tid == 0
      unless tile_passable?(tid)
        has_blocker = true
        break
      end
      # Layer 1/2 non-zero non-ground tiles usually indicate structures
      if z > 0 && tid != 0
        has_blocker = true
        break
      end
    end
    has_blocker
  end

  # ── Check 1: Stamp Integrity ────────────────────────────────────────────────

  def check_stamp_integrity
    puts "  [CHECK 1] Stamp Integrity"
    stamps = @spec["stamps"] || []

    if stamps.empty?
      info "  No stamps in spec."
      return
    end

    stamps.each do |stamp_spec|
      name = stamp_spec["stamp"]
      ox = stamp_spec["x"] || 0
      oy = stamp_spec["y"] || 0
      flip_h = stamp_spec["flip_h"] || false

      stamp_file = File.join(@stamps_dir, "#{name}.json")
      unless File.exist?(stamp_file)
        error "Stamp '#{name}' file not found: #{stamp_file}"
        next
      end

      stamp = JSON.parse(File.read(stamp_file))
      sw = stamp["width"]
      sh = stamp["height"]

      # Check bounds
      if ox + sw > @xsize || oy + sh > @ysize
        error "Stamp '#{name}' at (#{ox},#{oy}) extends beyond map bounds (#{sw}x#{sh} stamp, #{@xsize}x#{@ysize} map)"
      end
      if ox < 0 || oy < 0
        error "Stamp '#{name}' at (#{ox},#{oy}) has negative coordinates"
        next
      end

      # Compare tiles
      mismatches = []
      total_tiles = 0
      matched_tiles = 0

      if stamp["tiles"]
        3.times do |z|
          key = "layer#{z}"
          rows = stamp["tiles"][key]
          next unless rows
          rows.each_with_index do |row, dy|
            row.each_with_index do |expected_tid, dx|
              next if expected_tid == 0  # skip empty stamp tiles
              total_tiles += 1

              tx = flip_h ? (sw - 1 - dx) : dx
              mx = ox + tx
              my = oy + dy

              next if mx >= @xsize || my >= @ysize  # out of bounds, already reported

              actual_tid = get_tile(mx, my, z)
              if actual_tid == expected_tid
                matched_tiles += 1
              else
                mismatches << {
                  stamp_pos: "(#{dx},#{dy})",
                  map_pos: "(#{mx},#{my})",
                  layer: z,
                  expected: expected_tid,
                  actual: actual_tid
                }
              end
            end
          end
        end
      end

      if mismatches.empty?
        info "  [OK] '#{name}' at (#{ox},#{oy}): #{matched_tiles}/#{total_tiles} tiles correct"
      else
        pct = total_tiles > 0 ? (matched_tiles * 100.0 / total_tiles).round(1) : 0
        error "Stamp '#{name}' at (#{ox},#{oy}): #{mismatches.length}/#{total_tiles} tiles WRONG (#{pct}% correct)"

        # Show first few mismatches as detail
        mismatches.first(5).each do |m|
          error "  -> layer#{m[:layer]} map#{m[:map_pos]}: expected tile #{m[:expected]}, got #{m[:actual]}"
        end
        if mismatches.length > 5
          error "  -> ... and #{mismatches.length - 5} more mismatches"
        end

        # Categorize the problem
        overwritten_by_later = mismatches.count { |m| m[:actual] != 0 }
        zeroed_out = mismatches.count { |m| m[:actual] == 0 }
        if overwritten_by_later > mismatches.length / 2
          warning "  -> Most mismatches show different non-zero tiles — likely overwritten by a later stamp or path"
        end
        if zeroed_out > mismatches.length / 2
          warning "  -> Most mismatches show tile 0 — stamp tiles may not have been placed"
        end
      end
    end
  end

  # ── Check 2: Pathfinding ────────────────────────────────────────────────────

  def check_pathfinding
    puts "  [CHECK 2] Exit Reachability (Pathfinding)"

    # Find all exit/warp events
    exits = find_exits
    if exits.length < 2
      info "  Only #{exits.length} exit(s) found — skipping pathfinding."
      return
    end

    puts "    Found #{exits.length} exits: #{exits.map { |e| "#{e[:name]}(#{e[:x]},#{e[:y]})" }.join(', ')}"

    # BFS from first exit to find all reachable cells
    start = exits.first
    reachable = bfs_reachable(start[:x], start[:y])

    # Check each other exit
    unreachable_exits = []
    exits[1..].each do |ex|
      # Check the exit tile and adjacent tiles (exits are often on impassable edge tiles)
      found = false
      check_positions = [
        [ex[:x], ex[:y]],
        [ex[:x], ex[:y] - 1], [ex[:x], ex[:y] + 1],
        [ex[:x] - 1, ex[:y]], [ex[:x] + 1, ex[:y]],
      ]
      check_positions.each do |cx, cy|
        if reachable.include?([cx, cy])
          found = true
          break
        end
      end

      if found
        info "  [OK] #{start[:name]} -> #{ex[:name]}: reachable"
      else
        # Before flagging, check if this is a "split map" by doing BFS from this exit
        their_reach = bfs_reachable(ex[:x], ex[:y])
        their_exit_count = exits.count do |other|
          check_positions_other = [
            [other[:x], other[:y]],
            [other[:x], other[:y] - 1], [other[:x], other[:y] + 1],
            [other[:x] - 1, other[:y]], [other[:x] + 1, other[:y]],
          ]
          check_positions_other.any? { |cx, cy| their_reach.include?([cx, cy]) }
        end

        if their_exit_count >= 2
          # This exit can reach at least one other exit — it's a split-map segment
          warning "#{ex[:name]} at (#{ex[:x]},#{ex[:y]}) not reachable from #{start[:name]} — may be intentional split-map design (reaches #{their_exit_count} exits from its side)"
        else
          unreachable_exits << ex
        end
      end
    end

    unreachable_exits.each do |ex|
      error "Exit '#{ex[:name]}' at (#{ex[:x]},#{ex[:y]}) is ISOLATED — not reachable from any other exit"
    end
  end

  def find_exits
    exits = []

    # From events: look for transfer commands and edge-positioned events
    @map.events.each do |id, ev|
      is_warp = false
      ev.pages.each do |page|
        next unless page.list
        page.list.each do |cmd|
          if cmd.code == 201  # Transfer Player
            is_warp = true
            break
          end
        end
        break if is_warp
      end

      if is_warp
        exits << { name: ev.name, x: ev.x, y: ev.y, id: id }
      end
    end

    # Also check spec events if map hasn't been built yet
    if exits.empty? && @spec["events"]
      @spec["events"].each do |ev_spec|
        has_transfer = (ev_spec["pages"] || [ev_spec]).any? do |page|
          (page["commands"] || []).any? { |c| c["type"] == "transfer" }
        end
        if has_transfer
          exits << { name: ev_spec["name"] || "Event#{ev_spec["id"]}", x: ev_spec["x"], y: ev_spec["y"], id: ev_spec["id"] }
        end
      end
    end

    exits
  end

  def bfs_reachable(start_x, start_y)
    visited = Set.new
    queue = []

    # Seed: start tile + all adjacent walkable tiles (exits may be on edge)
    seeds = [
      [start_x, start_y],
      [start_x, start_y - 1], [start_x, start_y + 1],
      [start_x - 1, start_y], [start_x + 1, start_y],
    ]
    seeds.each do |sx, sy|
      next if sx < 0 || sy < 0 || sx >= @xsize || sy >= @ysize
      if cell_walkable?(sx, sy) && visited.add?([sx, sy])
        queue << [sx, sy]
      end
    end

    # BFS
    head = 0
    while head < queue.length
      x, y = queue[head]
      head += 1

      [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
        nx = x + dx
        ny = y + dy
        next if nx < 0 || ny < 0 || nx >= @xsize || ny >= @ysize
        next unless visited.add?([nx, ny])
        next unless cell_walkable?(nx, ny)
        queue << [nx, ny]
      end
    end

    visited
  end

  # ── Check 3: Edge Boundaries ────────────────────────────────────────────────

  def check_edge_boundaries
    puts "  [CHECK 3] Edge Boundaries"

    # Check all 4 edges of the map. Each edge tile should be bounded
    # (trees, rocks, water, buildings) UNLESS it's an exit.
    exit_positions = Set.new
    find_exits.each do |ex|
      # Mark exit and a few tiles around it as OK to be unbounded
      (-2..2).each do |d|
        exit_positions.add([ex[:x] + d, ex[:y]])
        exit_positions.add([ex[:x], ex[:y] + d])
      end
    end

    edges = { top: [], bottom: [], left: [], right: [] }

    # Top edge (y=0)
    (0...@xsize).each do |x|
      unless tile_is_boundary?(x, 0) || exit_positions.include?([x, 0])
        edges[:top] << x
      end
    end

    # Bottom edge (y=ysize-1)
    (0...@xsize).each do |x|
      unless tile_is_boundary?(x, @ysize - 1) || exit_positions.include?([x, @ysize - 1])
        edges[:bottom] << x
      end
    end

    # Left edge (x=0)
    (0...@ysize).each do |y|
      unless tile_is_boundary?(0, y) || exit_positions.include?([0, y])
        edges[:left] << y
      end
    end

    # Right edge (x=xsize-1)
    (0...@ysize).each do |y|
      unless tile_is_boundary?(@xsize - 1, y) || exit_positions.include?([@xsize - 1, y])
        edges[:right] << y
      end
    end

    total_edge_tiles = 2 * @xsize + 2 * @ysize - 4  # perimeter
    unbounded = edges.values.map(&:length).sum
    bounded_pct = ((total_edge_tiles - unbounded) * 100.0 / total_edge_tiles).round(1)

    if unbounded == 0
      info "  [OK] All #{total_edge_tiles} edge tiles are properly bounded (#{bounded_pct}%)"
    else
      edges.each do |side, positions|
        next if positions.empty?
        # Group consecutive positions into ranges for readable output
        ranges = group_consecutive(positions)
        range_strs = ranges.map { |r| r.length == 1 ? r[0].to_s : "#{r.first}-#{r.last}" }
        if positions.length <= 5
          warning "#{side.to_s.capitalize} edge: #{positions.length} unbounded tile(s) at #{side == :top || side == :bottom ? 'x' : 'y'}=#{range_strs.join(', ')}"
        else
          error "#{side.to_s.capitalize} edge: #{positions.length} unbounded tile(s) at #{side == :top || side == :bottom ? 'x' : 'y'}=#{range_strs.join(', ')}"
        end
      end
      puts "    Edge coverage: #{bounded_pct}% bounded (#{unbounded}/#{total_edge_tiles} tiles open)"
    end
  end

  def group_consecutive(nums)
    return [] if nums.empty?
    ranges = []
    current = [nums.first]
    nums[1..].each do |n|
      if n == current.last + 1
        current << n
      else
        ranges << current
        current = [n]
      end
    end
    ranges << current
    ranges
  end

  # ── Reporting ───────────────────────────────────────────────────────────────

  def error(msg)
    @errors << msg
    puts "  [ERROR] #{msg}"
  end

  def warning(msg)
    @warnings << msg
    puts "  [WARN]  #{msg}"
  end

  def info(msg)
    @info << msg
    puts "  #{msg}"
  end

  def report
    puts "─" * 60
    if @errors.empty? && @warnings.empty?
      puts "  RESULT: ALL CHECKS PASSED"
    else
      puts "  RESULT: #{@errors.length} error(s), #{@warnings.length} warning(s)"
    end
    puts "─" * 60
    @errors.empty?
  end
end

# ── CLI ──────────────────────────────────────────────────────────────────────

if __FILE__ == $0
  if ARGV.length < 3
    STDERR.puts "Usage: ruby tools/validate_composition.rb <game_data_dir> <map_file.rxdata> <spec.json>"
    STDERR.puts ""
    STDERR.puts "Validates a composed map against its spec:"
    STDERR.puts "  1. Stamp integrity — all building tiles placed correctly"
    STDERR.puts "  2. Pathfinding — all exits reachable from each other"
    STDERR.puts "  3. Edge boundaries — map edges properly bounded"
    exit 1
  end

  game_dir = ARGV[0]
  map_file = ARGV[1]
  spec_file = ARGV[2]

  validator = CompositionValidator.new(game_dir)
  success = validator.validate(map_file, spec_file)
  exit(success ? 0 : 1)
end
