#!/usr/bin/env python3
"""Run and seal the complete Phase-34 live DSL control-plane daemon acceptance gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_33"
LIVE_EVIDENCE = EVIDENCE / "control-plane-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_34_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_34_ledger.json"
EXPECTED = ROOT / "test/fixture/live_dsl_deploy/expected-enact-pass1.json"
KEYCLOAK_INGRESS_RECEIPT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_32/phase-receipt.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
UNVERIFIED = {
    "full-app-tenancy", "cross-cluster-gateway-migration",
    "tenant-admin-scope", "parent-child-admin-reach",
}
MUTANTS = (
    ("M-enact-noop", "live-dsl-deploy-enact-noop-mutant", "pass1 exact enact"),
    ("M-effect-swap", "live-dsl-deploy-effect-swap-mutant", "control-plane daemon writer"),
    ("M-persist-password", "live-dsl-deploy-persist-password-mutant", "password transport only"),
    ("M-reach-any", "live-dsl-deploy-reach-any-mutant", "reach vault-init/AuthenticatedFabric"),
    ("M-admit-unproven-secret", "live-dsl-deploy-admit-unproven-secret-mutant", "negative capability admitted"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    flags = [f"-f{'-' if other != flag else ''}{other}" for _, other, _ in MUTANTS]
    arguments = (CABAL, "test", "live-dsl-deploy-gate-spec", *flags, "--test-show-details=direct", "-j1")
    result = subprocess.run(
        arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [
        line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 33,
        "gate_command": "python3 tools/live_dsl_deploy_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-10",
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


def fingerprint(value: dict[str, Any]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def require(value: bool, tag: str) -> None:
    if not value:
        raise GateFailure(tag)


def evidence_domain(*, require_fresh: bool) -> dict[str, Any]:
    if not LIVE_EVIDENCE.is_file():
        raise GateFailure("live-dsl-deploy-live-evidence-absent")
    if require_fresh and time.time() - LIVE_EVIDENCE.stat().st_mtime > 7200:
        raise GateFailure("live-dsl-deploy-live-evidence-stale")
    live = json.loads(LIVE_EVIDENCE.read_text(encoding="utf-8"))
    phase32 = json.loads(KEYCLOAK_INGRESS_RECEIPT.read_text(encoding="utf-8"))
    expected = set(json.loads(EXPECTED.read_text(encoding="utf-8"))["objects"])
    require(live.get("schema") == "amoebius.live-dsl-deploy.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "live-register-substrate")
    require(live.get("prerequisites", {}).get("phase32ReceiptFingerprint") == phase32.get("receiptFingerprint"), "keycloak-ingress-prerequisite")
    history = live.get("historyCapacity", {})
    require(history.get("withinEngineSystemReserve") and history.get("eventTtlSeconds", 0) >= history.get("gateWindowMaximumSeconds", 1), "history-capacity")
    require(history.get("observedResidentBytes", 1) <= history.get("retainedByteCapacity", 0), "history-resident-fit")
    artifacts = live.get("artifacts", {})
    require(artifacts.get("staticallyLinked") and str(artifacts.get("controlPlaneSha256", "")).startswith("sha256:"), "static-control-plane")
    manifest = live.get("manifest", {})
    require(manifest == {
        "kind": "Deployment", "replicas": 1, "strategy": "Recreate",
        "persistentVolumeClaims": [], "standbyReplicas": 0,
        "amoebiusElection": False, "image": IMAGE,
        "fieldManager": "amoebius-live-dsl-deploy",
    }, "control-plane-manifest")
    handoff = live.get("handoff", {})
    bootstrap, released, control_plane = (handoff.get(key, {}) for key in ("bootstrap", "released", "controlPlane"))
    require(bootstrap.get("holder") == "phase26-bootstrap-host" and released.get("holder") is None, "handoff-release")
    require(handoff.get("sameLeaseUid") and len({bootstrap.get("uid"), released.get("uid"), control_plane.get("uid")}) == 1, "handoff-lease-identity")
    require(control_plane.get("holder") and control_plane.get("holder") != bootstrap.get("holder"), "handoff-control-plane-holder")
    require(all(handoff.get(key) for key in ("hostQuiescedBeforeRelease", "podNonServingBeforeRelease", "noControlPlaneDaemonMutationBeforeAcquire")), "handoff-order")
    admin = live.get("adminSequence", {})
    require(admin.get("vaultInit", {}).get("result") == "already-initialized", "vault-init")
    require(admin.get("vaultUnseal", {}).get("result") == "unsealed", "vault-unseal")
    first, second = admin.get("firstPass", {}), admin.get("secondPass", {})
    require(set(first.get("objects", [])) == expected and second.get("objects") == [] and second.get("audit") == [], "reconcile-two-pass")
    control_plane_user = live.get("attribution", {}).get("controlPlaneServiceAccount")
    require(set(row.get("identity") for row in first.get("audit", [])) == expected, "audit-enact-set")
    require(first.get("audit") and all(row.get("user") == control_plane_user for row in first["audit"]), "audit-attribution")
    require(admin.get("kvCrud") == ["put", "get", "list", "delete"], "kv-crud")
    require(live.get("edge", {}).get("status") == 200 and live.get("edge", {}).get("body") == "live-dsl-deploy-trivial:/probe", "keycloak-edge")
    require(live.get("adminReach", {}).get("offHostDenied") and live.get("adminReach", {}).get("endpointClass") == "HostLocalPeer", "admin-reach")
    negative = live.get("negativeCorpus", {})
    require(negative.get("count") == 26 and negative.get("platformAppResourceVersionsUnchanged"), "negative-corpus")
    require(negative.get("apiserverWrites") == 0 and negative.get("vaultContacts") == 0, "negative-effects")
    admin_negative = live.get("adminNegatives", {})
    require(len(admin_negative.get("reach", [])) == 6 and admin_negative.get("reachVaultContacts") == 0, "reach-negatives")
    admission = admin_negative.get("admission", [])
    require(len(admission) == 4 and all(row.get("positiveAdmitted") for row in admission), "admission-pairs")
    require(admin_negative.get("admissionApiserverWrites") == 0 and admin_negative.get("admissionVaultContacts") == 0, "admission-negative-effects")
    password = live.get("passwordObserver", {})
    require(not password.get("passwordPersisted") and all(password.get(key) == "clear" for key in ("containerFilesystem", "processArgvAndEnvironment", "kubernetesObjects", "controlPlaneLogs")), "password-persistence")
    replacement = live.get("replacement", {})
    require(replacement.get("uidChanged") and replacement.get("byteIdentical") and replacement.get("oldPodUid") != replacement.get("newPodUid"), "durable-replacement")
    postflight = live.get("postflight", {})
    require(postflight.get("sharedStackRestored") and postflight.get("runLabelSweep") == [], "postflight")
    attribution = live.get("attribution", {})
    require(attribution.get("controlPlaneWriteCount", 0) > 0 and attribution.get("harnessPlatformWrites") == 0, "writer-attribution")
    source = live.get("artifactSource", {})
    require(source == {"image": IMAGE, "imagePullPolicy": "Never", "publicPulls": 0, "haskellControlPlaneDaemon": True, "pythonEffectHelper": True}, "artifact-source")
    routing = {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}
    universal = live.get("universalLinuxCpu", {})
    require(universal.get("availableOnEveryHardwareSubstrate") and universal.get("pristineLinuxHost") == routing, "universal-linux-cpu")
    require(set(live.get("deferred", {}).values()) == {"UNVERIFIED"} and len(live.get("deferred", {})) == 4, "deferred-honesty")
    return live


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true", help="seal a fresh final live receipt without repeating it")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        python = sys.executable
        rows = [
            invoke("static-control-plane-build", (CABAL, "build", "exe:amoebius-singleton", "exe:amoebius", "--disable-shared", "--disable-executable-dynamic", "--enable-executable-static", "--ghc-options=-optl-static", "-j1")),
            invoke("pure-control-plane-contract", (CABAL, "test", "live-dsl-deploy-gate-spec", "--test-show-details=direct", "-j1")),
            invoke("runtime-storage-contract", (CABAL, "test", "live-dsl-deploy-runtime-storage-spec", "--test-show-details=direct", "-j1")),
            invoke("pb-admin-client", (python, "-m", "unittest", "discover", "-s", "test/spec/host", "-p", "test_phase33_admin_client.py", "-v")),
        ]
        if arguments.reuse_fresh_live:
            rows.append({"name": "control-plane-live", "command": "sealed just-produced tools/live_dsl_deploy_live.py receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("control-plane-live", (python, "tools/live_dsl_deploy_live.py"), timeout=3600))
        evidence_domain(require_fresh=arguments.reuse_fresh_live)
        rows.append(invoke("external-live-reader", (CABAL, "test", "live-dsl-deploy-live", "--test-show-details=direct", "-j1")))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "live-dsl-deploy-gate-spec", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        committed = json.loads(LEDGER.read_text(encoding="utf-8"))
        if committed != derived:
            raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase33.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "deploymentReplicasOneRecreateStateless": True, "kubernetesLeaseSingleWriter": True,
            "amoebiusElectionAbsent": True, "inProcessDhallProvisionSeal": True,
            "exactFirstPassAndEmptySecondPass": True, "adminRestOnlyOperatorSequence": True,
            "passwordNeverPersisted": True, "durableReplacementRecovered": True,
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        log = [f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows]
        log.append(f"PHASE-33-GATE PASS {derived['ledger_hash']}")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"live-dsl-deploy-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"live-dsl-deploy-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
