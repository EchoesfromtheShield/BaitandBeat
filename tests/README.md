# Norns Tests

No automated Norns test runner is configured yet. The host simulation remains
useful as a basic state smoke test:

```powershell
python tools\simulate_vertical_slice.py
```

Then install from Maiden/Matron and test locally:

```text
;install https://github.com/EchoesfromtheShield/BaitandBeat
```

Expected behavior:

- `E1` switches pages.
- `K3` casts, hooks, selects, and returns from sub-pages.
- `E3` moves line depth during exploration.
- `E3` pushes the tension bar during `STRUGGLE`.
- Page 2 shows captured crab, fish, and octopus loops with `free / mix / mod`.
- Page 3 edits BPM, root note, and scale.
