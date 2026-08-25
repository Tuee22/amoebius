#!/usr/bin/env python3
"""Run and seal the scoped Phase-51 infernix UI-lift gate."""

from __future__ import annotations

import argparse
import csv
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

import phase34_tenant_provider_live as phase34
import phase35_pulsar_live as phase35
import phase36_isolation_live as phase36
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = ROOT / "DEVELOPMENT_PLAN/evidence/phase_50"
LIVE = EVIDENCE_DIR / "infernix-ui-live.json"
INFERNIX_LIFT_RECEIPT = ROOT / "DEVELOPMENT_PLAN/evidence/phase_49/phase-receipt.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_51_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_51_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL = "/home/matthewnowak/.local/bin/dhall"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
KUBECTL = "/usr/bin/kubectl"
FLAGS = ("infernix-ui-lift-trust-client-artifact-scope-mutant", "infernix-ui-lift-drop-command-id-from-terminal-mutant")
MUTANTS = {
    "infernix-ui-lift-trust-client-artifact-scope-mutant": "mut-50-trust-client-artifact-scope",
    "infernix-ui-lift-drop-command-id-from-terminal-mutant": "mut-50-drop-command-id-from-terminal",
}
UNVERIFIED = {
    "browser-through-envoy-to-ui-server", "kubernetes-ui-server-replicas", "infernix-ui-lift-native-cbor-chain",
    "full-infernix-lift-inference-output-correspondence", "production-tinyllama-inference",
    "general-noninterference", "redis-websocket-cross-pod-recovery",
    "direct-bound-infernix-service-networkpolicy", "live-same-tenant-foreign-owner",
    "live-changed-input-zero-effect",
}


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any, *, newline: bool = False) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    if newline:
        payload += b"\n"
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    stable = dict(value)
    stable.pop("ledger_hash", None)
    return fingerprint(stable)


def invoke(name: str, arguments: Sequence[str], *, timeout: int = 1800) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    require(result.returncode == 0, f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(("-f" if flag == enabled else "-f-") + flag for flag in FLAGS)


def contract_args(enabled: str | None = None) -> tuple[str, ...]:
    return (
        CABAL, "test", "infernix-ui-lift-contract", "-w", GHC, *flags(enabled),
        "--test-show-details=direct", "-j1", "-v0",
    )


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    arguments = contract_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0 and marker in result.stdout, f"{marker}:green-or-wrong-locus:{result.stdout}")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("50\t")]
    require(len(rows) == 8, "phase0-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 6 and sum("\tmutant\t" in row for row in rows) == 2,
            "phase0-kind-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-missing:{path}")
    patches = "\n".join((ROOT / row.split("\t")[2]).read_text(encoding="utf-8") for row in rows if "\tmutant\t" in row)
    require("src/Amoebius/Infernix/UiAdapter.hs" in patches and all(marker in patches for marker in
            ("authorizationTenant", "terminalCommandId")), "phase0-mutant-loci")
    return {"name": "phase0-custody", "command": "read Phase-51 manifest rows", "output": "6 oracles; 2 mutants", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    decoded = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/fixture/dhall/infernix_ui_lift/infernix_ui.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(decoded.returncode == 0, f"infernix-ui-lift-dhall-oracle:{decoded.stdout}")
    value = json.loads(decoded.stdout)
    require(value == {"program": "infernix-ui", "ports": ["WorkflowProgress", "ArtifactProvenance", "ModelInteractor"], "mode": "SingleTenant"}, "infernix-ui-lift-dhall-domain")
    model_rows = list(csv.DictReader((ROOT / "test/fixture/infernix_ui_lift/public_model_input.tsv").open(encoding="utf-8"), delimiter="\t"))
    require(model_rows == [
        {"model": "reference-uppercase", "input": "fresh-challenge", "expected_public_result": "FRESH-CHALLENGE"},
        {"model": "reference-escape", "input": "port:admin", "expected_public_result": "port:admin"},
    ], "public-model-oracle")
    scope = list(csv.DictReader((ROOT / "test/fixture/infernix_ui_lift/scope_matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["result"] for row in scope] == ["allow", "Unavailable", "Unavailable", "ReloadRequired"] and
            [int(row["dispatch_count"]) for row in scope] == [1, 0, 0, 0], "scope-matrix")
    interaction = list(csv.DictReader((ROOT / "test/fixture/infernix_ui_lift/expected_interaction.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["event"] for row in interaction] == ["start", "progress", "ready", "invoke"], "interaction-oracle")
    identity = list(csv.DictReader((ROOT / "test/fixture/infernix_ui_lift/terminal_receipt_identity.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["field"] for row in identity] == ["scope", "command_id", "work_id", "handle", "input_digest", "terminal_outcome"], "receipt-identity-oracle")
    contract = (ROOT / "test/fixture/infernix_ui_lift/public_contract.golden").read_text(encoding="utf-8")
    require("OpaqueHandle" in contract and not any(token in contract for token in ("http://", "https://", "s3://", "pulsar://")), "public-contract")
    return {"name": "independent-oracles", "command": "Dhall/TSV/public-contract validation", "output": "UI, model, scope, interaction, receipt oracles valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    raw = LIVE.read_text(encoding="utf-8")
    live = json.loads(raw)
    stable = dict(live)
    actual = stable.pop("evidenceDigest", None)
    require(actual == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live["schema"] == "amoebius.phase50.infernix-ui-live.v1" and live["register"] == 3 and
            live["substrate"] == "linux-cpu" and live["result"] == "PASS-SCOPED", "live-schema")
    phase49 = json.loads(INFERNIX_LIFT_RECEIPT.read_text(encoding="utf-8"))
    require(live["prerequisite"] == {"phase49ReceiptFingerprint": phase49["receiptFingerprint"], "phase49Result": "PASS-SCOPED"}, "infernix-lift-prerequisite")
    authority = live["authority"]
    require(not authority["rawTokensStored"] and set(authority["tenantSessions"]) == {"alice", "carol"} and
            authority["tenantSessions"]["alice"]["tenant"] == "t-a" and authority["tenantSessions"]["carol"]["tenant"] == "t-b" and
            all(row["active"] for row in authority["tenantSessions"].values()) and all(str(value).startswith("sha256:") for value in authority["tokenDigests"].values()), "live-authority")
    browser = live["browser"]
    require(browser["engine"] == "google-chrome/playwright-core" and browser["positiveStatuses"] == [200] * 4 and
            browser["visibleResult"] == "FRESH-CHALLENGE" and browser["hostileText"] == "<SCRIPT>PORT:ADMIN</SCRIPT>" and
            "&lt;SCRIPT&gt;" in browser["hostileHtml"] and browser["hostileScriptCount"] == 0, "live-browser")
    workflow = live["workflow"]
    require(workflow["commandId"] == workflow["workId"] and workflow["terminalOutcome"] == "TerminalSucceeded" and
            workflow["effectCounts"] == {"workflowStarts": 1, "inferenceDispatches": 1, "artifactReads": 1, "resultWrites": 1} and
            workflow["foreignStatus"] == 404 and workflow["foreignEffectDelta"] == 0 and
            workflow["receiptReadByServer"] == "replica-b" and workflow["acceptanceSource"] == "MinIO durable receipt", "live-workflow")
    providers = live["providers"]
    require(providers["Minio"] == {"readyPointerWrittenLast": True, "resultAndReceiptReadBack": True, "directBearerStatus": 403}, "live-minio")
    require(len(providers["Pulsar"]["topics"]) == 2 and all(value == 0 for value in providers["Pulsar"]["before"].values()) and
            all(value == 1 for value in providers["Pulsar"]["after"].values()), "live-pulsar")
    require(providers["Kubernetes"]["argv0"] == "/usr/bin/python3" and providers["Kubernetes"]["workerPodUid"], "live-worker")
    require(all(live["cleanup"].values()), "live-cleanup")
    require(live["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "live-universal")
    honesty = live["honesty"]
    require({key for key, value in honesty.items() if value == "TESTED"} == {"typedUiAdapter", "realBrowser", "tenantKeycloakSessions", "retainedProviderIntegration"} and
            all(value in {"TESTED", "UNVERIFIED"} for value in honesty.values()), "live-honesty")
    require(not re.search(r'(?i)(access_token|client_secret|client_token|root_token|password"\s*:|authorization"\s*:)', raw), "secret-in-evidence")


def external_cleanup() -> dict[str, str]:
    namespace = subprocess.run(
        (KUBECTL, "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"), "get", "namespace", "-o", "name"),
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=60,
    )
    require(namespace.returncode == 0 and not any("infernix-ui-lift-ui-" in line for line in namespace.stdout.splitlines()), "infernix-ui-lift-namespace-residue")
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-bootstrap-coordinator"], f"kind-clusters:{clusters}")
    pulsar_tenants = phase35.admin_cli("tenants", "list", allow_missing=True)
    require(not any(line.strip().startswith("p50") for line in pulsar_tenants.splitlines()), "infernix-ui-lift-pulsar-residue")
    with phase34.port_forward("edge-system", "service/keycloak", phase36.KEYCLOAK_PORT, 8080):
        admin = phase36.keycloak_admin()
        realms = phase36.keycloak_json("GET", "/admin/realms", headers={"Authorization": "Bearer " + admin}, expected={200})
        require(not any(str(row.get("realm", "")).startswith("infernix-ui-lift-") for row in realms), "infernix-ui-lift-keycloak-residue")
    with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
        status, payload, _ = phase37.s3_request("GET", "")
        require(status == 200 and b"<Name>p50-" not in payload, "infernix-ui-lift-minio-residue")
    return {"name": "external-cleanup-readback", "command": "Kubernetes/Keycloak/MinIO/Pulsar/kind inventories", "output": "no Phase-51 residue; retained kind only", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 50,
        "gate_command": "python3 tools/infernix_ui_lift_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"}, {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        disabled = flags()
        rows = [invoke("infernix-ui-lift-source-build", (CABAL, "build", "infernix-ui-lift:lib:infernix-ui-lift", "infernix-ui-lift-contract", "infernix-ui-lift-live-gate", "-w", GHC, *disabled, "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("production-dhall-ui", (DHALL, "type", "--file", "dhall/ui/infernix.dhall", "--quiet")))
        rows.append(invoke("infernix-ui-lift-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "infernix-ui-live", "command": "sealed just-produced Phase-51 live receipt", "output": "fresh browser/Keycloak/Pulsar/MinIO/Kubernetes evidence", "result": "PASS"})
        else:
            rows.append(invoke("infernix-ui-live", (sys.executable, "tools/infernix_ui_lift_live.py"), timeout=2400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(external_cleanup())
        reader = (CABAL, "test", "infernix-ui-lift-live-gate", "-w", GHC, "--test-show-details=direct", "-j1", "-v0")
        rows.append(invoke("sealed-live-reader", reader))
        for flag, marker in MUTANTS.items():
            rows.append(reject_mutant(flag, marker))
        rows.append(invoke("baseline-restored-contract", contract_args()))
        rows.append(invoke("baseline-restored-live-reader", reader))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase50.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "realBrowser": "TESTED", "tenantKeycloakSessions": 2, "forbiddenEffects": 0,
            "productionTinyLlamaInference": "UNVERIFIED", "browserThroughEnvoy": "UNVERIFIED",
            "mutantsRed": list(MUTANTS.values()), "result": "PASS-SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
        (EVIDENCE_DIR / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE_DIR / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE_DIR / "phase-gate.log").write_text("\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows) + f"\nPHASE-50-GATE PASS-SCOPED {derived['ledger_hash']}\n", encoding="utf-8")
        print(f"infernix-ui-lift-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; full edge/replica/native-CBOR/production inference chain UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"infernix-ui-lift-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
