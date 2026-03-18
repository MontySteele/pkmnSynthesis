#!/usr/bin/env ruby
# validate_transplant.rb — Validates transplanted maps against the transplant report.
#
# Usage:
#   ruby tools/validate_transplant.rb <game_data_dir> <transplant_report.json>
#
# For each transplanted map in the report, this validator checks:
#   1. Event count matches the report
#   2. All events are on walkable tiles (using tileset passages)
#   3. All warps (Transfer Player, code 201) point to valid map files
#   4. The tileset_id matches the target map's tileset
#
# Exit code 0 if all checks pass, 1 if any fail.

require "json"
require_relative "rpgmaker_stubs"

module RPG
  class Tileset
    attr_accessor :id, :name, :tileset_name, :autotile_names
    attr_accessor :panorama_name, :panorama_hue
    attr_accessor :fog_name, :fog_hue, :fog_opacity, :fog_blend_type
    attr_accessor :fog_zoom, :fog_sx, :fog_sy
    attr_accessor :battleback_name
    attr_accessor :passages, :priorities, :terrain_tags
  end
end

# ─── Tile / passability helpers ────────────────────────────────────────────

def parse_table(table)
  raw = table.instance_variable_get(:@raw)
  _ndim, xsize, ysize, zsize, _total = raw.unpack("V5")
  tiles = raw[20..-1].unpack("v*")
  { xsize: xsize, ysize: ysize, zsize: zsize, tiles: tiles }
end

def load_passages(tilesets, tileset_id)
  ts = tilesets[tileset_id]
  return nil unless ts && ts.passages
  praw = ts.passages.instance_variable_get(:@raw)
  praw[20..-1].unpack("v*")
end

def tile_passable?(tile_id, passages)
  return true if tile_id == 0
  return true if !passages || tile_id >= passages.length
  (passages[tile_id] & 0x0F) == 0
end

def cell_walkable?(x, y, tiles, xsize, ysize, zsize, passages)
  (0...zsize).each do |z|
    tid = tiles[x + y * xsize + z * xsize * ysize]
    next if tid == 0
    return false unless tile_passable?(tid, passages)
  end
  true
end

# ─── Map I/O ──────────────────────────────────────────────────────────────

def load_map(data_dir, map_id)
  path = File.join(data_dir, "Data", "Map%03d.rxdata" % map_id)
  return nil unless File.exist?(path)
  Marshal.load(File.binread(path))
end

def map_file_exists?(data_dir, map_id)
  File.exist?(File.join(data_dir, "Data", "Map%03d.rxdata" % map_id))
end

def load_tilesets(data_dir)
  path = File.join(data_dir, "Data", "Tilesets.rxdata")
  return nil unless File.exist?(path)
  Marshal.load(File.binread(path))
end

# ─── Validator ─────────────────────────────────────────────────────────────

class TransplantValidator
  def initialize(game_dir)
    @game_dir = game_dir
    @tilesets = load_tilesets(game_dir)
    @errors = []
    @warnings = []
    @checks_run = 0
    @checks_passed = 0
  end

  def validate_report(report)
    transplants = report["transplants"] || []

    if transplants.empty?
      error("Report contains no transplants")
      return summary
    end

    unless @tilesets
      error("Tilesets.rxdata not found in #{@game_dir}")
      return summary
    end

    transplants.each do |t|
      validate_transplant(t)
    end

    summary
  end

  private

  def validate_transplant(t)
    output_id = t["output_map_id"]
    target_id = t["target_map_id"]
    expected_events = t["events_after"]
    label = "Map%03d" % output_id

    puts "--- Validating #{label} (target=Map%03d) ---" % target_id

    # Load the output map (the transplanted result)
    map = load_map(@game_dir, output_id)
    unless map
      error("#{label}: output map file not found")
      return
    end

    # Load the target map to get its tileset_id
    target_map = load_map(@game_dir, target_id)

    # ── Check 1: Event count ──
    check("#{label}: event count") do
      actual = (map.events || {}).length
      if expected_events && actual != expected_events
        "expected #{expected_events} events, found #{actual}"
      else
        nil
      end
    end

    # ── Check 2: Tileset matches target ──
    if target_map
      check("#{label}: tileset_id matches target") do
        if map.tileset_id != target_map.tileset_id
          "output tileset_id=#{map.tileset_id}, target tileset_id=#{target_map.tileset_id}"
        else
          nil
        end
      end
    else
      warning("#{label}: could not load target map Map%03d for tileset comparison" % target_id)
    end

    # ── Check 3: Events on walkable tiles ──
    passages = load_passages(@tilesets, map.tileset_id)
    td = parse_table(map.data)

    unwalkable = []
    (map.events || {}).each do |eid, ev|
      next if ev.x < 0 || ev.x >= td[:xsize] || ev.y < 0 || ev.y >= td[:ysize]
      unless cell_walkable?(ev.x, ev.y, td[:tiles], td[:xsize], td[:ysize], td[:zsize], passages)
        unwalkable << { id: eid, name: ev.name, x: ev.x, y: ev.y }
      end
    end

    check("#{label}: events on walkable tiles") do
      if unwalkable.any?
        msgs = unwalkable.first(5).map { |e| "  E#{e[:id]} (#{e[:name]}) at (#{e[:x]},#{e[:y]})" }
        extra = unwalkable.length > 5 ? "\n  ... and #{unwalkable.length - 5} more" : ""
        "#{unwalkable.length} event(s) on non-walkable tiles:\n#{msgs.join("\n")}#{extra}"
      else
        nil
      end
    end

    # ── Check 4: All warps point to valid map files ──
    invalid_warps = []
    (map.events || {}).each do |eid, ev|
      next unless ev.pages
      ev.pages.each_with_index do |page, pi|
        next unless page.list
        page.list.each do |cmd|
          next unless cmd.code == 201         # Transfer Player
          next unless cmd.parameters[0] == 0  # Direct designation only
          warp_target = cmd.parameters[1]
          unless map_file_exists?(@game_dir, warp_target)
            invalid_warps << { event_id: eid, event_name: ev.name, page: pi, target: warp_target }
          end
        end
      end
    end

    check("#{label}: warp targets valid") do
      if invalid_warps.any?
        msgs = invalid_warps.first(5).map do |w|
          "  E#{w[:event_id]} (#{w[:event_name]}) page #{w[:page]} -> Map%03d (missing)" % w[:target]
        end
        extra = invalid_warps.length > 5 ? "\n  ... and #{invalid_warps.length - 5} more" : ""
        "#{invalid_warps.length} warp(s) to non-existent maps:\n#{msgs.join("\n")}#{extra}"
      else
        nil
      end
    end

    # ── Check 5: Events in bounds ──
    out_of_bounds = []
    (map.events || {}).each do |eid, ev|
      if ev.x < 0 || ev.x >= td[:xsize] || ev.y < 0 || ev.y >= td[:ysize]
        out_of_bounds << { id: eid, name: ev.name, x: ev.x, y: ev.y }
      end
    end

    check("#{label}: events in bounds (#{td[:xsize]}x#{td[:ysize]})") do
      if out_of_bounds.any?
        msgs = out_of_bounds.first(5).map { |e| "  E#{e[:id]} (#{e[:name]}) at (#{e[:x]},#{e[:y]})" }
        "#{out_of_bounds.length} event(s) out of bounds:\n#{msgs.join("\n")}"
      else
        nil
      end
    end
  end

  def check(label)
    @checks_run += 1
    failure = yield
    if failure
      error("#{label}: #{failure}")
    else
      puts "  [PASS] #{label}"
      @checks_passed += 1
    end
  end

  def error(msg)
    puts "  [FAIL] #{msg}"
    @errors << msg
  end

  def warning(msg)
    puts "  [WARN] #{msg}"
    @warnings << msg
  end

  def summary
    puts ""
    puts "=" * 60
    puts "Transplant Validation Summary"
    puts "=" * 60
    puts "  Checks run:    #{@checks_run}"
    puts "  Checks passed: #{@checks_passed}"
    puts "  Errors:        #{@errors.length}"
    puts "  Warnings:      #{@warnings.length}"
    puts "=" * 60

    if @errors.empty?
      puts "RESULT: PASS"
    else
      puts "RESULT: FAIL"
      @errors.each { |e| puts "  - #{e}" }
    end

    @errors.empty?
  end
end

# ─── Main ─────────────────────────────────────────────────────────────────

def main
  game_data_dir = ARGV[0]
  report_file = ARGV[1]

  unless game_data_dir && report_file
    $stderr.puts "Usage: ruby tools/validate_transplant.rb <game_data_dir> <transplant_report.json>"
    exit 1
  end

  unless File.directory?(game_data_dir)
    $stderr.puts "Error: Game data directory not found: #{game_data_dir}"
    exit 1
  end

  unless File.exist?(report_file)
    $stderr.puts "Error: Report file not found: #{report_file}"
    exit 1
  end

  report = JSON.parse(File.read(report_file))
  validator = TransplantValidator.new(game_data_dir)
  success = validator.validate_report(report)
  exit(success ? 0 : 1)
end

main
