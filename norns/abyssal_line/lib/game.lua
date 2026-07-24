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

  self.line_depth = clamp(
    self.line_depth + delta * self.config.DEPTH_STEP,
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
    self.fish_depth = self.creature_depth
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
  self.still_timer = 0
  self.bite_ready = false
  self.fight_time = 0
  self.tension = 0
  self.slack_timer = 0
  self.overload_timer = 0
  self.capture_progress = 0
  self.creature_depth = clamp(0.58 + (#self.captured_layers * 0.09), 0.2, 0.86)
  self.fish_depth = self.creature_depth
end

function Game:_update_resonance(dt)
  local distance = math.abs(self.line_depth - self.creature_depth)
  self.signal = clamp(1 - (distance / self.config.RESONANCE_RADIUS), 0, 1)

  if self.signal <= 0 then
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
end

function Game:_update_struggle(dt, events)
  self.fight_time = self.fight_time + dt

  local item, index = pattern_at(self.fight_time)
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

  local pull_offset = item.pull * 0.22
  local target = clamp(self.creature_depth + pull_offset, 0, 1)
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

  if self.tension >= self.config.SAFE_TENSION_MIN
      and self.tension <= self.config.SAFE_TENSION_MAX then
    self.capture_progress = clamp(
      self.capture_progress + dt * self.config.CAPTURE_RATE,
      0,
      1
    )
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
