#!/usr/bin/env ruby
# tools/add_trainer.rb
#
# Adds a new trainer entry to the compiled trainers.dat file.
# Used to create the Silph Co version of Archer (version 1)
# with a team comparable to Giovanni v4 (levels 45-51).
#
# Usage:
#   ruby tools/add_trainer.rb <game_data_dir> [--dry-run]
#
# The game_data_dir should be the base game's root (containing Data/).

game_data_dir = ARGV[0] || abort("Usage: ruby tools/add_trainer.rb <game_data_dir> [--dry-run]")
dry_run = ARGV.include?("--dry-run")

trainers_path = File.join(game_data_dir, "Data", "trainers.dat")
abort("trainers.dat not found at #{trainers_path}") unless File.exist?(trainers_path)

# Load the game's compatibility script for PBTrainers constants
compat_path = File.join(game_data_dir, "Data", "Scripts", "049_Compatibility", "PBTrainers.rb")
require compat_path if File.exist?(compat_path)

# Stub GameData classes for Marshal deserialization
module GameData
  class TrainerType; end
  class Trainer
    attr_accessor :id, :id_number, :trainer_type, :real_name, :version, :items, :real_lose_text, :pokemon
    def initialize; end
  end
  class Species; end
end

data = Marshal.load(File.binread(trainers_path))

key = [:ROCKETEXEC_Archer, "Archer", 1]

if data.key?(key)
  puts "Trainer entry #{key.inspect} already exists!"
  existing = data[key]
  puts "  Pokemon: #{existing.pokemon.inspect}"
  exit 0
end

# Clone the existing Archer v0 as a base
base = data[[:ROCKETEXEC_Archer, "Archer", 0]]
abort("Cannot find base Archer v0 entry!") unless base

# Create new trainer by cloning and modifying
trainer = Marshal.load(Marshal.dump(base))
trainer.instance_variable_set(:@id, key)
trainer.instance_variable_set(:@id_number, data.values.select { |t| t.respond_to?(:id_number) }.map(&:id_number).max + 1)
trainer.instance_variable_set(:@version, 1)
trainer.instance_variable_set(:@items, [:MAXPOTION])
trainer.instance_variable_set(:@real_lose_text, "You shouldn't have come here.")
trainer.instance_variable_set(:@pokemon, [
  # Scaled versions of his v0 team + 1 new mon
  # Giovanni v4: 45/45/47/51 with 4 mons and Max Potion
  { species: :B57H228,  level: 46, poke_ball: :ROCKETBALL },  # Primeape/Houndoom
  { species: :B168H110, level: 46, poke_ball: :ROCKETBALL },  # Ariados/Weezing
  { species: :B229H208, level: 48, poke_ball: :ROCKETBALL },  # Houndoom/Steelix (ace from v0)
  { species: :B24H89,   level: 50, poke_ball: :ROCKETBALL },  # Arbok/Muk (new, tough anchor)
])

if dry_run
  puts "[DRY RUN] Would add trainer entry: #{key.inspect}"
  puts "  ID number: #{trainer.id_number}"
  puts "  Items: #{trainer.items.inspect}"
  puts "  Pokemon:"
  trainer.pokemon.each do |p|
    puts "    #{p[:species]} Lv.#{p[:level]} (#{p[:poke_ball]})"
  end
  puts "  Lose text: #{trainer.real_lose_text}"
  puts ""
  puts "  For comparison, Giovanni v4:"
  g4 = data[[:ROCKETBOSS, "Giovanni", 4]]
  puts "  Items: #{g4.items.inspect}"
  g4.pokemon.each do |p|
    puts "    #{p[:species]} Lv.#{p[:level]} (#{p[:poke_ball]})"
  end
else
  data[key] = trainer
  File.binwrite(trainers_path, Marshal.dump(data))
  puts "Added trainer entry: #{key.inspect}"
  puts "  Wrote updated trainers.dat (#{File.size(trainers_path)} bytes)"
end
