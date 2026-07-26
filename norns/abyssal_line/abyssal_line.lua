engine.name = "AbyssalLine"

local Config = include("abyssal_line/lib/config")
local Game = include("abyssal_line/lib/game")
local GenesisSerial = include("abyssal_line/lib/genesis_serial")
local Music = include("abyssal_line/lib/music")
local Render = include("abyssal_line/lib/render")

local game = nil
local genesis = nil
local redraw_dirty = true

local function norns_fallback_controls()
  return not (genesis and genesis:is_connected())
end

local function loop()
  while true do
    clock.sleep(Config.TICK_S)
    if genesis and genesis:poll(game) then
      redraw_dirty = true
    end

    local events = game:update(Config.TICK_S)
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
  Music.init(game)
  genesis = GenesisSerial.new(Config)
  genesis:open()
  clock.run(loop)
end

function cleanup()
  Music.cleanup()
end

function enc(n, delta)
  if n == 3 and game and norns_fallback_controls() then
    game:encoder(delta)
    redraw_dirty = true
  end
end

function key(n, z)
  if n == 3 and z == 1 and game and norns_fallback_controls() then
    game:press()
    redraw_dirty = true
  end
end

function redraw()
  if not redraw_dirty or not game then
    return
  end

  Render.redraw(game, Music.drone_params(game), genesis)
  redraw_dirty = false
end
