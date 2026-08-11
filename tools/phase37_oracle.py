#!/usr/bin/env python3
"""Independent, deliberately tiny Phase-37 canonical-CBOR oracle.

This encoder is fixture custody, not the Haskell implementation.  It supports
only the closed Phase-37 manifest vector and emits definite-length CBOR.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any


COMPONENTS = [
    ("alpha", hashlib.sha256(b"phase37-alpha").digest()),
    ("zeta", hashlib.sha256(b"phase37-zeta").digest()),
]


def head(major: int, length: int) -> bytes:
    if length < 24:
        return bytes([(major << 5) | length])
    if length < 256:
        return bytes([(major << 5) | 24, length])
    raise ValueError("phase37-oracle-length-out-of-domain")


def encode(value: Any) -> bytes:
    if isinstance(value, bytes):
        return head(2, len(value)) + value
    if isinstance(value, str):
        raw = value.encode("utf-8")
        return head(3, len(raw)) + raw
    if isinstance(value, list):
        return head(4, len(value)) + b"".join(encode(item) for item in value)
    raise TypeError(f"phase37-oracle-type:{type(value).__name__}")


def manifest(components: list[tuple[str, bytes]]) -> bytes:
    ordered = sorted(components, key=lambda item: item[0].encode("utf-8"))
    return encode(["amoebius.manifest.v1", [[name, digest] for name, digest in ordered]])


def main() -> None:
    canonical = manifest(COMPONENTS)
    noncanonical = encode([
        "amoebius.manifest.v1",
        [[name, digest] for name, digest in reversed(COMPONENTS)],
    ])
    mismatch = next(index for index, pair in enumerate(zip(canonical, noncanonical)) if pair[0] != pair[1])
    value = {
        "canonicalHex": canonical.hex(),
        "canonicalSha256": hashlib.sha256(canonical).hexdigest(),
        "noncanonicalHex": noncanonical.hex(),
        "noncanonicalSha256": hashlib.sha256(noncanonical).hexdigest(),
        "firstMismatchOffset": mismatch,
    }
    print(json.dumps(value, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
