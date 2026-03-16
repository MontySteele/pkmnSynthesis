#!/usr/bin/env ruby
# Verify all stamps - check for empty, full-map-sized, or bad stamps

require "json"

STAMPS_DIR = File.join(__dir__, "stamps")

stamps = Dir.glob(File.join(STAMPS_DIR, "*.json")).reject { |f| File.basename(f) == "catalog.json" }
stamps.sort!

puts "=== Stamp Verification Report ==="
puts "Total stamp files: #{stamps.size}"
puts

bad_stamps = []
good_stamps = []

stamps.each do |path|
  name = File.basename(path, ".json")
  data = JSON.parse(File.read(path))

  w = data["width"]
  h = data["height"]
  source = "Map%03d" % data["source_map"]

  # Check if stamp is too large (likely full-map extraction)
  if w > 40 || h > 40
    puts "  [BAD - TOO LARGE] #{name}: #{w}x#{h} from #{source}"
    bad_stamps << path
    next
  end

  # Check if stamp is effectively empty (all zeros on layers 1 and 2)
  l1_nonzero = 0
  l2_nonzero = 0
  data["tiles"]["layer1"]&.each { |row| row.each { |t| l1_nonzero += 1 if t != 0 } }
  data["tiles"]["layer2"]&.each { |row| row.each { |t| l2_nonzero += 1 if t != 0 } }

  total_cells = w * h
  content_ratio = (l1_nonzero + l2_nonzero).to_f / (total_cells * 2)

  if l1_nonzero == 0 && l2_nonzero == 0
    puts "  [BAD - EMPTY] #{name}: #{w}x#{h} from #{source} (no L1/L2 content)"
    bad_stamps << path
    next
  end

  # Check for very low content (< 5% non-zero on L1+L2)
  if content_ratio < 0.03
    puts "  [WARN - LOW CONTENT] #{name}: #{w}x#{h} from #{source} L1=#{l1_nonzero} L2=#{l2_nonzero} (#{(content_ratio*100).round(1)}%)"
    # Don't delete these, just warn
  end

  good_stamps << {
    name: name,
    file: "#{name}.json",
    width: w,
    height: h,
    source_map: data["source_map"],
    source_rect: data["source_rect"],
    l1_tiles: l1_nonzero,
    l2_tiles: l2_nonzero,
    content_ratio: (content_ratio * 100).round(1)
  }

  puts "  [OK] #{name}: #{w}x#{h} from #{source} L1=#{l1_nonzero} L2=#{l2_nonzero}"
end

# Delete bad stamps
if bad_stamps.any?
  puts "\n=== Deleting #{bad_stamps.size} bad stamps ==="
  bad_stamps.each do |path|
    puts "  Deleting #{File.basename(path)}"
    File.delete(path)
  end
end

# Categorize stamps
categories = {
  "pokemon_center" => /pokecenter/,
  "gym" => /gym/,
  "house" => /house|home/,
  "building" => /building|dept|museum|mart|lab|store|shop|condo/,
  "natural" => /tree|grass|garden|flower|route|ledge|terrain|pond|water/,
  "structure" => /fence|sign|lamppost|lamp|post|safari|structure/,
  "misc" => //
}

good_stamps.each do |s|
  cat = "misc"
  categories.each do |c, pattern|
    if s[:name] =~ pattern
      cat = c
      break
    end
  end
  s[:category] = cat
end

# Write updated catalog
catalog = {
  generated_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00"),
  total_stamps: good_stamps.size,
  stamps: good_stamps.map { |s|
    { name: s[:name], file: s[:file], width: s[:width], height: s[:height],
      source_map: s[:source_map], category: s[:category] }
  }.sort_by { |s| [s[:category], s[:name]] }
}

File.write(File.join(STAMPS_DIR, "catalog.json"), JSON.pretty_generate(catalog))

puts "\n=== Summary ==="
puts "Good stamps: #{good_stamps.size}"
puts "Deleted: #{bad_stamps.size}"
puts "\nBy category:"
good_stamps.group_by { |s| s[:category] }.sort.each do |cat, stamps|
  puts "  #{cat}: #{stamps.size}"
  stamps.sort_by { |s| s[:name] }.each do |s|
    puts "    #{s[:name]} (#{s[:width]}x#{s[:height]}) from Map%03d" % s[:source_map]
  end
end
