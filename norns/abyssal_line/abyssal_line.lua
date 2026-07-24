engine.name = "PolyPerc"

local Config = include("abyssal_line/lib/config")
local Game = include("abyssal_line/lib/game")
local Music = include("abyssal_line/lib/music")
local Render = include("abyssal_line/lib/render")

local game = nil
local redraw_dirty = true

local function loop()
  while true do
    clock.sleep(Config.TICK_S)
    local events = game:update(Config.TICK_S)
    Music.tick(game, events)
    redraw_dirty = true
    redraw()
  end
end

function init()
  game = Game.new(Config)
  clock.run(loop)
end

function enc(n, delta)
  if n == 3 and game then
    game:encoder(delta)
    redraw_dirty = true
  end
end

function key(n, z)
  if n == 3 and z == 1 and game then
    game:press()
    redraw_dirty = true
  end
end

function redraw()
  if not redraw_dirty or not game then
    return
  end

  Render.redraw(game, Music.drone_params(game))
  redraw_dirty = false
end

