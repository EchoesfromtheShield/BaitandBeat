# Norns Tests

No automated Norns test runner is configured yet. The host simulation remains
useful as a basic state/transport smoke test:

```powershell
python tools\simulate_vertical_slice.py
```

Then copy or sync `norns/abyssal_line` to Norns and test locally with `K3` and
`E3`.

## Genesis Serial Smoke Test

With the Genesis M0 firmware uploaded and plugged into Norns:

```sh
ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

Expected device:

```text
/dev/ttyACM0
```

Launch `ABYSSAL LINE` on Norns. The top-right display should show `G io` when
the port opens and `G ok` after the Genesis `HELLO` handshake.

Expected behavior:

- Genesis button sends cast/hook input.
- Genesis encoder changes line depth after casting.
- Genesis LED follows `RESONANCE`, `STRUGGLE`, and `SURFACE` state feedback.
- Genesis motor pulses only when a bite becomes ready and when a capture
  reaches `SURFACE`.

Fallback controls remain active:

- `K3`: cast/hook/reset.
- `E3`: line depth.
