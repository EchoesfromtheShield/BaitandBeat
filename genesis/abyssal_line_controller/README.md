# Genesis Controller

Hardware code intentionally starts after M0 enumeration and pin discovery.

The Genesis side should eventually own only:

- encoder/button reading;
- minimal OLED status;
- LED matrix resonance or tension display;
- transport adapter;
- reconnection handshake.

It must not own:

- authoritative game state;
- creature movement;
- tension rules;
- captured layer state;
- musical decisions.

Before adding `.ino`, `HardwareConfig.h`, or library dependencies, fill in the
facts listed in:

```text
docs/HARDWARE_QUESTIONS.md
```

