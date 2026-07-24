local Game = {}
Game.__index = Game

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function struggle_gain(config, tension)
  local safe_mid = (config.SAFE_TENSION_MIN + config.SAFE_TENSION_MAX) * 0.5
  local span = math.max(safe_mid - config.SLACK_TENSION, config.OVERLOAD_TENSION - safe_mid)
  local edge_distance = clamp(math.abs(tension - safe_mid) / span, 0, 1)
  local center_weight = 1 - edge_distance
  local edge_gain = config.STRUGGLE_EDGE_GAIN or 0.28
  return edge_gain + (1 - edge_gain) * center_weight * center_weight
end

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

function Game.new(config)
  local self = {
    config = config,
    state = "CAST",
    depth = 0.0,
    line_depth = 0.0,
    creature_depth = config.CREATURE_DEPTH,
    fish_depth = config.CREATURE_DEPTH,
    hooked_depth = config.CREATURE_DEPTH,
    hook_x = 0.5,
    fish_x = 0.5,
    fish_target_x = 0.72,
    fish_turn_timer = 0.4,
    fish_burst_timer = 0.0,
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
    capture_progress = 0.0,
    captured_layers = {},
    captured_events = {},
    last_reason = "",
  }

  return setmetatable(self, Game)
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

  self.line_depth = clamp(
    self.line_depth + delta * step,
    0,
    1
  )
  self.depth = self.line_depth
end

function Game:press()
  if self.state == "CAST" then
    self.state = "EXPLORE"
    self.last_reason = "cast"
    return
  end

  if self.state == "RESONANCE" and self.bite_ready then
    self.state = "STRUGGLE"
    self.fight_time = 0
    self.pattern_index = 0
    self.hooked_depth = self.creature_depth
    self.fish_depth = self.creature_depth
    self.fish_target_x = self.fish_x < self.hook_x and 0.74 or 0.26
    self.fish_turn_timer = 0.15
    self.fish_burst_timer = 0
    self.bite_ready = false
    self.captured_events = {}
    self.last_reason = "hooked"
    return
  end

  if self.state == "SURFACE" then
    self:reset_to_explore()
  end
end

function Game:reset_to_explore()
  self.state = "EXPLORE"
  self.signal = 0
  self.depth_signal = 0
  self.overlap_signal = 0
  self.still_timer = 0
  self.bite_ready = false
  self.fight_time = 0
  self.tension = 0
  self.slack_timer = 0
  self.overload_timer = 0
  self.capture_progress = 0
  self.creature_depth = clamp(0.58 + (#self.captured_layers * 0.09), 0.2, 0.86)
  self.hooked_depth = self.creature_depth
  self.fish_depth = self.creature_depth
  self.fish_x = 0.5
  self.fish_target_x = #self.captured_layers % 2 == 0 and 0.76 or 0.24
  self.fish_turn_timer = 0.35
  self.fish_burst_timer = 0
end

function Game:_update_fish_swim(dt, depth_signal, speed_scale)
  local base_speed = self.config.CREATURE_SWIM_SPEED or 0.17
  local scale = speed_scale or 1.0
  self.fish_turn_timer = self.fish_turn_timer - dt
  self.fish_burst_timer = math.max(0, self.fish_burst_timer - dt)

  if self.fish_turn_timer <= 0 then
    local side_target = self.fish_x < self.hook_x and 1 or -1
    local far = 0.23 + math.random() * 0.18
    local near = 0.05 + math.random() * 0.12
    local offset = math.random() < 0.65 and far or near
    self.fish_target_x = clamp(self.hook_x + side_target * offset, 0.08, 0.92)
    self.fish_turn_timer = 1.0 + math.random() * 2.2

    if math.random() < (self.config.CREATURE_SWIM_BURST_CHANCE or 0.34) then
      self.fish_burst_timer = 0.25 + math.random() * 0.55
    end
  end

  local burst = self.fish_burst_timer > 0 and 2.8 or 1.0
  local speed = base_speed * scale * (0.75 + depth_signal * 0.55) * burst
  local dx = self.fish_target_x - self.fish_x
  local max_step = speed * dt

  if math.abs(dx) <= max_step then
    self.fish_x = self.fish_target_x
  elseif dx > 0 then
    self.fish_x = self.fish_x + max_step
  else
    self.fish_x = self.fish_x - max_step
  end

  self.overlap_signal = clamp(
    1 - (math.abs(self.fish_x - self.hook_x) / (self.config.HOOK_OVERLAP_RADIUS or 0.105)),
    0,
    1
  )
end

function Game:_update_resonance(dt)
  local distance = math.abs(self.line_depth - self.creature_depth)
  self.depth_signal = clamp(1 - (distance / self.config.RESONANCE_RADIUS), 0, 1)
  self:_update_fish_swim(dt, self.depth_signal)
  self.signal = self.depth_signal * (0.45 + self.overlap_signal * 0.55)

  if self.depth_signal <= 0 then
    self.state = "EXPLORE"
    self.still_timer = 0
    self.bite_ready = false
    return
  end

  if self.state == "EXPLORE" then
    self.state = "RESONANCE"
  end

  if distance <= self.config.BITE_RADIUS then
    self.still_timer = self.still_timer + dt
  else
    self.still_timer = math.max(0, self.still_timer - dt * 2)
  end

  self.bite_ready = self.still_timer >= self.config.BITE_HOLD_S
    and self.overlap_signal >= 0.72
end

function Game:_update_struggle(dt, events)
  self.fight_time = self.fight_time + dt

  local item, index = pattern_at(self.fight_time)
  self:_update_fish_swim(dt, 1.0, 1.15 + item.pull * 1.25)
  self.depth_signal = 1.0
  self.signal = clamp(0.55 + item.pull * 0.45, 0, 1)

  if index ~= self.pattern_index then
    self.pattern_index = index
    if item.name ~= "rest" then
      local event = {
        type = "pattern",
        name = item.name,
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

  local ascent_depth = self.hooked_depth * (1 - self.capture_progress)
  local pull_offset = item.pull * 0.18
  local target = clamp(ascent_depth + pull_offset, 0, 1)
  self.fish_depth = self.fish_depth + (target - self.fish_depth) * 0.18
  self.tension = clamp(math.abs(self.fish_depth - self.line_depth) * 2.6, 0, 1)

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
    self.last_reason = "escaped_slack"
    self:reset_to_explore()
    table.insert(events, { type = "failure", name = "escaped_slack" })
    return
  end

  if self.overload_timer >= self.config.OVERLOAD_FAIL_S then
    self.state = "CAST"
    self.last_reason = "line_broken"
    table.insert(events, { type = "failure", name = "line_broken" })
    return
  end

  if self.capture_progress >= 1 then
    table.insert(self.captured_layers, {
      event_count = #self.captured_events,
      fight_time = self.fight_time,
    })
    self.state = "SURFACE"
    self.last_reason = "captured"
    table.insert(events, { type = "surface", name = "captured" })
  end
end

function Game:update(dt)
  local events = {}

  if self.state == "EXPLORE" or self.state == "RESONANCE" then
    self:_update_resonance(dt)
  elseif self.state == "STRUGGLE" then
    self:_update_struggle(dt, events)
  end

  return events
end

return Game
