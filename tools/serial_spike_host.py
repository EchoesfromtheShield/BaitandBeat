from __future__ import annotations

import argparse
import json
import math
import time

import serial


def envelope(seq: int, message_type: str, payload: dict) -> dict:
    return {
        "v_major": 1,
        "v_minor": 0,
        "seq": seq,
        "type": message_type,
        "payload": payload,
    }


def write_message(port: serial.Serial, seq: int, message_type: str, payload: dict) -> int:
    line = json.dumps(envelope(seq, message_type, payload), separators=(",", ":"))
    port.write((line + "\n").encode("utf-8"))
    port.flush()
    print("HOST>", line)
    return seq + 1


def synthetic_state(elapsed_s: float) -> dict:
    cycle = elapsed_s % 24.0

    if cycle < 4.0:
        state = "EXPLORE"
        signal = 0.0
        tension = 0.0
        progress = 0.0
        bite_ready = False
    elif cycle < 9.0:
        state = "RESONANCE"
        signal = min(1.0, (cycle - 4.0) / 4.0)
        tension = 0.0
        progress = 0.0
        bite_ready = cycle > 8.0
    elif cycle < 21.0:
        state = "STRUGGLE"
        signal = 1.0
        tension = 0.42 + math.sin(elapsed_s * 2.4) * 0.22
        progress = min(1.0, (cycle - 9.0) / 12.0)
        bite_ready = False
    else:
        state = "SURFACE"
        signal = 0.0
        tension = 0.0
        progress = 1.0
        bite_ready = False

    depth = 0.62
    return {
        "state": state,
        "depth_0_1": round(depth, 3),
        "drone": {
            "root_hz": round(55.0 * (1.0 + depth * 0.9), 2),
            "brightness_0_1": round(1.0 - depth * 0.65 + signal * 0.25, 3),
            "pressure_0_1": depth,
        },
        "signal_0_1": round(signal, 3),
        "tension_0_1": round(tension, 3),
        "capture_progress_0_1": round(progress, 3),
        "captured_layers": 0 if state != "SURFACE" else 1,
        "bite_ready": bite_ready,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Host-side USB CDC serial spike for Genesis Mini.")
    parser.add_argument("--port", default="COM20")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--duration", type=float, default=0.0, help="Stop after N seconds; 0 means run forever.")
    parser.add_argument("--listen-only", action="store_true", help="Only print incoming serial lines.")
    args = parser.parse_args()

    seq = 1000
    start = time.monotonic()
    last_state_s = 0.0
    last_pattern_second = -1

    with serial.Serial(args.port, args.baud, timeout=0.05) as ser:
        print(f"Listening on {args.port} at {args.baud}. Press Ctrl+C to stop.")
        time.sleep(0.3)
        ser.reset_input_buffer()

        while True:
            if args.duration > 0 and (time.monotonic() - start) >= args.duration:
                print("Duration reached; stopping.")
                return

            raw = ser.readline()
            if raw:
                text = raw.decode("utf-8", errors="replace").strip()
                print("GENESIS>", text)
                if not args.listen_only and "\"type\":\"HELLO\"" in text:
                    seq = write_message(
                        ser,
                        seq,
                        "HELLO_ACK",
                        {
                            "accepted": True,
                            "negotiated_minor": 0,
                            "capabilities": ["game_state", "pattern_event"],
                        },
                    )

            elapsed = time.monotonic() - start
            if args.listen_only:
                continue

            if elapsed - last_state_s >= 0.2:
                last_state_s = elapsed
                state = synthetic_state(elapsed)
                seq = write_message(ser, seq, "GAME_STATE", state)

                if state["state"] == "STRUGGLE":
                    whole_second = int(elapsed)
                    if whole_second != last_pattern_second:
                        last_pattern_second = whole_second
                        seq = write_message(
                            ser,
                            seq,
                            "PATTERN_EVENT",
                            {
                                "event": "small_tug",
                                "strength_0_1": 0.45,
                                "tension_0_1": state["tension_0_1"],
                            },
                        )


if __name__ == "__main__":
    main()
