#!/usr/bin/env python3
"""Run and seal the Phase-19 pure UI effect-binding checks."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "toolchain/pins.json"
FIXTURES = ROOT / "test/fixtures/ui_effect_binding"
MUTANTS = ROOT / "tests/mutants/phase19/mutants.tsv"
LOCUS = ROOT / "tests/oracle/phase19/validation_locus.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_19_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_19_ledger.json"
RESULTS = ROOT / "gen/dsl/phase19/phase-results.tsv"
GENERATED_LEDGER = ROOT / "gen/dsl/phase19/validation-locus-ledger.tsv"
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_19"


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = dict(os.environ)
    for name in list(value):
        if name in {"KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=environment(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def verify_pins() -> tuple[Path, str]:
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    cabal = Path(pins["cabal"]["path"])
    ghc = Path(pins["ghc"]["path"])
    for executable in (cabal, ghc):
        if not executable.is_absolute() or not executable.is_file():
            raise GateFailure(f"pinned executable is absent: {executable}")
    versions = run([str(cabal), "--numeric-version"]).stdout + run([str(ghc), "--numeric-version"]).stdout
    if pins["cabal"]["version"] not in versions or pins["ghc"]["version"] not in versions:
        raise GateFailure(f"toolchain version drifted:\n{versions}")
    return cabal, versions


def verify_oracles() -> None:
    ports = read_tsv(FIXTURES / "ports.tsv")
    handlers = read_tsv(FIXTURES / "handlers.tsv")
    capabilities = read_tsv(FIXTURES / "capabilities.tsv")
    bindings = read_tsv(FIXTURES / "expected_bindings.tsv")
    links = read_tsv(FIXTURES / "external_link_catalog.tsv")
    resolved = read_tsv(FIXTURES / "expected_external_links.tsv")
    errors = read_tsv(FIXTURES / "bind_errors.tsv")
    effects = ["ReadData", "MutateData", "StartWorkflow", "ObserveWorkflow", "Subscribe", "UploadBounded", "UseReadyArtifact"]
    if len(ports) != 7 or [row["effect"] for row in ports] != effects:
        raise GateFailure("port registry must pin the seven closed effect arms")
    if not all(len(rows) == 7 for rows in (handlers, capabilities, bindings)):
        raise GateFailure("handler, capability, and binding registries must each contain seven rows")
    if len(links) != 2 or len(resolved) != 2 or any(not row["url"].startswith("https://") for row in links):
        raise GateFailure("external-link oracle must contain two fixed HTTPS joins")
    if [row["error"] for row in errors] != [
        "MissingHandler", "DuplicateHandler", "ContractMismatch", "MissingCapability",
        "ScopeMismatch", "IdempotencyRequired", "ProviderCoordinateForbidden", "ExternalLinkNotAnEffect",
    ]:
        raise GateFailure("bind error oracle drifted")
    if len(read_tsv(MUTANTS)) != 7:
        raise GateFailure("Phase-19 mutant manifest must contain seven rows")
    locus = read_tsv(LOCUS)
    if len(locus) != 48 or len({row["entry"] for row in locus}) != 48:
        raise GateFailure("Phase-19 validation locus must contain forty-eight unique rows")
    phase0_rows = read_tsv(ROOT / "test/phase0_oracle_manifest.tsv")
    if len([row for row in phase0_rows if row["# phase"] == "19"]) != 14:
        raise GateFailure("Phase-0 manifest must pin fourteen Phase-19 artifacts")
    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_LEDGER.write_text(
        "# Register 1 only; browser/handler/provider/live isolation UNVERIFIED\n"
        + LOCUS.read_text(encoding="utf-8"), encoding="utf-8",
    )


def verify_source_boundaries() -> None:
    bind_path = ROOT / "src/Amoebius/Ui/Bind.hs"
    link_path = ROOT / "src/Amoebius/Ui/ExternalLinkCatalog.hs"
    bind = bind_path.read_text(encoding="utf-8")
    link = link_path.read_text(encoding="utf-8")
    bind_header = bind.split(") where", 1)[0]
    link_header = link.split(") where", 1)[0]
    for type_name, header in (
        ("PortId", bind_header), ("HandlerId", bind_header), ("Codec", bind_header),
        ("BoundUiProgram", bind_header), ("ExternalLinkId", link_header), ("BoundExternalLinks", link_header),
    ):
        if f"{type_name} (.." in header:
            raise GateFailure(f"private constructor exported: {type_name}")
    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path, source in ((bind_path, bind), (link_path, link)):
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", source))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(f"partial/unsafe token {match.group(0)!r} in {path.relative_to(ROOT)}")
    port_declaration = bind.split("data PortRequirement", 1)[1].split("deriving stock", 1)[0]
    if "Text" in port_declaration or "ExternalLink" in port_declaration or "Url" in port_declaration:
        raise GateFailure("raw provider/link coordinate entered PortRequirement")
    for token in ("ProviderCoordinateForbidden", "ExternalLinkNotAnEffect", "IdempotencyRequired", "ScopeMismatch"):
        if token not in bind:
            raise GateFailure(f"binding refusal arm disappeared: {token}")
    reference = (ROOT / "test/ui/EffectBindingReference.hs").read_text(encoding="utf-8")
    if "Amoebius.Ui.Bind" in reference or "Amoebius.Ui.ExternalLinkCatalog" in reference:
        raise GateFailure("independent relation imports a production binder")


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:ui-effect-binding-spec", "--offline"])
    binary = Path(run([str(cabal), "list-bin", "test:ui-effect-binding-spec", "--offline"]).stdout.strip())
    with tempfile.TemporaryDirectory(prefix="amoebius-phase19-") as directory:
        trace = Path(directory) / "network.trace"
        probe = run(["unshare", "-n", "true"], require_success=False)
        if probe.returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("neither network namespace isolation nor strace socket injection is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "inject=socket:error=EPERM",
                "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("effect-binding gate attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([str(cabal), "test", "ui-effect-binding-spec", "--offline", "--test-show-details=direct"])
    isolated, observer = isolated_green(cabal)
    token = "ui-effect-binding-spec: PASS (7 ports, 2 links, 8 errors, 13 coverage classes, 7 mutants)"
    if token not in suite.stdout or token not in isolated:
        raise GateFailure("Phase-19 acceptance token is absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path) -> str:
    rows = read_tsv(MUTANTS)
    logs: list[str] = []
    for row in rows:
        mutant = row["mutant"]
        case_name = row["target"].split(":")[-1]
        result = run([
            str(cabal), "test", "ui-effect-binding-spec", "--offline", "--test-show-details=direct",
            f"--test-options=--mutant={mutant}",
        ], require_success=False)
        token = f"phase19-bind-mutant: RED {mutant} {case_name}"
        if result.returncode == 0 or token not in result.stdout:
            raise GateFailure(f"effect-binding mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        logs.append(result.stdout)
    return "\n".join(logs)


def write_results(observer: str) -> None:
    metrics = {
        "port-bindings": "7/7-independent-exact",
        "external-links": "2/2-independent-fixed-https",
        "pinned-errors": "8/8-exact-empty-trace",
        "link-negatives": "8/8-distinct",
        "bounded-input-negatives": "3/3-distinct",
        "generated-coverage": "13/13-classes-at-5-percent",
        "mutants": "7/7-red",
        "network-observer": observer,
        "browser-enforcement": "UNVERIFIED",
        "handler-implementation-truth": "UNVERIFIED",
        "provider-state-truth": "UNVERIFIED",
        "live-tenant-isolation": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()), encoding="utf-8")


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def derive_ledger() -> dict[str, Any]:
    model_proven = {
        "opaque-port-id", "opaque-handler-id", "opaque-codec", "closed-port-effect",
        "closed-capability-name", "closed-scope-requirement", "closed-retry-policy",
        "opaque-bound-ui-program", "opaque-bound-external-links",
    }
    unverified = {"browser-enforcement", "handler-implementation-truth", "provider-state-truth", "live-tenant-isolation"}
    coverage = []
    for surface in ENUMERATION.read_text(encoding="utf-8").splitlines():
        status = "proven-for-the-model" if surface in model_proven else "UNVERIFIED" if surface in unverified else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger = {
        "phase": 19,
        "gate_command": "python3 tools/phase19_gate.py",
        "register": "1",
        "substrate": "none",
        "date": "2026-08-09",
        "layers": [
            {"name": "Decision", "status": "proven-for-the-model"},
            {"name": "Protocol", "status": "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def verify_ledger() -> str:
    derived = derive_ledger()
    committed = json.loads(LEDGER.read_text(encoding="utf-8"))
    if committed != derived:
        raise GateFailure("committed Phase-19 ledger differs from outcomes:\n" + json.dumps(derived, indent=2))
    run([sys.executable, str(ROOT / "tools/ledger_lint.py"), str(LEDGER), "--enumeration", str(ENUMERATION)])
    return str(derived["ledger_hash"])


def retain_evidence(green: str, mutants: str, versions: str) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "gate.log").write_text(green, encoding="utf-8")
    (EVIDENCE / "mutant.log").write_text(mutants, encoding="utf-8")
    (EVIDENCE / "toolchain.txt").write_text(versions, encoding="utf-8")
    shutil.copyfile(RESULTS, EVIDENCE / "phase-results.tsv")
    shutil.copyfile(GENERATED_LEDGER, EVIDENCE / "validation-locus-ledger.tsv")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--derive-ledger", action="store_true")
    args = parser.parse_args(argv)
    if args.derive_ledger:
        print(json.dumps(derive_ledger(), indent=2))
        return 0
    try:
        cabal, versions = verify_pins()
        verify_oracles()
        verify_source_boundaries()
        green, observer = run_green(cabal)
        mutants = run_mutants(cabal)
        write_results(observer)
        ledger_hash = verify_ledger()
        retain_evidence(green, mutants, versions)
        print(green, end="", flush=True)
        print(f"phase19-network-observer: {observer}")
        print(f"phase19-gate: PASS ({ledger_hash})")
        return 0
    except (GateFailure, OSError, KeyError, ValueError, json.JSONDecodeError) as problem:
        print(f"phase19-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
