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
  for y = top, bottom, 3 do
    local world_depth = clamp(view_top + ((y - top) / (bottom - top)) * view_span, 0, 1)
    local spacing = math.max(7, 22 - math.floor(world_depth * 9))
    local level = 1 + math.floor(world_depth * 3)
    local phase = (y + math.floor(world_depth * 127)) % spacing

    screen.level(level)
    for x = 1 - phase, 127, spacing do
      if x >= 1 then
        screen.rect(x, y, 1, 1)
      end
      if world_depth > 0.62 and x + 5 >= 1 and x + 5 < 128 and (x + y) % 5 == 0 then
        screen.rect(x + 5, y + 1, 1, 1)
      end
      if world_depth > 0.82 and x + 2 >= 1 and x + 2 < 128 and (x + y) % 7 == 0 then
        screen.rect(x + 2, y + 2, 1, 1)
      end
    end
    screen.fill()
  end
end

local function draw_surface(view_top, view_span, top, bottom)
  if view_top > 0 then
    return
  end

  local y = clamp(world_to_y(0, view_top, view_span, top, bottom), top, bottom)
  screen.level(10)
  screen.move(0, y)
  screen.line(127, y)
  screen.stroke()
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

local function draw_fish_signal(x, y, level, signal, ready)
  local radius = 2 + clamp(signal, 0, 1) * 8

  screen.level(math.max(2, level - 3))
  screen.circle(x, y, radius)
  screen.stroke()

  if signal > 0.34 then
    screen.level(math.max(1, level - 6))
    screen.circle(x, y, radius + 4)
    screen.stroke()
  end

  screen.level(level)
  screen.rect(x - 1, y - 1, 3, 3)
  screen.fill()

  if ready then
    screen.level(15)
    screen.rect(x - 2, y - 2, 5, 5)
    screen.stroke()
  end
end

local function draw_fish_shape(shape, x, y, level, signal, ready)
  local radius = 2 + clamp(signal, 0, 1) * 7

  screen.level(math.max(1, level - 4))
  screen.circle(x, y, radius)
  screen.stroke()

  if ready then
    screen.level(15)
    screen.circle(x, y, radius + 3)
    screen.stroke()
  end

  screen.level(level)
  if shape == "square" then
    screen.rect(x - 2, y - 2, 5, 5)
    screen.fill()
  elseif shape == "circle" then
    screen.circle(x, y, 3)
    screen.fill()
  elseif shape == "triangle" then
    screen.move(x, y - 4)
    screen.line(x + 4, y + 3)
    screen.line(x - 4, y + 3)
    screen.line(x, y - 4)
    screen.fill()
  else
    draw_fish_signal(x, y, level, signal, ready)
  end
end

local function draw_ascent_trace(hook_x, fish_y, top)
  screen.level(3)
  for y = top, fish_y, 7 do
    screen.move(hook_x - 2, y)
    screen.line(hook_x + 2, y)
    screen.stroke()
  end
end

local function draw_loop_slots(captured_by_type)
  local slots = {
    { type = "square", x = 9 },
    { type = "circle", x = 20 },
    { type = "triangle", x = 31 },
  }

  for _, slot in ipairs(slots) do
    local active = captured_by_type and captured_by_type[slot.type]
    draw_fish_shape(slot.type, slot.x, 45, active and 12 or 3, active and 0.9 or 0.0, false)
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
  local bottom = 50
  local view_span = game.config.CAMERA_DEPTH_SPAN or 0.16
  local view_top = clamp(game.depth - view_span * 0.55, 0, 1 - view_span)
  local hook_x = 64
  local hook_y = clamp(world_to_y(game.depth, view_top, view_span, top, bottom), top, bottom)
  local page = math.floor(game.depth / view_span) + 1
  local depth_m = math.floor(game.depth * (game.config.MAX_DEPTH_M or 420))

  draw_dither(view_top, view_span, top, bottom)
  draw_surface(view_top, view_span, top, bottom)

  screen.level(15)
  screen.move(2, 8)
  screen.text(game.state)

  screen.level(7)
  screen.move(76, 8)
  screen.text(string.format("%03dm p%d", depth_m, page))

  if game.state == "STRUGGLE" then
    local fish = game.hooked_fish or game.active_fish
    local fish_y = clamp(world_to_y(game.fish_depth, view_top, view_span, top, bottom), top, bottom)
    local fish_x = fish_to_x(game.fish_x)
    draw_ascent_trace(hook_x, fish_y, top)
    screen.level(11)
    screen.move(hook_x, top)
    screen.line(hook_x, hook_y)
    screen.line(fish_x, fish_y)
    screen.stroke()
    draw_hook(hook_x, hook_y, false)
    draw_fish_shape(
      fish and fish.type or "square",
      fish_x,
      fish_y,
      7 + math.floor(game.signal * 8),
      game.signal,
      false
    )
  else
    screen.level(12)
    screen.move(hook_x, top)
    screen.line(hook_x, hook_y)
    screen.stroke()
    draw_hook(hook_x, hook_y, game.bite_ready)

    for _, fish in ipairs(game.fish or {}) do
      local fish_y = world_to_y(fish.depth, view_top, view_span, top, bottom)
      if fish_y >= top - 8 and fish_y <= bottom + 8 then
        local fish_x = fish_to_x(fish.x)
        local signal = fish.signal or 0
        local level = 3 + math.floor(signal * 12)
        local ready = game.bite_ready and game.active_fish == fish
        draw_fish_shape(fish.type, fish_x, fish_y, level, signal, ready)
      end
    end
  end

  if game.state == "STRUGGLE" then
    screen.level(5)
    screen.move(5, 53)
    screen.text("TEN")
    screen.move(74, 53)
    screen.text("UP")
    marked_bar(
      5,
      56,
      56,
      7,
      game.tension,
      game.config.SAFE_TENSION_MIN,
      game.config.SAFE_TENSION_MAX
    )
    marked_bar(74, 56, 49, 7, game.capture_progress)
  end

  screen.level(6)
  screen.move(2, 19)
  screen.text(string.format("S %.2f", game.signal))
  draw_loop_slots(game.captured_by_type)

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
