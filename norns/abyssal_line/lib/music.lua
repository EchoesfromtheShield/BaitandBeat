local Music = {}

local drone_send_t = 0

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function has_engine_command(name)
  return engine ~= nil and engine[name] ~= nil
end

local function strike_kind(name)
  if name == "small_tug" then
    return 0
  end
  if name == "long_pull" then
    return 1
  end
  if name == "vibration" then
    return 2
  end
  return 3
end

function Music.drone_params(game)
  local depth = game.depth or 0
  local signal = game.signal or 0
  local depth_signal = game.depth_signal or signal
  local fish = (game.overlap_signal or 0) * depth_signal
  local pressure = depth
  local brightness = clamp(1 - depth * 0.72 + signal * 0.18 + fish * 0.26, 0, 1)
  local root_hz = game.config.BASE_DRONE_HZ * (1 + depth * 0.72)

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

function Music.init()
  drone_send_t = 0
  if has_engine_command("clear_layers") then
    engine.clear_layers()
  end
  if has_engine_command("start") then
    engine.start()
  end
end

function Music.cleanup()
  if has_engine_command("stop") then
    engine.stop()
  end
end

function Music.capture_layer(event, drone)
  if not has_engine_command("capture_layer") then
    return
  end

  local layer = event.layer or {}
  local slot = ((event.layer_index or 1) - 1) % 3 + 1
  local fight_time = math.max(layer.fight_time or 10, 0.1)
  local event_count = layer.event_count or 1
  local density = clamp(event_count / fight_time, 0.05, 2.8)
  local avg_tension = clamp(layer.avg_tension or 0.4, 0, 1)
  local max_tension = clamp(layer.max_tension or avg_tension, 0, 1)
  local texture = clamp(avg_tension * 0.65 + max_tension * 0.35, 0, 1)
  local rate = 0.12 + density * 0.85
  local pan = ({ -0.48, 0.42, 0.0 })[slot] or 0
  local amp = 0.08 + math.min(slot, 3) * 0.012

  engine.capture_layer(slot, drone.root_hz, rate, texture, pan, amp)
end

function Music.tick(game, events)
  if engine == nil then
    return
  end

  local drone = Music.drone_params(game)
  drone_send_t = drone_send_t + game.config.TICK_S

  if has_engine_command("drone") and drone_send_t >= 0.08 then
    drone_send_t = 0
    local amp = game.state == "CAST" and 0.0 or 0.26 + drone.pressure_0_1 * 0.08
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
    if event.type == "pattern" and has_engine_command("strike") then
      local pan = ((game.fish_x or 0.5) - 0.5) * 1.4
      engine.strike(
        strike_kind(event.name),
        drone.root_hz,
        clamp(event.pull or 0, 0, 1),
        clamp(event.tension or game.tension or 0, 0, 1),
        clamp(pan, -1, 1)
      )
    elseif event.type == "surface" and event.name == "captured" then
      Music.capture_layer(event, drone)
    end
  end
end

return Music
