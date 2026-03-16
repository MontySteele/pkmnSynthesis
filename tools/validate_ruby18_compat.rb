# encoding: utf-8
#!/usr/bin/env ruby
# Validates that patched game scripts are compatible with Ruby 1.8 (JoiPlay).
#
# This script simulates the patcher output by running patch_scripts_for_joiplay.rb
# on a temporary copy of the scripts, then scans the result for known Ruby 1.9+/2.0+
# patterns that would crash at runtime.
#
# Usage: ruby validate_ruby18_compat.rb <scripts_dir>
#   Or:  ruby validate_ruby18_compat.rb --post-patch <patched_scripts_dir>

require 'fileutils'
require 'tempfile'

# ── Known Ruby 1.9+/2.0+ incompatibility patterns ──
# Each check: [regex, description, severity]
# severity: :error (will crash), :warn (might crash depending on context)

LINE_CHECKS = [
  # Syntax features
  [/(?<!\w)&\./, "Safe navigation operator (&.)", :error],
  [/(?<!:)\b\w+:\s(?!:)(?!.*=>)/, "Ruby 1.9 symbol hash key syntax (key: value)", :warn],
  [/(?:,\s*|[\(|]\s*)\*\*\w+/, "Double splat operator (**kwargs)", :error],

  # Method APIs that don't exist in 1.8
  # File/Dir.exist? is supported by JoiPlay's Ruby; exists? has been removed
  # [/(?:File|Dir)\.exist\?/, "File/Dir.exist? (use .exists? in 1.8)", :error],
  [/\.force_encoding\b/, ".force_encoding (no encoding API in 1.8)", :error],
  [/\.encode\(/, ".encode() (no encoding API in 1.8)", :error],
  [/Encoding::/, "Encoding constants (no Encoding class in 1.8)", :error],
  [/\.bytesize\b/, ".bytesize (use .length in 1.8)", :error],
  [/\.bytes\b(?!\s*\{)/, ".bytes (use .unpack('C*') in 1.8)", :error],
  [/\.to_h\b(?!\s*\{)/, ".to_h (Array#to_h is Ruby 2.1+)", :error],
  [/\.chars\b(?!\s*\{)/, ".chars without block (Ruby 1.9+)", :warn],
  [/\.each_char\b/, ".each_char (Ruby 1.9+, use .split('').each)", :warn],
  [/\.prepend\b/, ".prepend (String#prepend is Ruby 1.9+)", :error],
  [/(?<!Graphics)\.freeze\b/, ".freeze (harmless but unnecessary in 1.8)", :warn],

  # Class/Module methods
  [/^\s*deprecate_constant\b/, "deprecate_constant (Ruby 2.3+)", :error],
  [/\w+\.define_method\(/, "Public define_method call (private in 1.8)", :error],
  [/\w+\.public_send\(/, "public_send (Ruby 1.9+, use send)", :error],
  [/\brespond_to_missing\?\b/, "respond_to_missing? (Ruby 1.9+)", :warn],
  [/\bdefine_singleton_method\b/, "define_singleton_method (Ruby 1.9+)", :error],

  # Kernel / Object methods
  [/\b__dir__\b/i, "__dir__ (Ruby 2.0+)", :error],
  [/\b__callee__\b/, "__callee__ (Ruby 1.9+)", :error],
  [/\bHash\.try_convert\b/, "Hash.try_convert (Ruby 1.9+)", :error],
  [/\bArray\.try_convert\b/, "Array.try_convert (Ruby 1.9+)", :error],

  # Hash methods
  [/\.key\b(?!\s*=>)(?!\?)/, ".key (Hash#key is Ruby 1.9+, use .index)", :warn],

  # Proc / Lambda
  [/->\s*[\({]/, "Stabby lambda (-> {})", :error],
  [/\.curry\b/, ".curry (Ruby 1.9+)", :error],

  # Regex
  [/\(\?<=/, "Lookbehind assertion in regex (may not work in 1.8)", :warn],
  [/\(\?<!/, "Negative lookbehind in regex (may not work in 1.8)", :warn],
  [/\\h\b/, "\\h hex digit shorthand in regex (Ruby 1.9+)", :warn],

  # String
  [/\?\w\s*==\s*\d/, "?char returns String in 1.9+ but Integer in 1.8", :warn],

  # Keyword arguments in def (should already be patched)
  # We check for the pattern but with lower confidence since the hash key check may false-positive
]

# Patterns that are OK in comments/strings but bad in code
SKIP_IN_COMMENTS = true

def in_string_or_comment?(line, match_start)
  # Simple heuristic: check if we're after a # or inside quotes
  code_before = line[0...match_start]

  # After a comment
  stripped = ""
  in_str = nil
  code_before.each_char.with_index do |ch, i|
    if in_str.nil?
      return true if ch == "#"
      in_str = ch if ch == '"' || ch == "'"
    elsif ch == in_str
      in_str = nil
    elsif ch == "\\" && in_str == '"'
      next # skip escaped
    end
  end
  !in_str.nil? # true if we're still inside a string
end

def validate_file(path, errors, warnings)
  lines = File.read(path, encoding: "utf-8").lines
  rel_path = path

  lines.each_with_index do |line, idx|
    line_num = idx + 1
    stripped = line.lstrip

    # Skip comment lines entirely
    next if stripped.start_with?("#")
    # Skip require lines (they reference gem names, not code)
    next if stripped.start_with?("require ")

    LINE_CHECKS.each do |pattern, description, severity|
      if line =~ pattern
        match_start = $~.begin(0)
        next if in_string_or_comment?(line, match_start)

        entry = {
          file: rel_path,
          line: line_num,
          desc: description,
          code: line.rstrip,
          severity: severity
        }

        if severity == :error
          errors << entry
        else
          warnings << entry
        end
      end
    end
  end
end

# ── Main ──

if ARGV.empty?
  $stderr.puts "Usage: ruby validate_ruby18_compat.rb <scripts_dir>"
  $stderr.puts "       ruby validate_ruby18_compat.rb --post-patch <patched_scripts_dir>"
  exit 1
end

post_patch_mode = ARGV[0] == "--post-patch"
scripts_dir = post_patch_mode ? ARGV[1] : ARGV[0]

unless scripts_dir && Dir.exist?(scripts_dir)
  $stderr.puts "Error: Directory not found: #{scripts_dir}"
  exit 1
end

# If not --post-patch, run the patcher on a temp copy first
if !post_patch_mode
  puts "Creating temporary copy and running patcher..."
  tmp_dir = Dir.mktmpdir("ruby18_validate_")
  begin
    FileUtils.cp_r(Dir.glob(File.join(scripts_dir, "*")), tmp_dir)

    patcher = File.join(File.dirname(__FILE__), "patch_scripts_for_joiplay.rb")
    unless File.exist?(patcher)
      $stderr.puts "Error: Patcher not found at #{patcher}"
      exit 1
    end

    system("ruby", patcher, tmp_dir)
    puts ""
    scripts_dir = tmp_dir
  rescue => e
    $stderr.puts "Error running patcher: #{e.message}"
    FileUtils.rm_rf(tmp_dir) if tmp_dir
    exit 1
  end
end

puts "Scanning for Ruby 1.8 incompatibilities..."
puts "=" * 70

errors = []
warnings = []

Dir.glob(File.join(scripts_dir, "**", "*.rb")).sort.each do |path|
  rel = path.sub(scripts_dir + "/", "")
  validate_file(path, errors, warnings)
  # Update relative path in results
  errors.each { |e| e[:file] = rel if e[:file] == path }
  warnings.each { |w| w[:file] = rel if w[:file] == path }
end

# Clean up temp dir if we created one
if !post_patch_mode && defined?(tmp_dir)
  FileUtils.rm_rf(tmp_dir)
end

# ── Report ──

if errors.empty? && warnings.empty?
  puts "\nAll clear! No Ruby 1.8 incompatibilities detected after patching."
  exit 0
end

if errors.any?
  puts "\n#{"ERROR".ljust(8)} #{errors.length} issue(s) that WILL crash on Ruby 1.8:"
  puts "-" * 70
  errors.group_by { |e| e[:desc] }.each do |desc, group|
    puts "\n  #{desc} (#{group.length} occurrence#{'s' if group.length > 1}):"
    group.first(10).each do |e|
      puts "    #{e[:file]}:#{e[:line]}"
      puts "      #{e[:code]}"
    end
    puts "    ... and #{group.length - 10} more" if group.length > 10
  end
end

if warnings.any?
  puts "\n#{"WARN".ljust(8)} #{warnings.length} issue(s) that MAY cause problems on Ruby 1.8:"
  puts "-" * 70
  warnings.group_by { |w| w[:desc] }.each do |desc, group|
    puts "\n  #{desc} (#{group.length} occurrence#{'s' if group.length > 1}):"
    group.first(5).each do |w|
      puts "    #{w[:file]}:#{w[:line]}"
      puts "      #{w[:code]}"
    end
    puts "    ... and #{group.length - 5} more" if group.length > 5
  end
end

puts "\n#{"=" * 70}"
puts "Summary: #{errors.length} error(s), #{warnings.length} warning(s)"
exit(errors.any? ? 1 : 0)
