#!/usr/bin/env ruby
# inject_dialogue.rb — Injects modified dialogue back into .rxdata map files.
#
# Usage:
#   ruby inject_dialogue.rb <data_dir> <changes.json> [--dry-run]
#
# Arguments:
#   data_dir     - Path to the Data/ directory containing MapXXX.rxdata files
#   changes.json - JSON file with the same structure as extract_dialogue.rb output,
#                  containing only the entries you want to modify
#   --dry-run    - Preview changes without writing files
#
# The changes JSON should have the same structure as the extraction output.
# Only maps/events/pages/blocks present in the JSON will be modified.
# All other data is preserved exactly as-is.
#
# Block types:
#   text            — Modify existing Show Text (101) or pbMessage Script (355)
#                     at start_index. Provide "lines" array with new text.
#                     Automatically detects whether the game uses native Show Text
#                     or pbMessage script calls, and handles both transparently.
#   choices         — Modify existing Show Choices (102) at start_index.
#                     Provide "choices" array with new labels.
#   script_message  — Modify existing Script (355) at start_index.
#                     Provide "lines" array with new text.
#   insert_commands — Insert new event commands BEFORE start_index.
#                     Provide "commands" array of {code, indent, parameters}.
#                     Supports any RPG Maker XP event command code:
#                       101/401 (Show Text), 102/402/404 (Choices),
#                       121 (Control Switches), 122 (Control Variables), etc.
#   replace_commands — Remove commands from start_index to end_index (inclusive),
#                      then insert new commands at that position.
#                      Provide "end_index", "commands" array.

require "json"
require_relative "rpgmaker_stubs"

# Maximum distance to search when the exact index doesn't match
FUZZY_SEARCH_RANGE = 20

# Characters that RPG Maker XP's bitmap font cannot render (they display as []).
# Map each to a safe ASCII fallback.
UNICODE_REPLACEMENTS = {
  "\u2014" => "--",  # em dash
  "\u2013" => "-",   # en dash
  "\u2018" => "'",   # left single curly quote
  "\u2019" => "'",   # right single curly quote
  "\u201C" => "\"",  # left double curly quote
  "\u201D" => "\"",  # right double curly quote
  "\u2026" => "...", # ellipsis
}.freeze

def sanitize_text(str)
  UNICODE_REPLACEMENTS.each { |from, to| str = str.gsub(from, to) }
  str
end

# ─── Text command detection ──────────────────────────────────────────────────

def pb_message_call?(cmd)
  cmd && cmd.code == 355 &&
    cmd.parameters[0].to_s =~ /(?:Kernel\.)?(?:pbMessage|pbMsg)\s*\(/i
end

def text_command?(cmd)
  return false unless cmd
  cmd.code == 101 || pb_message_call?(cmd)
end

# Search near target_index for a text command (code 101 or pbMessage 355).
# Returns [actual_index, :show_text | :pb_message] or nil.
def find_text_command_near(command_list, target_index, range = FUZZY_SEARCH_RANGE)
  # Check exact index first
  if target_index >= 0 && target_index < command_list.length
    cmd = command_list[target_index]
    return [target_index, :show_text] if cmd.code == 101
    return [target_index, :pb_message] if pb_message_call?(cmd)
  end

  # Expand outward from target
  (1..range).each do |offset|
    [target_index - offset, target_index + offset].each do |idx|
      next if idx < 0 || idx >= command_list.length
      cmd = command_list[idx]
      return [idx, :show_text] if cmd.code == 101
      return [idx, :pb_message] if pb_message_call?(cmd)
    end
  end

  nil
end

# Search near target_index for a choice command (code 102).
def find_choice_command_near(command_list, target_index, range = FUZZY_SEARCH_RANGE)
  if target_index >= 0 && target_index < command_list.length
    return target_index if command_list[target_index].code == 102
  end

  (1..range).each do |offset|
    [target_index - offset, target_index + offset].each do |idx|
      next if idx < 0 || idx >= command_list.length
      return idx if command_list[idx].code == 102
    end
  end

  nil
end

# Search near target_index for a script command (code 355).
def find_script_command_near(command_list, target_index, range = FUZZY_SEARCH_RANGE)
  if target_index >= 0 && target_index < command_list.length
    return target_index if command_list[target_index].code == 355
  end

  (1..range).each do |offset|
    [target_index - offset, target_index + offset].each do |idx|
      next if idx < 0 || idx >= command_list.length
      return idx if command_list[idx].code == 355
    end
  end

  nil
end

# ─── Show Text (101/401) handling ────────────────────────────────────────────

def apply_show_text(command_list, start_idx, new_lines)
  new_lines = new_lines.map { |l| sanitize_text(l) }

  # Count existing continuation lines (401)
  old_line_count = 1
  j = start_idx + 1
  while j < command_list.length && command_list[j].code == 401
    old_line_count += 1
    j += 1
  end

  # Set the first line
  command_list[start_idx].parameters[0] = new_lines[0]

  if new_lines.length == old_line_count
    new_lines[1..].each_with_index do |line, li|
      command_list[start_idx + 1 + li].parameters[0] = line
    end
  elsif new_lines.length < old_line_count
    remove_count = old_line_count - new_lines.length
    new_lines[1..].each_with_index do |line, li|
      command_list[start_idx + 1 + li].parameters[0] = line
    end
    command_list.slice!(start_idx + new_lines.length, remove_count)
  else
    new_lines[1...old_line_count].each_with_index do |line, li|
      command_list[start_idx + 1 + li].parameters[0] = line
    end
    insert_at = start_idx + old_line_count
    indent = command_list[start_idx].indent
    new_lines[old_line_count..].each_with_index do |line, li|
      new_cmd = RPG::EventCommand.new
      new_cmd.code = 401
      new_cmd.indent = indent
      new_cmd.parameters = [line]
      command_list.insert(insert_at + li, new_cmd)
    end
  end

  true
end

# ─── pbMessage (355/655) handling ────────────────────────────────────────────

def apply_pb_message(command_list, start_idx, new_lines)
  new_lines = new_lines.map { |l| sanitize_text(l) }
  cmd = command_list[start_idx]
  existing = cmd.parameters[0].to_s

  # Detect the wrapper format from the existing command
  wrapper_prefix = if existing =~ /^(Kernel\.pbMessage\(_INTL\()/
                     $1
                   elsif existing =~ /^(pbMessage\(_INTL\()/
                     $1
                   elsif existing =~ /^(Kernel\.pbMessage\()/
                     $1
                   elsif existing =~ /^(pbMessage\()/
                     $1
                   else
                     "pbMessage(_INTL("
                   end

  # Determine closing based on prefix
  wrapper_suffix = if wrapper_prefix.include?("_INTL(")
                     "\"))"
                   else
                     "\")"
                   end

  # Count existing continuation lines (655)
  old_count = 1
  j = start_idx + 1
  while j < command_list.length && command_list[j].code == 655
    old_count += 1
    j += 1
  end

  # Join all new lines and wrap in pbMessage
  # Use \n for line breaks within the text box
  joined_text = new_lines.join("\\n")
  new_script = "#{wrapper_prefix}\"#{joined_text}#{wrapper_suffix}"

  # Replace: single 355 command with new text, remove extra 655s
  command_list[start_idx].parameters[0] = new_script
  if old_count > 1
    command_list.slice!(start_idx + 1, old_count - 1)
  end

  true
end

# ─── Block application functions ─────────────────────────────────────────────

def apply_text_block(command_list, block)
  target_idx = block["start_index"]
  new_lines = block["lines"]

  result = find_text_command_near(command_list, target_idx)

  unless result
    $stderr.puts "    Warning: No text command (101 or pbMessage) found near index #{target_idx}. Skipping."
    return false
  end

  actual_idx, cmd_type = result
  if actual_idx != target_idx
    $stderr.puts "    Note: Adjusted text index #{target_idx} -> #{actual_idx}"
  end

  case cmd_type
  when :show_text
    apply_show_text(command_list, actual_idx, new_lines)
  when :pb_message
    apply_pb_message(command_list, actual_idx, new_lines)
  end
end

def apply_choice_block(command_list, block)
  target_idx = block["start_index"]
  new_choices = block["choices"].map { |c| sanitize_text(c) }
  new_cancel = block["cancel_type"]

  actual_idx = find_choice_command_near(command_list, target_idx)
  unless actual_idx
    $stderr.puts "    Warning: No choice command (102) found near index #{target_idx}. Skipping."
    return false
  end

  if actual_idx != target_idx
    $stderr.puts "    Note: Adjusted choice index #{target_idx} -> #{actual_idx}"
  end

  cmd = command_list[actual_idx]
  cmd.parameters[0] = new_choices
  cmd.parameters[1] = new_cancel if new_cancel
  true
end

def apply_script_message_block(command_list, block)
  target_idx = block["start_index"]
  new_lines = block["lines"].map { |l| sanitize_text(l) }

  actual_idx = find_script_command_near(command_list, target_idx)
  unless actual_idx
    $stderr.puts "    Warning: No script command (355) found near index #{target_idx}. Skipping."
    return false
  end

  if actual_idx != target_idx
    $stderr.puts "    Note: Adjusted script index #{target_idx} -> #{actual_idx}"
  end

  cmd = command_list[actual_idx]

  # Count existing continuation lines (655)
  old_line_count = 1
  j = actual_idx + 1
  while j < command_list.length && command_list[j].code == 655
    old_line_count += 1
    j += 1
  end

  # Replace first line
  command_list[actual_idx].parameters[0] = new_lines[0]

  if new_lines.length == old_line_count
    new_lines[1..].each_with_index do |line, li|
      command_list[actual_idx + 1 + li].parameters[0] = line
    end
  elsif new_lines.length < old_line_count
    remove_count = old_line_count - new_lines.length
    new_lines[1..].each_with_index do |line, li|
      command_list[actual_idx + 1 + li].parameters[0] = line
    end
    command_list.slice!(actual_idx + new_lines.length, remove_count)
  else
    new_lines[1...old_line_count].each_with_index do |line, li|
      command_list[actual_idx + 1 + li].parameters[0] = line
    end
    insert_at = actual_idx + old_line_count
    indent = command_list[actual_idx].indent
    new_lines[old_line_count..].each_with_index do |line, li|
      new_cmd = RPG::EventCommand.new
      new_cmd.code = 655
      new_cmd.indent = indent
      new_cmd.parameters = [line]
      command_list.insert(insert_at + li, new_cmd)
    end
  end

  true
end

def apply_insert_commands(command_list, block)
  insert_idx = block["start_index"]
  commands = block["commands"]

  unless commands.is_a?(Array) && commands.any?
    $stderr.puts "    Warning: insert_commands block has no commands. Skipping."
    return false
  end

  unless insert_idx >= 0 && insert_idx <= command_list.length
    $stderr.puts "    Warning: insert index #{insert_idx} out of range (0..#{command_list.length}). Skipping."
    return false
  end

  # Insert commands in reverse order so they end up in the correct sequence.
  # Inserting at the same index repeatedly pushes earlier insertions forward.
  commands.reverse_each do |cmd_data|
    new_cmd = RPG::EventCommand.new
    new_cmd.code = cmd_data["code"] || 0
    new_cmd.indent = cmd_data["indent"] || 0
    new_cmd.parameters = resolve_parameters(cmd_data["parameters"] || [])
    command_list.insert(insert_idx, new_cmd)
  end

  true
end

def resolve_parameter(param)
  # Handle special string placeholders for RPG Maker objects
  if param.is_a?(Hash)
    if param["type"] == "audio_file"
      audio = RPG::AudioFile.new
      audio.name = param["name"] || ""
      audio.volume = param["volume"] || 100
      audio.pitch = param["pitch"] || 100
      return audio
    end
  end
  param
end

def resolve_parameters(params)
  return params unless params.is_a?(Array)
  params.map { |p| resolve_parameter(p) }
end

def apply_replace_commands(command_list, block)
  start_idx = block["start_index"]
  end_idx = block["end_index"]
  commands = block["commands"]

  unless commands.is_a?(Array)
    $stderr.puts "    Warning: replace_commands block has no commands. Skipping."
    return false
  end

  unless start_idx >= 0 && end_idx >= start_idx && end_idx < command_list.length
    $stderr.puts "    Warning: replace range #{start_idx}..#{end_idx} out of bounds (0..#{command_list.length - 1}). Skipping."
    return false
  end

  # Remove the old commands
  remove_count = end_idx - start_idx + 1
  command_list.slice!(start_idx, remove_count)

  # Insert new commands at the same position (in reverse to maintain order)
  commands.reverse_each do |cmd_data|
    new_cmd = RPG::EventCommand.new
    new_cmd.code = cmd_data["code"] || 0
    new_cmd.indent = cmd_data["indent"] || 0
    new_cmd.parameters = resolve_parameters(cmd_data["parameters"] || [])
    command_list.insert(start_idx, new_cmd)
  end

  $stderr.puts "    Replaced commands #{start_idx}..#{end_idx} (#{remove_count} removed, #{commands.length} inserted)"
  true
end

# ─── Main ────────────────────────────────────────────────────────────────────

def main
  data_dir = ARGV[0]
  changes_file = ARGV[1]
  dry_run = ARGV.include?("--dry-run")

  unless data_dir && changes_file
    $stderr.puts "Usage: ruby inject_dialogue.rb <data_dir> <changes.json> [--dry-run]"
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

  total_modifications = 0
  total_failures = 0
  total_adjusted = 0
  files_written = 0

  # Process map changes
  maps_changed.each do |map_id_str, map_changes|
    map_id = map_id_str.to_i
    map_file = File.join(data_dir, "Map%03d.rxdata" % map_id)

    unless File.exist?(map_file)
      $stderr.puts "Warning: #{map_file} not found, skipping map #{map_id}"
      next
    end

    $stderr.puts "Processing Map#{"%03d" % map_id} (#{map_changes["name"] || "?"})..."
    map = Marshal.load(File.binread(map_file))
    modified = false

    (map_changes["events"] || {}).each do |event_id_str, event_changes|
      event_id = event_id_str.to_i
      event = map.events[event_id]

      unless event
        $stderr.puts "  Warning: Event #{event_id} not found in map #{map_id}"
        next
      end

      (event_changes["pages"] || {}).each do |page_idx_str, page_changes|
        page_idx = page_idx_str.to_i
        page = event.pages[page_idx]

        unless page
          $stderr.puts "  Warning: Page #{page_idx} not found for event #{event_id}"
          next
        end

        # Process blocks in reverse order of start_index to avoid
        # index shifts when inserting/removing continuation lines.
        # Tiebreaker: at the same index, process modifications (text/choices)
        # before insertions, so insertions see the already-modified command.
        sorted_blocks = (page_changes["dialogue_blocks"] || []).sort_by do |b|
          [-(b["start_index"] || 0), ["insert_commands", "replace_commands"].include?(b["type"]) ? 1 : 0]
        end
        sorted_blocks.each do |block|
          success = case block["type"]
                    when "text"
                      if dry_run
                        $stderr.puts "  [DRY RUN] Would modify text at event #{event_id}, page #{page_idx}, index #{block["start_index"]}"
                        $stderr.puts "    New text: #{block["lines"].first(2).join(" / ")}..."
                        true
                      else
                        apply_text_block(page.list, block)
                      end
                    when "choices"
                      if dry_run
                        $stderr.puts "  [DRY RUN] Would modify choices at event #{event_id}, page #{page_idx}, index #{block["start_index"]}"
                        $stderr.puts "    New choices: #{block["choices"].inspect}"
                        true
                      else
                        apply_choice_block(page.list, block)
                      end
                    when "script_message"
                      if dry_run
                        $stderr.puts "  [DRY RUN] Would modify script message at event #{event_id}, page #{page_idx}, index #{block["start_index"]}"
                        true
                      else
                        apply_script_message_block(page.list, block)
                      end
                    when "insert_commands"
                      if dry_run
                        $stderr.puts "  [DRY RUN] Would insert #{block["commands"]&.length || 0} commands before index #{block["start_index"]} at event #{event_id}, page #{page_idx}"
                        true
                      else
                        apply_insert_commands(page.list, block)
                      end
                    when "replace_commands"
                      if dry_run
                        $stderr.puts "  [DRY RUN] Would replace commands #{block["start_index"]}..#{block["end_index"]} with #{block["commands"]&.length || 0} new commands at event #{event_id}, page #{page_idx}"
                        true
                      else
                        apply_replace_commands(page.list, block)
                      end
                    else
                      $stderr.puts "  Warning: Unknown block type '#{block["type"]}'"
                      false
                    end

          if success
            total_modifications += 1
            modified = true
          else
            total_failures += 1
          end
        end
      end
    end

    if modified && !dry_run
      File.binwrite(map_file, Marshal.dump(map))
      files_written += 1
      $stderr.puts "  Written: #{map_file}"
    end
  end

  # Process common event changes
  if common_events_changed.any?
    common_events_path = File.join(data_dir, "CommonEvents.rxdata")
    if File.exist?(common_events_path)
      $stderr.puts "Processing CommonEvents..."
      common_events = Marshal.load(File.binread(common_events_path))
      ce_modified = false

      common_events_changed.each do |ce_id_str, ce_changes|
        ce_id = ce_id_str.to_i
        ce = common_events.find { |c| c && c.id == ce_id }

        unless ce
          $stderr.puts "  Warning: Common event #{ce_id} not found"
          next
        end

        sorted_ce_blocks = (ce_changes["dialogue_blocks"] || []).sort_by do |b|
          [-(b["start_index"] || 0), ["insert_commands", "replace_commands"].include?(b["type"]) ? 1 : 0]
        end
        sorted_ce_blocks.each do |block|
          success = case block["type"]
                    when "text"
                      dry_run ? true : apply_text_block(ce.list, block)
                    when "choices"
                      dry_run ? true : apply_choice_block(ce.list, block)
                    when "script_message"
                      dry_run ? true : apply_script_message_block(ce.list, block)
                    when "insert_commands"
                      dry_run ? true : apply_insert_commands(ce.list, block)
                    when "replace_commands"
                      dry_run ? true : apply_replace_commands(ce.list, block)
                    else
                      false
                    end

          if success
            total_modifications += 1
            ce_modified = true
          else
            total_failures += 1
          end
        end
      end

      if ce_modified && !dry_run
        File.binwrite(common_events_path, Marshal.dump(common_events))
        files_written += 1
        $stderr.puts "  Written: #{common_events_path}"
      end
    end
  end

  $stderr.puts ""
  $stderr.puts "=== Injection #{dry_run ? "(DRY RUN) " : ""}Complete ==="
  $stderr.puts "Modifications applied: #{total_modifications}"
  $stderr.puts "Failures:              #{total_failures}"
  $stderr.puts "Files written:         #{files_written}" unless dry_run
end

main
