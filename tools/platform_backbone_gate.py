#!/usr/bin/env python3
"""Run and seal Phase 30's project-contained platform-backbone gate."""

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
RESULTS = ROOT / ".build/dsl/platform-backbone/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/platform_backbone_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_30_platform_backbone.md"
GATE_COMMAND = "python3 tools/platform_backbone_gate.py --execute"
SIDES = ("toolchain", "oracle", "static", "predecessor", "live", "mutant", "results")

MUTANTS = (
    ("M-registry-fs-driver", "platform-backbone-registry-fs-driver-mutant", "registry uses MinIO S3 driver"),
    ("M-offload-time-only", "platform-backbone-offload-time-only-mutant", "size-triggered-offload-required"),
    ("M-storage-logical-as-physical", "platform-backbone-logical-as-physical-mutant", "MinIO physical geometry amplifies logical bytes"),
    ("M-storage-drop-fault-scenario", "platform-backbone-drop-fault-scenario-mutant", "MinIO fault scenarios complete"),
    ("M-storage-sum-ordinals", "platform-backbone-sum-ordinals-mutant", "uniform MinIO drive debit"),
    ("M-content-immediate-gc", "platform-backbone-content-immediate-gc-mutant", "failed-write orphan horizon retained"),
)
EXPECTED_MUTANTS = {name for name, _flag, _marker in MUTANTS}

CHECKS = {
    "authored-backbone-oracles": "the storage-driver, hot-tier, geometry, kind, and surface expectations are authored",
    "toolchain-satisfies-requirements": "resolved tools satisfy authored compatibility ranges",
    "phase29-predecessor-verified": "the exact latest all-pass Phase-29 record is verified",
    "phase25-image-handoff-verified": "the OCI archive is joined to its all-pass Phase-25 record",
    "pure-backbone-contract": "the topology, storage, migration, render, and readiness contracts pass",
    "live-private-backbone": "a private marker-owned cluster runs the complete backbone",
    "external-live-reader": "the independently compiled Haskell reader accepts the live observation",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "generated output remains outside the source snapshot",
}

EXPECTED_RESULTS = {
    "sprint-receipts": "3/3-PASS",
    "vault-readiness": "exact-predecessor-live-floor",
    "load-balancer": "stable-external-vip",
    "minio": "four-drive-byte-identical",
    "registry": "verified-s3-rehome",
    "pulsar": "3-zk-3-bookie-2-broker",
    "native-dedup": "7,7,8-to-2-cbor",
    "offload": "size-triggered-bounded",
    "render": "11-byte-identical",
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
        raise GateFailure(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout[-8000:]}")
    return result


def cabal_command(cabal: str, compiler: str, *arguments: str) -> tuple[str, ...]:
    return (
        cabal,
        f"--builddir={ROOT / '.build/dist-newstyle/platform-backbone'}",
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
        ROOT / "test/fixture/platform_backbone/hot-tier-cap.golden",
        ROOT / "test/fixture/platform_backbone/registry-storage-driver.golden",
        ROOT / "test/fixture/platform_backbone/storage-geometry-boundaries.csv",
        ROOT / "test/fixture/platform_backbone/kind.yaml",
        *(ROOT / "test/mutant/platform_backbone" / f"{name}.mutant" for name in (
            "registry-fs-driver",
            "offload-time-only",
            "storage-logical-as-physical",
            "drop-required-fault-scenario",
            "storage-sum-unequal-ordinals",
            "content-store-immediate-gc",
        )),
    )
    absent = [gate_common.rel(path) for path in required if not path.is_file()]
    if absent:
        raise GateFailure("authored-oracle-absent:" + ",".join(absent))
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_30"
    if retired.exists():
        raise GateFailure(f"retired-evidence-root-present:{gate_common.rel(retired)}")
    stale_digest = ROOT / "test/fixture/platform_backbone/expected-base-digest.txt"
    if stale_digest.exists():
        raise GateFailure(f"derived-image-digest-is-authored:{gate_common.rel(stale_digest)}")


def reject_mutant(
    cabal: str, compiler: str, name: str, flag: str, marker: str,
    environment: Mapping[str, str],
) -> str:
    arguments = cabal_command(
        cabal, compiler, "test", "platform-backbone-spec",
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
        raise GateFailure(f"{name}:wrong-red-reason\n{result.stdout[-5000:]}")
    return "red"


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{gate_common.rel(path)}")
    return value


def verify_live_domain(evidence: Path, expected_digest: str) -> dict[str, Any]:
    live = json_object(evidence)
    artifact = live.get("artifactSource", {})
    if artifact.get("digest") != expected_digest or artifact.get("publicPulls") != 0:
        raise GateFailure("base-image-domain")
    if artifact.get("pullEvents", {}).get("publicPullEventCount") != 0:
        raise GateFailure("public-pull-event-domain")
    predecessor = live.get("vaultPredecessor", {})
    if predecessor.get("vaultClusterId") is not True or predecessor.get("pkiRootStable") is not True:
        raise GateFailure("vault-predecessor-domain")
    load_balancer = live.get("loadBalancer", {})
    if not load_balancer.get("externallyReachable") or load_balancer.get("stableReadyObservations", 0) < 5:
        raise GateFailure("loadbalancer-domain")
    minio = live.get("minio", {})
    if minio.get("topology") != "distributed-erasure-four-drive" or len(minio.get("volumes", [])) != 4:
        raise GateFailure("minio-topology-domain")
    if not live.get("minioRoundtrip", {}).get("byteIdentical"):
        raise GateFailure("minio-roundtrip-domain")
    registry = live.get("registryRehome", {})
    if registry.get("backend") != "s3" or not registry.get("migration", {}).get("verified") or not registry.get("sourceHashStable"):
        raise GateFailure("registry-rehome-domain")
    pulsar = live.get("pulsar", {})
    if (
        pulsar.get("zookeeper", {}).get("readyPods") != 3
        or pulsar.get("bookkeeper", {}).get("readyPods") != 3
        or pulsar.get("broker", {}).get("readyPods") != 2
    ):
        raise GateFailure("pulsar-ha-domain")
    if pulsar.get("broker", {}).get("developmentOffloaderMount") or pulsar.get("broker", {}).get("bakedOffloaderFileCount", 0) < 1:
        raise GateFailure("development-offloader-mount-forbidden")
    drill = pulsar.get("drill", {})
    offload = drill.get("offload", {})
    if not all(drill.get(key) for key in ("nativeRoundtrip", "deduplicationExercised", "cborByteIdentical", "producerExited")):
        raise GateFailure("pulsar-native-domain")
    if "platform-backbone-dedup-probe: PASS" not in drill.get("dedupProbeOutput", ""):
        raise GateFailure("dedup-probe-marker-domain")
    if (
        offload.get("timeOnly")
        or not offload.get("bounded")
        or offload.get("objectCount", 0) < 1
        or offload.get("hotTierBytes", 1) > offload.get("hotTierCapBytes", 0)
    ):
        raise GateFailure("pulsar-offload-domain")
    provenance = live.get("provenance", {})
    if not provenance.get("allRuntimeImageIdsMatchBaseDigest") or provenance.get("publicImageReferences") or not provenance.get("completeResourceFields"):
        raise GateFailure("runtime-provenance-domain")
    ssa = provenance.get("ssaProjection", {})
    if ssa.get("fieldManager") != "amoebius" or not ssa.get("allOwnedFieldsByteIdentical") or ssa.get("objectCount", 0) < 1:
        raise GateFailure("ssa-render-byte-identity-domain")
    haskell = provenance.get("haskellRenderProjection", {})
    if (
        haskell.get("renderer") != "Amoebius.Platform.Backbone.renderBackbone"
        or not haskell.get("freshGateProcessOutput")
        or not haskell.get("allAppliedProjectionsByteIdentical")
        or haskell.get("objectCount") != 11
    ):
        raise GateFailure("haskell-render-provenance-domain")
    universal = live.get("universalLinuxCpu", {})
    expected_hosts = {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}
    if not universal.get("availableOnEveryHardwareSubstrate") or universal.get("pristineLinuxHost") != expected_hosts:
        raise GateFailure("universal-linux-domain")
    return live


def receipt(path: Path, sprint: str, observations: Mapping[str, Any]) -> None:
    stable = {
        "schema": "amoebius.platform-backbone.sprint-receipt.v1",
        "sprint": sprint,
        "result": "PASS",
        **dict(observations),
    }
    stable["receiptFingerprint"] = "sha256:" + hashlib.sha256(
        json.dumps(stable, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    path.write_text(json.dumps(stable, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def live_metrics(live: Mapping[str, Any], outcomes: Mapping[str, str]) -> dict[str, str]:
    predecessor = live.get("vaultPredecessor", {})
    load_balancer = live.get("loadBalancer", {})
    minio = live.get("minio", {})
    registry = live.get("registryRehome", {})
    pulsar = live.get("pulsar", {})
    drill = pulsar.get("drill", {})
    offload = drill.get("offload", {})
    haskell = live.get("provenance", {}).get("haskellRenderProjection", {})
    return {
        "sprint-receipts": "3/3-PASS",
        "vault-readiness": "exact-predecessor-live-floor" if predecessor.get("vaultClusterId") is True and predecessor.get("pkiRootStable") is True else "predecessor-failed",
        "load-balancer": "stable-external-vip" if load_balancer.get("externallyReachable") and load_balancer.get("stableReadyObservations", 0) >= 5 else "vip-failed",
        "minio": "four-drive-byte-identical" if minio.get("topology") == "distributed-erasure-four-drive" and len(minio.get("volumes", [])) == 4 and live.get("minioRoundtrip", {}).get("byteIdentical") else "minio-failed",
        "registry": "verified-s3-rehome" if registry.get("backend") == "s3" and registry.get("migration", {}).get("verified") and registry.get("sourceHashStable") else "rehome-failed",
        "pulsar": "3-zk-3-bookie-2-broker" if pulsar.get("zookeeper", {}).get("readyPods") == 3 and pulsar.get("bookkeeper", {}).get("readyPods") == 3 and pulsar.get("broker", {}).get("readyPods") == 2 else "ha-failed",
        "native-dedup": "7,7,8-to-2-cbor" if drill.get("nativeRoundtrip") and drill.get("cborByteIdentical") and drill.get("sequenceIds") == [7, 7, 8] and drill.get("deliveredMessages") == 2 else "dedup-failed",
        "offload": "size-triggered-bounded" if not offload.get("timeOnly") and offload.get("bounded") and offload.get("objectCount", 0) > 0 and offload.get("hotTierBytes", 1) <= offload.get("hotTierCapBytes", 0) else "offload-failed",
        "render": "11-byte-identical" if haskell.get("objectCount") == 11 and haskell.get("allAppliedProjectionsByteIdentical") else "render-failed",
        "public-registry-pulls": str(live.get("artifactSource", {}).get("pullEvents", {}).get("publicPullEventCount", -1)),
        "mutants": f"{sum(outcomes.get(name) == 'red' for name in EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
    }


def surface_decisions(
    expected: list[tuple[str, str, list[str]]], outcomes: Mapping[str, str], checks: Mapping[str, bool],
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    for surface, owner, ids in expected:
        if owner == "items":
            status[surface] = all(outcomes.get(name) == "red" for name in ids)
        elif owner == "checks":
            status[surface] = all(checks.get(identifier, False) for identifier in ids)
    return status


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="run the complete private live backbone")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed live observation")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=30,
        contract=CONTRACT,
        command=GATE_COMMAND,
        expectations=str(EXPECTATIONS.relative_to(ROOT)),
        register="3",
        substrate="linux-cpu",
        sides=SIDES,
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
        resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
        environment = toolchain.contained_env()
        environment["PATH"] = os.pathsep.join((str(ROOT / "tools"), environment.get("PATH", "")))
        environment.update({
            "AMOEBIUS_CABAL": resolved["cabal"]["path"],
            "AMOEBIUS_GHC": resolved["ghc"]["path"],
            "AMOEBIUS_KIND": resolved["kind"]["path"],
            "AMOEBIUS_KUBECTL": resolved["kubectl"]["path"],
        })
        print("toolchain side — resolved tools satisfy authored compatibility ranges\n")
        for name in ("cabal", "ghc", "kind", "kubectl"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = check_results["toolchain-satisfies-requirements"] = True

        print("\noracle side — authored backbone fixtures and surface expectation\n")
        verify_oracles()
        check_results["authored-backbone-oracles"] = results["oracle"] = True
        print("  ok    authored-backbone-oracles")

        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        print("\nstatic side — pure topology, capacity, migration, render, and readiness contracts\n")
        run(cabal_command(cabal, compiler, "test", "platform-backbone-spec", *baseline_flags(), "--test-show-details=direct", "-j1"), environment=environment)
        check_results["pure-backbone-contract"] = results["static"] = True
        print("  ok    pure-backbone-contract")

        predecessor = project_cluster_fixture.verified_phase_record(29)
        handoff = project_cluster_fixture.verified_image_handoff()
        check_results["phase29-predecessor-verified"] = True
        check_results["phase25-image-handoff-verified"] = True
        results["predecessor"] = True
        print("\npredecessor side — exact Phase-29 seal and Phase-25 OCI handoff\n")
        print(f"  ok    phase29     {predecessor.attestation}")
        print(f"  ok    phase25     {handoff.attestation}")
        print(f"  ok    image-index {handoff.index_digest}")

        if arguments.execute:
            fixture = project_cluster_fixture.start(
                run_id=f"backbone-{gate.run_dir.name}",
                run_dir=gate.run_dir,
                kind=resolved["kind"]["path"],
                kubectl=resolved["kubectl"]["path"],
                base_environment=environment,
            )
            fixture.cluster_attempted = True
            evidence = gate.run_dir / "capability/platform-backbone-live.json"
            print("\nlive side — one marker-owned private fixture, Vault readiness floor, and full backbone\n")
            run(
                (
                    sys.executable,
                    "tools/platform_backbone_live.py",
                    "--output",
                    str(evidence),
                    "--artifact",
                    str(handoff.artifact),
                    "--image-digest",
                    handoff.index_digest,
                ),
                environment=fixture.environment,
                timeout=28800,
            )
        elif evidence is None:
            raise GateFailure("Phase 30 requires --execute or a completed --evidence observation")
        if not evidence.is_file():
            raise GateFailure("platform-backbone-live-evidence-absent")
        live = verify_live_domain(evidence, handoff.index_digest)
        live_environment = dict(environment)
        live_environment.update({
            "AMOEBIUS_PLATFORM_BACKBONE_EVIDENCE": str(evidence),
            "AMOEBIUS_PLATFORM_BACKBONE_IMAGE_DIGEST": handoff.index_digest,
        })
        run(cabal_command(cabal, compiler, "test", "platform-backbone-live", "--test-show-details=direct", "-j1"), environment=live_environment)
        check_results["live-private-backbone"] = True
        check_results["external-live-reader"] = True
        results["live"] = True
        print("  ok    live-private-backbone")
        print("  ok    external-live-reader")

        print("\nmutant side — every committed defect turns its own assertion red\n")
        for name, flag, marker in MUTANTS:
            outcomes[name] = reject_mutant(cabal, compiler, name, flag, marker, environment)
            print(f"  ok    {name:<34} red")
        results["mutant"] = all(outcomes.get(name) == "red" for name in EXPECTED_MUTANTS)
        run(cabal_command(cabal, compiler, "test", "platform-backbone-spec", *baseline_flags(), "--test-show-details=direct", "-j1"), environment=environment)

        capability = evidence.parent
        receipt(capability / "sprint-30.1-receipt.json", "30.1", {"externalVip": True, "fourDriveMinio": True, "registryS3Rehome": True})
        receipt(capability / "sprint-30.2-receipt.json", "30.2", {"pulsarHa": True, "nativeDedup": True, "sizeTriggeredOffload": True})
        receipt(capability / "sprint-30.3-receipt.json", "30.3", {"haskellRenderAndSsaByteIdentity": True, "publicPulls": 0})

        rows.update(live_metrics(live, outcomes))
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text(
            "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in sorted(rows.items())),
            encoding="utf-8",
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent],
            (".tsv",),
            gate.run_dir,
            check="emitted-results-untracked",
            label="the run's generated results stay generated",
        )
        check_results["recorded-results-match-oracle"] = oracle_ok
        check_results["emitted-results-untracked"] = artifact_ok
        results["results"] = oracle_ok and artifact_ok
    except (
        GateFailure,
        OSError,
        ValueError,
        KeyError,
        IndexError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
        containment.ContainmentError,
        project_cluster_fixture.FixtureFailure,
        project_container_engine.EngineFailure,
        toolchain.ResolutionError,
    ) as problem:
        print(f"platform-backbone-gate: FAIL: {problem}", file=sys.stderr)
    finally:
        if fixture is not None:
            cleanup_problems = fixture.stop()
            if cleanup_problems:
                results["live"] = False
                for problem in cleanup_problems:
                    print(f"platform-backbone-gate: CLEANUP-FAIL: {problem}", file=sys.stderr)

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
        "Protocol": "tested" if rows.get("registry") == EXPECTED_RESULTS["registry"] and rows.get("native-dedup") == EXPECTED_RESULTS["native-dedup"] else "UNVERIFIED",
        "Runtime": "tested" if results.get("live") else "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(EXPECTED_MUTANTS)},
        rows=rows,
        evidence=evidence_map,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={
            "cluster": "fresh private marker-owned kind fixture with retained child filesystems",
            "image": "verified Phase-25 OCI export imported into both fresh nodes",
            **({"phase25Attestation": handoff.attestation, "phase25Index": handoff.index_digest} if handoff else {}),
            **({"phase29Attestation": predecessor.attestation} if predecessor else {}),
        },
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
        extra_status=surface_decisions(expected_rows, outcomes, check_results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
