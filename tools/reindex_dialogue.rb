#!/usr/bin/env ruby
# reindex_dialogue.rb — Fix start_index values in dialogue JSON files
# by reading the actual game data and finding where text commands really are.
#
# Usage:
#   ruby reindex_dialogue.rb <data_dir> <changes.json> [--write]
#
# Without --write, shows what would change (dry run).
# With --write, updates the JSON file in place.
#
# This tool fixes the common issue where dialogue JSON files have
# incorrect start_index values that don't match the actual event
# command positions in the game's .rxdata files.

require "json"
require_relative "rpgmaker_stubs"

SEARCH_RANGE = 30

def pb_message_call?(cmd)
  cmd && cmd.code == 355 &&
    cmd.parameters[0].to_s =~ /(?:Kernel\.)?(?:pbMessage|pbMsg)\s*\(/i
end

# Collect all "text-like" command positions in a command list.
# Returns array of {index:, type:, code:, preview:}
def collect_text_positions(command_list)
  positions = []
  i = 0
  while i < command_list.length
    cmd = command_list[i]
    if cmd.code == 101
      preview = cmd.parameters[0].to_s[0..60]
      positions << { index: i, type: "text", code: 101, preview: preview }
      # Skip continuation lines
      i += 1
      i += 1 while i < command_list.length && command_list[i].code == 401
    elsif pb_message_call?(cmd)
      preview = cmd.parameters[0].to_s[0..60]
      positions << { index: i, type: "text", code: 355, preview: preview }
      i += 1
      i += 1 while i < command_list.length && command_list[i].code == 655
    elsif cmd.code == 102
      preview = (cmd.parameters[0] || []).join(", ")[0..60]
      positions << { index: i, type: "choices", code: 102, preview: preview }
      i += 1
    elsif cmd.code == 355
      preview = cmd.parameters[0].to_s[0..60]
      positions << { index: i, type: "script", code: 355, preview: preview }
      i += 1
      i += 1 while i < command_list.length && command_list[i].code == 655
    else
      i += 1
    end
  end
  positions
end

def find_nearest(actual_positions, target_index, target_type)
  # Filter to matching type
  candidates = actual_positions.select do |pos|
    case target_type
    when "text"
      pos[:type] == "text" # matches both code 101 and pbMessage 355
    when "choices"
      pos[:type] == "choices"
    when "script_message"
      pos[:type] == "script" || (pos[:type] == "text" && pos[:code] == 355)
    else
      false
    end
  end

  return nil if candidates.empty?

  # Find nearest by distance
  candidates.min_by { |pos| (pos[:index] - target_index).abs }
end

def main
  data_dir = ARGV[0]
  changes_file = ARGV[1]
  write_mode = ARGV.include?("--write")

  unless data_dir && changes_file
    $stderr.puts "Usage: ruby reindex_dialogue.rb <data_dir> <changes.json> [--write]"
    $stderr.puts ""
    $stderr.puts "Fixes start_index values in dialogue JSON to match actual game data."
    $stderr.puts "Run without --write first to preview changes."
    exit 1
  end

  unless Dir.exist?(data_dir)
    $stderr.puts "Error: Data directory not found: #{data_dir}"
    exit 1
  end

  unless File.exist?(changes_file)
    $stderr.puts "Error: Changes file not found: #{changes_file}"
    exit 1
  end

  changes = JSON.parse(File.read(changes_file))
  maps = changes["maps"] || {}

  total_fixed = 0
  total_ok = 0
  total_unfixable = 0
  any_changes = false

  maps.each do |map_id_str, map_changes|
    map_id = map_id_str.to_i
    map_file = File.join(data_dir, "Map%03d.rxdata" % map_id)

    unless File.exist?(map_file)
      $stderr.puts "Warning: #{map_file} not found, skipping"
      next
    end

    map = Marshal.load(File.binread(map_file))
    $stderr.puts "Map#{"%03d" % map_id} (#{map_changes["name"] || "?"}):"

    (map_changes["events"] || {}).each do |event_id_str, event_changes|
      event_id = event_id_str.to_i
      event = map.events[event_id]

      unless event
        $stderr.puts "  Event #{event_id}: NOT FOUND in map"
        total_unfixable += 1
        next
      end

      (event_changes["pages"] || {}).each do |page_idx_str, page_changes|
        page_idx = page_idx_str.to_i
        page = event.pages[page_idx]

        unless page
          $stderr.puts "  Event #{event_id} Page #{page_idx}: NOT FOUND"
          total_unfixable += 1
          next
        end

        actual_positions = collect_text_positions(page.list)

        # Track which actual positions have been claimed (for dedup)
        claimed = {}

        (page_changes["dialogue_blocks"] || []).each do |block|
          block_type = block["type"]
          old_index = block["start_index"]

          # Skip non-text block types (insert_commands, replace_commands)
          unless ["text", "choices", "script_message"].include?(block_type)
            next
          end

          # Check if the current index is already correct
          cmd = page.list[old_index] if old_index >= 0 && old_index < page.list.length
          correct = case block_type
                    when "text"
                      cmd && (cmd.code == 101 || pb_message_call?(cmd))
                    when "choices"
                      cmd && cmd.code == 102
                    when "script_message"
                      cmd && cmd.code == 355
                    else
                      false
                    end

          if correct && !claimed[old_index]
            claimed[old_index] = true
            total_ok += 1
            next
          end

          # Find the nearest unclaimed matching command
          best = nil
          best_distance = SEARCH_RANGE + 1

          actual_positions.each do |pos|
            next if claimed[pos[:index]]

            matches = case block_type
                      when "text"
                        pos[:type] == "text"
                      when "choices"
                        pos[:type] == "choices"
                      when "script_message"
                        pos[:code] == 355
                      else
                        false
                      end

            if matches
              distance = (pos[:index] - old_index).abs
              if distance < best_distance
                best = pos
                best_distance = distance
              end
            end
          end

          if best && best_distance <= SEARCH_RANGE
            claimed[best[:index]] = true
            if best[:index] != old_index
              $stderr.puts "  Event #{event_id} Page #{page_idx}: #{block_type} index #{old_index} -> #{best[:index]} (#{best[:preview][0..40]})"
              block["start_index"] = best[:index]
              total_fixed += 1
              any_changes = true
            else
              total_ok += 1
            end
          else
            $stderr.puts "  Event #{event_id} Page #{page_idx}: #{block_type} index #{old_index} -> NO MATCH FOUND"
            total_unfixable += 1
          end
        end
      end
    end
  end

  $stderr.puts ""
  $stderr.puts "=== Reindex Summary ==="
  $stderr.puts "Already correct: #{total_ok}"
  $stderr.puts "Fixed:           #{total_fixed}"
  $stderr.puts "Unfixable:       #{total_unfixable}"

  if any_changes && write_mode
    File.write(changes_file, JSON.pretty_generate(changes))
    $stderr.puts ""
    $stderr.puts "Updated: #{changes_file}"
  elsif any_changes && !write_mode
    $stderr.puts ""
    $stderr.puts "Run with --write to apply these fixes:"
    $stderr.puts "  ruby #{$0} #{ARGV[0]} #{ARGV[1]} --write"
  end
end

main
