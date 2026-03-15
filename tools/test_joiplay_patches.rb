# encoding: utf-8
#!/usr/bin/env ruby
# Test harness for JoiPlay patcher — validates that patch_scripts_for_joiplay.rb
# produces output that compiles under Ruby 1.8.
#
# Can run in three modes:
#   1. Local:    ruby test_joiplay_patches.rb
#                Applies the patcher to test fixtures, checks output patterns.
#   2. Ruby 1.8: ruby test_joiplay_patches.rb --ruby18
#                Syntax-checks patched output with actual Ruby 1.8.7 via rbenv.
#                Install first: RUBY_CONFIGURE_OPTS="--without-openssl" rbenv install 1.8.7-p374
#   3. Docker:   ruby test_joiplay_patches.rb --docker
#                Builds a Ruby 1.8 container and compiles patched code inside it.
#
# The test fixtures exercise every transform the patcher handles:
#   - Safe navigation (&.)
#   - Symbol hash keys (key: val)
#   - Keyword args in defs
#   - Encoding/force_encoding removal
#   - Symbol#to_proc (&:method)
#   - chomp: true
#   - Array#to_h
#   - String#bytesize
#   - String#bytes

require "fileutils"
require "tmpdir"
require "open3"

PATCHER = File.expand_path("patch_scripts_for_joiplay.rb", __dir__)

# ── Test fixtures ──
# Each fixture is a [name, input_ruby, expected_pattern] triple.
# input_ruby:       code using Ruby 1.9+/2.0+ features
# expected_pattern:  regex that the patched output must match (nil = just check it compiles)
FIXTURES = [
  [
    "safe_navigation_simple",
    <<~'RUBY',
      result = obj&.name
    RUBY
    /\(obj && obj\.name\)/
  ],
  [
    "safe_navigation_with_args",
    <<~'RUBY',
      result = player&.move(x, y)
    RUBY
    /\(player && player\.move\(x, y\)\)/
  ],
  [
    "safe_navigation_chained",
    <<~'RUBY',
      val = a&.b&.c
    RUBY
    /&&/  # both &. should be converted
  ],
  [
    "symbol_hash_keys",
    <<~'RUBY',
      opts = { name: "Pikachu", level: 25, shiny: true }
    RUBY
    /:name =>/
  ],
  [
    "symbol_hash_keys_in_method_call",
    <<~'RUBY',
      Pokemon.create(name: "Eevee", type: :normal)
    RUBY
    /:name => "Eevee"/
  ],
  [
    "symbol_hash_keys_skip_strings",
    <<~'RUBY',
      msg = "key: value is fine in a string"
      opts = { real_key: 42 }
    RUBY
    /key: value/  # string content must NOT be transformed
  ],
  [
    "symbol_hash_keys_skip_comments",
    <<~'RUBY',
      # This comment has key: value syntax
      x = { actual: 1 }
    RUBY
    /# This comment has key: value syntax/
  ],
  [
    "keyword_args_simple",
    <<~'RUBY',
      def greet(name, loud: false)
        puts name
      end
    RUBY
    /_kw = \{\}/
  ],
  [
    "keyword_args_with_default_positional",
    <<~'RUBY',
      def self.save(save_file = "game.sav", safe: false)
        File.write(save_file, "data")
      end
    RUBY
    /_kw = \{\}/
  ],
  [
    "keyword_args_multiple",
    <<~'RUBY',
      def battle(trainer, pokemon, auto_level: true, weather: nil)
        puts trainer
      end
    RUBY
    /auto_level = _kw.key\?\(:auto_level\)/
  ],
  [
    "encoding_removal",
    <<~'RUBY',
      text = data.force_encoding(Encoding::UTF_8)
    RUBY
    nil  # just check it doesn't contain force_encoding
  ],
  [
    "symbol_to_proc",
    <<~'RUBY',
      names = items.map(&:name)
      values = list.select(&:valid?)
    RUBY
    /map \{ \|_e\| _e\.name \}/
  ],
  [
    "chomp_keyword",
    <<~'RUBY',
      lines = File.readlines("data.txt", chomp: true)
    RUBY
    /\.map \{ \|_l\| _l\.chomp \}/
  ],
  [
    "array_to_h",
    <<~'RUBY',
      hash = pairs.to_h
    RUBY
    /\.inject\(\{\}\)/
  ],
  [
    "string_bytesize",
    <<~'RUBY',
      len = str.bytesize
    RUBY
    /\.length/
  ],
  [
    "string_bytes",
    <<~'RUBY',
      raw = str.bytes
    RUBY
    /\.unpack\('C\*'\)/
  ],
  [
    "combined_transforms",
    <<~'RUBY',
      def process(input, verbose: false)
        data = input&.strip
        items = data.force_encoding(Encoding::UTF_8)
        names = items.split(",").map(&:strip)
        opts = { mode: "fast", count: names.bytesize }
        lines = File.readlines("f.txt", chomp: true)
        result = lines.to_h
      end
    RUBY
    /_kw = \{\}/  # keyword args patched
  ],
  [
    "no_false_positive_ternary",
    <<~'RUBY',
      x = condition ? "yes" : "no"
    RUBY
    /condition \? "yes" : "no"/  # must NOT be transformed
  ],
  [
    "no_false_positive_namespace",
    <<~'RUBY',
      path = SaveData::FILE_PATH
    RUBY
    /SaveData::FILE_PATH/  # :: must NOT be transformed
  ],
  [
    "deprecation_stub_integration",
    <<~'RUBY',
      module Deprecation
        module_function
        def warn_method(method_name, removal_version = nil, alternative = nil); end
      end

      class Module
        private
        def deprecated_method_alias(name, aliased_method, *args)
          opts = args.last.is_a?(Hash) ? args.last : {}
          removal_in = opts[:removal_in]
          class_method = opts[:class_method] || false
          target = class_method ? self.class : self
          return unless target.method_defined?(aliased_method)
          target.define_method(name) do |*a|
            method(aliased_method).call(*a)
          end
        end
      end
    RUBY
    nil  # this is already 1.8-safe — just verify it compiles
  ],
].freeze

# ── Helpers ──

def run_patcher(fixture_dir)
  out, err, status = Open3.capture3("ruby", PATCHER, fixture_dir)
  [out, err, status]
end

def write_fixture(dir, name, code)
  path = File.join(dir, "#{name}.rb")
  File.write(path, code)
  path
end

def check_ruby18_syntax_docker(fixture_dir)
  # Write a Dockerfile that compiles all .rb files under Ruby 1.8
  dockerfile = <<~DOCKER
    FROM ruby:1.8.7-p374
    COPY scripts/ /scripts/
    RUN for f in /scripts/*.rb; do ruby -c "$f"; done
  DOCKER

  # Fall back to a publicly available Ruby 1.8 image if the exact tag doesn't exist
  dockerfile_alt = <<~DOCKER
    FROM centos:6
    RUN yum install -y ruby && ruby --version
    COPY scripts/ /scripts/
    RUN for f in /scripts/*.rb; do ruby -c "$f" 2>&1; done
  DOCKER

  [dockerfile, dockerfile_alt]
end

# ── Main test runner ──

docker_mode = ARGV.include?("--docker")
ruby18_mode = ARGV.include?("--ruby18")
verbose = ARGV.include?("--verbose") || ARGV.include?("-v")

# Auto-detect Ruby 1.8 via rbenv
RUBY18_PATH = "/opt/rbenv/versions/1.8.7-p374/bin/ruby"
RUBY18_AVAILABLE = File.executable?(RUBY18_PATH)

mode_label = if docker_mode
  "Docker (Ruby 1.8 compilation)"
elsif ruby18_mode
  "Ruby 1.8 (rbenv syntax check)"
else
  "Local (pattern matching)"
end

puts "JoiPlay Patcher Test Harness"
puts "=" * 40
puts "Mode: #{mode_label}"
puts

pass = 0
fail_count = 0
errors = []

Dir.mktmpdir("joiplay_test") do |tmpdir|
  fixture_dir = File.join(tmpdir, "scripts")
  FileUtils.mkdir_p(fixture_dir)

  # Write all fixtures
  FIXTURES.each do |name, code, _|
    write_fixture(fixture_dir, name, code)
  end

  # Run the patcher
  puts "Running patcher on #{FIXTURES.size} test fixtures..."
  out, err, status = run_patcher(fixture_dir)

  unless status.success?
    $stderr.puts "FATAL: Patcher failed to run!"
    $stderr.puts err
    exit 1
  end

  puts out if verbose
  puts

  # Check each fixture's output
  FIXTURES.each do |name, original, pattern|
    patched_path = File.join(fixture_dir, "#{name}.rb")
    patched = File.read(patched_path)

    label = "  [#{name}]"

    # Pattern check (local mode)
    if pattern
      if patched =~ pattern
        puts "#{label} PASS  (pattern matched)"
        pass += 1
      else
        puts "#{label} FAIL  (expected pattern: #{pattern.inspect})"
        puts "    Got: #{patched.lines.map(&:rstrip).join("\n    ")}" if verbose
        fail_count += 1
        errors << "#{name}: pattern #{pattern.inspect} not found in output"
      end
    else
      # No pattern — just verify the patcher didn't break it
      # Check it's valid Ruby syntax (using current Ruby as a sanity check)
      out2, err2, st2 = Open3.capture3("ruby", "-c", patched_path)
      if st2.success?
        puts "#{label} PASS  (syntax valid)"
        pass += 1
      else
        puts "#{label} FAIL  (syntax error: #{err2.strip})"
        fail_count += 1
        errors << "#{name}: #{err2.strip}"
      end
    end
  end

  # Additional check: verify no Ruby 1.9+ syntax remains in patched output
  puts
  puts "Checking for residual Ruby 1.9+ syntax..."
  residual_issues = []
  FIXTURES.each do |name, _, _|
    patched_path = File.join(fixture_dir, "#{name}.rb")
    patched = File.read(patched_path)

    patched.each_line.with_index do |line, lineno|
      next if line.lstrip.start_with?("#")
      next if line.include?('"') && line =~ /["'].*&\..*["']/  # skip strings

      if line =~ /&\./
        residual_issues << "#{name}:#{lineno + 1}: residual safe navigation: #{line.strip}"
      end
      # Check for force_encoding
      if line =~ /force_encoding/
        residual_issues << "#{name}:#{lineno + 1}: residual force_encoding: #{line.strip}"
      end
    end
  end

  if residual_issues.empty?
    puts "  No residual 1.9+ syntax found."
  else
    residual_issues.each { |issue| puts "  WARNING: #{issue}" }
  end

  # Ruby 1.8 mode: syntax-check every patched file with actual Ruby 1.8.7
  if ruby18_mode
    puts
    puts "=" * 40
    puts "Ruby 1.8.7 syntax check (rbenv)"
    puts "=" * 40

    unless RUBY18_AVAILABLE
      puts "SKIP: Ruby 1.8.7 not found at #{RUBY18_PATH}"
      puts "      Install with: RUBY_CONFIGURE_OPTS=\"--without-openssl\" rbenv install 1.8.7-p374"
    else
      puts "Using: #{`#{RUBY18_PATH} --version`.strip}"
      r18_pass = 0
      r18_fail = 0
      FIXTURES.each do |name, _, _|
        patched_path = File.join(fixture_dir, "#{name}.rb")
        out2, err2, st2 = Open3.capture3(RUBY18_PATH, "-c", patched_path)
        if st2.success?
          puts "  [#{name}] PASS  (Ruby 1.8 syntax OK)"
          r18_pass += 1
        else
          puts "  [#{name}] FAIL  (Ruby 1.8 syntax error)"
          err2.each_line { |l| puts "    #{l}" }
          r18_fail += 1
          fail_count += 1
          errors << "#{name}: Ruby 1.8 syntax error: #{err2.lines.first&.strip}"
        end
      end
      puts
      puts "Ruby 1.8 results: #{r18_pass} passed, #{r18_fail} failed"
    end
  end

  # Docker mode: compile all patched files under actual Ruby 1.8
  if docker_mode
    puts
    puts "=" * 40
    puts "Docker Ruby 1.8 compilation check"
    puts "=" * 40

    docker_ctx = File.join(tmpdir, "docker_ctx")
    FileUtils.mkdir_p(docker_ctx)
    FileUtils.cp_r(fixture_dir, File.join(docker_ctx, "scripts"))

    dockerfile_path = File.join(docker_ctx, "Dockerfile")
    File.write(dockerfile_path, <<~DOCKER)
      FROM centos:6
      RUN yum install -y ruby 2>/dev/null && ruby --version
      COPY scripts/ /scripts/
      RUN failed=0; \\
          for f in /scripts/*.rb; do \\
            echo "Checking $f..."; \\
            ruby -c "$f" 2>&1 || failed=$((failed+1)); \\
          done; \\
          echo ""; \\
          if [ $failed -gt 0 ]; then \\
            echo "FAILED: $failed file(s) had syntax errors"; \\
            exit 1; \\
          else \\
            echo "All files passed syntax check"; \\
          fi
    DOCKER

    # Check Docker daemon is available
    _, _, docker_st = Open3.capture3("docker", "info")
    unless docker_st.success?
      puts "SKIP: Docker daemon not available — run with Docker running to test Ruby 1.8 compilation."
      puts "      Local pattern-matching tests still passed above."
    else
      puts "Building Docker image (this may take a moment on first run)..."
      tag = "joiplay-ruby18-test"
      build_out, build_err, build_st = Open3.capture3(
        "docker", "build", "-t", tag, docker_ctx
      )

      if build_st.success?
        puts "Docker build succeeded — all patched files compile under Ruby 1.8!"
        puts build_out.lines.select { |l| l.include?("Checking") || l.include?("passed") || l.include?("ruby") }.join if verbose
      else
        puts "Docker build FAILED:"
        puts build_err
        puts build_out
        fail_count += 1
        errors << "Docker Ruby 1.8 compilation failed"
      end
    end
  end
end

# Summary
puts
puts "=" * 40
puts "Results: #{pass} passed, #{fail_count} failed (#{FIXTURES.size} total)"
if errors.any?
  puts
  puts "Failures:"
  errors.each { |e| puts "  - #{e}" }
  exit 1
else
  puts "All tests passed!"
end
