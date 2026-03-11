#!/usr/bin/env ruby
# extract_dialogue.rb — Extracts all dialogue from Pokemon Infinite Fusion .rxdata map files.
#
# Usage:
#   ruby extract_dialogue.rb <data_dir> [output.json]
#
# Arguments:
#   data_dir   - Path to the Data/ directory containing MapXXX.rxdata and MapInfos.rxdata
#   output     - Output JSON file path (default: dialogue_dump.json)
#
# The output JSON has the structure:
#   {
#     "maps": {
#       "<map_id>": {
#         "name": "Cerulean City",
#         "events": {
#           "<event_id>": {
#             "name": "Blue",
#             "x": 10, "y": 15,
#             "pages": {
#               "<page_index>": {
#                 "conditions": { ... },
#                 "dialogue_blocks": [
#                   {
#                     "start_index": 5,
#                     "type": "text",
#                     "lines": ["Line 1", "Line 2"]
#                   },
#                   {
#                     "start_index": 12,
#                     "type": "choices",
#                     "choices": ["Yes", "No"],
#                     "cancel_type": 2
#                   }
#                 ]
#               }
#             }
#           }
#         }
#       }
#     },
#     "common_events": { ... },
#     "metadata": { "extracted_at": "...", "map_count": ..., "total_text_blocks": ... }
#   }
#
# Event command codes:
#   101 = Show Text (first line)
#   401 = Show Text (continuation lines)
#   102 = Show Choices
#   402 = When [Choice]
#   403 = When Cancel
#   108 = Comment (first line)
#   408 = Comment (continuation)
#   111 = Conditional Branch
#   121 = Control Switches
#   122 = Control Variables
#   355 = Script (first line)
#   655 = Script (continuation)

require "json"
require_relative "rpgmaker_stubs"

def extract_page_conditions(condition)
  conds = {}
  if condition.switch1_valid
    conds["switch1_id"] = condition.switch1_id
  end
  if condition.switch2_valid
    conds["switch2_id"] = condition.switch2_id
  end
  if condition.variable_valid
    conds["variable_id"] = condition.variable_id
    conds["variable_value"] = condition.variable_value
  end
  if condition.self_switch_valid
    conds["self_switch"] = condition.self_switch_ch
  end
  conds
end

def extract_dialogue_blocks(command_list)
  blocks = []
  i = 0

  while i < command_list.length
    cmd = command_list[i]

    case cmd.code
    when 101
      # Show Text: 101 starts it, 401 continues
      lines = [cmd.parameters[0]]
      j = i + 1
      while j < command_list.length && command_list[j].code == 401
        lines << command_list[j].parameters[0]
        j += 1
      end
      blocks << {
        "start_index" => i,
        "type" => "text",
        "lines" => lines
      }
      i = j

    when 102
      # Show Choices
      blocks << {
        "start_index" => i,
        "type" => "choices",
        "choices" => cmd.parameters[0],
        "cancel_type" => cmd.parameters[1]
      }
      i += 1

    when 355
      # Script call — extract because pbMessage/Kernel.pbMessage is used for dialogue
      lines = [cmd.parameters[0]]
      j = i + 1
      while j < command_list.length && command_list[j].code == 655
        lines << command_list[j].parameters[0]
        j += 1
      end
      script_text = lines.join("\n")
      if script_text =~ /pbMessage|Kernel\.pbMessage|pbConfirmMessage/
        blocks << {
          "start_index" => i,
          "type" => "script_message",
          "lines" => lines,
          "script" => script_text
        }
      end
      i = j

    when 108
      # Comment — skip continuation lines but don't extract
      j = i + 1
      while j < command_list.length && command_list[j].code == 408
        j += 1
      end
      i = j

    else
      i += 1
    end
  end

  blocks
end

def main
  data_dir = ARGV[0]
  output_file = ARGV[1] || "dialogue_dump.json"

  unless data_dir && Dir.exist?(data_dir)
    $stderr.puts "Usage: ruby extract_dialogue.rb <data_dir> [output.json]"
    $stderr.puts "  data_dir must be the path to the Data/ directory"
    exit 1
  end

  # Load map names
  mapinfos_path = File.join(data_dir, "MapInfos.rxdata")
  unless File.exist?(mapinfos_path)
    $stderr.puts "Error: MapInfos.rxdata not found in #{data_dir}"
    exit 1
  end
  map_infos = Marshal.load(File.binread(mapinfos_path))

  result = { "maps" => {}, "common_events" => {}, "metadata" => {} }
  total_text_blocks = 0
  total_choice_blocks = 0
  total_script_messages = 0
  maps_with_dialogue = 0

  # Process all map files
  map_files = Dir.glob(File.join(data_dir, "Map[0-9]*.rxdata")).reject { |f| f =~ /MapInfos/ }.sort
  $stderr.puts "Processing #{map_files.length} map files..."

  map_files.each do |map_file|
    map_id = File.basename(map_file, ".rxdata").sub(/^Map0*/, "").to_i
    map_name = map_infos[map_id]&.name || "Unknown"

    begin
      map = Marshal.load(File.binread(map_file))
    rescue => e
      $stderr.puts "  Warning: Failed to load #{map_file}: #{e.message}"
      next
    end

    map_data = { "name" => map_name, "events" => {} }
    map_has_dialogue = false

    map.events.each do |event_id, event|
      event_data = {
        "name" => event.name,
        "x" => event.x,
        "y" => event.y,
        "pages" => {}
      }
      event_has_dialogue = false

      event.pages.each_with_index do |page, page_idx|
        blocks = extract_dialogue_blocks(page.list)
        next if blocks.empty?

        conditions = extract_page_conditions(page.condition)

        event_data["pages"][page_idx.to_s] = {
          "conditions" => conditions,
          "dialogue_blocks" => blocks
        }

        blocks.each do |b|
          case b["type"]
          when "text" then total_text_blocks += 1
          when "choices" then total_choice_blocks += 1
          when "script_message" then total_script_messages += 1
          end
        end

        event_has_dialogue = true
      end

      if event_has_dialogue
        map_data["events"][event_id.to_s] = event_data
        map_has_dialogue = true
      end
    end

    if map_has_dialogue
      result["maps"][map_id.to_s] = map_data
      maps_with_dialogue += 1
    end
  end

  # Process common events
  common_events_path = File.join(data_dir, "CommonEvents.rxdata")
  if File.exist?(common_events_path)
    $stderr.puts "Processing CommonEvents.rxdata..."
    begin
      common_events = Marshal.load(File.binread(common_events_path))
      common_events.each do |ce|
        next unless ce
        blocks = extract_dialogue_blocks(ce.list)
        next if blocks.empty?

        result["common_events"][ce.id.to_s] = {
          "name" => ce.name,
          "trigger" => ce.trigger,
          "switch_id" => ce.switch_id,
          "dialogue_blocks" => blocks
        }

        blocks.each do |b|
          case b["type"]
          when "text" then total_text_blocks += 1
          when "choices" then total_choice_blocks += 1
          when "script_message" then total_script_messages += 1
          end
        end
      end
    rescue => e
      $stderr.puts "  Warning: Failed to load CommonEvents: #{e.message}"
    end
  end

  result["metadata"] = {
    "extracted_at" => Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "data_dir" => File.expand_path(data_dir),
    "total_maps" => map_files.length,
    "maps_with_dialogue" => maps_with_dialogue,
    "total_text_blocks" => total_text_blocks,
    "total_choice_blocks" => total_choice_blocks,
    "total_script_messages" => total_script_messages,
    "common_events_with_dialogue" => result["common_events"].length
  }

  File.write(output_file, JSON.pretty_generate(result))

  $stderr.puts ""
  $stderr.puts "=== Extraction Complete ==="
  $stderr.puts "Maps processed:        #{map_files.length}"
  $stderr.puts "Maps with dialogue:    #{maps_with_dialogue}"
  $stderr.puts "Text blocks (101):     #{total_text_blocks}"
  $stderr.puts "Choice blocks (102):   #{total_choice_blocks}"
  $stderr.puts "Script messages:       #{total_script_messages}"
  $stderr.puts "Common events:         #{result["common_events"].length}"
  $stderr.puts "Output written to:     #{output_file}"
end

main
