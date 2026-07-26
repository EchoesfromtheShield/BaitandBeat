# Genesis Mini Pin Probe

Use this when a module does not react on the assumed GPIO assignment.

The pin-probe firmware does two things:

- reports all P1/P2/P3/P4 input pin changes over serial;
- pulses a requested P2, P3, or P4 local IO pin on command.

This identifies:

- encoder A/B pins;
- action button pin and polarity;
- button LED pin and polarity;
- vibration motor pin and polarity.

## Flash Probe Firmware

Reconnect the Genesis Mini to the PC so it appears as `COM20`, then run:

```powershell
cd genesis\bait_and_beat_controller
python -m platformio run -e genesis_mini_pin_probe -t upload
```

Do not press the LED button while a P2 output pulse is active. A button tied
to ground could stress the pin if that same line is being driven high.

## What To Observe

### Output Pins

Run a slot scan from the repo root:

```powershell
python tools\pin_probe_tool.py --port COM20 --scan p2 --ms 2500
```

For each `WATCH NOW` line:

- note whether the LED changes;
- note whether the motor vibrates;
- keep the printed `PIN_PROBE_OUTPUT` line.

Then scan the motor slot:

```powershell
python tools\pin_probe_tool.py --port COM20 --scan p3 --ms 2500
```

If P3 does not vibrate, scan P4. On the current hardware, the application should
not need this because the Axiometa test firmware has confirmed the ERM on
`P3_IO1`.

```powershell
python tools\pin_probe_tool.py --port COM20 --scan p4 --ms 2500
```

Current known observation:

- GPIO5 illuminates the tactile button LED; in Axiometa naming this is
  `P2_IO2`.
- The ERM motor is confirmed by the Axiometa test firmware on `P3_IO1`.

When probing the ERM again, use 2500 ms pulses; ERM pulses shorter than roughly
50 ms can be imperceptible.

### Input Pins

Run:

```powershell
python tools\pin_probe_tool.py --port COM20 --snapshot --duration 20
```

Then:

- rotate only the encoder first and use the `INPUT CHANGE SUMMARY`;
- run the command again, press only the button, and use the summary.

The expected useful lines look like:

```json
{"type":"PIN_PROBE_OUTPUT","payload":{"label":"p2_io2","gpio":5,"active":true}}
{"type":"PIN_PROBE_INPUT","payload":{"reason":"changed","pins":{"p1_io1":0}}}
```

## Restore Main Spike Firmware

After the probe:

```powershell
cd genesis\bait_and_beat_controller
python -m platformio run -e genesis_mini_m0_serial -t upload
```
