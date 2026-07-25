local Music = {}

local DEFAULT_SCALE = { 0, 3, 5, 7, 10, 12, 15, 17, 19, 22 }

local current_game = nil
local clock_id = nil
local step16 = 0
local drone_send_t = 0
local preview_latch = {}
local preview_burst = nil
local loop_state = {}

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
  return seeded(fish and fish.timbre_seed or 1, salt)
end

local function fish_event(mode, note, timbre_value, amp, pan)
  if has_engine_command("fish_event") then
    engine.fish_event(mode, note, timbre_value, amp, pan)
  end
end

local function fish_step_seed(fish, salt)
  return seeded((fish and fish.pattern_seed or 1) + step16 * 17, salt)
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
  local subdivision = choice(fish.pattern_seed, 1, { 4, 2, 2, 1 })
  if step16 % subdivision ~= 0 then
    return
  end

  local local_step = math.floor(step16 / subdivision)
  local mode = 2
  if step16 % 16 == 0 then
    mode = 0
  elseif step16 % 16 == 8 then
    mode = 1
  elseif fish_step_seed(fish, 2) < 0.38 then
    mode = 2
  else
    return
  end

  local note = scale_hz(current_game, 1 + (mode == 2 and (local_step % 3) or 0), mode == 2 and 1 or 0)
  local amp = (mode == 0 and 1.1 or 0.78) * (amp_scale or 1)
  fish_event(mode, note, timbre(fish, 10 + mode), amp, pan_from_fish(fish))
end

local function arp_degree(fish, index)
  local mode = choice(fish.pattern_seed, 11, { "up", "down", "updown", "walk" })
  local notes = { 1, 2, 3, 5, 6, 8 }

  if mode == "down" then
    return notes[#notes - (index % #notes)]
  end

  if mode == "updown" then
    local period = (#notes * 2) - 2
    local pos = index % period
    if pos >= #notes then
      pos = period - pos
    end
    return notes[pos + 1]
  end

  if mode == "walk" then
    local offset = math.floor(seeded(fish.pattern_seed + index * 19, 12) * #notes)
    return notes[offset + 1]
  end

  return notes[(index % #notes) + 1]
end

local function circle_step(fish, amp_scale)
  local subdivision = choice(fish.pattern_seed, 13, { 2, 2, 1 })
  if step16 % subdivision ~= 0 then
    return
  end

  local index = math.floor(step16 / subdivision)
  local degree = arp_degree(fish, index)
  local octave = choice(fish.timbre_seed, 14, { 1, 1, 2 })
  local note = scale_hz(current_game, degree, octave)
  fish_event(3, note, timbre(fish, 15), 0.55 * (amp_scale or 1), pan_from_fish(fish))
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
  fish_event(4, note, timbre(fish, pair[2]), 0.72 * (amp_scale or 1), pan_from_fish(fish))
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
    fish_event(2, scale_hz(current_game, 1, 1), timbre(fish, 30), 0.95, pan_from_fish(fish))
  elseif fish.type == "circle" then
    preview_burst = { fish = fish, remaining = 4, index = 0 }
  elseif fish.type == "triangle" then
    fish_event(4, scale_hz(current_game, 1, 1), timbre(fish, 31), 0.84, pan_from_fish(fish))
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

local function update_preview_burst()
  if not preview_burst or not preview_burst.fish then
    return
  end

  local fish = preview_burst.fish
  local degree = arp_degree(fish, preview_burst.index)
  fish_event(3, scale_hz(current_game, degree, 1), timbre(fish, 32), 0.55, pan_from_fish(fish))
  preview_burst.index = preview_burst.index + 1
  preview_burst.remaining = preview_burst.remaining - 1

  if preview_burst.remaining <= 0 then
    preview_burst = nil
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
    update_preview_burst()
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
  local brightness = clamp(1 - depth * 0.72 + signal * 0.18 + fish * 0.26, 0, 1)
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
  preview_burst = nil
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

function Music.remove_loop(fish_type)
  loop_state[fish_type] = nil
end

function Music.capture_loop(event)
  local layer = event.layer or {}
  local fish = event.fish or layer
  local fish_type = event.fish_type or layer.type

  if not fish_type then
    return
  end

  loop_state[fish_type] = {
    id = layer.pattern_seed or fish.pattern_seed or 1,
    type = fish_type,
    slot = layer.slot or fish.slot or 1,
    x = fish.x or 0.5,
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
      amp = 1.00 + drone.pressure_0_1 * 0.22
    elseif game.state == "RESONANCE" then
      amp = 1.12 + drone.pressure_0_1 * 0.20 + drone.signal_0_1 * 0.18
    elseif game.state == "STRUGGLE" then
      amp = 0.88 + drone.pressure_0_1 * 0.12
    elseif game.state == "SURFACE" then
      amp = 0.74
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
      Music.remove_loop(event.fish_type)
    elseif event.type == "surface" and event.name == "captured" then
      Music.capture_loop(event)
    end
  end
end

return Music
