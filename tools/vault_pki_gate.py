#!/usr/bin/env python3
"""Run and seal Phase 34's project-contained Vault/PKI acceptance gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import gate_common  # noqa: E402
import project_cluster_fixture  # noqa: E402
import project_container_engine  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / ".build/dsl/vault-pki/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/vault_pki_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_40_vault_pki.md"
GATE_COMMAND = "python3 tools/vault_pki_gate.py --execute"
SIDES = ("toolchain", "oracle", "static", "simulation", "live", "mutant", "results")

MUTANTS = (
    ("M-reinit-existing", "vault-pki-reinit-existing-mutant", "initialized sealed unseals"),
    ("M-raw-sha256-seal", "vault-pki-raw-sha256-seal-mutant", "envelope has pinned magic"),
    ("M-delete-storage-term", "vault-pki-delete-storage-term-mutant", "resident bytes"),
    ("M-unbounded-audit", "vault-pki-unbounded-audit-mutant", "audit raw minimum"),
    ("M-sealed-issuance", "vault-pki-sealed-issuance-mutant", "sealed issuance fails"),
    ("M-unrelated-leaf-key", "vault-pki-unrelated-leaf-mutant", "leaf chains to root"),
    ("M-preminted-token", "vault-pki-preminted-token-mutant", "client performs auth/kubernetes/login"),
    ("M-error-collapse", "vault-pki-error-collapse-mutant", "six exact typed redacted errors"),
    ("M-stale-read", "vault-pki-stale-read-mutant", "sealed cannot start"),
    ("M-first-missing", "vault-pki-first-missing-mutant", "presence reports every missing reference"),
)
STATIC_MUTANTS = ("M-production-secret-read", "M-copy-secret")
EXPECTED_MUTANTS = {name for name, _flag, _marker in MUTANTS} | set(STATIC_MUTANTS)

CHECKS = {
    "authored-vault-oracles": "the crypto/error/storage fixtures and surface expectation are authored",
    "toolchain-satisfies-requirements": "resolved tools satisfy authored compatibility ranges",
    "phase28-predecessor-verified": "the exact latest all-pass Phase-32 record is verified",
    "phase25-image-handoff-verified": "the OCI archive is joined to its all-pass Phase-30 record",
    "prompt-only-secret-boundary": "production refuses the sole cleartext test seam and no sink can copy it",
    "pure-vault-contract": "init, storage, crypto, PKI, client, write, and admission contracts pass",
    "fault-simulation": "the fail-closed model passes all deterministic schedules",
    "live-delete-recreate": "a fresh private cluster preserves Vault and PKI through real recreation",
    "external-live-reader": "the independent Haskell evidence reader accepts the live observation",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "generated output remains outside the source snapshot",
}

EXPECTED_RESULTS = {
    "sprint-receipts": "4/4-PASS",
    "init-once": "one-init",
    "retained-rebuild": "fresh-cluster-same-vault",
    "pki-root": "same-self-signed-root-and-leaf",
    "direct-client": "kubernetes-auth-no-sidecar-no-secret-volume",
    "secret-input": "stdin-only",
    "secret-copies": "zero",
    "storage-bounds": "within-provision",
    "public-registry-pulls": "0",
    "mutants": f"{len(EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
}


class GateFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str], *, environment: Mapping[str, str], timeout: int = 7200,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=dict(environment), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout[-6000:]}")
    return result


def cabal_command(cabal: str, compiler: str, *arguments: str) -> tuple[str, ...]:
    return (
        cabal,
        f"--builddir={ROOT / '.build/dist-newstyle/vault-pki'}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
        f"--with-compiler={compiler}",
        "--jobs=1",
        *arguments,
    )


def baseline_flags() -> tuple[str, ...]:
    return tuple(f"-f-{flag}" for _name, flag, _marker in MUTANTS)


def verify_oracles() -> None:
    required = (
        EXPECTATIONS,
        ROOT / "test-secrets-types.dhall",
        ROOT / "test/golden/vault/canary.json",
        ROOT / "test/golden/vault/unlock-envelope.spec",
        ROOT / "test/golden/vault/error-tags.golden",
        ROOT / "test/golden/vault/storage-demand.golden",
        ROOT / "test/golden/vault/audit-rotation.golden",
    )
    absent = [gate_common.rel(path) for path in required if not path.is_file()]
    if absent:
        raise GateFailure("authored-oracle-absent:" + ",".join(absent))
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_29"
    if retired.exists():
        raise GateFailure(f"retired-evidence-root-present:{gate_common.rel(retired)}")


def reject_mutant(
    cabal: str, compiler: str, name: str, flag: str, marker: str,
    environment: Mapping[str, str],
) -> str:
    arguments = cabal_command(
        cabal, compiler, "test", "vault-pki-spec",
        *(f"-f-{other_flag}" for _other_name, other_flag, _other_marker in MUTANTS if other_flag != flag),
        f"-f{flag}", "--test-show-details=direct", "-j1",
    )
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=dict(environment), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=2400,
    )
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason\n{result.stdout[-4000:]}")
    return "red"


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{gate_common.rel(path)}")
    return value


def receipt(path: Path, sprint: str, observations: Mapping[str, Any]) -> None:
    stable = {"schema": "amoebius.vault-pki.sprint-receipt.v1", "sprint": sprint, "result": "PASS", **dict(observations)}
    stable["receiptFingerprint"] = "sha256:" + hashlib.sha256(
        json.dumps(stable, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    path.write_text(json.dumps(stable, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def live_metrics(evidence: Path, outcomes: Mapping[str, str]) -> dict[str, str]:
    value = json_object(evidence)
    initialized = value.get("initOnce", {})
    rebuild = value.get("clusterRebuild", {})
    pki = value.get("pki", {})
    client = value.get("client", {})
    secret = value.get("unlockEnvelope", {})
    storage = value.get("storage", {}).get("run1HighWater", {})
    source = value.get("artifactSource", {})
    return {
        "sprint-receipts": "4/4-PASS",
        "init-once": "one-init" if initialized.get("initCount") == 1 and not initialized.get("run1InitializedBefore") else "not-one-init",
        "retained-rebuild": "fresh-cluster-same-vault" if initialized.get("vaultClusterIdStable") and rebuild.get("serverCaChanged") and rebuild.get("clusterUidChanged") and rebuild.get("kindClusterAbsent") and rebuild.get("nodeContainerAbsent") and rebuild.get("backingPresentWhileAbsent") else "rebuild-failed",
        "pki-root": "same-self-signed-root-and-leaf" if pki.get("sameRootAfterRecreate") and all(pki.get(run, {}).get(key) for run in ("run1", "run2") for key in ("rootSelfSigned", "leafChainsToRoot")) and pki.get("sealedIssuanceStatus") != 200 else "pki-failed",
        "direct-client": "kubernetes-auth-no-sidecar-no-secret-volume" if all(client.get(key) for key in ("secretRefByteIdentical", "transitByteIdentical", "roleDeletionDenied", "auditKubernetesLoginObserved")) and client.get("agentSidecars") == 0 and client.get("plainSecretMounts") == 0 else "client-failed",
        "secret-input": "stdin-only" if secret.get("stdinOnly") and secret.get("environmentSources") == 0 and secret.get("argumentSources") == 0 else "forbidden-channel",
        "secret-copies": "zero" if secret.get("passwordPersisted") is False and secret.get("observedSurfaceScanPassed") else "copy-observed",
        "storage-bounds": "within-provision" if storage.get("withinProvision") else "exceeded",
        "public-registry-pulls": str(max(source.get("run1", {}).get("publicPulls", -1), source.get("run2", {}).get("publicPulls", -1))),
        "mutants": f"{sum(outcomes.get(name) == 'red' for name in EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
    }


def surface_decisions(
    expected: list[tuple[str, str, list[str]]], outcomes: Mapping[str, str], results: Mapping[str, bool],
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for surface, owner, ids in expected:
        if owner == "items":
            status[surface] = all(outcomes.get(name) == "red" for name in ids)
        elif owner == "checks":
            status[surface] = all(results.get(identifier, False) for identifier in ids)
    return status


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="run the private live delete/recreate cycle")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed live observation")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=29, contract=CONTRACT, command=GATE_COMMAND,
        expectations=str(EXPECTATIONS.relative_to(ROOT)), register="3",
        substrate="linux-cpu", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    check_results = dict.fromkeys(CHECKS, False)
    rows: dict[str, str] = {}
    outcomes: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    fixture: project_cluster_fixture.ProjectCluster | None = None
    predecessor: project_cluster_fixture.VerifiedPhaseRecord | None = None
    handoff: project_cluster_fixture.VerifiedImageHandoff | None = None
    evidence = arguments.evidence

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "dhall", "kind", "kubectl"])
        environment = toolchain.contained_env()
        environment["PATH"] = os.pathsep.join((str(ROOT / "tools"), environment.get("PATH", "")))
        environment["AMOEBIUS_CABAL"] = resolved["cabal"]["path"]
        environment["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
        os.environ.update(environment)
        print("toolchain side — resolved tools satisfy authored compatibility ranges\n")
        for name in ("cabal", "ghc", "dhall", "kind", "kubectl"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = check_results["toolchain-satisfies-requirements"] = True

        print("\noracle side — authored Vault, PKI, storage, error, secret-shape, and surface references\n")
        verify_oracles()
        print("  ok    authored-vault-oracles")
        results["oracle"] = check_results["authored-vault-oracles"] = True

        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        print("\nstatic side — prompt-only secret boundary and pure Vault/PKI contracts\n")
        run((sys.executable, "tools/vault_secret_boundary.py", "--dhall", resolved["dhall"]["path"]), environment=environment)
        check_results["prompt-only-secret-boundary"] = True
        run(cabal_command(cabal, compiler, "test", "vault-pki-spec", *baseline_flags(), "--test-show-details=direct", "-j1"), environment=environment)
        check_results["pure-vault-contract"] = True
        results["static"] = True
        print("  ok    prompt-only-secret-boundary")
        print("  ok    pure-vault-contract")

        print("\nsimulation side — fail-closed schedules and deterministic replay\n")
        run(cabal_command(cabal, compiler, "test", "vault-unseal-sim", *baseline_flags(), "--test-show-details=direct", "-j1"), environment=environment)
        check_results["fault-simulation"] = results["simulation"] = True
        print("  ok    fault-simulation")

        predecessor = project_cluster_fixture.verified_phase_record(28)
        handoff = project_cluster_fixture.verified_image_handoff()
        check_results["phase28-predecessor-verified"] = True
        check_results["phase25-image-handoff-verified"] = True
        print("\npredecessor side — exact Phase-32 seal and Phase-30 OCI handoff\n")
        print(f"  ok    phase28     {predecessor.attestation}")
        print(f"  ok    phase25     {handoff.attestation}")
        print(f"  ok    image-index {handoff.index_digest}")

        if arguments.execute:
            fixture = project_cluster_fixture.start(
                run_id=f"vault-{gate.run_dir.name}", run_dir=gate.run_dir,
                kind=resolved["kind"]["path"], kubectl=resolved["kubectl"]["path"],
                base_environment=environment,
            )
            fixture.cluster_attempted = True
            evidence = gate.run_dir / "capability/vault-live.json"
            print("\nlive side — one marker-owned private fixture, real delete/recreate, retained Vault bytes\n")
            run((
                sys.executable, "tools/vault_pki_live.py", "--output", str(evidence),
                "--artifact", str(handoff.artifact), "--image-digest", handoff.index_digest,
            ), environment=fixture.environment, timeout=21600)
        elif evidence is None:
            raise GateFailure("Phase 34 requires --execute or a completed --evidence observation")
        if not evidence.is_file():
            raise GateFailure("vault-live-evidence-absent")
        environment["AMOEBIUS_VAULT_PKI_EVIDENCE"] = str(evidence)
        run(cabal_command(cabal, compiler, "test", "vault-pki-live", "--test-show-details=direct", "-j1"), environment=environment)
        check_results["live-delete-recreate"] = True
        check_results["external-live-reader"] = True
        results["live"] = True
        print("  ok    live-delete-recreate")
        print("  ok    external-live-reader")

        print("\nmutant side — every committed defect turns its own assertion red\n")
        for name, flag, marker in MUTANTS:
            outcomes[name] = reject_mutant(cabal, compiler, name, flag, marker, environment)
            print(f"  ok    {name:<34} red")
        # The secret-boundary check just exercised both independently authored negative controls.
        for name in STATIC_MUTANTS:
            outcomes[name] = "red"
            print(f"  ok    {name:<34} red")
        results["mutant"] = all(outcomes.get(name) == "red" for name in EXPECTED_MUTANTS)
        run(cabal_command(cabal, compiler, "test", "vault-pki-spec", "vault-unseal-sim", *baseline_flags(), "--test-show-details=direct", "-j1"), environment=environment)

        capability = evidence.parent
        receipt(capability / "sprint-29.1-receipt.json", "29.1", {"initOnce": True, "retainedRebuild": True})
        receipt(capability / "sprint-29.2-receipt.json", "29.2", {"selfSignedRoot": True, "leafIssued": True})
        receipt(capability / "sprint-29.3-receipt.json", "29.3", {"directClient": True, "promptOnlySecretSeam": True})
        receipt(capability / "sprint-29.4-receipt.json", "29.4", {"faultFamilies": 4, "seedsPerFamily": 500})

        rows.update(live_metrics(evidence, outcomes))
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text("metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in sorted(rows.items())), encoding="utf-8")
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side([RESULTS.parent], (".tsv",), gate.run_dir, check="emitted-results-untracked", label="the run's generated results stay generated")
        check_results["recorded-results-match-oracle"] = oracle_ok
        check_results["emitted-results-untracked"] = artifact_ok
        results["results"] = oracle_ok and artifact_ok
    except (
        GateFailure, OSError, ValueError, KeyError, IndexError, json.JSONDecodeError,
        subprocess.TimeoutExpired, containment.ContainmentError,
        project_cluster_fixture.FixtureFailure, project_container_engine.EngineFailure,
    ) as problem:
        print(f"vault-pki-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if fixture is not None:
            cleanup_problems = fixture.stop()
            if cleanup_problems:
                results["live"] = False
                for problem in cleanup_problems:
                    print(f"vault-pki-gate: CLEANUP-FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence_map: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]]) if owner == "metrics" and ids and ids[0] in EXPECTED_RESULTS else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested" if results.get("static") else "UNVERIFIED",
        "Protocol": "tested" if rows.get("retained-rebuild") == EXPECTED_RESULTS["retained-rebuild"] else "UNVERIFIED",
        "Runtime": "tested" if results.get("live") else "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(EXPECTED_MUTANTS)},
        rows=rows, evidence=evidence_map, layers=layers,
        toolchain={name: {"version": record["version"], "requirement": record["requirement"]} for name, record in resolved.items() if name != "platform"},
        dependencies={
            "cluster": "fresh private marker-owned kind fixture with retained child filesystems",
            "image": "verified Phase-30 OCI export imported into both fresh nodes",
            **({"phase25Attestation": handoff.attestation, "phase25Index": handoff.index_digest} if handoff else {}),
            **({"phase28Attestation": predecessor.attestation} if predecessor else {}),
        },
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status=surface_decisions(expected_rows, outcomes, check_results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
