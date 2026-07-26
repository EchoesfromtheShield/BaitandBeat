local Music = {}

local DEFAULT_SCALE = { 0, 3, 5, 7, 10, 12, 15, 17, 19, 22 }

local current_game = nil
local clock_id = nil
local step16 = 0
local drone_send_t = 0
local preview_latch = {}
local loop_state = {}
local TIMBRE_FAMILIES = 8
local MOTION_MOD_SCALE = {
  square = { x = 0.16, y = 0.10 },
  circle = { x = 0.12, y = 0.08 },
  triangle = { x = 0.08, y = 0.05 },
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

local function frac(value)
  return value - math.floor(value)
end

local function seeded(seed, salt)
  return frac(math.sin((seed or 1) * 12.9898 + salt * 78.233) * 43758.5453)
end

local function choice(seed, salt, options)
  local index = 1 + math.floor(seeded(seed, salt) * #options)
  return options[clamp(index, 1, #options)]
end

local function has_engine_command(name)
  return engine ~= nil and engine[name] ~= nil
end

local function base_root_hz(game)
  return game.config.ROOT_HZ or game.config.BASE_DRONE_HZ or 73.416
end

local function scale_hz(game, degree, octave)
  local scale = game.config.SCALE or DEFAULT_SCALE
  local size = #scale
  local d = degree - 1
  local scale_index = (d % size) + 1
  local scale_octave = math.floor(d / size) + (octave or 0)
  local semitone = scale[scale_index] + scale_octave * 12

  return base_root_hz(game) * (2 ^ (semitone / 12))
end

local function safe_tension_weight(game)
  local tension = game.tension or 0
  local min = game.config.SAFE_TENSION_MIN
  local max = game.config.SAFE_TENSION_MAX
  local center = (min + max) * 0.5
  local span = (max - min) * 0.5

  if span <= 0 then
    return 0
  end

  return clamp(1 - (math.abs(tension - center) / span), 0, 1)
end

local function pan_from_fish(fish)
  return clamp(((fish and fish.x or 0.5) - 0.5) * 1.5, -1, 1)
end

local function timbre(fish, salt)
  local seed = fish and fish.timbre_seed or 1
  local family = math.floor(seeded(seed, 1) * TIMBRE_FAMILIES)
  local color = seeded(seed, salt) * 0.92
  return clamp((family + color) / TIMBRE_FAMILIES, 0, 0.999)
end

local function movement_from_fish(fish)
  local scale = MOTION_MOD_SCALE[fish and fish.type] or { x = 0.10, y = 0.08 }
  return clamp(fish and fish.motion_x or 0, 0, 1) * scale.x,
    clamp(fish and fish.motion_y or 0, 0, 1) * scale.y
end

local function fish_event(mode, note, timbre_value, amp, pan, motion_x, motion_y)
  if has_engine_command("fish_event") then
    engine.fish_event(
      mode,
      note,
      timbre_value,
      amp,
      pan,
      clamp(motion_x or 0, 0, 1),
      clamp(motion_y or 0, 0, 1)
    )
  end
end

local function fish_step_seed(fish, salt)
  return seeded((fish and fish.pattern_seed or 1) + step16 * 17, salt)
end

local function beat_seconds(beats)
  local bpm = current_game and current_game.config and current_game.config.BPM or 90
  return (60 / bpm) * beats
end

local function delayed_fish_event(delay_beats, mode, note, timbre_value, amp, pan, motion_x, motion_y)
  if clock and clock.run and clock.sleep then
    clock.run(function()
      clock.sleep(beat_seconds(delay_beats))
      fish_event(mode, note, timbre_value, amp, pan, motion_x, motion_y)
    end)
  end
end

local function set_clock_bpm(bpm)
  if params and params.set then
    pcall(function()
      params:set("clock_tempo", bpm)
    end)
  end

  if clock then
    clock.tempo = bpm
  end
end

local function square_step(fish, amp_scale)
  local phrase_step = step16 % 64
  local bar_step = step16 % 16
  local section = math.floor(phrase_step / 16)
  local dense_section = math.floor(seeded(fish.pattern_seed, 3) * 4)
  local sparse_section = (dense_section + 2 + math.floor(seeded(fish.pattern_seed, 4) * 2)) % 4
  local density = 0.46

  if section == dense_section then
    density = 0.88
  elseif section == sparse_section then
    density = 0.18
  end

  local mode = nil
  if bar_step == 0 and seeded(fish.pattern_seed + math.floor(step16 / 16), 5) > density * 0.18 then
    mode = 0
  elseif bar_step == 8 and seeded(fish.pattern_seed + math.floor(step16 / 16), 6) > density * 0.08 then
    mode = 1
  elseif section == dense_section and (bar_step == 3 or bar_step == 6 or bar_step == 11 or bar_step == 14) then
    if fish_step_seed(fish, 7 + bar_step) < 0.72 then
      mode = 2
    end
  elseif bar_step % 4 == 2 and fish_step_seed(fish, 8 + bar_step) < density then
    mode = 2
  elseif bar_step % 2 == 1 and fish_step_seed(fish, 9 + bar_step) < density * 0.34 then
    mode = 2
  end

  if not mode then
    return
  end

  local degree_offset = mode == 2 and ((phrase_step + section) % 4) or 0
  local note = scale_hz(current_game, 1 + degree_offset, mode == 2 and 1 or 0)
  local accent = 0.72 + density * 0.38
  local base_amp = 0.52
  if mode == 0 then
    base_amp = 1.20
  elseif mode == 1 then
    base_amp = 0.62
  end

  local amp = base_amp * accent * (amp_scale or 1)
  local motion_x, motion_y = movement_from_fish(fish)
  fish_event(mode, note, timbre(fish, 10 + mode), amp, pan_from_fish(fish), motion_x, motion_y)

  if section == dense_section and mode == 2 and fish_step_seed(fish, 40 + bar_step) < 0.36 then
    delayed_fish_event(
      1 / 8,
      2,
      scale_hz(current_game, 3 + (bar_step % 3), 1),
      timbre(fish, 44),
      amp * 0.46,
      pan_from_fish(fish) * -0.6,
      motion_x,
      motion_y
    )
  end
end

local function arp_degree(fish, index)
  local patterns = {
    { 1, 2, 3, 5, 6, 8, 10, 11, 13, 11, 10, 8, 6, 5, 3, 2 },
    { 1, 3, 5, 8, 10, 13, 15, 13, 10, 8, 6, 5, 3, 5, 8, 10 },
    { 1, 5, 8, 10, 13, 10, 8, 5, 3, 6, 10, 13, 17, 13, 10, 6 },
    { 1, 2, 5, 6, 8, 10, 13, 15, 13, 10, 8, 6, 5, 3, 2, 1 },
  }
  local pattern = choice(fish.pattern_seed, 11, patterns)
  local reverse = seeded(fish.pattern_seed, 12) > 0.76
  local phase = math.floor(seeded(fish.pattern_seed, 13) * #pattern)
  local pos = (index + phase) % #pattern

  if reverse then
    pos = (#pattern - 1) - pos
  end

  return pattern[pos + 1]
end

local function circle_step(fish, amp_scale)
  local index = step16
  local degree = arp_degree(fish, index)
  local octave = choice(fish.timbre_seed, 14, { 1, 1, 1, 2 })
  local note = scale_hz(current_game, degree, octave)
  local phrase_step = index % 16
  local accent = 1.0
  if phrase_step == 0 then
    accent = 1.28
  elseif phrase_step == 4 or phrase_step == 8 or phrase_step == 12 then
    accent = 1.12
  elseif phrase_step % 2 == 1 then
    accent = 0.86
  end

  local amp = 0.50 * accent * (amp_scale or 1)
  local pan = pan_from_fish(fish)
  local motion_x, motion_y = movement_from_fish(fish)
  fish_event(3, note, timbre(fish, 15), amp, pan, motion_x, motion_y)
end

local function triangle_step(fish, amp_scale)
  local period = choice(fish.pattern_seed, 21, { 8, 12, 16 })
  if step16 % period ~= 0 then
    return
  end

  local intervals = {
    { 1, 3 },
    { 1, 4 },
    { 2, 5 },
    { 3, 6 },
  }
  local pair = choice(fish.pattern_seed, 22 + math.floor(step16 / period), intervals)
  local degree = pair[1]
  local note = scale_hz(current_game, degree, 1)
  local motion_x, motion_y = movement_from_fish(fish)
  fish_event(
    4,
    note,
    timbre(fish, pair[2]),
    0.54 * (amp_scale or 1),
    pan_from_fish(fish),
    motion_x,
    motion_y
  )
end

local function run_fish_step(fish, amp_scale)
  if not fish then
    return
  end

  if fish.type == "square" then
    square_step(fish, amp_scale)
  elseif fish.type == "circle" then
    circle_step(fish, amp_scale)
  elseif fish.type == "triangle" then
    triangle_step(fish, amp_scale)
  end
end

local function trigger_preview(fish)
  if fish.type == "square" then
    fish_event(2, scale_hz(current_game, 1, 1), timbre(fish, 30), 0.88, pan_from_fish(fish), 0, 0)
  elseif fish.type == "circle" then
    fish_event(3, scale_hz(current_game, arp_degree(fish, 0), 1), timbre(fish, 32), 0.62, pan_from_fish(fish), 0, 0)
  elseif fish.type == "triangle" then
    fish_event(4, scale_hz(current_game, 1, 1), timbre(fish, 31), 0.50, pan_from_fish(fish), 0, 0)
  end
end

local function update_preview()
  local fish = current_game and current_game.active_fish
  if not fish or current_game.state ~= "RESONANCE" then
    return
  end

  if fish.overlap_signal < 0.25 then
    preview_latch[fish.id] = nil
    return
  end

  if fish.overlap_signal >= 0.72 and fish.depth_signal >= 0.55 and not preview_latch[fish.id] then
    preview_latch[fish.id] = true
    trigger_preview(fish)
  end
end

local function update_struggle()
  if not current_game or current_game.state ~= "STRUGGLE" then
    return
  end

  local safe = safe_tension_weight(current_game)
  run_fish_step(current_game.hooked_fish, 0.95 + safe * 0.55)
end

local function update_loops()
  for _, layer in pairs(loop_state) do
    run_fish_step(layer, 0.62 + (layer.loop_amp or 0))
  end
end

local function clock_loop()
  while true do
    clock.sync(1 / 4)
    step16 = step16 + 1
    update_preview()
    update_struggle()
    update_loops()
  end
end

function Music.drone_params(game)
  local depth = game.depth or 0
  local signal = game.signal or 0
  local depth_signal = game.depth_signal or signal
  local fish = (game.overlap_signal or 0) * depth_signal
  local pressure = depth
  local brightness = clamp(0.42 - depth * 0.10 + signal * 0.08 + fish * 0.18, 0.18, 0.72)
  local root_hz = base_root_hz(game)

  return {
    root_hz = root_hz,
    fifth_hz = root_hz * 1.5,
    brightness_0_1 = brightness,
    pressure_0_1 = pressure,
    signal_0_1 = signal,
    depth_signal_0_1 = depth_signal,
    fish_0_1 = fish,
  }
end

function Music.init(game)
  current_game = game
  step16 = 0
  drone_send_t = 0
  preview_latch = {}
  loop_state = {}

  if game and game.config.BPM then
    set_clock_bpm(game.config.BPM)
  end

  if has_engine_command("clear_layers") then
    engine.clear_layers()
  end
  if has_engine_command("start") then
    engine.start()
  end

  if clock and clock.run then
    clock_id = clock.run(clock_loop)
  end
end

function Music.cleanup()
  if clock and clock.cancel and clock_id then
    clock.cancel(clock_id)
    clock_id = nil
  end
  if has_engine_command("stop") then
    engine.stop()
  end
end

function Music.remove_loop_event(event)
  if event.loop_key then
    loop_state[event.loop_key] = nil
    return
  end

  if event.fish_type then
    for key, layer in pairs(loop_state) do
      if layer.type == event.fish_type then
        loop_state[key] = nil
        return
      end
    end
  end
end

function Music.capture_loop(event)
  local layer = event.layer or {}
  local fish = event.fish or layer
  local fish_type = event.fish_type or layer.type

  if not fish_type then
    return
  end

  local loop_key = layer.loop_key or string.format("%s:%s", fish_type, tostring(layer.pattern_seed or fish.pattern_seed or 1))

  loop_state[loop_key] = {
    id = layer.pattern_seed or fish.pattern_seed or 1,
    loop_key = loop_key,
    type = fish_type,
    slot = layer.slot or fish.slot or 1,
    x = fish.x or 0.5,
    motion_x = 0.08,
    motion_y = 0.06,
    pattern_seed = layer.pattern_seed or fish.pattern_seed or 1,
    timbre_seed = layer.timbre_seed or fish.timbre_seed or 1,
    loop_amp = clamp((layer.avg_tension or 0.4) * 0.35 + (layer.max_tension or 0.5) * 0.25, 0, 0.55),
  }
end

function Music.tick(game, events)
  if engine == nil then
    return
  end

  current_game = game

  local drone = Music.drone_params(game)
  drone_send_t = drone_send_t + game.config.TICK_S

  if has_engine_command("drone") and drone_send_t >= 0.08 then
    drone_send_t = 0
    local amp = 0.0
    if game.state == "EXPLORE" then
      amp = 0.42 + drone.pressure_0_1 * 0.06
    elseif game.state == "RESONANCE" then
      amp = 0.48 + drone.pressure_0_1 * 0.06 + drone.signal_0_1 * 0.08
    elseif game.state == "STRUGGLE" then
      amp = 0.36 + drone.pressure_0_1 * 0.05
    elseif game.state == "SURFACE" then
      amp = 0.30
    end
    engine.drone(
      drone.root_hz,
      clamp(game.depth or 0, 0, 1),
      drone.brightness_0_1,
      drone.pressure_0_1,
      drone.signal_0_1,
      drone.fish_0_1,
      amp
    )
  end

  for _, event in ipairs(events) do
    if event.type == "loop_removed" then
      Music.remove_loop_event(event)
    elseif event.type == "surface" and event.name == "captured" then
      Music.capture_loop(event)
    end
  end
end

return Music
