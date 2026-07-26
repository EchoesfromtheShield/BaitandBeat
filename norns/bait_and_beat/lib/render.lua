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
    { 8, 7, 0 },
    { 31, 3, 7 },
    { 48, 10, 12 },
    { 83, 5, 19 },
    { 104, 12, 27 },
    { 119, 8, 35 },
  }

  if surface_y > 11 then
    local moon = {
      "...#.....",
      ".##......",
      ".#.......",
      "##.......",
      "###......",
      "###.....#",
      ".####..#.",
      ".#######.",
      "...###...",
    }
    local moon_scale = 2
    local moon_x = 16
    local moon_y = 2

    screen.level(9)
    for row_index, row in ipairs(moon) do
      for column = 1, #row do
        if row:sub(column, column) == "#" then
          screen.rect(
            moon_x + (column - 1) * moon_scale,
            moon_y + (row_index - 1) * moon_scale,
            moon_scale,
            moon_scale
          )
        end
      end
    end
    screen.fill()
  end

  for _, star in ipairs(stars) do
    if star[2] < surface_y - 1 then
      local phase = (frame + star[3]) % 42
      local level = phase < 10 and 15 or (phase < 22 and 7 or 2)
      screen.level(level)
      screen.rect(star[1], star[2], 1, 1)
      if level > 6 then
        screen.rect(star[1] - 1, star[2], 1, 1)
        screen.rect(star[1] + 1, star[2], 1, 1)
        screen.rect(star[1], star[2] - 1, 1, 1)
        screen.rect(star[1], star[2] + 1, 1, 1)
      end
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

  screen.level(11)
  screen.move(76, y - 1)
  screen.line(tip_x, tip_y)
  screen.stroke()

  return tip_y
end

local function draw_water_noise(view_top, view_span, surface_y)
  local start_y = 6
  if surface_y then
    start_y = math.max(start_y, math.floor(surface_y) + 4)
  end

  screen.level(2)
  for y = start_y, SCREEN_H - 3, 9 do
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

local function draw_status_message(game)
  if not game.message or game.message == "" or not game.message_timer or game.message_timer <= 0 then
    return
  end

  screen.level(15)
  local split_at = string.find(game.message, "|", 1, true)
  if split_at then
    screen.move(2, 55)
    screen.text(string.sub(game.message, 1, split_at - 1))
    screen.move(2, 63)
    screen.text(string.sub(game.message, split_at + 1))
  else
    screen.move(2, 63)
    screen.text(game.message)
  end
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

  draw_water_noise(view_top, view_span, surface_y)

  if surface_y > -12 and surface_y < SCREEN_H + 8 then
    draw_sky(surface_y, render_frame)
    draw_sea_line(surface_y)
    line_start_y = draw_boat(surface_y, line_x)
  end

  if game.state == "CAST" or game.state == "SURFACE" then
    draw_status_message(game)
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
    { type = "square", x = 80, max = 1 },
    { type = "circle", x = 96, max = 1 },
    { type = "triangle", x = 112, max = 1 },
  }

  for _, slot in ipairs(slots) do
    local layers = captured_by_type and captured_by_type[slot.type] or {}
    for index = 1, slot.max do
      small_icon(slot.type, slot.x + ((index - 1) * 10), y, layers[index] ~= nil)
    end
  end
end

local function marked_bar(x, y, w, h, value, mark_min, mark_max, fail_min, fail_max)
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

  if fail_min and fail_max then
    local fail_min_x = x + 1 + math.floor((w - 2) * clamp(fail_min, 0, 1))
    local fail_max_x = x + 1 + math.floor((w - 2) * clamp(fail_max, 0, 1))
    screen.level(7)
    screen.move(fail_min_x, y - 1)
    screen.line(fail_min_x, y + h)
    screen.move(fail_max_x, y - 1)
    screen.line(fail_max_x, y + h)
    screen.stroke()
  end
end

local function captured_layer_for_type(game, fish_type)
  local layers = game.captured_by_type and game.captured_by_type[fish_type] or {}
  return layers[1]
end

local function draw_empty_slot(x, y, selected)
  screen.level(selected and 8 or 2)
  screen.rect(x - 8, y - 8, 16, 16)
  screen.stroke()

  screen.level(selected and 5 or 1)
  screen.move(x - 4, y)
  screen.line(x + 4, y)
  screen.stroke()
end

local function draw_action_text(ui, y, has_layer)
  local actions = {
    { label = "free", x = 34, slash_x = 57 },
    { label = "mix", x = 65, slash_x = 84 },
    { label = "mod", x = 94 },
  }

  if not has_layer then
    return
  end

  for index, action in ipairs(actions) do
    local selected = (ui.action_index or 1) == index
    screen.level(selected and 15 or 5)
    screen.move(action.x, y)
    screen.text(action.label)

    if index < #actions then
      screen.level(3)
      screen.move(action.slash_x, y)
      screen.text("/")
    end
  end
end

local function draw_captured_list_page(game, ui)
  local rows = {
    { type = "square", y = 11 },
    { type = "circle", y = 32 },
    { type = "triangle", y = 53 },
  }
  local selected_index = ui.selected_index or 1

  for index, row in ipairs(rows) do
    local layer = captured_layer_for_type(game, row.type)
    local selected = selected_index == index
    local sprite = SPRITES[row.type]

    if layer then
      draw_sprite(sprite, 14, row.y, selected and 15 or 7)
    else
      draw_empty_slot(14, row.y, selected)
    end

    if selected then
      draw_action_text(ui, row.y + 3, layer ~= nil)
    end
  end
end

local function selected_layer(game, ui)
  local rows = { "square", "circle", "triangle" }
  return captured_layer_for_type(game, rows[ui.selected_index or 1])
end

local MOD_LABELS = {
  square = { x = "X events", y = "Y verb" },
  circle = { x = "X prob", y = "Y sus/cut" },
  triangle = { x = "X harmony", y = "Y sustain" },
}

local function draw_mix_page(game, ui)
  local layer = selected_layer(game, ui)
  local fish_type = layer and layer.type or "square"
  local volume = layer and layer.volume_0_1 or 0
  local sprite = SPRITES[fish_type] or SPRITES.square

  if layer then
    draw_sprite(sprite, 15, 18, 14)
  else
    draw_empty_slot(15, 18, true)
  end

  marked_bar(32, 29, 88, 8, volume)
end

local function draw_mod_page(game, ui)
  local layer = selected_layer(game, ui)
  local fish_type = layer and layer.type or "square"
  local mod_x = layer and layer.mod_x or 0.5
  local mod_y = layer and layer.mod_y or 0.5
  local sprite = SPRITES[fish_type] or SPRITES.square
  local labels = MOD_LABELS[fish_type] or MOD_LABELS.square
  local w = 84
  local h = 38
  local x0 = math.floor((SCREEN_W - w) * 0.5)
  local y0 = 16
  local x = x0 + 9 + clamp(mod_x, 0, 1) * (w - 18)
  local y = y0 + 9 + (1 - clamp(mod_y, 0, 1)) * (h - 18)

  screen.level(8)
  screen.move(2, 8)
  screen.text(labels.y)
  screen.move(70, 8)
  screen.text(labels.x)

  screen.level(4)
  screen.rect(x0, y0, w, h)
  screen.stroke()

  screen.level(3)
  screen.move(x0, y0 + h * 0.5)
  screen.line(x0 + w, y0 + h * 0.5)
  screen.move(x0 + w * 0.5, y0)
  screen.line(x0 + w * 0.5, y0 + h)
  screen.stroke()

  draw_sprite(sprite, x, y, layer and 15 or 5)
end

local function draw_struggle_page(game)
  local fish = game.hooked_fish or game.active_fish
  local zoom_x = clamp(64 + ((game.fish_x or 0.5) - 0.5) * 76, 20, 108)
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

  draw_sprite_scaled(sprite, zoom_x, zoom_y, 14, 1)

  marked_bar(
    6,
    49,
    116,
    6,
    game.tension or 0,
    game.config.SAFE_TENSION_MIN,
    game.config.SAFE_TENSION_MAX,
    game.config.SLACK_TENSION,
    game.config.OVERLOAD_TENSION
  )
  marked_bar(6, 58, 116, 5, game.capture_progress or 0)
end

local function draw_loop_ui_page(game, ui)
  ui = ui or {}

  if ui.mode == "mix" then
    draw_mix_page(game, ui)
  elseif ui.mode == "mod" then
    draw_mod_page(game, ui)
  else
    draw_captured_list_page(game, ui)
  end
end

local function draw_settings_row(label, value, y, selected)
  screen.level(selected and 15 or 5)
  screen.move(7, y)
  screen.text(label)
  screen.move(46, y)
  screen.text(value)

  if selected then
    screen.level(10)
    screen.move(0, y)
    screen.text(">")
  end
end

local function draw_settings_page(game, ui)
  local config = game.config or {}
  local note = config.NOTES and config.NOTES[config.ROOT_NOTE_INDEX or 1] or nil
  local scale = config.SCALES and config.SCALES[config.SCALE_INDEX or 1] or nil
  local selected = ui and ui.settings_index or 1

  screen.level(15)
  screen.move(2, 8)
  screen.text("MUSIC")

  draw_settings_row("BPM", tostring(config.BPM or 90), 22, selected == 1)
  draw_settings_row("ROOT", note and note.name or "D", 36, selected == 2)

  screen.level(selected == 3 and 15 or 5)
  screen.move(7, 50)
  screen.text("SCALE")
  if selected == 3 then
    screen.level(10)
    screen.move(0, 50)
    screen.text(">")
  end
  screen.level(selected == 3 and 15 or 7)
  screen.move(7, 61)
  screen.text(scale and scale.name or "Pentatonic Minor")
end

function Render.redraw(game, drone, genesis, page, ui)
  if screen == nil then
    return
  end

  screen.clear()

  render_frame = render_frame + 1

  if page == 2 and game.state == "STRUGGLE" then
    draw_struggle_page(game)
  elseif page == 2 then
    draw_loop_ui_page(game, ui)
  elseif page == 3 then
    draw_settings_page(game, ui)
  else
    draw_main_page(game)
  end

  screen.update()
end

return Render
