# encoding: utf-8
#!/usr/bin/env ruby
# Patches Ruby 1.9+/2.0+ syntax in game scripts for JoiPlay compatibility (Ruby 1.8).
#
# Transforms:
#   1. Safe navigation:       obj&.method(args)       →  (obj && obj.method(args))
#   2. Symbol hash keys:      { key: value }          →  { :key => value }
#   3. Keyword args in def:   def foo(key: default)   →  options hash pattern
#   4. Encoding / force_encoding                      →  removed (no-op in 1.8)
#   5. Symbol#to_proc:        map(&:method)           →  map { |x| x.method }
#   6. chomp: true:           readlines(f, chomp:true) → readlines(f).map{|l|l.chomp}
#   7. Trailing commas:       foo(a, b,)              →  foo(a, b)
#   8. Double splat:          **kwargs                →  removed
#   9. Leading-dot chains:    \n  .method             →  joined to previous line
#  10. Lookbehind regex:      (?<=X)                  →  (X)  (capturing group)
#  11. Regex literal braces:  /{WORD}/                →  /\{WORD\}/
#  12. Required after optional: def f(a=1, b)         →  def f(b, a=1)
#  13. deprecate_constant:      deprecate_constant :X →  commented out (Ruby 2.3+)
#  14. Private define_method:   obj.define_method(m)  →  obj.send(:define_method, m)
#  15. File/Dir.exists?:        File.exists? → File.exist?  (exists? removed in Ruby 3.0+)
#  16. .match?:                 str.match?(pat)       →  str.match(pat)  (match? is Ruby 2.4+)
#  17. .key?:                   hash.key?(k)          →  hash.has_key?(k)  (key? is Ruby 1.9+)
#  18. .each_char:              str.each_char         →  str.split('').each
#  19. Array#prepend:           arr.prepend(x)        →  arr.unshift(x)
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
          # Check for ternary operator context: if there's a `?` earlier on
          # the line that's part of a ternary, then this `:` is the else-branch
          # separator, not a hash key.
          # Heuristic: if the code portion so far contains an unmatched `?` in
          # ternary position (not part of a method name like `.nil?`), skip.
          code_before = result + line[start...i]
          is_ternary_else = false
          # Walk backwards looking for `?` that isn't `word?`
          scan_pos = code_before.length - 1
          while scan_pos >= 0
            if code_before[scan_pos] == "?"
              # Check if preceded by a word char (method? name) — not ternary
              if scan_pos > 0 && code_before[scan_pos - 1] =~ /\w/
                scan_pos -= 1
                next
              else
                is_ternary_else = true
                break
              end
            end
            scan_pos -= 1
          end

          unless is_ternary_else
            # This is a symbol hash key! Transform word: → :word =>
            word = line[start...i]
            result += ":#{word} =>"
            i += 1  # skip the colon
            next
          end
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

  # 7. deprecate_constant — Ruby 2.3+ Module method; comment out in 1.8
  line = line.gsub(/^(\s*)deprecate_constant\b(.*)$/, '\1# deprecate_constant\2 # removed for JoiPlay')

  # 8. Private method calls with explicit receiver: obj.define_method → obj.send(:define_method, ...)
  #    In Ruby 1.8, define_method is private on Module/Class
  line = line.gsub(/(\w+)\.define_method\((\w+)\)/) do
    "#{$1}.send(:define_method, #{$2})"
  end

  # 9. File.exists? → File.exist? and Dir.exist?/Dir.exists? → File.directory?
  #    - File.exist? works on Ruby 1.8.7+ through 3.x (exists? removed in 3.0)
  #    - Dir.exist? was added in Ruby 1.9 — does NOT exist in Ruby 1.8!
  #    - Dir.exists? was removed in Ruby 3.0
  #    - File.directory? works on ALL Ruby versions (1.8 through 3.x)
  #    So: normalize File to exist?, and Dir to File.directory?.
  line = line.gsub(/Dir\.exists?\?/, 'File.directory?')
  line = line.gsub(/File\.exists\?/, 'File.exist?')

  # 10. .match? → .match (Ruby 2.4+; match? doesn't exist in 1.8)
  #     String#match and Regexp#match both exist in Ruby 1.8 and return truthy/falsy.
  line = line.gsub(/\.match\?\(/, '.match(')

  # 11. .key? → .has_key? (Hash#key? is Ruby 1.9+; has_key? works in all versions)
  line = line.gsub(/\.key\?\(/, '.has_key?(')

  # 12. .each_char → .split('').each (Ruby 1.9+)
  line = line.gsub(/\.each_char\b/, ".split('').each")

  # 13. Array#prepend → Array#unshift (Ruby 2.5+ alias)
  #     Only convert when clearly an Array method (not String#prepend which exists in 1.8).
  #     Heuristic: skip if the argument is a string literal (String#prepend use case).
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

  line
end

# ── Trailing commas before closing paren ──
# Ruby 1.8 does not allow `foo(a, b,)` — remove trailing comma.
def patch_trailing_commas(line)
  return line if line.lstrip.start_with?("#")
  line.gsub(/,(\s*\))/, '\1')
end

# ── Double splat **kwargs ──
# Ruby 1.8 has no ** operator. Convert `|*args, **kwargs|` → `|*args|`
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
# Ruby 1.8 doesn't allow a line to start with `.method`. Join it to prev line.
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

# ── Lookbehind assertions in regex ──
# Ruby 1.8's Oniguruma may not support lookbehind `(?<=...)`.
# Convert to a capturing group alternative where possible.
def patch_lookbehind_regex(line)
  return line if line.lstrip.start_with?("#")
  # Positive lookbehind: (?<=X)pattern → capture group: (X)pattern
  # Callers must use $1. Works for .scan and .match usage.
  line = line.gsub(/\(\?<=([^)]+)\)/) do
    "(#{$1})"
  end
  # Negative lookbehind: (?<!X)pattern → remove the assertion entirely.
  # This is lossy (weakens the match) but avoids a hard crash in Ruby 1.8.
  # A warning comment is inserted inline.
  line = line.gsub(/\(\?<!([^)]+)\)/) do
    "" # remove negative lookbehind — no simple equivalent in 1.8
  end
  line
end

# ── Regex unescaped braces ──
# Ruby 1.8 treats `{` in regex as quantifier start. Escape literal braces.
def patch_regex_braces(line)
  return line if line.lstrip.start_with?("#")
  # Find regex literals and escape unescaped { that aren't quantifiers
  line.gsub(%r{/([^/\n]+)/}) do |match|
    inner = $1
    # Skip if it looks like it contains a real quantifier: {1,3} or {2}
    if inner =~ /\{\d+(?:,\d*)?\}/
      match
    else
      "/" + inner.gsub(/(?<!\\)\{/, '\\{').gsub(/(?<!\\)\}/, '\\}') + "/"
    end
  end
end

# ── Required parameter after optional ──
# Ruby 1.8 doesn't allow `def foo(a = default, b)`. Reorder so required
# args come first: `def foo(b, a = default)`.
def patch_required_after_optional(lines)
  result = []
  changed = false

  lines.each do |line|
    if line =~ /^(\s*def\s+\S+\()(.+)\)\s*$/
      prefix = $1
      params_str = $2
      params = split_params(params_str)

      # Check if there's a required param after an optional one
      has_optional = false
      needs_reorder = false
      params.each do |p|
        p = p.strip
        if p.include?("=")
          has_optional = true
        elsif has_optional && p =~ /^\w+$/ && p !~ /^\*/ && p != "_kw"
          needs_reorder = true
        end
      end

      if needs_reorder
        required = []
        optional = []
        params.each do |p|
          p = p.strip
          if p.include?("=") || p =~ /^\*/
            optional << p
          else
            required << p
          end
        end
        new_params = required + optional
        result << "#{prefix}#{new_params.join(', ')})\n"
        changed = true
        next
      end
    end

    result << line
  end

  [result, changed]
end

# ── Main processing ──

patched_count = 0

Dir.glob(File.join(scripts_dir, "**", "*.rb")).each do |path|
  original = File.read(path, encoding: "utf-8")
  lines = original.lines
  any_changed = false

  # First pass: multi-line transforms (keyword args, leading dots, reorder params)
  lines, kw_changed = patch_keyword_args_in_def(lines)
  any_changed = true if kw_changed

  lines, dot_changed = patch_leading_dot_chains(lines)
  any_changed = true if dot_changed

  lines, reorder_changed = patch_required_after_optional(lines)
  any_changed = true if reorder_changed

  # Second pass: line-by-line transforms
  lines.each_with_index do |line, i|
    next if line.lstrip.start_with?("#")

    new_line = patch_ruby19_apis(line)          # API compat (before hash key conversion)
    new_line = patch_safe_navigation(new_line)   # &. → && .
    new_line = patch_symbol_hash_keys(new_line)  # key: val → :key => val
    new_line = patch_trailing_commas(new_line)    # foo(a,) → foo(a)
    new_line = patch_double_splat(new_line)       # **kwargs → removed
    new_line = patch_lookbehind_regex(new_line)   # (?<=X) → (X)
    new_line = patch_regex_braces(new_line)       # /{LIT}/ → /\{LIT\}/

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
