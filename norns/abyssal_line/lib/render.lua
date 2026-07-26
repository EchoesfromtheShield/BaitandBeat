local Render = {}

local SCREEN_W = 128
local SCREEN_H = 64
local HORIZON_Y = 16
local render_frame = 0

local SPRITES = {
  square = {
    ".###.........###.",
    "###...........###",
    "##.............##",
    "##.#.###.###.#.##",
    "####.###.###.####",
    "#.....##.##.....#",
    "#....#######....#",
    "#..###.###.###..#",
    "#####.#####.#####",
    "#####.#####.#####",
    "..#############..",
    "...###########...",
    "....#########....",
    ".###.#######.###.",
    "#...#.......#...#",
    "#..#.........#..#",
    "#..#.........#..#",
  },
  circle = {
    "......###########",
    ".....#######.....",
    "....#########....",
    "...######.#.##...",
    "...####.##.#.#...",
    "...######.#.##...",
    "#..#.##.####.#..#",
    "#..#.##.##.#.#.##",
    "#######......####",
    "#######......####",
    "...####......#.##",
    "...###.......#..#",
    "...#.........#...",
    "...#........#....",
    "....########.....",
    ".....#####.......",
    "......#########..",
  },
  triangle = {
    "......#####......",
    ".....#######.....",
    ".....#######.....",
    ".....#######.....",
    ".....#.###.#.....",
    "...#.#######.#...",
    "..#..###.###..#..",
    "..#..#######..#..",
    "..#..#######..#..",
    "...#.#.....#.#...",
    "#..#.#...##..#..#",
    ".##...##.##...##.",
    "......##...##....",
    "..#...#......#...",
    "...###.......#...",
    "............#....",
  },
}

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function fish_to_x(value)
  return 10 + clamp(value, 0, 1) * 108
end

local function hook_x(game)
  return fish_to_x(game.hook_x or game.config.HOOK_X_0_1 or 0.5)
end

local function camera_view(game)
  local span = clamp(game.config.CAMERA_DEPTH_SPAN or 0.30, 0.12, 0.95)
  if game.state == "CAST" or game.state == "SURFACE" then
    return 0, span
  end

  local target = (game.depth or 0) - span * 0.42
  return clamp(target, 0, 1 - span), span
end

local function view_top_y(view_top)
  local scroll = clamp(view_top / 0.10, 0, 1)
  return HORIZON_Y - scroll * (HORIZON_Y - 2)
end

local function world_to_y(depth, view_top, view_span)
  local top = view_top_y(view_top)
  local bottom = SCREEN_H - 3
  local t = (depth - view_top) / view_span
  return top + (bottom - top) * t
end

local function sprite_width(sprite)
  local w = 0
  for _, row in ipairs(sprite) do
    w = math.max(w, #row)
  end
  return w
end

local function draw_sprite(sprite, cx, cy, level)
  local w = sprite_width(sprite)
  local h = #sprite
  local x0 = math.floor(cx - w * 0.5)
  local y0 = math.floor(cy - h * 0.5)

  screen.level(level)
  for row_index, row in ipairs(sprite) do
    for column = 1, #row do
      if row:sub(column, column) == "#" then
        screen.rect(x0 + column - 1, y0 + row_index - 1, 1, 1)
      end
    end
  end
  screen.fill()
end

local function draw_sprite_scaled(sprite, cx, cy, level, scale)
  local w = sprite_width(sprite) * scale
  local h = #sprite * scale
  local x0 = math.floor(cx - w * 0.5)
  local y0 = math.floor(cy - h * 0.5)

  screen.level(level)
  for row_index, row in ipairs(sprite) do
    for column = 1, #row do
      if row:sub(column, column) == "#" then
        screen.rect(
          x0 + (column - 1) * scale,
          y0 + (row_index - 1) * scale,
          scale,
          scale
        )
      end
    end
  end
  screen.fill()
end

local function draw_sky(surface_y, frame)
  local stars = {
    { 8, 7, 5, 0 },
    { 29, 2, 3, 7 },
    { 47, 9, 4, 12 },
    { 83, 5, 6, 19 },
    { 103, 11, 4, 27 },
    { 119, 8, 3, 35 },
  }

  for _, star in ipairs(stars) do
    if star[2] < surface_y - 1 then
      local phase = (frame + star[4]) % 48
      local blink = phase < 6 and 5 or 0
      screen.level(clamp(star[3] + blink, 2, 12))
      screen.rect(star[1], star[2], 1, 1)
      screen.fill()
    end
  end
end

local function draw_sea_line(y)
  y = math.floor(y)

  screen.level(7)
  screen.move(0, y)
  screen.line(SCREEN_W - 1, y)
  screen.stroke()

  screen.level(4)
  for x = 0, SCREEN_W - 1, 6 do
    screen.rect(x, y - 1, 1, 1)
    screen.rect(x + 3, y - 2, 1, 1)
  end
  screen.fill()
end

local function draw_boat(surface_y, line_x)
  local y = math.floor(surface_y)
  local tip_x = math.floor(line_x)
  local tip_y = y - 7

  screen.level(12)
  screen.rect(59, y - 6, 10, 2)
  screen.rect(57, y - 4, 14, 2)
  screen.fill()

  screen.level(15)
  screen.move(51, y - 1)
  screen.line(77, y - 1)
  screen.line(72, y + 3)
  screen.line(56, y + 3)
  screen.line(51, y - 1)
  screen.stroke()

  screen.level(8)
  screen.rect(62, y + 2, 2, 5)
  screen.rect(68, y + 2, 2, 5)
  screen.fill()

  screen.level(11)
  screen.move(76, y - 1)
  screen.line(tip_x, tip_y)
  screen.stroke()

  return tip_y
end

local function draw_water_noise(view_top, view_span)
  screen.level(2)
  for y = 6, SCREEN_H - 3, 9 do
    local world_depth = clamp(view_top + (y / SCREEN_H) * view_span, 0, 1)
    local spacing = 21 - math.floor(world_depth * 5)
    local phase = math.floor(world_depth * 97 + y * 3) % spacing
    for x = 2 + phase, SCREEN_W - 1, spacing do
      screen.rect(x, y, 1, 1)
    end
  end
  screen.fill()
end

local function draw_bottom_noise(bottom_y)
  bottom_y = math.floor(bottom_y)

  screen.level(3)
  for x = 0, SCREEN_W - 1, 3 do
    local y = bottom_y + ((x * 7) % 3)
    if y >= 0 and y < SCREEN_H then
      screen.rect(x, y, 2, 1)
    end
  end
  screen.fill()

  screen.level(6)
  if bottom_y >= 0 and bottom_y < SCREEN_H then
    screen.move(0, bottom_y)
    for x = 0, SCREEN_W - 1, 2 do
      local y = bottom_y + ((x * 5) % 2)
      screen.line(x, clamp(y, 0, SCREEN_H - 1))
    end
    screen.stroke()
  end
end

local function draw_hook(x, y, ready)
  screen.level(ready and 15 or 10)
  screen.move(x, y - 4)
  screen.line(x, y + 2)
  screen.line(x + 3, y + 4)
  screen.stroke()
  screen.circle(x, y, ready and 2 or 1)
  screen.fill()
end

local function draw_fish(fish, x, y, signal, ready)
  local sprite = SPRITES[fish and fish.type or "square"] or SPRITES.square
  local level = ready and 15 or (3 + math.floor(clamp(signal or 0, 0, 1) * 10))

  draw_sprite(sprite, x, y, level)
end

local function draw_line_to_hook(game, line_x, start_y, hook_y)
  if game.state == "CAST" or game.state == "SURFACE" then
    return
  end

  screen.level(9)
  screen.move(line_x, clamp(start_y, 0, SCREEN_H - 1))
  screen.line(line_x, hook_y)
  screen.stroke()
end

local function draw_main_page(game)
  local line_x = hook_x(game)
  local view_top, view_span = camera_view(game)
  local surface_y = world_to_y(0, view_top, view_span)
  local line_start_y = 0

  if game.state ~= "CAST" and game.state ~= "SURFACE" then
    draw_water_noise(view_top, view_span)
  end

  if surface_y > -12 and surface_y < SCREEN_H + 8 then
    draw_sky(surface_y, render_frame)
    draw_sea_line(surface_y)
    line_start_y = draw_boat(surface_y, line_x)
  end

  if game.state == "CAST" or game.state == "SURFACE" then
    return
  end

  local bottom_y = world_to_y(1, view_top, view_span)
  if bottom_y >= 48 and bottom_y < SCREEN_H + 8 then
    draw_bottom_noise(bottom_y)
  end

  local hook_y = clamp(world_to_y(game.depth, view_top, view_span), 1, SCREEN_H - 4)

  if game.state == "STRUGGLE" then
    local fish = game.hooked_fish or game.active_fish
    local fish_y = clamp(world_to_y(game.fish_depth, view_top, view_span), 1, SCREEN_H - 6)
    local fish_x = fish_to_x(game.fish_x)

    draw_line_to_hook(game, line_x, line_start_y, hook_y)
    screen.level(8)
    screen.move(line_x, hook_y)
    screen.line(fish_x, fish_y)
    screen.stroke()
    draw_hook(line_x, hook_y, false)
    draw_fish(fish, fish_x, fish_y, game.signal, false)
    return
  end

  draw_line_to_hook(game, line_x, line_start_y, hook_y)
  draw_hook(line_x, hook_y, false)

  for _, fish in ipairs(game.fish or {}) do
    local signal = fish.signal or 0
    local ready = game.bite_ready and game.active_fish == fish
    if signal > 0.06 or ready then
      local fish_y = world_to_y(fish.depth, view_top, view_span)
      local fish_x = fish_to_x(fish.x)
      if fish_y >= -12 and fish_y <= SCREEN_H + 12 then
        draw_fish(fish, fish_x, clamp(fish_y, 1, SCREEN_H - 4), signal, ready)
      end
    end
  end
end

local function small_icon(shape, x, y, active)
  screen.level(active and 13 or 3)

  if shape == "square" then
    screen.rect(x - 2, y - 2, 5, 5)
    screen.stroke()
  elseif shape == "circle" then
    screen.circle(x, y, 3)
    screen.stroke()
  elseif shape == "triangle" then
    screen.move(x, y - 3)
    screen.line(x + 3, y + 3)
    screen.line(x - 3, y + 3)
    screen.line(x, y - 3)
    screen.stroke()
  end
end

local function draw_loop_slots(captured_by_type, y)
  local slots = {
    { type = "square", x = 75, max = 1 },
    { type = "circle", x = 90, max = 2 },
    { type = "triangle", x = 113, max = 2 },
  }

  for _, slot in ipairs(slots) do
    local layers = captured_by_type and captured_by_type[slot.type] or {}
    for index = 1, slot.max do
      small_icon(slot.type, slot.x + ((index - 1) * 10), y, layers[index] ~= nil)
    end
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

local function draw_struggle_page(game)
  local fish = game.hooked_fish or game.active_fish
  local zoom_x = clamp(64 + ((game.fish_x or 0.5) - 0.5) * 96, 27, 101)
  local depth_delta = clamp((game.fish_depth or game.depth or 0) - (game.depth or 0), -0.18, 0.18)
  local zoom_y = clamp(27 + depth_delta * 86, 20, 30)
  local hook_x_pos = 64
  local hook_y_pos = 22
  local anchor_x = 64
  local anchor_y = 3
  local motion = clamp((fish and fish.motion_x or 0) + (fish and fish.motion_y or 0), 0, 1)
  local line_level = 8 + math.floor(clamp(game.tension or 0, 0, 1) * 6)
  local sprite = SPRITES[fish and fish.type or "square"] or SPRITES.square

  screen.level(1)
  for y = 4, 45, 7 do
    for x = 1 + ((y * 5 + render_frame) % 17), SCREEN_W - 1, 19 do
      screen.rect(x, y, 1, 1)
    end
  end
  screen.fill()

  screen.level(line_level)
  screen.move(anchor_x, anchor_y)
  screen.line(hook_x_pos, hook_y_pos)
  screen.line(zoom_x, zoom_y)
  screen.stroke()

  screen.level(11)
  screen.move(hook_x_pos, hook_y_pos - 5)
  screen.line(hook_x_pos, hook_y_pos + 2)
  screen.line(hook_x_pos + 4, hook_y_pos + 4)
  screen.stroke()

  if motion > 0.35 then
    screen.level(3 + math.floor(motion * 4))
    screen.move(zoom_x - 18, zoom_y - 9)
    screen.line(zoom_x - 23, zoom_y - 6)
    screen.move(zoom_x + 18, zoom_y + 8)
    screen.line(zoom_x + 23, zoom_y + 5)
    screen.stroke()
  end

  draw_sprite_scaled(sprite, zoom_x, zoom_y, 14, 2)

  marked_bar(
    6,
    49,
    116,
    6,
    game.tension or 0,
    game.config.SAFE_TENSION_MIN,
    game.config.SAFE_TENSION_MAX
  )
  marked_bar(6, 58, 116, 5, game.capture_progress or 0)
end

local function draw_hud_page(game, drone, genesis)
  local depth_m = math.floor((game.depth or 0) * (game.config.MAX_DEPTH_M or 420))
  local genesis_label = "fallback"

  if genesis and genesis:is_connected() then
    genesis_label = "genesis"
  elseif genesis and genesis:is_open() then
    genesis_label = "serial"
  end

  screen.level(15)
  screen.move(2, 8)
  screen.text(game.state)

  draw_loop_slots(game.captured_by_type, 8)

  screen.level(9)
  screen.move(2, 19)
  screen.text(string.format("depth %03dm", depth_m))
  marked_bar(58, 13, 66, 7, game.depth or 0)

  screen.level(9)
  screen.move(2, 31)
  screen.text("signal")
  marked_bar(58, 25, 66, 7, game.signal or 0)

  screen.level(9)
  screen.move(2, 43)
  screen.text("tension")
  marked_bar(
    58,
    37,
    66,
    7,
    game.tension or 0,
    game.config.SAFE_TENSION_MIN,
    game.config.SAFE_TENSION_MAX
  )

  screen.level(9)
  screen.move(2, 55)
  screen.text("catch")

  screen.level(5)
  screen.move(2, 63)
  screen.text(genesis_label)
  marked_bar(58, 55, 66, 7, game.capture_progress or 0)
end

function Render.redraw(game, drone, genesis, page)
  if screen == nil then
    return
  end

  screen.clear()

  render_frame = render_frame + 1

  if page == 2 and game.state == "STRUGGLE" then
    draw_struggle_page(game)
  elseif page == 2 then
    draw_hud_page(game, drone, genesis)
  else
    draw_main_page(game)
  end

  screen.update()
end

return Render
