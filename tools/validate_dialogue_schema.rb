#!/usr/bin/env ruby
# encoding: utf-8
# tools/validate_dialogue_schema.rb
#
# Validates the JSON schema of all dialogue_changes/*.json files.
# Does NOT require game_data/ — purely structural validation.
#
# Checks:
#   - Valid JSON
#   - Required top-level keys
#   - maps → events → pages → dialogue_blocks structure
#   - Each block has required keys for its type
#   - Command objects in insert_commands/replace_commands have code/indent/parameters
#   - No unknown block types
#
# Usage: ruby tools/validate_dialogue_schema.rb [file ...]
#        (no args = validate all dialogue_changes/*.json)

require 'json'

VALID_BLOCK_TYPES = %w[text choices script_message insert_commands replace_commands].freeze

def validate_block(block, path)
  issues = []

  unless block.is_a?(Hash)
    issues << "#{path}: block is not an object"
    return issues
  end

  type = block["type"]
  unless type
    issues << "#{path}: missing 'type'"
    return issues
  end

  unless VALID_BLOCK_TYPES.include?(type)
    issues << "#{path}: unknown block type '#{type}'"
    return issues
  end

  # All block types except audio_file need start_index
  unless block.key?("start_index")
    issues << "#{path}: missing 'start_index'"
  end

  case type
  when "text"
    unless block["lines"].is_a?(Array) && block["lines"].any?
      issues << "#{path}: text block missing or empty 'lines' array"
    end
  when "choices"
    unless block["choices"].is_a?(Array) && block["choices"].any?
      issues << "#{path}: choices block missing or empty 'choices' array"
    end
  when "script_message"
    unless block["lines"].is_a?(Array) && block["lines"].any?
      issues << "#{path}: script_message block missing or empty 'lines' array"
    end
  when "insert_commands"
    unless block["commands"].is_a?(Array) && block["commands"].any?
      issues << "#{path}: insert_commands block missing or empty 'commands' array"
    else
      block["commands"].each_with_index do |cmd, ci|
        issues.concat(validate_command(cmd, "#{path} cmd##{ci}"))
      end
    end
  when "replace_commands"
    unless block.key?("end_index")
      issues << "#{path}: replace_commands block missing 'end_index'"
    end
    unless block["commands"].is_a?(Array) && block["commands"].any?
      issues << "#{path}: replace_commands block missing or empty 'commands' array"
    else
      block["commands"].each_with_index do |cmd, ci|
        issues.concat(validate_command(cmd, "#{path} cmd##{ci}"))
      end
    end
  end

  issues
end

def validate_command(cmd, path)
  issues = []
  unless cmd.is_a?(Hash)
    issues << "#{path}: command is not an object"
    return issues
  end
  unless cmd.key?("code") && cmd["code"].is_a?(Integer)
    issues << "#{path}: missing or non-integer 'code'"
  end
  unless cmd.key?("indent") && cmd["indent"].is_a?(Integer)
    issues << "#{path}: missing or non-integer 'indent'"
  end
  unless cmd.key?("parameters") && cmd["parameters"].is_a?(Array)
    issues << "#{path}: missing or non-array 'parameters'"
  end
  issues
end

def validate_file(filepath)
  issues = []
  fname = File.basename(filepath)

  begin
    data = JSON.parse(File.read(filepath))
  rescue JSON::ParserError => e
    issues << "#{fname}: Invalid JSON — #{e.message}"
    return issues
  end

  unless data.is_a?(Hash)
    issues << "#{fname}: Top level is not an object"
    return issues
  end

  maps = data["maps"]
  unless maps.is_a?(Hash)
    issues << "#{fname}: missing or non-object 'maps'"
    return issues
  end

  maps.each do |map_id, map_data|
    next if map_id.start_with?("_")

    unless map_data.is_a?(Hash)
      issues << "#{fname} Map#{map_id}: not an object"
      next
    end

    events = map_data["events"]
    next unless events # events can be absent if map has only metadata

    unless events.is_a?(Hash)
      issues << "#{fname} Map#{map_id}: 'events' is not an object"
      next
    end

    events.each do |event_id, event_data|
      unless event_data.is_a?(Hash)
        issues << "#{fname} Map#{map_id} E#{event_id}: not an object"
        next
      end

      pages = event_data["pages"]
      # Events with only metadata (name, _note, _preserve) and no pages are OK
      next unless pages
      unless pages.is_a?(Hash)
        issues << "#{fname} Map#{map_id} E#{event_id}: 'pages' is not an object"
        next
      end

      pages.each do |page_id, page_data|
        unless page_data.is_a?(Hash)
          issues << "#{fname} Map#{map_id} E#{event_id} P#{page_id}: not an object"
          next
        end

        blocks = page_data["dialogue_blocks"]
        next unless blocks

        unless blocks.is_a?(Array)
          issues << "#{fname} Map#{map_id} E#{event_id} P#{page_id}: 'dialogue_blocks' is not an array"
          next
        end

        blocks.each_with_index do |block, bi|
          path = "#{fname} Map#{map_id} E#{event_id} P#{page_id} B#{bi}"
          issues.concat(validate_block(block, path))
        end
      end
    end
  end

  # Validate common_events if present
  ce = data["common_events"]
  if ce
    unless ce.is_a?(Hash)
      issues << "#{fname}: 'common_events' is not an object"
    else
      ce.each do |ce_id, ce_data|
        unless ce_data.is_a?(Hash)
          issues << "#{fname} CE#{ce_id}: not an object"
          next
        end
        blocks = ce_data["dialogue_blocks"]
        next unless blocks
        unless blocks.is_a?(Array)
          issues << "#{fname} CE#{ce_id}: 'dialogue_blocks' is not an array"
          next
        end
        blocks.each_with_index do |block, bi|
          path = "#{fname} CE#{ce_id} B#{bi}"
          issues.concat(validate_block(block, path))
        end
      end
    end
  end

  issues
end

# ── Main ──

files = if ARGV.any?
  ARGV
else
  dialogue_dir = File.join(File.dirname(__FILE__), "..", "dialogue_changes")
  Dir.glob(File.join(dialogue_dir, "*.json")).sort
end

if files.empty?
  $stderr.puts "No JSON files to validate."
  exit 1
end

total_ok = 0
total_issues = 0
all_issues = []

files.each do |f|
  issues = validate_file(f)
  if issues.empty?
    total_ok += 1
  else
    total_issues += issues.length
    all_issues.concat(issues)
  end
end

puts "=== Dialogue JSON Schema Validation ==="
puts "  Files checked: #{files.length}"
puts "  Files OK:      #{total_ok}"
puts "  Issues found:  #{total_issues}"

if all_issues.any?
  puts ""
  all_issues.each { |i| puts "  ERROR: #{i}" }
  puts ""
  puts "FAILED"
  exit 1
else
  puts ""
  puts "ALL CLEAR"
end
