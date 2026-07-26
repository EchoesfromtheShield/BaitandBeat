# Norns Tests

No automated Norns test runner is configured yet. The host simulation remains
useful as a basic state/transport smoke test:

```powershell
python tools\simulate_vertical_slice.py
```

Then copy or sync `norns/abyssal_line` to Norns and test locally with `K3` and
`E3` while Genesis is disconnected.

## Genesis Serial Smoke Test

With the Genesis M0 firmware uploaded and plugged into Norns:

```sh
ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

Expected device:

```text
/dev/ttyACM0
```

Launch `Bait & Beat` on Norns. The current minimal Norns UI does not show
serial status on the main page, so confirm Genesis connection from behavior or
logs rather than an on-screen `G ok` indicator.

Expected behavior:

- Genesis button sends cast/hook input.
- Genesis encoder changes line depth after casting and pushes the tension bar
  during `STRUGGLE`.
- Genesis LED follows `RESONANCE`, `STRUGGLE`, and `SURFACE` state feedback.
- Genesis motor pulses only when a bite becomes ready and when a capture
  reaches `SURFACE`.

Fallback controls are active when Genesis is not connected or has not
completed the handshake:

- `K3`: cast/hook/reset.
- `E3`: line depth; in `STRUGGLE`, tension bar left/right.
