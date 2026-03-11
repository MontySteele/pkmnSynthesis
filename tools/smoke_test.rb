#!/usr/bin/env ruby
# smoke_test.rb — Broad smoke test and coverage report for dialogue injections.
#
# Usage:
#   ruby tools/smoke_test.rb <data_dir> [dialogue_changes_dir]
#
# Arguments:
#   data_dir             - Path to the Data/ directory containing MapXXX.rxdata
#   dialogue_changes_dir - Directory containing JSON change files (default: dialogue_changes/)
#
# What it does:
#   1. Scans ALL .rxdata map files in the data directory
#   2. For each map, identifies the first event with dialogue on its first page
#      (the "key character") and extracts current text
#   3. If an .originals/ backup directory exists, compares current text against
#      originals to confirm changes were applied (or that unchanged maps are intact)
#   4. Cross-references all dialogue_changes/*.json files to build a coverage report:
#      - Which maps have been modified
#      - Which maps still need work
#      - Total events modified vs total events with dialogue

require "json"
require_relative "rpgmaker_stubs"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_map_safe(path)
  Marshal.load(File.binread(path))
rescue => e
  $stderr.puts "  Warning: Failed to load #{path}: #{e.message}"
  nil
end

# Extract the first text block from the first event page that has dialogue.
# Returns { event_id:, event_name:, text: } or nil.
def find_key_character(map)
  return nil unless map.events

  # Sort by event ID for deterministic results
  map.events.sort_by { |eid, _| eid }.each do |event_id, event|
    next unless event.pages && event.pages.length > 0

    page = event.pages[0]
    next unless page.list

    page.list.each_with_index do |cmd, i|
      if cmd.code == 101
        lines = [cmd.parameters[0].to_s]
        j = i + 1
        while j < page.list.length && page.list[j].code == 401
          lines << page.list[j].parameters[0].to_s
          j += 1
        end
        return {
          event_id: event_id,
          event_name: event.name,
          text: lines.join("\n")
        }
      end
    end
  end

  nil
end

# Count total events with dialogue and total dialogue blocks in a map.
def count_dialogue_in_map(map)
  events_with_dialogue = 0
  total_blocks = 0

  return [0, 0] unless map.events

  map.events.each do |_, event|
    event_has_dialogue = false
    event.pages.each do |page|
      next unless page.list
      page.list.each do |cmd|
        if [101, 102, 355].include?(cmd.code)
          total_blocks += 1
          event_has_dialogue = true
        end
      end
    end
    events_with_dialogue += 1 if event_has_dialogue
  end

  [events_with_dialogue, total_blocks]
end

# Build a set of map IDs and event IDs targeted by all change files.
# Returns: { map_id => { event_ids: Set, block_count: int, file: string } }
def load_change_manifest(changes_dir)
  manifest = {}
  return manifest unless changes_dir && Dir.exist?(changes_dir)

  Dir.glob(File.join(changes_dir, "*.json")).sort.each do |json_file|
    begin
      data = JSON.parse(File.read(json_file))
    rescue JSON::ParserError => e
      $stderr.puts "Warning: Failed to parse #{json_file}: #{e.message}"
      next
    end

    (data["maps"] || {}).each do |map_id_str, map_data|
      next if map_id_str.start_with?("_")
      map_id = map_id_str.to_i

      manifest[map_id] ||= { event_ids: [], block_count: 0, files: [] }
      manifest[map_id][:files] << File.basename(json_file)

      (map_data["events"] || {}).each do |event_id_str, event_data|
        event_id = event_id_str.to_i
        manifest[map_id][:event_ids] << event_id

        (event_data["pages"] || {}).each do |_, page_data|
          manifest[map_id][:block_count] += (page_data["dialogue_blocks"] || []).length
        end
      end

      manifest[map_id][:event_ids].uniq!
    end
  end

  manifest
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main
  data_dir = ARGV[0]
  changes_dir = ARGV[1] || "dialogue_changes"

  unless data_dir && Dir.exist?(data_dir)
    $stderr.puts "Usage: ruby tools/smoke_test.rb <data_dir> [dialogue_changes_dir]"
    $stderr.puts "  data_dir must be the path to the Data/ directory"
    exit 1
  end

  # Try to find an originals backup directory
  originals_dir = nil
  [".originals", "originals", File.join(File.dirname(data_dir), ".originals")].each do |candidate|
    if Dir.exist?(candidate)
      originals_dir = candidate
      break
    end
  end

  # Load map names
  mapinfos_path = File.join(data_dir, "MapInfos.rxdata")
  map_infos = if File.exist?(mapinfos_path)
                Marshal.load(File.binread(mapinfos_path))
              else
                $stderr.puts "Warning: MapInfos.rxdata not found — map names unavailable"
                {}
              end

  # Load change manifest
  manifest = load_change_manifest(changes_dir)

  # Scan all map files
  map_files = Dir.glob(File.join(data_dir, "Map[0-9]*.rxdata"))
                 .reject { |f| f =~ /MapInfos/ }
                 .sort

  puts "Smoke Test: #{map_files.length} maps, #{manifest.keys.length} maps targeted by changes"
  puts "Originals directory: #{originals_dir || '(none — diff checks skipped)'}"
  puts ""

  # Tracking
  maps_modified = []
  maps_unmodified = []
  maps_no_dialogue = []
  maps_with_issues = []
  total_events_with_dialogue = 0
  total_events_modified = 0
  total_dialogue_blocks = 0
  total_blocks_modified = 0

  map_files.each do |map_file|
    map_id = File.basename(map_file, ".rxdata").sub(/^Map0*/, "").to_i
    map_name = map_infos[map_id]&.name || "Unknown"
    map = load_map_safe(map_file)
    next unless map

    events_count, blocks_count = count_dialogue_in_map(map)
    total_events_with_dialogue += events_count
    total_dialogue_blocks += blocks_count

    is_targeted = manifest.key?(map_id)
    key_char = find_key_character(map)

    if events_count == 0
      maps_no_dialogue << { id: map_id, name: map_name }
      next
    end

    if is_targeted
      total_events_modified += manifest[map_id][:event_ids].length
      total_blocks_modified += manifest[map_id][:block_count]
    end

    # Compare against original if available
    diff_status = nil
    if originals_dir
      orig_file = File.join(originals_dir, File.basename(map_file))
      if File.exist?(orig_file)
        orig_map = load_map_safe(orig_file)
        if orig_map
          orig_key = find_key_character(orig_map)

          if is_targeted
            # This map SHOULD have changes
            if key_char && orig_key && key_char[:text] != orig_key[:text]
              diff_status = :changed
            elsif key_char && orig_key && key_char[:text] == orig_key[:text]
              # Key character text unchanged — could be that a different event was modified
              diff_status = :key_char_unchanged
            else
              diff_status = :no_key_char
            end
          else
            # This map should NOT have changes
            if key_char && orig_key && key_char[:text] != orig_key[:text]
              diff_status = :unexpected_change
            else
              diff_status = :intact
            end
          end
        end
      end
    end

    entry = {
      id: map_id,
      name: map_name,
      events_with_dialogue: events_count,
      dialogue_blocks: blocks_count,
      key_char: key_char,
      targeted: is_targeted,
      change_files: is_targeted ? manifest[map_id][:files] : [],
      events_targeted: is_targeted ? manifest[map_id][:event_ids].length : 0,
      blocks_targeted: is_targeted ? manifest[map_id][:block_count] : 0,
      diff_status: diff_status
    }

    if is_targeted
      maps_modified << entry
    else
      maps_unmodified << entry
    end

    if diff_status == :unexpected_change
      maps_with_issues << entry
    end
  end

  # ---- Modified maps report ----
  puts "=" * 70
  puts "MODIFIED MAPS (targeted by dialogue_changes)"
  puts "=" * 70

  if maps_modified.empty?
    puts "  (none)"
  else
    maps_modified.sort_by { |m| m[:id] }.each do |m|
      status = case m[:diff_status]
               when :changed then "CHANGED"
               when :key_char_unchanged then "KEY-CHAR-SAME"
               when :intact then "INTACT"
               when nil then "-"
               else m[:diff_status].to_s.upcase
               end

      puts "  Map%03d %-30s  events: %d/%d  blocks: %d/%d  diff: %-15s  from: %s" % [
        m[:id],
        m[:name],
        m[:events_targeted],
        m[:events_with_dialogue],
        m[:blocks_targeted],
        m[:dialogue_blocks],
        status,
        m[:change_files].join(", ")
      ]

      if m[:key_char]
        preview = m[:key_char][:text].split("\n").first(2).join(" / ")
        preview = preview[0, 70] + "..." if preview.length > 70
        puts "    Key: E#{m[:key_char][:event_id]} (#{m[:key_char][:event_name]}): #{preview}"
      end
    end
  end

  puts ""

  # ---- Issues ----
  if maps_with_issues.any?
    puts "=" * 70
    puts "ISSUES: Maps with unexpected changes"
    puts "=" * 70
    maps_with_issues.each do |m|
      puts "  Map%03d %-30s  — key character text differs from original but no changes JSON targets this map" % [
        m[:id], m[:name]
      ]
    end
    puts ""
  end

  # ---- Unmodified maps with dialogue (sample) ----
  puts "=" * 70
  puts "UNMODIFIED MAPS WITH DIALOGUE (not yet targeted)"
  puts "=" * 70
  remaining = maps_unmodified.sort_by { |m| m[:id] }
  shown = remaining.first(20)
  shown.each do |m|
    status = case m[:diff_status]
             when :intact then "OK"
             when :unexpected_change then "UNEXPECTED-CHANGE"
             when nil then "-"
             else m[:diff_status].to_s.upcase
             end
    puts "  Map%03d %-30s  events: %d  blocks: %d  diff: %s" % [
      m[:id], m[:name], m[:events_with_dialogue], m[:dialogue_blocks], status
    ]
  end
  if remaining.length > 20
    puts "  ... and #{remaining.length - 20} more maps with dialogue"
  end

  puts ""

  # ---- Coverage Report ----
  puts "=" * 70
  puts "COVERAGE REPORT"
  puts "=" * 70
  total_maps_with_dialogue = maps_modified.length + maps_unmodified.length
  pct_maps = total_maps_with_dialogue > 0 ? (maps_modified.length.to_f / total_maps_with_dialogue * 100).round(1) : 0
  pct_events = total_events_with_dialogue > 0 ? (total_events_modified.to_f / total_events_with_dialogue * 100).round(1) : 0
  pct_blocks = total_dialogue_blocks > 0 ? (total_blocks_modified.to_f / total_dialogue_blocks * 100).round(1) : 0

  puts "  Total map files:                #{map_files.length}"
  puts "  Maps with dialogue:             #{total_maps_with_dialogue}"
  puts "  Maps without dialogue:          #{maps_no_dialogue.length}"
  puts "  Maps modified (targeted):       #{maps_modified.length} / #{total_maps_with_dialogue} (#{pct_maps}%)"
  puts "  Events with dialogue:           #{total_events_with_dialogue}"
  puts "  Events modified (targeted):     #{total_events_modified} / #{total_events_with_dialogue} (#{pct_events}%)"
  puts "  Dialogue blocks total:          #{total_dialogue_blocks}"
  puts "  Dialogue blocks modified:       #{total_blocks_modified} / #{total_dialogue_blocks} (#{pct_blocks}%)"
  puts "  Maps with issues:               #{maps_with_issues.length}"
  puts ""

  # ---- Change files summary ----
  if Dir.exist?(changes_dir)
    json_files = Dir.glob(File.join(changes_dir, "*.json")).sort
    puts "  Change files (#{json_files.length}):"
    json_files.each do |f|
      begin
        data = JSON.parse(File.read(f))
        map_count = (data["maps"] || {}).keys.reject { |k| k.start_with?("_") }.length
        puts "    %-35s  maps: %d" % [File.basename(f), map_count]
      rescue
        puts "    %-35s  (parse error)" % File.basename(f)
      end
    end
  end

  puts ""
  puts "=" * 70

  if maps_with_issues.any?
    puts "RESULT: #{maps_with_issues.length} issue(s) found"
    exit 1
  else
    puts "RESULT: OK — no issues detected"
    exit 0
  end
end

main
