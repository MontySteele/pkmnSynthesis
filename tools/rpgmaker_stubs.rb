# RPG Maker XP / RGSS class stubs for Marshal deserialization.
# These classes mirror the built-in RGSS classes so that Ruby's Marshal
# can load .rxdata files outside of the RPG Maker XP runtime.

module RPG
  class Map
    attr_accessor :tileset_id, :width, :height, :autoplay_bgm, :bgm
    attr_accessor :autoplay_bgs, :bgs, :encounter_list, :encounter_step
    attr_accessor :data, :events
  end

  class Event
    attr_accessor :id, :name, :x, :y, :pages

    class Page
      attr_accessor :condition, :graphic, :move_type, :move_speed
      attr_accessor :move_frequency, :move_route, :walk_anime, :step_anime
      attr_accessor :direction_fix, :through, :always_on_top, :trigger, :list

      class Condition
        attr_accessor :switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid
        attr_accessor :switch1_id, :switch2_id, :variable_id, :variable_value, :self_switch_ch
      end

      class Graphic
        attr_accessor :tile_id, :character_name, :character_hue
        attr_accessor :direction, :pattern, :opacity, :blend_type
      end
    end
  end

  class EventCommand
    attr_accessor :code, :indent, :parameters
  end

  class MoveRoute
    attr_accessor :repeat, :skippable, :list
  end

  class MoveCommand
    attr_accessor :code, :parameters
  end

  class AudioFile
    attr_accessor :name, :volume, :pitch
  end

  class MapInfo
    attr_accessor :name, :parent_id, :order, :expanded, :scroll_x, :scroll_y
  end

  class System
    attr_accessor :magic_number, :party_members, :elements, :switches, :variables
    attr_accessor :windowskin_name, :title_name, :gameover_name, :battle_transition
    attr_accessor :title_bgm, :battle_bgm, :battle_end_me, :gameover_me
    attr_accessor :cursor_se, :decision_se, :cancel_se, :buzzer_se, :equip_se
    attr_accessor :shop_se, :save_se, :load_se, :battle_start_se, :escape_se
    attr_accessor :actor_collapse_se, :enemy_collapse_se, :words
    attr_accessor :test_battlers, :test_troop_id, :start_map_id, :start_x, :start_y
    attr_accessor :battleback_name, :battler_name, :battler_hue, :edit_map_id

    class Words
      attr_accessor :gold, :hp, :sp, :str, :dex, :agi, :int
      attr_accessor :atk, :pdef, :mdef, :weapon, :armor1, :armor2, :armor3, :armor4
      attr_accessor :attack, :skill, :guard, :item, :equip
    end

    class TestBattler
      attr_accessor :actor_id, :level, :weapon_id
      attr_accessor :armor1_id, :armor2_id, :armor3_id, :armor4_id
    end
  end

  class CommonEvent
    attr_accessor :id, :name, :trigger, :switch_id, :list
  end

  class Animation
    attr_accessor :id, :name, :animation_name, :animation_hue
    attr_accessor :position, :frame_max, :frames, :timings

    class Frame
      attr_accessor :cell_max, :cell_data
    end

    class Timing
      attr_accessor :frame, :se, :flash_scope, :flash_color, :flash_duration, :condition
    end
  end
end

# RGSS built-in classes that use custom marshal format.
# We store the raw binary to guarantee byte-identical round-trips.

class Table
  def self._load(s)
    t = allocate
    t.instance_variable_set(:@raw, s)
    t
  end

  def _dump(_depth = 0)
    @raw
  end
end

class Tone
  def self._load(s)
    t = allocate
    t.instance_variable_set(:@raw, s)
    t
  end

  def _dump(_depth = 0)
    @raw
  end
end

class Color
  def self._load(s)
    t = allocate
    t.instance_variable_set(:@raw, s)
    t
  end

  def _dump(_depth = 0)
    @raw
  end
end
