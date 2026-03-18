#!/usr/bin/env ruby
# generate_transplant_spec.rb — Reads map match results and generates a transplant
# spec JSON suitable for transplant_events.rb.
#
# Usage:
#   ruby tools/generate_transplant_spec.rb <matches.json> [--min-score N] [--output spec.json]
#
# Arguments:
#   matches.json  - Path to map_matches.json (from map matching tool)
#   --min-score N - Minimum match score to include (default: 50)
#   --output FILE - Output file path (default: transplant_spec.json)

require "json"

# ─── Argument parsing ────────────────────────────────────────────────────────

def usage
  $stderr.puts "Usage: ruby tools/generate_transplant_spec.rb <matches.json> [--min-score N] [--output spec.json]"
  exit 1
end

usage if ARGV.empty?

matches_file = nil
min_score = 50
output_file = "transplant_spec.json"

i = 0
while i < ARGV.length
  case ARGV[i]
  when "--min-score"
    i += 1
    usage unless ARGV[i]
    min_score = ARGV[i].to_i
  when "--output"
    i += 1
    usage unless ARGV[i]
    output_file = ARGV[i]
  when /^--/
    $stderr.puts "ERROR: Unknown option: #{ARGV[i]}"
    usage
  else
    if matches_file.nil?
      matches_file = ARGV[i]
    else
      $stderr.puts "ERROR: Unexpected argument: #{ARGV[i]}"
      usage
    end
  end
  i += 1
end

unless matches_file
  $stderr.puts "ERROR: No matches file specified"
  usage
end

unless File.exist?(matches_file)
  $stderr.puts "ERROR: File not found: #{matches_file}"
  exit 1
end

# ─── Load matches ────────────────────────────────────────────────────────────

data = JSON.parse(File.read(matches_file))
matches = data["matches"] || []

$stderr.puts "Loaded #{matches.size} matches from #{matches_file}"
$stderr.puts "Filter: min_score >= #{min_score}"

# ─── Filter and build transplant entries ─────────────────────────────────────

skipped_review = 0
skipped_score = 0
skipped_self_mapped = 0
transplants = []

matches.each do |m|
  # Skip entries flagged for manual review
  if m["manual_review_needed"]
    skipped_review += 1
    next
  end

  # Skip self-mapped entries (small interiors kept as original Kanto)
  if m["self_mapped"] || m["kanto_map_id"] == m["assigned_johto_id"]
    skipped_self_mapped += 1
    next
  end

  score = m["score"] || 0
  if score < min_score
    skipped_score += 1
    next
  end

  kanto_id   = m["kanto_map_id"]
  johto_id   = m["assigned_johto_id"]
  kanto_name = m["kanto_name"] || "Unknown"
  johto_name = m["johto_name"] || "Unknown"
  kanto_dims = m["kanto_dims"] || "?x?"
  johto_dims = m["johto_dims"] || "?x?"

  transplants << {
    "source_map_id" => kanto_id,
    "target_map_id" => johto_id,
    "output_map_id" => kanto_id,
    "description"   => "#{kanto_name} (#{kanto_dims}) <- #{johto_name} (#{johto_dims}), score: #{score}",
  }
end

# Sort by score descending (best matches first)
transplants.sort_by! { |t| -(t["description"][/score: ([\d.]+)/, 1].to_f) }

# ─── Output ──────────────────────────────────────────────────────────────────

output = {
  "transplants"     => transplants,
  "warp_retargets"  => {},
}

File.open(output_file, "w") do |f|
  f.write(JSON.pretty_generate(output))
  f.puts
end

# ─── Summary stats ───────────────────────────────────────────────────────────

included = transplants.size
total = matches.size

$stderr.puts ""
$stderr.puts "=== Summary ==="
$stderr.puts "Total matches:          #{total}"
$stderr.puts "Included (score >= #{min_score}): #{included}"
$stderr.puts "Skipped (low score):    #{skipped_score}"
$stderr.puts "Skipped (manual review):#{skipped_review}"
$stderr.puts "Skipped (self-mapped):  #{skipped_self_mapped}"
$stderr.puts ""

if transplants.any?
  scores = transplants.map { |t| t["description"][/score: ([\d.]+)/, 1].to_f }
  $stderr.puts "Score range: #{scores.min} - #{scores.max}"
  $stderr.puts "Mean score:  #{(scores.reduce(:+) / scores.size).round(1)}"
end

$stderr.puts ""
$stderr.puts "Wrote #{included} transplant entries -> #{output_file}"
