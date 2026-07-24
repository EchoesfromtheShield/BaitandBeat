# ABYSSAL LINE

Minimal sonic fishing game for Norns plus Genesis Mini.

This repo intentionally replaces the previous PELAGOS direction. The old
documents in `sources/` are preserved as read-only reference material only.
The active concept is:

> Depth shapes the drone. The creature shapes the pattern. The player shapes
> the tension between them.

## Current Scope

Implement only the communication spike and a minimal vertical slice:

- `CAST`: cast the line into the sea.
- `EXPLORE`: Genesis encoder moves the line down, up, or leaves it still.
- `RESONANCE`: a hidden creature contaminates the drone near its depth.
- `STRUGGLE`: creature movement directly emits musical pattern events.
- `SURFACE`: the captured pattern becomes a persistent musical layer.

No species system, inventory, resources, economy, complex menus, persistence,
mutation tree, or multi-page Genesis UI.

## Repo Shape

```text
docs/                         Active design and milestone docs
protocol/                     Transport-independent logical protocol
protocol/fixtures/            Example messages for M0 spike testing
norns/abyssal_line/           Norns script skeleton and Lua modules
genesis/abyssal_line_controller/
                              Hardware-dependent implementation placeholder
tools/                        Host-side simulators and utilities
sources/                      Read-only imported PELAGOS reference docs
```

## Run The Host Simulation

The current runnable artifact is a host-side simulation of the vertical slice.
It proves state transitions and message payload shape without requiring Norns
or Genesis hardware.

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

The intended local Norns controls for early testing are:

- `K3`: cast or hook when the bite is ready.
- `E3`: move the line depth.

Genesis hardware code is deliberately not written yet. The USB transport and
module pin map must be verified first.

## Genesis M0 Hardware Spike

Current known setup:

- Genesis Mini V1 Rev2, ESP32-S3-Mini-N4R2;
- slot 1 rotary encoder;
- slot 2 tactile LED button;
- slot 3 vibration motor ERM;
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

The remaining unknown is whether Norns sees the Genesis Mini USB CDC serial
device through its USB host port.
