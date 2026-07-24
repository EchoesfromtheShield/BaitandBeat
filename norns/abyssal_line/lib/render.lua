local Render = {}

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function bar(x, y, w, h, value)
  screen.rect(x, y, w, h)
  screen.stroke()
  screen.rect(x + 1, y + 1, math.floor((w - 2) * clamp(value, 0, 1)), h - 2)
  screen.fill()
end

function Render.redraw(game, drone, genesis)
  if screen == nil then
    return
  end

  screen.clear()
  screen.level(15)
  screen.move(2, 8)
  screen.text(game.state)

  local top = 12
  local bottom = 62
  local x = 64
  local y = top + (bottom - top) * game.depth

  screen.level(4)
  for i = 0, 4 do
    local yy = top + i * 10
    screen.move(6, yy)
    screen.line(122, yy)
    screen.stroke()
  end

  screen.level(12)
  screen.move(x, top)
  screen.line(x, y)
  screen.stroke()
  screen.circle(x, y, 2)
  screen.fill()

  if game.state == "RESONANCE" or game.state == "STRUGGLE" then
    local cy = top + (bottom - top) * game.creature_depth
    screen.level(3 + math.floor(game.signal * 12))
    screen.circle(x + 18, cy, 4 + game.signal * 5)
    screen.stroke()
  end

  if game.state == "STRUGGLE" then
    screen.level(15)
    bar(6, 54, 34, 6, game.tension)
    bar(88, 54, 34, 6, game.capture_progress)
  end

  screen.level(8)
  screen.move(2, 20)
  screen.text(string.format("D %.2f", game.depth))
  screen.move(2, 30)
  screen.text(string.format("S %.2f", game.signal))
  screen.move(2, 40)
  screen.text(string.format("L %d", #game.captured_layers))

  screen.level(6)
  screen.move(78, 8)
  screen.text(string.format("%dhz", math.floor(drone.root_hz)))

  local genesis_label = "G --"
  if genesis and genesis.connected then
    genesis_label = "G ok"
  elseif genesis and genesis:is_open() then
    genesis_label = "G io"
  end

  screen.level(genesis and genesis:is_open() and 10 or 3)
  screen.move(104, 8)
  screen.text(genesis_label)

  screen.update()
end

return Render
