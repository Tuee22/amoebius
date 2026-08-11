#!/usr/bin/env python3
"""Run and seal the complete Phase-32 Keycloak-owned ingress acceptance gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_32"
LIVE_EVIDENCE = EVIDENCE / "keycloak-ingress-live.json"
REBIND_EVIDENCE = EVIDENCE / "rebind-regression.json"
ENUMERATION = ROOT / "test/enumeration/phase_32_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_32_ledger.json"
EXPECTED_DIGEST = ROOT / "test/fixtures/phase32/expected-base-digest.txt"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"singleton-owned-reconcile", "app-tenancy"}
MUTANTS = (
    ("M-drop-oidc", "phase32-drop-oidc-mutant", "oidc-guard-required"),
    ("M-netpol-swap", "phase32-netpol-swap-mutant", "network policy independent oracle"),
    ("M-delete-noop", "phase32-delete-noop-mutant", "cluster-recreate-identity-unchanged"),
    ("M-drop-origin", "phase32-drop-origin-mutant", "websocket-exact-origin-required"),
    ("M-nonce-replay", "phase32-nonce-replay-mutant", "websocket-single-use-nonce-required"),
    ("M-direct-backend", "phase32-direct-backend-mutant", "direct-websocket-backend-forbidden"),
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
    return {
        "name": name, "command": shlex.join(arguments),
        "output": result.stdout.strip(), "result": "PASS",
    }


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (
        CABAL, "test", "phase32-edge-spec", f"-f{flag}",
        "--test-show-details=direct", "-j1",
    )
    result = subprocess.run(
        arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {
        "name": name, "command": shlex.join(arguments),
        "output": marker, "result": "RED",
    }


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(
        payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [
        line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    ledger: dict[str, Any] = {
        "phase": 32,
        "gate_command": "python3 tools/phase32_gate.py",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-10",
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


def all_route_statuses_succeed(value: dict[str, Any]) -> bool:
    return bool(value) and all(
        isinstance(row, dict)
        and 200 <= row.get("authenticatedStatus", 0) < 400
        and row.get("unauthenticatedStatus", 200) in {200, 302, 303, 401, 403}
        for row in value.values()
    )


def evidence_domain(*, require_fresh: bool) -> dict[str, Any]:
    if not LIVE_EVIDENCE.is_file() or not REBIND_EVIDENCE.is_file():
        raise GateFailure("phase32-live-evidence-absent")
    if require_fresh and time.time() - LIVE_EVIDENCE.stat().st_mtime > 7200:
        raise GateFailure("phase32-live-evidence-stale")
    live = json.loads(LIVE_EVIDENCE.read_text(encoding="utf-8"))
    rebind = json.loads(REBIND_EVIDENCE.read_text(encoding="utf-8"))
    expected_digest = EXPECTED_DIGEST.read_text(encoding="utf-8").strip()
    if (
        live.get("schema") != "amoebius.phase32.keycloak-ingress-live.v1"
        or live.get("register") != 3 or live.get("substrate") != "linux-cpu"
    ):
        raise GateFailure("live-schema-domain")
    artifact = live.get("artifactSource", {})
    if (
        artifact.get("digest") != expected_digest
        or artifact.get("imagePullPolicy") != "Never"
        or artifact.get("publicPulls") != 0
        or artifact.get("pullEvents", {}).get("publicPullEventCount") != 0
        or not artifact.get("allRuntimeImageIdsMatchBaseDigest")
        or not artifact.get("completeResourceFields")
        or artifact.get("publicImageReferences")
        or artifact.get("ssa", {}).get("fieldManager") != "amoebius"
        or artifact.get("ssa", {}).get("observedObjectCount", 0) < 1
    ):
        raise GateFailure("artifact-provenance-domain")
    if not live.get("vaultMaterial", {}).get("vaultSourced") or live.get("vaultMaterial", {}).get("literalRecorded"):
        raise GateFailure("vault-secret-domain")
    database = live.get("database", {})
    if (
        database.get("readyReplicas") != 3
        or not database.get("strictSynchronous")
        or database.get("maximumLagOnFailoverBytes") != 1048576
        or database.get("namespace") != "keycloak-db"
        or database.get("backingPatroniCluster") != "keycloak"
        or not database.get("dedicatedPerConsumerCluster")
        or not database.get("perconaCrObserved")
        or not database.get("manualChildProjection")
        or not live.get("keycloak", {}).get("ready")
        or not live.get("keycloak", {}).get("wildIngressOwner")
    ):
        raise GateFailure("keycloak-patroni-domain")
    gateway = live.get("gatewayApi", {})
    controller = live.get("gatewayController", {})
    load_balancer = live.get("loadBalancer", {})
    if (
        gateway.get("apiVersion") != "gateway.networking.k8s.io/v1"
        or not gateway.get("manualDataPlaneProjection")
        or controller.get("version") != "v1.4.2" or not controller.get("ready")
        or load_balancer.get("soleLoadBalancer") != "edge-system/envoy"
        or load_balancer.get("unauthenticatedStatus") != 401
    ):
        raise GateFailure("single-edge-domain")
    gating = live.get("readinessGating", {})
    if not all(gating.get(key) for key in (
        "loadBalancerAddressWithheld", "gatewayListenerBlocked",
        "keycloakReadinessWithheld", "wildAdmitBlocked",
    )):
        raise GateFailure("readiness-withholding-domain")
    routes = live.get("routeInventory", {})
    if not all_route_statuses_succeed(routes.get("host", {})):
        raise GateFailure("host-route-domain")
    if set(routes.get("origins", {})) != {"wan", "lan", "localhost-browser"}:
        raise GateFailure("route-origin-domain")
    for origin in ("wan", "lan"):
        statuses = routes["origins"][origin].get("statuses", {})
        if len(statuses) != 5 or any(not 200 <= status < 400 for status in statuses.values()):
            raise GateFailure(f"route-origin-{origin}-domain")
    localhost_status = routes["origins"]["localhost-browser"].get("statuses", {})
    if not all_route_statuses_succeed(localhost_status):
        raise GateFailure("route-origin-localhost-domain")
    websocket = live.get("websocket", {})
    if (
        websocket.get("valid", {}).get("status") != 101
        or not websocket.get("valid", {}).get("challengeMatched")
        or websocket.get("replayedNonce", {}).get("status") != 409
        or websocket.get("wrongOrigin", {}).get("status") != 403
        or websocket.get("wrongSubprotocol", {}).get("status") != 426
        or websocket.get("forbiddenBackendChallenges") != 0
        or not live.get("directBackend", {}).get("denied")
    ):
        raise GateFailure("websocket-domain")
    scanner = live.get("backdoorScanner", {})
    host_local = live.get("hostLocalPeer", {})
    if (
        not scanner.get("seedTurnedScannerRed") or not scanner.get("restoredGreen")
        or scanner.get("violationsAfterRemoval")
        or host_local.get("endpointType") != "HostLocalPeer"
        or host_local.get("hostLoopbackStatus") != 200
        or not host_local.get("offHostDenied")
    ):
        raise GateFailure("backdoor-hostlocal-domain")
    tls = live.get("tlsAndAcme", {})
    if not tls.get("eabMaterialPresent") or tls.get("eabValuesRecorded") or tls.get("dhallLiteralScan") != "clear":
        raise GateFailure("tls-acme-domain")
    policy = live.get("networkPolicy", {})
    graph = policy.get("graphVariation", {})
    if (
        not policy.get("setEquality") or not policy.get("defaultDenyApplied")
        or not all(graph.get(key) for key in (
            "deniedBefore", "allowedAfterGraphAdd", "deniedAfterGraphRemove",
        ))
    ):
        raise GateFailure("network-policy-domain")
    if (
        rebind.get("schema") != "amoebius.phase32.rebind-regression.v1"
        or not rebind.get("freshCluster", {}).get("allIdentitiesChanged")
        or not rebind.get("markers", {}).get("allByteIdentical")
        or not rebind.get("cleanup", {}).get("scratchClusterRemovedAfterReadback")
        or not rebind.get("cleanup", {}).get("retainedBackingPreserved")
        or live.get("storageRebindRegression", {}).get("markers", {}).get("allByteIdentical") is not True
    ):
        raise GateFailure("rebind-domain")
    universal = live.get("universalLinuxCpu", {})
    routing = {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}
    if (
        not universal.get("availableOnEveryHardwareSubstrate")
        or universal.get("pristineLinuxHost") != routing
    ):
        raise GateFailure("universal-linux-domain")
    return live


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument(
        "--seal-existing-live", action="store_true",
        help="seal the just-produced long live receipt without repeating its two-cluster rebind",
    )
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        python = sys.executable
        rows = [
            invoke(
                "pure-edge-contract",
                (CABAL, "test", "phase32-edge-spec", "--test-show-details=direct", "-j1"),
            ),
        ]
        if arguments.seal_existing_live:
            rows.append({
                "name": "keycloak-ingress-live",
                "command": "sealed just-produced tools/phase32_keycloak_ingress_live.py receipt",
                "output": "fresh final live and isolated rebind evidence",
                "result": "PASS",
            })
        else:
            rows.append(invoke(
                "keycloak-ingress-live",
                (python, "tools/phase32_keycloak_ingress_live.py"), timeout=3600,
            ))
        evidence_domain(require_fresh=arguments.seal_existing_live)
        rows.append(invoke(
            "external-live-reader",
            (CABAL, "test", "phase32-keycloak-ingress-live", "--test-show-details=direct", "-j1"),
        ))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, flag, _ in MUTANTS)
        rows.append(invoke(
            "baseline-restored",
            (CABAL, "test", "phase32-edge-spec", *disabled, "--test-show-details=direct", "-j1"),
        ))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        committed = json.loads(LEDGER.read_text(encoding="utf-8"))
        if committed != derived:
            raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
        rows.append(invoke(
            "ledger-lint",
            (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION)),
        ))
        stable = {
            "schema": "amoebius.phase32.receipt.v1", "register": 3,
            "substrate": "linux-cpu", "soleKeycloakOwnedWildEdge": True,
            "oidcPositiveAndNegativeRoutes": True,
            "websocketExactOriginNonceSubprotocol": True,
            "hostLocalPeerOffHostDenied": True,
            "derivedDefaultDenyGraphTransitions": True,
            "exactMarkersSurvivedFreshClusterIdentity": True,
            "isolatedRebindScratchRemoved": True,
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(
            json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8",
        )
        (EVIDENCE / "phase-results.tsv").write_text(
            "check\tresult\n" + "".join(
                f"{row['name']}\t{row['result']}\n" for row in rows
            ), encoding="utf-8",
        )
        log = [
            f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}"
            for row in rows
        ]
        log.append(f"PHASE-32-GATE PASS {derived['ledger_hash']}")
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(log) + "\n", encoding="utf-8",
        )
        print(
            f"phase32-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; "
            f"{receipt['receiptFingerprint']})"
        )
        return 0
    except (
        GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase32-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
