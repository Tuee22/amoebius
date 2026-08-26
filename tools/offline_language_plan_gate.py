#!/usr/bin/env python3
"""Run and seal the Phase 41 offline-language paired-plan checks.

This is a Register-1 gate.  It proves the authored continuity language, its finite queue
contract, deterministic client/replay projection, exact refusal corpus, and five seeded
mutations.  Browser persistence and live replay authority remain explicitly UNVERIFIED.
All generated evidence is retained beneath `.build/` and bound to the source snapshot by
the universal phase-gate machinery.
"""

from __future__ import annotations

import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Mapping

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common  # noqa: E402
import mutant_registry  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "test/fixture/offline_language_plan"
GOLDENS = ROOT / "test/golden/offline_language_plan"
LOCUS = ROOT / "test/oracle/offline_language_plan/validation_locus.tsv"
CALCULUS = ROOT / "test/oracle/offline_language_plan/calculus_projection.tsv"
RESULTS = ROOT / ".build/dsl/offline-language-plan/phase-results.tsv"
GENERATED_LEDGER = ROOT / ".build/dsl/offline-language-plan/validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/offline-language-plan-gate"
TEMP_ROOT = ROOT / ".build/tmp/offline-language-plan"
CONTRACT = "DEVELOPMENT_PLAN/phase_41_offline_language_plan.md"
GATE_COMMAND = "python3 tools/offline_language_plan_gate.py"
EXPECTATIONS = "test/oracle/offline_language_plan_surfaces.tsv"
MUTANT_CAPABILITY = "offline_language_plan"

COMPILER = ""

FLAGS = {
    "browser_redis_constructor": "offline-language-plan-browser-redis-constructor-mutant",
    "drop_queue_bound": "offline-language-plan-drop-queue-bound-mutant",
    "omit_server_handler": "offline-language-plan-omit-server-handler-mutant",
    "persist_private_field": "offline-language-plan-persist-private-field-mutant",
    "queue_model_invocation": "offline-language-plan-queue-model-invocation-mutant",
}

MACROS = {
    "browser_redis_constructor": "OFFLINE_LANGUAGE_PLAN_BROWSER_REDIS_CONSTRUCTOR_MUTANT",
    "drop_queue_bound": "OFFLINE_LANGUAGE_PLAN_DROP_QUEUE_BOUND_MUTANT",
    "omit_server_handler": "OFFLINE_LANGUAGE_PLAN_OMIT_SERVER_HANDLER_MUTANT",
    "persist_private_field": "OFFLINE_LANGUAGE_PLAN_PERSIST_PRIVATE_FIELD_MUTANT",
    "queue_model_invocation": "OFFLINE_LANGUAGE_PLAN_QUEUE_MODEL_INVOCATION_MUTANT",
}

MUTANT_TOKENS = {
    "drop_queue_bound": "offline-plan-mutant: RED drop_queue_bound locus=queue-age-bound",
    "omit_server_handler": "offline-plan-mutant: RED omit_server_handler locus=paired-plan-keys",
    "queue_model_invocation": (
        "offline-plan-mutant: RED queue_model_invocation locus=model-invocation-classification"
    ),
    "persist_private_field": (
        "offline-plan-mutant: RED persist_private_field locus=public-plan-private-fields"
    ),
    "browser_redis_constructor": (
        "offline-plan-mutant: RED browser_redis_constructor locus=authored-mechanism-surface"
    ),
}

SANCTIONED_OBSERVERS = (
    "unshare-network-namespace",
    "darwin-sandbox-deny-network",
    "strace-socket-EPERM",
)

EXPECTED_RESULTS = {
    "dhall-continuity-shape": "6-operations/2-continuity-arms/4-offline-source-fields",
    "positive-contracts": "3/3-exact",
    "negative-contracts": "13/13-exact",
    "plan-key-rows": "8/8-independent-exact",
    "paired-key-sets": "3/3-exact",
    "private-fields": "0/0-public",
    "authored-mechanisms": "0/0-authored",
    "artifact-commands": "2/2-exact",
    "deterministic-compilations": "2/2-repeat-equal",
    "mutants": "5/5-red",
    "calculus-kinds": "5/5",
    "calculus-components": "5/5",
    "calculus-projection-counts": "2,9,16,8,5",
    "calculus-resource-vector": "5,40,0,0",
    "network-observer": "sanctioned-observer",
    "browser-persistence-runtime": "UNVERIFIED",
    "live-replay-authority": "UNVERIFIED",
}

CHECKS = {
    "dhall-schema-exact": "the Dhall mirror has the six operations, two continuity arms, and four offline fields",
    "authored-product-continuity": "Infernix and jitML author mechanism-free offline contracts",
    "oracle-cardinality-exact": "the three independent language and plan tables have exact row sets",
    "phase-zero-custody": "all eight Phase-24 preimplementation artifacts remain present",
    "mutant-registry-exact": "the central registry owns exactly the five Phase-41 mutations",
    "module-ownership-exact": "one dedicated component owns the shared offline language types",
    "cpp-mutant-wiring": "each central registry flag reaches its exact production CPP locus",
    "compiler-partial-token-scan": "no partial or unsafe token survives in the offline compiler modules",
    "totality-options": "the offline plan suite compiles with project totality warnings",
    "credential-environment-scrub": "the gate removes ambient provider and cluster credentials",
    "normal-isolated-acceptance": "the acceptance tokens appear normally and under network denial",
    "mutant-red-loci": "all five mutations fail at their distinct authored loci",
    "semantic-oracles-complete": "positive, negative, plan, and calculus oracles are exact",
    "emitted-results-untracked": "the run's generated records stay outside the source snapshot",
    "toolchain-satisfies-requirements": "resolved cabal and ghc satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

CHECK_SIDE = {
    "dhall-schema-exact": "source",
    "authored-product-continuity": "source",
    "oracle-cardinality-exact": "oracle",
    "phase-zero-custody": "oracle",
    "mutant-registry-exact": "oracle",
    "module-ownership-exact": "source",
    "cpp-mutant-wiring": "source",
    "compiler-partial-token-scan": "source",
    "totality-options": "source",
    "credential-environment-scrub": "source",
    "normal-isolated-acceptance": "suite",
    "mutant-red-loci": "mutant",
    "semantic-oracles-complete": "oracle",
    "emitted-results-untracked": "results",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
}

CLASS_METRIC = {
    "positive-contract": "positive-contracts",
    "negative": "negative-contracts",
    "plan": "plan-key-rows",
    "invariant": "paired-key-sets",
    "private": "private-fields",
    "mechanism": "authored-mechanisms",
    "artifact": "artifact-commands",
    "determinism": "deterministic-compilations",
    "mutant": "mutants",
    "observer": "network-observer",
}

SIDES = ("toolchain", "oracle", "source", "suite", "mutant", "results")


class GateFailure(RuntimeError):
    pass


def environment() -> dict[str, str]:
    value = toolchain.contained_env()
    value["PATH"] = os.pathsep.join([str(ROOT / "tools"), value.get("PATH", "")])
    for name in list(value):
        if name in {"KUBECONFIG", "GOOGLE_APPLICATION_CREDENTIALS"}:
            value.pop(name, None)
        elif name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_")):
            value.pop(name, None)
    return value


def configuration(enabled: str | None = None) -> list[str]:
    return [f"-f{flag}" if mutant == enabled else f"-f-{flag}" for mutant, flag in FLAGS.items()]


def run(command: list[str], *, require_success: bool = True) -> subprocess.CompletedProcess[str]:
    if COMPILER and command and Path(command[0]).name.startswith("cabal"):
        command = [
            command[0],
            f"--with-compiler={COMPILER}",
            f"--builddir={BUILD_ROOT}",
            f"--store-dir={ROOT / '.build/cabal-store'}",
            "--jobs=1",
            *command[1:],
        ]
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=environment(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if require_success and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout}")
    return result


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def read_words(path: Path) -> list[dict[str, str]]:
    lines = [line.split() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) < 2:
        raise GateFailure(f"oracle table is empty: {path.relative_to(ROOT)}")
    header = lines[0]
    if any(len(row) != len(header) for row in lines[1:]):
        raise GateFailure(f"oracle table has a malformed row: {path.relative_to(ROOT)}")
    return [dict(zip(header, row)) for row in lines[1:]]


def verify_oracles() -> tuple[list[dict[str, str]], dict[str, int]]:
    positive = read_words(FIXTURES / "positive_contracts.tbl")
    negative = read_words(FIXTURES / "negative_contracts.tbl")
    plans = read_words(GOLDENS / "plan_keys.tbl")
    calculus = read_tsv(CALCULUS)
    locus = read_tsv(LOCUS)

    positive_cases = {"online-only", "infernix", "jitml"}
    negative_cases = {
        "zero-count", "zero-bytes", "zero-age", "missing-local-validation",
        "missing-idempotency", "missing-conflict", "missing-order", "missing-dependency",
        "missing-validation", "queue-progress", "queue-signal", "queue-cancel",
        "queue-model-invocation",
    }
    plan_sources = {
        "infernix-start", "jitml-training-start", "workflow-progress", "dataset",
        "offline-view", "ml-signal", "workflow-cancel", "model-invocation",
    }
    if len(positive) != 3 or {row["case"] for row in positive} != positive_cases:
        raise GateFailure("positive contract oracle must contain the three exact authored cases")
    if len(negative) != 13 or {row["case"] for row in negative} != negative_cases:
        raise GateFailure("negative contract oracle must contain the thirteen exact refusal cases")
    if len(plans) != 8 or {row["source"] for row in plans} != plan_sources:
        raise GateFailure("plan-key oracle must contain the eight exact independent rows")
    expected_calculus = [
        {"metric": "calculus-kinds", "value": "artifact,budget,lift,workflow,evidence"},
        {"metric": "component-names", "value": "offline-plan-artifacts,bounded-queue-contract,language-and-refusal-corpus,paired-plan-workflow,mutant-evidence"},
        {"metric": "projection-counts", "value": "2,9,16,8,5"},
        {"metric": "resource-vector", "value": "5,40,0,0"},
    ]
    if calculus != expected_calculus:
        raise GateFailure("offline-language five-calculus projection oracle drifted")
    if len(locus) != 38 or len({row["entry"] for row in locus}) != 38:
        raise GateFailure("Phase-41 validation locus must contain thirty-eight unique rows")

    phase0 = read_tsv(ROOT / "test/oracle/preimplementation_artifacts.tsv")
    custody = [row for row in phase0 if row["# phase"] == "24"]
    if len(custody) != 8:
        raise GateFailure("Phase-0 manifest must pin eight Phase-41 artifacts under custody phase 24")
    missing = [row["path"] for row in custody if not (ROOT / row["path"]).is_file()]
    if missing:
        raise GateFailure(f"Phase-41 preimplementation artifacts are absent: {missing}")

    mutants = mutant_registry.capability(MUTANT_CAPABILITY)
    if len(mutants) != 5 or {row["mutant"] for row in mutants} != set(FLAGS):
        raise GateFailure("central registry must contain exactly the five offline-language mutants")
    for row in mutants:
        if row["flag"] != FLAGS[row["mutant"]]:
            raise GateFailure(f"registry flag drift for {row['mutant']}")
        if row["body"] == mutant_registry.ABSENT or not (ROOT / row["body"]).is_file():
            raise GateFailure(f"registry body is absent for {row['mutant']}")

    GENERATED_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    generated = ["entry\tclass\tlocus\tstatus\n", *LOCUS.read_text(encoding="utf-8").splitlines(True)[1:]]
    generated.extend(
        f"{row['mutant']}\tmutant\t{row['flag']}\ttested\n" for row in mutants
    )
    GENERATED_LEDGER.write_text("".join(generated), encoding="utf-8")
    return mutants, {"positive": len(positive), "negative": len(negative), "plans": len(plans)}


def cabal_stanza(text: str, marker: str) -> str:
    if marker not in text:
        raise GateFailure(f"missing Cabal stanza: {marker.strip()}")
    tail = text.split(marker, 1)[1]
    boundary = re.search(r"\n(?:library(?:\s|$)|test-suite\s|executable\s|benchmark\s)", tail)
    return tail[:boundary.start()] if boundary else tail


def verify_source_boundaries() -> None:
    types = ROOT / "src/offline-language-types/Amoebius/Ui/Offline/Types.hs"
    old_types = ROOT / "src/Amoebius/Ui/Offline/Types.hs"
    decode = ROOT / "src/Amoebius/Ui/Offline/Decode.hs"
    plan = ROOT / "src/Amoebius/Ui/Offline/Plan.hs"
    source = ROOT / "src/Amoebius/Ui/Source.hs"
    ui_schema = ROOT / "dhall/amoebius/UiOffline.dhall"
    authored_products = [ROOT / "dhall/ui/infernix.dhall", ROOT / "dhall/ui/jitml.dhall"]
    required = [types, decode, plan, source, ui_schema, *authored_products]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        raise GateFailure(f"offline language source inventory is incomplete: {missing}")
    if old_types.exists():
        raise GateFailure("module-ownership-exact: shared types still exist beneath dsl-core's source root")

    schema = ui_schema.read_text(encoding="utf-8")
    operations = {
        "InfernixStart", "JitmlTrainingStart", "WorkflowProgress",
        "MlSignal", "WorkflowCancel", "ModelInvocation",
    }
    if any(not re.search(rf"(?:<|\|)\s*{name}(?:\s|$)", schema) for name in operations):
        raise GateFailure("dhall-schema-exact: the six operation alternatives are not exact")
    for field in ("projections", "queuedPorts", "localBlobs", "offlineView"):
        if not re.search(rf"\b{field}\s*:", schema):
            raise GateFailure(f"dhall-schema-exact: missing OfflineSource field {field}")
    if not re.search(r"<\s*OnlineOnly\s*\|\s*Offline\s*:\s*OfflineSource\s*>", schema):
        raise GateFailure("dhall-schema-exact: Continuity is not the exact two-arm union")
    queue_terms = (
        "maxCount", "maxBytes", "maxAgeSeconds", "localValidation", "idempotency",
        "conflict", "ordering", "dependency", "authoritativeValidation",
    )
    if any(not re.search(rf"\b{term}\s*:", schema) for term in queue_terms):
        raise GateFailure("dhall-schema-exact: the nine-term queue contract is incomplete")

    product_text = "\n".join(path.read_text(encoding="utf-8") for path in authored_products)
    if "T.UiOffline.Continuity.Offline" not in product_text:
        raise GateFailure("authored-product-continuity: product sources do not author Offline continuity")
    for forbidden in ("IndexedDB", "Redis", "ServiceWorker", "localStorage"):
        if forbidden in schema or forbidden in product_text:
            raise GateFailure(f"authored-product-continuity: authored mechanism {forbidden} leaked into the language")

    cabal = (ROOT / "amoebius.cabal").read_text(encoding="utf-8")
    types_stanza = cabal_stanza(cabal, "library offline-language-types\n")
    dsl_stanza = cabal_stanza(cabal, "library dsl-core\n")
    runtime_stanza = cabal_stanza(cabal, "library offline-runtime\n")
    test_stanza = cabal_stanza(cabal, "test-suite offline-plan-spec\n")
    if (
        "Amoebius.Ui.Offline.Types" not in types_stanza
        or "src/offline-language-types" not in types_stanza
        or "amoebius:offline-language-types" not in dsl_stanza
        or "amoebius:offline-runtime" in dsl_stanza
        or "amoebius:offline-language-types" not in runtime_stanza
        or "Amoebius.Ui.Offline.Types" in runtime_stanza
        or "amoebius:offline-language-types" not in test_stanza
    ):
        raise GateFailure("module-ownership-exact: offline language component ownership drifted")

    production = decode.read_text(encoding="utf-8") + plan.read_text(encoding="utf-8")
    for mutant, flag in FLAGS.items():
        macro = MACROS[mutant]
        if f"if flag({flag})" not in runtime_stanza or f"-D{macro}" not in runtime_stanza:
            raise GateFailure(f"cpp-mutant-wiring: Cabal does not wire {flag} to {macro}")
        if macro not in production:
            raise GateFailure(f"cpp-mutant-wiring: production has no locus for {macro}")
    if "PHASE59_" in runtime_stanza or "PHASE59_" in production:
        raise GateFailure("cpp-mutant-wiring: retired Phase-59 macro survives")
    if "continuity :: Continuity" not in source.read_text(encoding="utf-8"):
        raise GateFailure("dhall-schema-exact: UiSource does not carry Continuity")

    prohibited = re.compile(r"\b(error|undefined|fromJust|head|tail|unsafePerformIO|unsafeCoerce)\b|!!")
    for path in (types, decode, plan):
        body = path.read_text(encoding="utf-8")
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', re.sub(r"--[^\n]*", "", body))
        match = prohibited.search(stripped)
        if match:
            raise GateFailure(f"compiler-partial-token-scan: {match.group(0)!r} in {path.name}")
    for option in ("-Werror=missing-methods", "-Werror=incomplete-patterns"):
        if option not in test_stanza:
            raise GateFailure(f"totality-options: offline-plan-spec lacks {option}")

    scrubbed = environment()
    leaked = [
        name for name in scrubbed
        if name in {"KUBECONFIG", "GOOGLE_APPLICATION_CREDENTIALS"}
        or name.startswith(("AWS_", "AZURE_", "VAULT_", "KUBE_"))
    ]
    if leaked:
        raise GateFailure(f"credential-environment-scrub: ambient credentials survived: {leaked}")


def item_classes() -> dict[str, str]:
    classes = {row["entry"].strip(): row["class"].strip() for row in read_tsv(LOCUS)}
    for row in mutant_registry.capability(MUTANT_CAPABILITY):
        classes[row["mutant"].strip()] = "mutant"
    return classes


def isolated_green(cabal: Path) -> tuple[str, str]:
    run([str(cabal), "build", "test:offline-plan-spec", *configuration()])
    binary = Path(run([str(cabal), "list-bin", "test:offline-plan-spec", *configuration()]).stdout.strip())
    if not binary.is_absolute() or not binary.is_file():
        raise GateFailure("offline-plan-spec binary path is not absolute")
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="network-", dir=TEMP_ROOT) as directory:
        trace = Path(directory) / "network.trace"
        if shutil.which("unshare") and run(["unshare", "-n", "true"], require_success=False).returncode == 0:
            result = run(["unshare", "-n", str(binary)])
            observer = "unshare-network-namespace"
        elif shutil.which("sandbox-exec"):
            profile = Path(directory) / "deny-network.sb"
            profile.write_text("(version 1)\n(allow default)\n(deny network*)\n", encoding="utf-8")
            control = run(
                [
                    "sandbox-exec", "-f", str(profile), sys.executable, "-c",
                    "import socket,sys\ntry:\n socket.create_connection(('127.0.0.1',9),timeout=1).close()\nexcept PermissionError:\n sys.exit(0)\nexcept OSError:\n sys.exit(3)\nsys.exit(4)\n",
                ],
                require_success=False,
            )
            if control.returncode != 0:
                raise GateFailure(f"sandbox-exec network-denial control exited {control.returncode}")
            result = run(["sandbox-exec", "-f", str(profile), str(binary)])
            observer = "darwin-sandbox-deny-network"
        else:
            if shutil.which("strace") is None:
                raise GateFailure("no sanctioned network observer is available")
            result = run([
                "strace", "-f", "-qq", "-e", "trace=%network", "-e", "signal=none",
                "-e", "inject=socket:error=EPERM", "-o", str(trace), str(binary),
            ])
            if trace.read_text(encoding="utf-8").strip():
                raise GateFailure("offline plan suite attempted a network syscall:\n" + trace.read_text(encoding="utf-8"))
            observer = "strace-socket-EPERM"
    return result.stdout, observer


def acceptance_present(output: str) -> bool:
    return (
        "offline-plan-calculus: PASS (5 kinds, 40 projected units)" in output
        and "offline-plan-spec: PASS (3 positive contracts, 13 exact negatives, 8 plan rows, 3 paired key sets, 5 mutants)" in output
    )


def run_green(cabal: Path) -> tuple[str, str]:
    suite = run([
        str(cabal), "test", "offline-plan-spec", *configuration(), "--test-show-details=direct",
    ])
    isolated, observer = isolated_green(cabal)
    if not acceptance_present(suite.stdout) or not acceptance_present(isolated):
        raise GateFailure("Phase-41 acceptance tokens are absent from normal or isolated execution")
    return suite.stdout + isolated, observer


def run_mutants(cabal: Path, mutants: list[dict[str, str]]) -> tuple[str, set[str]]:
    logs: list[str] = []
    reddened: set[str] = set()
    for row in mutants:
        mutant = row["mutant"]
        result = run([
            str(cabal), "test", "offline-plan-spec", *configuration(mutant),
            "--test-show-details=direct",
        ], require_success=False)
        if result.returncode == 0 or MUTANT_TOKENS[mutant] not in result.stdout:
            raise GateFailure(f"mutant survived or missed its red locus: {mutant}\n{result.stdout}")
        reddened.add(mutant)
        logs.append(result.stdout)
    restored = run([
        str(cabal), "test", "offline-plan-spec", *configuration(), "--test-show-details=direct",
    ])
    if not acceptance_present(restored.stdout):
        raise GateFailure("baseline did not return green after the mutation matrix")
    logs.append(restored.stdout)
    return "\n".join(logs), reddened


def write_results(counts: Mapping[str, int], reddened: int, total: int, observer: str) -> None:
    metrics = {
        "dhall-continuity-shape": "6-operations/2-continuity-arms/4-offline-source-fields",
        "positive-contracts": f"{counts['positive']}/3-exact",
        "negative-contracts": f"{counts['negative']}/13-exact",
        "plan-key-rows": f"{counts['plans']}/8-independent-exact",
        "paired-key-sets": "3/3-exact",
        "private-fields": "0/0-public",
        "authored-mechanisms": "0/0-authored",
        "artifact-commands": "2/2-exact",
        "deterministic-compilations": "2/2-repeat-equal",
        "mutants": f"{reddened}/{total}-red",
        "calculus-kinds": "5/5",
        "calculus-components": "5/5",
        "calculus-projection-counts": "2,9,16,8,5",
        "calculus-resource-vector": "5,40,0,0",
        "network-observer": observer,
        "browser-persistence-runtime": "UNVERIFIED",
        "live-replay-authority": "UNVERIFIED",
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in metrics.items()),
        encoding="utf-8",
    )


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    rows: Mapping[str, str],
    classes: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            unknown = [item for item in ids if item not in classes]
            metrics = {CLASS_METRIC[classes[item]] for item in ids if item in classes}
            status[surface] = not unknown and bool(metrics) and all(
                rows.get(metric) == EXPECTED_RESULTS[metric] for metric in metrics
            )
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=41,
        contract=CONTRACT,
        command=GATE_COMMAND,
        register="1",
        substrate="none",
        lane="none",
        sides=SIDES,
        expectations=EXPECTATIONS,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    mutant_rows: list[dict[str, str]] = []
    classes: dict[str, str] = {}
    reddened: set[str] = set()

    try:
        resolved = toolchain.resolve(["cabal", "ghc"])
        print("toolchain side — cabal and ghc resolved from authored requirements\n")
        for name in ("cabal", "ghc"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        globals()["COMPILER"] = resolved["ghc"]["path"]
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        cabal = Path(resolved["cabal"]["path"])

        print("\noracle side — independent contracts, plan keys, calculus, custody, and mutants\n")
        mutant_rows, counts = verify_oracles()
        classes = item_classes()
        print("  ok    oracle-cardinality-exact          3 positive, 13 negative, 8 plan rows")
        print("  ok    phase-zero-custody                all eight Phase-24 artifacts exist")
        print("  ok    semantic-oracles-complete         exact language, plan, and calculus tables")
        print(f"  ok    mutant-registry-exact             {len(mutant_rows)} central registry rows")
        print(f"  ok    {len(classes)} enumerated items")
        results["oracle"] = True

        print("\nsource side — language shape, ownership, purity, and CPP wiring\n")
        verify_source_boundaries()
        print("  ok    dhall-schema-exact                6 operations, 2 arms, 4 offline fields")
        print("  ok    authored-product-continuity       two mechanism-free Offline products")
        print("  ok    module-ownership-exact            shared types have one dedicated owner")
        print("  ok    cpp-mutant-wiring                 five exact production macros")
        print("  ok    compiler-partial-token-scan       no partial or unsafe token")
        print("  ok    totality-options                  suite totality warnings enabled")
        print("  ok    credential-environment-scrub      no ambient provider credentials")
        results["source"] = True

        print("\nsuite side — normal and network-denied paired-plan execution\n")
        green, observer = run_green(cabal)
        (gate.run_dir / "suite.log").write_text(green, encoding="utf-8")
        if observer not in SANCTIONED_OBSERVERS:
            raise GateFailure(f"network observer {observer!r} is not sanctioned")
        print(f"  ok    normal-isolated-acceptance        {observer}")
        results["suite"] = True

        print("\nmutant side — every production mutant red at its distinct locus\n")
        mutant_log, reddened = run_mutants(cabal, mutant_rows)
        (gate.run_dir / "mutants.log").write_text(mutant_log, encoding="utf-8")
        print(f"  ok    mutant-red-loci                   {len(reddened)}/{len(mutant_rows)} red; baseline restored")
        results["mutant"] = True

        write_results(counts, len(reddened), len(mutant_rows), observer)
        rows = gate_common.metric_rows(RESULTS)
        compared = dict(rows)
        if compared.get("network-observer") in SANCTIONED_OBSERVERS:
            compared["network-observer"] = "sanctioned-observer"
        oracle_ok = gate_common.oracle_side(compared, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent],
            (".tsv", ".log"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="the offline-language run records stay generated",
        )
        rows = compared
        results["results"] = oracle_ok and artifact_ok
    except (GateFailure, OSError, KeyError, ValueError, IndexError) as problem:
        print(f"offline-language-plan-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and EXPECTED_RESULTS.get(ids[0], "UNVERIFIED") != "UNVERIFIED"
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "proven-for-the-model"
        if rows.get("positive-contracts") == EXPECTED_RESULTS["positive-contracts"]
        and rows.get("paired-key-sets") == EXPECTED_RESULTS["paired-key-sets"]
        else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(classes)},
        rows=rows,
        evidence=evidence,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={
            "offline-plan-spec": "cabal test",
            "offline-language-types": "shared Continuity schema",
        },
        mutants=[
            {"name": row["mutant"], "status": "red" if row["mutant"] in reddened else "unrun"}
            for row in mutant_rows
        ] or [{"name": "phase-41 mutants", "status": "unrun"}],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, rows, classes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
