# Bait & Beat - New Core Concept

## One Sentence

A minimal sonic fishing game where a line explores depth, passing fish create
resonance near the hook, and hooked creatures generate musical patterns through
their own struggle.

## Active Principles

- Norns is authoritative.
- The current public build is Norns standalone.
- The main gesture is turning one Norns encoder.
- The first prototype must prove feel before adding systems.

## Core Loop

1. Cast the line.
2. Move through depth with the encoder.
3. Listen for fish resonance as the line descends or rises.
4. Detect a hidden creature through resonance near the hook.
5. Hold position in the correct zone until the bite.
6. Press to hook.
7. Use the encoder to keep line tension in the playable range.
8. Let the creature movement produce musical pattern events.
9. Bring it to the surface.
10. Keep the resulting pattern as a persistent musical layer.

## States

### CAST

The line is not yet in the water. Audio is sparse or silent. A press casts the
line.

### EXPLORE

The encoder directly changes line depth.

- Positive delta lets out line and moves deeper.
- Negative delta reels in line and moves shallower.
- No delta holds the current depth.

Explore itself stays quiet. The player listens for fish resonance when a
creature crosses the hook.

### RESONANCE

One hidden creature lives around a target depth. When the line enters its field
and the fish crosses the hook, a resonant fifth voice emerges. Standing near
the correct depth makes the signal clearer. Holding still in the bite zone arms
the bite.

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

## First Musical Fish Set

The active vertical slice now uses three musical fish archetypes on every cast.
They are not inventory, species, or progression systems: they are three fixed
roles that make the music legible.

- crab: percussive kick/snare/rim loop;
- fish: bright square-wave arpeggiator;
- octopus: slow harmony arcs.

Each cast spawns all three at different random depths. Fish have deterministic
pattern and timbre seeds, so a new crab is still a crab but can choose a
different rhythmic subdivision and sound color.

When a fish approaches the hook in `RESONANCE`, it previews its role:

- crab: one percussive hit;
- fish: one arpeggiator pulse;
- octopus: one slow-attack harmonic note.

When the player presses on bite-ready and enters `STRUGGLE`, the fish generates
its quantized pattern from the Norns clock. Captured loop limits are:

- crab: one percussive loop;
- fish: one arpeggiator loop;
- octopus: one harmony-arc loop.

If a type is already full, hooking a new fish of that type removes the oldest
loop immediately. If the new fish escapes or the line breaks, the removed loop
remains lost.

Captured fish can be edited from the loop page:

- crab: X changes event density, Y changes reverb;
- fish: X changes note probability, Y opens sustain and filtering;
- octopus: X changes harmonic interval spread, Y changes sustain.

## Explicit Non-Goals

- no ecosystem simulation;
- no families;
- no resources;
- no inventory;
- no mutation or evolution tree;
- no persistence;
- no multi-creature rules;
- no external hardware requirement.
