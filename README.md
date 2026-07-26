# Bait & Beat

Minimal sonic fishing game for Norns plus Genesis Mini.

This repo intentionally replaces the previous PELAGOS direction. The old
documents in `sources/` are preserved as read-only reference material only.
The active concept is:

> The line finds resonance. The creature shapes the pattern. The player shapes
> the tension between them.

## Current Scope

Implement only the communication spike and a minimal vertical slice:

- `CAST`: cast the line into the sea.
- `EXPLORE`: the encoder moves the line down, up, or leaves it still.
- `RESONANCE`: one of three hidden fish adds resonance when it crosses the hook.
- `STRUGGLE`: the hooked fish role drives a quantized musical pattern.
- `SURFACE`: the captured fish becomes a persistent loop for its role.

No species system, inventory, resources, economy, complex menus, persistence,
mutation tree, or multi-page Genesis UI.

## Repo Shape

```text
docs/                         Active design and milestone docs
protocol/                     Transport-independent logical protocol
protocol/fixtures/            Example messages for M0 spike testing
norns/abyssal_line/           Norns script, Lua modules, and custom SC engine
genesis/abyssal_line_controller/
                              Hardware-dependent implementation placeholder
tools/                        Host-side simulators and utilities
sources/                      Read-only imported PELAGOS reference docs
```

## Run The Host Simulation

The host-side simulation is a lightweight state/transport sanity check. The
current clocked three-fish musical behavior lives in the Norns Lua script and
custom SuperCollider engine.

```powershell
python tools\simulate_vertical_slice.py
```

The script prints compact JSON snapshots when important events happen and at a
low diagnostic rate.

## Norns Local Test Path

The Norns folder contains a first script skeleton:

```text
norns/abyssal_line/abyssal_line.lua
```

The script now loads the custom `AbyssalLine` SuperCollider engine from
`norns/abyssal_line/lib/Engine_AbyssalLine.sc`.

The local Norns controls are active when Genesis is not connected or stops
responding:

- `K3`: cast or hook when the bite is ready.
- `E3`: move the line depth; in `STRUGGLE`, push the tension bar left/right.

Genesis hardware code exists for the M0 communication spike. USB serial has
been verified on the PC and on Norns; the corrected firmware uses Axiometa
ports P1/P2/P3 for encoder, LED button, and ERM motor.

When Genesis is connected to the Norns USB host it should appear as
`/dev/ttyACM0`. The script opens that port at 115200 baud, receives Genesis
encoder/button input, and streams authoritative `GAME_STATE` and
`PATTERN_EVENT` messages back to Genesis. The current Norns UI is intentionally
minimal and does not show serial status on the main page. After a Genesis
handshake, Genesis owns input and the local Norns fallback controls are ignored.

The active musical slice uses the Norns clock at 90 BPM. Each cast creates
three seeded fish at different depths:

- square: percussive kick/snare/rim loop;
- circle: bright square-wave arpeggiator with seeded 1/8, 1/16, or 1/32
  subdivision;
- triangle: slow harmony arcs.

Captured loop limits are intentionally small:

- square: one percussive loop;
- circle: one arpeggiator loop;
- triangle: one harmony-arc loop.

Hooking a new fish of a full type removes that type's oldest loop immediately;
if the new fight is lost, the removed loop is still gone.

Each fish has two seeds:

- `pattern_seed`: phrase structure, subdivisions, arpeggio direction, and
  harmonic interval choices;
- `timbre_seed`: a stable voice family plus smaller color variations for that
  fish.

The current SuperCollider engine uses a curated SCLOrk-inspired voice palette
instead of loading the full SCLOrkSynths quark on Norns.

## Genesis M0 Hardware Spike

Current known setup:

- Genesis Mini V1 Rev2, ESP32-S3-Mini-N4R2;
- P1 rotary encoder;
- P2 tactile LED button;
- P3 vibration motor ERM;
- PC serial port `COM20`.

Build the first firmware spike:

```powershell
cd genesis\abyssal_line_controller
python -m platformio run
```

Then upload and run the host test:

```powershell
python -m platformio run -t upload
cd ..\..
python tools\serial_spike_host.py --port COM20
```

Norns sees the Genesis Mini as `/dev/ttyACM0`. The Norns-side serial adapter
streams authoritative `GAME_STATE` messages from the vertical slice.

Genesis motor haptics are intentionally sparse: vibration is used only for
bite-ready and successful capture.
