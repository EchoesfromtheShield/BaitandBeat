# Logical Protocol M0

The logical protocol is transport-independent. The same messages can be carried
over USB CDC serial, USB MIDI SysEx, or another verified transport.

## Envelope

```json
{
  "v_major": 1,
  "v_minor": 0,
  "seq": 1,
  "type": "GAME_STATE",
  "payload": {}
}
```

## Genesis To Norns

### HELLO

```json
{
  "device_role": "genesis",
  "firmware": "unknown",
  "capabilities": ["encoder", "button"]
}
```

### INPUT_ENCODER_DELTA

```json
{
  "delta": 1
}
```

Positive delta lets out line. Negative delta reels in line.

### INPUT_BUTTON

```json
{
  "event": "press"
}
```

In M0/M1, a press casts in `CAST` and hooks when the bite is ready in
`RESONANCE`.

### REQUEST_STATE

Requests a full state snapshot after reconnect.

## Norns To Genesis

### HELLO_ACK

```json
{
  "accepted": true,
  "negotiated_minor": 0,
  "capabilities": ["game_state"]
}
```

### GAME_STATE

```json
{
  "state": "EXPLORE",
  "depth_0_1": 0.42,
  "drone": {
    "root_hz": 68.9,
    "brightness_0_1": 0.58,
    "pressure_0_1": 0.42
  },
  "signal_0_1": 0.0,
  "tension_0_1": 0.0,
  "capture_progress_0_1": 0.0,
  "captured_layers": 0
}
```

### PATTERN_EVENT

Sent when the hooked creature emits a musical/gameplay event.

```json
{
  "event": "small_tug",
  "strength_0_1": 0.32,
  "tension_0_1": 0.44
}
```

### ERROR

Used for invalid payloads, unsupported messages, or version mismatch.

