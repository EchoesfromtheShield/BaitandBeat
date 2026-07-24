# ABYSSAL LINE - New Core Concept

## One Sentence

A minimal sonic fishing game where a line explores depth, a drone changes with
the water column, and hooked creatures generate musical patterns through their
own struggle.

## Active Principles

- Norns is authoritative.
- Genesis Mini is a physical peripheral.
- Genesis sends intentions, not world state.
- The main gesture is turning one encoder.
- The first prototype must prove feel before adding systems.

## Core Loop

1. Cast the line.
2. Move through depth with the encoder.
3. Hear the drone change as the line descends or rises.
4. Detect a hidden creature through resonance in the drone.
5. Hold position in the correct zone until the bite.
6. Press to hook.
7. Use the encoder to keep line tension in the playable range.
8. Let the creature movement produce musical pattern events.
9. Bring it to the surface.
10. Keep the resulting pattern as a persistent musical layer.

## States

### CAST

The line is not yet in the water. Audio is sparse or silent. A press casts the
line and starts the drone.

### EXPLORE

The encoder directly changes line depth.

- Positive delta lets out line and moves deeper.
- Negative delta reels in line and moves shallower.
- No delta holds the current depth.

Depth continuously changes the drone. The mapping should feel like moving
through water strata, not like a simple pitch slider.

### RESONANCE

One hidden creature lives around a target depth. When the line enters its
field, the drone is contaminated by the creature signal. Standing near the
correct depth makes the signal clearer. Holding still in the bite zone arms the
bite.

### STRUGGLE

After the bite, pressing hooks the creature. The creature now produces pull
events. The same pull events are gameplay and music:

- small tug: short note or impulse;
- vibration: clustered fast events;
- long pull: sustained tone or phrase;
- direction change: interval or timbral change;
- violent tug: accented event.

The encoder controls tension.

- Slack: pattern weakens; too much slack causes escape.
- Correct tension: capture progresses.
- Overload: pattern becomes aggressive; too much overload breaks the line.

### SURFACE

When capture progress reaches the surface, the struggle pattern is stabilized
as a persistent musical layer. The player may cast again and search for the
next layer.

## First Creature

Do not implement multiple species yet. The first creature is a single readable
behavior phrase:

```text
rest
small tug
small tug
long pull
rest
three fast vibrations
```

The behavior phrase should generate the temporary pattern during `STRUGGLE`.
The captured layer should retain a trace of the actual fight: average tension,
slack count, overload count, fight duration, and event timing.

## Explicit Non-Goals

- no ecosystem simulation;
- no families;
- no resources;
- no inventory;
- no mutation or evolution tree;
- no Genesis pages beyond immediate status;
- no persistence;
- no multi-creature rules;
- no complex protocol before the transport spike passes.

