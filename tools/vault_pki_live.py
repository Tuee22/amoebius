#!/usr/bin/env python3
"""Run the root Vault, PKI, direct-client, and retained-rebuild proof."""

from __future__ import annotations

import argparse
import base64
import contextlib
import hashlib
import http.client
import json
import os
import secrets
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterator, Sequence

import yaml


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
KIND = ""
KUBECTL = ""
CABAL = ""
KUBECONFIG = Path(os.environ.get("AMOEBIUS_KUBECONFIG", ROOT / ".build/tmp/vault-pki/unconfigured-kubeconfig"))
KIND_CONFIG_TEMPLATE = ROOT / "test/fixture/vault_pki/kind.yaml"
KIND_CONFIG = Path()
IMAGE_ARCHIVE = Path()
IMAGE_DIGEST = ""
PRIVATE_IMAGE = ""
NODE_IMAGE = "kindest/node:v1.36.1"
CLUSTER = "amoebius-bootstrap-coordinator"
NODE = f"{CLUSTER}-control-plane"
NAMESPACE = "vault-system"
CONSUMER_NAMESPACE = "vault-consumer"
STORAGE_CLASS = "amoebius-retained"
TEST_ROOT = Path(os.environ.get("AMOEBIUS_TEST_ROOT", ROOT / ".build/tmp/vault-pki/unconfigured-test-root"))
RETAINED_ROOT = TEST_ROOT / "retained"
VAULT_IMAGE_BYTES = 134217728
AUDIT_IMAGE_BYTES = 67108864
VAULT_CAPACITY = "128Mi"
AUDIT_CAPACITY = "64Mi"
CANARY_FIXTURE = ROOT / "test/golden/vault/canary.json"
UNLOCK_ENVELOPE = RETAINED_ROOT / "vault-unlock.age"
LOCAL_PORT = 18290


class VaultLiveFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 600,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments),
        cwd=ROOT,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout,
    )
    if check and result.returncode:
        raise VaultLiveFailure(f"{arguments}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def sudo(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return run(("/usr/bin/sudo", "-n", *arguments), check=check)


def kubectl(
    *arguments: str,
    input_value: str | None = None,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 300,
) -> subprocess.CompletedProcess[bytes]:
    payload = input_bytes if input_bytes is not None else (input_value.encode() if input_value is not None else None)
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl(
        "apply",
        "--server-side",
        "--field-manager=amoebius",
        "--force-conflicts",
        "-f",
        "-",
        input_value=json.dumps(value),
    )


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
        raise VaultLiveFailure(f"raw-image-size:{name}:{image.stat().st_size}:{raw_bytes}")
    if not mountpoint(target):
        sudo("/usr/bin/mount", "-o", "loop", str(image), str(target))
    sudo("/usr/bin/chown", "-R", "0:0", str(target))
    filesystem_type = text(run(("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(target)))).strip()
    usable = int(text(run(("/usr/bin/df", "--block-size=1", "--output=avail", str(target)))).splitlines()[-1])
    return {
        "image": str(image),
        "mount": str(target),
        "rawBytes": image.stat().st_size,
        "usableBytes": usable,
        "filesystemType": filesystem_type,
    }


def materialize_kind_config(output_root: Path) -> Path:
    template = KIND_CONFIG_TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "__VAULT_MOUNT__": str(RETAINED_ROOT / "mounts/vault"),
        "__AUDIT_MOUNT__": str(RETAINED_ROOT / "mounts/vault-audit"),
        "__AMOEBIUS_BINARY__": str(TEST_ROOT / "runtime/amoebius"),
    }
    for marker, replacement in replacements.items():
        if template.count(marker) != 1:
            raise VaultLiveFailure(f"kind-config-placeholder:{marker}:{template.count(marker)}")
        template = template.replace(marker, replacement)
    if "__" in template:
        raise VaultLiveFailure("kind-config-unresolved-placeholder")
    target = output_root / "runtime/kind.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(template, encoding="utf-8")
    return target


def install_current_binary() -> dict[str, Any]:
    builddir = ROOT / ".build/dist-newstyle/vault-pki-live"
    store = ROOT / ".build/cabal-store"
    common = (CABAL, f"--builddir={builddir}", f"--store-dir={store}")
    compiler = os.environ.get("AMOEBIUS_GHC")
    if compiler:
        common = (*common, f"--with-compiler={compiler}")
    run((*common, "--jobs=1", "build", "exe:amoebius"), timeout=2400)
    binary = Path(text(run((*common, "list-bin", "exe:amoebius"))).strip())
    destination = TEST_ROOT / "runtime/amoebius"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binary, destination)
    destination.chmod(0o755)
    return {"path": str(destination), "sha256": sha256_file(destination), "compiledFromCurrentTree": True}


def delete_cluster() -> None:
    transcripts: list[str] = []
    for attempt in range(1, 4):
        deleted = run((KIND, "delete", "cluster", "--name", CLUSTER), check=False, timeout=600)
        transcripts.append(f"attempt-{attempt}:{deleted.returncode}:{text(deleted).strip()}")
        clusters = text(run((KIND, "get", "clusters"), check=False)).splitlines()
        node_absent = run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
        if CLUSTER not in clusters and node_absent:
            return
        if attempt < 3:
            # A busy private containerd can occasionally miss Docker's forced-kill
            # exit event immediately after a multi-gigabyte image import.  Give the
            # kind node a bounded graceful-stop opportunity, then ask Kind to own
            # network/volume removal again.  Success is still decided only by the
            # independently observed cluster and container absence above.
            run(("/usr/bin/docker", "stop", "--time", "60", NODE), check=False, timeout=90)
            time.sleep(2)
    raise VaultLiveFailure("cluster-delete:" + " | ".join(transcripts))


def import_selected_image() -> None:
    repository = PRIVATE_IMAGE.split("@", 1)[0]
    with IMAGE_ARCHIVE.open("rb") as archive:
        result = subprocess.run(
            (
                "/usr/bin/docker", "exec", "--privileged", "-i", NODE,
                "ctr", "--namespace", "k8s.io", "images", "import",
                "--platform", "linux/amd64", "--base-name", repository,
                "--digests", "--snapshotter", "overlayfs", "-",
            ),
            cwd=ROOT,
            stdin=archive,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=1200,
        )
    if result.returncode:
        raise VaultLiveFailure(f"selected-platform-image-import:exit-{result.returncode}:{result.stdout.decode('utf-8', 'replace')}")


def create_cluster() -> dict[str, Any]:
    KUBECONFIG.parent.mkdir(parents=True, exist_ok=True)
    run(
        (
            KIND,
            "create",
            "cluster",
            "--name",
            CLUSTER,
            "--image",
            NODE_IMAGE,
            "--config",
            str(KIND_CONFIG),
            "--kubeconfig",
            str(KUBECONFIG),
            "--wait",
            "180s",
        ),
        timeout=600,
    )
    import_selected_image()
    images = text(run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q"))).splitlines()
    repository = PRIVATE_IMAGE.split("@", 1)[0]
    wrappers = [name for name in images if name.startswith(repository + "@") and name != PRIVATE_IMAGE]
    for wrapper in wrappers:
        run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "rm", wrapper))
    images = text(run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q"))).splitlines()
    if PRIVATE_IMAGE not in images:
        raise VaultLiveFailure("private-phase25-image-not-restored")
    kubectl("wait", "--for=condition=Ready", f"node/{NODE}", "--timeout=180s")
    return {"archive": str(IMAGE_ARCHIVE), "digest": IMAGE_DIGEST, "selectedPlatform": "linux/amd64", "imagePullPolicy": "Never", "publicPulls": 0, "discardedWrapperNames": wrappers}


def cluster_identity() -> dict[str, str]:
    config = yaml.safe_load(KUBECONFIG.read_text(encoding="utf-8"))
    cluster = config["clusters"][0]["cluster"]
    ca = base64.b64decode(cluster["certificate-authority-data"])
    uid = json.loads(text(kubectl("get", "namespace", "kube-system", "-o", "json")))["metadata"]["uid"]
    return {"serverCaSha256": hashlib.sha256(ca).hexdigest(), "clusterUid": uid, "server": cluster["server"]}


def storage_class() -> dict[str, Any]:
    return {
        "apiVersion": "storage.k8s.io/v1",
        "kind": "StorageClass",
        "metadata": {"name": STORAGE_CLASS},
        "provisioner": "kubernetes.io/no-provisioner",
        "reclaimPolicy": "Retain",
        "volumeBindingMode": "WaitForFirstConsumer",
    }


def persistent_volume(name: str, capacity: str, claim: str, host_path: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1",
        "kind": "PersistentVolume",
        "metadata": {
            "name": name,
            "labels": {"amoebius.io/pv-identity": name},
            "annotations": {"amoebius.io/pv-logical-identity": f"{NAMESPACE}/root-vault/{name}"},
        },
        "spec": {
            "capacity": {"storage": capacity},
            "accessModes": ["ReadWriteOnce"],
            "storageClassName": STORAGE_CLASS,
            "persistentVolumeReclaimPolicy": "Retain",
            "volumeMode": "Filesystem",
            "claimRef": {"namespace": NAMESPACE, "name": claim},
            "hostPath": {"path": host_path, "type": "Directory"},
            "nodeAffinity": {
                "required": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {"key": "kubernetes.io/hostname", "operator": "In", "values": [NODE]}
                            ]
                        }
                    ]
                }
            },
        },
    }


def stateful_set() -> dict[str, Any]:
    return {
        "apiVersion": "apps/v1",
        "kind": "StatefulSet",
        "metadata": {"name": "root-vault", "namespace": NAMESPACE},
        "spec": {
            "serviceName": "root-vault-internal",
            "replicas": 1,
            "selector": {"matchLabels": {"app": "root-vault"}},
            "template": {
                "metadata": {"labels": {"app": "root-vault"}},
                "spec": {
                    "serviceAccountName": "root-vault",
                    "securityContext": {"runAsUser": 0, "runAsGroup": 0},
                    "containers": [
                        {
                            "name": "vault",
                            "image": PRIVATE_IMAGE,
                            "imagePullPolicy": "Never",
                            "command": ["/bin/sh", "-c"],
                            "args": ["mkdir -p /vault/data/raft /vault/audit && exec /usr/bin/vault server -config=/vault/config/server.hcl"],
                            "env": [{"name": "VAULT_ADDR", "value": "http://127.0.0.1:8200"}],
                            "ports": [{"name": "http", "containerPort": 8200}, {"name": "cluster", "containerPort": 8201}],
                            "resources": {
                                "requests": {"cpu": "100m", "memory": "128Mi", "ephemeral-storage": "32Mi"},
                                "limits": {"cpu": "500m", "memory": "512Mi", "ephemeral-storage": "64Mi"},
                            },
                            "volumeMounts": [
                                {"name": "data", "mountPath": "/vault/data"},
                                {"name": "audit", "mountPath": "/vault/audit"},
                                {"name": "config", "mountPath": "/vault/config", "readOnly": True},
                            ],
                            "readinessProbe": {
                                "exec": {"command": ["/bin/sh", "-c", "VAULT_ADDR=http://127.0.0.1:8200 vault status >/dev/null 2>&1"]},
                                "periodSeconds": 2,
                                "failureThreshold": 60,
                            },
                        }
                    ],
                    "volumes": [{"name": "config", "configMap": {"name": "root-vault-config"}}],
                },
            },
            "volumeClaimTemplates": [
                {
                    "metadata": {"name": "data"},
                    "spec": {
                        "accessModes": ["ReadWriteOnce"],
                        "storageClassName": STORAGE_CLASS,
                        "resources": {"requests": {"storage": VAULT_CAPACITY}},
                    },
                },
                {
                    "metadata": {"name": "audit"},
                    "spec": {
                        "accessModes": ["ReadWriteOnce"],
                        "storageClassName": STORAGE_CLASS,
                        "resources": {"requests": {"storage": AUDIT_CAPACITY}},
                    },
                },
            ],
        },
    }


def apply_vault() -> dict[str, Any]:
    kubectl("delete", "storageclass", "standard", "--ignore-not-found=true")
    persistent_volumes = [
        persistent_volume("vault-system.root-vault.pv-0", VAULT_CAPACITY, "data-root-vault-0", "/amoebius-retained/vault"),
        persistent_volume("vault-system.root-vault-audit.pv-0", AUDIT_CAPACITY, "audit-root-vault-0", "/amoebius-retained/vault-audit"),
    ]
    prebinds = [volume["spec"]["claimRef"] for volume in persistent_volumes]
    resources = [
        {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE}},
        storage_class(),
        {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {"name": "root-vault-config", "namespace": NAMESPACE},
            "data": {
                "server.hcl": 'storage "raft" { path = "/vault/data/raft" node_id = "root-vault-0" }\nlistener "tcp" { address = "0.0.0.0:8200" cluster_address = "0.0.0.0:8201" tls_disable = 1 }\ndisable_mlock = true\napi_addr = "http://root-vault-0.root-vault-internal.vault-system.svc:8200"\ncluster_addr = "http://root-vault-0.root-vault-internal.vault-system.svc:8201"\nui = false\n',
            },
        },
        {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "root-vault", "namespace": NAMESPACE}},
        {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "ClusterRoleBinding",
            "metadata": {"name": "root-vault-token-review"},
            "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "system:auth-delegator"},
            "subjects": [{"kind": "ServiceAccount", "name": "root-vault", "namespace": NAMESPACE}],
        },
        {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": "root-vault-internal", "namespace": NAMESPACE},
            "spec": {"clusterIP": "None", "selector": {"app": "root-vault"}, "ports": [{"name": "http", "port": 8200}]},
        },
        {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": "root-vault", "namespace": NAMESPACE},
            "spec": {"selector": {"app": "root-vault"}, "ports": [{"name": "http", "port": 8200}]},
        },
        *persistent_volumes,
        stateful_set(),
    ]
    for resource in resources:
        apply(resource)
    wait_pod_running()
    return {"claimRefsOmitServerFields": all("uid" not in value and "resourceVersion" not in value for value in prebinds)}


def wait_pod_running() -> None:
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        result = kubectl("-n", NAMESPACE, "get", "pod", "root-vault-0", "-o", "json", check=False)
        if result.returncode == 0:
            status = json.loads(text(result)).get("status", {})
            containers = status.get("containerStatuses", [])
            if status.get("phase") == "Running" and containers and containers[0].get("state", {}).get("running") is not None:
                return
        time.sleep(2)
    raise VaultLiveFailure("vault-pod-running-timeout")


def vault_status() -> dict[str, Any]:
    deadline = time.monotonic() + 180
    last = ""
    while time.monotonic() < deadline:
        result = kubectl("-n", NAMESPACE, "exec", "root-vault-0", "--", "/bin/sh", "-c", "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json || true", check=False)
        last = text(result)
        try:
            return json.loads(last)
        except json.JSONDecodeError:
            time.sleep(1)
    raise VaultLiveFailure(f"vault-status-timeout:{last}")


def initialize_vault(password: bytes, binary_path: Path) -> tuple[dict[str, Any], str, str]:
    before = vault_status()
    if before.get("initialized"):
        raise VaultLiveFailure("run1-vault-already-initialized")
    initialized = kubectl(
        "-n",
        NAMESPACE,
        "exec",
        "root-vault-0",
        "--",
        "/bin/sh",
        "-c",
        "VAULT_ADDR=http://127.0.0.1:8200 vault operator init -key-shares=1 -key-threshold=1 -format=json",
    )
    material = json.loads(text(initialized))
    unseal_key = material["unseal_keys_b64"][0]
    root_token = material["root_token"]
    plaintext = json.dumps({"unseal_key": unseal_key, "root_token": root_token}, separators=(",", ":")).encode()
    sealed = run((str(binary_path), "vault-seal-unlock"), input_bytes=password + b"\n" + plaintext, timeout=120)
    UNLOCK_ENVELOPE.write_bytes(sealed.stdout)
    UNLOCK_ENVELOPE.chmod(0o600)
    del material
    del plaintext
    return before, unseal_key, root_token


def open_unlock(password: bytes, binary_path: Path) -> dict[str, str]:
    opened = run((str(binary_path), "vault-open-unlock"), input_bytes=password + b"\n" + UNLOCK_ENVELOPE.read_bytes(), timeout=120)
    return json.loads(opened.stdout)


def unseal(unseal_key: str) -> dict[str, Any]:
    with port_forward():
        response_status, payload = api_request("PUT", "sys/unseal", body={"key": unseal_key})
    if response_status != 200:
        raise VaultLiveFailure(f"vault-unseal-api:{response_status}:{payload.decode(errors='replace')}")
    status = json.loads(payload)
    if status.get("sealed"):
        raise VaultLiveFailure("vault-remained-sealed")
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", "pod/root-vault-0", "--timeout=180s")
    return status


@contextlib.contextmanager
def port_forward() -> Iterator[None]:
    process = subprocess.Popen(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", NAMESPACE, "port-forward", "pod/root-vault-0", f"{LOCAL_PORT}:8200"),
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", LOCAL_PORT), timeout=0.25):
                    break
            except OSError:
                if process.poll() is not None:
                    output = process.stdout.read().decode(errors="replace") if process.stdout else ""
                    raise VaultLiveFailure(f"vault-port-forward:{output}")
                time.sleep(0.1)
        else:
            raise VaultLiveFailure("vault-port-forward-timeout")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def api_request(method: str, path: str, token: str | None = None, body: dict[str, Any] | None = None) -> tuple[int, bytes]:
    payload = json.dumps(body).encode() if body is not None else b""
    headers = {"Content-Type": "application/json", "Content-Length": str(len(payload))}
    if token:
        headers["X-Vault-Token"] = token
    connection = http.client.HTTPConnection("127.0.0.1", LOCAL_PORT, timeout=30)
    try:
        connection.request(method, "/v1/" + path.lstrip("/"), body=payload, headers=headers)
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


def require_api(method: str, path: str, token: str | None = None, body: dict[str, Any] | None = None, accepted: set[int] | None = None) -> dict[str, Any]:
    expected = accepted or {200, 204}
    status, payload = api_request(method, path, token, body)
    if status not in expected:
        raise VaultLiveFailure(f"vault-api:{method}:{path}:{status}:{payload.decode(errors='replace')}")
    return json.loads(payload) if payload else {}


def configure_vault(root_token: str, canary: dict[str, str]) -> dict[str, Any]:
    require_api("POST", "sys/audit/file", root_token, {"type": "file", "options": {"file_path": "/vault/audit/audit.log", "log_raw": "false"}}, {204, 400})
    require_api("POST", "sys/mounts/secret", root_token, {"type": "kv", "options": {"version": "2"}}, {204, 400})
    require_api("POST", "secret/data/amoebius/canary", root_token, {"data": {"token": canary["value"]}})
    require_api("POST", "sys/mounts/transit", root_token, {"type": "transit"}, {204, 400})
    require_api("POST", "transit/keys/canary-key", root_token, {}, {200, 204, 400})
    encrypted = require_api("POST", "transit/encrypt/canary-key", root_token, {"plaintext": base64.b64encode(b"phase29-transit-cleartext").decode()})
    require_api("POST", "sys/mounts/pki", root_token, {"type": "pki"}, {204, 400})
    ca_status, _ = api_request("GET", "pki/cert/ca", root_token)
    if ca_status != 200:
        require_api("POST", "pki/root/generate/internal", root_token, {"common_name": "amoebius.internal", "ttl": "87600h"})
    require_api("POST", "pki/roles/internal", root_token, {"allowed_domains": "amoebius.internal", "allow_subdomains": True, "max_ttl": "72h"})
    issue = require_api("POST", "pki/issue/internal", root_token, {"common_name": "vault.vault-system.svc.amoebius.internal", "ttl": "1h"})
    return {
        "ciphertext": encrypted["data"]["ciphertext"],
        "rootCertificate": issue["data"]["issuing_ca"],
        "issuingCa": issue["data"]["issuing_ca"],
        "leafCertificate": issue["data"]["certificate"],
    }


def configure_kubernetes_auth(root_token: str) -> None:
    require_api("POST", "sys/auth/kubernetes", root_token, {"type": "kubernetes"}, {204, 400})
    reviewer_jwt = text(kubectl("-n", NAMESPACE, "exec", "root-vault-0", "--", "cat", "/var/run/secrets/kubernetes.io/serviceaccount/token")).strip()
    ca_certificate = text(kubectl("-n", NAMESPACE, "exec", "root-vault-0", "--", "cat", "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"))
    require_api(
        "POST",
        "auth/kubernetes/config",
        root_token,
        {
            "kubernetes_host": "https://kubernetes.default.svc:443",
            "token_reviewer_jwt": reviewer_jwt,
            "kubernetes_ca_cert": ca_certificate,
            "disable_iss_validation": True,
        },
    )
    policy = 'path "secret/data/amoebius/canary" { capabilities = ["read"] }\npath "transit/decrypt/canary-key" { capabilities = ["update"] }\n'
    require_api("PUT", "sys/policies/acl/amoebius-canary", root_token, {"policy": policy})
    restore_client_role(root_token)


def restore_client_role(root_token: str) -> None:
    require_api(
        "POST",
        "auth/kubernetes/role/amoebius-canary",
        root_token,
        {
            "bound_service_account_names": ["vault-reader"],
            "bound_service_account_namespaces": [CONSUMER_NAMESPACE],
            "policies": ["amoebius-canary"],
            "token_ttl": "10m",
        },
    )


def deploy_consumer() -> dict[str, Any]:
    for resource in (
        {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": CONSUMER_NAMESPACE}},
        {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "vault-reader", "namespace": CONSUMER_NAMESPACE}},
        {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {"name": "vault-reader", "namespace": CONSUMER_NAMESPACE},
            "spec": {
                "serviceAccountName": "vault-reader",
                "restartPolicy": "Never",
                "containers": [
                    {
                        "name": "consumer",
                        "image": PRIVATE_IMAGE,
                        "imagePullPolicy": "Never",
                        "command": ["/bin/sh", "-c", "sleep 3600"],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "32Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "128Mi", "ephemeral-storage": "16Mi"},
                        },
                        "volumeMounts": [{"name": "amoebius-live", "mountPath": "/usr/local/bin/amoebius-live", "readOnly": True}],
                    }
                ],
                "volumes": [
                    {
                        "name": "amoebius-live",
                        "hostPath": {"path": "/amoebius-test/bin/amoebius", "type": "File"},
                    }
                ],
            },
        },
    ):
        apply(resource)
    kubectl("-n", CONSUMER_NAMESPACE, "wait", "--for=condition=Ready", "pod/vault-reader", "--timeout=180s")
    pod = json.loads(text(kubectl("-n", CONSUMER_NAMESPACE, "get", "pod", "vault-reader", "-o", "json")))
    return {
        "containers": [container["name"] for container in pod["spec"]["containers"]],
        "plainSecretVolumes": [volume["name"] for volume in pod["spec"].get("volumes", []) if "secret" in volume],
        "imageId": pod["status"]["containerStatuses"][0]["imageID"],
    }


def client_read(canary: dict[str, str], *, expect_success: bool) -> subprocess.CompletedProcess[bytes]:
    result = kubectl(
        "-n",
        CONSUMER_NAMESPACE,
        "exec",
        "vault-reader",
        "--",
        "/usr/local/bin/amoebius-live",
        "vault-read",
        "root-vault.vault-system.svc",
        "8200",
        "amoebius-canary",
        CONSUMER_NAMESPACE,
        "vault-reader",
        canary["mount"],
        canary["path"],
        canary["field"],
        "/var/run/secrets/kubernetes.io/serviceaccount/token",
        check=False,
    )
    if expect_success and (result.returncode != 0 or text(result).strip() != canary["value"]):
        raise VaultLiveFailure(f"haskell-client-read:{result.returncode}:{text(result)}")
    if not expect_success and (result.returncode == 0 or "tag=policy-missing" not in text(result)):
        raise VaultLiveFailure(f"haskell-client-denial:{result.returncode}:{text(result)}")
    return result


def client_transit(ciphertext: str) -> str:
    result = kubectl(
        "-n",
        CONSUMER_NAMESPACE,
        "exec",
        "vault-reader",
        "--",
        "/usr/local/bin/amoebius-live",
        "vault-transit-decrypt",
        "root-vault.vault-system.svc",
        "8200",
        "amoebius-canary",
        CONSUMER_NAMESPACE,
        "vault-reader",
        "canary-key",
        ciphertext,
        "/var/run/secrets/kubernetes.io/serviceaccount/token",
    )
    value = text(result).strip()
    if value != "phase29-transit-cleartext":
        raise VaultLiveFailure(f"transit-cleartext:{value}")
    return value


def verify_certificates(root_certificate: str, issuing_ca: str, leaf_certificate: str) -> dict[str, str]:
    temporary = TEST_ROOT / "runtime/cert-verify"
    temporary.mkdir(parents=True, exist_ok=True)
    root_path = temporary / "root.pem"
    issuing_path = temporary / "issuing.pem"
    leaf_path = temporary / "leaf.pem"
    root_path.write_text(root_certificate, encoding="utf-8")
    issuing_path.write_text(issuing_ca, encoding="utf-8")
    leaf_path.write_text(leaf_certificate, encoding="utf-8")
    subject = text(run(("/usr/bin/openssl", "x509", "-in", str(root_path), "-noout", "-subject"))).strip()
    issuer = text(run(("/usr/bin/openssl", "x509", "-in", str(root_path), "-noout", "-issuer"))).strip()
    verify = text(run(("/usr/bin/openssl", "verify", "-CAfile", str(root_path), str(leaf_path)))).strip()
    if subject.replace("subject=", "") != issuer.replace("issuer=", "") or not verify.endswith(": OK"):
        raise VaultLiveFailure(f"pki-chain:{subject}:{issuer}:{verify}")
    return {"rootSelfSigned": True, "leafChainsToRoot": True, "rootSha256": sha256_file(root_path)}


def raft_and_audit_bounds(root_token: str, vault_volume: dict[str, Any], audit_volume: dict[str, Any]) -> dict[str, Any]:
    for index in range(64):
        require_api("POST", f"secret/data/amoebius/history-{index}", root_token, {"data": {"value": "x" * 1024}})
    snapshot_status, snapshot = api_request("GET", "sys/storage/raft/snapshot", root_token)
    if snapshot_status != 200 or not snapshot:
        raise VaultLiveFailure(f"raft-snapshot:{snapshot_status}:{len(snapshot)}")
    vault_used = int(text(sudo("/usr/bin/du", "-sb", vault_volume["mount"])).split()[0])
    audit_path = Path(audit_volume["mount"]) / "audit.log"
    if not audit_path.is_file():
        raise VaultLiveFailure("audit-file-absent")
    require_api("DELETE", "sys/audit/file", root_token)
    rotated = audit_path.with_name("audit.log.1")
    if rotated.exists():
        sudo("/usr/bin/rm", "-f", "--", str(rotated))
    sudo("/usr/bin/mv", str(audit_path), str(rotated))
    require_api("POST", "sys/audit/file", root_token, {"type": "file", "options": {"file_path": "/vault/audit/audit.log", "log_raw": "false"}})
    require_api("GET", "secret/data/amoebius/canary", root_token)
    audit_files = sorted(Path(audit_volume["mount"]).glob("audit.log*"))
    audit_total = sum(path.stat().st_size for path in audit_files)
    if vault_used > vault_volume["usableBytes"] or audit_total > audit_volume["usableBytes"] or len(audit_files) > 4:
        raise VaultLiveFailure(f"storage-highwater:{vault_used}:{audit_total}:{len(audit_files)}")
    return {
        "snapshotBytes": len(snapshot),
        "raftHighWaterBytes": vault_used,
        "auditHighWaterBytes": audit_total,
        "auditFiles": [path.name for path in audit_files],
        "withinProvision": True,
    }


def execute() -> dict[str, Any]:
    if not IMAGE_ARCHIVE.is_file():
        raise VaultLiveFailure("phase25-image-archive-absent")
    canary = json.loads(CANARY_FIXTURE.read_text(encoding="utf-8"))
    if len(canary["value"].encode()) != 32:
        raise VaultLiveFailure("canary-not-32-bytes")
    vault_volume = prepare_volume("vault", VAULT_IMAGE_BYTES)
    audit_volume = prepare_volume("vault-audit", AUDIT_IMAGE_BYTES)
    binary = install_current_binary()
    binary_path = Path(binary["path"])
    # The elevated live harness simulates the operator at stdin with an in-memory,
    # one-use value.  No credential arrives through argv, environment, or a file.
    password = secrets.token_urlsafe(32).encode()
    delete_cluster()
    source1 = create_cluster()
    identity1 = cluster_identity()
    prebind1 = apply_vault()
    before_init, unseal_key, root_token = initialize_vault(password, binary_path)
    opened = open_unlock(password, binary_path)
    envelope_sha256 = sha256_file(UNLOCK_ENVELOPE)
    if opened != {"unseal_key": unseal_key, "root_token": root_token}:
        raise VaultLiveFailure("unlock-envelope-roundtrip")
    wrong = run((str(binary_path), "vault-open-unlock"), input_bytes=b"wrong-password\n" + UNLOCK_ENVELOPE.read_bytes(), check=False, timeout=120)
    if wrong.returncode == 0:
        raise VaultLiveFailure("wrong-password-opened-envelope")
    unseal1 = unseal(unseal_key)

    with port_forward():
        configured = configure_vault(root_token, canary)
        configure_kubernetes_auth(root_token)
        consumer1 = deploy_consumer()
        client_read(canary, expect_success=True)
        transit_value = client_transit(configured["ciphertext"])
        pki1 = verify_certificates(configured["rootCertificate"], configured["issuingCa"], configured["leafCertificate"])
        require_api("DELETE", "auth/kubernetes/role/amoebius-canary", root_token)
        denied = client_read(canary, expect_success=False)
        restore_client_role(root_token)
        bounds1 = raft_and_audit_bounds(root_token, vault_volume, audit_volume)
        health1 = require_api("GET", "sys/health", accepted={200})
        require_api("PUT", "sys/seal", root_token, {})
        sealed_issue_status, sealed_issue_body = api_request("POST", "pki/issue/internal", root_token, {"common_name": "denied.amoebius.internal"})
    if sealed_issue_status == 200:
        raise VaultLiveFailure("pki-issued-while-sealed")
    unseal(unseal_key)

    old_vault_hash = sha256_file(Path(vault_volume["image"]))
    delete_cluster()
    clusters = text(run((KIND, "get", "clusters"))).splitlines()
    cluster_absent = CLUSTER not in clusters
    node_absent = run(("/usr/bin/docker", "inspect", NODE), check=False).returncode != 0
    backing_present = mountpoint(Path(vault_volume["mount"])) and Path(vault_volume["image"]).is_file()
    if not (cluster_absent and node_absent and backing_present):
        raise VaultLiveFailure(f"delete-boundary:{cluster_absent}:{node_absent}:{backing_present}")

    source2 = create_cluster()
    identity2 = cluster_identity()
    if identity1["serverCaSha256"] == identity2["serverCaSha256"] or identity1["clusterUid"] == identity2["clusterUid"]:
        raise VaultLiveFailure("cluster-recreate-not-fresh")
    prebind2 = apply_vault()
    before_unseal2 = vault_status()
    if not before_unseal2.get("initialized") or not before_unseal2.get("sealed"):
        raise VaultLiveFailure(f"recreate-did-not-find-initialized-sealed-vault:{before_unseal2}")
    opened2 = open_unlock(password, binary_path)
    unseal2 = unseal(opened2["unseal_key"])
    with port_forward():
        health2 = require_api("GET", "sys/health", accepted={200})
        if health1.get("cluster_id") != health2.get("cluster_id"):
            raise VaultLiveFailure("vault-cluster-identity-changed")
        configure_kubernetes_auth(opened2["root_token"])
        consumer2 = deploy_consumer()
        client_read(canary, expect_success=True)
        issue2 = require_api("POST", "pki/issue/internal", opened2["root_token"], {"common_name": "vault-recreated.vault-system.svc.amoebius.internal", "ttl": "1h"})
        pki2 = verify_certificates(issue2["data"]["issuing_ca"], issue2["data"]["issuing_ca"], issue2["data"]["certificate"])

    pod_spec = json.loads(text(kubectl("-n", NAMESPACE, "get", "statefulset", "root-vault", "-o", "json")))
    storage_classes = json.loads(text(kubectl("get", "storageclass", "-o", "json")))["items"]
    vault_hash_after = sha256_file(Path(vault_volume["image"]))
    audit_text = "".join(text(sudo("/usr/bin/cat", str(path))) for path in Path(audit_volume["mount"]).glob("audit.log*"))
    audit_login = "auth/kubernetes/login" in audit_text
    audit_read = "secret/data/amoebius/canary" in audit_text
    if not (audit_login and audit_read):
        raise VaultLiveFailure("vault-audit-provenance-operations-absent")
    password_scan = password.decode() not in json.dumps(pod_spec) and password.decode() not in audit_text
    if not password_scan:
        raise VaultLiveFailure("password-persisted-in-observed-surface")

    return {
        "schema": "amoebius.vault-pki.live.v2",
        "register": 3,
        "substrate": "linux-cpu",
        "initOnce": {
            "run1InitializedBefore": before_init.get("initialized"),
            "run2InitializedBeforeUnseal": before_unseal2.get("initialized"),
            "run2SealedBeforeUnseal": before_unseal2.get("sealed"),
            "initCount": 1,
            "vaultClusterIdStable": health1.get("cluster_id") == health2.get("cluster_id"),
            "run1Unsealed": not unseal1.get("sealed"),
            "run2Unsealed": not unseal2.get("sealed"),
        },
        "unlockEnvelope": {
            "path": str(UNLOCK_ENVELOPE),
            "sha256": envelope_sha256,
            "format": "Argon2id-v1.3+ChaCha20-Poly1305-IETF",
            "wrongPasswordRejected": True,
            "mode": "0600",
            "passwordPersisted": False,
            "observedSurfaceScanPassed": password_scan,
            "stdinOnly": True,
            "environmentSources": 0,
            "argumentSources": 0,
        },
        "storage": {
            "durable": vault_volume,
            "audit": audit_volume,
            "declared": {"raftProvisionedRawBytes": VAULT_IMAGE_BYTES, "auditProvisionedRawBytes": AUDIT_IMAGE_BYTES},
            "run1HighWater": bounds1,
            "backingHashChangedOnlyByVault": old_vault_hash != vault_hash_after,
        },
        "clusterRebuild": {
            "run1": identity1,
            "run2": identity2,
            "serverCaChanged": identity1["serverCaSha256"] != identity2["serverCaSha256"],
            "clusterUidChanged": identity1["clusterUid"] != identity2["clusterUid"],
            "kindClusterAbsent": cluster_absent,
            "nodeContainerAbsent": node_absent,
            "backingPresentWhileAbsent": backing_present,
            "prebindRun1": prebind1,
            "prebindRun2": prebind2,
        },
        "pki": {
            "run1": pki1,
            "run2": pki2,
            "sameRootAfterRecreate": pki1["rootSha256"] == pki2["rootSha256"],
            "sealedIssuanceStatus": sealed_issue_status,
            "sealedIssuanceBodySha256": hashlib.sha256(sealed_issue_body).hexdigest(),
        },
        "client": {
            "compiledBinary": binary,
            "run1": consumer1,
            "run2": consumer2,
            "secretRefByteIdentical": True,
            "transitByteIdentical": transit_value == "phase29-transit-cleartext",
            "roleDeletionDenied": denied.returncode != 0,
            "auditKubernetesLoginObserved": audit_login,
            "auditSecretReadObserved": audit_read,
            "agentSidecars": 0,
            "plainSecretMounts": 0,
        },
        "manifestProjection": {
            "vaultContainers": len(pod_spec["spec"]["template"]["spec"]["containers"]),
            "resources": pod_spec["spec"]["template"]["spec"]["containers"][0]["resources"],
            "storageClassCount": len(storage_classes),
            "storageClass": storage_classes[0]["metadata"]["name"] if len(storage_classes) == 1 else None,
        },
        "artifactSource": {"run1": source1, "run2": source2, "phase25IndexDigest": IMAGE_DIGEST},
        "deferred": {
            "parentChildUnseal": "UNVERIFIED",
            "crossClusterIntermediateCa": "UNVERIFIED",
            "parentSecretInjection": "UNVERIFIED",
        },
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="write the run observation beneath .build")
    parser.add_argument("--artifact", type=Path, required=True, help="verified Phase-25 OCI handoff")
    parser.add_argument("--image-digest", required=True, help="verified Phase-25 image index digest")
    arguments = parser.parse_args(argv)
    globals()["IMAGE_ARCHIVE"] = arguments.artifact
    globals()["IMAGE_DIGEST"] = arguments.image_digest
    globals()["PRIVATE_IMAGE"] = f"registry.amoebius.invalid:5000/amoebius/base@{arguments.image_digest}"
    resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
    globals()["CABAL"] = os.environ.get("AMOEBIUS_CABAL", resolved["cabal"]["path"])
    globals()["KIND"] = os.environ.get("AMOEBIUS_KIND", resolved["kind"]["path"])
    globals()["KUBECTL"] = os.environ.get("AMOEBIUS_KUBECTL", resolved["kubectl"]["path"])
    globals()["KIND_CONFIG"] = materialize_kind_config(arguments.output.parent)
    try:
        evidence = execute()
        containment.require_state_path(arguments.output, "build", actor="test")
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("vault-pki-live: PASS (init once, retained unseal, PKI chain, Kubernetes-auth Haskell client)")
        return 0
    except (VaultLiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired, yaml.YAMLError) as problem:
        print(f"vault-pki-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
