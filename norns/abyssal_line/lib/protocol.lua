local Protocol = {}

Protocol.V_MAJOR = 1
Protocol.V_MINOR = 0

function Protocol.envelope(seq, message_type, payload)
  return {
    v_major = Protocol.V_MAJOR,
    v_minor = Protocol.V_MINOR,
    seq = seq,
    type = message_type,
    payload = payload or {},
  }
end

function Protocol.game_state(seq, game, drone)
  return Protocol.envelope(seq, "GAME_STATE", {
    state = game.state,
    depth_0_1 = game.depth,
    drone = drone,
    signal_0_1 = game.signal,
    tension_0_1 = game.tension,
    capture_progress_0_1 = game.capture_progress,
    captured_layers = #game.captured_layers,
    bite_ready = game.bite_ready,
  })
end

function Protocol.handle_input(game, message)
  if message.type == "INPUT_ENCODER_DELTA" then
    game:encoder(message.payload.delta or 0)
    return true, nil
  end

  if message.type == "INPUT_BUTTON" then
    if message.payload.event == "press" then
      game:press()
      return true, nil
    end
    return false, "INVALID_BUTTON_EVENT"
  end

  return false, "UNSUPPORTED_MESSAGE"
end

return Protocol

