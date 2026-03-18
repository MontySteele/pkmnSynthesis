#!/usr/bin/env ruby
# encoding: utf-8
# tools/validate_encounters.rb
#
# Validates trainer and wild Pokemon encounter consistency after map
# transplantation. Checks that trainer levels and wild encounter levels
# fall within expected ranges for each game phase.
#
# Usage: ruby tools/validate_encounters.rb <game_data_dir> [transplant_report.json]

require_relative 'rpgmaker_stubs'

# Additional stubs needed for loading game data files
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

# Stub for GameData classes used in encounters.dat and trainers.dat
module GameData
  class Encounter
    attr_accessor :id, :map, :version, :step_chances, :types
  end

  class Trainer
    attr_accessor :id, :id_number, :trainer_type, :real_name, :version
    attr_accessor :items, :real_lose_text, :pokemon
  end
end

# ─── Level progression table ──────────────────────────────────────────

LEVEL_PROGRESSION = {
  # ── Early game (Pallet → Pewter) ──
  "pallet_town" => { maps: [42, 43, 48, 77, 78, 76, 97, 185, 205], levels: [1, 10], desc: "Starting area" },
  "route_1" => { maps: [78, 97, 185], levels: [2, 5], desc: "First route" },
  "viridian_city" => { maps: [79, 80, 81, 83, 84, 85, 371, 458, 710, 711, 746, 38, 375, 40, 669, 655], levels: [2, 10], desc: "First city" },
  "route_2" => { maps: [86, 90, 92, 222], levels: [3, 8], desc: "Viridian to Pewter" },
  "viridian_forest" => { maps: [491], levels: [3, 7], desc: "Forest dungeon" },
  "pewter_city" => { maps: [91, 93, 380, 386, 392, 382, 96, 385, 381, 470, 459, 460], levels: [8, 14], desc: "First gym (Rock)" },

  # ── Mt. Moon → Cerulean ──
  "route_3" => { maps: [490], levels: [8, 12], desc: "Pewter to Mt. Moon" },
  "mt_moon" => { maps: [102, 103, 104, 105, 116, 117, 494, 496, 515, 699, 767, 801, 802, 827, 828], levels: [8, 14], desc: "First cave" },
  "route_4" => { maps: [106, 233, 236, 291], levels: [10, 14], desc: "Mt. Moon to Cerulean" },
  "cerulean_city" => { maps: [1, 2, 3, 4, 5, 6, 7, 384, 387, 388, 389, 461, 462, 383, 178, 390], levels: [15, 25], desc: "Second gym (Water)" },
  "route_24_25" => { maps: [8, 9, 10, 11], levels: [15, 22], desc: "Nugget Bridge / Bill's area" },

  # ── Cerulean → Vermilion ──
  "route_5" => { maps: [12, 13, 14, 15], levels: [15, 20], desc: "Cerulean to Saffron gate" },
  "route_6" => { maps: [16, 18], levels: [15, 20], desc: "Saffron gate to Vermilion" },
  "vermilion_city" => { maps: [19, 20, 21, 22, 23, 24, 25, 26, 37, 61, 226, 394, 395, 396, 463, 464, 546], levels: [20, 30], desc: "Third gym (Electric)" },
  "ss_anne" => { maps: [17, 27, 28, 29, 30, 31, 32, 34, 35, 36, 201], levels: [18, 25], desc: "S.S. Anne" },
  "route_11" => { maps: [155, 161], levels: [20, 25], desc: "Vermilion east" },
  "digletts_cave" => { maps: [140, 398, 399], levels: [15, 22], desc: "Diglett's Cave" },

  # ── Rock Tunnel → Lavender ──
  "route_9" => { maps: [351, 495], levels: [20, 25], desc: "Cerulean to Rock Tunnel" },
  "rock_tunnel" => { maps: [349, 350, 512, 513, 800], levels: [20, 28], desc: "Rock Tunnel" },
  "route_10" => { maps: [154], levels: [20, 25], desc: "Rock Tunnel to Lavender" },
  "lavender_town" => { maps: [50, 419, 420, 421, 422], levels: [25, 32], desc: "Lavender Town" },
  "pokemon_tower" => { maps: [142, 400, 401, 402, 403, 467, 468, 469, 556], levels: [25, 35], desc: "Pokemon Tower" },

  # ── Celadon area ──
  "route_8" => { maps: [409, 410, 411], levels: [25, 30], desc: "Lavender to Saffron gate" },
  "route_7" => { maps: [413, 415], levels: [25, 30], desc: "Saffron gate to Celadon" },
  "celadon_city" => { maps: [62, 63, 64, 65, 95, 408, 414, 542, 405, 510, 406, 407,
                              432, 433, 434, 435, 436, 514, 450, 451, 452, 453, 454,
                              465, 466, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507,
                              508, 509, 768, 771], levels: [25, 35], desc: "Fourth gym (Grass)" },
  "rocket_hideout" => { maps: [45, 449, 455, 456, 457, 446, 447, 448], levels: [25, 35], desc: "Team Rocket Hideout (Celadon)" },
  "celadon_sewers" => { maps: [72, 372, 431], levels: [25, 35], desc: "Celadon Sewers" },

  # ── South routes (Cycling Road → Fuchsia) ──
  "route_12" => { maps: [159], levels: [25, 32], desc: "South of Lavender" },
  "route_13" => { maps: [437], levels: [25, 32], desc: "South route" },
  "route_14" => { maps: [440], levels: [25, 32], desc: "South route" },
  "route_15" => { maps: [444], levels: [28, 35], desc: "South route to Fuchsia" },
  "route_16_17_18" => { maps: [438, 516, 146, 517, 518], levels: [28, 35], desc: "Cycling Road" },
  "fuchsia_city" => { maps: [472, 476, 60, 479, 87, 481, 482, 477, 478], levels: [30, 40], desc: "Poison gym" },
  "safari_zone" => { maps: [443, 445, 484, 485, 486, 487, 488, 715, 717, 718, 473, 804], levels: [22, 40], desc: "Safari Zone" },

  # ── Saffron / Silph Co. ──
  "saffron_city" => { maps: [108, 120, 122, 133, 141, 153, 156, 180, 182, 183, 184,
                              194, 196, 199, 200, 215, 232, 152, 191, 192, 179, 151,
                              110, 111, 112, 113, 114, 115, 701, 702, 772, 803, 825, 829], levels: [30, 40], desc: "Fighting/Psychic gym" },
  "silph_co" => { maps: [121, 212, 660, 661, 662, 663, 665, 666, 667, 668, 757, 807], levels: [30, 40], desc: "Silph Co. (all floors)" },

  # ── Water routes / Seafoam / Cinnabar ──
  "route_19_20" => { maps: [57, 58], levels: [30, 38], desc: "Water routes to Seafoam" },
  "seafoam_islands" => { maps: [808, 53, 54, 55], levels: [30, 40], desc: "Seafoam Islands" },
  "route_21" => { maps: [59], levels: [35, 42], desc: "Cinnabar to Pallet" },
  "cinnabar_island" => { maps: [98, 130, 188, 221, 125, 189, 190, 207, 219, 135, 136, 206, 208, 209, 721, 703], levels: [35, 45], desc: "Fire gym" },
  "pokemon_mansion" => { maps: [173, 174, 181, 187], levels: [35, 45], desc: "Pokemon Mansion" },
  "power_plant" => { maps: [144, 197, 198], levels: [30, 42], desc: "Power Plant" },

  # ── Endgame ──
  "route_22" => { maps: [171], levels: [35, 45], desc: "Viridian west" },
  "route_23" => { maps: [143], levels: [40, 50], desc: "Victory Road approach" },
  "victory_road" => { maps: [304, 306, 307], levels: [40, 50], desc: "Victory Road" },
  "elite_four" => { maps: [148, 260, 303, 314, 315, 316, 317, 318, 328, 341], levels: [45, 65], desc: "Indigo Plateau / Elite Four" },

  # ── Viridian Gym (revisit — late game) ──
  "viridian_gym" => { maps: [85], levels: [40, 50], desc: "Viridian Gym (Giovanni)" },
}

WARN_TOLERANCE = 5   # Levels outside expected range but within tolerance => WARN
ERROR_TOLERANCE = 10 # Levels outside expected range by more than this => ERROR

# ─── Data loading ─────────────────────────────────────────────────────

def load_marshal_safe(path)
  Marshal.load(File.binread(path))
rescue ArgumentError => e
  if e.message =~ /undefined class\/module (.+)/
    cls = $1
    parts = cls.split("::")
    mod = Object
    parts.each_with_index do |p, i|
      if i == parts.length - 1
        mod.const_set(p, Class.new) unless mod.const_defined?(p, false)
      else
        mod.const_set(p, Module.new) unless mod.const_defined?(p, false)
        mod = mod.const_get(p)
      end
    end
    retry
  else
    raise
  end
end

def load_map_infos(data_dir)
  path = File.join(data_dir, "MapInfos.rxdata")
  return {} unless File.exist?(path)
  infos = Marshal.load(File.binread(path))
  result = {}
  infos.each { |id, info| result[id] = info.name if info }
  result
end

def load_trainers(data_dir)
  path = File.join(data_dir, "trainers.dat")
  return {} unless File.exist?(path)
  data = load_marshal_safe(path)
  # Build lookup by [trainer_type, name, version]
  trainers = {}
  data.each do |key, trainer|
    next unless trainer.respond_to?(:trainer_type)
    # Both array keys and integer keys exist; we index by array key
    arr_key = if trainer.respond_to?(:id) && trainer.id.is_a?(Array)
                trainer.id
              elsif key.is_a?(Array)
                key
              else
                [trainer.trainer_type, trainer.real_name, trainer.version || 0]
              end
    trainers[arr_key] = trainer
  end
  trainers
end

def load_encounters(data_dir)
  path = File.join(data_dir, "encounters.dat")
  return {} unless File.exist?(path)
  data = load_marshal_safe(path)
  # encounters.dat is a Hash keyed by "mapid_version" symbols
  # Group by map ID
  by_map = Hash.new { |h, k| h[k] = [] }
  data.each do |_key, enc|
    next unless enc.respond_to?(:instance_variable_get)
    map_id = enc.instance_variable_get(:@map)
    types = enc.instance_variable_get(:@types)
    next unless map_id && types
    by_map[map_id] << { types: types }
  end
  by_map
end

# ─── Trainer battle extraction from map events ────────────────────────

TrainerBattle = Struct.new(:map_id, :event_id, :trainer_class, :trainer_name, :version, :levels)

def extract_trainer_battles(data_dir, trainers_db)
  battles = Hash.new { |h, k| h[k] = [] }

  Dir.glob(File.join(data_dir, "Map*.rxdata")).sort.each do |f|
    map_id = f[/Map(\d+)/, 1].to_i
    begin
      map = Marshal.load(File.binread(f))
      next unless map.respond_to?(:events) && map.events
      map.events.each do |eid, ev|
        next unless ev.respond_to?(:pages) && ev.pages
        ev.pages.each do |page|
          next unless page.list
          page.list.each do |cmd|
            # pbTrainerBattle appears in conditional branch (code 111, param[0]==12)
            # or in script calls (code 355/655)
            script_text = nil
            if cmd.code == 111 && cmd.parameters[0] == 12
              script_text = cmd.parameters[1].to_s
            elsif [355, 655].include?(cmd.code)
              script_text = cmd.parameters[0].to_s
            end

            next unless script_text && script_text =~ /pbTrainerBattle/

            # Parse: pbTrainerBattle(PBTrainers::CLASS,"Name",...,version,...)
            # or:    pbTrainerBattle(:CLASS,"Name",...,version,...)
            if script_text =~ /pbTrainerBattle\(\s*(?:PBTrainers::)?:?(\w+)\s*,\s*"([^"]+)"\s*(?:,\s*(?:_I\()?"[^"]*"(?:\))?\s*)?(?:,\s*(false|true)\s*)?(?:,\s*(\d+))?/
              trainer_class = $1.to_sym
              trainer_name = $2
              version = $4 ? $4.to_i : 0

              # Look up trainer in trainers.dat to get Pokemon levels
              levels = lookup_trainer_levels(trainers_db, trainer_class, trainer_name, version)

              battles[map_id] << TrainerBattle.new(
                map_id, eid, trainer_class, trainer_name, version, levels
              )
            end
          end
        end
      end
    rescue => e
      $stderr.puts "Warning: could not load #{f}: #{e.message}" if ENV['DEBUG']
    end
  end

  battles
end

def lookup_trainer_levels(trainers_db, trainer_class, trainer_name, version)
  # Try exact key match
  key = [trainer_class, trainer_name, version]
  trainer = trainers_db[key]

  # Try without version
  unless trainer
    key = [trainer_class, trainer_name, 0]
    trainer = trainers_db[key]
  end

  # Try case-insensitive match on trainer class
  unless trainer
    trainers_db.each do |k, v|
      next unless k.is_a?(Array) && k.length >= 3
      if k[0].to_s.downcase == trainer_class.to_s.downcase &&
         k[1].to_s == trainer_name &&
         k[2].to_i == version
        trainer = v
        break
      end
    end
  end

  return [] unless trainer

  pokemon = trainer.respond_to?(:pokemon) ? trainer.pokemon : trainer.instance_variable_get(:@pokemon)
  return [] unless pokemon.is_a?(Array)

  pokemon.map { |p| p.is_a?(Hash) ? p[:level] : nil }.compact
end

# ─── Wild encounter extraction ────────────────────────────────────────

WildEncounter = Struct.new(:species, :min_level, :max_level, :encounter_type)

def extract_wild_encounters(encounters_by_map)
  result = Hash.new { |h, k| h[k] = [] }

  encounters_by_map.each do |map_id, enc_list|
    enc_list.each do |enc|
      enc[:types].each do |type_name, entries|
        entries.each do |entry|
          # entry format: [chance, :SPECIES, min_level, max_level]
          next unless entry.is_a?(Array) && entry.length >= 4
          species = entry[1]
          min_lvl = entry[2].to_i
          max_lvl = entry[3].to_i
          result[map_id] << WildEncounter.new(species, min_lvl, max_lvl, type_name)
        end
      end
    end
  end

  result
end

# ─── Level checking ──────────────────────────────────────────────────

def check_level(level, expected_min, expected_max)
  return :ok if level >= expected_min && level <= expected_max
  diff = if level < expected_min
           expected_min - level
         else
           level - expected_max
         end
  return :error if diff > ERROR_TOLERANCE
  return :warn if diff > WARN_TOLERANCE
  :ok  # Within tolerance
end

def check_level_range(min_lvl, max_lvl, expected_min, expected_max)
  # Check if the encounter range overlaps or is near the expected range
  worst = :ok
  [min_lvl, max_lvl].each do |lvl|
    result = check_level(lvl, expected_min, expected_max)
    if result == :error
      worst = :error
    elsif result == :warn && worst != :error
      worst = :warn
    end
  end
  worst
end

# ─── Transplant report loading ────────────────────────────────────────

def load_transplant_report(path)
  return nil unless path && File.exist?(path)
  require 'json'
  JSON.parse(File.read(path))
rescue => e
  $stderr.puts "Warning: could not load transplant report: #{e.message}"
  nil
end

# ─── Main ─────────────────────────────────────────────────────────────

game_dir = ARGV[0]
transplant_report_path = ARGV[1]

unless game_dir
  abort "Usage: ruby tools/validate_encounters.rb <game_data_dir> [transplant_report.json]"
end

data_dir = File.join(game_dir, "Data")
unless File.directory?(data_dir)
  abort "Error: #{data_dir} is not a directory"
end

puts "Loading game data..."
map_names = load_map_infos(data_dir)
trainers_db = load_trainers(data_dir)
encounters_by_map = load_encounters(data_dir)
transplant_report = load_transplant_report(transplant_report_path)

puts "  Map names loaded: #{map_names.length}"
puts "  Trainer definitions loaded: #{trainers_db.length}"
puts "  Maps with encounters: #{encounters_by_map.length}"
puts "  Transplant report: #{transplant_report ? 'loaded' : 'not provided'}"
puts

puts "Extracting trainer battles from map events..."
trainer_battles = extract_trainer_battles(data_dir, trainers_db)
total_trainers = trainer_battles.values.flatten.length
puts "  Trainer battles found: #{total_trainers}"
puts

puts "Extracting wild encounter data..."
wild_encounters = extract_wild_encounters(encounters_by_map)
total_encounters = wild_encounters.values.flatten.length
puts "  Wild encounter entries: #{total_encounters}"
puts

# ─── Validation ───────────────────────────────────────────────────────

maps_checked = 0
trainers_ok = 0
trainers_warn = 0
trainers_error = 0
encounters_ok = 0
encounters_warn = 0
encounters_error = 0
maps_missing_data = []

puts "=" * 50
puts "=== Encounter Validation Report ==="
puts "=" * 50
puts

LEVEL_PROGRESSION.each do |phase_name, phase|
  expected_min, expected_max = phase[:levels]
  phase_has_output = false
  phase_header = "Phase: #{phase_name} (#{phase[:desc]}, expected levels #{expected_min}-#{expected_max})"

  phase[:maps].each do |map_id|
    maps_checked += 1
    map_name = map_names[map_id] || "Unknown"
    map_lines = []

    # Check trainers on this map
    if trainer_battles[map_id] && !trainer_battles[map_id].empty?
      trainer_battles[map_id].each do |battle|
        if battle.levels.empty?
          map_lines << "    Trainer: #{battle.trainer_class} #{battle.trainer_name} (levels unknown - not in trainers.dat)"
          next
        end

        level_str = battle.levels.join(", ")
        status = :ok
        battle.levels.each do |lvl|
          result = check_level(lvl, expected_min, expected_max)
          if result == :error
            status = :error
          elsif result == :warn && status != :error
            status = :warn
          end
        end

        case status
        when :ok
          trainers_ok += 1
          map_lines << "    Trainer: #{battle.trainer_class} #{battle.trainer_name} v#{battle.version} (levels #{level_str}) [OK]"
        when :warn
          trainers_warn += 1
          map_lines << "    Trainer: #{battle.trainer_class} #{battle.trainer_name} v#{battle.version} (levels #{level_str}) [WARN: outside expected #{expected_min}-#{expected_max}]"
        when :error
          trainers_error += 1
          map_lines << "    Trainer: #{battle.trainer_class} #{battle.trainer_name} v#{battle.version} (levels #{level_str}) [ERROR: far outside expected #{expected_min}-#{expected_max}]"
        end
      end
    end

    # Check wild encounters on this map
    if wild_encounters[map_id] && !wild_encounters[map_id].empty?
      # Group by species and encounter type to avoid duplicate reporting
      grouped = {}
      wild_encounters[map_id].each do |enc|
        key = "#{enc.species}_#{enc.encounter_type}"
        existing = grouped[key]
        if existing
          existing[:min] = [existing[:min], enc.min_level].min
          existing[:max] = [existing[:max], enc.max_level].max
        else
          grouped[key] = {
            species: enc.species,
            type: enc.encounter_type,
            min: enc.min_level,
            max: enc.max_level
          }
        end
      end

      by_type = grouped.values.group_by { |g| g[:type] }
      by_type.each do |enc_type, entries|
        parts = entries.map { |e| "#{e[:species]} #{e[:min]}-#{e[:max]}" }
        all_levels = entries.flat_map { |e| [e[:min], e[:max]] }
        min_lvl = all_levels.min
        max_lvl = all_levels.max

        status = check_level_range(min_lvl, max_lvl, expected_min, expected_max)

        case status
        when :ok
          encounters_ok += 1
          map_lines << "    Wild (#{enc_type}): #{parts.join(', ')} [OK]"
        when :warn
          encounters_warn += 1
          map_lines << "    Wild (#{enc_type}): #{parts.join(', ')} [WARN: outside expected #{expected_min}-#{expected_max}]"
        when :error
          encounters_error += 1
          map_lines << "    Wild (#{enc_type}): #{parts.join(', ')} [ERROR: far outside expected #{expected_min}-#{expected_max}]"
        end
      end
    end

    # Report maps with no data at all
    if !trainer_battles[map_id] && !wild_encounters[map_id]
      maps_missing_data << [map_id, map_name, phase_name]
    end

    unless map_lines.empty?
      unless phase_has_output
        puts phase_header
        phase_has_output = true
      end
      puts "  Map #{map_id} (#{map_name}):"
      map_lines.each { |l| puts l }
    end
  end

  puts if phase_has_output
end

# ─── Transplant report cross-check ───────────────────────────────────

if transplant_report
  puts "=" * 50
  puts "=== Transplant Cross-Check ==="
  puts "=" * 50
  puts

  # Check if transplanted maps lost encounter data
  transplanted_maps = transplant_report["transplanted_maps"] || transplant_report["maps"] || []
  if transplanted_maps.is_a?(Hash)
    transplanted_maps = transplanted_maps.keys.map(&:to_i)
  elsif transplanted_maps.is_a?(Array)
    transplanted_maps = transplanted_maps.map { |m| m.is_a?(Hash) ? (m["map_id"] || m["id"]).to_i : m.to_i }
  end

  transplanted_maps.each do |map_id|
    map_name = map_names[map_id] || "Unknown"
    had_encounters = encounters_by_map.key?(map_id)
    had_trainers = trainer_battles.key?(map_id) && !trainer_battles[map_id].empty?

    unless had_encounters || had_trainers
      puts "  Map #{map_id} (#{map_name}): transplanted but has no encounter/trainer data"
    end
  end

  puts "  Transplanted maps checked: #{transplanted_maps.length}"
  puts
end

# ─── Maps with no encounter data ─────────────────────────────────────

unless maps_missing_data.empty?
  puts "=" * 50
  puts "=== Maps in Progression with No Encounter Data ==="
  puts "=" * 50
  maps_missing_data.each do |map_id, map_name, phase|
    puts "  Map #{map_id} (#{map_name}) in phase '#{phase}'"
  end
  puts
end

# ─── Summary ──────────────────────────────────────────────────────────

puts "=" * 50
puts "=== Summary ==="
puts "=" * 50
puts "  Maps checked: #{maps_checked}"
puts "  Trainers found: #{total_trainers}"
puts "    Level OK:    #{trainers_ok}"
puts "    Level WARN:  #{trainers_warn}"
puts "    Level ERROR: #{trainers_error}"
puts "  Wild encounters checked: #{encounters_ok + encounters_warn + encounters_error}"
puts "    Level OK:    #{encounters_ok}"
puts "    Level WARN:  #{encounters_warn}"
puts "    Level ERROR: #{encounters_error}"
puts

has_errors = trainers_error > 0 || encounters_error > 0
if has_errors
  puts "RESULT: FAIL - #{trainers_error + encounters_error} encounter(s) far outside expected level range"
  exit 1
elsif trainers_warn > 0 || encounters_warn > 0
  puts "RESULT: WARN - #{trainers_warn + encounters_warn} encounter(s) slightly outside expected level range"
  exit 0
else
  puts "RESULT: PASS - all encounters within expected level ranges"
  exit 0
end
