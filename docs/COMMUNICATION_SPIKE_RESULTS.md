# Communication Spike Results

Status: passed for USB serial transport on development PC and Norns. Physical
module mapping is now known for the M0 modules and needs one final test on the
Abyssal Line firmware.

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
- Norns port: `/dev/ttyACM0`

Connected modules:

- P1: rotary encoder;
- P2: tactile LED button;
- P3: vibration motor ERM.

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

## Norns Round Trip

Norns detected the Genesis Mini as:

```text
/dev/ttyACM0
```

Kernel log:

```text
idVendor=303a, idProduct=1001
Product: USB JTAG/serial debug unit
Manufacturer: Espressif
ttyACM0: USB ACM device
```

Manual JSON-line test confirmed:

- Genesis sends `HELLO`;
- Norns can write `HELLO_ACK`;
- Genesis replies with `DEBUG_RX` for `HELLO_ACK`;
- Norns can write `GAME_STATE`;
- Genesis replies with `DEBUG_RX` for `GAME_STATE`.

Repeated `HELLO` messages after a single test `GAME_STATE` are expected because
the firmware returns to discovery when it does not receive a live state stream.

## Physical Module Probe

Observed result:

- Button LED reacted on GPIO5.
- A separate Axiometa-generated firmware confirmed:
  - encoder on `P1_IO1` / `P1_IO2`;
  - LED button signal on `P2_IO1`;
  - LED control on `P2_IO2`;
  - ERM motor on `P3_IO1`.

The old `slotN_ioX` probe labels were misleading because they did not match the
Axiometa physical port labels. The firmware now uses explicit `P1` / `P2` /
`P3` assignments.

Follow-up on the first corrected firmware test:

- `INPUT_BUTTON` press/release appeared in the serial log, so the button path is
  executing.
- The ERM did not vibrate with `P3_IO1` mapped to GPIO3.
- The ERM did not vibrate with `P3_IO1` mapped to GPIO17.
- Axiometa diagnostic output showed `MOTOR_HIGH pin=16`, `LED_HIGH pin=5`, and
  `ENCODER_BUTTON_PRESS pin=4`.
- M0 now uses `VIBRATION_MOTOR_PIN = 16` and prints `HAPTIC_PULSE` whenever it
  tries to drive the motor.
- The old provisional encoder pin also used GPIO16, so encoder polling is
  temporarily disabled in M0 until the numeric `P1_IO1` / `P1_IO2` values are
  captured from Axiometa.

## Current Limitations

- LED button and ERM motor need one verification pass on the corrected M0
  firmware.
- Encoder CLK/DT numeric pins are still pending from Axiometa `PINMAP_BEGIN`.
- Norns-side serial adapter is not committed yet.

## Selected Transport For Next Test

USB serial remains the leading candidate. It is already bidirectional on the
development PC and easy to log.

Do not close M0 until the Norns script also proves:

- read/write line protocol;
- 5 to 10 Hz `GAME_STATE`;
- disconnect/reconnect and resync.
