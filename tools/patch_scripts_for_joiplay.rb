# encoding: utf-8
#!/usr/bin/env ruby
# Patches Ruby 2.0+ syntax in game scripts for JoiPlay compatibility (Ruby 1.9).
#
# Target: Ruby 1.9 (JoiPlay's libmkxp19.so with "Use Ruby 1.8" OFF)
#
# Transforms (features NOT available in Ruby 1.9):
#   1. Safe navigation:       obj&.method(args)       →  (obj && obj.method(args))          [2.3+]
#   2. Keyword args in def:   def foo(key: default)   →  options hash pattern                [2.0+]
#   3. Double splat:          **kwargs                →  removed                             [2.0+]
#   4. Leading-dot chains:    \n  .method             →  joined to prev line                 [2.0+]
#   5. .match?:               str.match?(pat)         →  str.match(pat)                      [2.4+]
#   6. deprecate_constant:    deprecate_constant :X   →  commented out                       [2.3+]
#   7. .to_h:                 pairs.to_h              →  pairs.inject(...){...}              [2.1+]
#   8. chomp: true:           readlines(f,chomp:true) →  readlines(f).map{|l|l.chomp}        [2.4+]
#   9. Array#prepend:         arr.prepend(x)          →  arr.unshift(x)                      [2.5+]
#  10. Private define_method: obj.define_method(m)    →  obj.send(:define_method, m)
#  11. File.exists?:          File.exists?(p)         →  File.exist?(p)                      [removed 3.0]
#  12. Dir.exist?/exists?:    Dir.exist?(d)           →  File.directory?(d)                   [cross-version]
#  13. File.write:            File.write(p, d)        →  File.open(p,'w'){|f|f.write(d)}     [1.9.3 only]
#  14. Backslash paths:       "Graphics\\Battlers\\"  →  "Graphics/Battlers/"                [Linux/Android]
#
# Note: Kernel.method() calls are handled by a polyfill (not patcher transforms)
# because some game code uses Kernel.X inside def X to call the original.
#
# Dropped transforms (available in Ruby 1.9, were only needed for 1.8):
#   - Symbol hash keys (key: val), Encoding/force_encoding, Symbol#to_proc (&:method),
#     .bytesize, .bytes, .each_char, .key?, lookbehind regex, regex brace escaping,
#     required-after-optional params, trailing commas
#
# Usage: ruby patch_scripts_for_joiplay.rb <scripts_dir>

scripts_dir = ARGV[0]
unless scripts_dir && Dir.exist?(scripts_dir)
  $stderr.puts "Usage: #{$0} <scripts_dir>"
  exit 1
end

# ── Safe navigation operator helpers ──

def find_receiver_start(line, ampersand_pos)
  pos = ampersand_pos - 1
  return nil if pos < 0

  loop do
    if line[pos] == ")" || line[pos] == "]"
      close_char = line[pos]
      open_char = (close_char == ")") ? "(" : "["
      depth = 1
      pos -= 1
      while pos >= 0 && depth > 0
        depth += 1 if line[pos] == close_char
        depth -= 1 if line[pos] == open_char
        pos -= 1
      end
      return nil if depth != 0
      pos += 1
      if pos > 0 && line[pos - 1] =~ /[\w?!]/
        pos -= 1
      else
        return pos
      end
    end

    if line[pos] =~ /[\w@?!]/
      pos -= 1 while pos >= 0 && line[pos] =~ /[\w@]/
      pos += 1

      if pos >= 3 && line[pos - 2..pos - 1] == "::"
        pos -= 3
        next
      elsif pos >= 2 && line[pos - 1] == "."
        pos -= 2
        next
      else
        return pos
      end
    else
      return nil
    end
  end
end

def find_method_end(line, dot_pos)
  pos = dot_pos + 1
  return nil if pos >= line.length || line[pos] !~ /\w/

  pos += 1 while pos < line.length && line[pos] =~ /\w/
  pos += 1 if pos < line.length && (line[pos] == "?" || line[pos] == "!")

  if pos < line.length && line[pos] == "("
    depth = 1
    pos += 1
    while pos < line.length && depth > 0
      depth += 1 if line[pos] == "("
      depth -= 1 if line[pos] == ")"
      pos += 1
    end
    return nil if depth != 0
  end

  return pos
end

def patch_safe_navigation(line)
  # Loop until no &. remain — chained safe navigation (a&.b&.c) requires
  # multiple passes because each replacement changes the string layout.
  max_passes = 10  # safety limit
  max_passes.times do
    positions = []
    idx = 0
    while (found = line.index("&.", idx))
      positions << found
      idx = found + 2
    end
    break if positions.empty?

    changed = false
    positions.reverse.each do |amp_pos|
      dot_pos = amp_pos + 1
      recv_start = find_receiver_start(line, amp_pos)
      meth_end = find_method_end(line, dot_pos)
      next unless recv_start && meth_end

      receiver = line[recv_start...amp_pos]
      method_call = line[(dot_pos + 1)...meth_end]

      replacement = "(#{receiver} && #{receiver}.#{method_call})"
      line = line[0...recv_start] + replacement + line[meth_end..]
      changed = true
    end
    break unless changed
  end

  line
end

# ── Keyword arguments in method definitions ──

# Detects `def method(pos_args..., key: default, ...)` and converts to
# `def method(pos_args..., _kw = {})` with extraction lines injected after.
# In Ruby 1.9, keyword args don't exist — callers pass a trailing hash
# that Ruby auto-wraps, and it lands in the last positional parameter.
def patch_keyword_args_in_def(lines)
  result = []
  i = 0
  changed = false

  while i < lines.length
    line = lines[i]
    # Match: def [self.]method_name(... , key: default [, key2: default2])
    if line =~ /^(\s*def\s+\S+\()(.+)\)\s*$/
      prefix = $1  # "  def self.save("
      params_str = $2  # "save_file = SaveData::FILE_PATH, safe: false"
      indent = line[/^\s*/]

      # Split params, respecting nested parens/brackets
      params = split_params(params_str)

      # Separate positional params from keyword params
      positional = []
      keywords = []
      params.each do |p|
        p = p.strip
        if p =~ /^(\w+):\s*(.+)$/
          keywords << [$1, $2]  # [name, default]
        else
          positional << p
        end
      end

      if keywords.any?
        changed = true
        # Build new def line with positional params + _kw = {}
        new_params = positional + ["_kw = {}"]
        result << "#{prefix}#{new_params.join(', ')})\n"

        # Inject extraction lines: handle case where hash lands in wrong positional param
        if positional.any?
          first_pos_name = positional.first.split("=").first.strip
          result << "#{indent}  if #{first_pos_name}.is_a?(Hash) && _kw.empty?\n"
          result << "#{indent}    _kw = #{first_pos_name}\n"
          first_default = positional.first.include?("=") ? positional.first.split("=", 2).last.strip : "nil"
          result << "#{indent}    #{first_pos_name} = #{first_default}\n"
          result << "#{indent}  end\n"
        end

        # Extract keyword values from _kw hash
        keywords.each do |name, default|
          result << "#{indent}  #{name} = _kw.has_key?(:#{name}) ? _kw[:#{name}] : #{default}\n"
        end

        i += 1
        next
      end
    end

    result << line
    i += 1
  end

  [result, changed]
end

# Split a parameter string by commas, respecting nested parens/brackets
def split_params(str)
  params = []
  current = ""
  depth = 0
  str.each_char do |ch|
    if ch == "(" || ch == "["
      depth += 1
      current += ch
    elsif ch == ")" || ch == "]"
      depth -= 1
      current += ch
    elsif ch == "," && depth == 0
      params << current
      current = ""
    else
      current += ch
    end
  end
  params << current unless current.empty?
  params
end

# ── Ruby 2.0+ API patches ──

# Patches applied line-by-line for API incompatibilities with Ruby 1.9
def patch_post19_apis(line)
  # Skip comments
  return line if line.lstrip.start_with?("#")

  # 1. chomp: true in File.readlines (Ruby 2.4+)
  line = line.gsub(/File\.readlines\(([^,)]+),\s*chomp:\s*true\)/) do
    path_arg = $1
    "File.readlines(#{path_arg}).map { |_l| _l.chomp }"
  end

  # 2. .to_h (Array#to_h is Ruby 2.1+)
  line = line.gsub(/\.to_h\b(?!\s*\{)/) do
    ".inject({}) { |_h, (_k, _v)| _h[_k] = _v; _h }"
  end

  # 3. deprecate_constant — Ruby 2.3+ Module method; comment out
  line = line.gsub(/^(\s*)deprecate_constant\b(.*)$/, '\1# deprecate_constant\2 # removed for JoiPlay')

  # 4. Private method calls with explicit receiver: obj.define_method → obj.send(:define_method, ...)
  #    In Ruby 1.9, define_method is private on Module/Class
  line = line.gsub(/(\w+)\.define_method\((\w+)\)/) do
    "#{$1}.send(:define_method, #{$2})"
  end

  # 5. File.exists? → File.exist? and Dir.exist?/Dir.exists? → File.directory?
  #    - File.exist? works on Ruby 1.8.7+ through 3.x (exists? removed in 3.0)
  #    - Dir.exist? works in Ruby 1.9+ but Dir.exists? removed in 3.0
  #    - File.directory? works on ALL Ruby versions
  #    Normalize Dir to File.directory? for cross-version safety.
  line = line.gsub(/Dir\.exists?\?/, 'File.directory?')
  line = line.gsub(/File\.exists\?/, 'File.exist?')

  # 6. .match? → .match (Ruby 2.4+; match? doesn't exist in 1.9)
  line = line.gsub(/\.match\?\(/, '.match(')

  # 7. Array#prepend → Array#unshift (Ruby 2.5+ alias)
  #    Only convert when clearly an Array method (not String#prepend which exists in 1.9).
  line = line.gsub(/\.prepend\(([^)]*)\)/) do
    captured = $1
    arg = captured.strip
    # String#prepend takes a single string arg — skip those
    if arg.start_with?('"') || arg.start_with?("'")
      ".prepend(#{captured})"
    else
      ".unshift(#{captured})"
    end
  end

  # 8. File.write → File.open(..., 'w') { |f| f.write(...) }
  #    File.write was added in Ruby 1.9.3; may not exist in all 1.9.x builds
  line = line.gsub(/File\.write\(([^,]+),\s*(.+)\)/) do
    "File.open(#{$1}, 'w') { |_fw| _fw.write(#{$2}) }"
  end

  # 9. Windows backslash paths → forward slashes (JoiPlay runs on Linux/Android)
  #    Only convert inside string literals where the path starts with "Graphics\\"
  line = line.gsub(/"(Graphics(?:\\\\[^"]*)+)"/) do
    '"' + $1.gsub('\\\\', '/') + '"'
  end

  line
end

# ── Double splat **kwargs ──
# Ruby 1.9 has no ** operator. Convert `|*args, **kwargs|` → `|*args|`
# and `method(*args, **kwargs)` → `method(*args)`.
# Also converts `def foo(*args, **kwargs)` → `def foo(*args)`.
def patch_double_splat(line)
  return line if line.lstrip.start_with?("#")
  # In block params: |*args, **kw| → |*args|
  line = line.gsub(/,\s*\*\*\w+\|/, '|')
  # In method calls and defs: (*args, **kw) → (*args)
  line = line.gsub(/,\s*\*\*\w+\)/, ')')
  # Standalone **kw in params: (** kw) — unlikely but handle it
  line = line.gsub(/\(\*\*\w+\)/, '()')
  line
end

# ── Leading-dot method chains ──
# Ruby 1.9 doesn't allow a line to start with `.method`. Join it to prev line.
# (Leading-dot continuation was added in Ruby 2.0.)
def patch_leading_dot_chains(lines)
  result = []
  changed = false
  lines.each do |line|
    if line =~ /^\s+\./ && result.length > 0
      # This line starts with a dot — append to previous line
      prev = result.last.rstrip
      continuation = line.lstrip  # ".method(...)"
      result[-1] = prev + continuation + "\n"
      changed = true
    else
      result << line
    end
  end
  [result, changed]
end

# ── Main processing ──

patched_count = 0

Dir.glob(File.join(scripts_dir, "**", "*.rb")).each do |path|
  original = File.read(path, encoding: "utf-8")
  lines = original.lines
  any_changed = false

  # First pass: multi-line transforms (keyword args, leading dots)
  lines, kw_changed = patch_keyword_args_in_def(lines)
  any_changed = true if kw_changed

  lines, dot_changed = patch_leading_dot_chains(lines)
  any_changed = true if dot_changed

  # Second pass: line-by-line transforms
  lines.each_with_index do |line, i|
    next if line.lstrip.start_with?("#")

    new_line = patch_post19_apis(line)          # API compat
    new_line = patch_safe_navigation(new_line)   # &. → && .
    new_line = patch_double_splat(new_line)       # **kwargs → removed

    if new_line != lines[i]
      lines[i] = new_line
      any_changed = true
    end
  end

  if any_changed
    File.write(path, lines.join)
    rel = path.sub(scripts_dir + "/", "")
    puts "Patched: #{rel}"
    patched_count += 1
  end
end

puts "#{patched_count} file(s) patched for JoiPlay compatibility."
