# Genesis Mini Pin Probe

Use this when a module does not react on the assumed GPIO assignment.

The pin-probe firmware does two things:

- reports all slot 1/2/3 input pin changes over serial;
- pulses a requested slot 2 or slot 3 local IO pin on command.

This identifies:

- encoder A/B pins;
- action button pin and polarity;
- button LED pin and polarity;
- vibration motor pin and polarity.

## Flash Probe Firmware

Reconnect the Genesis Mini to the PC so it appears as `COM20`, then run:

```powershell
cd genesis\abyssal_line_controller
python -m platformio run -e genesis_mini_pin_probe -t upload
```

Do not press the LED button while a slot 2 output pulse is active. A button tied
to ground could stress the pin if that same line is being driven high.

## What To Observe

### Output Pins

Run a slot scan from the repo root:

```powershell
python tools\pin_probe_tool.py --port COM20 --scan slot2 --ms 2500
```

For each `WATCH NOW` line:

- note whether the LED changes;
- note whether the motor vibrates;
- keep the printed `PIN_PROBE_OUTPUT` line.

Then scan the motor slot:

```powershell
python tools\pin_probe_tool.py --port COM20 --scan slot3 --ms 2500
```

### Input Pins

Run:

```powershell
python tools\pin_probe_tool.py --port COM20 --snapshot --duration 20
```

Then:

- rotate the encoder and note which `slot1_*` values change;
- press the button and note which `slot2_*` value changes.

The expected useful lines look like:

```json
{"type":"PIN_PROBE_OUTPUT","payload":{"label":"slot2_io2","gpio":18,"active":true}}
{"type":"PIN_PROBE_INPUT","payload":{"reason":"changed","pins":{"slot1_io1":0}}}
```

## Restore Main Spike Firmware

After the probe:

```powershell
cd genesis\abyssal_line_controller
python -m platformio run -e genesis_mini_m0_serial -t upload
```
