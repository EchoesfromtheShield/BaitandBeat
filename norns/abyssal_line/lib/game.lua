local Game = {}
Game.__index = Game

local FISH_TYPES = {
  { type = "square", slot = 1 },
  { type = "circle", slot = 2 },
  { type = "triangle", slot = 3 },
}

local CAPTURE_LIMITS = {
  square = 1,
  circle = 2,
  triangle = 2,
}

local PULL_PATTERN = {
  { name = "rest", duration = 0.90, pull = 0.00 },
  { name = "small_tug", duration = 0.18, pull = 0.42 },
  { name = "rest", duration = 0.22, pull = 0.00 },
  { name = "small_tug", duration = 0.18, pull = 0.36 },
  { name = "long_pull", duration = 1.20, pull = 0.68 },
  { name = "rest", duration = 0.70, pull = 0.00 },
  { name = "vibration", duration = 0.12, pull = 0.34 },
  { name = "vibration", duration = 0.12, pull = 0.50 },
  { name = "vibration", duration = 0.12, pull = 0.28 },
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

local function pattern_period()
  local total = 0
  for _, item in ipairs(PULL_PATTERN) do
    total = total + item.duration
  end
  return total
end

local PATTERN_PERIOD = pattern_period()

local function pattern_at(t)
  local x = t % PATTERN_PERIOD
  local cursor = 0

  for index, item in ipairs(PULL_PATTERN) do
    cursor = cursor + item.duration
    if x <= cursor then
      return item, index
    end
  end

  return PULL_PATTERN[#PULL_PATTERN], #PULL_PATTERN
end

local function struggle_gain(config, tension)
  local safe_mid = (config.SAFE_TENSION_MIN + config.SAFE_TENSION_MAX) * 0.5
  local span = math.max(safe_mid - config.SLACK_TENSION, config.OVERLOAD_TENSION - safe_mid)
  local edge_distance = clamp(math.abs(tension - safe_mid) / span, 0, 1)
  local center_weight = 1 - edge_distance
  local edge_gain = config.STRUGGLE_EDGE_GAIN or 0.28
  return edge_gain + (1 - edge_gain) * center_weight * center_weight
end

local function rand_range(lo, hi)
  return lo + math.random() * (hi - lo)
end

local function random_depth(existing)
  local depth = 0.2

  for _ = 1, 24 do
    depth = rand_range(0.16, 0.88)
    local ok = true
    for _, other in ipairs(existing) do
      if math.abs(depth - other) < 0.13 then
        ok = false
        break
      end
    end

    if ok then
      return depth
    end
  end

  return depth
end

function Game.new(config)
  math.randomseed(os.time())

  local self = {
    config = config,
    state = "CAST",
    depth = 0.0,
    line_depth = 0.0,
    fish = {},
    active_fish = nil,
    hooked_fish = nil,
    creature_depth = config.CREATURE_DEPTH,
    fish_depth = config.CREATURE_DEPTH,
    hooked_depth = config.CREATURE_DEPTH,
    hook_x = 0.5,
    fish_x = 0.5,
    depth_signal = 0.0,
    overlap_signal = 0.0,
    signal = 0.0,
    still_timer = 0.0,
    bite_ready = false,
    fight_time = 0.0,
    pattern_index = 0,
    tension = 0.0,
    slack_timer = 0.0,
    overload_timer = 0.0,
    fight_tension_sum = 0.0,
    fight_tension_samples = 0,
    fight_max_tension = 0.0,
    capture_progress = 0.0,
    captured_by_type = {},
    captured_layers = {},
    captured_events = {},
    pending_events = {},
    generation = 0,
    last_reason = "",
  }

  return setmetatable(self, Game)
end

function Game:_queue(event)
  table.insert(self.pending_events, event)
end

function Game:_rebuild_captured_layers()
  self.captured_layers = {}
  for _, fish_type in ipairs(FISH_TYPES) do
    local layers = self.captured_by_type[fish_type.type] or {}
    for _, layer in ipairs(layers) do
      table.insert(self.captured_layers, layer)
    end
  end
end

function Game:_make_fish(def, depth)
  self.generation = self.generation + 1
  local pattern_seed = math.random(1000, 999999)
  local timbre_seed = math.random(1000, 999999)

  return {
    id = self.generation,
    type = def.type,
    slot = def.slot,
    depth = depth,
    fish_depth = depth,
    hooked_depth = depth,
    x = rand_range(0.22, 0.78),
    target_x = rand_range(0.18, 0.82),
    turn_timer = rand_range(0.25, 1.4),
    burst_timer = 0,
    pattern_seed = pattern_seed,
    timbre_seed = timbre_seed,
    depth_signal = 0,
    overlap_signal = 0,
    signal = 0,
  }
end

function Game:_spawn_fish_set()
  local depths = {}
  self.fish = {}

  for _, def in ipairs(FISH_TYPES) do
    local depth = random_depth(depths)
    table.insert(depths, depth)
    table.insert(self.fish, self:_make_fish(def, depth))
  end

  self.active_fish = nil
  self.hooked_fish = nil
end

function Game:_focus_fish(fish)
  if not fish then
    self.creature_depth = self.line_depth
    self.fish_depth = self.line_depth
    self.fish_x = self.hook_x
    self.depth_signal = 0
    self.overlap_signal = 0
    self.signal = 0
    return
  end

  self.creature_depth = fish.depth
  self.fish_depth = fish.fish_depth or fish.depth
  self.hooked_depth = fish.hooked_depth or fish.depth
  self.fish_x = fish.x
  self.depth_signal = fish.depth_signal or 0
  self.overlap_signal = fish.overlap_signal or 0
  self.signal = fish.signal or 0
end

function Game:encoder(delta)
  if self.state == "CAST" or self.state == "SURFACE" then
    return
  end

  local step = self.config.EXPLORE_DEPTH_STEP or self.config.DEPTH_STEP
  if self.state == "STRUGGLE" then
    local base = self.config.STRUGGLE_DEPTH_STEP or step
    step = base * struggle_gain(self.config, self.tension)
  end

  self.line_depth = clamp(self.line_depth + delta * step, 0, 1)
  self.depth = self.line_depth
end

function Game:press()
  if self.state == "CAST" then
    self:_spawn_fish_set()
    self.line_depth = self.config.CAST_DEPTH or 0.04
    self.depth = self.line_depth
    self.state = "EXPLORE"
    self.last_reason = "cast"
    return
  end

  if self.state == "RESONANCE" and self.bite_ready and self.active_fish then
    local fish = self.active_fish
    local layers = self.captured_by_type[fish.type] or {}
    local limit = CAPTURE_LIMITS[fish.type] or 1

    if #layers >= limit then
      local removed = table.remove(layers, 1)
      self.captured_by_type[fish.type] = layers
      self:_rebuild_captured_layers()
      self:_queue({
        type = "loop_removed",
        fish_type = fish.type,
        slot = fish.slot,
        loop_key = removed and removed.loop_key or nil,
        layer = removed,
      })
    end

    self.state = "STRUGGLE"
    self.hooked_fish = fish
    self.fight_time = 0
    self.pattern_index = 0
    fish.hooked_depth = fish.depth
    fish.fish_depth = fish.depth
    fish.target_x = fish.x < self.hook_x and 0.74 or 0.26
    fish.turn_timer = 0.15
    fish.burst_timer = 0
    self.bite_ready = false
    self.captured_events = {}
    self.fight_tension_sum = 0
    self.fight_tension_samples = 0
    self.fight_max_tension = 0
    self.capture_progress = 0
    self.last_reason = "hooked"
    self:_focus_fish(fish)
    return
  end

  if self.state == "SURFACE" then
    self:reset_to_explore()
  end
end

function Game:reset_to_explore()
  self.state = "EXPLORE"
  self:_spawn_fish_set()
  self.signal = 0
  self.depth_signal = 0
  self.overlap_signal = 0
  self.still_timer = 0
  self.bite_ready = false
  self.fight_time = 0
  self.tension = 0
  self.slack_timer = 0
  self.overload_timer = 0
  self.fight_tension_sum = 0
  self.fight_tension_samples = 0
  self.fight_max_tension = 0
  self.capture_progress = 0
end

function Game:_update_fish_swim(fish, dt, depth_signal, speed_scale)
  local base_speed = self.config.CREATURE_SWIM_SPEED or 0.17
  local scale = speed_scale or 1.0
  fish.turn_timer = fish.turn_timer - dt
  fish.burst_timer = math.max(0, fish.burst_timer - dt)

  if fish.turn_timer <= 0 then
    local side_target = fish.x < self.hook_x and 1 or -1
    local far = 0.23 + math.random() * 0.18
    local near = 0.05 + math.random() * 0.12
    local offset = math.random() < 0.65 and far or near
    fish.target_x = clamp(self.hook_x + side_target * offset, 0.08, 0.92)
    fish.turn_timer = 1.0 + math.random() * 2.2

    if math.random() < (self.config.CREATURE_SWIM_BURST_CHANCE or 0.34) then
      fish.burst_timer = 0.25 + math.random() * 0.55
    end
  end

  local burst = fish.burst_timer > 0 and 2.8 or 1.0
  local speed = base_speed * scale * (0.75 + depth_signal * 0.55) * burst
  local dx = fish.target_x - fish.x
  local max_step = speed * dt

  if math.abs(dx) <= max_step then
    fish.x = fish.target_x
  elseif dx > 0 then
    fish.x = fish.x + max_step
  else
    fish.x = fish.x - max_step
  end

  fish.overlap_signal = clamp(
    1 - (math.abs(fish.x - self.hook_x) / (self.config.HOOK_OVERLAP_RADIUS or 0.105)),
    0,
    1
  )
end

function Game:_update_resonance(dt)
  local best = nil
  local best_signal = 0

  for _, fish in ipairs(self.fish) do
    local distance = math.abs(self.line_depth - fish.depth)
    fish.depth_signal = clamp(1 - (distance / self.config.RESONANCE_RADIUS), 0, 1)
    self:_update_fish_swim(fish, dt, fish.depth_signal)
    fish.signal = fish.depth_signal * (0.45 + fish.overlap_signal * 0.55)

    if fish.signal > best_signal then
      best = fish
      best_signal = fish.signal
    end
  end

  if not best or best.depth_signal <= 0 then
    self.state = "EXPLORE"
    self.active_fish = nil
    self.still_timer = 0
    self.bite_ready = false
    self:_focus_fish(nil)
    return
  end

  if self.active_fish ~= best then
    self.still_timer = 0
    self.bite_ready = false
  end

  self.active_fish = best
  self.state = "RESONANCE"
  self:_focus_fish(best)

  local distance = math.abs(self.line_depth - best.depth)
  if distance <= self.config.BITE_RADIUS then
    self.still_timer = self.still_timer + dt
  else
    self.still_timer = math.max(0, self.still_timer - dt * 2)
  end

  self.bite_ready = self.still_timer >= self.config.BITE_HOLD_S
    and best.overlap_signal >= 0.72
end

function Game:_fail_to_explore(events, reason)
  self.last_reason = reason
  self:reset_to_explore()
  table.insert(events, { type = "failure", name = reason })
end

function Game:_update_struggle(dt, events)
  local fish = self.hooked_fish
  if not fish then
    self:_fail_to_explore(events, "lost_hook")
    return
  end

  self.fight_time = self.fight_time + dt

  local item, index = pattern_at(self.fight_time)
  local previous_x = fish.x
  local previous_y = fish.fish_depth
  self:_update_fish_swim(fish, dt, 1.0, 1.15 + item.pull * 1.25)
  fish.depth_signal = 1.0
  fish.signal = clamp(0.55 + item.pull * 0.45, 0, 1)
  self.active_fish = fish
  self:_focus_fish(fish)

  if index ~= self.pattern_index then
    self.pattern_index = index
    if item.name ~= "rest" then
      local event = {
        type = "pattern",
        name = item.name,
        fish_type = fish.type,
        fish = fish,
        pull = item.pull,
        tension = self.tension,
      }
      table.insert(events, event)
      table.insert(self.captured_events, event)
    end
  end

  if self.tension >= self.config.SAFE_TENSION_MIN
      and self.tension <= self.config.SAFE_TENSION_MAX then
    self.capture_progress = clamp(
      self.capture_progress + dt * self.config.CAPTURE_RATE,
      0,
      1
    )
  end

  local ascent_depth = fish.hooked_depth * (1 - self.capture_progress)
  local pull_offset = item.pull * 0.18
  local target = clamp(ascent_depth + pull_offset, 0, 1)
  fish.fish_depth = fish.fish_depth + (target - fish.fish_depth) * 0.18
  fish.motion_x = clamp(math.abs(fish.x - previous_x) / math.max(dt * 0.42, 0.0001), 0, 1)
  fish.motion_y = clamp(math.abs(fish.fish_depth - previous_y) / math.max(dt * 0.18, 0.0001), 0, 1)
  self.fish_depth = fish.fish_depth
  self.tension = clamp(math.abs(fish.fish_depth - self.line_depth) * 2.6, 0, 1)
  self.fight_tension_sum = self.fight_tension_sum + self.tension
  self.fight_tension_samples = self.fight_tension_samples + 1
  self.fight_max_tension = math.max(self.fight_max_tension, self.tension)

  if self.tension < self.config.SLACK_TENSION then
    self.slack_timer = self.slack_timer + dt
  else
    self.slack_timer = math.max(0, self.slack_timer - dt)
  end

  if self.tension > self.config.OVERLOAD_TENSION then
    self.overload_timer = self.overload_timer + dt
  else
    self.overload_timer = math.max(0, self.overload_timer - dt)
  end

  if self.slack_timer >= self.config.SLACK_FAIL_S then
    self:_fail_to_explore(events, "escaped_slack")
    return
  end

  if self.overload_timer >= self.config.OVERLOAD_FAIL_S then
    self.state = "CAST"
    self.last_reason = "line_broken"
    self.hooked_fish = nil
    table.insert(events, { type = "failure", name = "line_broken" })
    return
  end

  if self.capture_progress >= 1 then
    local avg_tension = self.tension
    if self.fight_tension_samples > 0 then
      avg_tension = self.fight_tension_sum / self.fight_tension_samples
    end

    local layer = {
      type = fish.type,
      slot = fish.slot,
      loop_key = string.format("%s:%d", fish.type, fish.id),
      pattern_seed = fish.pattern_seed,
      timbre_seed = fish.timbre_seed,
      event_count = #self.captured_events,
      fight_time = self.fight_time,
      avg_tension = avg_tension,
      max_tension = self.fight_max_tension,
    }

    local layers = self.captured_by_type[fish.type] or {}
    table.insert(layers, layer)
    self.captured_by_type[fish.type] = layers
    self:_rebuild_captured_layers()
    self.state = "SURFACE"
    self.hooked_fish = nil
    self.last_reason = "captured"
    table.insert(events, {
      type = "surface",
      name = "captured",
      fish_type = fish.type,
      slot = fish.slot,
      fish = fish,
      layer = layer,
    })
  end
end

function Game:update(dt)
  local events = self.pending_events
  self.pending_events = {}

  if self.state == "EXPLORE" or self.state == "RESONANCE" then
    self:_update_resonance(dt)
  elseif self.state == "STRUGGLE" then
    self:_update_struggle(dt, events)
  end

  return events
end

return Game
