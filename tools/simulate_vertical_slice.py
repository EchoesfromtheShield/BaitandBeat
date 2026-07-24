from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
import json
import math


class Mode(str, Enum):
    CAST = "CAST"
    EXPLORE = "EXPLORE"
    RESONANCE = "RESONANCE"
    STRUGGLE = "STRUGGLE"
    SURFACE = "SURFACE"


PULL_PATTERN = [
    ("rest", 0.90, 0.00),
    ("small_tug", 0.18, 0.42),
    ("rest", 0.22, 0.00),
    ("small_tug", 0.18, 0.36),
    ("long_pull", 1.20, 0.68),
    ("rest", 0.70, 0.00),
    ("vibration", 0.12, 0.34),
    ("vibration", 0.12, 0.50),
    ("vibration", 0.12, 0.28),
]


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def pattern_at(t: float) -> tuple[int, str, float]:
    period = sum(duration for _, duration, _ in PULL_PATTERN)
    cursor = 0.0
    local_t = t % period
    for index, (name, duration, pull) in enumerate(PULL_PATTERN):
        cursor += duration
        if local_t <= cursor:
            return index, name, pull
    index = len(PULL_PATTERN) - 1
    name, _, pull = PULL_PATTERN[index]
    return index, name, pull


@dataclass
class Layer:
    event_count: int
    fight_duration_s: float
    average_tension: float
    overloads: int
    slacks: int


@dataclass
class AbyssalLineSim:
    mode: Mode = Mode.CAST
    now_s: float = 0.0
    line_depth: float = 0.0
    creature_depth: float = 0.63
    fish_depth: float = 0.63
    signal: float = 0.0
    still_timer_s: float = 0.0
    bite_ready: bool = False
    fight_time_s: float = 0.0
    pattern_index: int = -1
    tension: float = 0.0
    slack_timer_s: float = 0.0
    overload_timer_s: float = 0.0
    capture_progress: float = 0.0
    tension_sum: float = 0.0
    tension_samples: int = 0
    slacks: int = 0
    overloads: int = 0
    captured_events: list[dict] = field(default_factory=list)
    layers: list[Layer] = field(default_factory=list)
    events: list[dict] = field(default_factory=list)

    depth_step: float = 0.008
    resonance_radius: float = 0.13
    bite_radius: float = 0.035
    bite_hold_s: float = 3.0
    safe_min: float = 0.24
    safe_max: float = 0.56
    slack_limit: float = 0.12
    overload_limit: float = 0.76
    slack_fail_s: float = 2.0
    overload_fail_s: float = 1.2
    capture_rate: float = 0.055

    def step(self, dt: float, encoder_delta: int = 0, button_press: bool = False) -> dict:
        self.now_s += dt
        self.events = []

        if self.mode in {Mode.EXPLORE, Mode.RESONANCE, Mode.STRUGGLE}:
            self.line_depth = clamp(self.line_depth + encoder_delta * self.depth_step)

        if self.mode == Mode.CAST:
            if button_press:
                self.mode = Mode.EXPLORE
                self.events.append({"type": "state", "name": "cast"})

        elif self.mode in {Mode.EXPLORE, Mode.RESONANCE}:
            self._update_resonance(dt)
            if self.mode == Mode.RESONANCE and self.bite_ready and button_press:
                self._start_struggle()

        elif self.mode == Mode.STRUGGLE:
            self._update_struggle(dt)

        elif self.mode == Mode.SURFACE and button_press:
            self._reset_for_next_cast()

        return self.snapshot()

    def _update_resonance(self, dt: float) -> None:
        distance = abs(self.line_depth - self.creature_depth)
        self.signal = clamp(1.0 - distance / self.resonance_radius)

        if self.signal <= 0:
            self.mode = Mode.EXPLORE
            self.still_timer_s = 0.0
            self.bite_ready = False
            return

        if self.mode == Mode.EXPLORE:
            self.mode = Mode.RESONANCE
            self.events.append({"type": "state", "name": "resonance"})

        if distance <= self.bite_radius:
            self.still_timer_s += dt
        else:
            self.still_timer_s = max(0.0, self.still_timer_s - dt * 2.0)

        self.bite_ready = self.still_timer_s >= self.bite_hold_s
        if self.bite_ready and not any(e.get("name") == "bite_ready" for e in self.events):
            self.events.append({"type": "state", "name": "bite_ready"})

    def _start_struggle(self) -> None:
        self.mode = Mode.STRUGGLE
        self.fight_time_s = 0.0
        self.pattern_index = -1
        self.fish_depth = self.creature_depth
        self.bite_ready = False
        self.tension = 0.0
        self.capture_progress = 0.0
        self.tension_sum = 0.0
        self.tension_samples = 0
        self.slacks = 0
        self.overloads = 0
        self.captured_events = []
        self.events.append({"type": "state", "name": "hooked"})

    def _update_struggle(self, dt: float) -> None:
        self.fight_time_s += dt
        index, name, pull = pattern_at(self.fight_time_s)

        if index != self.pattern_index:
            self.pattern_index = index
            if name != "rest":
                event = {
                    "type": "pattern",
                    "name": name,
                    "pull_0_1": round(pull, 3),
                    "tension_0_1": round(self.tension, 3),
                }
                self.events.append(event)
                self.captured_events.append(event)

        target = clamp(self.creature_depth + pull * 0.22)
        self.fish_depth += (target - self.fish_depth) * 0.18
        self.tension = clamp(abs(self.fish_depth - self.line_depth) * 2.6)
        self.tension_sum += self.tension
        self.tension_samples += 1

        if self.tension < self.slack_limit:
            if self.slack_timer_s == 0:
                self.slacks += 1
            self.slack_timer_s += dt
        else:
            self.slack_timer_s = max(0.0, self.slack_timer_s - dt)

        if self.tension > self.overload_limit:
            if self.overload_timer_s == 0:
                self.overloads += 1
            self.overload_timer_s += dt
        else:
            self.overload_timer_s = max(0.0, self.overload_timer_s - dt)

        if self.slack_timer_s >= self.slack_fail_s:
            self.events.append({"type": "failure", "name": "escaped_slack"})
            self._reset_for_next_cast()
            return

        if self.overload_timer_s >= self.overload_fail_s:
            self.events.append({"type": "failure", "name": "line_broken"})
            self.mode = Mode.CAST
            return

        if self.safe_min <= self.tension <= self.safe_max:
            self.capture_progress = clamp(self.capture_progress + dt * self.capture_rate)

        if self.capture_progress >= 1.0:
            average_tension = self.tension_sum / max(1, self.tension_samples)
            self.layers.append(
                Layer(
                    event_count=len(self.captured_events),
                    fight_duration_s=self.fight_time_s,
                    average_tension=average_tension,
                    overloads=self.overloads,
                    slacks=self.slacks,
                )
            )
            self.mode = Mode.SURFACE
            self.events.append({"type": "state", "name": "captured"})

    def _reset_for_next_cast(self) -> None:
        self.mode = Mode.EXPLORE
        self.signal = 0.0
        self.still_timer_s = 0.0
        self.bite_ready = False
        self.fight_time_s = 0.0
        self.tension = 0.0
        self.slack_timer_s = 0.0
        self.overload_timer_s = 0.0
        self.capture_progress = 0.0
        self.creature_depth = clamp(0.58 + len(self.layers) * 0.09, 0.2, 0.86)
        self.fish_depth = self.creature_depth

    def drone(self) -> dict:
        depth = self.line_depth
        brightness = clamp(1.0 - depth * 0.65 + self.signal * 0.25)
        pressure = depth
        root_hz = 55.0 * (1.0 + depth * 0.9)
        return {
            "root_hz": round(root_hz, 2),
            "brightness_0_1": round(brightness, 3),
            "pressure_0_1": round(pressure, 3),
        }

    def snapshot(self) -> dict:
        return {
            "t_s": round(self.now_s, 2),
            "state": self.mode.value,
            "depth_0_1": round(self.line_depth, 3),
            "drone": self.drone(),
            "signal_0_1": round(self.signal, 3),
            "bite_ready": self.bite_ready,
            "tension_0_1": round(self.tension, 3),
            "capture_progress_0_1": round(self.capture_progress, 3),
            "captured_layers": len(self.layers),
            "events": self.events,
        }


def scripted_controller(sim: AbyssalLineSim) -> tuple[int, bool]:
    if sim.mode == Mode.CAST:
        return 0, sim.now_s < 0.2

    if sim.mode in {Mode.EXPLORE, Mode.RESONANCE}:
        target = sim.creature_depth
        if abs(sim.line_depth - target) > 0.012:
            return (2 if sim.line_depth < target else -2), False
        return 0, sim.bite_ready

    if sim.mode == Mode.STRUGGLE:
        if sim.tension > sim.safe_max * 0.96:
            return 3, False
        if sim.tension < sim.safe_min * 1.05:
            return -2, False
        return -1, False

    if sim.mode == Mode.SURFACE:
        return 0, False

    return 0, False


def main() -> None:
    sim = AbyssalLineSim()
    dt = 0.1

    for frame in range(900):
        encoder_delta, button = scripted_controller(sim)
        snapshot = sim.step(dt, encoder_delta=encoder_delta, button_press=button)
        should_print = bool(snapshot["events"]) or frame % 10 == 0
        if should_print:
            print(json.dumps(snapshot, separators=(",", ":")))
        if sim.mode == Mode.SURFACE:
            break


if __name__ == "__main__":
    main()
