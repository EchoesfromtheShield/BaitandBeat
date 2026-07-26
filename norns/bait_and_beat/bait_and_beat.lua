-- Bait & Beat
--
-- A fishing game
-- for Norns.
-- By Echoes from
-- the Shield.
--
-- E1 pages
-- K3 cast/hook
-- E3 line/tension
-- P2 caught fish
-- P3 music settings

engine.name = "BaitAndBeat"

local Config = include("bait_and_beat/lib/config")
local Game = include("bait_and_beat/lib/game")
local GenesisSerial = include("bait_and_beat/lib/genesis_serial")
local Music = include("bait_and_beat/lib/music")
local Render = include("bait_and_beat/lib/render")

local game = nil
local genesis = nil
local redraw_dirty = true
local display_page = 1
local observed_state = nil
local ui = {
  mode = "list",
  selected_index = 1,
  action_index = 2,
  settings_index = 1,
}
local ui_actions = { "free", "mix", "mod" }
local settings_count = 3
local update_display_page_from_state = nil

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function wrap_index(value, max)
  return ((value - 1) % max) + 1
end

local function norns_fallback_controls()
  return not (genesis and genesis:is_connected())
end

local function ui_active()
  return game ~= nil and display_page == 2 and game.state ~= "STRUGGLE"
end

local function settings_active()
  return game ~= nil and display_page == 3 and game.state ~= "STRUGGLE"
end

local function selected_layer()
  return game and game:captured_layer(ui.selected_index) or nil
end

local function handle_ui_encoder(n, delta)
  if not ui_active() then
    return false
  end

  if ui.mode == "list" then
    if n == 3 then
      ui.selected_index = wrap_index(ui.selected_index + delta, 3)
      redraw_dirty = true
      return true
    elseif n == 2 then
      ui.action_index = wrap_index(ui.action_index + delta, #ui_actions)
      redraw_dirty = true
      return true
    end
  elseif ui.mode == "mix" then
    if n == 3 then
      local layer = selected_layer()
      if layer then
        game:set_captured_volume(ui.selected_index, clamp((layer.volume_0_1 or 0.85) + delta * 0.025, 0, 1))
      end
      redraw_dirty = true
      return true
    end
  elseif ui.mode == "mod" then
    local layer = selected_layer()
    if layer and n == 2 then
      game:set_captured_mod(ui.selected_index, clamp((layer.mod_x or 0.5) + delta * 0.025, 0, 1), layer.mod_y or 0.5)
      redraw_dirty = true
      return true
    elseif layer and n == 3 then
      game:set_captured_mod(ui.selected_index, layer.mod_x or 0.5, clamp((layer.mod_y or 0.5) + delta * 0.025, 0, 1))
      redraw_dirty = true
      return true
    end
  end

  return false
end

local function apply_root_note(index)
  Config.ROOT_NOTE_INDEX = wrap_index(index, #Config.NOTES)
  Config.ROOT_HZ = Config.NOTES[Config.ROOT_NOTE_INDEX].hz
  Config.BASE_DRONE_HZ = Config.ROOT_HZ
end

local function apply_scale(index)
  Config.SCALE_INDEX = wrap_index(index, #Config.SCALES)
  Config.SCALE = Config.SCALES[Config.SCALE_INDEX].intervals
end

local function handle_settings_encoder(n, delta)
  if not settings_active() then
    return false
  end

  if n == 2 then
    ui.settings_index = wrap_index((ui.settings_index or 1) + delta, settings_count)
    redraw_dirty = true
    return true
  elseif n == 3 then
    if ui.settings_index == 1 then
      Config.BPM = clamp(math.floor((Config.BPM or 90) + delta + 0.5), 40, 240)
      Music.set_bpm(Config.BPM)
    elseif ui.settings_index == 2 then
      apply_root_note((Config.ROOT_NOTE_INDEX or 3) + delta)
    elseif ui.settings_index == 3 then
      apply_scale((Config.SCALE_INDEX or 5) + delta)
    end
    redraw_dirty = true
    return true
  end

  return false
end

local function handle_ui_press()
  if not ui_active() then
    return false
  end

  local layer = selected_layer()
  if ui.mode == "mix" or ui.mode == "mod" then
    ui.mode = "list"
    redraw_dirty = true
    return true
  end

  if not layer then
    redraw_dirty = true
    return true
  end

  local action = ui_actions[ui.action_index]
  if action == "free" then
    game:free_captured(ui.selected_index)
  elseif action == "mix" then
    ui.mode = "mix"
  elseif action == "mod" then
    ui.mode = "mod"
  end

  redraw_dirty = true
  return true
end

local function handle_settings_press()
  if not settings_active() then
    return false
  end

  display_page = 1
  redraw_dirty = true
  return true
end

local genesis_input = {}

function genesis_input:encoder(delta)
  if not handle_settings_encoder(3, delta) and not handle_ui_encoder(3, delta) then
    game:encoder(delta)
  end
end

function genesis_input:press()
  if not handle_settings_press() and not handle_ui_press() then
    game:press()
    update_display_page_from_state()
  end
end

function update_display_page_from_state()
  if not game or game.state == observed_state then
    return
  end

  if game.state == "STRUGGLE" then
    display_page = 2
    ui.mode = "list"
  elseif observed_state == "STRUGGLE" or game.state == "CAST" then
    display_page = 1
    ui.mode = "list"
  end

  observed_state = game.state
  redraw_dirty = true
end

local function loop()
  while true do
    clock.sleep(Config.TICK_S)
    if genesis and genesis:poll(genesis_input) then
      redraw_dirty = true
    end
    update_display_page_from_state()

    local events = game:update(Config.TICK_S)
    update_display_page_from_state()
    Music.tick(game, events)
    if genesis then
      genesis:tick(Config.TICK_S, game, Music.drone_params(game), events)
    end

    redraw_dirty = true
    redraw()
  end
end

function init()
  game = Game.new(Config)
  observed_state = game.state
  Music.init(game)
  genesis = GenesisSerial.new(Config)
  genesis:open()
  clock.run(loop)
end

function cleanup()
  Music.cleanup()
end

function enc(n, delta)
  if n == 1 and game then
    if game.state == "STRUGGLE" then
      display_page = 2
    elseif delta ~= 0 then
      display_page = wrap_index(display_page + delta, 3)
      if display_page ~= 2 then
        ui.mode = "list"
      end
    end
    redraw_dirty = true
    return
  end

  if handle_settings_encoder(n, delta) or handle_ui_encoder(n, delta) then
    return
  end

  if n == 3 and game and norns_fallback_controls() then
    game:encoder(delta)
    redraw_dirty = true
  end
end

function key(n, z)
  if n == 3 and z == 1 and (handle_settings_press() or handle_ui_press()) then
    return
  end

  if n == 3 and z == 1 and game and norns_fallback_controls() then
    game:press()
    update_display_page_from_state()
    redraw_dirty = true
  end
end

function redraw()
  if not redraw_dirty or not game then
    return
  end

  Render.redraw(game, Music.drone_params(game), genesis, display_page, ui)
  redraw_dirty = false
end
