#!/usr/bin/env python3
"""Project-contained live-cluster fixture and verified predecessor handoff.

Live phases do not inherit a daemon or cluster from an earlier gate: every gate creates
its own marker-owned `.test_data` run, starts the private container engine there, and
destroys the entire fixture before attestation.  Durable predecessor artifacts are read
from `.build` only after an all-pass immutable attestation is joined back to the exact
run ledger that produced them.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import project_container_engine  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
CLUSTER_NAME = "amoebius-bootstrap-coordinator"
NODE_NAME = f"{CLUSTER_NAME}-control-plane"


class FixtureFailure(RuntimeError):
    """A predecessor or live fixture did not satisfy its containment contract."""


def _run(
    arguments: Sequence[str],
    *,
    environment: Mapping[str, str],
    timeout: int = 3600,
    stdin: str | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        env=dict(environment),
        text=True,
        input=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout,
    )
    if check and result.returncode:
        raise FixtureFailure(
            f"command:{arguments[0]}:exit-{result.returncode}\n{result.stdout[-6000:]}"
        )
    return result


def _digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return "sha256:" + value.hexdigest()


def _json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise FixtureFailure(f"json-object-required:{path}")
    return value


def _json_from_output(payload: str, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload)
    except json.JSONDecodeError as error:
        raise FixtureFailure(f"json-output:{label}:{error}") from error
    if not isinstance(value, dict):
        raise FixtureFailure(f"json-object-output-required:{label}")
    return value


@dataclass(frozen=True)
class VerifiedImageHandoff:
    """One predecessor OCI export joined to its honest immutable seal."""

    attestation: str
    run_dir: Path
    artifact: Path
    evidence: Path
    index_digest: str
    archive_sha256: str


@dataclass(frozen=True)
class VerifiedPhaseRecord:
    """One all-pass immutable phase record joined to its exact run ledger."""

    phase: int
    attestation: str
    run_dir: Path
    source_digest: str


def verified_phase_record(phase: int) -> VerifiedPhaseRecord:
    store = containment.require_state_path(
        ROOT / ".build/evidence-store", "build", actor="test"
    )
    run_root = containment.require_state_path(
        ROOT / ".build/runs" / f"phase_{phase:02d}", "build", actor="test"
    )
    records = sorted(
        (path for path in store.glob("*.json") if path.is_file()),
        key=lambda path: path.stat().st_mtime_ns,
        reverse=True,
    )
    for record_path in records:
        try:
            record = _json(record_path)
        except (OSError, ValueError, json.JSONDecodeError):
            continue
        checks = record.get("checks", [])
        attestation = "sha256:" + record_path.stem
        if (
            _digest(record_path) != attestation
            or record.get("phase") != phase
            or not isinstance(checks, list)
            or not checks
            or any(row.get("status") != "pass" for row in checks if isinstance(row, dict))
            or any(not isinstance(row, dict) for row in checks)
            or record.get("cleanup", {}).get("left_resources") is not False
        ):
            continue
        ledger_digest = str(record.get("observations", {}).get("ledger", ""))
        source_digest = str(record.get("source_digest", ""))
        if not ledger_digest.startswith("sha256:") or not source_digest.startswith("sha256:"):
            continue
        candidates = sorted(run_root.iterdir(), reverse=True) if run_root.is_dir() else ()
        for candidate in candidates:
            ledger = candidate / "ledger.json"
            if ledger.is_file() and _digest(ledger) == ledger_digest:
                return VerifiedPhaseRecord(
                    phase=phase,
                    attestation=attestation,
                    run_dir=candidate,
                    source_digest=source_digest,
                )
    raise FixtureFailure(f"no-all-pass-phase{phase}-record")


def verified_image_handoff(phase: int = 25) -> VerifiedImageHandoff:
    """Find the newest all-pass Phase-31 record and its exact producing run.

    An attestation does not carry a mutable pathname.  Its content-addressed ledger
    observation is therefore joined to the digest of each candidate run ledger.  That
    makes the selected archive the output of the sealed run instead of merely the newest
    file somebody left below `.build`.
    """
    store = containment.require_state_path(
        ROOT / ".build/evidence-store", "build", actor="test"
    )
    run_root = containment.require_state_path(
        ROOT / ".build/runs" / f"phase_{phase:02d}", "build", actor="test"
    )
    records = sorted(
        (path for path in store.glob("*.json") if path.is_file()),
        key=lambda path: path.stat().st_mtime_ns,
        reverse=True,
    )
    for record_path in records:
        try:
            record = _json(record_path)
        except (OSError, ValueError, json.JSONDecodeError):
            continue
        checks = record.get("checks", [])
        attestation = "sha256:" + record_path.stem
        if (
            _digest(record_path) != attestation
            or record.get("phase") != phase
            or not isinstance(checks, list)
            or not checks
            or any(row.get("status") != "pass" for row in checks if isinstance(row, dict))
            or any(not isinstance(row, dict) for row in checks)
            or record.get("cleanup", {}).get("left_resources") is not False
        ):
            continue
        ledger_digest = str(record.get("observations", {}).get("ledger", ""))
        if not ledger_digest.startswith("sha256:"):
            continue
        for candidate in sorted(run_root.iterdir(), reverse=True) if run_root.is_dir() else ():
            ledger = candidate / "ledger.json"
            artifact = candidate / "handoff/base-image.oci.tar"
            evidence = candidate / "capability"
            receipt = evidence / "bake-receipt.json"
            image_artifact = evidence / "image-artifact.json"
            if not all(path.is_file() for path in (ledger, artifact, receipt, image_artifact)):
                continue
            if _digest(ledger) != ledger_digest:
                continue
            receipt_value = _json(receipt)
            artifact_value = _json(image_artifact)
            index_digest = str(receipt_value.get("imageIndexDigest", ""))
            archive_sha256 = str(receipt_value.get("artifactArchiveSha256", ""))
            if (
                not index_digest.startswith("sha256:")
                or artifact_value.get("imageIndexDigest") != index_digest
                or not archive_sha256.startswith("sha256:")
                or _digest(artifact) != archive_sha256
            ):
                raise FixtureFailure("phase25-handoff-digest-mismatch")
            return VerifiedImageHandoff(
                attestation=attestation,
                run_dir=candidate,
                artifact=artifact,
                evidence=evidence,
                index_digest=index_digest,
                archive_sha256=archive_sha256,
            )
    raise FixtureFailure("no-all-pass-phase25-handoff")


@dataclass
class ProjectCluster:
    """The exact marker-owned resources one live phase is authorized to remove."""

    test_run: containment.TestRun
    engine: project_container_engine.ProjectContainerEngine
    kubeconfig: Path
    storage_root: Path
    kind: str
    kubectl: str
    environment: dict[str, str]
    cluster_attempted: bool = False

    def create(self) -> None:
        self.storage_root.mkdir(parents=True, exist_ok=True)
        config = self.test_run.path / "cluster/kind.yaml"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(
            "\n".join(
                (
                    "kind: Cluster",
                    "apiVersion: kind.x-k8s.io/v1alpha4",
                    "nodes:",
                    "- role: control-plane",
                    "  extraMounts:",
                    f"  - hostPath: {self.storage_root}",
                    "    containerPath: /amoebius-test/storage",
                    "",
                )
            ),
            encoding="utf-8",
        )
        self.cluster_attempted = True
        _run(
            (
                self.kind,
                "create",
                "cluster",
                "--name",
                CLUSTER_NAME,
                "--config",
                str(config),
                "--kubeconfig",
                str(self.kubeconfig),
                "--wait",
                "300s",
            ),
            environment=self.environment,
        )
        _run(
            (
                "/usr/bin/docker",
                "update",
                "--cpus",
                "2",
                "--memory",
                "4g",
                "--memory-swap",
                "4g",
                NODE_NAME,
            ),
            environment=self.environment,
            timeout=300,
        )
        envelope = _run(
            (
                "/usr/bin/docker",
                "inspect",
                NODE_NAME,
                "--format",
                "{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}",
            ),
            environment=self.environment,
            timeout=60,
        ).stdout.strip()
        if envelope != "2000000000 4294967296 4294967296":
            raise FixtureFailure(f"node-envelope:{envelope}")
        _run(
            (
                self.kubectl,
                "--kubeconfig",
                str(self.kubeconfig),
                "wait",
                "--for=condition=Ready",
                "node",
                "--all",
                "--timeout=300s",
            ),
            environment=self.environment,
            timeout=600,
        )

    def bootstrap_registry(self, handoff: VerifiedImageHandoff, evidence: Path) -> str:
        """Side-load and publish the verified predecessor export in this fresh cluster."""
        evidence = containment.require_state_path(evidence, "build", actor="test")
        evidence.mkdir(parents=True, exist_ok=True)
        shutil.copy2(handoff.evidence / "image-artifact.json", evidence / "image-artifact.json")
        _run(
            (
                sys.executable,
                "tools/base_image_registry_bootstrap_preflight.py",
                "--evidence",
                str(evidence),
                "--artifact",
                str(handoff.artifact),
                "--expected-archive-sha256",
                handoff.archive_sha256.removeprefix("sha256:"),
                "--host-storage-root",
                str(self.engine.data_root),
                "--output",
                str(evidence / "standup-preflight.json"),
            ),
            environment=self.environment,
        )
        _run(
            (
                sys.executable,
                "tools/base_image_registry_standup.py",
                "--evidence",
                str(evidence),
                "--index-digest",
                handoff.index_digest,
                "--artifact",
                str(handoff.artifact),
                "--output",
                str(evidence / "standup.json"),
            ),
            environment=self.environment,
            timeout=10800,
        )
        _run(
            (
                sys.executable,
                "tools/base_image_registry_publish.py",
                "--evidence",
                str(evidence),
                "--artifact",
                str(handoff.artifact),
                "--output",
                str(evidence / "publication.json"),
            ),
            environment=self.environment,
            timeout=10800,
        )
        publication = _json(evidence / "publication.json")
        reference = str(publication.get("digestReference", ""))
        if not reference.endswith("@" + handoff.index_digest):
            raise FixtureFailure(f"published-reference:{reference}")
        wiring = self._configure_registry_pull_route()
        (evidence / "registry-wiring.json").write_text(
            json.dumps(wiring, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        prefix = "registry.amoebius.invalid/"
        if not reference.startswith(prefix):
            raise FixtureFailure(f"published-registry-host:{reference}")
        return "registry.amoebius.invalid:5000/" + reference.removeprefix(prefix)

    def _node_file(self, path: str, contents: str, *, append: bool = False) -> None:
        arguments = ["/usr/bin/docker", "exec", "-i", NODE_NAME, "/usr/bin/tee"]
        if append:
            arguments.append("--append")
        arguments.append(path)
        result = _run(arguments, environment=self.environment, stdin=contents, timeout=120)
        if result.stdout != contents:
            raise FixtureFailure(f"node-file-write-readback:{path}")

    def _configure_registry_pull_route(self) -> dict[str, Any]:
        """Route the authored registry name to this run's fresh Service.

        Phase 31 proves the same containerd hosts-directory mechanism under the
        no-public-pull firewall. Successor phases recreate that runtime-only node
        wiring because a fresh cluster deliberately inherits no predecessor state.
        """
        service = _json_from_output(
            _run(
                (
                    self.kubectl,
                    "--kubeconfig",
                    str(self.kubeconfig),
                    "-n",
                    "amoebius-bootstrap",
                    "get",
                    "service",
                    "distribution-read",
                    "-o",
                    "json",
                ),
                environment=self.environment,
                timeout=120,
            ).stdout,
            "distribution-read-service",
        )
        cluster_ip = str(service.get("spec", {}).get("clusterIP", ""))
        if not cluster_ip:
            raise FixtureFailure("registry-service-cluster-ip-absent")
        config = _run(
            (
                "/usr/bin/docker",
                "exec",
                NODE_NAME,
                "/usr/bin/sed",
                "-n",
                "1,220p",
                "/etc/containerd/config.toml",
            ),
            environment=self.environment,
            timeout=120,
        ).stdout
        registry_stanza = (
            '\n[plugins."io.containerd.grpc.v1.cri".registry]\n'
            '  config_path = "/etc/containerd/certs.d"\n'
        )
        if 'config_path = "/etc/containerd/certs.d"' not in config:
            _run(
                (
                    "/usr/bin/docker",
                    "exec",
                    NODE_NAME,
                    "/usr/bin/cp",
                    "--preserve=mode,ownership,timestamps",
                    "/etc/containerd/config.toml",
                    "/etc/containerd/config.toml.amoebius-successor-before",
                ),
                environment=self.environment,
                timeout=120,
            )
            self._node_file("/etc/containerd/config.toml", registry_stanza, append=True)
        registry_host = "registry.amoebius.invalid:5000"
        hosts_directory = f"/etc/containerd/certs.d/{registry_host}"
        _run(
            ("/usr/bin/docker", "exec", NODE_NAME, "/usr/bin/mkdir", "-p", hosts_directory),
            environment=self.environment,
            timeout=120,
        )
        hosts = (
            f'server = "http://{cluster_ip}:5000"\n\n'
            f'[host."http://{cluster_ip}:5000"]\n'
            '  capabilities = ["pull", "resolve"]\n'
            "  skip_verify = true\n"
        )
        hosts_file = f"{hosts_directory}/hosts.toml"
        self._node_file(hosts_file, hosts)
        _run(
            ("/usr/bin/docker", "exec", NODE_NAME, "/usr/bin/systemctl", "restart", "containerd"),
            environment=self.environment,
            timeout=180,
        )
        for _ in range(60):
            active = _run(
                ("/usr/bin/docker", "exec", NODE_NAME, "/usr/bin/systemctl", "is-active", "containerd"),
                environment=self.environment,
                timeout=10,
                check=False,
            )
            if active.returncode == 0 and active.stdout.strip() == "active":
                break
            time.sleep(1)
        else:
            raise FixtureFailure("containerd-restart-timeout")
        _run(
            (
                self.kubectl,
                "--kubeconfig",
                str(self.kubeconfig),
                "wait",
                "--for=condition=Ready",
                f"node/{NODE_NAME}",
                "--timeout=120s",
            ),
            environment=self.environment,
            timeout=180,
        )
        dump = _run(
            (
                "/usr/bin/docker",
                "exec",
                NODE_NAME,
                "/usr/local/bin/containerd",
                "config",
                "dump",
            ),
            environment=self.environment,
            timeout=120,
        ).stdout
        if "config_path = '/etc/containerd/certs.d'" not in dump:
            raise FixtureFailure("containerd-registry-config-path-not-active")
        return {
            "registryHost": registry_host,
            "serviceClusterIp": cluster_ip,
            "configPath": "/etc/containerd/certs.d",
            "hostsFile": hosts_file,
            "containerdActive": True,
            "nodeReady": True,
        }

    def stop(self) -> list[str]:
        """Tear down in dependency order and return any exact cleanup failures."""
        failures: list[str] = []
        if self.cluster_attempted:
            transcripts: list[str] = []
            deleted = False
            for attempt in range(1, 4):
                result = _run(
                    (self.kind, "delete", "cluster", "--name", CLUSTER_NAME),
                    environment=self.environment,
                    timeout=900,
                    check=False,
                )
                transcripts.append(f"attempt-{attempt}:{result.returncode}:{result.stdout.strip()}")
                clusters = _run(
                    (self.kind, "get", "clusters"),
                    environment=self.environment,
                    timeout=60,
                    check=False,
                ).stdout.splitlines()
                node = _run(
                    ("/usr/bin/docker", "inspect", NODE_NAME),
                    environment=self.environment,
                    timeout=60,
                    check=False,
                )
                if CLUSTER_NAME not in clusters and node.returncode != 0:
                    deleted = True
                    break
                if attempt < 3:
                    _run(
                        ("/usr/bin/docker", "stop", "--time", "60", NODE_NAME),
                        environment=self.environment,
                        timeout=120,
                        check=False,
                    )
            if not deleted:
                failures.append("kind-delete:" + " | ".join(transcripts))
        try:
            self.engine.stop()
        except project_container_engine.EngineFailure as problem:
            failures.append(f"engine-stop:{problem}")
        if not failures:
            try:
                containment.cleanup_test_run(self.test_run)
            except containment.ContainmentError as problem:
                failures.append(f"test-root-cleanup:{problem}")
        return failures


def start(
    *,
    run_id: str,
    run_dir: Path,
    kind: str,
    kubectl: str,
    base_environment: Mapping[str, str],
) -> ProjectCluster:
    """Start a private engine and prepare, but do not yet create, one cluster."""
    production = ROOT / ".data"
    if production.is_dir() and any(production.iterdir()):
        raise FixtureFailure("test-safety-refusal:production-state-is-present")
    test_run = containment.create_test_run(run_id)
    try:
        engine = project_container_engine.start(
            test_run,
            log_path=run_dir / "project-engine.log",
            base_environment=base_environment,
        )
    except Exception:
        containment.cleanup_test_run(test_run)
        raise
    kubeconfig = test_run.path / "cluster/kubeconfig"
    kubeconfig.parent.mkdir(parents=True, exist_ok=True)
    storage_root = test_run.path / "storage"
    environment = dict(base_environment)
    environment.update(
        {
            "DOCKER_HOST": f"unix://{engine.socket}",
            "DOCKER_CONFIG": str(engine.client_config),
            "DOCKER_BUILDKIT": "1",
            "AMOEBIUS_KUBECONFIG": str(kubeconfig),
            "AMOEBIUS_KUBECTL": kubectl,
            "AMOEBIUS_KIND": kind,
            "AMOEBIUS_TEST_ROOT": str(test_run.path),
            "AMOEBIUS_LIVE_STORAGE_ROOT": "/amoebius-test/storage",
            "AMOEBIUS_RUN_TMP": str(run_dir / "tmp"),
        }
    )
    return ProjectCluster(
        test_run=test_run,
        engine=engine,
        kubeconfig=kubeconfig,
        storage_root=storage_root,
        kind=kind,
        kubectl=kubectl,
        environment=environment,
    )
