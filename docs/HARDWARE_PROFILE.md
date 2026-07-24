# Hardware Profile - Genesis Mini V1 Rev 2

## Board

- Product: Axiometa Genesis Mini
- Version: 1
- Revision: 2
- MCU module: ESP32-S3-Mini-N4R2
- Development path for M0: PlatformIO + Arduino framework
- Current USB serial port on development PC: `COM20`
- Norns USB host test: not run yet

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

| Function | Slot | Module signal | GPIO |
| --- | --- | --- | --- |
| Encoder A/CLK | 1 | IO1 | GPIO16 |
| Encoder B/DT | 1 | IO2 | GPIO15 |
| Encoder push | 1 | IO0 | GPIO9, unused |
| Action button | 2 | IO1 | GPIO17 |
| Button LED | 2 | IO2 | GPIO18 |
| Vibration motor | 3 | IO1 | GPIO6 |

The button and vibration assignments follow the public module examples and
schematics. If the first upload proves a signal is on IO0 or IO2 instead, only
`genesis/abyssal_line_controller/include/HardwareConfig.h` should change.

## Transport Assumption For First Test

Use USB CDC serial first because the board already enumerates as `COM20`.

The communication spike still needs to prove:

- Norns sees the board as a usable serial device;
- bidirectional JSON lines are stable at 5 to 10 Hz;
- reconnect triggers a clean handshake and state resync.

