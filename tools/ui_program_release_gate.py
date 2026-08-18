#!/usr/bin/env python3
"""Run and seal the Phase-40 atomic UI-program release gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_40"
LIVE = EVIDENCE / "ui-program-release-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_40_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_40_ledger.json"
ORACLE_MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"future-ui-release-compatibility-witnesses", "rolling-overlap-and-reconnect"}
MUTANTS = (
    ("M-accept-stale-authority", "ui-program-release-accept-stale-authority-digest-mutant", "ui-program-release-accept-stale-authority-digest:"),
    ("M-publish-mixed-plan-pair", "ui-program-release-publish-mixed-plan-pair-mutant", "ui-program-release-publish-mixed-plan-pair:"),
    ("M-rebuild-runtime-per-program", "ui-program-release-rebuild-runtime-per-program-mutant", "ui-program-release-rebuild-runtime-per-program:"),
)


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return fingerprint(payload)


def invoke(name: str, arguments: Sequence[str], *, extra_env: dict[str, str] | None = None, timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(extra_env or {})
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def all_flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'-' if flag != enabled else ''}{flag}" for _, flag, _ in MUTANTS)


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (
        CABAL, "test", "ui-program-release-live-gate", *all_flags(flag),
        "--test-show-details=direct", "-j1", "-v0",
    )
    environment = os.environ.copy()
    environment["UI_PROGRAM_RELEASE_PURE_ONLY"] = "1"
    result = subprocess.run(
        arguments, cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in ORACLE_MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("40\t")]
    require(len(rows) == 8, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 5, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 3, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file(), f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read test/oracle/preimplementation_artifacts.tsv", "output": "5 oracles; 3 mutants", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 40,
        "gate_command": "python3 tools/ui_program_release_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [
            {"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"}
            for surface in surfaces
        ],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schemaVersion") == "amoebius.phase40.ui-program-release-live.v1", "live-schema")
    require(live.get("sealed") is True and live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate-seal")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable), "live-evidence-digest")
    fixtures = live.get("fixtureDigests", {})
    require(set(fixtures) == {
        "plan_pair_matrix.tsv", "release_content_manifest.golden", "source_key_set.txt", "stale_digest_matrix.tsv",
    }, "fixture-domain")
    require(all(re.fullmatch(r"sha256:[0-9a-f]{64}", str(value)) for value in fixtures.values()), "fixture-digests")

    store = live.get("releaseStore", {})
    releases = store.get("releases", [])
    require([row.get("revision") for row in releases] == ["A", "B"], "release-domain")
    require(all(row.get("atomicPair") is True for row in releases), "atomic-plan-pairs")
    require(all([entry.get("role") for entry in row.get("objects", [])] == [
        "client-plan", "ui-server-plan", "public-contract-manifest", "release-manifest",
    ] for row in releases), "release-object-domain")
    require(len(store.get("pointerHistory", [])) == 2 and store.get("finalHead") == store["pointerHistory"][-1], "pointer-history")
    require(store.get("missingOrMixedPairPointerEffects") == 0, "invalid-pair-pointer-effects")

    actions = live.get("actions", {})
    transcript = actions.get("transcript", [])
    require(len(transcript) == 10, "action-transcript-cardinality")
    accepted = [row for row in transcript if row.get("outcome") == "Accepted"]
    rejected = [row for row in transcript if row.get("outcome") == "ReloadRequired"]
    require([row.get("case") for row in accepted] == ["pair-A-A", "pair-B-B"], "accepted-action-domain")
    require(len(rejected) == 8 and all(row.get("status") == 409 and row.get("expectedEffectCount") == 0 for row in rejected), "rejected-action-domain")
    require(actions.get("acceptedEffects") == 2 and actions.get("rejectedEffects") == 0, "action-effects")
    require(actions.get("freshChallengesRecoveredExactly") is True, "fresh-action-challenges")
    require(actions.get("bypassMissingDigest") == actions.get("bypassHandAuthoredTuple") == "ReloadRequired", "bypass-refusals")

    runtime = live.get("runtimeImage", {})
    require(runtime.get("declaredImageDigest") == "sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4", "runtime-image-digest")
    require(runtime.get("imageCountAcrossReleases") == 1 and runtime.get("programSpecificImages") == 0, "generic-runtime-image")
    edge = live.get("authorityAndEdge", {})
    require(edge.get("freshOidcSessionAfterGateStart") is True and edge.get("tokenRouteObserved") is True, "fresh-edge-session")
    require(edge.get("downstreamRequestDelta", 0) >= 1 and edge.get("keycloakUpstreamRequestDelta", 0) >= 1, "edge-counter-observation")
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", str(edge.get("tokenDigest"))), "token-digest-custody")
    cleanup = live.get("cleanup", {})
    require(cleanup.get("providers") == {"KubernetesApi": True, "Minio": True}, "cleanup-providers")
    require(cleanup.get("residue") == [] and cleanup.get("inventoriesEqualRetainedSet") is True, "cleanup-residue")
    require(set(live.get("unverified", [])) == {"future UI release compatibility witnesses", "rolling overlap and reconnect"}, "unverified-domain")
    require(live.get("universalLinuxCpu") == {
        "allHardwareSubstrates": True,
        "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
    }, "universal-linux-cpu-and-pristine-routing")
    serialized = LIVE.read_text(encoding="utf-8")
    require("resultChallenge" not in serialized and "stateFile" not in serialized and "access_token" not in serialized, "secret-custody")
    require(not re.search(r'"challenge"\s*:', serialized), "raw-challenge-custody")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        disabled = all_flags()
        rows = [invoke("source-build", (
            CABAL, "build", "amoebius:dsl-core", "ui-program-release-live-gate", *disabled, "-j1", "-v0",
        ))]
        rows.append(phase0_domain())
        if args.reuse_fresh_live:
            rows.append({"name": "ui-release-live", "command": "sealed just-produced Phase-40 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("ui-release-live", (
                CABAL, "test", "ui-program-release-live-gate", *disabled, "--test-show-details=direct", "-j1", "-v0",
            ), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(invoke("sealed-live-reader", (
            CABAL, "test", "ui-program-release-live-gate", *disabled, "--test-show-details=direct", "-j1", "-v0",
        ), extra_env={"UI_PROGRAM_RELEASE_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", (
            CABAL, "test", "ui-program-release-live-gate", *disabled, "--test-show-details=direct", "-j1", "-v0",
        ), extra_env={"UI_PROGRAM_RELEASE_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase40.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "releases": ["A", "B"], "acceptedActions": 2, "invalidActionEffects": 0,
            "runtimeImages": 1, "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-40-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8",
        )
        print(f"ui-program-release-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"ui-program-release-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
