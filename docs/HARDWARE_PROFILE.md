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

| Axiometa port | Module | M0 role |
| --- | --- | --- |
| P1 | Rotary encoder | Depth/tension encoder |
| P2 | Tactile LED button | Cast/hook button and status LED |
| P3 | Vibration motor ERM | Fishing haptic feedback |

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

The local PlatformIO board definition does not expose the official Axiometa
`P*_IO*` macros, so these values are copied from the Axiometa diagnostic
firmware's runtime `PINMAP_JSON` output.

| Port | IO0/ADC | IO1/CS/PWM/TX | IO2/RX |
| --- | --- | --- | --- |
| P1 | GPIO4 | GPIO3 | GPIO2 |
| P2 | GPIO7 | GPIO6 | GPIO5 |
| P3 | GPIO9 | GPIO16 | GPIO15 |
| P4 | GPIO1 | GPIO17 | GPIO18 |

Shared AX22 bus lines:

| Signal | GPIO |
| --- | --- |
| MOSI | GPIO12 |
| MISO | GPIO13 |
| SCK | GPIO14 |
| SDA | GPIO10 |
| SCL | GPIO11 |

## M0 Pin Assignment

The Axiometa diagnostic firmware produced the following verified runtime pinmap:

```text
P1_IO0_PIN=4
P1_IO1_PIN=3
P1_IO2_PIN=2
P2_IO0_PIN=7
P2_IO1_PIN=6
P2_IO2_PIN=5
P3_IO0_PIN=9
P3_IO1_PIN=16
P3_IO2_PIN=15
P4_IO0_PIN=1
P4_IO1_PIN=17
P4_IO2_PIN=18
LED_HIGH pin=5
MOTOR_HIGH pin=16
ENCODER_BUTTON_PRESS pin=4
```

| Function | Port | Module signal | GPIO |
| --- | --- | --- | --- |
| Encoder A/CLK | P1 | IO1 | GPIO3 |
| Encoder B/DT | P1 | IO2 | GPIO2 |
| Encoder push | P1 | IO0 | GPIO4, unused in M0 |
| Action button | P2 | IO1 | GPIO6 |
| Button LED | P2 | IO2 | GPIO5 |
| Vibration motor | P3 | IO1 | GPIO16 |

The ERM module should use pulses of at least 50 ms. Variable intensity can later
use PWM; M0 only uses simple HIGH/LOW pulses.

## Transport Assumption For First Test

Use USB CDC serial first because the board already enumerates as `COM20`.

The communication spike has proved:

- Norns sees the board as a usable serial device;
- bidirectional JSON lines are stable at 5 to 10 Hz;
- reconnect triggers a clean handshake and state resync.

Open hardware confirmations:

- encoder, LED button, and ERM motor on the final Abyssal Line firmware.
