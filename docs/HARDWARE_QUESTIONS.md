# Hardware Questions Before Genesis Code

The first required facts are now recorded in `docs/HARDWARE_PROFILE.md`.

## Genesis Mini

- Answered: Axiometa Genesis Mini Version 1 Rev 2.
- Answered: ESP32-S3-Mini-N4R2.
- Current implementation path: PlatformIO + Arduino framework.

## Connected Modules

For each connected module:

- module name and model;
- physical port;
- GPIO pins or bus;
- voltage/power notes;
- official library or example, if already known.

Minimum expected modules:

- Answered: rotary encoder in slot 1;
- Answered: tactile LED button in slot 2;
- Answered: vibration motor ERM in slot 3.

OLED and RGB LED matrix are not part of the current M0 wiring.

## USB Access

- Answered: currently appears as `COM20` on the development computer.
- VID/PID and device name, if visible.
- Still open: whether Norns sees it when plugged into the Norns USB host.
- Whether power comes from Norns, a powered hub, or external power.
