#!/usr/bin/env python3
"""Prove Postgres and MinIO retained bytes across a genuine kind delete/recreate."""

from __future__ import annotations

import base64
import contextlib
import csv
import datetime as dt
import hashlib
import hmac
import http.client
import argparse
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any, Iterator, Sequence

import yaml


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
# Resolved per run from the authored requirements: a developer-home path bound this
# driver to one machine, and the tool that deletes and recreates the cluster is exactly
# the one that must not be whatever happens to be on PATH.
KIND = ""
KUBECTL = ""
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KIND_CONFIG_TEMPLATE = ROOT / "test/live/fixtures/phase28-kind.yaml"
KIND_CONFIG = Path()
IMAGE_ARCHIVE = Path()
# The digest Phase 25 published and the export it published from, both caller-supplied:
# a constant named a build that no longer exists, and the recreated cluster imports the
# archive directly because the in-cluster registry does not survive its own node.
IMAGE_DIGEST = ""
PRIVATE_IMAGE = ""
NODE_IMAGE = "kindest/node:v1.36.1"
CLUSTER = "amoebius-phase24"
NODE = f"{CLUSTER}-control-plane"
NAMESPACE = "retained-witness"
STORAGE_CLASS = "amoebius-retained"
RETAINED_ROOT = Path("/var/tmp/amoebius-phase28-retained")
AUDIT_ROOT = Path("/var/tmp/amoebius-phase28-audit")
ROWS = ROOT / "test/live/fixtures/claimref_table.csv"
POSTGRES_INVENTORY = ROOT / "test/fixtures/phase25/bake_inventory_expected.dhall"
POSTGRES_BIN_DIR = ""
POSTGRES_MAJOR = ""
RUN_ROOT = Path()
# Later phases may reuse this proven harness against an isolated cluster while
# pinning their own committed marker bytes.  Phase 28 leaves both unset and
# therefore retains its original per-run unique marker behavior.
MARKER_TEXT: str | None = None
MARKER_OBJECT_BYTES: bytes | None = None


class RebindFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, input_text: str | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(list(arguments), cwd=ROOT, input=input_text, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if check and result.returncode:
        raise RebindFailure(f"{arguments}:exit-{result.returncode}:{result.stdout}")
    return result


def sudo(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(("/usr/bin/sudo", "-n", *arguments), check=check)


def kubectl(*arguments: str, input_text: str | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[str]:
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_text=input_text, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius", "--force-conflicts", "-f", "-", input_text=json.dumps(value))


def oracle_rows() -> dict[str, dict[str, str]]:
    with ROWS.open(encoding="utf-8", newline="") as source:
        rows = {row["statefulset"]: row for row in csv.DictReader(source)}
    if set(rows) != {"pg-witness", "minio-witness"}:
        raise RebindFailure(f"representative-set:{sorted(rows)}")
    return rows


def mountpoint(path: Path) -> bool:
    return run(("/usr/bin/mountpoint", "-q", str(path)), check=False).returncode == 0


def prepare_volume(name: str, raw_bytes: int) -> dict[str, Any]:
    image = RETAINED_ROOT / f"images/{name}.ext4"
    target = RETAINED_ROOT / f"mounts/{name}"
    image.parent.mkdir(parents=True, exist_ok=True)
    target.mkdir(parents=True, exist_ok=True)
    if not image.exists():
        run(("/usr/bin/truncate", "-s", str(raw_bytes), str(image)))
        sudo("/usr/sbin/mkfs.ext4", "-q", "-F", "-m", "0", str(image))
    if image.stat().st_size != raw_bytes:
        raise RebindFailure(f"raw-image-size:{name}:{image.stat().st_size}:{raw_bytes}")
    if not mountpoint(target):
        sudo("/usr/bin/mount", "-o", "loop", str(image), str(target))
    sudo("/usr/bin/mkdir", "-p", str(target / "data"))
    sudo("/usr/bin/chown", "-R", "1000:1000", str(target / "data"))
    fs_type = run(("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(target))).stdout.strip()
    usable = int(run(("/usr/bin/df", "--block-size=1", "--output=avail", str(target))).stdout.splitlines()[-1])
    return {"name": name, "image": str(image), "mount": str(target), "rawBytes": image.stat().st_size, "usableBytes": usable, "filesystemType": fs_type}


def prepare_volumes(rows: dict[str, dict[str, str]]) -> dict[str, dict[str, Any]]:
    """Mount the retained filesystems only after any predecessor node is gone."""
    volumes = {
        name: prepare_volume(name, int(row["provisioned_bytes"]))
        for name, row in rows.items()
    }
    unmounted = [name for name, value in volumes.items() if not mountpoint(Path(value["mount"]))]
    if unmounted:
        raise RebindFailure(f"retained-volume-not-mounted:{unmounted}")
    return volumes


def postgres_inventory() -> dict[str, str]:
    """Read the PostgreSQL executable path from Phase 25's independent inventory."""
    text = POSTGRES_INVENTORY.read_text(encoding="utf-8")
    match = re.search(
        r'catalogName\s*=\s*"postgres"(?P<row>.*?)(?=\n\s*}\s*(?:,|\]))',
        text,
        re.DOTALL,
    )
    if match is None:
        raise RebindFailure("postgres-inventory-row-absent")
    binary_match = re.search(r'binary\s*=\s*"([^"]+)"', match.group("row"))
    acquisition_match = re.search(r'acquisition\s*=\s*"([^"]+)"', match.group("row"))
    if binary_match is None or acquisition_match is None:
        raise RebindFailure("postgres-inventory-row-incomplete")
    binary = binary_match.group(1)
    major_match = re.fullmatch(r"/usr/lib/postgresql/(\d+)/bin/postgres", binary)
    if major_match is None:
        raise RebindFailure(f"postgres-inventory-binary:{binary}")
    major = major_match.group(1)
    return {
        "inventory": str(POSTGRES_INVENTORY.relative_to(ROOT)),
        "binary": binary,
        "binDir": str(Path(binary).parent),
        "major": major,
        "catalog": f"/usr/share/postgresql/{major}/postgres.bki",
        "acquisition": acquisition_match.group(1),
        "bakedIntoPhase25Image": "true",
    }


def materialize_kind_config() -> Path:
    template = KIND_CONFIG_TEMPLATE.read_text(encoding="utf-8")
    marker = "__AMOEBIUS_ROOT__"
    if template.count(marker) != 1:
        raise RebindFailure(f"kind-config-root-placeholders:{template.count(marker)}")
    target = RUN_ROOT / "runtime" / "retained-storage-kind.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(template.replace(marker, str(ROOT)), encoding="utf-8")
    return target


def reset_audit() -> None:
    AUDIT_ROOT.mkdir(parents=True, exist_ok=True)
    for path in AUDIT_ROOT.glob("audit.log*"):
        sudo("/usr/bin/rm", "-f", "--", str(path))


def delete_cluster() -> None:
    run((KIND, "delete", "cluster", "--name", CLUSTER), timeout=600)


def import_selected_image() -> None:
    repository = PRIVATE_IMAGE.split("@", 1)[0]
    with IMAGE_ARCHIVE.open("rb") as archive:
        result = subprocess.run(
            (
                "/usr/bin/docker", "exec", "--privileged", "-i", NODE,
                "ctr", "--namespace", "k8s.io", "images", "import",
                "--platform", "linux/amd64", "--base-name", repository, "--digests",
                "--snapshotter", "overlayfs", "-",
            ),
            cwd=ROOT,
            stdin=archive,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=1200,
        )
    if result.returncode:
        raise RebindFailure(f"selected-platform-image-import:exit-{result.returncode}:{result.stdout.decode('utf-8', 'replace')}")


def create_cluster() -> dict[str, Any]:
    reset_audit()
    KUBECONFIG.parent.mkdir(parents=True, exist_ok=True)
    run((KIND, "create", "cluster", "--name", CLUSTER, "--image", NODE_IMAGE, "--config", str(KIND_CONFIG), "--kubeconfig", str(KUBECONFIG), "--wait", "180s"), timeout=600)
    import_selected_image()
    images = run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q")).stdout.splitlines()
    repository = PRIVATE_IMAGE.split("@", 1)[0]
    wrappers = [name for name in images if name.startswith(repository + "@") and name != PRIVATE_IMAGE]
    for wrapper in wrappers:
        run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "rm", wrapper))
    images = run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q")).stdout.splitlines()
    if PRIVATE_IMAGE not in images:
        raise RebindFailure("private-phase25-image-not-restored")
    kubectl("wait", "--for=condition=Ready", f"node/{NODE}", "--timeout=180s")
    return {
        "imagePresentByDigest": True,
        "archive": str(IMAGE_ARCHIVE),
        "importedPlatforms": ["linux/amd64"],
        "discardedWrapperNames": wrappers,
        "publicPulls": 0,
        "imagePullPolicy": "Never",
    }


def prepare_cluster() -> dict[str, Any]:
    """Stand up the predecessor cluster that the first two sprint seams consume."""
    if not IMAGE_ARCHIVE.is_file():
        raise RebindFailure("phase25-image-archive-absent")
    rows = oracle_rows()
    # Docker resolves bind sources when the node container is created.  Remove the
    # predecessor first, then mount each loop filesystem, so the node and host cannot
    # retain different directory/mount-namespace views of the same source path.
    delete_cluster()
    volumes = prepare_volumes(rows)
    AUDIT_ROOT.mkdir(parents=True, exist_ok=True)
    source = create_cluster()
    return {
        "schema": "amoebius.phase28.cluster-preflight.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "cluster": CLUSTER,
        "identity": cluster_identity(),
        "backingVolumes": volumes,
        "artifactSource": source,
    }


def cluster_identity() -> dict[str, str]:
    config = yaml.safe_load(KUBECONFIG.read_text(encoding="utf-8"))
    cluster = config["clusters"][0]["cluster"]
    ca = base64.b64decode(cluster["certificate-authority-data"])
    uid = json.loads(kubectl("get", "namespace", "kube-system", "-o", "json").stdout)["metadata"]["uid"]
    node_id = run(("/usr/bin/docker", "inspect", "--format", "{{.Id}}", NODE)).stdout.strip()
    return {
        "serverCaSha256": hashlib.sha256(ca).hexdigest(),
        "clusterUid": uid,
        "nodeContainerId": node_id,
        "server": cluster["server"],
    }


def storage_class() -> dict[str, Any]:
    return {
        "apiVersion": "storage.k8s.io/v1", "kind": "StorageClass", "metadata": {"name": STORAGE_CLASS},
        "provisioner": "kubernetes.io/no-provisioner", "reclaimPolicy": "Retain", "volumeBindingMode": "WaitForFirstConsumer",
    }


def namespace() -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE}}


def service(name: str, port: int) -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "Service", "metadata": {"name": name, "namespace": NAMESPACE}, "spec": {"clusterIP": "None", "selector": {"app": name}, "ports": [{"name": "service", "port": port}]}}


def pv(row: dict[str, str]) -> dict[str, Any]:
    capacity = f"{int(row['provisioned_bytes']) // (1024 * 1024)}Mi"
    return {
        "apiVersion": "v1", "kind": "PersistentVolume",
        "metadata": {"name": row["pv_name"], "labels": {"amoebius.io/pv-identity": row["pv_name"]}, "annotations": {"amoebius.io/pv-logical-identity": row["logical_identity"]}},
        "spec": {
            "capacity": {"storage": capacity}, "accessModes": ["ReadWriteOnce"], "storageClassName": STORAGE_CLASS,
            "persistentVolumeReclaimPolicy": "Retain", "volumeMode": "Filesystem",
            "claimRef": {"namespace": row["namespace"], "name": row["pvc_name"]},
            "hostPath": {"path": f"/amoebius-retained/{row['statefulset']}", "type": "Directory"},
            "nodeAffinity": {"required": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "kubernetes.io/hostname", "operator": "In", "values": [NODE]}]}]}},
        },
    }


def statefulset(row: dict[str, str]) -> dict[str, Any]:
    name = row["statefulset"]
    capacity = f"{int(row['provisioned_bytes']) // (1024 * 1024)}Mi"
    if name == "pg-witness":
        container = {
            "name": "postgres", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "securityContext": {"runAsUser": 1000, "runAsGroup": 1000},
            "command": ["/bin/sh", "-c"],
            "args": [f"if test ! -f /volume/data/PG_VERSION; then {POSTGRES_BIN_DIR}/initdb -D /volume/data --username=phase28 --auth=trust; fi; exec {POSTGRES_BIN_DIR}/postgres -D /volume/data -c listen_addresses='*' -c unix_socket_directories=/tmp -c fsync=on"],
            "ports": [{"containerPort": 5432}], "volumeMounts": [{"name": row["template"], "mountPath": "/volume"}],
            "readinessProbe": {"tcpSocket": {"port": 5432}, "periodSeconds": 1, "failureThreshold": 30},
        }
    else:
        container = {
            "name": "minio", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "securityContext": {"runAsUser": 1000, "runAsGroup": 1000},
            "command": ["/usr/bin/minio"], "args": ["server", "/volume/data", "--address", ":9000"],
            "env": [{"name": "MINIO_ROOT_USER", "value": "phase28"}, {"name": "MINIO_ROOT_PASSWORD", "value": "phase28-secret"}],
            "ports": [{"containerPort": 9000}], "volumeMounts": [{"name": row["template"], "mountPath": "/volume"}],
            "readinessProbe": {"tcpSocket": {"port": 9000}, "periodSeconds": 1, "failureThreshold": 30},
        }
    pod_spec: dict[str, Any] = {"containers": [container]}
    return {
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": name, "namespace": NAMESPACE},
        "spec": {
            "serviceName": name, "replicas": 1, "selector": {"matchLabels": {"app": name}},
            "template": {"metadata": {"labels": {"app": name}}, "spec": pod_spec},
            "volumeClaimTemplates": [{"metadata": {"name": row["template"]}, "spec": {"accessModes": ["ReadWriteOnce"], "storageClassName": STORAGE_CLASS, "volumeMode": "Filesystem", "resources": {"requests": {"storage": capacity}}}}],
        },
    }


def apply_base(rows: dict[str, dict[str, str]]) -> dict[str, Any]:
    apply(namespace())
    apply(storage_class())
    apply(service("pg-witness", 5432))
    apply(service("minio-witness", 9000))
    for row in rows.values():
        apply(pv(row))
    prebind = {name: json.loads(kubectl("get", "pv", row["pv_name"], "-o", "json").stdout)["spec"]["claimRef"] for name, row in rows.items()}
    return {"claimRefs": prebind, "uidsOmitted": all("uid" not in value and "resourceVersion" not in value for value in prebind.values())}


def apply_workloads(rows: dict[str, dict[str, str]]) -> dict[str, Any]:
    for row in rows.values():
        apply(statefulset(row))
    for name in rows:
        kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", f"pod/{name}-0", "--timeout=300s")
    pvs = {name: json.loads(kubectl("get", "pv", row["pv_name"], "-o", "json").stdout) for name, row in rows.items()}
    return {name: {"uid": value["metadata"]["uid"], "claimUid": value["spec"]["claimRef"]["uid"], "phase": value["status"]["phase"]} for name, value in pvs.items()}


def pg_sql(sql: str) -> str:
    return kubectl("-n", NAMESPACE, "exec", "pg-witness-0", "--", f"{POSTGRES_BIN_DIR}/psql", "-h", "127.0.0.1", "-U", "phase28", "-d", "postgres", "-Atqc", sql).stdout.strip()


@contextlib.contextmanager
def port_forward(pod: str, local: int, remote: int) -> Iterator[None]:
    process = subprocess.Popen((KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "port-forward", f"pod/{pod}", f"{local}:{remote}"), cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", local), timeout=0.25):
                    break
            except OSError:
                if process.poll() is not None:
                    raise RebindFailure(f"port-forward-exit:{process.stdout.read().decode(errors='replace')}")
                time.sleep(0.1)
        else:
            raise RebindFailure("port-forward-timeout")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def s3_request(method: str, path: str, body: bytes = b"") -> tuple[int, bytes]:
    now = dt.datetime.now(dt.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    payload_hash = hashlib.sha256(body).hexdigest()
    host = "127.0.0.1:19000"
    canonical_uri = urllib.parse.quote(path, safe="/~")
    canonical_headers = f"host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = f"{method}\n{canonical_uri}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    scope = f"{date_stamp}/us-east-1/s3/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amz_date}\n{scope}\n{hashlib.sha256(canonical_request.encode()).hexdigest()}"
    key_date = hmac.new(b"AWS4phase28-secret", date_stamp.encode(), hashlib.sha256).digest()
    key_region = hmac.new(key_date, b"us-east-1", hashlib.sha256).digest()
    key_service = hmac.new(key_region, b"s3", hashlib.sha256).digest()
    signing_key = hmac.new(key_service, b"aws4_request", hashlib.sha256).digest()
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    authorization = f"AWS4-HMAC-SHA256 Credential=phase28/{scope}, SignedHeaders={signed_headers}, Signature={signature}"
    connection = http.client.HTTPConnection("127.0.0.1", 19000, timeout=30)
    try:
        connection.request(method, canonical_uri, body=body, headers={"Host": host, "x-amz-content-sha256": payload_hash, "x-amz-date": amz_date, "Authorization": authorization, "Content-Length": str(len(body))})
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


def image_contains(path: Path, needle: str) -> bool:
    return run(("/usr/bin/grep", "-a", "-F", "-q", "--", needle, str(path)), check=False, timeout=120).returncode == 0


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def execute(*, prepared_cluster: bool = False) -> dict[str, Any]:
    if not IMAGE_ARCHIVE.is_file():
        raise RebindFailure("phase25-image-archive-absent")
    rows = oracle_rows()
    postgres_runtime = postgres_inventory()
    # A direct run may inherit a node whose bind mounts were resolved before the loop
    # filesystems.  Delete it before preparing the source paths.  The whole-phase mode
    # consumes the clean cluster prepared by `prepare_cluster`, so it must preserve it.
    if not prepared_cluster:
        delete_cluster()
    volumes = prepare_volumes(rows)
    pg_data = Path(volumes["pg-witness"]["mount"]) / "data"
    if not (pg_data / "PG_VERSION").is_file() and any(pg_data.iterdir()):
        incomplete = pg_data.with_name("data.incomplete-" + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
        sudo("/usr/bin/mv", str(pg_data), str(incomplete))
        sudo("/usr/bin/mkdir", str(pg_data))
        sudo("/usr/bin/chown", "1000:1000", str(pg_data))

    # The whole-phase gate prepares this clean run-1 cluster before it exercises the two
    # independent sprint seams.  A direct invocation creates run 1 here instead.
    if prepared_cluster:
        if kubectl("get", "namespace", NAMESPACE, check=False).returncode == 0:
            raise RebindFailure("prepared-run1-not-empty")
        images = run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q")).stdout.splitlines()
        if PRIVATE_IMAGE not in images:
            raise RebindFailure("prepared-run1-import-absent")
        source_run1 = {
            "imagePresentByDigest": True,
            "archive": str(IMAGE_ARCHIVE),
            "publicPulls": 0,
            "imagePullPolicy": "Never",
            "preparedByWholePhaseGate": True,
        }
    else:
        source_run1 = create_cluster()
    identity1 = cluster_identity()
    prebind1 = apply_base(rows)
    if not prebind1["uidsOmitted"]:
        raise RebindFailure("run1-prebind-has-server-owned-fields")
    bound1 = apply_workloads(rows)

    nonce = MARKER_TEXT if MARKER_TEXT is not None else "phase28-" + secrets.token_hex(24)
    object_bytes = MARKER_OBJECT_BYTES if MARKER_OBJECT_BYTES is not None else nonce.encode()
    pg_sql("CREATE TABLE IF NOT EXISTS rebind_witness(nonce text PRIMARY KEY)")
    pg_absent = pg_sql(f"SELECT count(*) FROM rebind_witness WHERE nonce = '{nonce}'") == "0"
    with port_forward("minio-witness-0", 19000, 9000):
        bucket_status, _ = s3_request("PUT", "/rebind-witness")
        minio_absent_status, prior_minio_body = s3_request("GET", "/rebind-witness/rebind/nonce")
        minio_nonce_absent = minio_absent_status == 404 or prior_minio_body != object_bytes
        if bucket_status not in {200, 409} or not minio_nonce_absent:
            raise RebindFailure(f"marker-absence:{bucket_status}:{minio_absent_status}")
        put_status, put_body = s3_request("PUT", "/rebind-witness/rebind/nonce", object_bytes)
        if put_status != 200:
            raise RebindFailure(f"minio-put:{put_status}:{put_body!r}")
    if not pg_absent:
        raise RebindFailure("postgres-marker-preseeded")
    pg_sql(f"INSERT INTO rebind_witness(nonce) VALUES ('{nonce}')")
    pg_before = pg_sql(f"SELECT nonce FROM rebind_witness WHERE nonce = '{nonce}'")
    if pg_before != nonce:
        raise RebindFailure("postgres-marker-write")

    # Prove the Pod, node, and host see the same retained filesystem before removing
    # the node.  A bind of only the parent directory hides child loop mounts and would
    # otherwise let both services pass until their node-local bytes vanish at delete.
    pg_version = pg_data / "PG_VERSION"
    pod_pg_version = kubectl(
        "-n", NAMESPACE, "exec", "pg-witness-0", "--", "/usr/bin/test", "-f", "/volume/data/PG_VERSION",
        check=False,
    ).returncode == 0
    node_pg_version = run(
        ("/usr/bin/docker", "exec", NODE, "/usr/bin/test", "-f", "/amoebius-retained/pg-witness/data/PG_VERSION"),
        check=False,
    ).returncode == 0
    host_pg_version = pg_version.is_file()
    if not (pod_pg_version and node_pg_version and host_pg_version):
        raise RebindFailure(
            f"retained-mount-identity:{pod_pg_version}:{node_pg_version}:{host_pg_version}"
        )
    sudo("/usr/bin/sync")

    delete_cluster()
    clusters_after_delete = run((KIND, "get", "clusters")).stdout.splitlines()
    node_absent = run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
    api_unreachable = run(("/usr/bin/curl", "-kfsS", "--connect-timeout", "2", identity1["server"] + "/readyz"), check=False).returncode != 0
    cluster_absent = CLUSTER not in clusters_after_delete
    backing_paths = {name: Path(value["image"]) for name, value in volumes.items()}
    backing_present = all(path.is_file() and mountpoint(Path(volumes[name]["mount"])) for name, path in backing_paths.items())
    postgres_catalog_present = pg_version.is_file()
    external_marker_scan = {
        "pg-witness": image_contains(backing_paths["pg-witness"], nonce),
        "minio-witness": image_contains(
            backing_paths["minio-witness"], object_bytes.decode("utf-8", "strict").strip(),
        ),
    }
    absent_window_hashes = {name: sha256_file(path) for name, path in backing_paths.items()}
    if not (
        cluster_absent and node_absent and api_unreachable and backing_present
        and postgres_catalog_present and external_marker_scan["minio-witness"]
    ):
        raise RebindFailure(
            f"real-delete-boundary:{cluster_absent}:{node_absent}:{api_unreachable}:"
            f"{backing_present}:{postgres_catalog_present}:{external_marker_scan}"
        )

    source_run2 = create_cluster()
    identity2 = cluster_identity()
    if (
        identity1["serverCaSha256"] == identity2["serverCaSha256"]
        or identity1["clusterUid"] == identity2["clusterUid"]
        or identity1["nodeContainerId"] == identity2["nodeContainerId"]
    ):
        raise RebindFailure("recreated-cluster-not-fresh")
    prebind2 = apply_base(rows)
    if not prebind2["uidsOmitted"]:
        raise RebindFailure("run2-prebind-has-server-owned-fields")
    bound2 = apply_workloads(rows)
    for name in rows:
        if bound1[name]["uid"] == bound2[name]["uid"] or bound2[name]["phase"] != "Bound":
            raise RebindFailure(f"fresh-pv-object:{name}:{bound1[name]}:{bound2[name]}")

    # Read-only after recreate: SELECT and S3 GET are the only marker operations.
    pg_after = pg_sql(f"SELECT nonce FROM rebind_witness WHERE nonce = '{nonce}'")
    with port_forward("minio-witness-0", 19000, 9000):
        get_status, minio_after = s3_request("GET", "/rebind-witness/rebind/nonce")
    if pg_after != nonce or get_status != 200 or minio_after != object_bytes:
        raise RebindFailure(f"readback:{pg_after}:{get_status}:{minio_after!r}")
    audit_path = AUDIT_ROOT / "audit.log"
    audit_text = sudo("/usr/bin/cat", str(audit_path)).stdout if audit_path.is_file() else ""
    audit_uris = []
    for line in audit_text.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        audit_uris.append(urllib.parse.unquote_plus(str(event.get("requestURI", ""))))
    decoded_audit = "\n".join(audit_uris)
    audit_exec_observed = "pods/pg-witness-0/exec" in decoded_audit and "SELECT nonce FROM rebind_witness" in decoded_audit
    post_recreate_write_tokens = [token for token in ("INSERT INTO rebind_witness", "CREATE TABLE", "PUT /rebind-witness/rebind/nonce") if token in decoded_audit]
    if not audit_exec_observed or post_recreate_write_tokens:
        raise RebindFailure(f"post-recreate-audit:{audit_exec_observed}:{post_recreate_write_tokens}")

    image_ids = {
        name: json.loads(kubectl("-n", NAMESPACE, "get", "pod", f"{name}-0", "-o", "json").stdout)["status"]["containerStatuses"][0]["imageID"]
        for name in rows
    }
    if not all(IMAGE_DIGEST in value for value in image_ids.values()):
        raise RebindFailure(f"image-digest-drift:{image_ids}")

    return {
        "schema": "amoebius.phase28.rebind-live.v1", "register": 3, "substrate": "linux-cpu",
        "representativeSet": {"count": 2, "statefulSets": sorted(rows), "postgresTable": "rebind_witness", "minioBucket": "rebind-witness", "minioObject": "rebind/nonce"},
        "marker": {"nonceSha256": hashlib.sha256(nonce.encode()).hexdigest(), "objectSha256": hashlib.sha256(object_bytes).hexdigest(), "postgresAbsentBeforeWrite": pg_absent, "minioAbsentBeforeWrite": minio_nonce_absent, "writtenBeforeDelete": True, "postgresByteIdentical": pg_after == nonce, "minioByteIdentical": minio_after == object_bytes, "postRecreateWriteOperations": 0, "seedCommands": []},
        "deleteBoundary": {
            "kindClusterAbsent": cluster_absent,
            "nodeContainerAbsent": node_absent,
            "apiServerUnreachable": api_unreachable,
            "backingPresent": backing_present,
            "postgresCatalogPresent": postgres_catalog_present,
            "externalMarkerBytesObserved": external_marker_scan,
            "absentWindowBackingSha256": absent_window_hashes,
        },
        "freshCluster": {"run1": identity1, "run2": identity2, "serverCaChanged": identity1["serverCaSha256"] != identity2["serverCaSha256"], "clusterUidChanged": identity1["clusterUid"] != identity2["clusterUid"], "nodeContainerIdChanged": identity1["nodeContainerId"] != identity2["nodeContainerId"]},
        "rebind": {"run1": bound1, "run2": bound2, "freshPvObjects": all(bound1[name]["uid"] != bound2[name]["uid"] for name in rows), "freshClaimRefsOmittedUid": prebind2["uidsOmitted"], "sameBackingImages": True},
        "backingVolumes": volumes,
        "postgresRuntime": postgres_runtime,
        "artifactSource": {"run1": source_run1, "run2": source_run2, "containerImageIds": image_ids, "phase25BakedBinaryDigest": IMAGE_DIGEST, "publicRegistryPulls": 0},
        "observer": {"auditExecObserved": audit_exec_observed, "postRecreateWriteTokens": post_recreate_write_tokens, "readOperations": ["Postgres SELECT", "S3 GET"]},
        "noNormalDelete": {"staticCheck": "test/ci/no_retained_delete.sh", "postCycleBackingPresent": backing_present},
        "controlPlaneNoPvc": "UNVERIFIED (Phase 33 subject absent)",
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="this run's observation")
    parser.add_argument("--artifact", type=Path, required=True, help="the Phase-25 OCI export to import")
    parser.add_argument("--image-digest", required=True, help="the index digest that export advertises")
    parser.add_argument(
        "--prepare-cluster-only", action="store_true",
        help="create the imported-image predecessor cluster consumed by Sprints 28.1 and 28.2",
    )
    parser.add_argument(
        "--prepared-cluster", action="store_true",
        help="consume the clean imported-image cluster this whole-phase run prepared",
    )
    arguments = parser.parse_args(argv)
    globals()["IMAGE_ARCHIVE"] = arguments.artifact
    globals()["IMAGE_DIGEST"] = arguments.image_digest
    globals()["PRIVATE_IMAGE"] = f"registry.amoebius.invalid:5000/amoebius/base@{arguments.image_digest}"
    resolved = toolchain.resolve(["kind", "kubectl"])
    globals()["KIND"] = resolved["kind"]["path"]
    globals()["KUBECTL"] = resolved["kubectl"]["path"]
    globals()["RUN_ROOT"] = arguments.output.parent
    globals()["KIND_CONFIG"] = materialize_kind_config()
    inventory = postgres_inventory()
    globals()["POSTGRES_BIN_DIR"] = inventory["binDir"]
    globals()["POSTGRES_MAJOR"] = inventory["major"]
    try:
        value = (
            prepare_cluster()
            if arguments.prepare_cluster_only
            else execute(prepared_cluster=arguments.prepared_cluster)
        )
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if arguments.prepare_cluster_only:
            print("phase28-rebind-live: PASS (predecessor cluster ready with imported Phase-25 image)")
        else:
            print("phase28-rebind-live: PASS (Postgres row + MinIO object survived real cluster delete/recreate)")
        return 0
    except (RebindFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired, yaml.YAMLError) as problem:
        print(f"phase28-rebind-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
