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

The Genesis Mini schematic shows shared SPI/I2C signals plus three local GPIO
lines per AX22 port. The application uses the Axiometa `P*` port names because
they match the working module examples.

| Port | IO0/ADC | IO1/CS/PWM/TX | IO2/RX |
| --- | --- | --- | --- |
| P1 | GPIO9 | GPIO16 | GPIO15 |
| P2 | GPIO7 | GPIO6 | GPIO5 |
| P3 | GPIO1 | GPIO17 | GPIO18 |
| P4 | GPIO4 | GPIO3 | GPIO2 |

Shared AX22 bus lines:

| Signal | GPIO |
| --- | --- |
| MOSI | GPIO12 |
| MISO | GPIO13 |
| SCK | GPIO14 |
| SDA | GPIO10 |
| SCL | GPIO11 |

## M0 Pin Assignment

The first probe session showed the LED button illuminating on GPIO5. The
working Axiometa test firmware identifies that same signal as `P2_IO2`; the old
probe labels were therefore misleading, not the hardware. The same inference
puts the ERM motor's `P3_IO1` on GPIO17.

| Function | Port | Module signal | GPIO |
| --- | --- | --- | --- |
| Encoder A/CLK | P1 | IO1 | GPIO16 |
| Encoder B/DT | P1 | IO2 | GPIO15 |
| Encoder push | P1 | IO0 | GPIO9, unused |
| Action button | P2 | IO1 | GPIO6 |
| Button LED | P2 | IO2 | GPIO5 |
| Vibration motor | P3 | IO1 | GPIO17 |

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
