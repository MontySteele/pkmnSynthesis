#!/usr/bin/env ruby
# validate_injection.rb — Validates that dialogue injections were applied correctly.
#
# Usage:
#   ruby tools/validate_injection.rb <data_dir> <changes.json>
#
# Arguments:
#   data_dir     - Path to the Data/ directory containing MapXXX.rxdata files
#   changes.json - JSON file describing the expected dialogue state (same format
#                  as inject_dialogue.rb input)
#
# For every dialogue_block in the JSON, this tool verifies:
#   - The target event and page exist
#   - The command at start_index has the expected code (101, 102, 355)
#   - Text lines, choices, and continuation lines match the JSON
#   - For insert_commands blocks: the inserted commands are present at the
#     right position with the right codes and parameters
#
# Exit code 0 if all checks pass, 1 if any fail.

require "json"
require_relative "rpgmaker_stubs"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_map(data_dir, map_id)
  path = File.join(data_dir, "Map%03d.rxdata" % map_id)
  return nil unless File.exist?(path)
  Marshal.load(File.binread(path))
end

def load_common_events(data_dir)
  path = File.join(data_dir, "CommonEvents.rxdata")
  return nil unless File.exist?(path)
  Marshal.load(File.binread(path))
end

# ---------------------------------------------------------------------------
# Validators for each block type
# ---------------------------------------------------------------------------

def validate_text_block(command_list, block, label)
  issues = []
  idx = block["start_index"]
  lines = block["lines"]
  expected_first = lines[0].to_s

  # After injection, indices may have shifted due to line-count changes at other
  # blocks. Search for the expected text near the original index (within +/-30).
  actual_idx = nil
  search_range = [0, idx - 30].max...[command_list.length, idx + 30].min
  search_range.each do |i|
    cmd = command_list[i]
    if cmd.code == 101 && cmd.parameters[0].to_s == expected_first
      actual_idx = i
      break
    end
  end

  unless actual_idx
    issues << "Text not found near index #{idx}: expected #{expected_first.inspect}"
    return issues
  end

  # Check continuation lines (401)
  continuation_count = 0
  j = actual_idx + 1
  while j < command_list.length && command_list[j].code == 401
    continuation_count += 1
    j += 1
  end

  expected_continuations = lines.length - 1
  if continuation_count != expected_continuations
    issues << "Expected #{expected_continuations} continuation lines (401) after index #{actual_idx}, found #{continuation_count}"
  end

  # Verify each continuation line text
  [continuation_count, expected_continuations].min.times do |li|
    actual = command_list[actual_idx + 1 + li].parameters[0].to_s
    expected = lines[1 + li].to_s
    if actual != expected
      issues << "Line #{1 + li} mismatch at index #{actual_idx + 1 + li}: expected #{expected.inspect}, got #{actual.inspect}"
    end
  end

  issues
end

def validate_choice_block(command_list, block, label)
  issues = []
  idx = block["start_index"]

  if idx >= command_list.length
    issues << "start_index #{idx} out of range (command list length #{command_list.length})"
    return issues
  end

  cmd = command_list[idx]
  if cmd.code != 102
    issues << "Expected code 102 at index #{idx}, found #{cmd.code}"
    return issues
  end

  expected_choices = block["choices"]
  actual_choices = cmd.parameters[0]

  if actual_choices != expected_choices
    issues << "Choices mismatch at index #{idx}: expected #{expected_choices.inspect}, got #{actual_choices.inspect}"
  end

  if block.key?("cancel_type")
    actual_cancel = cmd.parameters[1]
    if actual_cancel != block["cancel_type"]
      issues << "cancel_type mismatch at index #{idx}: expected #{block["cancel_type"]}, got #{actual_cancel}"
    end
  end

  issues
end

def validate_script_message_block(command_list, block, label)
  issues = []
  idx = block["start_index"]
  lines = block["lines"]

  if idx >= command_list.length
    issues << "start_index #{idx} out of range (command list length #{command_list.length})"
    return issues
  end

  cmd = command_list[idx]
  if cmd.code != 355
    issues << "Expected code 355 at index #{idx}, found #{cmd.code}"
    return issues
  end

  # Check first line
  actual_first = cmd.parameters[0].to_s
  expected_first = lines[0].to_s
  if actual_first != expected_first
    issues << "Line 0 mismatch at index #{idx}: expected #{expected_first.inspect}, got #{actual_first.inspect}"
  end

  # Check continuation lines (655)
  continuation_count = 0
  j = idx + 1
  while j < command_list.length && command_list[j].code == 655
    continuation_count += 1
    j += 1
  end

  expected_continuations = lines.length - 1
  if continuation_count != expected_continuations
    issues << "Expected #{expected_continuations} continuation lines (655) after index #{idx}, found #{continuation_count}"
  end

  [continuation_count, expected_continuations].min.times do |li|
    actual = command_list[idx + 1 + li].parameters[0].to_s
    expected = lines[1 + li].to_s
    if actual != expected
      issues << "Line #{1 + li} mismatch at index #{idx + 1 + li}: expected #{expected.inspect}, got #{actual.inspect}"
    end
  end

  issues
end

def validate_insert_commands_block(command_list, block, label)
  issues = []
  idx = block["start_index"]
  commands = block["commands"]

  unless commands.is_a?(Array) && commands.any?
    issues << "insert_commands block has no commands"
    return issues
  end

  # After injection, the inserted commands should start AT start_index.
  # Verify each command is present in sequence.
  commands.each_with_index do |expected_cmd, ci|
    pos = idx + ci

    if pos >= command_list.length
      issues << "Inserted command #{ci} at index #{pos} out of range (list length #{command_list.length})"
      next
    end

    actual = command_list[pos]
    exp_code = expected_cmd["code"] || 0
    exp_indent = expected_cmd["indent"] || 0
    exp_params = expected_cmd["parameters"] || []

    if actual.code != exp_code
      issues << "Inserted command #{ci} at index #{pos}: expected code #{exp_code}, found #{actual.code}"
    end

    if actual.indent != exp_indent
      issues << "Inserted command #{ci} at index #{pos}: expected indent #{exp_indent}, found #{actual.indent}"
    end

    # Compare parameters. Convert to comparable form (arrays/strings).
    actual_params = actual.parameters || []
    if actual_params != exp_params
      issues << "Inserted command #{ci} at index #{pos}: parameter mismatch — expected #{exp_params.inspect}, got #{actual_params.inspect}"
    end
  end

  issues
end

# ---------------------------------------------------------------------------
# Main validation logic
# ---------------------------------------------------------------------------

def validate_page_blocks(command_list, blocks, context_label)
  results = []

  blocks.each_with_index do |block, bi|
    block_type = block["type"]
    block_label = "#{context_label} block##{bi} (#{block_type} @#{block["start_index"]})"

    issues = case block_type
             when "text"
               validate_text_block(command_list, block, block_label)
             when "choices"
               validate_choice_block(command_list, block, block_label)
             when "script_message"
               validate_script_message_block(command_list, block, block_label)
             when "insert_commands"
               validate_insert_commands_block(command_list, block, block_label)
             else
               ["Unknown block type '#{block_type}'"]
             end

    results << { label: block_label, issues: issues }
  end

  results
end

def main
  data_dir = ARGV[0]
  changes_file = ARGV[1]

  unless data_dir && changes_file
    $stderr.puts "Usage: ruby tools/validate_injection.rb <data_dir> <changes.json>"
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
  maps_changed = changes["maps"] || {}
  common_events_changed = changes["common_events"] || {}

  total_pass = 0
  total_fail = 0
  total_skip = 0
  all_results = []

  # ---- Validate map blocks ----
  maps_changed.each do |map_id_str, map_changes|
    next if map_id_str.start_with?("_") # skip metadata keys

    map_id = map_id_str.to_i
    map_name = map_changes["name"] || "?"
    map = load_map(data_dir, map_id)

    unless map
      puts "SKIP  Map#{"%03d" % map_id} (#{map_name}) — .rxdata file not found"
      total_skip += 1
      next
    end

    (map_changes["events"] || {}).each do |event_id_str, event_changes|
      event_id = event_id_str.to_i
      event = map.events[event_id]

      unless event
        label = "Map#{"%03d" % map_id} event##{event_id}"
        puts "FAIL  #{label} — event not found in map"
        total_fail += 1
        next
      end

      (event_changes["pages"] || {}).each do |page_idx_str, page_changes|
        page_idx = page_idx_str.to_i
        page = event.pages[page_idx]

        unless page
          label = "Map#{"%03d" % map_id} event##{event_id} page##{page_idx}"
          puts "FAIL  #{label} — page not found"
          total_fail += 1
          next
        end

        blocks = page_changes["dialogue_blocks"] || []
        next if blocks.empty?

        context = "Map#{"%03d" % map_id} E#{event_id} P#{page_idx}"
        results = validate_page_blocks(page.list, blocks, context)

        results.each do |r|
          if r[:issues].empty?
            puts "PASS  #{r[:label]}"
            total_pass += 1
          else
            puts "FAIL  #{r[:label]}"
            r[:issues].each { |issue| puts "        #{issue}" }
            total_fail += 1
          end
        end
      end
    end
  end

  # ---- Validate common event blocks ----
  if common_events_changed.any?
    common_events = load_common_events(data_dir)

    if common_events
      common_events_changed.each do |ce_id_str, ce_changes|
        ce_id = ce_id_str.to_i
        ce = common_events.find { |c| c && c.id == ce_id }

        unless ce
          puts "FAIL  CommonEvent##{ce_id} — not found"
          total_fail += 1
          next
        end

        blocks = ce_changes["dialogue_blocks"] || []
        next if blocks.empty?

        context = "CommonEvent##{ce_id} (#{ce.name})"
        results = validate_page_blocks(ce.list, blocks, context)

        results.each do |r|
          if r[:issues].empty?
            puts "PASS  #{r[:label]}"
            total_pass += 1
          else
            puts "FAIL  #{r[:label]}"
            r[:issues].each { |issue| puts "        #{issue}" }
            total_fail += 1
          end
        end
      end
    else
      puts "SKIP  CommonEvents.rxdata not found"
      total_skip += 1
    end
  end

  # ---- Summary ----
  puts ""
  puts "=" * 60
  puts "Validation Summary for: #{File.basename(changes_file)}"
  puts "=" * 60
  puts "  PASS:    #{total_pass}"
  puts "  FAIL:    #{total_fail}"
  puts "  SKIP:    #{total_skip}"
  puts "  TOTAL:   #{total_pass + total_fail + total_skip}"
  puts "=" * 60

  exit(total_fail > 0 ? 1 : 0)
end

main
