#!/usr/bin/env ruby
# frozen_string_literal: true

# validate_reuse.rb — Analyze and report on Johto map reuse in Kanto→Johto assignments
#
# Usage: ruby tools/validate_reuse.rb <map_matches.json> [map_classification.json] [--max-reuse N]

require 'json'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MAX_REUSE_DEFAULT = 3

# Game phases: maps are assigned to phases based on Kanto area names.
# Each phase has a label and a list of name patterns (matched case-insensitively).
GAME_PHASES = [
  {
    label: "Early game (Pallet→Pewter)",
    patterns: [
      /\bPallet\b/i, /\bRoute [12]\b/i, /\bViridian\b/i,
      /\bViridian Forest\b/i, /\bRoute 2\b/i, /\bPewter\b/i,
      /\bRoute 3\b/i, /\bMt\.? Moon\b/i, /\bRoute 4\b/i
    ]
  },
  {
    label: "Mid game (Cerulean→Celadon)",
    patterns: [
      /\bCerulean\b/i, /\bRoute [5-9]\b/i, /\bRoute 10\b/i,
      /\bRoute 24\b/i, /\bRoute 25\b/i,
      /\bVermillion\b/i, /\bS\.?S\.? Anne\b/i,
      /\bRock Tunnel\b/i, /\bLavender\b/i,
      /\bCeladon\b/i, /\bGame Corner\b/i, /\bTeam Rocket\b/i,
      /\bDiglett/i, /\bDay Care\b/i, /\bUnderground\b/i
    ]
  },
  {
    label: "Late game (Saffron→Cinnabar)",
    patterns: [
      /\bSaffron\b/i, /\bSilph Co\b/i,
      /\bRoute 1[1-9]\b/i, /\bRoute 2[0-1]\b/i,
      /\bFuchsia\b/i, /\bSafari\b/i,
      /\bCinnabar\b/i, /\bSeafoam\b/i,
      /\bPower Plant\b/i, /\bCrimson\b/i,
      /\bRoute 12\b/i, /\bRoute 13\b/i, /\bRoute 14\b/i,
      /\bRoute 15\b/i, /\bRoute 16\b/i, /\bRoute 17\b/i,
      /\bRoute 18\b/i, /\bRoute 19\b/i, /\bRoute 20\b/i
    ]
  },
  {
    label: "Endgame (Victory Road+)",
    patterns: [
      /\bVictory Road\b/i, /\bRoute 22\b/i, /\bRoute 23\b/i,
      /\bIndigo\b/i, /\bElite Four\b/i, /\bChampion\b/i,
      /\bCerulean Cave\b/i, /\bMewtwo\b/i,
      /\bFullmoon\b/i, /\bHalfmoon\b/i, /\bNewmoon\b/i,
      /\bNightsky\b/i, /\bHidden Forest\b/i, /\bMoonlit\b/i
    ]
  }
]

MAP_TYPES = %w[outdoor_route outdoor_city cave dungeon interior special].freeze
LARGE_TYPES = %w[outdoor_route outdoor_city].freeze

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_args(argv)
  max_reuse = MAX_REUSE_DEFAULT
  files = []

  i = 0
  while i < argv.length
    if argv[i] == '--max-reuse'
      i += 1
      max_reuse = (argv[i] || MAX_REUSE_DEFAULT).to_i
    else
      files << argv[i]
    end
    i += 1
  end

  matches_file = files[0]
  classification_file = files[1]

  unless matches_file
    $stderr.puts "Usage: ruby tools/validate_reuse.rb <map_matches.json> [map_classification.json] [--max-reuse N]"
    exit 1
  end

  [matches_file, classification_file, max_reuse]
end

def load_json(path)
  JSON.parse(File.read(path))
rescue Errno::ENOENT
  $stderr.puts "ERROR: File not found: #{path}"
  exit 1
rescue JSON::ParserError => e
  $stderr.puts "ERROR: Invalid JSON in #{path}: #{e.message}"
  exit 1
end

def classify_phase(kanto_name)
  GAME_PHASES.each_with_index do |phase, idx|
    phase[:patterns].each do |pat|
      return idx if kanto_name.match(pat)
    end
  end
  nil # unclassified
end

def build_classification_lookup(classification_data)
  lookup = {}
  if classification_data && classification_data["maps"]
    classification_data["maps"].each do |m|
      lookup[m["map_id"]] = m
    end
  end
  lookup
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

matches_file, classification_file, max_reuse = parse_args(ARGV)

match_data = load_json(matches_file)
matches = match_data["matches"] || []

classification_data = classification_file ? load_json(classification_file) : nil
classification_lookup = build_classification_lookup(classification_data)

# --- Compute reuse: johto_id → list of kanto match entries ---
johto_usage = Hash.new { |h, k| h[k] = [] }
matches.each do |m|
  johto_usage[m["assigned_johto_id"]] << m
end

# --- Self-mapped ---
self_mapped = matches.select { |m| m["kanto_map_id"] == m["assigned_johto_id"] }

# --- Reuse distribution ---
reuse_counts = Hash.new(0) # count_of_uses → number_of_johto_maps
johto_usage.each_value do |users|
  reuse_counts[users.length] += 1
end

# --- Reuse by type ---
# For each map type, find max reuse among Johto maps used by Kanto maps of that type
type_max_reuse = Hash.new(0)
type_reuse_details = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

johto_usage.each do |johto_id, users|
  MAP_TYPES.each do |t|
    type_users = users.select { |m| m["kanto_type"] == t }
    next if type_users.empty?
    type_max_reuse[t] = [type_max_reuse[t], type_users.length].max
    if type_users.length > 1
      type_reuse_details[t][johto_id] = type_users
    end
  end
end

# --- Flagged issues ---
errors = []
warnings = []
infos = []

johto_usage.each do |johto_id, users|
  johto_name = users.first["johto_name"]
  kanto_names = users.map { |m| "#{m['kanto_name']} (Map#{m['kanto_map_id']})" }

  if users.length > max_reuse
    errors << "[ERROR] #{johto_name} (Map#{johto_id}) used #{users.length}x (max #{max_reuse}) for: #{kanto_names.join(', ')}"
  end

  # Warn if a large type reuses the same Johto map
  large_users = users.select { |m| LARGE_TYPES.include?(m["kanto_type"]) }
  if large_users.length > 1
    large_names = large_users.map { |m| m["kanto_name"] }
    warnings << "[WARN] #{johto_name} (Map#{johto_id}) used for #{large_users.length} large maps: #{large_names.join(', ')}"
  end
end

self_mapped.each do |m|
  infos << "[INFO] #{m['kanto_name']} (Map#{m['kanto_map_id']}) is self-mapped (kanto_id == johto_id)"
end

# --- Visual diversity by phase ---
phase_stats = GAME_PHASES.each_with_index.map do |phase, idx|
  phase_matches = matches.select { |m| classify_phase(m["kanto_name"]) == idx }
  total = phase_matches.length
  unique_johto = phase_matches.map { |m| m["assigned_johto_id"] }.uniq.length
  pct = total > 0 ? (unique_johto.to_f / total * 100).round(1) : 0.0
  { label: phase[:label], unique: unique_johto, total: total, pct: pct }
end

# Unclassified maps
unclassified = matches.select { |m| classify_phase(m["kanto_name"]).nil? }

# --- Output report ---
puts "=== Map Reuse Report ==="
puts

puts "Reuse Distribution:"
(1..[reuse_counts.keys.max || 1, 1].max).each do |n|
  count = reuse_counts[n] || 0
  label = n == 1 ? "1x (unique)" : "#{n}x"
  puts "  #{label}: #{count} Johto maps"
end
puts "  Self-mapped: #{self_mapped.length} Kanto maps"
puts

puts "Reuse by Type:"
MAP_TYPES.each do |t|
  mr = type_max_reuse[t]
  status = mr > max_reuse ? "OVER LIMIT" : "OK"
  puts "  #{t}: max #{mr}x reuse [#{status}]"
end
puts

if errors.any? || warnings.any? || infos.any?
  puts "Flagged Issues:"
  errors.each { |e| puts "  #{e}" }
  warnings.each { |w| puts "  #{w}" }
  infos.each { |i| puts "  #{i}" }
  puts
end

puts "Visual Diversity by Phase:"
phase_stats.each do |ps|
  if ps[:total] > 0
    puts "  #{ps[:label]}: #{ps[:unique]} unique Johto maps / #{ps[:total]} total maps = #{ps[:pct]}%"
  else
    puts "  #{ps[:label]}: (no maps classified)"
  end
end
if unclassified.any?
  unclassified_unique = unclassified.map { |m| m["assigned_johto_id"] }.uniq.length
  pct = (unclassified_unique.to_f / unclassified.length * 100).round(1)
  puts "  Unclassified: #{unclassified_unique} unique / #{unclassified.length} total = #{pct}%"
end
puts

overall_max = reuse_counts.keys.max || 0
if errors.any?
  puts "Summary: FAIL (max reuse #{overall_max}x, exceeds threshold of #{max_reuse}x)"
  exit 1
else
  puts "Summary: PASS (max reuse #{overall_max}x, within threshold of #{max_reuse}x)"
  exit 0
end
