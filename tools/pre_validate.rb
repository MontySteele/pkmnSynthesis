#!/usr/bin/env ruby
# encoding: utf-8
# pre_validate.rb - Check that event IDs, page indices, and start_indices
# referenced in dialogue JSONs actually exist in the real game data.
#
# Usage: ruby tools/pre_validate.rb <data_dir> <json_file> [<json_file> ...]

require "json"
require_relative "rpgmaker_stubs"

data_dir = ARGV.shift
json_files = ARGV

unless data_dir && Dir.exist?(data_dir) && json_files.any?
  $stderr.puts "Usage: ruby tools/pre_validate.rb <data_dir> <json_file> [...]"
  exit 1
end

total_ok = 0
total_fail = 0
total_warn = 0

json_files.each do |json_file|
  fname = File.basename(json_file)
  data = JSON.parse(File.read(json_file))

  (data["maps"] || {}).each do |map_id_str, map_data|
    next if map_id_str.start_with?("_")
    map_id = map_id_str.to_i
    map_file = File.join(data_dir, "Map%03d.rxdata" % map_id)

    unless File.exist?(map_file)
      puts "MISS  #{fname} Map%03d -- .rxdata not found!" % map_id
      total_fail += 1
      next
    end

    map = Marshal.load(File.binread(map_file))

    (map_data["events"] || {}).each do |event_id_str, event_data|
      event_id = event_id_str.to_i

      unless map.events[event_id]
        puts "FAIL  #{fname} Map%03d E#{event_id} -- event does not exist" % map_id
        total_fail += 1
        next
      end

      event = map.events[event_id]

      (event_data["pages"] || {}).each do |page_idx_str, page_data|
        page_idx = page_idx_str.to_i

        unless event.pages[page_idx]
          puts "FAIL  #{fname} Map%03d E#{event_id} P#{page_idx} -- page does not exist (#{event.pages.length} pages)" % map_id
          total_fail += 1
          next
        end

        page = event.pages[page_idx]
        cmd_count = page.list ? page.list.length : 0

        (page_data["dialogue_blocks"] || []).each_with_index do |block, bi|
          idx = block["start_index"]
          if idx && idx >= cmd_count
            puts "WARN  #{fname} Map%03d E#{event_id} P#{page_idx} B#{bi} -- start_index #{idx} >= command count #{cmd_count}" % map_id
            total_warn += 1
          else
            total_ok += 1
          end
        end
      end
    end
  end
end

puts ""
puts "=" * 60
puts "Pre-injection validation (event/page/index existence)"
puts "=" * 60
puts "  OK:    #{total_ok}"
puts "  WARN:  #{total_warn}  (start_index out of bounds)"
puts "  FAIL:  #{total_fail}  (missing map/event/page)"
puts "  TOTAL: #{total_ok + total_warn + total_fail}"
puts "=" * 60

exit(total_fail > 0 ? 1 : 0)
