# encoding: utf-8
#!/usr/bin/env ruby
# tools/validate_switches.rb
#
# Scans the entire base game for usage of our Synthesis switches (1130, 1131)
# to confirm no collisions. Also validates the fork event structure.
#
# Usage: ruby tools/validate_switches.rb <game_root_dir>

require_relative 'rpgmaker_stubs'

game_dir = ARGV[0] || abort("Usage: ruby tools/validate_switches.rb <game_root_dir>")
data_dir = File.join(game_dir, "Data")

SYNTH_SWITCHES = [1130, 1131]

used = Hash.new { |h, k| h[k] = [] }

# Scan all maps
Dir.glob(File.join(data_dir, "Map*.rxdata")).sort.each do |f|
  map_id = f[/Map(\d+)/, 1].to_i
  begin
    data = Marshal.load(File.binread(f))
    next unless data.respond_to?(:events) && data.events
    data.events.each do |eid, ev|
      next unless ev.respond_to?(:pages) && ev.pages
      ev.pages.each_with_index do |page, pi|
        # Page conditions
        if page.condition
          if page.condition.switch1_valid && SYNTH_SWITCHES.include?(page.condition.switch1_id)
            used[page.condition.switch1_id] << "Map#{map_id} E#{eid} P#{pi} (page cond switch1)"
          end
          if page.condition.switch2_valid && SYNTH_SWITCHES.include?(page.condition.switch2_id)
            used[page.condition.switch2_id] << "Map#{map_id} E#{eid} P#{pi} (page cond switch2)"
          end
        end
        # Commands
        next unless page.list
        page.list.each_with_index do |cmd, ci|
          # Switch control (code 121): params [start_id, end_id, value]
          if cmd.code == 121 && cmd.parameters[0].is_a?(Integer)
            range = cmd.parameters[0]..cmd.parameters[1]
            SYNTH_SWITCHES.each do |sw|
              used[sw] << "Map#{map_id} E#{eid} P#{pi} cmd#{ci} (switch ctrl)" if range.include?(sw)
            end
          end
          # Conditional branch on switch (code 111, param[0]==0): params [0, switch_id]
          if cmd.code == 111 && cmd.parameters[0] == 0 && cmd.parameters[1].is_a?(Integer)
            SYNTH_SWITCHES.each do |sw|
              used[sw] << "Map#{map_id} E#{eid} P#{pi} cmd#{ci} (cond branch)" if cmd.parameters[1] == sw
            end
          end
          # Script calls referencing switch numbers
          if [355, 655].include?(cmd.code)
            s = cmd.parameters[0].to_s
            SYNTH_SWITCHES.each do |sw|
              # Use word boundary match to avoid false positives (e.g. "11300" matching "1130")
              used[sw] << "Map#{map_id} E#{eid} P#{pi} cmd#{ci} (script)" if s =~ /\b#{sw}\b/
            end
          end
        end
      end
    end
  rescue => e
    # skip
  end
end

# Scan common events
begin
  ce_path = File.join(data_dir, "CommonEvents.rxdata")
  if File.exist?(ce_path)
    ce_data = Marshal.load(File.binread(ce_path))
    ce_data.each do |ce|
      next unless ce && ce.respond_to?(:list) && ce.list
      ce.list.each_with_index do |cmd, ci|
        if cmd.code == 121 && cmd.parameters[0].is_a?(Integer)
          range = cmd.parameters[0]..cmd.parameters[1]
          SYNTH_SWITCHES.each do |sw|
            used[sw] << "CE#{ce.id} cmd#{ci} (switch ctrl)" if range.include?(sw)
          end
        end
        if cmd.code == 111 && cmd.parameters[0] == 0 && cmd.parameters[1].is_a?(Integer)
          SYNTH_SWITCHES.each do |sw|
            used[sw] << "CE#{ce.id} cmd#{ci} (cond branch)" if cmd.parameters[1] == sw
          end
        end
      end
    end
  end
rescue => e
  puts "CommonEvents error: #{e.message}"
end

# Also check the System switches array for names
begin
  sys_path = File.join(data_dir, "System.rxdata")
  if File.exist?(sys_path)
    sys = Marshal.load(File.binread(sys_path))
    if sys.respond_to?(:switches)
      SYNTH_SWITCHES.each do |sw|
        if sys.switches && sw < sys.switches.length && sys.switches[sw] && sys.switches[sw].to_s.strip != ""
          puts "Switch #{sw} has name in System: '#{sys.switches[sw]}'"
        end
      end
    end
  end
rescue => e
  puts "System check error: #{e.message}"
end

puts "=== Switch Collision Report ==="
SYNTH_SWITCHES.each do |sw|
  puts "\nSwitch #{sw}:"
  if used[sw].empty?
    puts "  CLEAR - not used anywhere in base game"
  else
    used[sw].each { |u| puts "  COLLISION: #{u}" }
  end
end

# Also find max switch ID in use to confirm we're in safe range
max_switch = 0
Dir.glob(File.join(data_dir, "Map*.rxdata")).each do |f|
  begin
    data = Marshal.load(File.binread(f))
    next unless data.respond_to?(:events) && data.events
    data.events.each do |eid, ev|
      next unless ev.respond_to?(:pages) && ev.pages
      ev.pages.each do |page|
        if page.condition
          max_switch = [max_switch, page.condition.switch1_id || 0, page.condition.switch2_id || 0].max
        end
        next unless page.list
        page.list.each do |cmd|
          if cmd.code == 121 && cmd.parameters[1].is_a?(Integer)
            max_switch = [max_switch, cmd.parameters[1]].max
          end
          if cmd.code == 111 && cmd.parameters[0] == 0 && cmd.parameters[1].is_a?(Integer)
            max_switch = [max_switch, cmd.parameters[1]].max
          end
        end
      end
    end
  rescue
  end
end
puts "\n=== Max switch ID in base game: #{max_switch} ==="
puts "Our switches: 1130, 1131"
puts max_switch < 1130 ? "SAFE: well above max used ID" : "WARNING: base game uses switches >= 1130"

# Exit with non-zero status if any collisions found
has_collisions = SYNTH_SWITCHES.any? { |sw| !used[sw].empty? }
exit 1 if has_collisions
