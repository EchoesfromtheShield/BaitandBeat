# Genesis Mini Pin Probe

Use this when a module does not react on the assumed GPIO assignment.

The pin-probe firmware does two things:

- reports all slot 1/2/3 input pin changes over serial;
- briefly drives each slot 2 and slot 3 local IO pin high, one at a time.

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
cd ..\..
python tools\serial_spike_host.py --port COM20 --listen-only --duration 30
```

Do not press the LED button while the output scan is running. The scan drives
candidate output pins briefly; pressing a button tied to ground during that
short pulse could stress the pin.

## What To Observe

While the probe runs:

- note which `PIN_PROBE_OUTPUT` line is printed when the LED turns on;
- note which `PIN_PROBE_OUTPUT` line is printed when the motor vibrates;
- rotate the encoder and note which `slot1_*` values change;
- when the output scan is stopped, press the button and note which `slot2_*`
  value changes.

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
