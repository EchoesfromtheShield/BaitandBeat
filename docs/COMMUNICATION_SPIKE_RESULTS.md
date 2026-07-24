# Communication Spike Results

Status: partially passed on development PC. Norns USB host test is still open.

Date: 2026-07-24

## Hardware

- Board: Axiometa Genesis Mini V1 Rev2
- MCU: ESP32-S3-Mini-N4R2
- Detected chip: ESP32-S3 QFN56, revision v0.2
- Embedded flash: 4MB
- Embedded PSRAM: 2MB
- MAC: d0:cf:13:07:88:e8
- Development PC port: `COM20`
- USB mode reported by esptool: USB-Serial/JTAG

Connected modules:

- slot 1: rotary encoder;
- slot 2: tactile LED button;
- slot 3: vibration motor ERM.

## Firmware

- Path: `genesis/abyssal_line_controller`
- Environment: PlatformIO + Arduino
- Board definition: local `boards/axiometa_genesis_mini.json`
- Transport under test: USB CDC style serial line protocol at 115200 baud
- Upload result: passed on `COM20`

Build result:

- RAM: 19012 bytes used, 5.8%
- Flash: 273737 bytes used, 20.9% of app partition

## PC Round Trip

Host tool:

```powershell
python tools\serial_spike_host.py --port COM20 --duration 10
```

Observed:

- Genesis sends `HELLO`.
- Host sends `HELLO_ACK`.
- Genesis confirms receive with `DEBUG_RX` for `HELLO_ACK`.
- Host sends `GAME_STATE` at 5 Hz.
- Genesis confirms receive with `DEBUG_RX` for `GAME_STATE`.
- Host sends synthetic `RESONANCE`, `bite_ready`, and `STRUGGLE` states.
- Longer test confirmed `PATTERN_EVENT` receive with `DEBUG_RX`.

The firmware sends `DEBUG_RX` during M0 so the bidirectional path is visible in
plain logs. This can be removed or gated once Norns integration is stable.

## Current Limitations

- Physical encoder movement was not verified by Codex because it requires
  someone to turn the knob during the host test.
- Physical LED button press was not verified by Codex for the same reason.
- Haptic feedback cannot be confirmed remotely; the firmware does pulse the
  motor on connection, button press, bite-ready, and pattern events.
- Norns enumeration has not been tested.
- Norns-side serial adapter is not committed yet because the actual device path
  and Norns access mode are unknown.

## Selected Transport For Next Test

USB serial remains the leading candidate. It is already bidirectional on the
development PC and easy to log.

Do not close M0 until Norns also proves:

- device enumeration;
- read/write line protocol;
- 5 to 10 Hz `GAME_STATE`;
- disconnect/reconnect and resync.

