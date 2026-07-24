# Reduced Milestones

## M0 - Communication Proof

Goal: prove one stable bidirectional path between Genesis Mini and Norns.

Required:

- enumerate the Genesis device on the development computer;
- enumerate it from Norns;
- exchange `HELLO` and `HELLO_ACK`;
- send encoder delta and button events from Genesis to Norns;
- send compact `GAME_STATE` from Norns to Genesis at 5 to 10 Hz;
- unplug and reconnect, then resync;
- document the selected transport.

Exit gate: `docs/COMMUNICATION_SPIKE_RESULTS.md` contains measured results and
the selected transport.

## M1 - Local Norns Vertical Slice

Goal: make the game loop work on Norns without Genesis hardware.

Required:

- `CAST`, `EXPLORE`, `RESONANCE`, `STRUGGLE`, `SURFACE`;
- local controls using Norns keys/encoders;
- depth-driven continuous drone;
- resonance near one hidden creature;
- bite after stillness in the bite zone;
- tension, slack, overload, capture progress;
- one captured persistent audio layer.

Exit gate: the loop is playable with only Norns controls.

## M2 - Genesis As Peripheral

Goal: replace local Norns controls with Genesis input.

Required:

- encoder delta controls depth and tension;
- button casts and hooks;
- Genesis OLED shows depth, signal, tension, and state;
- Genesis LED matrix shows resonance or tension;
- Norns remains authoritative after reconnect.

Exit gate: a full capture can be completed using Genesis only.

## M3 - Musical Feel Pass

Goal: decide whether the core gesture is worth keeping.

Required:

- drone depth mapping is expressive enough to explore;
- creature pull events are audible as a pattern;
- tension changes the pattern clearly;
- captured layer remains musically useful;
- no additional game systems added.

Exit gate: record a short session and decide whether to continue or redesign.
