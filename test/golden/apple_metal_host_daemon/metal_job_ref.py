#!/usr/bin/env python3
"""Independent float32 oracle: y = 2*x + 1 for a whitespace tensor."""

from __future__ import annotations

import struct
import sys
from pathlib import Path


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def compute(values: list[float]) -> bytes:
    return b"".join(struct.pack("<f", f32(f32(2.0) * f32(value) + f32(1.0))) for value in values)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: metal_job_ref.py INPUT")
    values = [float(value) for value in Path(sys.argv[1]).read_text(encoding="utf-8").split()]
    sys.stdout.buffer.write(compute(values))
