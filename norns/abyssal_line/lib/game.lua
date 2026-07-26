local Game = {}
Game.__index = Game

local FISH_TYPES = {
  { type = "square", slot = 1 },
  { type = "circle", slot = 2 },
  { type = "triangle", slot = 3 },
}

local CAPTURE_LIMITS = {
  square = 1,
  circle = 1,
  triangle = 1,
}

local PULL_PATTERN = {
  { name = "rest", duration = 1.10, pull = 0.00, resistance = 0.0 },
  { name = "small_tug", duration = 0.30, pull = 0.52, resistance = 0.45 },
  { name = "rest", duration = 0.85, pull = 0.00, resistance = 0.0 },
  { name = "long_pull", duration = 1.05, pull = 0.86, resistance = 0.86 },
  { name = "rest", duration = 0.95, pull = 0.00, resistance = 0.0 },
  { name = "vibration", duration = 0.22, pull = 0.58, resistance = 0.65 },
  { name = "vibration", duration = 0.22, pull = 0.72, resistance = 0.78 },
  { name = "hard_drag", duration = 0.72, pull = 0.96, resistance = 1.00 },
  { name = "rest", duration = 1.15, pull = 0.00, resistance = 0.0 },
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

local function rand_range(lo, hi)
  return lo + math.random() * (hi - lo)
end

local function distributed_depths()
  local depths = {
    rand_range(0.18, 0.34),
    rand_range(0.50, 0.68),
    rand_range(0.90, 0.97),
  }

  for index = #depths, 2, -1 do
    local swap_index = math.random(1, index)
    depths[index], depths[swap_index] = depths[swap_index], depths[index]
  end

  return depths
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
    hook_x = config.HOOK_X_0_1 or 0.5,
    fish_x = 0.5,
    depth_signal = 0.0,
    overlap_signal = 0.0,
    signal = 0.0,
    still_timer = 0.0,
    bite_ready = false,
    bite_window_timer = 0.0,
    fight_time = 0.0,
    pattern_index = 0,
    tension = 0.0,
    slack_timer = 0.0,
    overload_timer = 0.0,
    surface_timer = 0.0,
    fight_tension_sum = 0.0,
    fight_tension_samples = 0,
    fight_max_tension = 0.0,
    capture_progress = 0.0,
    tension_control = 0.46,
    fish_pull_tension = 0,
    struggle_resistance = 1,
    message = "",
    message_timer = 0,
    captured_by_type = {},
    captured_layers = {},
    captured_events = {},
    pending_events = {},
    pending_replacement_settings = nil,
    generation = 0,
    last_reason = "",
  }

  return setmetatable(self, Game)
end

function Game:_queue(event)
  table.insert(self.pending_events, event)
end

function Game:_set_message(message)
  self.message = message or ""
  self.message_timer = self.config.MESSAGE_HOLD_S or 2.2
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

function Game:captured_slots()
  local slots = {}

  for _, fish_type in ipairs(FISH_TYPES) do
    local layers = self.captured_by_type[fish_type.type] or {}
    table.insert(slots, {
      type = fish_type.type,
      slot = fish_type.slot,
      layer = layers[1],
    })
  end

  return slots
end

function Game:captured_layer(index)
  local fish_type = FISH_TYPES[index]
  if not fish_type then
    return nil
  end

  local layers = self.captured_by_type[fish_type.type] or {}
  return layers[1]
end

function Game:free_captured(index)
  local fish_type = FISH_TYPES[index]
  if not fish_type then
    return false
  end

  local layers = self.captured_by_type[fish_type.type] or {}
  local removed = table.remove(layers, 1)
  self.captured_by_type[fish_type.type] = layers

  if not removed then
    return false
  end

  self:_rebuild_captured_layers()
  self:_queue({
    type = "loop_removed",
    reason = "free",
    fish_type = fish_type.type,
    slot = fish_type.slot,
    loop_key = removed.loop_key,
    layer = removed,
  })
  return true
end

function Game:set_captured_volume(index, volume)
  local layer = self:captured_layer(index)
  if not layer then
    return false
  end

  layer.volume_0_1 = clamp(volume or layer.volume_0_1 or 0.85, 0, 1)
  self:_queue({
    type = "loop_updated",
    loop_key = layer.loop_key,
    layer = layer,
  })
  return true
end

function Game:set_captured_mod(index, x, y)
  local layer = self:captured_layer(index)
  if not layer then
    return false
  end

  layer.mod_x = clamp(x or layer.mod_x or 0.5, 0, 1)
  layer.mod_y = clamp(y or layer.mod_y or 0.5, 0, 1)
  self:_queue({
    type = "loop_updated",
    loop_key = layer.loop_key,
    layer = layer,
  })
  return true
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
  local depths = distributed_depths()
  self.fish = {}

  for index, def in ipairs(FISH_TYPES) do
    table.insert(self.fish, self:_make_fish(def, depths[index]))
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

  if self.state == "STRUGGLE" then
    local resistance = math.max(1, self.struggle_resistance or 1)
    self.tension_control = clamp(
      (self.tension_control or self.tension or 0.46)
        + delta * (self.config.STRUGGLE_TENSION_STEP or 0.045) / resistance,
      0,
      1
    )
    return
  end

  local step = self.config.EXPLORE_DEPTH_STEP or self.config.DEPTH_STEP

  self.line_depth = clamp(self.line_depth + delta * step, 0, 1)
  self.depth = self.line_depth
end

function Game:press()
  if self.state == "CAST" then
    self.message = ""
    self.message_timer = 0
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
      self.pending_replacement_settings = removed and {
        fish_type = fish.type,
        volume_0_1 = removed.volume_0_1,
        mod_x = removed.mod_x,
        mod_y = removed.mod_y,
      } or nil
      self:_rebuild_captured_layers()
      self:_queue({
        type = "loop_removed",
        reason = "replace",
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
    self.bite_window_timer = 0
    self.captured_events = {}
    self.fight_tension_sum = 0
    self.fight_tension_samples = 0
    self.fight_max_tension = 0
    self.capture_progress = 0
    self.tension_control = (self.config.SAFE_TENSION_MIN + self.config.SAFE_TENSION_MAX) * 0.5
    self.fish_pull_tension = 0
    self.struggle_resistance = 1
    self.tension = self.tension_control
    self.last_reason = "hooked"
    self:_focus_fish(fish)
    return
  end

  if self.state == "SURFACE" then
    self:_return_to_cast(self.last_reason)
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
  self.bite_window_timer = 0
  self.fight_time = 0
  self.tension = 0
  self.slack_timer = 0
  self.overload_timer = 0
  self.fight_tension_sum = 0
  self.fight_tension_samples = 0
  self.fight_max_tension = 0
  self.capture_progress = 0
  self.tension_control = 0.46
  self.fish_pull_tension = 0
  self.struggle_resistance = 1
  self.pending_replacement_settings = nil
end

function Game:_return_to_cast(reason)
  self.state = "CAST"
  self.depth = 0
  self.line_depth = 0
  self.fish = {}
  self.active_fish = nil
  self.hooked_fish = nil
  self.signal = 0
  self.depth_signal = 0
  self.overlap_signal = 0
  self.still_timer = 0
  self.bite_ready = false
  self.bite_window_timer = 0
  self.fight_time = 0
  self.tension = 0
  self.slack_timer = 0
  self.overload_timer = 0
  self.surface_timer = 0
  self.capture_progress = 0
  self.tension_control = 0.46
  self.fish_pull_tension = 0
  self.struggle_resistance = 1
  self.pending_replacement_settings = nil
  self.last_reason = reason
end

function Game:_return_to_surface(reason)
  self.state = "SURFACE"
  self.depth = 0
  self.line_depth = 0
  self.fish = {}
  self.active_fish = nil
  self.hooked_fish = nil
  self.signal = 0
  self.depth_signal = 0
  self.overlap_signal = 0
  self.still_timer = 0
  self.bite_ready = false
  self.bite_window_timer = 0
  self.fight_time = 0
  self.tension = 0
  self.slack_timer = 0
  self.overload_timer = 0
  self.surface_timer = self.config.SURFACE_HOLD_S or 0.45
  self.capture_progress = 0
  self.tension_control = 0.46
  self.fish_pull_tension = 0
  self.struggle_resistance = 1
  self.pending_replacement_settings = nil
  self.last_reason = reason
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
    self.bite_window_timer = 0
    self:_focus_fish(nil)
    return
  end

  if self.active_fish ~= best then
    self.still_timer = 0
    self.bite_ready = false
    self.bite_window_timer = 0
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

  local bite_overlap_min = self.config.BITE_OVERLAP_MIN or 0.58
  local bite_ready_now = self.still_timer >= self.config.BITE_HOLD_S
    and best.overlap_signal >= bite_overlap_min

  if bite_ready_now then
    self.bite_window_timer = self.config.BITE_READY_WINDOW_S or 1.15
  else
    self.bite_window_timer = math.max(0, self.bite_window_timer - dt)
  end

  self.bite_ready = self.bite_window_timer > 0
end

function Game:_fail_to_explore(events, reason)
  self:_return_to_cast(reason)
  if reason == "escaped_slack" then
    self:_set_message("Slack line|Fish lost!")
  elseif reason == "line_broken" then
    self:_set_message("Line snapped|Fish lost!")
  else
    self:_set_message("Fish lost!")
  end
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

  local ascent_depth = fish.hooked_depth * (1 - self.capture_progress)
  local pull_offset = item.pull * 0.24
  local target = clamp(ascent_depth + pull_offset, 0, 1)
  fish.fish_depth = fish.fish_depth + (target - fish.fish_depth) * 0.18
  fish.motion_x = clamp(math.abs(fish.x - previous_x) / math.max(dt * 0.42, 0.0001), 0, 1)
  fish.motion_y = clamp(math.abs(fish.fish_depth - previous_y) / math.max(dt * 0.18, 0.0001), 0, 1)
  self.fish_depth = fish.fish_depth
  local pull_target = item.pull * (self.config.STRUGGLE_PULL_TENSION or 0.28)
  self.fish_pull_tension = (self.fish_pull_tension or 0)
    + (pull_target - (self.fish_pull_tension or 0)) * (self.config.STRUGGLE_PULL_SLEW or 0.08)
  local resistance_target = 1 + (item.resistance or 0) * (self.config.STRUGGLE_ENCODER_RESISTANCE or 4.2)
  self.struggle_resistance = (self.struggle_resistance or 1)
    + (resistance_target - (self.struggle_resistance or 1)) * 0.10
  self.tension = clamp(
    (self.tension_control or 0.46)
      + (self.fish_pull_tension or 0),
    0,
    1
  )
  self.fight_tension_sum = self.fight_tension_sum + self.tension
  self.fight_tension_samples = self.fight_tension_samples + 1
  self.fight_max_tension = math.max(self.fight_max_tension, self.tension)

  if self.tension >= self.config.SAFE_TENSION_MIN
      and self.tension <= self.config.SAFE_TENSION_MAX then
    self.capture_progress = clamp(
      self.capture_progress + dt * self.config.CAPTURE_RATE,
      0,
      1
    )
  else
    self.capture_progress = clamp(
      self.capture_progress - dt * (self.config.CAPTURE_DECAY_RATE or 0.045),
      0,
      1
    )
  end

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
    self:_fail_to_explore(events, "line_broken")
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
      volume_0_1 = 0.85,
      mod_x = 0.5,
      mod_y = 0.5,
    }
    local replacement = self.pending_replacement_settings
    if replacement and replacement.fish_type == fish.type then
      layer.volume_0_1 = replacement.volume_0_1 or layer.volume_0_1
      layer.mod_x = replacement.mod_x or layer.mod_x
      layer.mod_y = replacement.mod_y or layer.mod_y
      layer.replaces_same_type = true
    end
    local safe_center = (self.config.SAFE_TENSION_MIN + self.config.SAFE_TENSION_MAX) * 0.5
    local safe_span = (self.config.SAFE_TENSION_MAX - self.config.SAFE_TENSION_MIN) * 0.5
    local final_safe = safe_span > 0 and clamp(1 - math.abs(self.tension - safe_center) / safe_span, 0, 1) or 0
    layer.capture_amp_scale = 0.95 + final_safe * 0.45
    self.pending_replacement_settings = nil

    local layers = self.captured_by_type[fish.type] or {}
    table.insert(layers, layer)
    self.captured_by_type[fish.type] = layers
    self:_rebuild_captured_layers()
    self:_return_to_surface("captured")
    self:_set_message("Fish caught!")
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

  if self.message_timer and self.message_timer > 0 then
    self.message_timer = math.max(0, self.message_timer - dt)
  end

  if self.state == "EXPLORE" or self.state == "RESONANCE" then
    self:_update_resonance(dt)
  elseif self.state == "STRUGGLE" then
    self:_update_struggle(dt, events)
  elseif self.state == "SURFACE" then
    self.surface_timer = math.max(0, self.surface_timer - dt)
    if self.surface_timer <= 0 then
      self:_return_to_cast(self.last_reason)
    end
  end

  return events
end

return Game
