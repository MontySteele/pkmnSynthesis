# encoding: utf-8
#!/usr/bin/env ruby
# Validates that JoiPlay-patched game scripts actually parse under both
# Ruby 1.8.7 and Ruby 3.x — the two runtimes JoiPlay ships (libmkxp18.so
# and libmkxp30.so).
#
# This goes beyond regex-based checks: it runs `ruby -c` (syntax check) on
# every patched script file using real Ruby 1.8.7 and 3.x interpreters via
# rbenv, catching issues that pattern matching would miss.
#
# Usage:
#   ruby tools/validate_joiplay_boot.rb [game_data/Data/Scripts]
#
# Requirements:
#   - rbenv with Ruby 1.8.7-p374 and a Ruby 3.x version installed
#   - Install 1.8.7: RUBY_CONFIGURE_OPTS="--without-openssl" rbenv install 1.8.7-p374
#
# Exit codes:
#   0 = all scripts pass syntax check under both Rubies
#   1 = one or more scripts failed

require "fileutils"
require "tmpdir"
require "open3"

PATCHER = File.expand_path("patch_scripts_for_joiplay.rb", __dir__)

# ── Locate Ruby interpreters via rbenv ──

RBENV_ROOT = ENV["RBENV_ROOT"] || File.expand_path("~/.rbenv")
# Also check /opt/rbenv which is common in CI environments
RBENV_ROOTS = [RBENV_ROOT, "/opt/rbenv"].uniq

def find_ruby(version_prefix)
  RBENV_ROOTS.each do |root|
    versions_dir = File.join(root, "versions")
    next unless Dir.exist?(versions_dir)
    Dir.entries(versions_dir).sort.each do |entry|
      if entry.start_with?(version_prefix)
        bin = File.join(versions_dir, entry, "bin", "ruby")
        return bin if File.executable?(bin)
      end
    end
  end
  nil
end

RUBY18 = find_ruby("1.8")
RUBY3X = find_ruby("3.")

# ── Syntax check a single file ──

def syntax_check(ruby_bin, script_path)
  out, err, status = Open3.capture3(ruby_bin, "-c", script_path)
  [status.success?, err.strip]
end

# ── Main ──

scripts_dir = ARGV[0] || File.join(Dir.pwd, "game_data", "Data", "Scripts")

unless Dir.exist?(scripts_dir)
  $stderr.puts "Error: Scripts directory not found: #{scripts_dir}"
  $stderr.puts "Usage: ruby #{$0} [path/to/Scripts]"
  exit 1
end

rubies = {}
rubies["Ruby 1.8"] = RUBY18 if RUBY18
rubies["Ruby 3.x"] = RUBY3X if RUBY3X

if rubies.empty?
  $stderr.puts "Error: No Ruby 1.8 or 3.x found via rbenv."
  $stderr.puts "Install with:"
  $stderr.puts '  RUBY_CONFIGURE_OPTS="--without-openssl" rbenv install 1.8.7-p374'
  $stderr.puts "  rbenv install 3.1.6"
  exit 1
end

# Show versions
puts "JoiPlay Boot Validator"
puts "=" * 60
rubies.each do |label, bin|
  version = `#{bin} --version 2>&1`.strip
  puts "  #{label}: #{version} (#{bin})"
end
puts

# Count scripts
script_files = Dir.glob(File.join(scripts_dir, "**", "*.rb")).sort
puts "Scripts directory: #{scripts_dir}"
puts "Script files found: #{script_files.length}"
puts

# ── Step 1: Copy scripts to temp dir ──

puts "Step 1/3: Copying scripts to temp directory..."
tmpdir = Dir.mktmpdir("joiplay_boot_validate_")
begin
  FileUtils.cp_r(Dir.glob(File.join(scripts_dir, "*")), tmpdir)
  patched_files = Dir.glob(File.join(tmpdir, "**", "*.rb")).sort
  puts "  Copied #{patched_files.length} files."

  # ── Step 2: Run the patcher ──

  puts "Step 2/3: Running JoiPlay patcher..."
  out, err, status = Open3.capture3("ruby", PATCHER, tmpdir)
  unless status.success?
    $stderr.puts "FATAL: Patcher failed!"
    $stderr.puts err
    FileUtils.rm_rf(tmpdir)
    exit 1
  end
  # Show patcher summary (last few lines)
  summary_lines = out.lines.select { |l| l =~ /patched|files|changes|total/i }
  summary_lines.each { |l| puts "  #{l.rstrip}" }
  puts "  Patcher completed successfully."
  puts

  # Refresh file list after patching
  patched_files = Dir.glob(File.join(tmpdir, "**", "*.rb")).sort

  # ── Step 3: Syntax check under each Ruby ──

  puts "Step 3/3: Syntax-checking #{patched_files.length} files..."
  puts

  all_passed = true

  rubies.each do |label, ruby_bin|
    puts "── #{label} ──"
    failures = []
    pass_count = 0

    patched_files.each do |f|
      ok, err_msg = syntax_check(ruby_bin, f)
      rel = f.sub(tmpdir + "/", "")
      if ok
        pass_count += 1
      else
        failures << { file: rel, error: err_msg }
      end
    end

    if failures.empty?
      puts "  ALL #{pass_count} scripts passed syntax check."
    else
      all_passed = false
      puts "  #{pass_count} passed, #{failures.length} FAILED:"
      failures.each do |f|
        puts "    FAIL: #{f[:file]}"
        # Show first line of error (most useful)
        f[:error].lines.first(3).each { |l| puts "      #{l.rstrip}" }
      end
    end
    puts
  end

  # ── Summary ──

  puts "=" * 60
  if all_passed
    puts "RESULT: All scripts pass syntax check under all Ruby versions."
    puts "JoiPlay should be able to load these scripts."
  else
    puts "RESULT: Some scripts have syntax errors."
    puts "JoiPlay will crash when loading these scripts."
  end

  exit(all_passed ? 0 : 1)

ensure
  FileUtils.rm_rf(tmpdir) if tmpdir
end
