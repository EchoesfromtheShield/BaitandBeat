local Render = {}

local SCREEN_W = 128
local SCREEN_H = 64
local HORIZON_Y = 16
local HOOK_X = 64

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

local function depth_to_y(depth)
  return HORIZON_Y + 4 + clamp(depth, 0, 1) * (SCREEN_H - HORIZON_Y - 8)
end

local function fish_to_x(value)
  return 10 + clamp(value, 0, 1) * 108
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

local function draw_sky()
  local stars = {
    { 8, 7, 5 },
    { 29, 2, 3 },
    { 47, 9, 4 },
    { 83, 5, 6 },
    { 103, 11, 4 },
    { 119, 8, 3 },
  }

  for _, star in ipairs(stars) do
    screen.level(star[3])
    screen.rect(star[1], star[2], 1, 1)
    screen.fill()
  end
end

local function draw_sea_line()
  screen.level(7)
  screen.move(0, HORIZON_Y)
  screen.line(SCREEN_W - 1, HORIZON_Y)
  screen.stroke()

  screen.level(4)
  for x = 0, SCREEN_W - 1, 6 do
    screen.rect(x, HORIZON_Y - 1, 1, 1)
    screen.rect(x + 3, HORIZON_Y + 1, 1, 1)
  end
  screen.fill()
end

local function draw_boat()
  local y = HORIZON_Y

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
end

local function draw_bottom_noise()
  screen.level(3)
  for x = 0, SCREEN_W - 1, 3 do
    local y = 61 + ((x * 7) % 3)
    screen.rect(x, y, 2, 1)
  end
  screen.fill()

  screen.level(6)
  screen.move(0, 63)
  for x = 0, SCREEN_W - 1, 2 do
    local y = 62 + ((x * 5) % 2)
    screen.line(x, y)
  end
  screen.stroke()
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
  local level = 4 + math.floor(clamp(signal or 0, 0, 1) * 11)

  if ready then
    screen.level(9)
    screen.circle(x, y, 9)
    screen.stroke()
    screen.level(4)
    screen.circle(x, y, 13)
    screen.stroke()
  elseif signal and signal > 0.25 then
    screen.level(3 + math.floor(signal * 4))
    screen.circle(x, y, 5 + signal * 6)
    screen.stroke()
  end

  draw_sprite(sprite, x, y, level)
end

local function draw_line_to_hook(game, hook_y)
  if game.state == "CAST" then
    return
  end

  screen.level(9)
  screen.move(HOOK_X, HORIZON_Y + 3)
  screen.line(HOOK_X, hook_y)
  screen.stroke()
end

local function draw_main_page(game)
  draw_sky()
  draw_sea_line()
  draw_boat()

  if game.state == "CAST" then
    return
  end

  draw_bottom_noise()

  local hook_y = clamp(depth_to_y(game.depth), HORIZON_Y + 5, SCREEN_H - 4)

  if game.state == "STRUGGLE" then
    local fish = game.hooked_fish or game.active_fish
    local fish_y = clamp(depth_to_y(game.fish_depth), HORIZON_Y + 5, SCREEN_H - 6)
    local fish_x = fish_to_x(game.fish_x)

    draw_line_to_hook(game, hook_y)
    screen.level(8)
    screen.move(HOOK_X, hook_y)
    screen.line(fish_x, fish_y)
    screen.stroke()
    draw_hook(HOOK_X, hook_y, false)
    draw_fish(fish, fish_x, fish_y, game.signal, false)
    return
  end

  draw_line_to_hook(game, hook_y)
  draw_hook(HOOK_X, hook_y, game.bite_ready)

  for _, fish in ipairs(game.fish or {}) do
    local signal = fish.signal or 0
    if signal > 0.06 then
      local fish_y = clamp(depth_to_y(fish.depth), HORIZON_Y + 6, SCREEN_H - 7)
      local fish_x = fish_to_x(fish.x)
      local ready = game.bite_ready and game.active_fish == fish
      draw_fish(fish, fish_x, fish_y, signal, ready)
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

  if page == 2 then
    draw_hud_page(game, drone, genesis)
  else
    draw_main_page(game)
  end

  screen.update()
end

return Render
