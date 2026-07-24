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

local function world_to_y(depth, view_top, view_span, top, bottom)
  local t = (depth - view_top) / view_span
  return top + (bottom - top) * t
end

local function fish_to_x(value)
  return 8 + clamp(value, 0, 1) * 112
end

local function draw_dither(view_top, view_span, top, bottom)
  for y = top, bottom, 2 do
    local world_depth = clamp(view_top + ((y - top) / (bottom - top)) * view_span, 0, 1)
    local spacing = math.max(4, 14 - math.floor(world_depth * 10))
    local level = 1 + math.floor(world_depth * 5)
    local phase = (y + math.floor(world_depth * 127)) % spacing

    screen.level(level)
    for x = 1 - phase, 127, spacing do
      if x >= 1 then
        screen.rect(x, y, 1, 1)
      end
      if world_depth > 0.45 and x + 3 >= 1 and x + 3 < 128 and (x + y) % 3 == 0 then
        screen.rect(x + 3, y + 1, 1, 1)
      end
      if world_depth > 0.72 and x + 1 >= 1 and x + 1 < 128 then
        screen.rect(x + 1, y + 1, 1, 1)
      end
    end
    screen.fill()
  end
end

local function draw_hook(x, y, ready)
  screen.level(ready and 15 or 12)
  screen.move(x, y - 5)
  screen.line(x, y + 2)
  screen.line(x + 4, y + 4)
  screen.stroke()
  screen.circle(x, y, ready and 2 or 1)
  screen.fill()
end

local function draw_fish_glyph(x, y, level, ready)
  screen.level(level)
  screen.move(x - 7, y)
  screen.line(x - 2, y - 3)
  screen.line(x + 6, y)
  screen.line(x - 2, y + 3)
  screen.line(x - 7, y)
  screen.stroke()

  screen.move(x - 7, y)
  screen.line(x - 11, y - 3)
  screen.move(x - 7, y)
  screen.line(x - 11, y + 3)
  screen.stroke()

  if ready then
    screen.level(15)
    screen.circle(x, y, 6)
    screen.stroke()
  end
end

local function marked_bar(x, y, w, h, value, mark_min, mark_max)
  local fill_w = math.floor((w - 2) * clamp(value, 0, 1))

  screen.level(4)
  screen.rect(x, y, w, h)
  screen.stroke()

  screen.level(9)
  screen.rect(x + 1, y + 1, fill_w, h - 2)
  screen.fill()

  if mark_min and mark_max then
    local min_x = x + 1 + math.floor((w - 2) * clamp(mark_min, 0, 1))
    local max_x = x + 1 + math.floor((w - 2) * clamp(mark_max, 0, 1))
    screen.level(15)
    screen.move(min_x, y - 2)
    screen.line(min_x, y + h + 1)
    screen.move(max_x, y - 2)
    screen.line(max_x, y + h + 1)
    screen.stroke()
  end
end

function Render.redraw(game, drone, genesis)
  if screen == nil then
    return
  end

  screen.clear()

  local top = 12
  local bottom = 51
  local view_span = game.config.CAMERA_DEPTH_SPAN or 0.22
  local view_top = clamp(game.depth - view_span * 0.55, 0, 1 - view_span)
  local hook_x = 64
  local hook_y = clamp(world_to_y(game.depth, view_top, view_span, top, bottom), top, bottom)
  local page = math.floor(game.depth / view_span) + 1
  local depth_m = math.floor(game.depth * 100)

  draw_dither(view_top, view_span, top, bottom)

  screen.level(15)
  screen.move(2, 8)
  screen.text(game.state)

  screen.level(7)
  screen.move(78, 8)
  screen.text(string.format("%03dm p%d", depth_m, page))

  if game.state == "STRUGGLE" then
    local fish_y = clamp(world_to_y(game.fish_depth, view_top, view_span, top, bottom), top, bottom)
    local fish_x = fish_to_x(game.fish_x)
    screen.level(11)
    screen.move(hook_x, top)
    screen.line(hook_x, hook_y)
    screen.line(fish_x, fish_y)
    screen.stroke()
    draw_hook(hook_x, hook_y, false)
    draw_fish_glyph(fish_x, fish_y, 7 + math.floor(game.signal * 8), false)
  else
    screen.level(12)
    screen.move(hook_x, top)
    screen.line(hook_x, hook_y)
    screen.stroke()
    draw_hook(hook_x, hook_y, game.bite_ready)

    if game.state == "RESONANCE" then
      local fish_y = world_to_y(game.creature_depth, view_top, view_span, top, bottom)
      if fish_y >= top - 6 and fish_y <= bottom + 6 then
        local fish_x = fish_to_x(game.fish_x)
        local level = 3 + math.floor(game.signal * 12)
        draw_fish_glyph(fish_x, fish_y, level, game.bite_ready)
      end
    end
  end

  if game.state == "STRUGGLE" then
    marked_bar(
      5,
      55,
      56,
      7,
      game.tension,
      game.config.SAFE_TENSION_MIN,
      game.config.SAFE_TENSION_MAX
    )
    marked_bar(74, 55, 49, 7, game.capture_progress)
  end

  screen.level(6)
  screen.move(2, 19)
  screen.text(string.format("S %.2f", game.signal))
  screen.move(2, 29)
  screen.text(string.format("L %d", #game.captured_layers))

  local genesis_label = "G --"
  if genesis and genesis.connected then
    genesis_label = "G ok"
  elseif genesis and genesis:is_open() then
    genesis_label = "G io"
  end

  screen.level(genesis and genesis:is_open() and 10 or 3)
  screen.move(104, 19)
  screen.text(genesis_label)

  screen.update()
end

return Render
