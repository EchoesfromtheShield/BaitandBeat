engine.name = "AbyssalLine"

local Config = include("abyssal_line/lib/config")
local Game = include("abyssal_line/lib/game")
local GenesisSerial = include("abyssal_line/lib/genesis_serial")
local Music = include("abyssal_line/lib/music")
local Render = include("abyssal_line/lib/render")

local game = nil
local genesis = nil
local redraw_dirty = true
local display_page = 1
local observed_state = nil

local function norns_fallback_controls()
  return not (genesis and genesis:is_connected())
end

local function update_display_page_from_state()
  if not game or game.state == observed_state then
    return
  end

  if game.state == "STRUGGLE" then
    display_page = 2
  elseif observed_state == "STRUGGLE" or game.state == "CAST" then
    display_page = 1
  end

  observed_state = game.state
  redraw_dirty = true
end

local function loop()
  while true do
    clock.sleep(Config.TICK_S)
    if genesis and genesis:poll(game) then
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
    if delta > 0 then
      display_page = 2
    elseif delta < 0 then
      display_page = 1
    end
    redraw_dirty = true
    return
  end

  if n == 3 and game and norns_fallback_controls() then
    game:encoder(delta)
    redraw_dirty = true
  end
end

function key(n, z)
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

  Render.redraw(game, Music.drone_params(game), genesis, display_page)
  redraw_dirty = false
end
