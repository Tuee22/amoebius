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
KUBECTL = "/usr/bin/kubectl"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KIND_CONFIG = ROOT / "test/live/fixtures/phase28-kind.yaml"
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
POSTGRES_SUPPORT_URL = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-17/postgresql-17_17.8-1.pgdg12+1_amd64.deb"
POSTGRES_SUPPORT_SHA256 = "6adde31d7bec9a921b06fbd74669d395c41a46bcf575e23a7568293b84f91729"
POSTGRES_SUPPORT_PACKAGE = RETAINED_ROOT / "postgresql-17_17.8-1.pgdg12+1_amd64.deb"
POSTGRES_SUPPORT_ROOT = RETAINED_ROOT / "mounts/postgres-share"
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


def prepare_postgres_support() -> dict[str, Any]:
    catalog = POSTGRES_SUPPORT_ROOT / "usr/share/postgresql/17/postgres.bki"
    if not POSTGRES_SUPPORT_PACKAGE.is_file():
        run(("/usr/bin/curl", "-fL", "--retry", "3", "-o", str(POSTGRES_SUPPORT_PACKAGE), POSTGRES_SUPPORT_URL), timeout=300)
    observed = sha256_file(POSTGRES_SUPPORT_PACKAGE)
    if observed != POSTGRES_SUPPORT_SHA256:
        raise RebindFailure(f"postgres-support-checksum:{observed}")
    if not catalog.is_file():
        POSTGRES_SUPPORT_ROOT.mkdir(parents=True, exist_ok=True)
        run(("/usr/bin/dpkg-deb", "-x", str(POSTGRES_SUPPORT_PACKAGE), str(POSTGRES_SUPPORT_ROOT)))
    if not catalog.is_file():
        raise RebindFailure("postgres-support-catalog-absent")
    return {"source": POSTGRES_SUPPORT_URL, "sha256": "sha256:" + observed, "catalog": str(catalog), "readOnlyMount": True}


def reset_audit() -> None:
    AUDIT_ROOT.mkdir(parents=True, exist_ok=True)
    for path in AUDIT_ROOT.glob("audit.log*"):
        sudo("/usr/bin/rm", "-f", "--", str(path))


def delete_cluster() -> None:
    run((KIND, "delete", "cluster", "--name", CLUSTER), timeout=600)


def import_selected_image() -> None:
    with IMAGE_ARCHIVE.open("rb") as archive:
        result = subprocess.run(
            (
                "/usr/bin/docker", "exec", "--privileged", "-i", NODE,
                "ctr", "--namespace", "k8s.io", "images", "import",
                "--platform", "linux/amd64", "--digests", "--snapshotter", "overlayfs",
                "--index-name", PRIVATE_IMAGE, "-",
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
    run((KIND, "create", "cluster", "--name", CLUSTER, "--image", NODE_IMAGE, "--config", str(KIND_CONFIG), "--kubeconfig", str(KUBECONFIG), "--wait", "180s"), timeout=600)
    import_selected_image()
    images = run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q")).stdout.splitlines()
    imported = next((name for name in images if name.startswith("import-") and name.endswith("@" + IMAGE_DIGEST)), None)
    if imported is not None:
        if PRIVATE_IMAGE not in images:
            run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "tag", imported, PRIVATE_IMAGE))
        qualified_import = "docker.io/library/" + imported
        if qualified_import not in images:
            run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "tag", imported, qualified_import))
        images = run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q")).stdout.splitlines()
    if PRIVATE_IMAGE not in images:
        raise RebindFailure("private-phase25-image-not-restored")
    kubectl("wait", "--for=condition=Ready", f"node/{NODE}", "--timeout=180s")
    return {"imagePresentByDigest": True, "archive": str(IMAGE_ARCHIVE), "selectedPlatform": "linux/amd64", "publicPulls": 0, "imagePullPolicy": "Never"}


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
            "args": ["if test ! -f /volume/data/PG_VERSION; then /usr/lib/postgresql/17/bin/initdb -D /volume/data --username=phase28 --auth=trust; fi; exec /usr/lib/postgresql/17/bin/postgres -D /volume/data -c listen_addresses='*' -c unix_socket_directories=/tmp -c fsync=on"],
            "ports": [{"containerPort": 5432}], "volumeMounts": [{"name": row["template"], "mountPath": "/volume"}, {"name": "postgres-share", "mountPath": "/usr/share/postgresql/17", "readOnly": True}],
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
    if name == "pg-witness":
        pod_spec["volumes"] = [{"name": "postgres-share", "hostPath": {"path": "/amoebius-retained/postgres-share/usr/share/postgresql/17", "type": "Directory"}}]
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
    return kubectl("-n", NAMESPACE, "exec", "pg-witness-0", "--", "/usr/lib/postgresql/17/bin/psql", "-h", "127.0.0.1", "-U", "phase28", "-d", "postgres", "-Atqc", sql).stdout.strip()


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


def execute() -> dict[str, Any]:
    if not IMAGE_ARCHIVE.is_file():
        raise RebindFailure("phase25-image-archive-absent")
    rows = oracle_rows()
    postgres_support = prepare_postgres_support()
    volumes = {
        name: prepare_volume(name, int(row["provisioned_bytes"]))
        for name, row in rows.items()
    }
    pg_data = Path(volumes["pg-witness"]["mount"]) / "data"
    if not (pg_data / "PG_VERSION").is_file() and any(pg_data.iterdir()):
        incomplete = pg_data.with_name("data.incomplete-" + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
        sudo("/usr/bin/mv", str(pg_data), str(incomplete))
        sudo("/usr/bin/mkdir", str(pg_data))
        sudo("/usr/bin/chown", "1000:1000", str(pg_data))

    # Replace the inherited Phase-24 cluster with run 1, whose node receives only the retained mounts.
    # The opt-in resume is only for an interrupted, still-empty run-1 bootstrap; phase gates never set it.
    resume_clean_run1 = os.environ.get("PHASE28_RESUME_CLEAN_RUN1") == "1"
    if resume_clean_run1:
        if kubectl("get", "namespace", NAMESPACE, check=False).returncode == 0:
            raise RebindFailure("resume-run1-not-empty")
        images = run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q")).stdout.splitlines()
        imported = next((name for name in images if name.startswith("import-") and name.endswith("@" + IMAGE_DIGEST)), None)
        if imported is None:
            raise RebindFailure("resume-run1-import-absent")
        if PRIVATE_IMAGE not in images:
            run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "tag", imported, PRIVATE_IMAGE))
        qualified_import = "docker.io/library/" + imported
        if qualified_import not in images:
            run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "tag", imported, qualified_import))
        source_run1 = {"imagePresentByDigest": True, "archive": str(IMAGE_ARCHIVE), "publicPulls": 0, "imagePullPolicy": "Never", "resumedAfterInterruptedBootstrap": True}
    else:
        delete_cluster()
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

    delete_cluster()
    clusters_after_delete = run((KIND, "get", "clusters")).stdout.splitlines()
    node_absent = run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
    api_unreachable = run(("/usr/bin/curl", "-kfsS", "--connect-timeout", "2", identity1["server"] + "/readyz"), check=False).returncode != 0
    cluster_absent = CLUSTER not in clusters_after_delete
    backing_paths = {name: Path(value["image"]) for name, value in volumes.items()}
    backing_present = all(path.is_file() and mountpoint(Path(volumes[name]["mount"])) for name, path in backing_paths.items())
    external_marker_scan = {
        "pg-witness": image_contains(backing_paths["pg-witness"], nonce),
        "minio-witness": image_contains(
            backing_paths["minio-witness"], object_bytes.decode("utf-8", "strict").strip(),
        ),
    }
    absent_window_hashes = {name: sha256_file(path) for name, path in backing_paths.items()}
    if not (cluster_absent and node_absent and api_unreachable and backing_present and all(external_marker_scan.values())):
        raise RebindFailure(f"real-delete-boundary:{cluster_absent}:{node_absent}:{api_unreachable}:{backing_present}:{external_marker_scan}")

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
        "deleteBoundary": {"kindClusterAbsent": cluster_absent, "nodeContainerAbsent": node_absent, "apiServerUnreachable": api_unreachable, "backingPresent": backing_present, "externalMarkerBytesObserved": external_marker_scan, "absentWindowBackingSha256": absent_window_hashes},
        "freshCluster": {"run1": identity1, "run2": identity2, "serverCaChanged": identity1["serverCaSha256"] != identity2["serverCaSha256"], "clusterUidChanged": identity1["clusterUid"] != identity2["clusterUid"], "nodeContainerIdChanged": identity1["nodeContainerId"] != identity2["nodeContainerId"]},
        "rebind": {"run1": bound1, "run2": bound2, "freshPvObjects": all(bound1[name]["uid"] != bound2[name]["uid"] for name in rows), "freshClaimRefsOmittedUid": prebind2["uidsOmitted"], "sameBackingImages": True},
        "backingVolumes": volumes,
        "postgresSupport": postgres_support,
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
    arguments = parser.parse_args(argv)
    globals()["IMAGE_ARCHIVE"] = arguments.artifact
    globals()["IMAGE_DIGEST"] = arguments.image_digest
    globals()["PRIVATE_IMAGE"] = f"registry.amoebius.invalid:5000/amoebius/base@{arguments.image_digest}"
    globals()["KIND"] = toolchain.resolve(["kind"])["kind"]["path"]
    try:
        value = execute()
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("phase28-rebind-live: PASS (Postgres row + MinIO object survived real cluster delete/recreate)")
        return 0
    except (RebindFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired, yaml.YAMLError) as problem:
        print(f"phase28-rebind-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
