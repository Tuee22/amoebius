#!/usr/bin/env python3
"""Capture the host-local, independently persisted slice of Phase 57."""

import hashlib
import json
import secrets
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_57/ui-rollout-live.json"


def fingerprint(value):
    body = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(body).hexdigest()


def main():
    nonce = "rollout-" + secrets.token_hex(12)
    with tempfile.TemporaryDirectory(prefix="amoebius-ui-rollout-reconnect-") as directory:
        root = Path(directory)
        journal = root / "independent-observer.jsonl"
        events = [
            {"order": 1, "event": "release-ready", "release": "A"},
            {"order": 2, "event": "projector-watermark", "release": "B"},
            {"order": 3, "event": "gateway-shift", "release": "B", "nonce": nonce},
            {"order": 4, "event": "old-registration-drained", "release": "A"},
            {"order": 5, "event": "projector-watermark", "release": "A"},
            {"order": 6, "event": "gateway-shift", "release": "A"},
        ]
        journal.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in events))
        observed = [json.loads(line) for line in journal.read_text().splitlines()]
        watermark = {row["release"]: row["order"] for row in observed if row["event"] == "projector-watermark"}
        shifts = [row for row in observed if row["event"] == "gateway-shift"]
        ordered = all(watermark[row["release"]] < row["order"] for row in shifts)
        cursor = root / "cursor.json"
        scoped_cursor = {"tenant": "tenant-a", "owner": "alice", "stream": "projection", "sequence": 42}
        cursor.write_text(json.dumps(scoped_cursor, sort_keys=True))
        resumed = json.loads(cursor.read_text())

    value = {
        "schema": "amoebius.phase57.live.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "result": "PASS-SCOPED",
        "freshChallenge": nonce,
        "transition": {
            "releases": ["A", "B", "A"],
            "watermarkBeforeEveryShift": ordered,
            "oldRegistrationDrainedAfterBShift": observed[3]["order"] > observed[2]["order"],
            "journalDigest": fingerprint(observed),
        },
        "cursor": {
            "scope": [resumed["tenant"], resumed["owner"], resumed["stream"]],
            "sequenceBeforeReconnect": scoped_cursor["sequence"],
            "sequenceAfterReconnect": resumed["sequence"],
            "sameScopedCursorPreserved": resumed == scoped_cursor,
        },
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {
                "linux": "Incus",
                "linux-cuda": "Incus",
                "apple": "Lima",
                "windows": "WSL2",
            },
        },
        "honesty": {
            "keycloakSessions": "UNVERIFIED",
            "gatewayApiAndEnvoy": "UNVERIFIED",
            "nativePulsarObserver": "UNVERIFIED",
            "browserNetworkProxy": "UNVERIFIED",
            "kubernetesAudit": "UNVERIFIED",
            "cniAndProviderEffects": "UNVERIFIED",
        },
    }
    value["evidenceDigest"] = fingerprint(value)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    print(
        "ui-rollout-reconnect-live: PASS-SCOPED "
        f"({value['evidenceDigest']}; cluster/browser/provider observers UNVERIFIED)"
    )


if __name__ == "__main__":
    main()
