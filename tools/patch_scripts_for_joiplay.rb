# encoding: utf-8
#!/usr/bin/env ruby
# Patches Ruby 1.9+/2.0+ syntax in game scripts for JoiPlay compatibility (Ruby 1.8).
#
# Transforms:
#   1. Safe navigation:    obj&.method(args)       →  (obj && obj.method(args))
#   2. Symbol hash keys:   { key: value }          →  { :key => value }
#   3. Keyword args in def: def foo(key: default)  →  options hash pattern
#   4. Encoding::UTF_8 / force_encoding            →  removed (no-op in 1.8)
#   5. Symbol#to_proc:     map(&:method)           →  map { |x| x.method }
#   6. chomp: true:        readlines(f, chomp:true) → readlines(f).map{|l|l.chomp}
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
  positions = []
  idx = 0
  while (found = line.index("&.", idx))
    positions << found
    idx = found + 2
  end

  positions.reverse.each do |amp_pos|
    dot_pos = amp_pos + 1
    recv_start = find_receiver_start(line, amp_pos)
    meth_end = find_method_end(line, dot_pos)
    next unless recv_start && meth_end

    receiver = line[recv_start...amp_pos]
    method_call = line[(dot_pos + 1)...meth_end]

    replacement = "(#{receiver} && #{receiver}.#{method_call})"
    line = line[0...recv_start] + replacement + line[meth_end..]
  end

  line
end

# ── Symbol hash key syntax helpers ──

# Converts `key: value` → `:key => value` in code portions of a line.
# Handles strings and comments to avoid false positives.
def patch_symbol_hash_keys(line)
  # Skip pure comment lines
  stripped = line.lstrip
  return line if stripped.start_with?("#")

  # Split line into code segments and string/comment segments
  # Process only the code segments
  result = ""
  i = 0
  in_code = true

  while i < line.length
    ch = line[i]

    # Track string boundaries (simplified — handles ' " and #-comments)
    if in_code
      if ch == "#"
        # Rest of line is a comment — append as-is
        result += line[i..]
        break
      elsif ch == '"'
        # Double-quoted string — find closing "
        result += ch
        i += 1
        while i < line.length && line[i] != '"'
          result += line[i]
          if line[i] == "\\"  # skip escaped char
            i += 1
            result += line[i] if i < line.length
          end
          i += 1
        end
        result += line[i].to_s if i < line.length  # closing quote
        i += 1
        next
      elsif ch == "'"
        # Single-quoted string — find closing '
        result += ch
        i += 1
        while i < line.length && line[i] != "'"
          result += line[i]
          if line[i] == "\\"
            i += 1
            result += line[i] if i < line.length
          end
          i += 1
        end
        result += line[i].to_s if i < line.length
        i += 1
        next
      end
    end

    # In code: look for word: pattern (symbol hash key)
    # Match: word character(s) followed by : and then a space (or end context)
    # Must NOT be preceded by : (that would be ::) or be a ternary
    if in_code && ch =~ /[a-zA-Z_]/
      # Capture the identifier
      start = i
      i += 1
      i += 1 while i < line.length && line[i] =~ /\w/

      # Check if followed by ": " (hash key) but not "::" (namespace)
      if i < line.length && line[i] == ":" && (i + 1 >= line.length || line[i + 1] != ":")
        # Check it's followed by a space or value-start character
        next_ch = (i + 1 < line.length) ? line[i + 1] : nil
        # Check not preceded by : (would be part of ::)
        prev_ch = (start > 0) ? line[start - 1] : nil

        if next_ch =~ /[\s]/ && prev_ch != ":"
          # This is a symbol hash key! Transform word: → :word =>
          word = line[start...i]
          result += ":#{word} =>"
          i += 1  # skip the colon
          next
        end
      end

      # Not a hash key — output the identifier as-is
      result += line[start...i]
      next
    end

    result += ch
    i += 1
  end

  result
end

# ── Keyword arguments in method definitions ──

# Detects `def method(pos_args..., key: default, ...)` and converts to
# `def method(pos_args..., _kw = {})` with extraction lines injected after.
# In Ruby 1.8, keyword args don't exist — callers pass a trailing hash
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
        # If a caller passes only keyword args (e.g., Game.save(:safe => true)),
        # the hash ends up in the first positional param. Detect and fix this.
        if positional.any?
          # Get the last positional param name (without default)
          last_pos_name = positional.last.split("=").first.strip
          # Also get first positional param name for hash-in-wrong-position detection
          first_pos_name = positional.first.split("=").first.strip
          result << "#{indent}  if #{first_pos_name}.is_a?(Hash) && _kw.empty?\n"
          result << "#{indent}    _kw = #{first_pos_name}\n"
          # Reset to default
          first_default = positional.first.include?("=") ? positional.first.split("=", 2).last.strip : "nil"
          result << "#{indent}    #{first_pos_name} = #{first_default}\n"
          result << "#{indent}  end\n"
        end

        # Extract keyword values from _kw hash
        keywords.each do |name, default|
          result << "#{indent}  #{name} = _kw.key?(:#{name}) ? _kw[:#{name}] : #{default}\n"
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

# ── Additional Ruby 1.9+ API patches ──

# Patches applied line-by-line for specific API incompatibilities
def patch_ruby19_apis(line)
  # Skip comments
  return line if line.lstrip.start_with?("#")

  # 1. Remove .force_encoding(Encoding::UTF_8) — no-op in Ruby 1.8
  line = line.gsub(/\.force_encoding\(Encoding::UTF_8\)/, "")

  # 2. Symbol#to_proc: map(&:method) → map { |_e| _e.method }
  #    Handles: .map(&:strip), .map(&:to_i), .map(&:dup), .map(&:capitalize)
  line = line.gsub(/\.\s*(map|select|reject|detect|collect|sort_by|min_by|max_by|flat_map|each)\(\&:(\w+[?!]?)\)/) do
    method = $1
    sym = $2
    ".#{method} { |_e| _e.#{sym} }"
  end

  # 3. chomp: true in File.readlines → readlines + map chomp
  #    File.readlines(path, chomp: true) → File.readlines(path).map { |_l| _l.chomp }
  line = line.gsub(/File\.readlines\(([^,)]+),\s*chomp:\s*true\)/) do
    path_arg = $1
    "File.readlines(#{path_arg}).map { |_l| _l.chomp }"
  end

  # 4. .to_h → Hash[...] (Array#to_h is Ruby 2.1+)
  line = line.gsub(/\.to_h\b(?!\s*\{)/) do
    ".inject({}) { |_h, (_k, _v)| _h[_k] = _v; _h }"
  end

  # 5. .bytesize → .length (in Ruby 1.8, String#length IS byte length)
  line = line.gsub(/\.bytesize\b/, ".length")

  # 6. .bytes → .unpack('C*') (String#bytes is Ruby 1.9+)
  line = line.gsub(/\.bytes\b(?!\s*\{)/, ".unpack('C*')")

  line
end

# ── Main processing ──

patched_count = 0

Dir.glob(File.join(scripts_dir, "**", "*.rb")).each do |path|
  original = File.read(path, encoding: "utf-8")
  lines = original.lines
  any_changed = false

  # First pass: patch keyword args in method definitions (adds lines)
  lines, kw_changed = patch_keyword_args_in_def(lines)
  any_changed = true if kw_changed

  # Second pass: patch safe navigation and symbol hash keys
  lines.each_with_index do |line, i|
    next if line.lstrip.start_with?("#")

    new_line = patch_ruby19_apis(line)        # before hash key conversion
    new_line = patch_safe_navigation(new_line)
    new_line = patch_symbol_hash_keys(new_line)

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
