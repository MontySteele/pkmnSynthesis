# encoding: utf-8
#!/usr/bin/env ruby
# Patches Ruby 1.9+/2.0+ syntax in game scripts for JoiPlay compatibility (Ruby 1.8).
#
# Transforms:
#   1. Safe navigation:  obj&.method(args)  →  (obj && obj.method(args))
#   2. Symbol hash keys:  { key: value }    →  { :key => value }
#      Also in method calls:  foo(key: val) →  foo(:key => val)
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

# ── Main processing ──

patched_count = 0

Dir.glob(File.join(scripts_dir, "**", "*.rb")).each do |path|
  original = File.read(path, encoding: "utf-8")
  lines = original.lines
  any_changed = false

  lines.each_with_index do |line, i|
    next if line.lstrip.start_with?("#")

    new_line = patch_safe_navigation(line)
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
