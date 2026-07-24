# Communication Spike Plan

The spike must choose the simplest stable transport. Do not assume USB Serial
or USB MIDI before testing the real hardware.

## Candidate Transports

### USB CDC Serial

Useful if the Genesis Mini exposes a serial port and Norns can read/write it
reliably. Best for line-delimited JSON during development.

### USB MIDI

Useful if the Genesis Mini can expose MIDI and Norns detects it naturally.
Best for encoder/button controls; structured state may need SysEx or compact
packetization.

### Hybrid

Only consider this if a single transport fails a clear requirement.

## Tests

1. Enumeration on development computer. Passed: `COM20`.
2. Enumeration on Norns. Not tested.
3. Genesis to host: `HELLO`. Passed on PC.
4. Host to Genesis: `HELLO_ACK`, `GAME_STATE`, `PATTERN_EVENT`. Passed on PC.
5. Physical inputs: encoder delta and button event. Not verified by Codex.
6. Sustained rate: 2 Hz, 10 Hz, 30 Hz. 5 Hz synthetic PC test passed.
7. Disconnect and reconnect. Not tested.
8. Version mismatch handling. Not tested.

## Decision Criteria

- bidirectional;
- reconnectable;
- stable at 10 Hz;
- low impact on Norns audio;
- easy to log while developing;
- no fragile shell polling;
- deployable on the actual Norns setup.

## Result File

When hardware is available, create:

```text
docs/COMMUNICATION_SPIKE_RESULTS.md
```

Required fields:

- Genesis board/model;
- firmware/toolchain version;
- Norns version;
- cable and power arrangement;
- selected transport;
- rejected transport and reason;
- measured latency;
- reconnect behavior;
- remaining limitations;
- minimal Norns code used;
- minimal Genesis code used.
