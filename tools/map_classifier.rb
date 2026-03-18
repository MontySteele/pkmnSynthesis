#!/usr/bin/env ruby
# map_classifier.rb — Bulk-loads all maps from game_data and outputs a JSON
# classification file with metadata, event stats, and heuristic type labels.
#
# Usage:
#   ruby tools/map_classifier.rb <game_data_dir> [output.json]
#
# Arguments:
#   game_data_dir - Path to the game_data/ directory (must contain Data/)
#   output.json   - Output file path (default: map_classification.json)

require "json"
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

# ─── Passability ─────────────────────────────────────────────────────────────

def walkable_pct(tiles, xsize, ysize, zsize, passages)
  walkable = 0
  total = xsize * ysize
  return 0.0 if total == 0

  (0...ysize).each do |y|
    (0...xsize).each do |x|
      blocked = false
      (0...zsize).each do |z|
        tid = tiles[x + y * xsize + z * xsize * ysize]
        next if tid == 0
        if tid < passages.length && (passages[tid] & 0x0F) != 0
          blocked = true
          break
        end
      end
      walkable += 1 unless blocked
    end
  end
  (walkable * 100.0 / total).round(1)
end

# ─── Classification heuristics ───────────────────────────────────────────────

INDOOR_TILESET_KEYWORDS = %w[
  indoor inside house building gym center mart museum lab office
  school hospital department store hotel mansion room floor
  headquarters hq ship ss cabin
].freeze

CAVE_TILESET_KEYWORDS = %w[cave tunnel underground cavern grotto].freeze

def classify_map(name, width, height, tileset_name)
  ts_lower = (tileset_name || "").downcase
  name_str = (name || "").to_s

  # Cave check (tileset-based)
  if CAVE_TILESET_KEYWORDS.any? { |kw| ts_lower.include?(kw) }
    return "cave"
  end

  # Dungeon check (name-based)
  if name_str =~ /\b(Tower|Mansion|Tunnel|Hideout)\b/i
    return "dungeon"
  end

  # Route check (name-based, or large linear maps)
  if name_str =~ /\bRoute\b/i
    return "outdoor_route"
  end

  # City/Town check (name-based)
  if name_str =~ /\b(City|Town|Island)\b/i
    return "outdoor_city"
  end

  # Interior check (small map with indoor tileset)
  if width <= 25 && height <= 25 && INDOOR_TILESET_KEYWORDS.any? { |kw| ts_lower.include?(kw) }
    return "interior"
  end

  "special"
end

# ─── Event analysis ──────────────────────────────────────────────────────────

def analyze_events(events)
  event_count = 0
  warp_count = 0
  npc_count = 0
  trainer_count = 0
  warp_targets = []

  return [event_count, warp_count, npc_count, trainer_count, warp_targets] unless events

  events.each do |_id, event|
    next unless event.is_a?(RPG::Event)
    event_count += 1

    has_text = false
    has_warp = false
    has_trainer = false

    (event.pages || []).each do |page|
      next unless page && page.list
      page.list.each do |cmd|
        next unless cmd

        case cmd.code
        when 201
          has_warp = true
          # Extract warp target map ID from parameters
          if cmd.parameters && cmd.parameters.length >= 2
            # parameters[0] = direct(0)/variable(1), parameters[1] = map_id or variable_id
            if cmd.parameters[0] == 0 && cmd.parameters[1].is_a?(Integer)
              warp_targets << cmd.parameters[1]
            end
          end
        when 101
          has_text = true
        when 355
          if cmd.parameters && cmd.parameters[0].is_a?(String)
            has_trainer = true if cmd.parameters[0].include?("pbTrainerBattle")
          end
        end
      end
    end

    warp_count += 1 if has_warp
    npc_count += 1 if has_text
    trainer_count += 1 if has_trainer
  end

  warp_targets.uniq!
  warp_targets.sort!
  [event_count, warp_count, npc_count, trainer_count, warp_targets]
end

# ─── Main ────────────────────────────────────────────────────────────────────

if ARGV.empty?
  $stderr.puts "Usage: ruby tools/map_classifier.rb <game_data_dir> [output.json]"
  exit 1
end

game_data_dir = ARGV[0]
output_file = ARGV[1] || "map_classification.json"
data_dir = File.join(game_data_dir, "Data")

unless File.directory?(data_dir)
  $stderr.puts "ERROR: Data directory not found: #{data_dir}"
  exit 1
end

# Load MapInfos
map_infos_path = File.join(data_dir, "MapInfos.rxdata")
unless File.exist?(map_infos_path)
  $stderr.puts "ERROR: MapInfos.rxdata not found in #{data_dir}"
  exit 1
end
map_infos = Marshal.load(File.binread(map_infos_path))
$stderr.puts "Loaded MapInfos: #{map_infos.size} entries"

# Load Tilesets
tilesets_path = File.join(data_dir, "Tilesets.rxdata")
tilesets = nil
if File.exist?(tilesets_path)
  tilesets = Marshal.load(File.binread(tilesets_path))
  $stderr.puts "Loaded Tilesets: #{tilesets.compact.size} entries"
else
  $stderr.puts "WARNING: Tilesets.rxdata not found, passability data unavailable"
end

# Find all map files
map_files = Dir.glob(File.join(data_dir, "Map[0-9][0-9][0-9].rxdata")).sort
$stderr.puts "Found #{map_files.size} map files"

maps_output = []
processed = 0

map_files.each do |map_file|
  basename = File.basename(map_file, ".rxdata")
  map_id = basename.sub("Map", "").to_i

  begin
    map = Marshal.load(File.binread(map_file))
  rescue => e
    $stderr.puts "WARNING: Failed to load #{basename}: #{e.message}"
    next
  end

  # Map name from MapInfos
  info = map_infos[map_id]
  map_name = info ? info.name : "Unknown"

  # Tileset info
  tileset_id = map.tileset_id
  tileset_name = ""
  if tilesets && tileset_id && tilesets[tileset_id]
    ts = tilesets[tileset_id]
    tileset_name = ts.name || ""
  end

  # Dimensions
  width = map.width || 0
  height = map.height || 0

  # Tile data and passability
  walkable_tile_pct = 0.0
  if map.data
    raw = map.data.instance_variable_get(:@raw)
    if raw && raw.length >= 20
      _ndim, xsize, ysize, zsize, _total = raw.unpack("V5")
      tile_data = raw[20..-1].unpack("v*")

      if tilesets && tileset_id && tilesets[tileset_id] && tilesets[tileset_id].passages
        praw = tilesets[tileset_id].passages.instance_variable_get(:@raw)
        if praw && praw.length >= 20
          passages = praw[20..-1].unpack("v*")
          walkable_tile_pct = walkable_pct(tile_data, xsize, ysize, zsize, passages)
        end
      end
    end
  end

  # Event analysis
  event_count, warp_count, npc_count, trainer_count, warp_targets =
    analyze_events(map.events)

  # Classification
  map_type = classify_map(map_name, width, height, tileset_name)

  maps_output << {
    "map_id"           => map_id,
    "name"             => map_name,
    "width"            => width,
    "height"           => height,
    "tileset_id"       => tileset_id,
    "tileset_name"     => tileset_name,
    "event_count"      => event_count,
    "warp_count"       => warp_count,
    "npc_count"        => npc_count,
    "trainer_count"    => trainer_count,
    "walkable_tile_pct" => walkable_tile_pct,
    "type"             => map_type,
    "warp_targets"     => warp_targets,
  }

  processed += 1
  if processed % 50 == 0
    $stderr.puts "Processed #{processed}/#{map_files.size} maps..."
  end
end

# Sort by map_id
maps_output.sort_by! { |m| m["map_id"] }

output = {
  "generated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "total_maps"   => maps_output.size,
  "maps"         => maps_output,
}

File.open(output_file, "w") do |f|
  f.write(JSON.pretty_generate(output))
  f.puts
end

$stderr.puts "Done. Classified #{maps_output.size} maps -> #{output_file}"
