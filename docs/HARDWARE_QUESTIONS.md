# Hardware Questions Before Genesis Code

Only these facts are required before writing Genesis hardware code.

## Genesis Mini

- Exact product name and revision.
- MCU model, if known.
- Firmware environment expected: Arduino, PlatformIO, CircuitPython, or other.

## Connected Modules

For each connected module:

- module name and model;
- physical port;
- GPIO pins or bus;
- voltage/power notes;
- official library or example, if already known.

Minimum expected modules:

- rotary encoder with push;
- OLED display;
- RGB LED matrix.

## USB Access

- How the device appears on the development computer: COM port, USB MIDI
  endpoint, HID, or other.
- VID/PID and device name, if visible.
- Whether Norns sees it when plugged into the Norns USB host.
- Whether power comes from Norns, a powered hub, or external power.

