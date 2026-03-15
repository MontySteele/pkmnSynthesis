#!/usr/bin/env ruby
# patch_scripts_for_joiplay.rb — Patches Scripts.rxdata for JoiPlay compatibility.
#
# JoiPlay's RPG Maker plugin uses an older Ruby (1.9-era) that lacks Ruby 2.0+
# features like keyword arguments (**kwargs) and keyword-style method parameters.
# This script rewrites those patterns so the game boots on JoiPlay.
#
# Usage:
#   ruby patch_scripts_for_joiplay.rb <Scripts.rxdata> [output_path]
#
# If output_path is omitted, the file is modified in place.

require "zlib"

def load_scripts(path)
  Marshal.load(File.binread(path))
end

def save_scripts(scripts, path)
  File.binwrite(path, Marshal.dump(scripts))
end

def decompress(data)
  Zlib::Inflate.inflate(data)
rescue
  data  # already decompressed or empty
end

def compress(source)
  Zlib::Deflate.deflate(source)
end

# Patch Ruby 2.0+ syntax that JoiPlay's Ruby 1.9 can't parse.
def patch_source(source, script_name)
  original = source.dup
  patched = source.dup

  # 1. Replace **kwargs (double-splat) in method definitions with *args splat
  #    e.g.  def foo(name, **kwargs)  =>  def foo(name, *args); kwargs = (args.last.is_a?(Hash) ? args.pop : {})
  #    This is a simplified but functional transform for the Deprecation module patterns.

  # Handle method def lines with **kwargs parameter
  # Pattern: def method_name(params, **varname)
  patched.gsub!(/^(\s*def\s+\w+[?!]?\s*\([^)]*?),\s*\*\*(\w+)\)/) do
    prefix = $1
    kwname = $2
    "#{prefix}, __#{kwname}_hash__ = {})"
  end

  # Handle standalone **varname parameter (only param or first param)
  patched.gsub!(/^(\s*def\s+\w+[?!]?\s*\()\s*\*\*(\w+)\)/) do
    prefix = $1
    kwname = $2
    "#{prefix}__#{kwname}_hash__ = {})"
  end

  # Replace references to the original kwarg variable name with the hash version
  # (Only if we actually made substitutions above)
  if patched != original
    # Find all kwarg names we replaced
    original.scan(/\*\*(\w+)/).flatten.uniq.each do |kwname|
      # Don't replace in string literals or comments, but do replace variable references
      patched.gsub!(/(?<!\w)#{Regexp.escape(kwname)}(?!\w|_hash__)/, "__#{kwname}_hash__")
    end
  end

  # 2. Replace keyword arguments with hash-rocket syntax in method calls
  #    e.g.  method(foo: bar, baz: qux)  — these are fine in Ruby 1.9 actually
  #    The issue is specifically in method DEFINITIONS with key: value defaults

  # 3. Fix method definitions with keyword argument defaults
  #    e.g.  def foo(name:, aliased_method: nil, removal_in: nil, class_method: false)
  #    =>    def foo(options = {})  with extraction inside
  patched.gsub!(/^(\s*)(def\s+\w+[?!]?\s*)\((\s*\w+:\s*[^,)]*(?:,\s*\w+:\s*[^,)]*)*)\s*\)/) do |match|
    indent = $1
    defpart = $2
    kwargs_str = $3

    # Parse keyword arguments
    kwargs = kwargs_str.scan(/(\w+):\s*([^,]*)/).map do |name, default|
      default = default.strip
      default = "nil" if default.empty?
      [name, default]
    end

    # Build the replacement
    lines = ["#{indent}#{defpart}(__keyword_opts__ = {})"]
    kwargs.each do |name, default|
      if default == "nil"
        lines << "#{indent}  #{name} = __keyword_opts__.fetch(:#{name}, nil)"
      else
        lines << "#{indent}  #{name} = __keyword_opts__.fetch(:#{name}, #{default})"
      end
    end
    lines.join("\n")
  end

  # 4. Fix define_method blocks with **kwargs
  #    e.g.  target.define_method(name) do |*args, **kwargs|
  #    =>    target.define_method(name) do |*args|
  patched.gsub!(/(\.\s*define_method\s*\([^)]*\)\s*do\s*\|[^|]*?),\s*\*\*\w+\|/) do
    "#{$1}|"
  end

  # Also handle the case where **kwargs is the only block param after *args
  patched.gsub!(/(\.\s*define_method\s*\([^)]*\)\s*\{\s*\|[^|]*?),\s*\*\*\w+\|/) do
    "#{$1}|"
  end

  if patched != original
    $stderr.puts "  Patched: #{script_name}"
  end

  patched
end

def main
  input_path = ARGV[0]
  output_path = ARGV[1] || input_path

  unless input_path && File.exist?(input_path)
    $stderr.puts "Usage: ruby patch_scripts_for_joiplay.rb <Scripts.rxdata> [output_path]"
    exit 1
  end

  scripts = load_scripts(input_path)
  patched_count = 0

  scripts.each do |entry|
    # Scripts.rxdata format: [id, name, zlib_compressed_source]
    next unless entry.is_a?(Array) && entry.length >= 3

    _id, name, compressed = entry
    source = decompress(compressed)
    next if source.nil? || source.empty?

    patched = patch_source(source, name)
    if patched != source
      entry[2] = compress(patched)
      patched_count += 1
    end
  end

  save_scripts(scripts, output_path)
  $stderr.puts "Patched #{patched_count} script(s) for JoiPlay compatibility."
  $stderr.puts "Saved to: #{output_path}"
end

main
