#!/usr/bin/env python3
"""Run and seal Phase 30's project-contained platform-backbone gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
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
import platform_backbone_service_census
import platform_backbone_hot_observer  # noqa: E402
import platform_backbone_zookeeper_observer
import platform_backbone_history_store_observer
import platform_backbone_storage_observer


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / ".build/dsl/platform-backbone/phase-results.tsv"
EXPECTATIONS = ROOT / "test/oracle/platform_backbone_surfaces.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_30_platform_backbone.md"
GATE_COMMAND = "python3 tools/platform_backbone_gate.py --execute"
SIDES = ("toolchain", "oracle", "static", "predecessor", "live", "mutant", "results")

MUTANTS = (
    ("M-registry-fs-driver", "platform-backbone-registry-fs-driver-mutant", "registry uses MinIO S3 driver"),
    ("M-offload-time-only", "platform-backbone-offload-time-only-mutant", "size-triggered-offload-required"),
    ("M-storage-logical-as-physical", "platform-backbone-logical-as-physical-mutant", "native MinIO per-object physical geometry"),
    ("M-storage-drop-fault-scenario", "platform-backbone-drop-fault-scenario-mutant", "native MinIO required fault family"),
    ("M-storage-sum-ordinals", "platform-backbone-sum-ordinals-mutant", "native uniform maximum-slot debit"),
    ("M-content-immediate-gc", "platform-backbone-content-immediate-gc-mutant", "all four structural populations stay charged"),
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


def verify_history_store_io(cabal: str, compiler: str, observer: Mapping[str, Any],
                            environment: Mapping[str, str], run_dir: Path) -> dict[str, Any]:
    """Run fresh native transitions under an independent syscall observer."""
    binary = Path(run(cabal_command(cabal, compiler, "list-bin", "test:platform-backbone-spec",
                                   *baseline_flags()), environment=environment).stdout.strip()).resolve(strict=True)
    if not binary.is_relative_to((ROOT / ".build/dist-newstyle").resolve()) or binary.name != "platform-backbone-spec":
        raise GateFailure("history-store-native-observation-binary-domain")
    folder = run_dir / "history-store"
    folder.mkdir()
    trace = folder / "syscalls.log"
    result = run((observer["path"], "-f", "-yy", "-s", "256", "-e",
                  "trace=openat,close,write,fsync,rename,renameat,renameat2,flock,mkdir,unlink",
                  "-o", str(trace), str(binary), "--history-store-only"), environment=environment, timeout=120)
    (folder / "native.log").write_text(result.stdout, encoding="utf-8")
    proof = platform_backbone_history_store_observer.check(trace)
    record = {"observer": dict(observer), "nativeBinarySha256": "sha256:" + gate_common.artifact_policy.digest(str(binary)),
              "traceSha256": "sha256:" + gate_common.artifact_policy.digest(str(trace)), "result": proof}
    (folder / "observation.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return record


def verify_capture_probe(capability: Path, expected_digest: str) -> None:
    observer = json_object(capability / "observer-compile/provenance.json")
    relative = observer.get("captureProbePath", "")
    if (observer.get("imageDigest") != expected_digest or observer.get("targetRelease") != 21
            or not isinstance(relative, str)
            or not re.fullmatch(r"observer-compile/history-capture-[0-9a-f]{16}/provenance\.json", relative)):
        raise GateFailure("capture-probe-image-or-path-provenance")
    path = capability / relative
    if path.is_symlink() or not path.resolve().is_relative_to(capability.resolve()):
        raise GateFailure("capture-probe-path-alias")
    if observer.get("captureProbeSha256") != "sha256:" + gate_common.artifact_policy.digest(str(path)):
        raise GateFailure("capture-probe-record-digest")
    capture = json_object(path)
    classes = path.parent / "classes"
    if classes.is_symlink() or not classes.is_dir():
        raise GateFailure("capture-probe-raw-classes-unavailable")
    entries = list(classes.rglob("*"))
    if any(entry.is_symlink() or (not entry.is_file() and not entry.is_dir()) for entry in entries):
        raise GateFailure("capture-probe-classfile-alias")
    if any(entry.is_file() and entry.suffix != ".class" for entry in entries):
        raise GateFailure("capture-probe-classfile-domain")
    actual_classes = {str(entry.relative_to(classes)): gate_common.artifact_policy.digest(str(entry))
                      for entry in entries if entry.is_file()}
    required_classes = {"org/amoebius/history/CapturedTransaction.class",
                        "org/amoebius/history/CapturedTransaction$BoundedBytes.class",
                        "org/amoebius/history/CaptureRegistry.class",
                        "CaptureProbe.class", "CaptureWithDigestProbe.class", "CaptureRegistryProbe.class", "MatcherProbe.class"}
    if not required_classes <= actual_classes.keys() or capture.get("classFiles") != actual_classes:
        raise GateFailure("capture-probe-classfile-domain-or-digest")
    if (capture.get("sourceSha256") != gate_common.artifact_policy.digest(str(ROOT / "jvm/org/amoebius/history/CapturedTransaction.java"))
            or capture.get("corpusSha256") != gate_common.artifact_policy.digest(str(ROOT / "test/oracle/platform_backbone_zookeeper_capture.json"))
            or capture.get("freshCompilation") is not True or capture.get("independentAssertions", 0) < 689
            or (capture.get("wireCases"), capture.get("boundaryCases"), capture.get("mutationCases")) != (34,41,3)):
        raise GateFailure("capture-probe-source-or-cases")
    for filename, key in (("classes/org/amoebius/history/CapturedTransaction.class", "classSha256"),
                          ("CaptureProbe.java", "generatedProbeSha256"), ("probe.log", "probeLogSha256")):
        if capture.get(key) != gate_common.artifact_policy.digest(str(path.parent / filename)):
            raise GateFailure("capture-probe-artifact-digest:" + key)
    header = (path.parent / "classes/org/amoebius/history/CapturedTransaction.class").read_bytes()[:8]
    result = re.search(rb"^PASS assertions=([0-9]+) cases=34\+41\+3$", (path.parent / "probe.log").read_bytes(), re.MULTILINE)
    if (header[:4] != b"\xca\xfe\xba\xbe" or int.from_bytes(header[6:8], "big") != 65
            or result is None or int(result[1]) != capture["independentAssertions"]):
        raise GateFailure("capture-probe-raw-result-or-class-target")
    rebound = capture.get("digestRebinding", {})
    if (rebound.get("corpusSha256") != gate_common.artifact_policy.digest(str(ROOT / "test/oracle/platform_backbone_zookeeper_capture_with_digest.json"))
            or rebound.get("independentAssertions", 0) < 2547
            or tuple(rebound.get(key) for key in ("wireCases","sequenceCases","denialCases","retryCases")) != (34,7,10,1)):
        raise GateFailure("capture-rebinding-source-or-cases")
    for filename, key in (("CaptureWithDigestProbe.java", "generatedProbeSha256"),
                          ("classes/CaptureWithDigestProbe.class", "classSha256"),
                          ("rebinding-probe.log", "probeLogSha256")):
        if rebound.get(key) != gate_common.artifact_policy.digest(str(path.parent / filename)):
            raise GateFailure("capture-rebinding-artifact-digest:" + key)
    rebound_result = re.search(rb"^PASS withDigest assertions=([0-9]+) cases=34\+7\+10\+1$",
                               (path.parent / "rebinding-probe.log").read_bytes(), re.MULTILINE)
    if rebound_result is None or int(rebound_result[1]) != rebound["independentAssertions"]:
        raise GateFailure("capture-rebinding-raw-result")
    registry = capture.get("registry", {})
    if (registry.get("sourceSha256") != gate_common.artifact_policy.digest(str(ROOT / "jvm/org/amoebius/history/CaptureRegistry.java"))
            or registry.get("corpusSha256") != gate_common.artifact_policy.digest(str(ROOT / "test/oracle/platform_backbone_zookeeper_capture_registry.json"))
            or registry.get("independentAssertions", 0) < 2137
            or tuple(registry.get(key) for key in ("constructorCases", "sequenceCases", "concurrencyCases")) != (4,32,3)):
        raise GateFailure("capture-registry-source-or-cases")
    for filename, key in (("CaptureRegistryProbe.java", "generatedProbeSha256"),
                          ("classes/CaptureRegistryProbe.class", "classSha256"),
                          ("registry-probe.log", "probeLogSha256")):
        if registry.get(key) != gate_common.artifact_policy.digest(str(path.parent / filename)):
            raise GateFailure("capture-registry-artifact-digest:" + key)
    registry_result = re.search(rb"^PASS registry assertions=([0-9]+) cases=4\+32\+3$",
                                (path.parent / "registry-probe.log").read_bytes(), re.MULTILINE)
    if registry_result is None or int(registry_result[1]) != registry["independentAssertions"]:
        raise GateFailure("capture-registry-raw-result")
    matcher = capture.get("registryMatcher", {})
    if (matcher.get("corpusSha256") != gate_common.artifact_policy.digest(str(ROOT / "test/oracle/platform_backbone_zookeeper_capture_registry_matcher.json"))
            or matcher.get("cases") != 3 or matcher.get("independentAssertions", 0) < 18):
        raise GateFailure("capture-registry-matcher-source-or-cases")
    for filename, key in (("MatcherProbe.java", "generatedProbeSha256"),
                          ("classes/MatcherProbe.class", "classSha256"), ("matcher-probe.log", "probeLogSha256")):
        if matcher.get(key) != gate_common.artifact_policy.digest(str(path.parent / filename)):
            raise GateFailure("capture-registry-matcher-artifact-digest:" + key)
    matcher_result = re.search(rb"^PASS matcher assertions=([0-9]+) cases=3$",
                               (path.parent / "matcher-probe.log").read_bytes(), re.MULTILINE)
    if matcher_result is None or int(matcher_result[1]) != matcher["independentAssertions"]:
        raise GateFailure("capture-registry-matcher-raw-result")
    captured_jars = {row["name"]: "sha256:"+row["sha256"] for row in capture.get("jarInputs", [])}
    observer_jars = {row["name"]: row["sha256"] for row in observer.get("classpath", [])}
    directory = capability / "observer-compile/pulsar-lib"
    if directory.is_symlink() or not directory.is_dir():
        raise GateFailure("capture-probe-raw-classpath-unavailable")
    paths = list(directory.glob("*.jar"))
    if any(not jar.is_file() or jar.is_symlink() for jar in paths):
        raise GateFailure("capture-probe-raw-classpath-alias")
    actual_jars = {jar.name: "sha256:" + gate_common.artifact_policy.digest(str(jar)) for jar in paths}
    core = json_object(ROOT / "test/oracle/platform_backbone_zookeeper_capture_classpath.json")["coreJars"]
    if not core or any(actual_jars.get(name) != "sha256:"+value for name, value in core.items()):
        raise GateFailure("capture-probe-reviewed-core-jar-mismatch")
    if (len(captured_jars) != len(capture.get("jarInputs", []))
            or len(observer_jars) != len(observer.get("classpath", []))
            or captured_jars != observer_jars or captured_jars != actual_jars):
        raise GateFailure("capture-probe-authenticated-classpath-domain")


def verify_oracles() -> None:
    required = (
        EXPECTATIONS,
        ROOT / "test/fixture/platform_backbone/hot-tier-cap.golden",
        ROOT / "test/fixture/platform_backbone/registry-storage-driver.golden",
        ROOT / "test/oracle/platform_backbone_capacity.json",
        ROOT / "test/oracle/platform_backbone_gateway.json",
        ROOT / "test/oracle/platform_backbone_recovery.json",
        ROOT / "test/oracle/platform_backbone_source_models.json",
        ROOT / "test/oracle/platform_backbone_uniform_templates.json",
        ROOT / "test/oracle/platform_backbone_source_inventory.json",
        ROOT / "test/oracle/platform_backbone_offload_profile.json",
        ROOT / "test/oracle/platform_backbone_aws_streaming.json",
        ROOT / "test/oracle/platform_backbone_offloader_readiness.json",
        ROOT / "test/oracle/platform_backbone_delete_grammar.json",
        ROOT / "test/oracle/platform_backbone_zookeeper.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_transactions.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_containers.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_wire.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_genesis.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_startup.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_capture.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_capture_classpath.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_capture_with_digest.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_capture_registry.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_capture_registry_matcher.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_optional_digest.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_padding.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_history.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_history_policy.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_history_store.json",
        ROOT / "test/oracle/platform_backbone_history_store_storage.json",
        ROOT / "test/oracle/platform_backbone_history_store_storage_coordinated.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_members.json",
        ROOT / "test/oracle/platform_backbone_zookeeper_members_amendment.json",
        ROOT / "test/oracle/platform_backbone_execution_pods.json",
        ROOT / "test/oracle/platform_backbone_runtime_policy.json",
        ROOT / "test/oracle/platform_backbone_runtime_policy_amendment.json",
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
    capacity = json_object(ROOT / "test/oracle/platform_backbone_capacity.json")
    if capacity.get("unresolved_class_specific_cases"):
        raise GateFailure("independent-capacity-review-has-open-class-derivations")
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


def verify_hot_trace(capability: Path, observation: Mapping[str, Any]) -> None:
    name = observation.get("samplesPath", "")
    if not name or Path(name).name != name or not name.endswith("-hot-tier.jsonl"):
        raise GateFailure("hot-trace-path-invalid")
    path = capability / name
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 32 * 1024 * 1024:
        raise GateFailure("hot-trace-unavailable-or-oversized")
    encoded = path.read_bytes()
    if "sha256:" + hashlib.sha256(encoded).hexdigest() != observation.get("sampleSha256"):
        raise GateFailure("hot-trace-digest-drift")
    samples = [json.loads(line) for line in encoded.splitlines()]
    if len(samples) < 2 or len(samples) != observation.get("sampleCount"):
        raise GateFailure("hot-trace-sample-count-drift")
    if any(sample.get("topic") != observation.get("topic") for sample in samples):
        raise GateFailure("hot-trace-topic-challenge-drift")
    coverage = platform_backbone_hot_observer.verify_coverage(samples,
        observation.get("producerStartedSeconds"), observation.get("producerFinishedSeconds"))
    if coverage != observation.get("coverage"):
        raise GateFailure("hot-trace-coverage-drift")
    measured = [platform_backbone_hot_observer.hot_bytes(sample) for sample in samples]
    topic_age = observation.get("topicAgeAtObservationStartSeconds")
    if topic_age is not None:
        first = next((row for row, value in zip(samples, measured) if value > 0), None)
        if (type(topic_age) not in (int, float) or not math.isfinite(topic_age) or topic_age < 0
            or observation.get("maximumTopicAgeBeforeFirstWriteSeconds") != 60 or measured[0] != 0 or first is None):
            raise GateFailure("positive-topic-freshness-domain")
        first_age = topic_age + first["observationFinishedSeconds"]
        if not 0 <= first_age < 60 or observation.get("firstWriteAgeUpperSeconds") != first_age:
            raise GateFailure("positive-topic-first-write-age-domain")
    if max(measured) != observation.get("maximumObservedHotTierBytes") or measured[-1] != observation.get("hotTierBytes"):
        raise GateFailure("hot-trace-counter-drift")
    if observation.get("lastObservation") != samples[-1]:
        raise GateFailure("hot-trace-last-observation-drift")
    closed = {ledger["ledgerId"] for sample in samples for ledger in sample["ledgers"]
              if ledger.get("bookkeeperMetadataExists") and ledger.get("bookkeeperClosed")
              and ledger.get("bookkeeperLengthBytes", 0) > 0}
    if not closed or len(closed) != observation.get("closedLedgerMetadataObservations"):
        raise GateFailure("hot-trace-closed-bookkeeper-metadata-absent")


def verify_protocol_readiness(capability: Path, readiness: Mapping[str, Any], positive: Mapping[str, Any]) -> None:
    oracle = json_object(ROOT / "test/oracle/platform_backbone_offloader_readiness.json")
    if (readiness.get("messageCount") != oracle["inputs"]["messages"]
        or readiness.get("producedBytes") != oracle["expected_payload_bytes"]
        or readiness.get("messagesPerSecond") != 2
        or readiness.get("maximumNonemptyDataLedgers") != oracle["no_minimum_fill_case"]["maximum_nonempty_ledgers"]
        or readiness.get("automaticOffloadAndBookkeeperDeletionObserved") is not True
        or readiness.get("maximumObservedHotTierBytes", 65537) > oracle["inputs"]["hot_cap_bytes"]):
        raise GateFailure("bounded-offloader-protocol-readiness-domain")
    verify_hot_trace(capability, readiness)
    owner = readiness.get("owner", {})
    if (not owner.get("uid") or not owner.get("containerID") or owner.get("pod") not in {"broker-0", "broker-1"}
        or type(owner.get("restartCount")) is not int or owner["restartCount"] < 0
        or readiness.get("ownerBeforeIngest") != owner or positive.get("ingestOwner") != owner):
        raise GateFailure("offloader-protocol-owner-domain")
    trace = readiness.get("completionTrace", {})
    name = trace.get("path", "")
    if not name or Path(name).name != name or not name.endswith("-offload-ready.jsonl"):
        raise GateFailure("offloader-readiness-completion-path")
    path = capability / name
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 32*1024*1024:
        raise GateFailure("offloader-readiness-completion-unavailable")
    data = path.read_bytes()
    if trace.get("sha256") != "sha256:" + hashlib.sha256(data).hexdigest():
        raise GateFailure("offloader-readiness-completion-digest")
    rows = [json.loads(line) for line in data.splitlines()]
    if not rows or len(rows) != trace.get("samples") or any(row.get("topic") != readiness.get("topic") for row in rows):
        raise GateFailure("offloader-readiness-completion-domain")
    previous = -1.0
    for row in rows:
        elapsed = row.get("elapsedAfterProducerSeconds")
        if (type(elapsed) not in (int, float) or not math.isfinite(elapsed) or not 0 <= elapsed <= 120 or elapsed < previous
            or platform_backbone_hot_observer.hot_bytes(row) > oracle["inputs"]["hot_cap_bytes"]):
            raise GateFailure("offloader-readiness-completion-trace")
        previous = elapsed
    ingest = [json.loads(line) for line in (capability / readiness["samplesPath"]).read_bytes().splitlines()]
    nonempty = {ledger["ledgerId"] for sample in ingest + rows for ledger in sample["ledgers"]
                if ledger.get("bytes", 0) > 0 or ledger.get("bookkeeperLengthBytes", 0) > 0}
    if len(nonempty) > oracle["no_minimum_fill_case"]["maximum_nonempty_ledgers"]:
        raise GateFailure("offloader-readiness-ledger-population-domain")
    if not any(ledger.get("offloaded") and ledger.get("deletionCredited") and not ledger.get("bookkeeperMetadataExists")
               for ledger in rows[-1]["ledgers"]):
        raise GateFailure("offloader-readiness-deletion-absent")


def verify_live_domain(evidence: Path, expected_digest: str) -> dict[str, Any]:
    live = json_object(evidence)
    artifact = live.get("artifactSource", {})
    if artifact.get("digest") != expected_digest or artifact.get("publicPulls") != 0:
        raise GateFailure("base-image-domain")
    if artifact.get("pullEvents", {}).get("publicPullEventCount") != 0:
        raise GateFailure("public-pull-event-domain")
    if (artifact.get("pullEvents", {}).get("logSource") != "systemd-containerd-journal"
        or artifact.get("pullEvents", {}).get("windowMessageCount", 0) < 1):
        raise GateFailure("containerd-journal-observer-domain")
    predecessor = live.get("vaultPredecessor", {})
    if predecessor.get("vaultClusterId") is not True or predecessor.get("pkiRootStable") is not True:
        raise GateFailure("vault-predecessor-domain")
    load_balancer = live.get("loadBalancer", {})
    if not load_balancer.get("externallyReachable") or load_balancer.get("stableReadyObservations", 0) < 5:
        raise GateFailure("loadbalancer-domain")
    minio = live.get("minio", {})
    if minio.get("topology") != "distributed-erasure-four-drive" or len(minio.get("volumes", [])) != 4 or minio.get("replacementClaimBound") is not True:
        raise GateFailure("minio-topology-domain")
    if not live.get("minioRoundtrip", {}).get("byteIdentical"):
        raise GateFailure("minio-roundtrip-domain")
    admission = live.get("minioRoundtrip", {}).get("writerAdmission", {})
    if not all(admission.get(key) is True for key in ("ownScopeSuccess", "foreignScopeDenied", "directMinioDenied", "zeroForbiddenEffects")):
        raise GateFailure("object-writer-authority-and-bypass-domain")
    if admission.get("allPresentProducersGatewayBound") is not True:
        raise GateFailure("sole-object-gateway-producer-inventory-domain")
    producers = admission.get("producerChecks", [])
    if len(producers) != 2 or {row.get("producer") for row in producers} != {"registry", "pulsar-offload"}:
        raise GateFailure("object-gateway-producer-proof-inventory-domain")
    for row in producers:
        if (row.get("authority") != "vault-kubernetes-scoped-kv" or row.get("observer") != "independent-backend-s3-get"
            or row.get("bytes") != 4096 or row.get("oversizeReason") != "gateway-object-extent-denied"
            or not all(row.get(key) is True for key in ("ownScopeSuccess", "foreignScopeDenied", "directMinioDenied",
                "oversizeDenied", "backendCredentialReadDenied", "foreignCredentialReadDenied", "zeroForbiddenEffects",
                "mixedBulkScopeDenied", "mixedBulkOwnObjectUnchanged", "mixedBulkForeignObjectAbsent"))):
            raise GateFailure("object-gateway-producer-authority-domain")
    if not next(row for row in producers if row["producer"] == "pulsar-offload").get("foreignCopySourceDenied"):
        raise GateFailure("object-gateway-copy-source-authority-domain")
    restart = admission.get("restartDebt", {})
    if (not restart.get("oldPodUid") or not restart.get("newPodUid")
        or restart["oldPodUid"] == restart["newPodUid"]
        or restart.get("observedBackendHashRejections") != 3
        or restart.get("failureReason") != "gateway-failed-history-full"
        or not all(restart.get(key) is True for key in
                   ("failureDebtRetainedAcrossRestart", "furtherWriteDenied", "forbiddenObjectAbsent"))):
        raise GateFailure("object-gateway-durable-failure-debt-domain")
    registry = live.get("registryRehome", {})
    if registry.get("backend") != "s3" or not registry.get("migration", {}).get("verified") or not registry.get("sourceHashStable"):
        raise GateFailure("registry-rehome-domain")
    if registry.get("postCutoverByteIdentical") is not True or registry.get("postCutoverBytes") != 4096:
        raise GateFailure("fresh-post-cutover-object-domain")
    storage = live.get("storageProvision", {})
    public = json_object(evidence.parent / "storage-plan-input.json")
    image_handoff = project_cluster_fixture.verified_image_handoff()
    if image_handoff.index_digest != expected_digest:
        raise GateFailure("storage-reference-predecessor-digest-mismatch")
    for field, filename in (("artifact", "image-artifact.json"), ("preflight", "standup-preflight.json"),
                            ("publication", "publication.json")):
        if public.get(field) != json_object(image_handoff.run_dir / "capability" / filename):
            raise GateFailure("storage-reference-predecessor-input-mismatch:" + field)
    platform_backbone_storage_observer.verify_plan(public, storage)
    reader_controls = platform_backbone_storage_observer.verify_negative_controls(public, storage)
    original = storage.get("registry", {})
    object_set = original.get("objectSet", {})
    driver_objects = original.get("driverObjects", [])
    migration = registry.get("migration", {})
    if (original.get("indexDigest") != expected_digest or len(object_set) < 5
        or migration.get("objects") != driver_objects or not driver_objects
        or migration.get("streamBufferBytes") != 65536 or not migration.get("fullNativeRenderMatch")):
        raise GateFailure("exact-handoff-migration-domain")
    for side in ("sourcePull", "targetPull"):
        pull = registry.get(side, {})
        rows = pull.get("objects", [])
        found = {row["digest"]: row["bytes"] for row in rows}
        if (len(found) != len(rows) or found != object_set or pull.get("indexDigest") != expected_digest
            or pull.get("immutableTag") != original.get("tag")):
            raise GateFailure("exact-handoff-pull-domain:" + side)
    failure = registry.get("verifyFailure", {})
    route = registry.get("route", {})
    if (failure.get("reason") != "transfer-target-digest-mismatch" or not failure.get("sourceRoutePreserved")
        or failure.get("sourceBytesRetained") != sum(object_set.values()) or failure.get("partialTargetBytesRetained") != 71
        or not failure.get("fullNativeRenderMatch") or not route.get("atomicServiceSelectorUpdate")
        or route.get("before") != {"app": "registry-source"} or route.get("after") != {"app": "registry"}):
        raise GateFailure("registry-failure-and-cutover-domain")
    observed = live.get("storageIndependentObservation", {})
    if (not observed.get("independentArithmeticMatch") or observed.get("registryObjectCount") != len(object_set)
        or observed.get("driverObjectCount") != len(driver_objects) or observed.get("readerNegativeControls") != reader_controls
        or observed.get("physicalObservation", {}).get("distinctFilesystems") != 16
        or observed.get("physicalObservation", {}).get("physicalPoolAllocatedBytes", 0) < storage.get("physicalPoolRawBytes", 1)):
        raise GateFailure("independent-physical-storage-domain")
    if live.get("pulsar", {}).get("bookkeeper", {}).get("replacementClaimBound") is not True:
        raise GateFailure("bookkeeper-replacement-binding-domain")
    census = live.get("serviceStorageCensus", {})
    devices = {row["name"]: row["filesystemDevice"] for row in observed["physicalObservation"]["volumes"]
               if row["name"] in {"phase30-" + service + "-" + str(i) for service in ("bookkeeper", "zookeeper") for i in range(3)} | {"phase30-gateway-state"}}
    verified_census = platform_backbone_service_census.verify_trace(evidence.parent / "service-census", census, devices)
    if verified_census != census.get("verification"):
        raise GateFailure("independent-service-census-domain")
    execution = live.get("executionAdmission", {})
    if (execution.get("oneUnitShortReasons") != ["CpuAxis", "MemoryAxis", "EphemeralStorageAxis", "PodSlotsAxis"]
        or execution.get("backboneApiWritesDuringAdmission") != 0 or len(execution.get("available", [])) != 4):
        raise GateFailure("complete-execution-admission-domain")
    member_axes = {"cpu", "memory", "ephemeral", "pods", "usable", "incoming", "raw", "backing"}
    member_negatives = execution.get("metadataMemberNegatives", [])
    if (len(member_negatives) != 24
        or {(row.get("ordinal"), row.get("axis")) for row in member_negatives}
            != {(ordinal, axis) for ordinal in range(3) for axis in member_axes}
        or execution.get("metadataParentShortRejected") is not True
        or execution.get("metadataParentShortLocus") != "StorageOverBacking:retained-parent"
        or execution.get("metadataApiWritesDuringAdmission") != 0):
        raise GateFailure("independent-metadata-member-admission-domain")
    for row in member_negatives:
        ordinal, axis = row["ordinal"], row["axis"]
        locus = ("StorageOverBacking" if axis == "backing" else "zookeeper-member-member-" + str(ordinal) + "-" +
                 {"usable": "claim-usable", "incoming": "claim-usable", "raw": "claim-raw"}.get(axis, axis))
        if row.get("locus") != locus or (axis == "backing" and row.get("backing") != "phase30-zookeeper-" + str(ordinal)):
            raise GateFailure("metadata-member-rejection-locus-domain")
    member_corpus = json_object(ROOT / "test/oracle/platform_backbone_zookeeper_members.json")
    member_expected = next(row["required"] for row in member_corpus["cases"] if row["id"] == "three-exact-complete")
    identity_expected = json_object(ROOT / "test/oracle/platform_backbone_zookeeper_members_amendment.json")["expectedIdentityRows"]["three"]
    # The isolated corpus names its parent zookeeper-parent; the actual
    # already admitted floor retains the parent named in the source input.
    identity_expected = [{**row, "parentBackingId": "retained-parent"} for row in identity_expected]
    actual_members = live.get("executionProvision", {}).get("zookeeperMembers", {})
    if actual_members != {"capacity": member_expected, "bindings": identity_expected}:
        raise GateFailure("metadata-member-private-witness-domain")
    pulsar = live.get("pulsar", {})
    genesis = pulsar.get("zookeeper", {}).get("initialGenesis", {})
    try:
        verified_genesis = platform_backbone_zookeeper_observer.verify_native_genesis_capture(
            evidence.parent / "zookeeper-genesis", genesis, devices)
    except platform_backbone_zookeeper_observer.ZooKeeperObservationFailure as problem:
        raise GateFailure("independent-zookeeper-genesis-domain:" + str(problem)) from problem
    if verified_genesis != genesis.get("verification"):
        raise GateFailure("independent-zookeeper-genesis-verification-domain")
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
    if offload.get("hotTierCapBytes") != 65536 or offload.get("configuredSizeTriggerBytes") != 32768:
        raise GateFailure("unchanged-hot-tier-cap-and-trigger-domain")
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
    samples = offload.get("continuousObservation", {})
    if (samples.get("messageCount"), samples.get("producedBytes"), samples.get("messagesPerSecond")) != (100, 409600, 2):
        raise GateFailure("unchanged-positive-stream-domain")
    if samples.get("topicAgeAtObservationStartSeconds") is None or samples.get("maximumTopicAgeBeforeFirstWriteSeconds") != 60:
        raise GateFailure("positive-topic-freshness-evidence-absent")
    time_only = offload.get("timeOnlyNegative", {})
    verify_hot_trace(evidence.parent, samples)
    verify_protocol_readiness(evidence.parent, offload.get("protocolReadiness", {}), samples)
    verify_hot_trace(evidence.parent, time_only.get("observation", {}))
    if offload.get("policyOperands") != {"managedLedgerOffloadThresholdInBytes": 32768,
        "managedLedgerOffloadThresholdInSeconds": -1, "managedLedgerOffloadDeletionLagInMillis": 0}:
        raise GateFailure("size-offload-policy-operands-domain")
    if time_only.get("policyOperands") != {"managedLedgerOffloadThresholdInBytes": -1,
        "managedLedgerOffloadThresholdInSeconds": 3600, "managedLedgerOffloadDeletionLagInMillis": 0}:
        raise GateFailure("time-only-policy-operands-domain")
    negative = time_only.get("observation", {})
    if any(samples.get(key) != negative.get(key) for key in ("payloadSha256", "producedBytes", "messageCount", "messagesPerSecond")):
        raise GateFailure("time-only-ingest-differs-from-positive")
    if (samples.get("sampleCount", 0) < 2 or not samples.get("creditsOnlyObservedBookkeeperDeletion")
        or samples.get("maximumObservedHotTierBytes", 1) > offload.get("hotTierCapBytes", 0)
        or not time_only.get("sameIngest") or not time_only.get("observedBreach")
        or time_only.get("hotTierBytes", 0) <= offload.get("hotTierCapBytes", 0)):
        raise GateFailure("continuous-hot-tier-and-time-only-negative-domain")
    reclaimed = {row["ledgerId"] for row in samples["lastObservation"]["ledgers"]
                 if row.get("offloaded") and row.get("deletionCredited") and not row.get("bookkeeperMetadataExists")}
    cold = offload.get("offloadedRead", {})
    if (cold.get("deliveredMessages") != 100 or cold.get("payloadSha256") != samples.get("payloadSha256")
        or not cold.get("readReclaimedLedgerIds") or not set(cold["readReclaimedLedgerIds"]) <= reclaimed
        or not all(cold.get(key) is True for key in
            ("freshEarliestSubscription", "bookkeeperAbsenceObservedBeforeRead", "managedLedgerUnloadedBeforeRead"))):
        raise GateFailure("native-cold-offloaded-read-domain")
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
    complete_render = provenance.get("fullHaskellRenderProjection", {})
    if (complete_render.get("renderer") != "Amoebius.Manifest.renderAll"
        or not complete_render.get("freshGateProcessOutput") or not complete_render.get("allOwnedFieldsByteIdentical")
        or complete_render.get("objectCount") != ssa.get("objectCount")):
        raise GateFailure("complete-native-render-provenance-domain")
    universal = live.get("universalLinuxCpu", {})
    expected_hosts = {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}
    if not universal.get("availableOnEveryHardwareSubstrate") or universal.get("pristineLinuxHost") != expected_hosts:
        raise GateFailure("universal-linux-domain")
    verify_capture_probe(evidence.parent, expected_digest)
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
        resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl", "javac", "strace"])
        environment = toolchain.contained_env()
        environment["PATH"] = os.pathsep.join((str(ROOT / "tools"), environment.get("PATH", "")))
        environment.update({
            "AMOEBIUS_CABAL": resolved["cabal"]["path"],
            "AMOEBIUS_GHC": resolved["ghc"]["path"],
            "AMOEBIUS_KIND": resolved["kind"]["path"],
            "AMOEBIUS_KUBECTL": resolved["kubectl"]["path"],
        })
        print("toolchain side — resolved tools satisfy authored compatibility ranges\n")
        for name in ("cabal", "ghc", "kind", "kubectl", "javac", "strace"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = check_results["toolchain-satisfies-requirements"] = True

        print("\noracle side — authored backbone fixtures and surface expectation\n")
        verify_oracles()
        check_results["authored-backbone-oracles"] = results["oracle"] = True
        print("  ok    authored-backbone-oracles")

        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]
        print("\nstatic side — pure topology, capacity, migration, render, and readiness contracts\n")
        run((sys.executable, "-m", "unittest", "discover", "-s", "test/spec/host", "-p", "test_vault_pki_composition.py"), environment=environment)
        for pattern in ("test_retained_storage_backing.py", "test_toolchain_release_checksum.py", "test_platform_backbone_hot_observer.py", "test_platform_backbone_service_census.py", "test_platform_backbone_zookeeper_observer.py", "test_platform_backbone_history_store_observer.py", "test_platform_backbone_startup.py", "test_platform_backbone_broker_http.py"):
            run((sys.executable, "-m", "unittest", "discover", "-s", "test/spec/host", "-p", pattern), environment=environment)
        run((sys.executable, "test/spec/platform/zookeeper_capture_reference.py"), environment=environment)
        run((sys.executable, "test/spec/platform/zookeeper_capture_with_digest_reference.py"), environment=environment)
        run(cabal_command(cabal, compiler, "test", "platform-backbone-spec", *baseline_flags(), "--test-show-details=direct", "-j1"), environment=environment)
        verify_history_store_io(cabal, compiler, resolved["strace"], environment, gate.run_dir)
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
                run_id=f"b30-{gate.run_dir.name}",
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
