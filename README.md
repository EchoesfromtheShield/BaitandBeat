# Bait & Beat

A minimal sonic fishing game for Norns by Echoes from the Shield.

Drop a line into a pixel sea, find resonant fish, fight them with the tension
bar, and turn each catch into a clocked musical loop. Drums, arpeggiators, and
harmony arcs can be caught, mixed, modulated, freed, and replaced during play.

## Norns Install

From Maiden/Matron:

```text
;install https://github.com/EchoesfromtheShield/BaitandBeat
```

The script entrypoint is:

```text
bait_and_beat.lua
```

It loads the custom SuperCollider engine:

```text
lib/Engine_BaitAndBeat.sc
```

On Norns, the script should appear as `Bait & Beat` with built-in script
information and control notes.

## Controls

Norns controls:

- `E1`: change page.
- `K3`: cast, hook, select, or back.
- `E3`: line depth in exploration; tension control in struggle.
- Page 2: caught fish, `free / mix / mod`.
- Page 3: BPM, root note, and scale.

The music settings page includes:

- BPM
- root note
- Harmonic Minor, Major, Natural Minor, Pentatonic Major, Pentatonic Minor,
  Dorian, Phrygian, Lydian, Mixolydian, Locrian, Harmonic Major, Diminished,
  Whole Tone, Hungarian Major, Hungarian Minor, Arabic, Hirajoshi, Egyptian,
  Blues

## Gameplay

Each cast creates three fish at different depths:

- crab: percussive kick/snare/rim loop;
- fish: bright square-wave arpeggiator;
- octopus: slow harmony arcs.

Only one loop per fish type is kept. Catching a new fish of the same type fades
the previous loop out; if the new fight is lost, the old loop remains gone.

## Repository

```text
bait_and_beat.lua             Norns script entrypoint
lib/                          Lua modules and SC engine
docs/                         Design notes
tests/                        Manual Norns test notes
tools/                        Host-side simulator
```
