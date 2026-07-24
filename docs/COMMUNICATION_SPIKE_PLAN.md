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

1. Enumeration on development computer.
2. Enumeration on Norns.
3. Genesis to Norns: `HELLO`, encoder delta, button event.
4. Norns to Genesis: `HELLO_ACK`, `GAME_STATE`.
5. Sustained rate: 2 Hz, 10 Hz, 30 Hz.
6. Disconnect and reconnect.
7. Version mismatch handling.

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

