# encoding: utf-8
#!/usr/bin/env ruby
# tools/validate_fork.rb
#
# Validates the Silph Co fork injection by:
# 1. Applying the injection to a copy of Map807
# 2. Checking conditional branch nesting is valid
# 3. Verifying all switch operations reference correct IDs
# 4. Confirming battle calls reference valid trainer types
# 5. Checking that cleanup code (partner removal, switch resets) is preserved
#
# Usage: ruby tools/validate_fork.rb <game_root_dir>

require_relative 'rpgmaker_stubs'
require 'json'
require 'fileutils'

game_dir = ARGV[0] || abort("Usage: ruby tools/validate_fork.rb <game_root_dir>")
data_dir = File.join(game_dir, "Data")
map_path = File.join(data_dir, "Map807.rxdata")

abort("Map807.rxdata not found") unless File.exist?(map_path)

# Load original map
original = Marshal.load(File.binread(map_path))

# Apply injection to a temp copy
require 'tmpdir'
tmp_dir = Dir.mktmpdir("fork_validate_")
FileUtils.cp(map_path, File.join(tmp_dir, "Map807.rxdata"))

fork_json = File.join(File.dirname(__FILE__), "..", "dialogue_changes", "silph_fork.json")
abort("silph_fork.json not found") unless File.exist?(fork_json)

# Run injection
inject_tool = File.join(File.dirname(__FILE__), "inject_dialogue.rb")
require 'open3'
result, _err, _st = Open3.capture3("ruby", inject_tool, tmp_dir, fork_json)
puts "=== Injection Output ==="
puts result
puts

# Load modified map
modified = Marshal.load(File.binread(File.join(tmp_dir, "Map807.rxdata")))

errors = []
warnings = []

# === VALIDATE EVENT 4 (Giovanni/Archer battle fork) ===
puts "=== Validating Event 4 (Battle Fork) ==="
ev4 = modified.events[4]
page0 = ev4.pages[0]
cmds = page0.list

# Check for choice command (code 102)
choice_cmds = cmds.each_with_index.select { |c, i| c.code == 102 }
if choice_cmds.empty?
  errors << "Event 4: No choice command (code 102) found"
else
  choice = choice_cmds[0][0]
  puts "  Choice found: #{choice.parameters[0].inspect}"
  if choice.parameters[0].length != 2
    errors << "Event 4: Choice should have exactly 2 options, has #{choice.parameters[0].length}"
  end
end

# Check for choice branches (code 402)
branches_402 = cmds.each_with_index.select { |c, i| c.code == 402 }
if branches_402.length != 2
  errors << "Event 4: Expected 2 choice branches (code 402), found #{branches_402.length}"
else
  puts "  Branch 0: #{branches_402[0][0].parameters.inspect}"
  puts "  Branch 1: #{branches_402[1][0].parameters.inspect}"
end

# Check for choice end (code 404)
end_404 = cmds.count { |c| c.code == 404 }
if end_404 < 1
  errors << "Event 4: No choice end (code 404) found"
else
  puts "  Choice end markers: #{end_404}"
end

# Check switch operations
switch_ops = cmds.each_with_index.select { |c, i| c.code == 121 }
puts "  Switch operations: #{switch_ops.length}"
switch_ops.each do |cmd, idx|
  sw_start, sw_end, value = cmd.parameters
  state = value == 0 ? "ON" : "OFF"
  puts "    cmd#{idx}: Switch #{sw_start}..#{sw_end} = #{state}"

  # Verify our synth switches
  if [1130, 1131].include?(sw_start)
    puts "      ^ Synthesis switch"
  end

  # Verify preserved cleanup switches
  if [222, 228, 628, 629].include?(sw_start)
    puts "      ^ Preserved game switch"
  end
end

# Check for two trainer battle calls
battle_calls = cmds.each_with_index.select { |c, i|
  c.code == 111 && c.parameters[0] == 12 && c.parameters[1].to_s.include?("pbTrainerBattle")
}
puts "  Trainer battles: #{battle_calls.length}"
battle_calls.each do |cmd, idx|
  script = cmd.parameters[1]
  puts "    cmd#{idx}: #{script}"

  if script.include?("ROCKETBOSS") && script.include?("Giovanni")
    puts "      ^ Giovanni battle (Oak Path)"
  elsif script.include?("ROCKETEXEC_Archer") && script.include?("Archer")
    puts "      ^ Archer battle (Giovanni Path)"
    # Verify battle index
    if script.include?(",true,1,false")
      puts "      ^ Battle index 1 (correct)"
    else
      errors << "Event 4: Archer battle index doesn't match version 1"
    end
  else
    warnings << "Event 4 cmd#{idx}: Unrecognized battle call: #{script}"
  end
end

if battle_calls.length != 2
  errors << "Event 4: Expected 2 trainer battles, found #{battle_calls.length}"
end

# Check conditional branches for battle won/lost
battle_won = cmds.count { |c| c.code == 111 && c.parameters[0] == 12 }
battle_else = cmds.count { |c| c.code == 411 }
battle_end = cmds.count { |c| c.code == 412 }
puts "  Battle conditionals: #{battle_won} won branches, #{battle_else} else branches, #{battle_end} end markers"

# Check partner deregistration is preserved in both paths
dereg = cmds.count { |c| [355, 655].include?(c.code) && c.parameters[0].to_s.include?("pbDeregisterPartner") }
puts "  pbDeregisterPartner calls: #{dereg}"
if dereg < 2
  errors << "Event 4: Expected pbDeregisterPartner in both battle-lost branches, found #{dereg}"
end

# Check dependency removal preserved
dep_remove = cmds.count { |c| [355, 655].include?(c.code) && c.parameters[0].to_s.include?("pbRemoveDependency") }
puts "  pbRemoveDependency calls: #{dep_remove}"
if dep_remove < 2
  errors << "Event 4: Expected pbRemoveDependency in both battle-lost branches, found #{dep_remove}"
end

# Check Switch 1130 is set ON in both paths
switch_1130_on = switch_ops.count { |cmd, _| cmd.parameters[0] == 1130 && cmd.parameters[2] == 0 }
puts "  Switch 1130 ON operations: #{switch_1130_on}"
if switch_1130_on < 2
  errors << "Event 4: Switch 1130 should be set ON in both paths, found #{switch_1130_on} times"
end

# Check Switch 228 is set (triggers Event 10)
switch_228_on = switch_ops.count { |cmd, _| cmd.parameters[0] == 228 && cmd.parameters[2] == 0 }
puts "  Switch 228 ON operations: #{switch_228_on}"

# === VALIDATE EVENT 10 (Blue post-battle) ===
puts "\n=== Validating Event 10 (Blue Post-Battle) ==="
ev10 = modified.events[10]
page0_10 = ev10.pages[0]
cmds10 = page0_10.list

# Check page condition
cond = page0_10.condition
if cond.switch1_valid && cond.switch1_id == 228
  puts "  Page condition: Switch 228 (correct)"
else
  errors << "Event 10: Page condition should check Switch 228"
end

# Check for conditional branch on Switch 1131
cond_1131 = cmds10.each_with_index.select { |c, i|
  c.code == 111 && c.parameters[0] == 0 && c.parameters[1] == 1131
}
if cond_1131.empty?
  errors << "Event 10: No conditional branch on Switch 1131 found"
else
  puts "  Switch 1131 branch found at cmd#{cond_1131[0][1]}"
end

# Check for else (411) and end (412)
has_else = cmds10.any? { |c| c.code == 411 }
has_end = cmds10.any? { |c| c.code == 412 }
puts "  Has else branch: #{has_else}"
puts "  Has end marker: #{has_end}"
errors << "Event 10: Missing else branch (411)" unless has_else
errors << "Event 10: Missing end marker (412)" unless has_end

# Check cleanup is preserved (should be AFTER the conditional)
cleanup_switches = cmds10.each_with_index.select { |c, i| c.code == 121 }
puts "  Cleanup switches: #{cleanup_switches.length}"
cleanup_switches.each do |cmd, idx|
  puts "    cmd#{idx}: Switch #{cmd.parameters[0]} = #{cmd.parameters[2] == 0 ? 'ON' : 'OFF'}"
end

# Preserved switches: 628 OFF, 629 OFF, 191 ON
preserved = { 628 => 1, 629 => 1, 191 => 0 }
preserved.each do |sw, expected_val|
  found = cleanup_switches.any? { |cmd, _| cmd.parameters[0] == sw && cmd.parameters[2] == expected_val }
  if found
    puts "  Switch #{sw} cleanup: PRESERVED"
  else
    errors << "Event 10: Missing cleanup for Switch #{sw} (expected value #{expected_val})"
  end
end

# === VALIDATE EVENT 8 (Giovanni cutscene) ===
puts "\n=== Validating Event 8 (Giovanni Cutscene) ==="
ev8 = modified.events[8]
page0_8 = ev8.pages[0]
cmds8 = page0_8.list

# Should have Switch 222 condition
cond8 = page0_8.condition
if cond8.switch1_valid && cond8.switch1_id == 222
  puts "  Page condition: Switch 222 (correct)"
else
  warnings << "Event 8: Expected Switch 222 page condition"
end

# Should set Switch 630 at end
switch_630 = cmds8.any? { |c| c.code == 121 && c.parameters[0] == 630 }
puts "  Sets Switch 630: #{switch_630}"
warnings << "Event 8: Missing Switch 630 set" unless switch_630

# === VALIDATE INDENT NESTING ===
puts "\n=== Validating Command Nesting ==="
[["Event 4", cmds], ["Event 10", cmds10]].each do |name, cmdlist|
  max_indent = 0
  prev_indent = 0
  cmdlist.each_with_index do |cmd, i|
    # Indent should never jump by more than 1 from the previous command
    if cmd.indent > prev_indent + 1
      errors << "#{name} cmd#{i}: Indent jump from #{prev_indent} to #{cmd.indent} (code #{cmd.code})"
    end
    # Indent should never go negative
    if cmd.indent < 0
      errors << "#{name} cmd#{i}: Negative indent #{cmd.indent} (code #{cmd.code})"
    end
    max_indent = cmd.indent if cmd.indent > max_indent
    prev_indent = cmd.indent
  end
  # The last command (code 0, end of list) should be at indent 0
  if cmdlist.any? && cmdlist.last.indent != 0
    errors << "#{name}: Final command not at indent 0 (at indent #{cmdlist.last.indent})"
  end

  # Verify all branches are properly closed
  # Count opens vs closes for choice branches
  opens = cmdlist.count { |c| c.code == 102 }  # Show Choices
  closes = cmdlist.count { |c| c.code == 404 }  # End Choices
  if opens != closes
    errors << "#{name}: Mismatched choice opens (#{opens}) vs closes (#{closes})"
  end

  # Count conditional opens vs closes
  cond_opens = cmdlist.count { |c| c.code == 111 }
  cond_closes = cmdlist.count { |c| c.code == 412 }
  if cond_opens != cond_closes
    errors << "#{name}: Mismatched conditional opens (#{cond_opens}) vs closes (#{cond_closes})"
  end

  puts "  #{name}: max indent #{max_indent}, #{opens} choices (#{closes} ends), #{cond_opens} conditionals (#{cond_closes} ends)"
end

# === SUMMARY ===
puts "\n=== VALIDATION SUMMARY ==="
if errors.empty? && warnings.empty?
  puts "ALL CHECKS PASSED"
elsif errors.empty?
  puts "PASSED with #{warnings.length} warnings:"
  warnings.each { |w| puts "  WARNING: #{w}" }
else
  puts "FAILED with #{errors.length} errors and #{warnings.length} warnings:"
  errors.each { |e| puts "  ERROR: #{e}" }
  warnings.each { |w| puts "  WARNING: #{w}" }
end

# Cleanup
FileUtils.rm_rf(tmp_dir)

exit(errors.any? ? 1 : 0)
