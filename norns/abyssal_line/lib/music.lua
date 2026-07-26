local Music = {}

local DEFAULT_SCALE = { 0, 3, 5, 7, 10, 12, 15, 17, 19, 22 }

local current_game = nil
local clock_id = nil
local step16 = 0
local drone_send_t = 0
local preview_latch = {}
local loop_state = {}
local TIMBRE_FAMILIES = 8
local CAPTURE_HANDOFF_STEPS = 24
local MOTION_MOD_SCALE = {
  square = { x = 0.16, y = 0.10 },
  circle = { x = 0.12, y = 0.08 },
  triangle = { x = 0.08, y = 0.05 },
}
local DRUM_VARIANTS = {
  {
    phrase = 64,
    density = 0.42,
    kick_prob = 0.92,
    snare_prob = 0.78,
    rim_prob = 0.48,
    kick = { 0, 10 },
    snare = { 4, 12 },
    rim = { 3, 7, 11, 15 },
    timbre = 10,
  },
  {
    phrase = 48,
    density = 0.52,
    kick_prob = 0.82,
    snare_prob = 0.64,
    rim_prob = 0.62,
    kick = { 0, 6, 12 },
    snare = { 8 },
    rim = { 2, 5, 10, 14 },
    timbre = 27,
  },
  {
    phrase = 64,
    density = 0.60,
    kick_prob = 0.74,
    snare_prob = 0.70,
    rim_prob = 0.76,
    kick = { 0, 8, 14 },
    snare = { 4, 11 },
    rim = { 1, 3, 6, 9, 13, 15 },
    timbre = 43,
  },
  {
    phrase = 80,
    density = 0.36,
    kick_prob = 0.88,
    snare_prob = 0.82,
    rim_prob = 0.42,
    kick = { 0, 5 },
    snare = { 7, 12 },
    rim = { 2, 4, 10, 14 },
    timbre = 59,
  },
  {
    phrase = 64,
    density = 0.56,
    kick_prob = 0.70,
    snare_prob = 0.58,
    rim_prob = 0.86,
    kick = { 0, 3, 11 },
    snare = { 6, 14 },
    rim = { 1, 5, 8, 10, 13, 15 },
    timbre = 76,
  },
}
local ARP_INTERVAL_SETS = {
  { 1, 2, 3, 5, 6 },
  { 1, 3, 5, 6, 8 },
  { 1, 2, 5, 8, 10 },
  { 1, 3, 6, 8, 10 },
  { 1, 5, 6, 8, 11 },
  { 1, 2, 4, 6, 9 },
}
local ARP_STYLES = { "up", "down", "updown", "skip", "outside" }
local ARP_OCTAVE_SPANS = { 2, 2, 3, 3, 4 }

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

local function step_in(pattern, step)
  for _, value in ipairs(pattern) do
    if value == step then
      return true
    end
  end

  return false
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

local function drum_timbre(fish, variant, mode, step)
  local raw = timbre(fish, variant.timbre + mode * 13)
  local step_color = seeded((fish and fish.pattern_seed or 1) + step16 * 17, 125 + mode + step) * 0.18

  if mode == 0 then
    return clamp(0.08 + raw * 0.18 + step_color * 0.35, 0.06, 0.30)
  elseif mode == 1 then
    return clamp(0.20 + raw * 0.34 + step_color * 0.55, 0.16, 0.58)
  end

  return clamp(0.14 + raw * 0.30 + step_color * 0.45, 0.10, 0.48)
end

local function movement_from_fish(fish)
  if fish and fish.loop_key then
    local y = clamp(fish.mod_y or 0.5, 0, 1)
    local handoff = clamp(fish.handoff_0_1 or 0, 0, 1)
    local x_motion = 0
    local y_motion = 0

    if fish.type == "square" then
      x_motion = y
      y_motion = 0
    elseif fish.type == "circle" then
      x_motion = y
      y_motion = y
    elseif fish.type == "triangle" then
      x_motion = y * 0.35
      y_motion = 0
    end

    if handoff > 0 then
      x_motion = x_motion * (1 - handoff) + clamp(fish.capture_motion_x or x_motion, 0, 1) * handoff
      y_motion = y_motion * (1 - handoff) + clamp(fish.capture_motion_y or y_motion, 0, 1) * handoff
    end

    return x_motion, y_motion
  end

  return 0, 0
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
  local variant = choice(fish.pattern_seed, 2, DRUM_VARIANTS)
  local phrase = variant.phrase or 64
  local phrase_step = step16 % phrase
  local bar_step = step16 % 16
  local section_count = math.max(1, math.floor(phrase / 16))
  local section = math.floor(phrase_step / 16)
  local dense_section = math.floor(seeded(fish.pattern_seed, 3) * section_count)
  local sparse_offset = section_count > 1 and (1 + math.floor(seeded(fish.pattern_seed, 4) * (section_count - 1))) or 0
  local sparse_section = (dense_section + sparse_offset) % section_count
  local density = variant.density or 0.46
  local events_mod = clamp(fish.mod_x or 0.5, 0, 1)

  if section == dense_section then
    density = math.min(0.92, density + 0.30)
  elseif section == sparse_section then
    density = math.max(0.12, density - 0.28)
  end
  density = clamp(density * (0.50 + events_mod * 1.15), 0.08, 0.98)

  local mode = nil
  if step_in(variant.kick, bar_step) and fish_step_seed(fish, 5 + bar_step) < variant.kick_prob then
    mode = 0
  elseif step_in(variant.snare, bar_step) and fish_step_seed(fish, 22 + bar_step) < variant.snare_prob then
    mode = 1
  elseif step_in(variant.rim, bar_step) and fish_step_seed(fish, 37 + bar_step) < variant.rim_prob then
    mode = 2
  elseif section == dense_section and bar_step % 2 == 1 then
    if fish_step_seed(fish, 51 + bar_step) < density * 0.82 then
      mode = 2
    end
  elseif section ~= sparse_section and bar_step % 4 == 2 and fish_step_seed(fish, 62 + bar_step) < density * 0.64 then
    mode = 2
  elseif section == sparse_section and bar_step % 8 == 6 and fish_step_seed(fish, 74 + bar_step) < density * 0.35 then
    mode = 2
  end

  if not mode then
    return
  end

  if mode ~= 0 then
    local event_probability = clamp(0.22 + events_mod * 0.78, 0, 1)
    if fish_step_seed(fish, 70 + bar_step) > event_probability then
      return
    end
  end

  local degree_offset = mode == 2 and ((phrase_step + section) % 4) or 0
  local note = scale_hz(current_game, 1 + degree_offset, mode == 2 and 1 or 0)
  local accent = 0.72 + density * 0.38
  local base_amp = 0.94
  if mode == 0 then
    base_amp = 1.54
  elseif mode == 1 then
    base_amp = 1.24
  end

  local amp = base_amp * accent * (amp_scale or 1)
  local motion_x, motion_y = movement_from_fish(fish)
  fish_event(mode, note, drum_timbre(fish, variant, mode, bar_step), amp, pan_from_fish(fish), motion_x, motion_y)

  if section == dense_section and mode == 2 and fish_step_seed(fish, 40 + bar_step) < 0.36 then
    delayed_fish_event(
      1 / 8,
      2,
      scale_hz(current_game, 3 + (bar_step % 3), 1),
      drum_timbre(fish, variant, 2, bar_step + 17),
      amp * 0.58,
      pan_from_fish(fish) * -0.6,
      motion_x,
      motion_y
    )
  end
end

local function arp_degree(fish, index)
  local intervals = choice(fish.pattern_seed, 11, ARP_INTERVAL_SETS)
  local style = choice(fish.pattern_seed, 12, ARP_STYLES)
  local octaves = choice(fish.pattern_seed, 13, ARP_OCTAVE_SPANS)
  local source = {}
  local sequence = {}

  for octave = 0, octaves - 1 do
    for _, degree in ipairs(intervals) do
      table.insert(source, degree + octave * 5)
    end
  end

  if style == "down" then
    for i = #source, 1, -1 do
      table.insert(sequence, source[i])
    end
  elseif style == "updown" then
    for i = 1, #source do
      table.insert(sequence, source[i])
    end
    for i = #source - 1, 2, -1 do
      table.insert(sequence, source[i])
    end
  elseif style == "skip" then
    for i = 1, #source, 2 do
      table.insert(sequence, source[i])
    end
    for i = 2, #source, 2 do
      table.insert(sequence, source[i])
    end
  elseif style == "outside" then
    local lo = 1
    local hi = #source
    while lo <= hi do
      table.insert(sequence, source[lo])
      if hi ~= lo then
        table.insert(sequence, source[hi])
      end
      lo = lo + 1
      hi = hi - 1
    end
  else
    sequence = source
  end

  local phase = math.floor(seeded(fish.pattern_seed, 16) * #sequence)
  local pos = (index + phase) % #sequence
  return sequence[pos + 1]
end

local function arp_subdivision(fish)
  local bucket = math.floor(seeded(fish.pattern_seed, 24) * 3)
  return clamp(bucket, 0, 2)
end

local function arp_accent(index)
  local phrase_step = index % 16
  if phrase_step == 0 then
    return 1.28
  end
  if phrase_step == 4 or phrase_step == 8 or phrase_step == 12 then
    return 1.12
  end
  if phrase_step % 2 == 1 then
    return 0.86
  end
  return 1.0
end

local function trigger_arp_note(fish, index, amp_scale, amp_mul, pan_mul, motion_x, motion_y)
  local degree = arp_degree(fish, index)
  local octave = choice(fish.timbre_seed, 15, { 1, 1, 1, 2 })
  local note = scale_hz(current_game, degree, octave)
  local amp = 0.32 * arp_accent(index) * (amp_scale or 1) * (amp_mul or 1)
  local pan = pan_from_fish(fish) * (pan_mul or 1)

  fish_event(3, note, timbre(fish, 15), amp, pan, motion_x, motion_y)
end

local function circle_step(fish, amp_scale)
  local subdivision = arp_subdivision(fish)
  local index = step16
  local trigger_probability = clamp(0.35 + (fish.mod_x or 0.5) * 0.65, 0, 1)

  if subdivision == 0 then
    if step16 % 2 ~= 0 then
      return
    end
    index = math.floor(step16 / 2)
  elseif subdivision == 2 then
    index = step16 * 2
  end

  local motion_x, motion_y = movement_from_fish(fish)
  if seeded(fish.pattern_seed + index * 31, 17) <= trigger_probability then
    trigger_arp_note(fish, index, amp_scale, 1.0, 1.0, motion_x, motion_y)
  end

  if subdivision == 2 then
    if seeded(fish.pattern_seed + (index + 1) * 31, 17) > trigger_probability then
      return
    end

    local degree = arp_degree(fish, index + 1)
    local octave = choice(fish.timbre_seed, 15, { 1, 1, 1, 2 })
    local note = scale_hz(current_game, degree, octave)
    delayed_fish_event(
      1 / 8,
      3,
      note,
      timbre(fish, 16),
      0.30 * arp_accent(index + 1) * (amp_scale or 1) * 0.92,
      pan_from_fish(fish),
      motion_x,
      motion_y
    )
  end
end

local function triangle_step(fish, amp_scale)
  local period = choice(fish.pattern_seed, 21, { 8, 12, 16 })
  if step16 % period ~= 0 then
    return
  end

  local harmony = clamp(fish.mod_x or 0.5, 0, 1)
  local intervals = { { 4, 3 } }
  if harmony >= 0.34 and harmony < 0.67 then
    intervals = {
      { 4, 3 },
      { 3, 4 },
      { 5, 5 },
    }
  elseif harmony >= 0.67 then
    intervals = {
      { 4, 3 },
      { 3, 4 },
      { 5, 5 },
      { 6, 6 },
      { 8, 7 },
    }
  end
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
    local variant = choice(fish.pattern_seed, 2, DRUM_VARIANTS)
    fish_event(0, scale_hz(current_game, 1, 0), drum_timbre(fish, variant, 0, 0), 1.20, pan_from_fish(fish), 0, 0)
  elseif fish.type == "circle" then
    fish_event(3, scale_hz(current_game, arp_degree(fish, 0), 1), timbre(fish, 32), 0.44, pan_from_fish(fish), 0, 0)
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
    local volume = clamp(layer.volume_0_1 or 0.85, 0, 1)
    local handoff = 0

    if layer.handoff_steps and layer.handoff_steps > 0 then
      handoff = clamp(layer.handoff_steps / math.max(1, layer.handoff_total_steps or CAPTURE_HANDOFF_STEPS), 0, 1)
      layer.handoff_steps = layer.handoff_steps - 1
    else
      layer.handoff_steps = nil
      layer.handoff_total_steps = nil
    end

    layer.handoff_0_1 = handoff
    run_fish_step(layer, (0.62 + (layer.loop_amp or 0)) * volume * (0.42 + (1 - handoff) * 0.58))
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

function Music.update_loop_event(event)
  local layer = event.layer or {}
  local key = event.loop_key or layer.loop_key

  if not key or not loop_state[key] then
    return
  end

  loop_state[key].volume_0_1 = layer.volume_0_1 or loop_state[key].volume_0_1
  loop_state[key].mod_x = layer.mod_x or loop_state[key].mod_x
  loop_state[key].mod_y = layer.mod_y or loop_state[key].mod_y
end

function Music.capture_loop(event)
  local layer = event.layer or {}
  local fish = event.fish or layer
  local fish_type = event.fish_type or layer.type

  if not fish_type then
    return
  end

  local loop_key = layer.loop_key or string.format("%s:%s", fish_type, tostring(layer.pattern_seed or fish.pattern_seed or 1))
  local motion_scale = MOTION_MOD_SCALE[fish_type] or { x = 0.10, y = 0.08 }
  local capture_motion_x = clamp((fish.motion_x or 0) * motion_scale.x, 0, 1)
  local capture_motion_y = clamp((fish.motion_y or 0) * motion_scale.y, 0, 1)

  if fish_type == "square" then
    capture_motion_y = clamp(capture_motion_y, 0, 0.025)
  end

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
    volume_0_1 = layer.volume_0_1 or 0.85,
    mod_x = layer.mod_x or 0.5,
    mod_y = layer.mod_y or 0.5,
    capture_motion_x = capture_motion_x,
    capture_motion_y = capture_motion_y,
    handoff_steps = CAPTURE_HANDOFF_STEPS,
    handoff_total_steps = CAPTURE_HANDOFF_STEPS,
    handoff_0_1 = 1,
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
      amp = 0.0
    elseif game.state == "RESONANCE" then
      amp = drone.fish_0_1 > 0.02 and (0.08 + drone.fish_0_1 * 0.64) or 0.0
    elseif game.state == "STRUGGLE" then
      amp = 0.0
    elseif game.state == "SURFACE" then
      amp = 0.0
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
    elseif event.type == "loop_updated" then
      Music.update_loop_event(event)
    elseif event.type == "surface" and event.name == "captured" then
      Music.capture_loop(event)
    end
  end
end

return Music
