# encoding: utf-8
#!/usr/bin/env ruby
# Patches Ruby 2.0+ syntax in game scripts for JoiPlay compatibility (Ruby 1.9).
#
# Transforms: receiver&.method_name(args)  →  (receiver && receiver.method_name(args))
#
# Usage: ruby patch_scripts_for_joiplay.rb <scripts_dir>

scripts_dir = ARGV[0]
unless scripts_dir && Dir.exist?(scripts_dir)
  $stderr.puts "Usage: #{$0} <scripts_dir>"
  exit 1
end

# Find the start position of the receiver expression to the left of &.
# Handles: @var, var, obj.method, Foo::Bar.method(args), list[idx], etc.
def find_receiver_start(line, ampersand_pos)
  pos = ampersand_pos - 1
  return nil if pos < 0

  loop do
    # If we're at a closing bracket/paren, walk back to find its match
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
      pos += 1  # now at open bracket
      # After finding open bracket, try to find an identifier before it
      # (e.g., method_name( or list[)
      if pos > 0 && line[pos - 1] =~ /[\w?!]/
        pos -= 1
        # Fall through to identifier handling below
      else
        # Bare brackets like [expr]&. — unlikely, but handle
        return pos
      end
    end

    # Walk back through identifier characters (word chars, @, ?)
    if line[pos] =~ /[\w@?!]/
      pos -= 1 while pos >= 0 && line[pos] =~ /[\w@]/
      pos += 1  # went one too far, now at start of identifier

      # Check if preceded by :: or . (method chain continues leftward)
      if pos >= 3 && line[pos - 2..pos - 1] == "::"
        pos -= 3  # move to char before ::
        next
      elsif pos >= 2 && line[pos - 1] == "."
        pos -= 2  # move to char before .
        next
      else
        return pos
      end
    else
      return nil
    end
  end
end

# Find the end position (exclusive) of the method call to the right of &.
# Captures: method_name, method_name?, method_name(args)
def find_method_end(line, dot_pos)
  pos = dot_pos + 1  # skip the '.'
  return nil if pos >= line.length || line[pos] !~ /\w/

  # Capture method name
  pos += 1 while pos < line.length && line[pos] =~ /\w/
  # Method may end with ? or !
  pos += 1 if pos < line.length && (line[pos] == "?" || line[pos] == "!")

  # Capture optional parenthesized arguments
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

patched_count = 0

Dir.glob(File.join(scripts_dir, "**", "*.rb")).each do |path|
  original = File.read(path, encoding: "utf-8")
  lines = original.lines
  any_changed = false

  lines.each_with_index do |line, i|
    next if line.lstrip.start_with?("#")

    # Find all &. positions, process from right to left to preserve indices
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

    if line != lines[i]
      lines[i] = line
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
