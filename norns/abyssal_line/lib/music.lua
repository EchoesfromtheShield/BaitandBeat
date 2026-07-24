local Music = {}

local last_drone_t = 0
local last_fifth_t = 0

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

function Music.drone_params(game)
  local depth = game.depth or 0
  local signal = game.signal or 0
  local depth_signal = game.depth_signal or signal
  local fish = (game.overlap_signal or 0) * depth_signal
  local pressure = depth
  local brightness = clamp(1 - depth * 0.65 + signal * 0.18 + fish * 0.22, 0, 1)
  local root_hz = game.config.BASE_DRONE_HZ * (1 + depth * 0.9)

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

local function event_hz(name, base)
  if name == "small_tug" then
    return base * 2
  end
  if name == "long_pull" then
    return base * 0.75
  end
  if name == "vibration" then
    return base * 3
  end
  return base
end

function Music.tick(game, events)
  if engine == nil then
    return
  end

  local drone = Music.drone_params(game)
  last_drone_t = last_drone_t + game.config.TICK_S

  if game.state ~= "CAST" and last_drone_t >= 0.45 then
    last_drone_t = 0
    if engine.amp then
      engine.amp(0.12 + drone.pressure_0_1 * 0.08)
    end
    if engine.release then
      engine.release(1.4)
    end
    if engine.hz then
      engine.hz(drone.root_hz)
    end
  end

  last_fifth_t = last_fifth_t + game.config.TICK_S
  if (game.state == "RESONANCE" or game.state == "STRUGGLE")
      and drone.fish_0_1 > 0.06 then
    local interval = 0.22 + (1 - drone.fish_0_1) * 0.46
    if last_fifth_t >= interval then
      last_fifth_t = 0
      if engine.amp then
        engine.amp(0.04 + drone.fish_0_1 * 0.13)
      end
      if engine.release then
        engine.release(0.45 + drone.fish_0_1 * 0.35)
      end
      if engine.hz then
        engine.hz(drone.fifth_hz)
      end
    end
  else
    last_fifth_t = 0
  end

  for _, event in ipairs(events) do
    if event.type == "pattern" and engine.hz then
      local hz = event_hz(event.name, drone.root_hz)
      if engine.amp then
        engine.amp(0.10 + (event.tension or 0) * 0.18)
      end
      if engine.release then
        engine.release(event.name == "long_pull" and 0.8 or 0.15)
      end
      engine.hz(hz)
    end
  end
end

return Music
