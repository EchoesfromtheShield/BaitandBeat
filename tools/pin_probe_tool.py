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


class LineReader:
    def __init__(self, port: serial.Serial) -> None:
        self.port = port
        self.buffer = b""

    def poll_until(self, stop_at: float) -> list[str]:
        lines: list[str] = []
        while time.monotonic() < stop_at:
            chunk = self.port.read(self.port.in_waiting or 1)
            if not chunk:
                continue

            self.buffer += chunk
            while b"\n" in self.buffer:
                raw_line, self.buffer = self.buffer.split(b"\n", 1)
                text = raw_line.decode("utf-8", errors="replace").strip("\r")
                if text:
                    lines.append(text)
                    print("GENESIS>", text, flush=True)
        return lines

    def flush_partial(self) -> None:
        if self.buffer.strip():
            text = self.buffer.decode("utf-8", errors="replace").strip()
            print("GENESIS_PARTIAL>", text, flush=True)
        self.buffer = b""


def wait_for_ready(reader: LineReader, timeout_s: float = 3.0) -> None:
    stop_at = time.monotonic() + timeout_s
    saw_anything = False

    while time.monotonic() < stop_at:
        lines = reader.poll_until(time.monotonic() + 0.1)
        for text in lines:
            saw_anything = True
            if "\"type\":\"PIN_PROBE_HELLO\"" in text:
                return

    if saw_anything:
        print("No PIN_PROBE_HELLO seen; continuing with current serial session.", flush=True)
    else:
        print("No probe output seen before command; continuing anyway.", flush=True)


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
    parser.add_argument("--scan", choices=["slot2", "slot3"], help="Pulse every candidate pin in a slot.")
    parser.add_argument("--level", choices=["HIGH", "LOW"], default="HIGH")
    parser.add_argument("--ms", type=int, default=1500)
    parser.add_argument("--snapshot", action="store_true")
    args = parser.parse_args()

    print(f"Opening {args.port} at {args.baud}", flush=True)
    seq = 9000

    with serial.Serial(args.port, args.baud, timeout=0.05) as ser:
        time.sleep(0.2)
        reader = LineReader(ser)
        wait_for_ready(reader)
        stop_at = time.monotonic() + args.duration

        if args.snapshot:
            seq = write_message(ser, seq, "PIN_PROBE_SNAPSHOT", {})

        if args.scan:
            labels = [f"{args.scan}_io0", f"{args.scan}_io1", f"{args.scan}_io2"]
            levels = ["HIGH", "LOW"]
            for label in labels:
                for level in levels:
                    print(f"\nWATCH NOW: {label} {level} for {args.ms} ms", flush=True)
                    seq = write_message(
                        ser,
                        seq,
                        "PIN_PROBE_PULSE",
                        {
                            "label": label,
                            "level": level,
                            "duration_ms": args.ms,
                        },
                    )
                    reader.poll_until(time.monotonic() + (args.ms / 1000.0) + 0.5)
            write_message(ser, seq, "PIN_PROBE_STOP", {})
            reader.flush_partial()
            return

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

        reader.poll_until(stop_at)
        reader.flush_partial()

        if args.pulse:
            write_message(ser, seq, "PIN_PROBE_STOP", {})


if __name__ == "__main__":
    main()
