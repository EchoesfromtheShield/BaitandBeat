# Communication Spike Results

Status: passed for USB serial transport on development PC and Norns. Physical
module mapping is still partially open.

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

Current observed result:

- Button LED reacted on probe label `slot3_io2` / GPIO5.
- ERM motor has not reacted on the tested pins.

For the M0 firmware, haptics are disabled and the LED button uses the observed
LED-button port. This keeps the communication spike moving while the exact ERM
GPIO remains unresolved.

## Current Limitations

- Physical encoder movement still needs verification on the final M0 firmware.
- Physical LED button input still needs verification; LED output is verified on
  GPIO5.
- Haptic feedback is intentionally disabled in M0 until the ERM GPIO is found.
- Norns-side serial adapter is not committed yet.

## Selected Transport For Next Test

USB serial remains the leading candidate. It is already bidirectional on the
development PC and easy to log.

Do not close M0 until the Norns script also proves:

- read/write line protocol;
- 5 to 10 Hz `GAME_STATE`;
- disconnect/reconnect and resync.
