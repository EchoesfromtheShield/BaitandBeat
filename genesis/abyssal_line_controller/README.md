# Genesis Controller

M0 hardware spike for Axiometa Genesis Mini V1 Rev2.

Connected modules:

- P1: rotary encoder;
- P2: tactile LED button;
- P3: vibration motor ERM.

The separate LED button is the action input. The encoder press is unused in M0.

## Build

```powershell
cd genesis\abyssal_line_controller
python -m platformio run
```

## Upload To Current PC Port

```powershell
cd genesis\abyssal_line_controller
python -m platformio run -t upload
```

`platformio.ini` currently targets `COM20`.

## Host Serial Test

After uploading, run from the repo root:

```powershell
python tools\serial_spike_host.py --port COM20
```

Expected behavior:

- Genesis sends repeated `HELLO` until `HELLO_ACK`.
- Turning the encoder sends `INPUT_ENCODER_DELTA`.
- Pressing the LED button sends `INPUT_BUTTON`.
- The LED button blinks during resonance, lights in safe tension, and stays on
  at surface.
- The vibration motor pulses on encoder movement, connect, bite-ready, button
  press, and pattern events.

The Genesis side still does not own authoritative game state.

## Pin Probe

If encoder, LED button, or vibration motor do not react, flash the probe env:

```powershell
cd genesis\abyssal_line_controller
python -m platformio run -e genesis_mini_pin_probe -t upload
```

Then follow [docs/PIN_PROBE.md](../../docs/PIN_PROBE.md).
