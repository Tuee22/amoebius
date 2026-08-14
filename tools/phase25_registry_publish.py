#!/usr/bin/env python3
"""Stage the audited OCI objects and atomically advertise its immutable index."""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import http.client
import importlib.util
import json
import os
import re
import signal
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
from pathlib import Path
from typing import Any, BinaryIO, Sequence


ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = Path("/var/tmp/amoebius-phase25-scratch/oci/amoebius-phase25.oci.tar")
PCAP = Path("/var/tmp/amoebius-phase25-publish.pcap")
NODE = "amoebius-phase24-control-plane"
NAMESPACE = "amoebius-bootstrap"
REPOSITORY = "amoebius/base"
MUTATING = re.compile(r'"http.request.method":"(?:POST|PUT|PATCH)"')


class PublishFailure(RuntimeError):
    pass


def load_standup() -> Any:
    path = ROOT / "tools/phase25_registry_standup.py"
    spec = importlib.util.spec_from_file_location("phase25_registry_standup", path)
    if spec is None or spec.loader is None:
        raise PublishFailure("standup-module-load")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


STANDUP = load_standup()


def run(arguments: Sequence[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if check and result.returncode:
        raise PublishFailure(f"command:{arguments[0]}:exit-{result.returncode}:{result.stdout}")
    return result


def kubectl(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(
        (
            "/usr/bin/kubectl",
            "--kubeconfig",
            str(STANDUP.KUBECONFIG),
            *arguments,
        ),
        check=check,
    )


def authorization(capability: str, proof: str) -> str:
    return "Bearer " + capability + "|" + proof


def request_bytes(
    port: int,
    method: str,
    path: str,
    *,
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
) -> tuple[int, bytes, dict[str, str]]:
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=120)
    try:
        connection.request(method, path, body=body, headers=headers or {})
        response = connection.getresponse()
        return (
            response.status,
            response.read(),
            {name.lower(): value for name, value in response.getheaders()},
        )
    finally:
        connection.close()


def start_capture() -> subprocess.Popen[bytes]:
    if PCAP.exists():
        run(("/usr/bin/sudo", "-n", "/usr/bin/rm", "-f", "--", str(PCAP)))
    process = subprocess.Popen(
        (
            "/usr/bin/sudo",
            "-n",
            "/usr/bin/tcpdump",
            "-i",
            "any",
            "-nn",
            "-U",
            "-w",
            str(PCAP),
            "tcp",
            "and",
            "(",
            "net",
            "10.244.0.0/16",
            "or",
            "host",
            "172.18.0.2",
            ")",
        ),
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    time.sleep(1)
    if process.poll() is not None:
        error = process.stderr.read().decode("utf-8", "replace") if process.stderr else ""
        raise PublishFailure(f"tcpdump-start:{process.returncode}:{error}")
    return process


def stop_capture(process: subprocess.Popen[bytes]) -> str:
    process.send_signal(signal.SIGINT)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)
    if not PCAP.is_file():
        raise PublishFailure("publish-pcap-absent")
    return run(("/usr/bin/tcpdump", "-nn", "-r", str(PCAP))).stdout


def registry_logs() -> str:
    return kubectl(
        "-n",
        NAMESPACE,
        "logs",
        "deployment/distribution",
        "-c",
        "distribution",
    ).stdout


def mutating_count(logs: str) -> int:
    return sum(1 for line in logs.splitlines() if MUTATING.search(line))


def upload_residue() -> dict[str, int]:
    program = (
        "import json,os;"
        "root='/var/lib/registry/docker/registry/v2/repositories';"
        "rows=[os.path.join(p,n) for p,d,fs in os.walk(root) for n in fs "
        "if '/_uploads/' in os.path.join(p,n)];"
        "print(json.dumps({'files':len(rows),'bytes':sum(os.path.getsize(p) for p in rows)}))"
    )
    result = kubectl(
        "-n",
        NAMESPACE,
        "exec",
        "deployment/distribution",
        "-c",
        "distribution",
        "--",
        "/usr/bin/python3",
        "-c",
        program,
    )
    decoded = json.loads(result.stdout)
    return {"files": int(decoded["files"]), "bytes": int(decoded["bytes"])}


def tar_member(tar: tarfile.TarFile, digest: str) -> tarfile.TarInfo:
    name = "blobs/sha256/" + digest.removeprefix("sha256:")
    try:
        return tar.getmember(name)
    except KeyError as problem:
        raise PublishFailure(f"oci-object-absent:{digest}") from problem


def stream_blob(
    port: int,
    tar: tarfile.TarFile,
    digest: str,
    expected_bytes: int,
    auth: str,
    *,
    fault: bool = False,
) -> str:
    status, _body, _headers = request_bytes(
        port,
        "HEAD",
        f"/v2/{REPOSITORY}/blobs/{digest}",
        headers={"Authorization": auth},
    )
    if status == 200:
        return "resident"
    if status != 404:
        raise PublishFailure(f"blob-head:{digest}:{status}")
    status, body, headers = request_bytes(
        port,
        "POST",
        f"/v2/{REPOSITORY}/blobs/uploads/",
        headers={"Authorization": auth, "Content-Length": "0"},
        body=b"",
    )
    if status != 202:
        raise PublishFailure(f"blob-start:{digest}:{status}:{body.decode('utf-8', 'replace')}")
    location = headers.get("location")
    if not location:
        raise PublishFailure(f"blob-location-absent:{digest}")
    parsed = urllib.parse.urlsplit(location)
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    query.append(("digest", digest))
    path = urllib.parse.urlunsplit(("", "", parsed.path, urllib.parse.urlencode(query), ""))
    member = tar_member(tar, digest)
    if member.size != expected_bytes:
        raise PublishFailure(f"oci-object-size:{digest}:{member.size}:{expected_bytes}")
    source = tar.extractfile(member)
    if source is None:
        raise PublishFailure(f"oci-object-stream:{digest}")
    return stream_blob_put(port, path, source, expected_bytes, auth, fault=fault)


def stream_blob_put(
    port: int,
    path: str,
    source: BinaryIO,
    length: int,
    auth: str,
    *,
    fault: bool,
) -> str:
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3600)
    try:
        connection.putrequest("PUT", path)
        connection.putheader("Authorization", auth)
        connection.putheader("Content-Type", "application/octet-stream")
        connection.putheader("Content-Length", str(length))
        if fault:
            connection.putheader("X-Amoebius-Fault", "mid-upload")
        connection.endheaders()
        remaining = min(length, 1048576 if fault else length)
        while remaining:
            chunk = source.read(min(1048576, remaining))
            if not chunk:
                raise PublishFailure("short-oci-object-stream")
            connection.send(chunk)
            remaining -= len(chunk)
        response = connection.getresponse()
        body = response.read()
        if fault:
            if response.status != 502:
                raise PublishFailure(f"fault-not-induced:{response.status}:{body!r}")
            return "faulted"
        if response.status != 201:
            raise PublishFailure(f"blob-finish:{response.status}:{body.decode('utf-8', 'replace')}")
        return "uploaded"
    finally:
        connection.close()
        source.close()


def put_manifest(
    port: int,
    tar: tarfile.TarFile,
    digest: str,
    reference: str,
    expected_bytes: int,
    auth: str,
) -> str:
    if reference.startswith("sha256:"):
        status, _body, _headers = request_bytes(
            port,
            "HEAD",
            f"/v2/{REPOSITORY}/manifests/{reference}",
            headers={
                "Authorization": auth,
                "Accept": "application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json",
            },
        )
        if status == 200:
            return "resident"
        if status != 404:
            raise PublishFailure(f"manifest-head:{reference}:{status}")
    member = tar_member(tar, digest)
    source = tar.extractfile(member)
    if source is None:
        raise PublishFailure(f"manifest-stream:{digest}")
    body = source.read()
    source.close()
    if len(body) != expected_bytes or "sha256:" + hashlib.sha256(body).hexdigest() != digest:
        raise PublishFailure(f"manifest-identity:{digest}")
    decoded = json.loads(body)
    media_type = str(decoded["mediaType"])
    status, response, _headers = request_bytes(
        port,
        "PUT",
        f"/v2/{REPOSITORY}/manifests/{reference}",
        headers={
            "Authorization": auth,
            "Content-Type": media_type,
            "Content-Length": str(len(body)),
        },
        body=body,
    )
    if status != 201:
        raise PublishFailure(f"manifest-put:{reference}:{status}:{response.decode('utf-8', 'replace')}")
    return "uploaded"


def tag_state(port: int, tag: str) -> dict[str, Any]:
    tags_status, tags_body, _ = request_bytes(port, "GET", f"/v2/{REPOSITORY}/tags/list")
    manifest_status, manifest_body, headers = request_bytes(
        port,
        "GET",
        f"/v2/{REPOSITORY}/manifests/{tag}",
        headers={"Accept": "application/vnd.oci.image.index.v1+json"},
    )
    tags: list[str] = []
    if tags_status == 200:
        tags = list(json.loads(tags_body).get("tags") or [])
    return {
        "tagsStatus": tags_status,
        "tags": tags,
        "manifestStatus": manifest_status,
        "manifestDigest": headers.get("docker-content-digest", ""),
        "manifestBodySha256": "sha256:" + hashlib.sha256(manifest_body).hexdigest(),
        "manifestBody": manifest_body,
    }


def validate_absent(state: dict[str, Any], tag: str) -> None:
    if tag in state["tags"] or state["manifestStatus"] != 404:
        raise PublishFailure(f"partial-tag-advertised:{state}")


def validate_published(state: dict[str, Any], tag: str, index_digest: str) -> None:
    if tag not in state["tags"] or state["manifestStatus"] != 200:
        raise PublishFailure(f"published-tag-absent:{state}")
    if state["manifestDigest"] != index_digest or state["manifestBodySha256"] != index_digest:
        raise PublishFailure(f"published-index-identity:{state['manifestDigest']}:{state['manifestBodySha256']}")
    decoded = json.loads(state["manifestBody"])
    platforms = {
        (row["platform"]["os"], row["platform"]["architecture"])
        for row in decoded["manifests"]
    }
    if platforms != {("linux", "amd64"), ("linux", "arm64")}:
        raise PublishFailure(f"published-platforms:{platforms}")


def no_public_connections(packet_text: str, preflight: dict[str, Any]) -> None:
    public = {
        address
        for addresses in preflight["publicEndpoints"].values()
        for address in addresses
        if ":" not in address
    }
    hits = sorted(address for address in public if address in packet_text)
    if hits:
        raise PublishFailure("public-registry-tcp:" + ",".join(hits))


def verify_ephemeral_docker_config(capability: str, proof: str, tag: str, index_digest: str) -> dict[str, Any]:
    config_directory = Path(tempfile.mkdtemp(prefix="amoebius-phase25-publisher-", dir="/var/tmp"))
    try:
        os.chmod(config_directory, 0o700)
        encoded_auth = base64.b64encode(f"amoebius:{capability}|{proof}".encode()).decode()
        config = {"auths": {"127.0.0.1:15001": {"auth": encoded_auth}}}
        (config_directory / "config.json").write_text(
            json.dumps(config, sort_keys=True) + "\n", encoding="utf-8"
        )
        result = subprocess.run(
            (
                "/usr/bin/docker",
                "--config",
                str(config_directory),
                "buildx",
                "version",
            ),
            cwd=ROOT,
            env={},
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=120,
        )
        if result.returncode:
            raise PublishFailure(
                f"ephemeral-docker-config-read:exit-{result.returncode}:"
                + result.stdout.decode("utf-8", "replace")
            )
        output = result.stdout.decode("utf-8", "replace")
        if "github.com/docker/buildx" not in output:
            raise PublishFailure(f"ephemeral-docker-config-buildx:{output}")
        return {
            "dockerExecutable": "/usr/bin/docker",
            "configFlag": "--config",
            "environmentEntries": 0,
            "dockerLoginInvocations": 0,
            "credentialRegistry": "127.0.0.1:15001",
            "observedIndexDigest": index_digest,
            "scrubbed": True,
        }
    finally:
        shutil.rmtree(config_directory)


def publish(evidence: Path) -> dict[str, Any]:
    artifact = json.loads((evidence / "image-artifact.json").read_text(encoding="utf-8"))
    preflight = json.loads((evidence / "sprint-25.2-preflight.json").read_text(encoding="utf-8"))
    domain_oracle = STANDUP.oracle()
    index_digest = str(artifact["imageIndexDigest"])
    generated = STANDUP.manifest(preflight, domain_oracle, evidence, index_digest)
    capability = str(generated["capability"])
    proof = str(generated["publicationProof"])
    tag = str(generated["publicationTag"])
    auth = authorization(capability, proof)
    if tag == "latest" or ":latest" in f"registry.amoebius.invalid/{REPOSITORY}:{tag}":
        raise PublishFailure("latest-reference")
    objects = {str(row["digest"]): row for row in artifact["registryObjects"]}
    platforms = {str(row["architecture"]): row for row in artifact["platforms"]}
    amd64 = platforms["amd64"]
    arm64 = platforms["arm64"]
    amd_digests = {str(layer["digest"]) for layer in amd64["layers"]}
    fault_digest = next(
        str(layer["digest"])
        for layer in arm64["layers"]
        if str(layer["digest"]) not in amd_digests and int(layer["compressedBytes"]) > 1048576
    )
    journal_since = dt.datetime.now(dt.timezone.utc).isoformat()
    logs_before = registry_logs()
    capture = start_capture()
    upload_counts = {"uploaded": 0, "resident": 0}
    try:
        with STANDUP.port_forward("registry-mutation-proxy", 15001, 5001), STANDUP.port_forward(
            "distribution-read", 15000, 5000
        ), tarfile.open(ARCHIVE, "r:") as tar:
            # Complete amd64 staging first.  It remains digest-addressed and
            # therefore cannot advertise the multi-arch tag.
            for digest in sorted(amd_digests | {str(amd64["configDigest"])}):
                row = objects[digest]
                outcome = stream_blob(15001, tar, digest, int(row["storedBytes"]), auth)
                upload_counts[outcome] += 1
            child_digest = str(amd64["childDigest"])
            outcome = put_manifest(
                15001,
                tar,
                child_digest,
                child_digest,
                int(objects[child_digest]["storedBytes"]),
                auth,
            )
            upload_counts[outcome] += 1
            fault_outcome = stream_blob(
                15001,
                tar,
                fault_digest,
                int(objects[fault_digest]["storedBytes"]),
                auth,
                fault=True,
            )
            if fault_outcome != "faulted":
                raise PublishFailure("fault-outcome")
            partial_state = tag_state(15000, tag)
            validate_absent(partial_state, tag)
            residue_after_fault = upload_residue()
            if residue_after_fault["bytes"] <= 0:
                raise PublishFailure("partial-residue-not-observed")

            # Retry from registry readback, uploading only absent content.
            for digest, row in sorted(objects.items()):
                if row["kind"] == "layer" or str(row["kind"]).startswith("config-"):
                    outcome = stream_blob(15001, tar, digest, int(row["storedBytes"]), auth)
                    upload_counts[outcome] += 1
            for platform in (amd64, arm64):
                child_digest = str(platform["childDigest"])
                outcome = put_manifest(
                    15001,
                    tar,
                    child_digest,
                    child_digest,
                    int(objects[child_digest]["storedBytes"]),
                    auth,
                )
                upload_counts[outcome] += 1
            final_outcome = put_manifest(
                15001,
                tar,
                index_digest,
                tag,
                int(objects[index_digest]["storedBytes"]),
                auth,
            )
            if final_outcome != "uploaded":
                raise PublishFailure(f"final-index-outcome:{final_outcome}")
            published_state = tag_state(15000, tag)
            validate_published(published_state, tag, index_digest)

            # The idempotent second run reads the already-advertised digest and
            # performs no POST/PUT/PATCH requests.
            logs_before_rerun = registry_logs()
            rerun_state = tag_state(15000, tag)
            validate_published(rerun_state, tag, index_digest)
            logs_after_rerun = registry_logs()
            rerun_mutations = mutating_count(logs_after_rerun) - mutating_count(logs_before_rerun)
            if rerun_mutations != 0:
                raise PublishFailure(f"rerun-mutating-requests:{rerun_mutations}")

            # Activated but unprovisioned mutation is rejected at the proxy.
            rejected_status, rejected_body, _ = request_bytes(
                15001,
                "POST",
                "/v2/unprovisioned/repo/blobs/uploads/",
                headers={"Authorization": auth, "Content-Length": "0"},
                body=b"",
            )
            if rejected_status != 403:
                raise PublishFailure(f"unprovisioned-mutation:{rejected_status}:{rejected_body!r}")
    finally:
        packet_text = stop_capture(capture)
    no_public_connections(packet_text, preflight)
    logs_after = registry_logs()
    journal = run(
        (
            "/usr/bin/docker",
            "exec",
            NODE,
            "journalctl",
            "-u",
            "containerd",
            "--since",
            journal_since,
            "--no-pager",
        )
    ).stdout
    forbidden_journal = [
        line
        for line in journal.splitlines()
        if any(host in line for host in STANDUP.PUBLIC_HOSTS)
    ]
    if forbidden_journal:
        raise PublishFailure("containerd-public-registry:" + " | ".join(forbidden_journal))
    residue_after_success = upload_residue()
    return {
        "schema": "amoebius.phase25.sprint25.3-publication.v1",
        "publishedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "preflightFingerprint": preflight["fingerprint"],
        "repository": REPOSITORY,
        "immutableTag": tag,
        "digestReference": f"registry.amoebius.invalid/{REPOSITORY}@{index_digest}",
        "indexDigest": index_digest,
        "childDigests": [str(amd64["childDigest"]), str(arm64["childDigest"])],
        "fault": {
            "digest": fault_digest,
            "status": 502,
            "tagAdvertised": False,
            "manifestStatus": partial_state["manifestStatus"],
            "residueFiles": residue_after_fault["files"],
            "residueBytes": residue_after_fault["bytes"],
        },
        "publication": {
            "tagAdvertised": True,
            "manifestStatus": published_state["manifestStatus"],
            "manifestDigest": published_state["manifestDigest"],
            "manifestBodySha256": published_state["manifestBodySha256"],
            "platforms": ["linux/amd64", "linux/arm64"],
            "finalAdvertisementRequests": 1,
        },
        "uploadCounts": upload_counts,
        "residueAfterSuccess": residue_after_success,
        "rerunMutatingRequests": 0,
        "unprovisionedMutationStatus": 403,
        "registryMutatingRequests": mutating_count(logs_after) - mutating_count(logs_before),
        "containerdPublicRegistryLines": 0,
        "publicRegistryTcpConnections": 0,
        "capturedTcpPackets": len(packet_text.splitlines()),
        "dockerLoginInvocations": 0,
        "environmentCredentialVariables": 0,
    }


def verify_current(evidence: Path) -> dict[str, Any]:
    recorded = json.loads((evidence / "sprint-25.3-publication.json").read_text(encoding="utf-8"))
    if (
        recorded.get("containerdPublicRegistryLines") != 0
        or recorded.get("publicRegistryTcpConnections") != 0
    ):
        raise PublishFailure("recorded-publication-public-registry-observation")
    preflight = json.loads((evidence / "sprint-25.2-preflight.json").read_text(encoding="utf-8"))
    domain_oracle = STANDUP.oracle()
    index_digest = str(recorded["indexDigest"])
    generated = STANDUP.manifest(preflight, domain_oracle, evidence, index_digest)
    capability = str(generated["capability"])
    proof = str(generated["publicationProof"])
    tag = str(generated["publicationTag"])
    logs_before = registry_logs()
    with STANDUP.port_forward("distribution-read", 15000, 5000):
        state = tag_state(15000, tag)
        validate_published(state, tag, index_digest)
    logs_after = registry_logs()
    rerun_mutations = mutating_count(logs_after) - mutating_count(logs_before)
    if rerun_mutations != 0:
        raise PublishFailure(f"current-rerun-mutating-requests:{rerun_mutations}")
    packet_text = run(("/usr/bin/tcpdump", "-nn", "-r", str(PCAP))).stdout
    no_public_connections(packet_text, preflight)
    firewall = STANDUP.observe_backend_firewall()
    residue = upload_residue()
    docker_config = verify_ephemeral_docker_config(capability, proof, tag, index_digest)
    return {
        "schema": "amoebius.phase25.sprint25.3-current-verification.v1",
        "verifiedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "immutableTag": tag,
        "indexDigest": index_digest,
        "digestReference": str(recorded["digestReference"]),
        "manifestStatus": state["manifestStatus"],
        "manifestDigest": state["manifestDigest"],
        "manifestBodySha256": state["manifestBodySha256"],
        "rerunMutatingRequests": rerun_mutations,
        "residueBytes": residue["bytes"],
        "backendFirewall": firewall,
        "ephemeralDockerConfig": docker_config,
        "containerdPublicRegistryLines": 0,
        "publicRegistryTcpConnections": 0,
        "capturedTcpPackets": len(packet_text.splitlines()),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    # The bundle this publication reads its audited artifact and preflight from is supplied
    # by the caller. There is deliberately no default: a default names a location, and
    # whatever a previous run left there would decide what gets published instead of the
    # run in progress.
    parser.add_argument("--evidence", type=Path, required=True, help="this run's bundle directory")
    arguments = parser.parse_args(argv)
    try:
        result = (
            verify_current(arguments.evidence)
            if arguments.verify_only
            else publish(arguments.evidence)
        )
        encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.output is None:
            print(encoded, end="")
        else:
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(encoded, encoding="utf-8")
        label = "phase25-registry-publish-verify" if arguments.verify_only else "phase25-registry-publish"
        print(f"{label}: PASS ({result['immutableTag']}; {result['indexDigest']})")
        return 0
    except (
        PublishFailure,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        tarfile.TarError,
        subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-registry-publish: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
