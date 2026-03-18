# encoding: utf-8
#!/usr/bin/env ruby
# tools/validate_conflicts.rb
#
# Checks all dialogue_changes/*.json files for conflicts:
# 1. Same map+event+page+start_index targeted by multiple files
# 2. Overlapping replace_commands ranges
# 3. insert_commands at same index from different files
#
# Usage: ruby tools/validate_conflicts.rb

require 'json'
require 'set'

dialogue_dir = File.join(File.dirname(__FILE__), "..", "dialogue_changes")

# Collect all targets: { "MapID:EventID:PageID:Index" => [file, type] }
targets = Hash.new { |h, k| h[k] = [] }
replace_ranges = Hash.new { |h, k| h[k] = [] }  # "MapID:EventID:PageID" => [[start, end, file]]

errors = []
warnings = []

Dir.glob(File.join(dialogue_dir, "*.json")).sort.each do |f|
  fname = File.basename(f)
  begin
    data = JSON.parse(File.read(f))
  rescue JSON::ParserError => e
    errors << "#{fname}: Invalid JSON - #{e.message}"
    next
  end

  maps = data["maps"] || {}
  maps.each do |map_id, map_data|
    events = map_data["events"] || {}
    events.each do |event_id, event_data|
      pages = event_data["pages"] || {}
      pages.each do |page_id, page_data|
        blocks = page_data["dialogue_blocks"] || []
        blocks.each do |block|
          idx = block["start_index"]
          type = block["type"]
          key = "Map#{map_id}:E#{event_id}:P#{page_id}:idx#{idx}"

          targets[key] << [fname, type]

          if type == "replace_commands" || type == "insert_commands"
            end_idx = block["end_index"] || idx
            range_key = "Map#{map_id}:E#{event_id}:P#{page_id}"
            replace_ranges[range_key] << [idx, end_idx, fname, type]
          end
        end
      end
    end
  end
end

# Check for duplicate targets
puts "=== Cross-File Target Conflicts ==="
conflict_count = 0
targets.each do |key, sources|
  if sources.length > 1
    conflict_count += 1
    files = sources.map { |f, t| "#{f} (#{t})" }.join(", ")
    errors << "CONFLICT at #{key}: targeted by #{files}"
  end
end
puts conflict_count == 0 ? "  No conflicts found" : "  #{conflict_count} conflicts found"

# Check for overlapping ranges
puts "\n=== Overlapping Command Ranges ==="
overlap_count = 0
replace_ranges.each do |key, ranges|
  ranges.sort_by! { |s, e, f, t| s }
  ranges.each_cons(2) do |(s1, e1, f1, t1), (s2, e2, f2, t2)|
    if s2 <= e1  # overlap
      overlap_count += 1
      errors << "OVERLAP at #{key}: #{f1} (#{t1} #{s1}..#{e1}) overlaps #{f2} (#{t2} #{s2}..#{e2})"
    end
  end
end
puts overlap_count == 0 ? "  No overlaps found" : "  #{overlap_count} overlaps found"

# Summary stats
file_count = Dir.glob(File.join(dialogue_dir, "*.json")).length
map_ids = Set.new
targets.each_key { |k| map_ids << k.split(":")[0] }

puts "\n=== Coverage Summary ==="
puts "  #{file_count} dialogue files"
puts "  #{map_ids.length} unique maps targeted"
puts "  #{targets.length} unique target points"

# Check for any map targeted by 3+ files (suspicious)
map_files = Hash.new { |h, k| h[k] = Set.new }
targets.each do |key, sources|
  map_id = key.split(":")[0]
  sources.each { |f, _| map_files[map_id] << f }
end

multi_file_maps = map_files.select { |_, files| files.length >= 3 }
if multi_file_maps.any?
  puts "\n=== Maps With 3+ Source Files (review recommended) ==="
  multi_file_maps.each do |map_id, files|
    puts "  #{map_id}: #{files.to_a.join(', ')}"
  end
end

puts "\n=== RESULT ==="
if errors.empty?
  puts "ALL CLEAR - no conflicts detected"
else
  puts "#{errors.length} issues found:"
  errors.each { |e| puts "  #{e}" }
  exit 1
end
