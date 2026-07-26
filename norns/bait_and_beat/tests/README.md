# Norns Tests

No automated Norns test runner is configured yet. The host simulation remains
useful as a basic state smoke test:

```powershell
python tools\simulate_vertical_slice.py
```

Then copy or sync `norns/bait_and_beat` to Norns and test locally.

Expected behavior:

- `E1` switches pages.
- `K3` casts, hooks, selects, and returns from sub-pages.
- `E3` moves line depth during exploration.
- `E3` pushes the tension bar during `STRUGGLE`.
- Page 2 shows captured crab, fish, and octopus loops with `free / mix / mod`.
- Page 3 edits BPM, root note, and scale.
