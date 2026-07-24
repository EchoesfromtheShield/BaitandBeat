# Hardware Profile - Genesis Mini V1 Rev 2

## Board

- Product: Axiometa Genesis Mini
- Version: 1
- Revision: 2
- MCU module: ESP32-S3-Mini-N4R2
- Development path for M0: PlatformIO + Arduino framework
- Current USB serial port on development PC: `COM20`
- Norns USB host test: passed as `/dev/ttyACM0`

Official references checked:

- Axiometa Genesis Mini product page and schematic
- Axiometa Rotary Encoder module page and schematic
- Axiometa Tactile LED Button module page and schematic
- Axiometa Vibration Motor ERM module page and schematic

## Connected Modules

| Physical slot | Module | M0 role |
| --- | --- | --- |
| Slot 1 | Rotary encoder | Depth/tension encoder |
| Slot 2 | Tactile LED button | Cast/hook button and status LED |
| Slot 3 | Vibration motor ERM | Fishing haptic feedback |

The separate LED button is the M0 action button. The encoder press is not used.

## Module Signal Reference

Current Axiometa module reference:

| Module | Signal | Meaning |
| --- | --- | --- |
| AX22-0003 rotary encoder | P1_IO0 | Button, HIGH = pressed |
| AX22-0003 rotary encoder | P1_IO1 | CLK |
| AX22-0003 rotary encoder | P1_IO2 | DT |
| AX22-0050 tactile LED button | P2_IO1 | Button, LOW = pressed |
| AX22-0050 tactile LED button | P2_IO2 | LED, HIGH = on |
| AX22-0013 ERM motor | P3_IO1 | Motor, HIGH = run, PWM capable |

## AX22 Port GPIO Map

The Genesis Mini schematic shows shared SPI/I2C signals plus three slot-local
GPIO lines per AX22 port.

| Port | IO0/ADC | IO1/CS/PWM/TX | IO2/RX |
| --- | --- | --- | --- |
| 1 | GPIO9 | GPIO16 | GPIO15 |
| 2 | GPIO1 | GPIO17 | GPIO18 |
| 3 | GPIO7 | GPIO6 | GPIO5 |
| 4 | GPIO4 | GPIO3 | GPIO2 |

Shared AX22 bus lines:

| Signal | GPIO |
| --- | --- |
| MOSI | GPIO12 |
| MISO | GPIO13 |
| SCK | GPIO14 |
| SDA | GPIO10 |
| SCL | GPIO11 |

## M0 Pin Assignment

The first probe session showed the LED button illuminating on the firmware label
`slot3_io2` / GPIO5, not on the initial `slot2_io2` assumption. Until the full
physical-port-to-GPIO map is verified, M0 uses the observed LED button mapping
and keeps the ERM motor disabled.

| Function | Slot | Module signal | GPIO |
| --- | --- | --- | --- |
| Encoder A/CLK | 1 | IO1 | GPIO16 |
| Encoder B/DT | 1 | IO2 | GPIO15 |
| Encoder push | 1 | IO0 | GPIO9, unused |
| Action button | observed LED-button port | IO1 | GPIO6, pending confirmation |
| Button LED | observed LED-button port | IO2 | GPIO5, verified |
| Vibration motor | pending | IO1 | disabled in M0 |

The ERM module should use pulses of at least 50 ms once its GPIO is known.
Variable intensity can later use PWM; do not add it to M0 before basic
serial/encoder/button/LED behavior is stable.

## Transport Assumption For First Test

Use USB CDC serial first because the board already enumerates as `COM20`.

The communication spike has proved:

- Norns sees the board as a usable serial device;
- bidirectional JSON lines are stable at 5 to 10 Hz;
- reconnect triggers a clean handshake and state resync.

Open hardware confirmations:

- encoder A/B movement on the final M0 firmware;
- action button input on GPIO6;
- ERM motor GPIO.
