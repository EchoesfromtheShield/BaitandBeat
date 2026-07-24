local GenesisSerial = {}
GenesisSerial.__index = GenesisSerial

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function json_bool(value)
  return value and "true" or "false"
end

local function json_number(value)
  return string.format("%.4f", value or 0)
end

local function read_type(line)
  return line:match('"type"%s*:%s*"([^"]+)"')
end

local function read_string_field(line, field)
  return line:match('"' .. field .. '"%s*:%s*"([^"]+)"')
end

local function read_number_field(line, field)
  local raw = line:match('"' .. field .. '"%s*:%s*(-?%d+%.?%d*)')
  return raw and tonumber(raw) or nil
end

local function write_line(handle, line)
  if not handle then
    return false
  end

  handle:write(line)
  handle:write("\n")
  handle:flush()
  return true
end

function GenesisSerial.new(config)
  local self = {
    config = config,
    enabled = config.SERIAL_ENABLED,
    path = config.SERIAL_DEVICE,
    baud = config.SERIAL_BAUD,
    reader = nil,
    writer = nil,
    connected = false,
    seq = 1,
    state_elapsed = 0,
    last_rx_type = nil,
    last_error = nil,
  }

  return setmetatable(self, GenesisSerial)
end

function GenesisSerial:open()
  if not self.enabled then
    self.last_error = "disabled"
    return false
  end

  local probe = io.open(self.path, "r")
  if not probe then
    self.last_error = "missing " .. self.path
    return false
  end
  probe:close()

  os.execute(
    "stty -F "
      .. shell_quote(self.path)
      .. " "
      .. tostring(self.baud)
      .. " raw -echo -icanon min 0 time 0"
  )

  self.reader = io.open(self.path, "r")
  self.writer = io.open(self.path, "w")
  if not self.reader or not self.writer then
    self:close()
    self.last_error = "open failed"
    return false
  end

  self.last_error = nil
  print("abyssal_line: genesis serial open " .. self.path)
  return true
end

function GenesisSerial:close()
  if self.reader then
    self.reader:close()
  end
  if self.writer then
    self.writer:close()
  end
  self.reader = nil
  self.writer = nil
  self.connected = false
end

function GenesisSerial:is_open()
  return self.reader ~= nil and self.writer ~= nil
end

function GenesisSerial:next_seq()
  local seq = self.seq
  self.seq = self.seq + 1
  return seq
end

function GenesisSerial:send_raw(message_type, payload)
  if not self:is_open() then
    return false
  end

  local line = string.format(
    '{"v_major":1,"v_minor":0,"seq":%d,"type":"%s","payload":%s}',
    self:next_seq(),
    message_type,
    payload or "{}"
  )
  return write_line(self.writer, line)
end

function GenesisSerial:send_hello_ack()
  self:send_raw(
    "HELLO_ACK",
    '{"accepted":true,"negotiated_minor":0,"capabilities":["game_state","pattern_event"]}'
  )
end

function GenesisSerial:send_game_state(game, drone)
  local payload = string.format(
    '{"state":"%s","depth_0_1":%s,"drone":{"root_hz":%s,"brightness_0_1":%s,"pressure_0_1":%s},"signal_0_1":%s,"tension_0_1":%s,"capture_progress_0_1":%s,"captured_layers":%d,"bite_ready":%s}',
    game.state,
    json_number(clamp(game.depth, 0, 1)),
    json_number(drone.root_hz),
    json_number(clamp(drone.brightness_0_1, 0, 1)),
    json_number(clamp(drone.pressure_0_1, 0, 1)),
    json_number(clamp(game.signal, 0, 1)),
    json_number(clamp(game.tension, 0, 1)),
    json_number(clamp(game.capture_progress, 0, 1)),
    #game.captured_layers,
    json_bool(game.bite_ready)
  )
  self:send_raw("GAME_STATE", payload)
end

function GenesisSerial:send_pattern_event(event)
  if event.type ~= "pattern" then
    return
  end

  local payload = string.format(
    '{"event":"%s","strength_0_1":%s,"tension_0_1":%s}',
    event.name,
    json_number(clamp(event.pull or 0, 0, 1)),
    json_number(clamp(event.tension or 0, 0, 1))
  )
  self:send_raw("PATTERN_EVENT", payload)
end

function GenesisSerial:handle_line(line, game)
  local message_type = read_type(line)
  if not message_type then
    return false
  end

  self.last_rx_type = message_type

  if message_type == "HELLO" then
    self.connected = true
    self:send_hello_ack()
    return true
  end

  if message_type == "INPUT_BUTTON" then
    if read_string_field(line, "event") == "press" then
      game:press()
      return true
    end
    return false
  end

  if message_type == "INPUT_ENCODER_DELTA" then
    game:encoder(read_number_field(line, "delta") or 0)
    return true
  end

  if message_type == "REQUEST_STATE" then
    return true
  end

  return false
end

function GenesisSerial:poll(game)
  if not self:is_open() then
    return false
  end

  local handled = false
  for _ = 1, self.config.SERIAL_MAX_LINES_PER_TICK do
    local line = self.reader:read("*l")
    if line == nil then
      break
    end
    if #line > 0 and self:handle_line(line, game) then
      handled = true
    end
  end

  return handled
end

function GenesisSerial:tick(dt, game, drone, events)
  if not self:is_open() then
    return
  end

  for _, event in ipairs(events) do
    self:send_pattern_event(event)
  end

  self.state_elapsed = self.state_elapsed + dt
  if self.state_elapsed >= self.config.SERIAL_STATE_INTERVAL_S then
    self.state_elapsed = 0
    self:send_game_state(game, drone)
  end
end

return GenesisSerial
