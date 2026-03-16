#!/usr/bin/env ruby
# validate_composition.rb — Post-composition validation for maps built by map_composer.
#
# Usage:
#   ruby tools/validate_composition.rb <game_data_dir> <map_file.rxdata> <composition_spec.json>
#
# Checks:
#   1. Stamp integrity — every non-zero tile from each stamp landed correctly
#   2. Pathfinding — all exits/warps are reachable from each other
#   3. Edge boundaries — map edges are bounded by impassable tiles
#   4. Tileset compatibility — stamps come from maps with matching tilesets
#   5. Ground tile seams — stamp boundaries blend with surrounding base fill
#   6. Door-to-path connectivity — door warps connect to the path network
#   7. Empty area detection — large dead zones of unbroken base fill
#   8. Border variety — edge stamps aren't all identical
#   9. Building spacing — buildings aren't too close or too far apart
#  10. Layer sanity — layer 1/2 tiles have appropriate layer 0 underneath

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
  # Categories that count as "buildings" for spacing checks
  BUILDING_CATEGORIES = %w[building house pokemon_center gym].freeze

  # Minimum/maximum gap between building bounding boxes (in tiles)
  MIN_BUILDING_GAP = 2
  MAX_BUILDING_GAP = 15

  # Minimum area (in tiles) to flag as an empty dead zone
  DEAD_ZONE_MIN_AREA = 64  # 8x8

  # Minimum percentage of border stamps that should be different types
  MIN_BORDER_VARIETY_PCT = 20

  def initialize(game_dir)
    @game_dir = game_dir
    @data_dir = File.join(game_dir, "Data")
    @stamps_dir = File.join(File.dirname(__FILE__), "stamps")
    @stamp_cache = {}
    @catalog = nil
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
    # Load stamp catalog
    load_catalog
    # Determine base fill tile
    @base_fill_tile = resolve_base_fill

    puts "=== Composition Validation: #{File.basename(map_file)} ==="
    puts "    Map: #{@xsize}x#{@ysize}, tileset #{@map.tileset_id}"
    puts ""

    check_stamp_integrity
    puts ""
    check_pathfinding
    puts ""
    check_edge_boundaries
    puts ""
    check_tileset_compatibility
    puts ""
    check_ground_seams
    puts ""
    check_door_path_connectivity
    puts ""
    check_empty_areas
    puts ""
    check_border_variety
    puts ""
    check_building_spacing
    puts ""
    check_layer_sanity
    puts ""

    report
  end

  private

  # ── Tile access ──────────────────────────────────────────────────────────────

  def get_tile(x, y, z)
    return 0 if x < 0 || y < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @tiles[x + y * @xsize + z * @xsize * @ysize]
  end

  # ── Setup helpers ───────────────────────────────────────────────────────────

  def load_passages
    @passages = nil
    tilesets_file = File.join(@data_dir, "Tilesets.rxdata")
    return unless File.exist?(tilesets_file)

    begin
      @tilesets = Marshal.load(File.binread(tilesets_file))
      ts = @tilesets[@map.tileset_id]
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

  def load_catalog
    catalog_file = File.join(@stamps_dir, "catalog.json")
    if File.exist?(catalog_file)
      @catalog = JSON.parse(File.read(catalog_file))
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

  def catalog_entry(name)
    return nil unless @catalog
    @catalog["stamps"]&.find { |s| s["name"] == name }
  end

  def resolve_base_fill
    fill_name = @spec["base_fill"]
    return 555 unless fill_name  # default grass

    # Match the TILE_VOCAB from map_composer
    vocab = {
      "grass" => 555, "grass_alt" => 560,
      "dirt_path" => 401, "dirt" => 401, "road" => 401,
      "sand" => 544, "cave_floor" => 386,
    }
    vocab[fill_name] || 555
  end

  # ── Passability ─────────────────────────────────────────────────────────────

  def tile_passable?(tile_id)
    return true unless @passages
    return true if tile_id == 0
    idx = tile_id
    return true if idx >= @passage_size
    (@passages[idx] & 0x0F) == 0
  end

  def cell_walkable?(x, y)
    (0...@zsize).each do |z|
      tid = get_tile(x, y, z)
      next if tid == 0
      return false unless tile_passable?(tid)
    end
    true
  end

  def tile_is_boundary?(x, y)
    has_blocker = false
    (0...@zsize).each do |z|
      tid = get_tile(x, y, z)
      next if tid == 0
      unless tile_passable?(tid)
        has_blocker = true
        break
      end
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
      info "No stamps in spec."
      return
    end

    stamps.each do |stamp_spec|
      name = stamp_spec["stamp"]
      ox = stamp_spec["x"] || 0
      oy = stamp_spec["y"] || 0
      flip_h = stamp_spec["flip_h"] || false

      stamp = load_stamp(name)
      unless stamp
        error "Stamp '#{name}' file not found"
        next
      end

      sw = stamp["width"]
      sh = stamp["height"]

      if ox + sw > @xsize || oy + sh > @ysize
        error "Stamp '#{name}' at (#{ox},#{oy}) extends beyond map bounds (#{sw}x#{sh} stamp, #{@xsize}x#{@ysize} map)"
      end
      if ox < 0 || oy < 0
        error "Stamp '#{name}' at (#{ox},#{oy}) has negative coordinates"
        next
      end

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
              next if expected_tid == 0
              total_tiles += 1

              tx = flip_h ? (sw - 1 - dx) : dx
              mx = ox + tx
              my = oy + dy
              next if mx >= @xsize || my >= @ysize

              actual_tid = get_tile(mx, my, z)
              if actual_tid == expected_tid
                matched_tiles += 1
              else
                mismatches << {
                  stamp_pos: "(#{dx},#{dy})", map_pos: "(#{mx},#{my})",
                  layer: z, expected: expected_tid, actual: actual_tid
                }
              end
            end
          end
        end
      end

      if mismatches.empty?
        info "[OK] '#{name}' at (#{ox},#{oy}): #{matched_tiles}/#{total_tiles} tiles correct"
      else
        pct = total_tiles > 0 ? (matched_tiles * 100.0 / total_tiles).round(1) : 0
        error "Stamp '#{name}' at (#{ox},#{oy}): #{mismatches.length}/#{total_tiles} tiles WRONG (#{pct}% correct)"
        mismatches.first(5).each do |m|
          error "  -> layer#{m[:layer]} map#{m[:map_pos]}: expected tile #{m[:expected]}, got #{m[:actual]}"
        end
        error "  -> ... and #{mismatches.length - 5} more mismatches" if mismatches.length > 5

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

    exits = find_exits
    if exits.length < 2
      info "Only #{exits.length} exit(s) found — skipping pathfinding."
      return
    end

    puts "    Found #{exits.length} exits: #{exits.map { |e| "#{e[:name]}(#{e[:x]},#{e[:y]})" }.join(', ')}"

    start = exits.first
    reachable = bfs_reachable(start[:x], start[:y])

    unreachable_exits = []
    exits[1..].each do |ex|
      found = adjacent_positions(ex[:x], ex[:y]).any? { |cx, cy| reachable.include?([cx, cy]) }

      if found
        info "[OK] #{start[:name]} -> #{ex[:name]}: reachable"
      else
        their_reach = bfs_reachable(ex[:x], ex[:y])
        their_exit_count = exits.count do |other|
          adjacent_positions(other[:x], other[:y]).any? { |cx, cy| their_reach.include?([cx, cy]) }
        end

        if their_exit_count >= 2
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

  # ── Check 3: Edge Boundaries ────────────────────────────────────────────────

  def check_edge_boundaries
    puts "  [CHECK 3] Edge Boundaries"

    exit_positions = Set.new
    find_exits.each do |ex|
      (-2..2).each do |d|
        exit_positions.add([ex[:x] + d, ex[:y]])
        exit_positions.add([ex[:x], ex[:y] + d])
      end
    end

    edges = { top: [], bottom: [], left: [], right: [] }

    (0...@xsize).each do |x|
      edges[:top] << x unless tile_is_boundary?(x, 0) || exit_positions.include?([x, 0])
      edges[:bottom] << x unless tile_is_boundary?(x, @ysize - 1) || exit_positions.include?([x, @ysize - 1])
    end
    (0...@ysize).each do |y|
      edges[:left] << y unless tile_is_boundary?(0, y) || exit_positions.include?([0, y])
      edges[:right] << y unless tile_is_boundary?(@xsize - 1, y) || exit_positions.include?([@xsize - 1, y])
    end

    total_edge_tiles = 2 * @xsize + 2 * @ysize - 4
    unbounded = edges.values.map(&:length).sum
    bounded_pct = ((total_edge_tiles - unbounded) * 100.0 / total_edge_tiles).round(1)

    if unbounded == 0
      info "[OK] All #{total_edge_tiles} edge tiles are properly bounded (#{bounded_pct}%)"
    else
      edges.each do |side, positions|
        next if positions.empty?
        ranges = group_consecutive(positions)
        range_strs = ranges.map { |r| r.length == 1 ? r[0].to_s : "#{r.first}-#{r.last}" }
        axis = (side == :top || side == :bottom) ? 'x' : 'y'
        if positions.length <= 5
          warning "#{side.to_s.capitalize} edge: #{positions.length} unbounded tile(s) at #{axis}=#{range_strs.join(', ')}"
        else
          error "#{side.to_s.capitalize} edge: #{positions.length} unbounded tile(s) at #{axis}=#{range_strs.join(', ')}"
        end
      end
      puts "    Edge coverage: #{bounded_pct}% bounded (#{unbounded}/#{total_edge_tiles} tiles open)"
    end
  end

  # ── Check 4: Tileset Compatibility ──────────────────────────────────────────

  def check_tileset_compatibility
    puts "  [CHECK 4] Tileset Compatibility"
    stamps = @spec["stamps"] || []
    target_tileset = @map.tileset_id

    stamps.each do |stamp_spec|
      name = stamp_spec["stamp"]
      stamp = load_stamp(name)
      next unless stamp

      source_map_id = stamp["source_map"]
      next unless source_map_id

      source_file = File.join(@data_dir, "Map%03d.rxdata" % source_map_id)
      next unless File.exist?(source_file)

      begin
        source_map = Marshal.load(File.binread(source_file))
        source_tileset = source_map.tileset_id
        if source_tileset != target_tileset
          error "Stamp '#{name}' was extracted from Map#{"%03d" % source_map_id} (tileset #{source_tileset}) but target map uses tileset #{target_tileset} — tile IDs will render as wrong graphics"
        end
      rescue => e
        warning "Could not check tileset for stamp '#{name}': #{e.message}"
      end
    end

    info "[OK] All stamps compatible with tileset #{target_tileset}" if @errors.none? { |e| e.include?("tileset") }
  end

  # ── Check 5: Ground Tile Seams ──────────────────────────────────────────────

  def check_ground_seams
    puts "  [CHECK 5] Ground Tile Seams"
    stamps = @spec["stamps"] || []
    seam_issues = []

    stamps.each do |stamp_spec|
      name = stamp_spec["stamp"]
      cat = catalog_entry(name)
      # Only check buildings/houses/structures — natural stamps are expected to blend
      next unless cat && BUILDING_CATEGORIES.include?(cat["category"])

      stamp = load_stamp(name)
      next unless stamp

      ox = stamp_spec["x"] || 0
      oy = stamp_spec["y"] || 0
      sw = stamp["width"]
      sh = stamp["height"]

      # Check the border tiles of the stamp's footprint on layer 0.
      # Compare each stamp-edge tile's layer0 with its neighbor outside the stamp.
      border_checks = []

      # Bottom edge of stamp (most visible — this is where the building meets ground)
      bottom_y = oy + sh
      (ox...(ox + sw)).each do |x|
        next if x < 0 || x >= @xsize || bottom_y >= @ysize
        stamp_ground = get_tile(x, bottom_y - 1, 0)
        outside_ground = get_tile(x, bottom_y, 0)
        if stamp_ground != 0 && outside_ground != 0 && stamp_ground != outside_ground
          # Check if they're from different "families" (different base row in tileset)
          # Tiles in the same 8-tile row are usually palette variants
          stamp_row = stamp_ground / 8
          outside_row = outside_ground / 8
          if stamp_row != outside_row
            border_checks << { x: x, y: bottom_y - 1, side: "bottom",
                               stamp_tile: stamp_ground, outside_tile: outside_ground }
          end
        end
      end

      # Left edge
      left_x = ox - 1
      if left_x >= 0
        (oy...(oy + sh)).each do |y|
          next if y < 0 || y >= @ysize
          stamp_ground = get_tile(ox, y, 0)
          outside_ground = get_tile(left_x, y, 0)
          if stamp_ground != 0 && outside_ground != 0
            stamp_row = stamp_ground / 8
            outside_row = outside_ground / 8
            if stamp_row != outside_row
              border_checks << { x: ox, y: y, side: "left",
                                 stamp_tile: stamp_ground, outside_tile: outside_ground }
            end
          end
        end
      end

      # Right edge
      right_x = ox + sw
      if right_x < @xsize
        (oy...(oy + sh)).each do |y|
          next if y < 0 || y >= @ysize
          stamp_ground = get_tile(ox + sw - 1, y, 0)
          outside_ground = get_tile(right_x, y, 0)
          if stamp_ground != 0 && outside_ground != 0
            stamp_row = stamp_ground / 8
            outside_row = outside_ground / 8
            if stamp_row != outside_row
              border_checks << { x: ox + sw - 1, y: y, side: "right",
                                 stamp_tile: stamp_ground, outside_tile: outside_ground }
            end
          end
        end
      end

      unless border_checks.empty?
        # Count unique seam sides
        sides = border_checks.map { |b| b[:side] }.uniq
        seam_issues << name
        if border_checks.length > 8
          warning "Stamp '#{name}' at (#{ox},#{oy}): #{border_checks.length} ground seam mismatches on #{sides.join(', ')} edge(s) — ground tiles don't blend with surrounding terrain"
        else
          info "[NOTICE] Stamp '#{name}' at (#{ox},#{oy}): #{border_checks.length} minor ground seams on #{sides.join(', ')} edge(s)"
        end
      end
    end

    if seam_issues.empty?
      info "[OK] No ground tile seams detected around buildings"
    else
      info "#{seam_issues.length} stamp(s) have ground seam issues"
      info "  FIX: Add transition tiles or match the stamp's ground tiles to the base fill around building footprints"
    end
  end

  # ── Check 6: Door-to-Path Connectivity ──────────────────────────────────────

  def check_door_path_connectivity
    puts "  [CHECK 6] Door-to-Path Connectivity"

    # Find door events (warps that are NOT on map edges)
    doors = find_exits.select do |ex|
      ex[:x] > 1 && ex[:x] < @xsize - 2 && ex[:y] > 1 && ex[:y] < @ysize - 2
    end

    if doors.empty?
      info "No interior door warps found."
      return
    end

    # Identify path tiles on the map (tiles matching dirt_path / road vocabulary)
    path_tile_ids = Set.new([401])  # dirt_path
    # Also include any tile used in spec paths
    (@spec["paths"] || []).each do |p|
      vocab = { "dirt_path" => 401, "dirt" => 401, "road" => 401, "sand" => 544 }
      tid = vocab[p["tile"]]
      path_tile_ids.add(tid) if tid
    end

    # BFS from path network to find all tiles connected to paths
    path_connected = Set.new
    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        if path_tile_ids.include?(get_tile(x, y, 0)) && cell_walkable?(x, y)
          path_connected.add([x, y])
        end
      end
    end

    # Expand path_connected by BFS through walkable tiles
    # (a door on grass next to a path tile is fine)
    expanded = bfs_from_set(path_connected, max_distance: 3)

    doors.each do |door|
      # Check if door or its immediate neighbors are on/near a path
      near_path = adjacent_positions(door[:x], door[:y]).any? { |cx, cy| expanded.include?([cx, cy]) }

      if near_path
        info "[OK] #{door[:name]}: connected to path network"
      else
        # Measure actual distance to nearest path tile
        dist = min_distance_to_set(door[:x], door[:y], path_connected)
        if dist
          error "#{door[:name]} at (#{door[:x]},#{door[:y]}): #{dist} tiles from nearest path — door is disconnected from road network"
        else
          error "#{door[:name]} at (#{door[:x]},#{door[:y]}): no path tiles found on map — door has no road access"
        end
      end
    end
  end

  # ── Check 7: Empty Area Detection ───────────────────────────────────────────

  def check_empty_areas
    puts "  [CHECK 7] Empty Area Detection"

    # Find contiguous regions of pure base fill (layer 0 = base, layer 1&2 = 0)
    visited = Set.new
    dead_zones = []

    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        next if visited.include?([x, y])
        next unless is_empty_cell?(x, y)

        # BFS flood-fill to find contiguous empty region
        region = []
        queue = [[x, y]]
        visited.add([x, y])
        head = 0

        while head < queue.length
          cx, cy = queue[head]
          head += 1
          region << [cx, cy]

          [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
            nx, ny = cx + dx, cy + dy
            next if nx < 0 || ny < 0 || nx >= @xsize || ny >= @ysize
            next if visited.include?([nx, ny])
            next unless is_empty_cell?(nx, ny)
            visited.add([nx, ny])
            queue << [nx, ny]
          end
        end

        if region.length >= DEAD_ZONE_MIN_AREA
          # Compute bounding box
          xs = region.map(&:first)
          ys = region.map(&:last)
          bbox = { x1: xs.min, y1: ys.min, x2: xs.max, y2: ys.max, area: region.length }
          dead_zones << bbox
        end
      end
    end

    if dead_zones.empty?
      info "[OK] No large empty areas detected (threshold: #{DEAD_ZONE_MIN_AREA} tiles)"
    else
      dead_zones.sort_by { |z| -z[:area] }.each do |zone|
        w = zone[:x2] - zone[:x1] + 1
        h = zone[:y2] - zone[:y1] + 1
        if zone[:area] >= DEAD_ZONE_MIN_AREA * 2
          error "Large empty area: #{zone[:area]} tiles at (#{zone[:x1]},#{zone[:y1]}) to (#{zone[:x2]},#{zone[:y2]}) (#{w}x#{h} bounding box) — add decoration, trees, or features"
        else
          warning "Empty area: #{zone[:area]} tiles at (#{zone[:x1]},#{zone[:y1]}) to (#{zone[:x2]},#{zone[:y2]}) (#{w}x#{h} bounding box) — consider adding detail"
        end
      end
    end
  end

  # ── Check 8: Border Variety ─────────────────────────────────────────────────

  def check_border_variety
    puts "  [CHECK 8] Border Variety"
    stamps = @spec["stamps"] || []

    # Identify stamps that are on or near the map edges (within 3 tiles)
    border_stamps = stamps.select do |s|
      stamp = load_stamp(s["stamp"])
      next false unless stamp
      ox = s["x"] || 0
      oy = s["y"] || 0
      sw = stamp["width"]
      sh = stamp["height"]

      # Is this stamp touching any edge?
      ox <= 3 || oy <= 3 || (ox + sw) >= (@xsize - 3) || (oy + sh) >= (@ysize - 3)
    end

    if border_stamps.length < 4
      info "Only #{border_stamps.length} border stamps — not enough to assess variety."
      return
    end

    # Count stamp types
    type_counts = Hash.new(0)
    border_stamps.each { |s| type_counts[s["stamp"]] += 1 }

    total = border_stamps.length
    unique_types = type_counts.keys.length
    most_common = type_counts.max_by { |_, v| v }
    most_common_pct = (most_common[1] * 100.0 / total).round(1)

    if unique_types == 1
      error "All #{total} border stamps are '#{most_common[0]}' — border looks monotonous. Use varied stamp types (mix tree clusters, different sizes, staggered depths)"
    elsif most_common_pct > 80
      warning "#{most_common_pct}% of border stamps (#{most_common[1]}/#{total}) are '#{most_common[0]}' — consider more variety"
    else
      info "[OK] Border stamp variety: #{unique_types} types across #{total} stamps (most common: '#{most_common[0]}' at #{most_common_pct}%)"
    end

    # Check for natural irregularity — are all border stamps on a perfect grid?
    if border_stamps.length >= 6
      x_coords = border_stamps.map { |s| s["x"] || 0 }
      y_coords = border_stamps.map { |s| s["y"] || 0 }

      # Check if X or Y coords are all multiples of the same value (grid-locked)
      x_diffs = x_coords.sort.each_cons(2).map { |a, b| b - a }.select { |d| d > 0 }
      if x_diffs.length >= 3
        most_common_diff = x_diffs.tally.max_by { |_, v| v }
        if most_common_diff && most_common_diff[1] > x_diffs.length * 0.7
          warning "Border stamps are grid-locked (#{most_common_diff[1]}/#{x_diffs.length} have x-spacing of #{most_common_diff[0]}) — stagger positions for natural look"
        end
      end
    end
  end

  # ── Check 9: Building Spacing ───────────────────────────────────────────────

  def check_building_spacing
    puts "  [CHECK 9] Building Spacing"
    stamps = @spec["stamps"] || []

    # Find building stamps with their bounding boxes
    buildings = []
    stamps.each do |s|
      cat = catalog_entry(s["stamp"])
      next unless cat && BUILDING_CATEGORIES.include?(cat["category"])
      stamp = load_stamp(s["stamp"])
      next unless stamp
      ox = s["x"] || 0
      oy = s["y"] || 0
      buildings << {
        name: s["stamp"], x: ox, y: oy,
        w: stamp["width"], h: stamp["height"]
      }
    end

    if buildings.length < 2
      info "Only #{buildings.length} building(s) — skipping spacing check."
      return
    end

    # Check pairwise distances between building bounding boxes
    too_close = []
    too_far = []

    buildings.combination(2).each do |a, b|
      gap = bounding_box_gap(a, b)
      if gap < MIN_BUILDING_GAP
        too_close << { a: a[:name], b: b[:name], gap: gap }
      end
    end

    # Check if any building is isolated (nearest neighbor > MAX_BUILDING_GAP)
    buildings.each do |bldg|
      others = buildings.reject { |b| b.equal?(bldg) }
      nearest = others.map { |b| bounding_box_gap(bldg, b) }.min
      if nearest && nearest > MAX_BUILDING_GAP
        too_far << { name: bldg[:name], nearest: nearest }
      end
    end

    if too_close.empty? && too_far.empty?
      info "[OK] Building spacing looks good (#{buildings.length} buildings, all #{MIN_BUILDING_GAP}-#{MAX_BUILDING_GAP} tiles apart)"
    else
      too_close.each do |tc|
        if tc[:gap] <= 0
          error "Buildings '#{tc[:a]}' and '#{tc[:b]}' OVERLAP (gap=#{tc[:gap]}) — buildings should have at least #{MIN_BUILDING_GAP} tiles between them"
        else
          warning "Buildings '#{tc[:a]}' and '#{tc[:b]}' are very close (gap=#{tc[:gap]} tiles, minimum #{MIN_BUILDING_GAP})"
        end
      end
      too_far.each do |tf|
        warning "Building '#{tf[:name]}' is isolated (nearest building is #{tf[:nearest]} tiles away, max #{MAX_BUILDING_GAP})"
      end
    end
  end

  # ── Check 10: Layer Sanity ──────────────────────────────────────────────────

  def check_layer_sanity
    puts "  [CHECK 10] Layer Sanity"
    issues = []

    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        l0 = get_tile(x, y, 0)
        l1 = get_tile(x, y, 1)
        l2 = get_tile(x, y, 2)

        # Layer 1 has content but layer 0 is empty
        if l1 != 0 && l0 == 0
          issues << { x: x, y: y, type: :floating_l1, l1: l1 }
        end

        # Layer 2 has content but layer 1 is empty AND layer 0 is empty
        if l2 != 0 && l1 == 0 && l0 == 0
          issues << { x: x, y: y, type: :floating_l2, l2: l2 }
        end

        # Tree top (layer 2) without any corresponding structure below.
        # Tree tops (8985-8999) are valid when they're part of a stamp (tree_2x2, etc.)
        # that places them as decorative overlays. Only flag truly orphaned ones where
        # the layer 2 tile exists but there's nothing at all on layers 0/1 below.
        if l2 != 0 && (l2 >= 8985 && l2 <= 8999)
          # Check if layer 0 has something other than the base fill, or layer 1 has content
          has_structure = (l0 != @base_fill_tile && l0 != 0) || (l1 != 0)
          # Also check one row below (tree tops often sit above tree trunks)
          below_l0 = get_tile(x, y + 1, 0)
          below_l1 = get_tile(x, y + 1, 1)
          has_structure_below = (below_l0 != @base_fill_tile && below_l0 != 0) || (below_l1 != 0)
          unless has_structure || has_structure_below
            issues << { x: x, y: y, type: :orphan_tree_top, l2: l2 }
          end
        end
      end
    end

    if issues.empty?
      info "[OK] Layer structure is clean — no floating objects or orphaned overlays"
    else
      type_counts = issues.group_by { |i| i[:type] }.transform_values(&:length)

      type_counts.each do |type, count|
        case type
        when :floating_l1
          if count > 10
            error "#{count} tiles have layer 1 content over empty layer 0 — objects floating over void"
          else
            warning "#{count} tile(s) have layer 1 content over empty layer 0"
          end
          # Show a few examples
          issues.select { |i| i[:type] == type }.first(3).each do |i|
            info "  -> (#{i[:x]},#{i[:y]}): layer1=#{i[:l1]}, layer0=empty"
          end
        when :floating_l2
          warning "#{count} tile(s) have layer 2 content over empty layers 0+1"
        when :orphan_tree_top
          if count > 5
            warning "#{count} orphaned tree tops (layer 2 tree overlay with no tree trunk below)"
          end
          issues.select { |i| i[:type] == type }.first(3).each do |i|
            info "  -> (#{i[:x]},#{i[:y]}): tree top tile #{i[:l2]} with no trunk"
          end
        end
      end
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  def find_exits
    exits = []
    @map.events.each do |id, ev|
      is_warp = false
      ev.pages.each do |page|
        next unless page.list
        page.list.each do |cmd|
          if cmd.code == 201
            is_warp = true
            break
          end
        end
        break if is_warp
      end
      exits << { name: ev.name, x: ev.x, y: ev.y, id: id } if is_warp
    end

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

  def adjacent_positions(x, y)
    [[x, y], [x, y - 1], [x, y + 1], [x - 1, y], [x + 1, y]]
  end

  def bfs_reachable(start_x, start_y)
    visited = Set.new
    queue = []

    adjacent_positions(start_x, start_y).each do |sx, sy|
      next if sx < 0 || sy < 0 || sx >= @xsize || sy >= @ysize
      if cell_walkable?(sx, sy) && visited.add?([sx, sy])
        queue << [sx, sy]
      end
    end

    head = 0
    while head < queue.length
      x, y = queue[head]
      head += 1
      [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
        nx, ny = x + dx, y + dy
        next if nx < 0 || ny < 0 || nx >= @xsize || ny >= @ysize
        next unless visited.add?([nx, ny])
        next unless cell_walkable?(nx, ny)
        queue << [nx, ny]
      end
    end
    visited
  end

  def bfs_from_set(start_set, max_distance: nil)
    visited = Set.new(start_set)
    queue = start_set.map { |pos| [pos[0], pos[1], 0] }
    head = 0

    while head < queue.length
      x, y, dist = queue[head]
      head += 1
      next if max_distance && dist >= max_distance

      [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
        nx, ny = x + dx, y + dy
        next if nx < 0 || ny < 0 || nx >= @xsize || ny >= @ysize
        next unless visited.add?([nx, ny])
        next unless cell_walkable?(nx, ny)
        queue << [nx, ny, dist + 1]
      end
    end
    visited
  end

  def min_distance_to_set(start_x, start_y, target_set)
    visited = Set.new
    queue = [[start_x, start_y, 0]]
    visited.add([start_x, start_y])

    while !queue.empty?
      x, y, dist = queue.shift
      return dist if target_set.include?([x, y])
      return nil if dist > 50  # give up after 50 tiles

      [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
        nx, ny = x + dx, y + dy
        next if nx < 0 || ny < 0 || nx >= @xsize || ny >= @ysize
        next unless visited.add?([nx, ny])
        queue << [nx, ny, dist + 1]
      end
    end
    nil
  end

  def is_empty_cell?(x, y)
    l0 = get_tile(x, y, 0)
    l1 = get_tile(x, y, 1)
    l2 = get_tile(x, y, 2)
    l0 == @base_fill_tile && l1 == 0 && l2 == 0
  end

  def bounding_box_gap(a, b)
    # Compute minimum distance between two bounding boxes
    # Negative means overlap
    ax1, ay1 = a[:x], a[:y]
    ax2, ay2 = ax1 + a[:w] - 1, ay1 + a[:h] - 1
    bx1, by1 = b[:x], b[:y]
    bx2, by2 = bx1 + b[:w] - 1, by1 + b[:h] - 1

    dx = [ax1 - bx2 - 1, bx1 - ax2 - 1, 0].max
    dy = [ay1 - by2 - 1, by1 - ay2 - 1, 0].max

    if dx == 0 && dy == 0
      # Overlapping — return negative overlap amount
      overlap_x = [ax2, bx2].min - [ax1, bx1].max + 1
      overlap_y = [ay2, by2].min - [ay1, by1].max + 1
      return -[overlap_x, overlap_y].min
    end

    # Chebyshev distance between nearest edges
    [dx, dy].max
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
      puts "  RESULT: ALL CHECKS PASSED (10/10)"
    else
      puts "  RESULT: #{@errors.length} error(s), #{@warnings.length} warning(s)"
      if @errors.any?
        puts ""
        puts "  ERRORS require fixing:"
        @errors.first(10).each { |e| puts "    - #{e}" }
        puts "    ... and #{@errors.length - 10} more" if @errors.length > 10
      end
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
    STDERR.puts "Validates a composed map against its spec (10 checks):"
    STDERR.puts "  1.  Stamp integrity        — all building tiles placed correctly"
    STDERR.puts "  2.  Pathfinding            — all exits reachable from each other"
    STDERR.puts "  3.  Edge boundaries        — map edges properly bounded"
    STDERR.puts "  4.  Tileset compatibility  — stamps match target tileset"
    STDERR.puts "  5.  Ground tile seams      — building edges blend with terrain"
    STDERR.puts "  6.  Door-path connectivity — doors connect to road network"
    STDERR.puts "  7.  Empty area detection   — flag large dead zones"
    STDERR.puts "  8.  Border variety         — edge stamps aren't monotonous"
    STDERR.puts "  9.  Building spacing       — buildings not too close/far"
    STDERR.puts "  10. Layer sanity           — no floating objects or orphan overlays"
    exit 1
  end

  game_dir = ARGV[0]
  map_file = ARGV[1]
  spec_file = ARGV[2]

  validator = CompositionValidator.new(game_dir)
  success = validator.validate(map_file, spec_file)
  exit(success ? 0 : 1)
end
