from __future__ import annotations

import argparse
import json
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
    print("HOST>", line, flush=True)
    return seq + 1


def read_until(port: serial.Serial, stop_at: float) -> None:
    while time.monotonic() < stop_at:
        raw = port.readline()
        if raw:
            print("GENESIS>", raw.decode("utf-8", errors="replace").strip(), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Command-driven pin probe helper.")
    parser.add_argument("--port", default="COM20")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--duration", type=float, default=10.0)
    parser.add_argument("--pulse", choices=[
        "slot2_io0",
        "slot2_io1",
        "slot2_io2",
        "slot3_io0",
        "slot3_io1",
        "slot3_io2",
    ])
    parser.add_argument("--level", choices=["HIGH", "LOW"], default="HIGH")
    parser.add_argument("--ms", type=int, default=1500)
    parser.add_argument("--snapshot", action="store_true")
    args = parser.parse_args()

    print(f"Opening {args.port} at {args.baud}", flush=True)
    seq = 9000

    with serial.Serial(args.port, args.baud, timeout=0.05) as ser:
        time.sleep(0.2)
        stop_at = time.monotonic() + args.duration

        if args.snapshot:
            seq = write_message(ser, seq, "PIN_PROBE_SNAPSHOT", {})

        if args.pulse:
            seq = write_message(
                ser,
                seq,
                "PIN_PROBE_PULSE",
                {
                    "label": args.pulse,
                    "level": args.level,
                    "duration_ms": args.ms,
                },
            )

        read_until(ser, stop_at)

        if args.pulse:
            write_message(ser, seq, "PIN_PROBE_STOP", {})


if __name__ == "__main__":
    main()

