#!/usr/bin/env ruby
# frozen_string_literal: true

# match_maps.rb — Suggests Kanto->Johto map pairings based on compatibility.
#
# Usage: ruby tools/match_maps.rb <classification.json> [output.json] [--max-reuse N]
#
# Reads the output of map_classifier.rb and scores every possible Kanto/Johto
# pairing within each map type, then performs a greedy global assignment.
#
# Options:
#   --max-reuse N   Maximum times a single Johto map can be reused (default: 3)

require 'json'
require 'time'

# ---------------------------------------------------------------------------
# Hard-coded map ID lists
# ---------------------------------------------------------------------------

KANTO_MAP_IDS = [
  42, 43, 48, 77, 78, 76, 97, 185, 205, 79, 80, 81, 83, 84, 491, 85, 371,
  458, 710, 711, 746, 38, 375, 40, 669, 655, 86, 88, 89, 90, 92, 222, 511,
  39, 91, 93, 380, 386, 392, 382, 96, 385, 381, 470, 459, 460, 490, 379,
  102, 103, 104, 105, 116, 117, 494, 496, 515, 699, 827, 828, 830, 831,
  767, 750, 801, 802, 106, 233, 291, 236, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  11, 384, 387, 388, 389, 461, 462, 383, 178, 390, 739, 12, 13, 214, 14,
  15, 397, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26, 37, 61, 155, 161, 226,
  394, 395, 396, 463, 464, 546, 158, 231, 733, 749, 17, 27, 28, 29, 30,
  31, 34, 35, 36, 32, 201, 351, 495, 154, 391, 349, 350, 512, 513, 800,
  256, 50, 416, 422, 417, 418, 419, 420, 421, 109, 400, 401, 402, 403,
  467, 468, 469, 100, 142, 556, 409, 410, 411, 412, 95, 408, 414, 542,
  405, 510, 406, 768, 407, 432, 433, 434, 435, 436, 514, 431, 446, 447,
  448, 449, 455, 456, 457, 62, 63, 64, 393, 450, 451, 452, 453, 454, 498,
  499, 500, 501, 502, 503, 504, 505, 506, 507, 509, 465, 466, 771, 508,
  72, 372, 413, 425, 415, 66, 438, 439, 474, 475, 146, 517, 518, 193, 204,
  516, 108, 122, 133, 215, 152, 191, 192, 179, 151, 110, 111, 701, 702,
  112, 113, 114, 115, 195, 825, 829, 120, 141, 153, 156, 180, 182, 183,
  184, 194, 196, 199, 200, 232, 772, 803, 757, 121, 212, 660, 661, 662,
  663, 758, 665, 666, 667, 668, 807, 658, 131, 305, 472, 476, 60, 479,
  473, 804, 87, 481, 482, 477, 478, 44, 445, 74, 484, 75, 485, 82, 486,
  107, 487, 488, 717, 443, 493, 715, 718, 159, 471, 162, 149, 437, 220,
  440, 444, 712, 713, 714, 213, 441, 483, 809, 98, 130, 188, 221, 125,
  189, 190, 207, 219, 135, 136, 206, 208, 209, 703, 721, 616, 761, 173,
  174, 181, 187, 808, 54, 55, 52, 53, 489, 57, 58, 59, 56, 229, 227, 228,
  442, 480, 492, 171, 85, 143, 148, 304, 306, 307, 303, 314, 315, 316,
  317, 318, 328, 341, 202, 322, 323, 324, 544, 140, 398, 399, 197, 198,
  144, 785, 720, 722, 723, 724, 719, 167, 65, 119, 168, 169, 170, 176,
  177, 523, 805, 819, 821, 822, 823, 824, 835
].freeze

JOHTO_MAP_IDS = [
  47, 49, 137, 138, 230, 235, 237, 238, 239, 240, 241, 242, 243, 244, 245,
  246, 247, 248, 249, 250, 251, 254, 255, 258, 259, 260, 261, 262, 263,
  264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277,
  278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 292, 293,
  294, 296, 297, 298, 299, 300, 301, 302, 308, 309, 310, 311, 312, 313,
  319, 320, 321, 325, 326, 327, 329, 330, 331, 332, 333, 334, 335, 336,
  337, 338, 339, 340, 342, 343, 344, 345, 346, 347, 348, 352, 353, 354,
  359, 360, 363, 364, 365, 366, 367, 368, 370, 377, 404, 426, 519, 520,
  521, 522, 524, 535, 536, 537, 538, 539, 540, 541, 545, 547, 548, 549,
  571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584,
  585, 586, 587, 588, 589, 590, 591, 592, 611, 631, 632, 635, 636, 637,
  638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 650, 651,
  652, 653, 670, 671, 672, 673, 674, 675, 676, 677, 692, 693, 694, 695,
  696, 697, 698, 709, 716, 730, 769, 770, 788, 832, 834, 836, 837, 838,
  839, 840, 841, 842, 843, 844, 845, 846, 847, 848, 849
].freeze

KANTO_SET = KANTO_MAP_IDS.to_a.freeze
JOHTO_SET = JOHTO_MAP_IDS.to_a.freeze

# Compatible types: allow cross-type matching for similar categories
COMPATIBLE_TYPES = {
  "interior" => ["interior", "special"],
  "special"  => ["special", "interior"],
  "cave"     => ["cave", "dungeon"],
  "dungeon"  => ["dungeon", "cave"],
  "outdoor_city"  => ["outdoor_city"],
  "outdoor_route" => ["outdoor_route"],
}.freeze

# Large/visible map types get priority for unique Johto assignment
PRIORITY_TYPES = %w[outdoor_route outdoor_city cave dungeon].freeze

# Max dimensions for a "small interior" eligible for self-mapping
SMALL_INTERIOR_MAX_WIDTH  = 25
SMALL_INTERIOR_MAX_HEIGHT = 20

def small_interior?(map_entry)
  t = (map_entry["type"] || "").to_s
  return false unless t == "interior" || t.include?("indoor")
  w = map_entry["width"]  || 0
  h = map_entry["height"] || 0
  w <= SMALL_INTERIOR_MAX_WIDTH && h <= SMALL_INTERIOR_MAX_HEIGHT
end

# ---------------------------------------------------------------------------
# Tileset category heuristic
# ---------------------------------------------------------------------------

TILESET_CATEGORIES = {
  "outdoor" => %w[outdoor_city outdoor_route outdoor_town outdoor_special],
  "indoor"  => %w[interior indoor indoor_house indoor_shop indoor_gym indoor_pokecenter
                   indoor_generic indoor_building indoor_lab indoor_mansion],
  "cave"    => %w[cave cave_floor dungeon underground],
  "special" => %w[special battle title_screen cutscene]
}.freeze

def tileset_category(map_type)
  TILESET_CATEGORIES.each do |cat, types|
    return cat if types.include?(map_type)
  end
  # Fallback: derive from the type string itself
  return "outdoor" if map_type.to_s.include?("outdoor") || map_type.to_s.include?("route")
  return "indoor"  if map_type.to_s.include?("indoor") || map_type.to_s.include?("interior")
  return "cave"    if map_type.to_s.include?("cave") || map_type.to_s.include?("dungeon")
  "other"
end

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def score_pair(kanto, johto)
  breakdown = {}

  # Dimension similarity (0-40)
  dim_diff = (kanto["width"] - johto["width"]).abs + (kanto["height"] - johto["height"]).abs
  breakdown["dimensions"] = [40 - dim_diff * 2, 0].max

  # Tileset match (0-20)
  if kanto["tileset_id"] == johto["tileset_id"]
    breakdown["tileset"] = 20
  elsif tileset_category(kanto["type"]) == tileset_category(johto["type"])
    breakdown["tileset"] = 10
  else
    breakdown["tileset"] = 0
  end

  # Walkability similarity (0-20)
  walk_diff = ((kanto["walkable_tile_pct"] || 50.0) - (johto["walkable_tile_pct"] || 50.0)).abs
  breakdown["walkability"] = [20 - walk_diff, 0].max.round(1)

  # Event capacity (0-20)
  kanto_events = kanto["event_count"] || 0
  johto_walkable = (johto["walkable_tile_pct"] || 50.0) * johto["width"] * johto["height"] / 100.0
  if kanto_events == 0 || johto_walkable >= kanto_events
    breakdown["capacity"] = 20
  else
    ratio = johto_walkable / [kanto_events, 1].max
    breakdown["capacity"] = [20 * ratio, 0].max.round(1)
  end

  # NPC count similarity bonus (0-10)
  k_npc = kanto["npc_count"] || 0
  j_npc = johto["npc_count"] || 0
  npc_diff = (k_npc - j_npc).abs
  breakdown["npc_similarity"] = [10 - npc_diff, 0].max

  # Type match bonus (0-10) — exact type match gets a bonus
  if kanto["type"] == johto["type"]
    breakdown["type_match"] = 10
  else
    breakdown["type_match"] = 0
  end

  total = breakdown.values.inject(0) { |s, v| s + v }.round(1)
  [total, breakdown]
end

# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

TYPE_DISPLAY_ORDER = %w[
  outdoor_city outdoor_town outdoor_route outdoor_special
  indoor_house indoor_shop indoor_gym indoor_pokecenter indoor_generic
  indoor_building indoor_lab indoor_mansion
  cave cave_floor dungeon underground
  special battle
].freeze

def type_group(t)
  return "Cities & Towns"   if t =~ /outdoor_city|outdoor_town/
  return "Routes"           if t =~ /outdoor_route/
  return "Outdoor Other"    if t =~ /outdoor/
  return "Interiors"        if t =~ /indoor|interior/
  return "Caves & Dungeons" if t =~ /cave|dungeon|underground/
  "Other"
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main
  if ARGV.empty?
    $stderr.puts "Usage: ruby tools/match_maps.rb <classification.json> [output.json] [--max-reuse N]"
    exit 1
  end

  # Parse arguments
  max_reuse_arg = 3
  positional = []
  i = 0
  while i < ARGV.length
    if ARGV[i] == "--max-reuse"
      i += 1
      max_reuse_arg = (ARGV[i] || "3").to_i
    else
      positional << ARGV[i]
    end
    i += 1
  end

  input_path  = positional[0]
  output_path = positional[1] || "map_matches.json"

  unless input_path
    $stderr.puts "Usage: ruby tools/match_maps.rb <classification.json> [output.json] [--max-reuse N]"
    exit 1
  end

  data = JSON.parse(File.read(input_path))
  all_maps = data["maps"]

  # Index by map_id
  map_index = {}
  all_maps.each { |m| map_index[m["map_id"]] = m }

  kanto_maps = KANTO_SET.map { |id| map_index[id] }.compact
  johto_maps = JOHTO_SET.map { |id| map_index[id] }.compact

  # Group Johto by type for efficient lookup
  johto_by_type = {}
  johto_maps.each do |jm|
    t = jm["type"] || "unknown"
    (johto_by_type[t] ||= []) << jm
  end

  # ---------------------------------------------------------------------------
  # Step 1 & 2: For each Kanto map, score all Johto maps of the same type
  # ---------------------------------------------------------------------------

  # candidates[kanto_id] = [ {johto_map, score, breakdown}, ... ] sorted desc
  candidates = {}

  kanto_maps.each do |km|
    kt = km["type"] || "unknown"
    compatible = COMPATIBLE_TYPES[kt] || [kt]
    pool = compatible.flat_map { |t| johto_by_type[t] || [] }.uniq
    scored = pool.map do |jm|
      total, breakdown = score_pair(km, jm)
      { "johto" => jm, "score" => total, "breakdown" => breakdown }
    end
    scored.sort_by! { |s| -s["score"] }
    candidates[km["map_id"]] = scored
  end

  # ---------------------------------------------------------------------------
  # Step 3: Top-3 per Kanto map (stored for the output)
  # ---------------------------------------------------------------------------

  top3 = {}
  candidates.each do |kid, list|
    top3[kid] = list.first(3)
  end

  # ---------------------------------------------------------------------------
  # Step 4: Global greedy assignment (two-pass: unique first, then reuse)
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Pre-pass: Self-map small interiors to preserve Johto maps for large areas
  # ---------------------------------------------------------------------------
  used_johto = {}        # johto_id => count of times used
  assignments = {}       # kanto_id => {johto, score, breakdown}
  self_mapped_count = 0

  kanto_maps_for_matching = []
  kanto_maps.each do |km|
    if small_interior?(km)
      assignments[km["map_id"]] = {
        "johto" => km,  # self-reference
        "score" => 0,
        "breakdown" => {},
        "self_mapped" => true
      }
      self_mapped_count += 1
    else
      kanto_maps_for_matching << km
    end
  end

  $stderr.puts "  Self-mapped #{self_mapped_count} small interiors (keeping original Kanto tiles)"

  # Sort remaining Kanto maps: priority types (large/visible) first, then by event_count descending
  sorted_kanto = kanto_maps_for_matching.sort_by do |km|
    priority = PRIORITY_TYPES.include?(km["type"]) ? 0 : 1
    [priority, -(km["event_count"] || 0)]
  end

  first_pass_unmatched = []

  # Pass 1: Unique 1:1 matching (each Johto map used at most once)
  sorted_kanto.each do |km|
    kid = km["map_id"]
    best = nil
    (candidates[kid] || []).each do |c|
      jid = c["johto"]["map_id"]
      next if used_johto[jid]
      best = c
      break
    end

    if best && best["score"] >= 10
      assignments[kid] = best
      used_johto[best["johto"]["map_id"]] = (used_johto[best["johto"]["map_id"]] || 0) + 1
    else
      first_pass_unmatched << km
    end
  end

  # Pass 2: Allow reuse of Johto maps for remaining unmatched Kanto maps
  # A Johto map can be reused if it's a good enough fit (score >= 10)
  # Total usage (pass 1 + pass 2) is capped at max_reuse
  second_pass_unmatched = []
  max_reuse = max_reuse_arg  # configurable via --max-reuse (default 3)

  first_pass_unmatched.each do |km|
    kid = km["map_id"]
    best = nil
    (candidates[kid] || []).each do |c|
      jid = c["johto"]["map_id"]
      total_use = used_johto[jid] || 0
      next if total_use >= max_reuse
      best = c
      break
    end

    if best && best["score"] >= 10
      assignments[kid] = best.merge("reused" => true)
      jid = best["johto"]["map_id"]
      used_johto[jid] = (used_johto[jid] || 0) + 1
    else
      second_pass_unmatched << km
    end
  end

  # Remaining unmatched maps after pass 1 + 2
  unmatched = second_pass_unmatched

  # ---------------------------------------------------------------------------
  # Build output
  # ---------------------------------------------------------------------------

  matches_out = []
  sorted_kanto.each do |km|
    kid = km["map_id"]
    next unless assignments[kid]
    a = assignments[kid]
    jm = a["johto"]

    if a["self_mapped"]
      matches_out << {
        "kanto_map_id"      => kid,
        "kanto_name"        => km["name"],
        "kanto_type"        => km["type"],
        "kanto_dims"        => "#{km["width"]}x#{km["height"]}",
        "assigned_johto_id" => kid,
        "self_mapped"       => true,
        "score"             => 0,
        "reason"            => "small interior kept as original Kanto"
      }
    else
      alts = (top3[kid] || []).select { |c| c["johto"]["map_id"] != jm["map_id"] }.first(2)
      alt_out = alts.map do |c|
        { "johto_id" => c["johto"]["map_id"],
          "name"     => c["johto"]["name"],
          "score"    => c["score"] }
      end

      matches_out << {
        "kanto_map_id"    => kid,
        "kanto_name"      => km["name"],
        "kanto_type"      => km["type"],
        "kanto_dims"      => "#{km["width"]}x#{km["height"]}",
        "assigned_johto_id" => jm["map_id"],
        "johto_name"      => jm["name"],
        "johto_type"      => jm["type"],
        "johto_dims"      => "#{jm["width"]}x#{jm["height"]}",
        "score"           => a["score"],
        "score_breakdown" => a["breakdown"],
        "reused"          => a["reused"] ? true : false,
        "alternatives"    => alt_out
      }
    end
  end

  unmatched_out = unmatched.map do |km|
    reason = if (candidates[km["map_id"]] || []).empty?
               "no Johto candidate with matching type"
             else
               "no viable Johto candidate (best score < 10 or all taken)"
             end
    { "map_id" => km["map_id"], "name" => km["name"], "type" => km["type"], "reason" => reason }
  end

  unique_johto_used = used_johto.keys
  unused_johto_ids = JOHTO_SET - unique_johto_used
  unused_out = unused_johto_ids.map do |jid|
    jm = map_index[jid]
    if jm
      { "map_id" => jid, "name" => jm["name"] }
    else
      { "map_id" => jid, "name" => "(not in classification)" }
    end
  end

  reused_count = assignments.count { |_, a| a["reused"] }
  unique_match_count = assignments.size - reused_count - self_mapped_count

  # Compute reuse distribution: {count => num_johto_maps}
  reuse_distribution = {}
  used_johto.each do |_jid, cnt|
    reuse_distribution[cnt] = (reuse_distribution[cnt] || 0) + 1
  end
  # Sort by key for readability
  reuse_distribution = reuse_distribution.sort_by { |k, _| k }.inject({}) { |h, (k, v)| h[k.to_s] = v; h }

  max_reuse_count = used_johto.values.max || 0

  result = {
    "generated_at" => Time.now.utc.iso8601,
    "summary" => {
      "kanto_maps_total"     => kanto_maps.size,
      "kanto_maps_matched"   => assignments.size,
      "kanto_maps_unique"    => unique_match_count,
      "kanto_maps_reused"    => reused_count,
      "kanto_maps_self_mapped" => self_mapped_count,
      "kanto_maps_unmatched" => unmatched.size,
      "johto_maps_used"      => unique_johto_used.size,
      "johto_maps_unused"    => unused_out.size,
      "max_reuse_count"      => max_reuse_count,
      "self_mapped_count"    => self_mapped_count,
      "reuse_distribution"   => reuse_distribution
    },
    "matches"        => matches_out,
    "unmatched_kanto" => unmatched_out,
    "unused_johto"   => unused_out
  }

  File.open(output_path, 'w') { |f| f.write(JSON.pretty_generate(result)) }
  $stderr.puts "Wrote #{output_path}"

  # ---------------------------------------------------------------------------
  # Human-readable summary to STDOUT
  # ---------------------------------------------------------------------------

  puts "=" * 72
  puts "  MAP MATCHING SUMMARY"
  puts "=" * 72
  puts
  puts "  Kanto maps in scope:   #{kanto_maps.size}"
  puts "  Successfully matched:  #{assignments.size}"
  puts "    - Unique (1:1):      #{unique_match_count}"
  puts "    - Reused Johto map:  #{reused_count}"
  puts "    - Self-mapped:       #{self_mapped_count}"
  puts "  Unmatched (review):    #{unmatched.size}"
  puts "  Johto maps used:       #{unique_johto_used.size}"
  puts "  Johto maps unused:     #{unused_out.size}"
  puts "  Max reuse count:       #{max_reuse_count}"
  puts "  Max reuse cap:         #{max_reuse}"
  puts
  puts "  Reuse distribution:"
  reuse_distribution.each do |count, num|
    puts "    #{count}x used: #{num} Johto maps"
  end
  puts

  # Group matches by display group
  grouped = {}
  matches_out.each do |m|
    g = type_group(m["kanto_type"].to_s)
    (grouped[g] ||= []) << m
  end

  display_order = ["Cities & Towns", "Routes", "Outdoor Other",
                   "Interiors", "Caves & Dungeons", "Other"]

  display_order.each do |group_name|
    list = grouped[group_name]
    next unless list && !list.empty?

    puts "-" * 72
    puts "  #{group_name} (#{list.size} maps)"
    puts "-" * 72

    list.sort_by { |m| -m["score"] }.each do |m|
      printf "  [%3d] %-30s (%s) => [%3d] %-30s  score: %.0f\n",
             m["kanto_map_id"],
             truncate(m["kanto_name"], 30),
             m["kanto_dims"],
             m["assigned_johto_id"],
             truncate(m["johto_name"], 30),
             m["score"]
    end
    puts
  end

  # Show self-mapped entries
  self_mapped_entries = matches_out.select { |m| m["self_mapped"] }
  unless self_mapped_entries.empty?
    puts "-" * 72
    puts "  Self-mapped small interiors (#{self_mapped_entries.size} maps)"
    puts "-" * 72
    self_mapped_entries.each do |m|
      printf "  [%3d] %-30s (%s)  => kept as original Kanto\n",
             m["kanto_map_id"],
             truncate(m["kanto_name"], 30),
             m["kanto_dims"]
    end
    puts
  end

  unless unmatched.empty?
    puts "-" * 72
    puts "  UNMATCHED KANTO MAPS (manual review needed): #{unmatched.size}"
    puts "-" * 72
    unmatched.each do |km|
      printf "  [%3d] %-30s  type: %-20s  events: %d\n",
             km["map_id"],
             truncate(km["name"], 30),
             km["type"],
             km["event_count"] || 0
    end
    puts
  end

  puts "=" * 72
end

def truncate(str, max)
  str = str.to_s
  str.length > max ? str[0, max - 3] + "..." : str
end

main
