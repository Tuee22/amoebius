#!/usr/bin/env python3
"""Exercise the platform backbone in one project-contained private cluster fixture."""

from __future__ import annotations

import argparse
import contextlib
import copy
import datetime
import base64
import hashlib
import hmac
import http.client
import ipaddress
import json
import os
import re
import secrets
import socket
import struct
import subprocess
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any, Iterator, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import containment  # noqa: E402
import toolchain  # noqa: E402
import vault_pki_live as vault  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
KIND = ""
KUBECTL = ""
CABAL = ""
KUBECONFIG = Path(os.environ.get("AMOEBIUS_KUBECONFIG", ROOT / ".build/tmp/platform-backbone/unconfigured-kubeconfig"))
NODE = "amoebius-bootstrap-coordinator-control-plane"
IMAGE_ARCHIVE = Path()
IMAGE_DIGEST = ""
PRIVATE_IMAGE = ""
TEST_ROOT = Path(os.environ.get("AMOEBIUS_TEST_ROOT", ROOT / ".build/tmp/platform-backbone/unconfigured-test-root"))
RETAINED_ROOT = TEST_ROOT / "retained"
EVIDENCE = ROOT / ".build/tmp/platform-backbone/unconfigured-evidence.json"
KIND_CONFIG_TEMPLATE = ROOT / "test/fixture/platform_backbone/kind.yaml"
KIND_CONFIG = Path()
PLATFORM_NAMESPACE = "platform-system"
METALLB_NAMESPACE = "metallb-system"
PULSAR_NAMESPACE = "pulsar-system"
MINIO_ACCESS = ""
MINIO_SECRET = ""
MEMBERLIST_SECRET = ""
LOAD_BALANCER_ADDRESS = ""
LOAD_BALANCER_POOL = ""
MINIO_PORT = 19000
REGISTRY_PORT = 15030
MIB = 1024 * 1024
HOT_TIER_CAP = int((ROOT / "test/fixture/platform_backbone/hot-tier-cap.golden").read_text(encoding="utf-8").strip())
DEV_OFFLOADERS = False
PUBLIC_REGISTRY_TOKENS = ("docker.io/", "quay.io/", "ghcr.io/", "registry.k8s.io/")
APPLIED_OBJECTS: dict[tuple[str, str, str], dict[str, Any]] = {}


class BackboneLiveFailure(RuntimeError):
    pass


def run(
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 600,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if check and result.returncode:
        raise BackboneLiveFailure(f"{arguments}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def cabal_command(*arguments: str) -> tuple[str, ...]:
    command = (
        CABAL,
        f"--builddir={ROOT / '.build/dist-newstyle/platform-backbone'}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
    )
    compiler = os.environ.get("AMOEBIUS_GHC")
    if compiler:
        command = (*command, f"--with-compiler={compiler}")
    return (*command, "--jobs=1", *arguments)


def materialize_kind_config(output_root: Path) -> Path:
    template = KIND_CONFIG_TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "__RETAINED_MOUNTS__": str(RETAINED_ROOT / "mounts"),
        "__AMOEBIUS_BINARY__": str(TEST_ROOT / "runtime/amoebius"),
    }
    for marker, replacement in replacements.items():
        if template.count(marker) != 1:
            raise BackboneLiveFailure(f"kind-config-placeholder:{marker}:{template.count(marker)}")
        template = template.replace(marker, replacement)
    if "__" in template:
        raise BackboneLiveFailure("kind-config-unresolved-placeholder")
    target = output_root / "runtime/kind.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(template, encoding="utf-8")
    return target


def bootstrap_vault_predecessor() -> dict[str, Any]:
    """Materialize Phase 29's real readiness floor inside this run's private fixture."""
    vault.KIND = KIND
    vault.KUBECTL = KUBECTL
    vault.CABAL = CABAL
    vault.KUBECONFIG = KUBECONFIG
    vault.TEST_ROOT = TEST_ROOT
    vault.RETAINED_ROOT = RETAINED_ROOT
    vault.UNLOCK_ENVELOPE = RETAINED_ROOT / "vault-unlock.age"
    vault.KIND_CONFIG = KIND_CONFIG
    vault.IMAGE_ARCHIVE = IMAGE_ARCHIVE
    vault.IMAGE_DIGEST = IMAGE_DIGEST
    vault.PRIVATE_IMAGE = PRIVATE_IMAGE
    observation = vault.execute()
    target = EVIDENCE.parent / "vault-readiness-floor.json"
    target.write_text(json.dumps(observation, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {
        "schema": observation.get("schema"),
        "vaultClusterId": observation.get("initOnce", {}).get("vaultClusterIdStable"),
        "pkiRootStable": observation.get("pki", {}).get("sameRootAfterRecreate"),
        "observation": str(target),
    }


def sudo(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return run(("/usr/bin/sudo", "-n", *arguments), check=check)


def kubectl(
    *arguments: str,
    input_value: str | None = None,
    check: bool = True,
    timeout: int = 300,
) -> subprocess.CompletedProcess[bytes]:
    return run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments),
        input_bytes=input_value.encode() if input_value is not None else None,
        check=check,
        timeout=timeout,
    )


def object_key(value: dict[str, Any]) -> tuple[str, str, str]:
    metadata = value["metadata"]
    return value["kind"], metadata.get("namespace", ""), metadata["name"]


def merge_object(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(left)
    for key, value in right.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = merge_object(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def apply(value: dict[str, Any]) -> None:
    desired = copy.deepcopy(value)
    labels = desired.setdefault("metadata", {}).setdefault("labels", {})
    labels["app.kubernetes.io/managed-by"] = "amoebius"
    if desired.get("kind") == "Secret" and "stringData" in desired:
        desired["data"] = {
            key: base64.b64encode(raw.encode()).decode()
            for key, raw in desired.pop("stringData").items()
        }
    kubectl(
        "apply", "--server-side", "--field-manager=amoebius", "--force-conflicts",
        "-f", "-", input_value=json.dumps(desired),
    )
    key = object_key(desired)
    APPLIED_OBJECTS[key] = merge_object(APPLIED_OBJECTS.get(key, {}), desired)


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
        raise BackboneLiveFailure(f"raw-image-size:{name}:{image.stat().st_size}:{raw_bytes}")
    if not mountpoint(target):
        sudo("/usr/bin/mount", "-o", "loop", str(image), str(target))
    sudo("/usr/bin/chmod", "0777", str(target))
    available = int(text(run(("/usr/bin/df", "-B1", "--output=avail", str(target)))).splitlines()[-1])
    filesystem = text(run(("/usr/bin/findmnt", "-n", "-o", "FSTYPE", "--target", str(target)))).strip()
    if filesystem != "ext4":
        raise BackboneLiveFailure(f"volume-filesystem:{name}:{filesystem}")
    return {"name": name, "image": str(image), "mount": str(target), "rawBytes": raw_bytes, "usableBytes": available, "filesystemType": filesystem}


def ensure_cluster_image() -> None:
    if run(("/usr/bin/docker", "inspect", NODE), check=False).returncode:
        raise BackboneLiveFailure("phase24-kind-node-absent")
    images = text(run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "list", "-q"))).splitlines()
    if PRIVATE_IMAGE not in images:
        imported = next((value for value in images if value.startswith("import-") and value.endswith("@" + IMAGE_DIGEST)), None)
        if imported is None:
            raise BackboneLiveFailure("phase25-image-absent")
        run(("/usr/bin/docker", "exec", NODE, "ctr", "-n", "k8s.io", "images", "tag", imported, PRIVATE_IMAGE))


def derive_load_balancer_pool() -> tuple[str, str]:
    """Select a host-routable pool from this private daemon's actual Kind network."""
    inspected = json.loads(text(run(("/usr/bin/docker", "network", "inspect", "kind"))))
    try:
        candidates = [
            ipaddress.ip_network(row["Subnet"])
            for row in inspected[0]["IPAM"]["Config"]
            if row.get("Subnet")
        ]
        network = next(candidate for candidate in candidates if candidate.version == 4)
    except (IndexError, KeyError, StopIteration, TypeError, ValueError) as problem:
        raise BackboneLiveFailure("kind-network-subnet-unreadable") from problem
    if network.num_addresses < 64:
        raise BackboneLiveFailure(f"kind-network-subnet-unsupported:{network}")
    first = network.broadcast_address - 20
    last = network.broadcast_address - 10
    if first not in network or last not in network:
        raise BackboneLiveFailure(f"kind-network-pool-outside-subnet:{network}:{first}:{last}")
    return str(first), f"{first}-{last}"


def reset_generated_phase30_state() -> None:
    for namespace_name in (PULSAR_NAMESPACE, PLATFORM_NAMESPACE, METALLB_NAMESPACE):
        kubectl("delete", "namespace", namespace_name, "--ignore-not-found=true", "--wait=true", "--timeout=300s", timeout=320)
    persistent_volumes = [f"platform-system.minio-data{index}.pv-0" for index in range(4)]
    persistent_volumes += [f"pulsar-system.zookeeper-data.pv-{index}" for index in range(3)]
    persistent_volumes += [f"pulsar-system.bookkeeper-data.pv-{index}" for index in range(3)]
    kubectl("delete", "persistentvolume", *persistent_volumes, "--ignore-not-found=true", "--wait=true", "--timeout=120s", timeout=140)
    targets = [RETAINED_ROOT / f"mounts/phase30-minio-{index}" for index in range(4)]
    targets += [RETAINED_ROOT / f"mounts/phase30-zookeeper-{index}" for index in range(3)]
    targets += [RETAINED_ROOT / f"mounts/phase30-bookkeeper-{index}" for index in range(3)]
    targets += [RETAINED_ROOT / "mounts/phase30-registry-source"]
    expected_parent = (RETAINED_ROOT / "mounts").resolve()
    for target in targets:
        resolved = target.resolve()
        if resolved.parent != expected_parent or not resolved.name.startswith("phase30-"):
            raise BackboneLiveFailure(f"phase30-reset-target-refused:{resolved}")
        resolved.mkdir(parents=True, exist_ok=True)
        sudo("/usr/bin/find", str(resolved), "-mindepth", "1", "-delete")


def namespace(name: str) -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": name}}


def resource_envelope(
    memory_request: str,
    memory_limit: str,
    ephemeral_request: str = "16Mi",
    ephemeral_limit: str = "64Mi",
) -> dict[str, Any]:
    return {
        "requests": {"cpu": "50m", "memory": memory_request, "ephemeral-storage": ephemeral_request},
        "limits": {"cpu": "500m", "memory": memory_limit, "ephemeral-storage": ephemeral_limit},
    }


def minimal_crd(plural: str, singular: str, kind: str, version: str | tuple[str, ...] = "v1beta1", *, namespaced: bool = True) -> dict[str, Any]:
    api_versions = (version,) if isinstance(version, str) else version
    return {
        "apiVersion": "apiextensions.k8s.io/v1",
        "kind": "CustomResourceDefinition",
        "metadata": {"name": f"{plural}.metallb.io"},
        "spec": {
            "group": "metallb.io",
            "scope": "Namespaced" if namespaced else "Cluster",
            "names": {"plural": plural, "singular": singular, "kind": kind},
            "versions": [
                {
                    "name": api_version,
                    "served": True,
                    "storage": offset == len(api_versions) - 1,
                    "schema": {"openAPIV3Schema": {"type": "object", "x-kubernetes-preserve-unknown-fields": True}},
                    "subresources": {"status": {}},
                }
                for offset, api_version in enumerate(api_versions)
            ],
        },
    }


def apply_metallb() -> dict[str, Any]:
    apply(namespace(METALLB_NAMESPACE))
    crds = [
        ("ipaddresspools", "ipaddresspool", "IPAddressPool", "v1beta1"),
        ("l2advertisements", "l2advertisement", "L2Advertisement", "v1beta1"),
        ("bgpadvertisements", "bgpadvertisement", "BGPAdvertisement", "v1beta1"),
        ("bfdprofiles", "bfdprofile", "BFDProfile", "v1beta1"),
        ("communities", "community", "Community", "v1beta1"),
        ("bgppeers", "bgppeer", "BGPPeer", ("v1beta1", "v1beta2")),
        ("servicel2statuses", "servicel2status", "ServiceL2Status", "v1beta1"),
        ("servicebgpstatuses", "servicebgpstatus", "ServiceBGPStatus", "v1beta1"),
    ]
    for plural, singular, kind, version in crds:
        apply(minimal_crd(plural, singular, kind, version))
    apply({"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "controller", "namespace": METALLB_NAMESPACE}})
    apply({"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "speaker", "namespace": METALLB_NAMESPACE}})
    role = {
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole", "metadata": {"name": "phase30-metallb"},
        "rules": [{"apiGroups": ["*"], "resources": ["*"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]}],
    }
    apply(role)
    for account in ("controller", "speaker"):
        apply({
            "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding", "metadata": {"name": f"phase30-metallb-{account}"},
            "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "phase30-metallb"},
            "subjects": [{"kind": "ServiceAccount", "name": account, "namespace": METALLB_NAMESPACE}],
        })
    apply({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "memberlist", "namespace": METALLB_NAMESPACE}, "type": "Opaque", "stringData": {"secretkey": MEMBERLIST_SECRET}})
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "controller", "namespace": METALLB_NAMESPACE},
        "spec": {"replicas": 1, "selector": {"matchLabels": {"app": "metallb-controller"}}, "template": {"metadata": {"labels": {"app": "metallb-controller"}}, "spec": {"serviceAccountName": "controller", "containers": [{
            "name": "controller", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/metallb-controller"],
            "args": ["-webhook-mode=disabled", "-namespace=metallb-system", "-deployment=controller", "-ml-secret-name=memberlist"],
            "resources": resource_envelope("32Mi", "128Mi"), "ports": [{"name": "metrics", "containerPort": 7472}],
        }]}}},
    })
    apply({
        "apiVersion": "apps/v1", "kind": "DaemonSet", "metadata": {"name": "speaker", "namespace": METALLB_NAMESPACE},
        "spec": {"selector": {"matchLabels": {"app": "metallb-speaker"}}, "template": {"metadata": {"labels": {"app": "metallb-speaker"}}, "spec": {"serviceAccountName": "speaker", "hostNetwork": True, "containers": [{
            "name": "speaker", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/metallb-speaker"],
            "args": ["-namespace=metallb-system", "-ml-secret-key-path=/etc/ml", "-ml-labels=app=metallb-speaker", "-node-name=$(NODE_NAME)", "-pod-name=$(POD_NAME)"],
            "env": [
                {"name": "NODE_NAME", "valueFrom": {"fieldRef": {"fieldPath": "spec.nodeName"}}},
                {"name": "POD_NAME", "valueFrom": {"fieldRef": {"fieldPath": "metadata.name"}}},
            ],
            "securityContext": {"runAsUser": 0, "runAsGroup": 0, "capabilities": {"add": ["NET_RAW"]}}, "resources": resource_envelope("32Mi", "128Mi"),
            "volumeMounts": [{"name": "memberlist", "mountPath": "/etc/ml", "readOnly": True}],
        }], "volumes": [{"name": "memberlist", "secret": {"secretName": "memberlist"}}]}}},
    })
    apply({"apiVersion": "metallb.io/v1beta1", "kind": "IPAddressPool", "metadata": {"name": "phase30", "namespace": METALLB_NAMESPACE}, "spec": {"addresses": [LOAD_BALANCER_POOL]}})
    apply({"apiVersion": "metallb.io/v1beta1", "kind": "L2Advertisement", "metadata": {"name": "phase30", "namespace": METALLB_NAMESPACE}, "spec": {"ipAddressPools": ["phase30"]}})
    kubectl("-n", METALLB_NAMESPACE, "rollout", "status", "deployment/controller", "--timeout=180s")
    kubectl("-n", METALLB_NAMESPACE, "rollout", "status", "daemonset/speaker", "--timeout=180s")
    return {"controller": "Ready", "speaker": "Ready", "crdCount": len(crds)}


def wait_for_load_balancer() -> dict[str, Any]:
    deadline = time.monotonic() + 180
    stable_observations = 0
    last_state = ""
    while time.monotonic() < deadline:
        service = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "service", "minio", "-o", "json")))
        controller = json.loads(text(kubectl("-n", METALLB_NAMESPACE, "get", "deployment", "controller", "-o", "json")))
        speaker = json.loads(text(kubectl("-n", METALLB_NAMESPACE, "get", "daemonset", "speaker", "-o", "json")))
        ingress = service.get("status", {}).get("loadBalancer", {}).get("ingress", [])
        controller_ready = controller.get("status", {}).get("readyReplicas", 0) == 1
        speaker_ready = speaker.get("status", {}).get("numberReady", 0) == speaker.get("status", {}).get("desiredNumberScheduled", -1) == 1
        ingress_reachable = False
        if ingress:
            connection = http.client.HTTPConnection(ingress[0]["ip"], 9000, timeout=1)
            try:
                connection.request("GET", "/minio/health/ready")
                response = connection.getresponse()
                response.read()
                ingress_reachable = response.status == 200
            except OSError:
                pass
            finally:
                connection.close()
        last_state = f"ingress={ingress},controller={controller_ready},speaker={speaker_ready},reachable={ingress_reachable}"
        stable_observations = stable_observations + 1 if ingress and controller_ready and speaker_ready and ingress_reachable else 0
        if stable_observations >= 5:
            return {"type": service["spec"]["type"], "ingress": ingress, "externallyReachable": True, "stableReadyObservations": stable_observations}
        time.sleep(1)
    raise BackboneLiveFailure(f"load-balancer-not-ready:{last_state}")


def storage_class() -> dict[str, Any]:
    return {
        "apiVersion": "storage.k8s.io/v1", "kind": "StorageClass", "metadata": {"name": "amoebius-retained"},
        "provisioner": "kubernetes.io/no-provisioner", "reclaimPolicy": "Retain", "volumeBindingMode": "WaitForFirstConsumer",
    }


def persistent_volume(index: int) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolume", "metadata": {"name": f"platform-system.minio-data{index}.pv-0", "labels": {"amoebius.io/owner": "phase30-minio"}},
        "spec": {
            "capacity": {"storage": "128Mi"}, "accessModes": ["ReadWriteOnce"], "storageClassName": "amoebius-retained",
            "persistentVolumeReclaimPolicy": "Retain", "volumeMode": "Filesystem",
            "claimRef": {"namespace": PLATFORM_NAMESPACE, "name": f"data{index}-minio-0"},
            "hostPath": {"path": f"/amoebius-retained/phase30-minio-{index}", "type": "Directory"},
            "nodeAffinity": {"required": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "kubernetes.io/hostname", "operator": "In", "values": [NODE]}]}]}},
        },
    }


def apply_minio(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    apply(namespace(PLATFORM_NAMESPACE))
    kubectl("delete", "storageclass", "standard", "--ignore-not-found=true")
    apply(storage_class())
    for index in range(4):
        apply(persistent_volume(index))
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "minio", "namespace": PLATFORM_NAMESPACE},
        "spec": {"type": "LoadBalancer", "selector": {"app": "minio"}, "ports": [{"name": "s3", "port": 9000, "targetPort": 9000}]},
    })
    templates = [
        {"metadata": {"name": f"data{index}"}, "spec": {"accessModes": ["ReadWriteOnce"], "storageClassName": "amoebius-retained", "resources": {"requests": {"storage": "128Mi"}}}}
        for index in range(4)
    ]
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "minio", "namespace": PLATFORM_NAMESPACE},
        "spec": {
            "serviceName": "minio", "replicas": 1, "selector": {"matchLabels": {"app": "minio"}},
            "template": {
                "metadata": {"labels": {"app": "minio"}},
                "spec": {
                    "securityContext": {"runAsUser": 0, "runAsGroup": 0},
                    "containers": [{
                        "name": "minio", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/minio"],
                        "args": ["server", "/data0", "/data1", "/data2", "/data3", "--address", ":9000", "--console-address", ":9001"],
                        "env": [{"name": "MINIO_ROOT_USER", "value": MINIO_ACCESS}, {"name": "MINIO_ROOT_PASSWORD", "value": MINIO_SECRET}],
                        "ports": [{"name": "s3", "containerPort": 9000}], "resources": resource_envelope("128Mi", "512Mi"),
                        "readinessProbe": {"httpGet": {"path": "/minio/health/ready", "port": 9000}, "periodSeconds": 2, "failureThreshold": 90},
                        "volumeMounts": [{"name": f"data{index}", "mountPath": f"/data{index}"} for index in range(4)],
                    }],
                },
            },
            "volumeClaimTemplates": templates,
        },
    })
    kubectl("-n", PLATFORM_NAMESPACE, "rollout", "status", "statefulset/minio", "--timeout=240s")
    stateful = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "statefulset", "minio", "-o", "json")))
    claims = json.loads(text(kubectl("-n", PLATFORM_NAMESPACE, "get", "pvc", "-o", "json")))
    return {
        "topology": "distributed-erasure-four-drive",
        "replicas": stateful["spec"]["replicas"],
        "claimTemplates": [item["metadata"]["name"] for item in stateful["spec"]["volumeClaimTemplates"]],
        "boundClaims": sorted(item["metadata"]["name"] for item in claims["items"] if item["metadata"]["name"].startswith("data")),
        "volumes": volumes,
    }


@contextlib.contextmanager
def port_forward(namespace_name: str, resource: str, local_port: int, remote_port: int) -> Iterator[None]:
    process = subprocess.Popen(
        [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", namespace_name, "port-forward", resource, f"{local_port}:{remote_port}"],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            connection = http.client.HTTPConnection("127.0.0.1", local_port, timeout=1)
            try:
                connection.request("GET", "/")
                connection.getresponse().read()
                break
            except OSError:
                time.sleep(0.2)
            finally:
                connection.close()
        else:
            raise BackboneLiveFailure(f"port-forward-not-ready:{namespace_name}:{resource}")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


@contextlib.contextmanager
def tcp_port_forward(namespace_name: str, resource: str, local_port: int, remote_port: int) -> Iterator[None]:
    process = subprocess.Popen(
        [KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", namespace_name, "port-forward", resource, f"{local_port}:{remote_port}"],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", local_port), timeout=1):
                    break
            except OSError:
                time.sleep(0.2)
        else:
            raise BackboneLiveFailure(f"tcp-port-forward-not-ready:{namespace_name}:{resource}")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def s3_request(method: str, bucket: str, key: str = "", body: bytes = b"", query: str = "") -> tuple[int, bytes]:
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    encoded_key = urllib.parse.quote(key, safe="/-_.~")
    path = "/" + urllib.parse.quote(bucket, safe="-_.~") + ("/" + encoded_key if key else "")
    payload_hash = hashlib.sha256(body).hexdigest()
    canonical_query = query
    canonical_headers = f"host:127.0.0.1:{MINIO_PORT}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = "\n".join([method, path, canonical_query, canonical_headers, signed_headers, payload_hash])
    scope = f"{date_stamp}/us-east-1/s3/aws4_request"
    string_to_sign = "\n".join(["AWS4-HMAC-SHA256", amz_date, scope, hashlib.sha256(canonical_request.encode()).hexdigest()])
    date_key = hmac.new(("AWS4" + MINIO_SECRET).encode(), date_stamp.encode(), hashlib.sha256).digest()
    region_key = hmac.new(date_key, b"us-east-1", hashlib.sha256).digest()
    service_key = hmac.new(region_key, b"s3", hashlib.sha256).digest()
    signing_key = hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
    authorization = f"AWS4-HMAC-SHA256 Credential={MINIO_ACCESS}/{scope}, SignedHeaders={signed_headers}, Signature={signature}"
    headers = {"x-amz-date": amz_date, "x-amz-content-sha256": payload_hash, "Authorization": authorization, "Content-Length": str(len(body))}
    target = path + ("?" + query if query else "")
    connection = http.client.HTTPConnection("127.0.0.1", MINIO_PORT, timeout=30)
    try:
        connection.request(method, target, body=body, headers=headers)
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


def ensure_bucket(bucket: str) -> None:
    status, payload = s3_request("PUT", bucket)
    if status not in {200, 409}:
        raise BackboneLiveFailure(f"s3-create-bucket:{bucket}:{status}:{payload.decode(errors='replace')}")


def minio_roundtrip() -> dict[str, Any]:
    bucket = "phase30-canary"
    key = "roundtrip/canary.bin"
    value = b"phase30-minio-roundtrip-byte-identical"
    ensure_bucket(bucket)
    status, payload = s3_request("PUT", bucket, key, value)
    if status != 200:
        raise BackboneLiveFailure(f"s3-put:{status}:{payload.decode(errors='replace')}")
    status, fetched = s3_request("GET", bucket, key)
    if status != 200 or fetched != value:
        raise BackboneLiveFailure(f"s3-get:{status}:{fetched!r}")
    return {"bucket": bucket, "key": key, "sha256": hashlib.sha256(value).hexdigest(), "byteIdentical": True}


def registry_config(filesystem: bool) -> str:
    storage = "  filesystem:\n    rootdirectory: /var/lib/registry\n" if filesystem else (
        "  s3:\n"
        f"    accesskey: {MINIO_ACCESS}\n"
        f"    secretkey: {MINIO_SECRET}\n"
        "    region: us-east-1\n"
        "    regionendpoint: http://minio.platform-system.svc:9000\n"
        "    forcepathstyle: true\n"
        "    bucket: registry\n"
        "    secure: false\n"
        "    v4auth: true\n"
    )
    return "version: 0.1\nlog:\n  level: info\nhttp:\n  addr: 0.0.0.0:5000\nstorage:\n" + storage


def apply_registry(filesystem: bool, source_dir: Path) -> None:
    config_name = "registry-source-config" if filesystem else "registry-config"
    name = "registry-source" if filesystem else "registry"
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": config_name, "namespace": PLATFORM_NAMESPACE}, "data": {"config.yml": registry_config(filesystem)}})
    volumes: list[dict[str, Any]] = [{"name": "config", "configMap": {"name": config_name}}]
    mounts: list[dict[str, Any]] = [{"name": "config", "mountPath": "/etc/distribution", "readOnly": True}]
    if filesystem:
        volumes.append({"name": "source", "hostPath": {"path": "/amoebius-retained/phase30-registry-source", "type": "Directory"}})
        mounts.append({"name": "source", "mountPath": "/var/lib/registry"})
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": name, "namespace": PLATFORM_NAMESPACE},
        "spec": {"replicas": 1, "selector": {"matchLabels": {"app": name}}, "template": {"metadata": {"labels": {"app": name}}, "spec": {"securityContext": {"runAsUser": 0, "runAsGroup": 0}, "containers": [{
            "name": "registry", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/docker-registry"], "args": ["serve", "/etc/distribution/config.yml"],
            "ports": [{"name": "registry", "containerPort": 5000}], "resources": resource_envelope("32Mi", "128Mi"), "volumeMounts": mounts,
            "readinessProbe": {"httpGet": {"path": "/v2/", "port": 5000}, "periodSeconds": 2, "failureThreshold": 90},
        }], "volumes": volumes}}},
    })
    apply({"apiVersion": "v1", "kind": "Service", "metadata": {"name": name, "namespace": PLATFORM_NAMESPACE}, "spec": {"selector": {"app": name}, "ports": [{"name": "registry", "port": 5000, "targetPort": 5000}]}})
    kubectl("-n", PLATFORM_NAMESPACE, "rollout", "status", f"deployment/{name}", "--timeout=180s")


def registry_request(method: str, path: str, body: bytes = b"", headers: dict[str, str] | None = None) -> tuple[int, dict[str, str], bytes]:
    connection = http.client.HTTPConnection("127.0.0.1", REGISTRY_PORT, timeout=30)
    try:
        request_headers = {"Content-Length": str(len(body)), **(headers or {})}
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        return response.status, {key.lower(): value for key, value in response.getheaders()}, response.read()
    finally:
        connection.close()


def registry_upload_blob(repository: str, value: bytes) -> str:
    digest = "sha256:" + hashlib.sha256(value).hexdigest()
    status, headers, payload = registry_request("POST", f"/v2/{repository}/blobs/uploads/")
    if status != 202:
        raise BackboneLiveFailure(f"registry-upload-start:{status}:{payload.decode(errors='replace')}")
    location = headers.get("location")
    if not location:
        raise BackboneLiveFailure("registry-upload-location-absent")
    separator = "&" if "?" in location else "?"
    status, _, payload = registry_request("PUT", location + separator + urllib.parse.urlencode({"digest": digest}), value, {"Content-Type": "application/octet-stream"})
    if status != 201:
        raise BackboneLiveFailure(f"registry-upload-finish:{status}:{payload.decode(errors='replace')}")
    return digest


def registry_push_fixture() -> dict[str, Any]:
    repository = "amoebius/phase30-preexisting"
    config = b'{"architecture":"amd64","config":{},"os":"linux","rootfs":{"diff_ids":[]},"schemaVersion":1}'
    layer = b"phase30-preexisting-layer"
    config_digest = registry_upload_blob(repository, config)
    layer_digest = registry_upload_blob(repository, layer)
    manifest = json.dumps({
        "schemaVersion": 2,
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "config": {"mediaType": "application/vnd.oci.image.config.v1+json", "digest": config_digest, "size": len(config)},
        "layers": [{"mediaType": "application/vnd.oci.image.layer.v1.tar", "digest": layer_digest, "size": len(layer)}],
    }, separators=(",", ":")).encode()
    status, _, payload = registry_request("PUT", f"/v2/{repository}/manifests/phase30", manifest, {"Content-Type": "application/vnd.oci.image.manifest.v1+json"})
    if status != 201:
        raise BackboneLiveFailure(f"registry-manifest-put:{status}:{payload.decode(errors='replace')}")
    status, _, fetched = registry_request("GET", f"/v2/{repository}/manifests/phase30", headers={"Accept": "application/vnd.oci.image.manifest.v1+json"})
    if status != 200 or json.loads(fetched) != json.loads(manifest):
        raise BackboneLiveFailure(f"registry-manifest-get:{status}")
    return {"repository": repository, "tag": "phase30", "configDigest": config_digest, "layerDigest": layer_digest, "manifestSha256": hashlib.sha256(manifest).hexdigest()}


def hash_directory(path: Path) -> str:
    digest = hashlib.sha256()
    for item in sorted(value for value in path.rglob("*") if value.is_file()):
        digest.update(str(item.relative_to(path)).encode() + b"\0")
        digest.update(item.read_bytes())
    return digest.hexdigest()


def migrate_registry_files(source_dir: Path) -> dict[str, Any]:
    ensure_bucket("registry")
    files = sorted(value for value in source_dir.rglob("*") if value.is_file())
    if not files:
        raise BackboneLiveFailure("registry-source-empty")
    copied: list[dict[str, Any]] = []
    for item in files:
        key = str(item.relative_to(source_dir))
        value = item.read_bytes()
        status, payload = s3_request("PUT", "registry", key, value)
        if status != 200:
            raise BackboneLiveFailure(f"registry-migration-put:{key}:{status}:{payload.decode(errors='replace')}")
        status, fetched = s3_request("GET", "registry", key)
        if status != 200 or fetched != value:
            raise BackboneLiveFailure(f"registry-migration-verify:{key}:{status}")
        copied.append({"key": key, "sha256": hashlib.sha256(value).hexdigest(), "bytes": len(value)})
    return {"objects": copied, "objectCount": len(copied), "verified": True}


def registry_rehome(source_dir: Path) -> dict[str, Any]:
    apply_registry(True, source_dir)
    with port_forward(PLATFORM_NAMESPACE, "service/registry-source", REGISTRY_PORT, 5000):
        fixture = registry_push_fixture()
    source_deployment = copy.deepcopy(APPLIED_OBJECTS[("Deployment", PLATFORM_NAMESPACE, "registry-source")])
    source_deployment["spec"]["replicas"] = 0
    apply(source_deployment)
    kubectl("-n", PLATFORM_NAMESPACE, "rollout", "status", "deployment/registry-source", "--timeout=120s")
    source_before = hash_directory(source_dir)
    with port_forward(PLATFORM_NAMESPACE, "service/minio", MINIO_PORT, 9000):
        migration = migrate_registry_files(source_dir)
    apply_registry(False, source_dir)
    with port_forward(PLATFORM_NAMESPACE, "service/registry", REGISTRY_PORT, 5000):
        status, _, manifest = registry_request("GET", f"/v2/{fixture['repository']}/manifests/{fixture['tag']}", headers={"Accept": "application/vnd.oci.image.manifest.v1+json"})
        if status != 200 or hashlib.sha256(manifest).hexdigest() != fixture["manifestSha256"]:
            raise BackboneLiveFailure(f"registry-after-cutover:{status}")
        new_digest = registry_upload_blob("amoebius/phase30-new", b"phase30-post-cutover-blob")
    source_after = hash_directory(source_dir)
    if source_before != source_after:
        raise BackboneLiveFailure("registry-source-mutated-after-cutover")
    with port_forward(PLATFORM_NAMESPACE, "service/minio", MINIO_PORT, 9000):
        status, listing = s3_request("GET", "registry", query="list-type=2")
    if status != 200:
        raise BackboneLiveFailure(f"registry-bucket-list:{status}:{listing.decode(errors='replace')}")
    keys = [node.text or "" for node in ElementTree.fromstring(listing).findall("{*}Contents/{*}Key")]
    digest_hex = new_digest.split(":", 1)[1]
    if not any(digest_hex in key for key in keys):
        raise BackboneLiveFailure("post-cutover-blob-not-in-minio")
    return {"fixture": fixture, "migration": migration, "sourceHashStable": True, "postCutoverDigest": new_digest, "minioObjectCount": len(keys), "backend": "s3"}


def assert_vault_unsealed() -> dict[str, Any]:
    def status_value() -> dict[str, Any]:
        result = kubectl(
            "-n", "vault-system", "exec", "root-vault-0", "--", "env", "VAULT_ADDR=http://127.0.0.1:8200",
            "/usr/bin/vault", "status", "-format=json", check=False,
        )
        try:
            status, _ = json.JSONDecoder().raw_decode(text(result).lstrip())
            return status
        except json.JSONDecodeError as problem:
            raise BackboneLiveFailure(f"vault-status-unreadable:{result.returncode}") from problem

    status = status_value()
    if status.get("sealed") or not status.get("initialized"):
        raise BackboneLiveFailure(f"vault-not-ready:{status}")
    kubectl("-n", "vault-system", "wait", "--for=condition=Ready", "pod/root-vault-0", "--timeout=180s")
    return {
        "initialized": True,
        "sealed": False,
        "clusterId": status.get("cluster_id", ""),
        "observedBeforePulsar": True,
        "unsealedDuringPlatformBackbone": False,
    }


def pulsar_persistent_volume(component: str, ordinal: int, raw_mib: int) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolume",
        "metadata": {"name": f"pulsar-system.{component}-data.pv-{ordinal}", "labels": {"amoebius.io/owner": f"phase30-{component}"}},
        "spec": {
            "capacity": {"storage": f"{raw_mib}Mi"}, "accessModes": ["ReadWriteOnce"], "storageClassName": "amoebius-retained",
            "persistentVolumeReclaimPolicy": "Retain", "volumeMode": "Filesystem",
            "claimRef": {"namespace": PULSAR_NAMESPACE, "name": f"data-{component}-{ordinal}"},
            "hostPath": {"path": f"/amoebius-retained/phase30-{component}-{ordinal}", "type": "Directory"},
            "nodeAffinity": {"required": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "kubernetes.io/hostname", "operator": "In", "values": [NODE]}]}]}},
        },
    }


def headless_service(name: str, selector: str, ports: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": name, "namespace": PULSAR_NAMESPACE},
        "spec": {"clusterIP": "None", "publishNotReadyAddresses": True, "selector": {"app": selector}, "ports": ports},
    }


def apply_zookeeper(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    config = "\n".join([
        "tickTime=2000", "initLimit=10", "syncLimit=5", "dataDir=/pulsar/data/zookeeper", "clientPort=2181",
        "maxClientCnxns=100", "admin.enableServer=false", "4lw.commands.whitelist=ruok,mntr,conf",
        "autopurge.snapRetainCount=3", "autopurge.purgeInterval=1", "forceSync=yes",
        "metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider", "metricsProvider.httpPort=8000",
        *[
            f"server.{ordinal + 1}=zookeeper-{ordinal}.zookeeper.{PULSAR_NAMESPACE}.svc.cluster.local:2888:3888"
            for ordinal in range(3)
        ],
    ]) + "\n"
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "zookeeper-config", "namespace": PULSAR_NAMESPACE}, "data": {"zookeeper.conf": config}})
    apply(headless_service("zookeeper", "pulsar-zookeeper", [
        {"name": "client", "port": 2181}, {"name": "quorum", "port": 2888}, {"name": "leader-election", "port": 3888},
    ]))
    for ordinal in range(3):
        apply(pulsar_persistent_volume("zookeeper", ordinal, 128))
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "zookeeper", "namespace": PULSAR_NAMESPACE},
        "spec": {
            "serviceName": "zookeeper", "replicas": 3, "podManagementPolicy": "Parallel",
            "selector": {"matchLabels": {"app": "pulsar-zookeeper"}},
            "template": {
                "metadata": {"labels": {"app": "pulsar-zookeeper"}},
                "spec": {"securityContext": {"runAsUser": 0, "runAsGroup": 0}, "containers": [{
                    "name": "zookeeper", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/bin/bash", "-ec"],
                    "args": ["ordinal=${HOSTNAME##*-}; printf '%s\\n' \"$((ordinal + 1))\" > /pulsar/data/zookeeper/myid; exec /pulsar/bin/pulsar zookeeper"],
                    "env": [
                        {"name": "PULSAR_ZK_CONF", "value": "/phase30-config/zookeeper.conf"},
                        {"name": "PULSAR_MEM", "value": "-Xms32m -Xmx96m -XX:MaxDirectMemorySize=32m"},
                        {"name": "PULSAR_LOG_DIR", "value": "/tmp"},
                    ],
                    "ports": [{"name": "client", "containerPort": 2181}, {"name": "quorum", "containerPort": 2888}, {"name": "election", "containerPort": 3888}],
                    "resources": resource_envelope("96Mi", "256Mi"),
                    "readinessProbe": {"tcpSocket": {"port": 2181}, "initialDelaySeconds": 2, "periodSeconds": 2, "failureThreshold": 90},
                    "volumeMounts": [{"name": "config", "mountPath": "/phase30-config"}, {"name": "data", "mountPath": "/pulsar/data/zookeeper"}],
                }], "volumes": [{"name": "config", "configMap": {"name": "zookeeper-config"}}]},
            },
            "volumeClaimTemplates": [{"metadata": {"name": "data"}, "spec": {"accessModes": ["ReadWriteOnce"], "storageClassName": "amoebius-retained", "resources": {"requests": {"storage": "128Mi"}}}}],
        },
    })
    kubectl("-n", PULSAR_NAMESPACE, "rollout", "status", "statefulset/zookeeper", "--timeout=360s", timeout=380)
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-zookeeper", "-o", "json")))
    return {"replicas": 3, "readyPods": len([pod for pod in pods["items"] if all(condition.get("status") == "True" for condition in pod["status"].get("conditions", []) if condition["type"] == "Ready")]), "volumes": volumes}


def apply_pulsar_metadata() -> dict[str, Any]:
    apply({
        "apiVersion": "batch/v1", "kind": "Job", "metadata": {"name": "pulsar-metadata", "namespace": PULSAR_NAMESPACE},
        "spec": {"backoffLimit": 12, "template": {"metadata": {"labels": {"app": "pulsar-metadata"}}, "spec": {
            "restartPolicy": "OnFailure", "containers": [{
                "name": "metadata", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/pulsar/bin/pulsar"],
                "args": [
                    "initialize-cluster-metadata", "--cluster", "phase30", "--zookeeper", "zookeeper:2181",
                    "--configuration-store", "zookeeper:2181", "--web-service-url", "http://broker.pulsar-system.svc.cluster.local:8080",
                    "--broker-service-url", "pulsar://broker.pulsar-system.svc.cluster.local:6650",
                ],
                "env": [{"name": "PULSAR_MEM", "value": "-Xms32m -Xmx96m -XX:MaxDirectMemorySize=32m"}, {"name": "PULSAR_LOG_DIR", "value": "/tmp"}],
                "resources": resource_envelope("96Mi", "256Mi"),
            }],
        }}},
    })
    kubectl("-n", PULSAR_NAMESPACE, "wait", "--for=condition=complete", "job/pulsar-metadata", "--timeout=300s", timeout=320)
    job = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "job", "pulsar-metadata", "-o", "json")))
    return {"completed": job.get("status", {}).get("succeeded", 0) == 1, "observedAfterZooKeeperReady": True}


def apply_bookkeeper(volumes: list[dict[str, Any]]) -> dict[str, Any]:
    config = "\n".join([
        "bookiePort=3181", "allowLoopback=true",
        "metadataServiceUri=zk+hierarchical://zookeeper.pulsar-system.svc.cluster.local:2181/ledgers",
        "journalDirectories=/pulsar/data/bookkeeper/journal", "ledgerDirectories=/pulsar/data/bookkeeper/ledgers",
        "indexDirectories=/pulsar/data/bookkeeper/index", "useHostNameAsBookieID=true",
        "minUsableSizeForIndexFileCreation=1048576", "diskUsageThreshold=0.99", "diskUsageWarnThreshold=0.95",
        "journalMaxSizeMB=16", "entryLogSizeLimit=16777216", "gcWaitTime=1000",
    ]) + "\n"
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "bookkeeper-config", "namespace": PULSAR_NAMESPACE}, "data": {"bookkeeper.conf": config}})
    apply(headless_service("bookkeeper", "pulsar-bookie", [{"name": "bookie", "port": 3181}, {"name": "metrics", "port": 8000}]))
    for ordinal in range(3):
        apply(pulsar_persistent_volume("bookkeeper", ordinal, 256))
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "bookkeeper", "namespace": PULSAR_NAMESPACE},
        "spec": {
            "serviceName": "bookkeeper", "replicas": 3, "podManagementPolicy": "Parallel",
            "selector": {"matchLabels": {"app": "pulsar-bookie"}},
            "template": {"metadata": {"labels": {"app": "pulsar-bookie"}}, "spec": {
                "securityContext": {"runAsUser": 0, "runAsGroup": 0}, "containers": [{
                    "name": "bookie", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/bin/bash", "-ec"],
                    "args": ["cp /phase30-config/bookkeeper.conf /tmp/bookkeeper.conf; printf 'advertisedAddress=%s.bookkeeper.pulsar-system.svc.cluster.local\\n' \"$HOSTNAME\" >> /tmp/bookkeeper.conf; exec /pulsar/bin/pulsar bookie"],
                    "env": [
                        {"name": "PULSAR_BOOKKEEPER_CONF", "value": "/tmp/bookkeeper.conf"},
                        {"name": "BOOKIE_MEM", "value": "-Xms64m -Xmx128m -XX:MaxDirectMemorySize=64m"},
                        {"name": "PULSAR_LOG_DIR", "value": "/tmp"},
                    ],
                    "ports": [{"name": "bookie", "containerPort": 3181}, {"name": "metrics", "containerPort": 8000}],
                    "resources": resource_envelope("160Mi", "384Mi"),
                    "readinessProbe": {"tcpSocket": {"port": 3181}, "initialDelaySeconds": 3, "periodSeconds": 2, "failureThreshold": 120},
                    "volumeMounts": [{"name": "config", "mountPath": "/phase30-config"}, {"name": "data", "mountPath": "/pulsar/data/bookkeeper"}],
                }], "volumes": [{"name": "config", "configMap": {"name": "bookkeeper-config"}}],
            }},
            "volumeClaimTemplates": [{"metadata": {"name": "data"}, "spec": {"accessModes": ["ReadWriteOnce"], "storageClassName": "amoebius-retained", "resources": {"requests": {"storage": "256Mi"}}}}],
        },
    })
    kubectl("-n", PULSAR_NAMESPACE, "rollout", "status", "statefulset/bookkeeper", "--timeout=480s", timeout=500)
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-bookie", "-o", "json")))
    return {"replicas": 3, "readyPods": len([pod for pod in pods["items"] if pod.get("status", {}).get("phase") == "Running"]), "volumes": volumes, "ensemble": 3, "writeQuorum": 2, "ackQuorum": 2}


def apply_brokers() -> dict[str, Any]:
    config = "\n".join([
        "metadataStoreUrl=zk:zookeeper.pulsar-system.svc.cluster.local:2181",
        "configurationMetadataStoreUrl=zk:zookeeper.pulsar-system.svc.cluster.local:2181", "clusterName=phase30",
        "brokerServicePort=6650", "webServicePort=8080", "defaultNumberOfNamespaceBundles=1",
        "managedLedgerDefaultEnsembleSize=3", "managedLedgerDefaultWriteQuorum=2", "managedLedgerDefaultAckQuorum=2",
        "managedLedgerMaxEntriesPerLedger=5", "managedLedgerMinLedgerRolloverTimeMinutes=0", "managedLedgerMaxLedgerRolloverTimeMinutes=1",
        "brokerDeduplicationEnabled=true", "brokerDeduplicationEntriesInterval=1", "allowAutoTopicCreation=false",
        "managedLedgerOffloadDriver=aws-s3", "offloadersDirectory=/pulsar/offloaders",
        "s3ManagedLedgerOffloadRegion=us-east-1", "s3ManagedLedgerOffloadBucket=pulsar-offload",
        "s3ManagedLedgerOffloadServiceEndpoint=http://minio.platform-system.svc.cluster.local:9000",
        "s3ManagedLedgerOffloadMaxBlockSizeInBytes=5242880", "s3ManagedLedgerOffloadReadBufferSizeInBytes=1048576",
        f"managedLedgerOffloadAutoTriggerSizeThresholdBytes={HOT_TIER_CAP}", "managedLedgerOffloadDeletionLagMs=0",
        "functionsWorkerEnabled=false", "brokerDeleteInactiveTopicsEnabled=false",
    ]) + "\n"
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "broker-config", "namespace": PULSAR_NAMESPACE}, "data": {"broker.conf": config}})
    apply(headless_service("broker-headless", "pulsar-broker", [{"name": "pulsar", "port": 6650}, {"name": "http", "port": 8080}]))
    apply({"apiVersion": "v1", "kind": "Service", "metadata": {"name": "broker", "namespace": PULSAR_NAMESPACE}, "spec": {"selector": {"app": "pulsar-broker"}, "ports": [{"name": "pulsar", "port": 6650}, {"name": "http", "port": 8080}]}})
    mounts = [{"name": "config", "mountPath": "/phase30-config"}]
    volumes: list[dict[str, Any]] = [{"name": "config", "configMap": {"name": "broker-config"}}]
    if DEV_OFFLOADERS:
        mounts.append({"name": "development-offloaders", "mountPath": "/pulsar/offloaders"})
        volumes.append({"name": "development-offloaders", "hostPath": {"path": "/amoebius-retained/phase30-offloaders", "type": "Directory"}})
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "broker", "namespace": PULSAR_NAMESPACE},
        "spec": {
            "serviceName": "broker-headless", "replicas": 2, "podManagementPolicy": "Parallel",
            "selector": {"matchLabels": {"app": "pulsar-broker"}},
            "template": {"metadata": {"labels": {"app": "pulsar-broker"}}, "spec": {
                "securityContext": {"runAsUser": 0, "runAsGroup": 0}, "containers": [{
                    "name": "broker", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/bin/bash", "-ec"],
                    "args": ["cp /phase30-config/broker.conf /tmp/broker.conf; printf 'advertisedAddress=%s.broker-headless.pulsar-system.svc.cluster.local\\n' \"$HOSTNAME\" >> /tmp/broker.conf; exec /pulsar/bin/pulsar broker"],
                    "env": [
                        {"name": "PULSAR_BROKER_CONF", "value": "/tmp/broker.conf"},
                        {"name": "PULSAR_MEM", "value": "-Xms128m -Xmx256m -XX:MaxDirectMemorySize=128m"},
                        {"name": "PULSAR_LOG_DIR", "value": "/tmp"},
                        {"name": "AWS_ACCESS_KEY_ID", "valueFrom": {"secretKeyRef": {"name": "pulsar-offload-credentials", "key": "access-key"}}},
                        {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": {"secretKeyRef": {"name": "pulsar-offload-credentials", "key": "secret-key"}}},
                    ],
                    "ports": [{"name": "pulsar", "containerPort": 6650}, {"name": "http", "containerPort": 8080}],
                    "resources": resource_envelope("320Mi", "768Mi", "256Mi", "1Gi"),
                    "readinessProbe": {"tcpSocket": {"port": 6650}, "initialDelaySeconds": 5, "periodSeconds": 2, "failureThreshold": 150},
                    "volumeMounts": mounts,
                }], "volumes": volumes,
            }},
        },
    })
    kubectl("-n", PULSAR_NAMESPACE, "rollout", "status", "statefulset/broker", "--timeout=600s", timeout=620)
    baked_offloaders = [
        line for line in text(kubectl(
            "-n", PULSAR_NAMESPACE, "exec", "broker-0", "--",
            "/usr/bin/find", "/pulsar/offloaders", "-type", "f",
        )).splitlines() if line.strip()
    ]
    if not baked_offloaders:
        raise BackboneLiveFailure("baked-pulsar-offloader-files-absent")
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "pulsar-tool", "namespace": PULSAR_NAMESPACE},
        "spec": {"replicas": 1, "selector": {"matchLabels": {"app": "pulsar-tool"}}, "template": {"metadata": {"labels": {"app": "pulsar-tool"}}, "spec": {
            "containers": [{
                "name": "tool", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/bin/bash", "-ec"],
                "args": ["exec /usr/bin/tail -f /dev/null"],
                "env": [{"name": "PULSAR_MEM", "value": "-Xms16m -Xmx64m -XX:MaxDirectMemorySize=32m"}, {"name": "PULSAR_LOG_DIR", "value": "/tmp"}],
                "resources": resource_envelope("32Mi", "384Mi"),
            }],
        }}},
    })
    kubectl("-n", PULSAR_NAMESPACE, "rollout", "status", "deployment/pulsar-tool", "--timeout=180s")
    pods = json.loads(text(kubectl("-n", PULSAR_NAMESPACE, "get", "pods", "-l", "app=pulsar-broker", "-o", "json")))
    return {
        "replicas": 2,
        "readyPods": len([pod for pod in pods["items"] if pod.get("status", {}).get("phase") == "Running"]),
        "nativePort": 6650,
        "webSocketUsed": False,
        "developmentOffloaderMount": DEV_OFFLOADERS,
        "bakedOffloaderFileCount": len(baked_offloaders),
        "bakedOffloaderFilesSha256": "sha256:" + hashlib.sha256("\n".join(sorted(baked_offloaders)).encode()).hexdigest(),
        "externalToolPod": True,
    }


def pulsar_admin(*arguments: str, allow_exists: bool = False) -> str:
    result = kubectl(
        "-n", PULSAR_NAMESPACE, "exec", "deployment/pulsar-tool", "--", "/pulsar/bin/pulsar-admin", "--admin-url", "http://broker.pulsar-system.svc.cluster.local:8080",
        *arguments, check=False, timeout=300,
    )
    output = text(result)
    if result.returncode and not (allow_exists and ("already exist" in output.lower() or "conflict" in output.lower())):
        raise BackboneLiveFailure(f"pulsar-admin:{arguments}:{result.returncode}:{output}")
    return output


def list_bucket_keys(bucket: str) -> list[str]:
    status, listing = s3_request("GET", bucket, query="list-type=2")
    if status != 200:
        raise BackboneLiveFailure(f"bucket-list:{bucket}:{status}:{listing.decode(errors='replace')}")
    return [node.text or "" for node in ElementTree.fromstring(listing).findall("{*}Contents/{*}Key")]


def encode_varint(value: int) -> bytes:
    encoded = bytearray()
    while value >= 0x80:
        encoded.append((value & 0x7f) | 0x80)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def proto_varint(field: int, value: int) -> bytes:
    return encode_varint(field << 3) + encode_varint(value)


def proto_bytes(field: int, value: bytes) -> bytes:
    return encode_varint((field << 3) | 2) + encode_varint(len(value)) + value


def proto_text(field: int, value: str) -> bytes:
    return proto_bytes(field, value.encode())


def base_command(command_type: int, command_field: int, payload: bytes) -> bytes:
    return proto_varint(1, command_type) + proto_bytes(command_field, payload)


def simple_pulsar_frame(command: bytes) -> bytes:
    body = struct.pack(">I", len(command)) + command
    return struct.pack(">I", len(body)) + body


def payload_pulsar_frame(command: bytes, metadata: bytes, payload: bytes) -> bytes:
    body = struct.pack(">I", len(command)) + command + struct.pack(">I", len(metadata)) + metadata + payload
    return struct.pack(">I", len(body)) + body


def decode_varint(value: bytes, offset: int) -> tuple[int, int]:
    result = 0
    shift = 0
    while offset < len(value) and shift < 70:
        byte = value[offset]
        offset += 1
        result |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return result, offset
        shift += 7
    raise BackboneLiveFailure("pulsar-protobuf-varint-malformed")


def proto_fields(value: bytes) -> dict[int, list[int | bytes]]:
    fields: dict[int, list[int | bytes]] = {}
    offset = 0
    while offset < len(value):
        tag, offset = decode_varint(value, offset)
        field = tag >> 3
        wire_type = tag & 7
        if wire_type == 0:
            decoded, offset = decode_varint(value, offset)
        elif wire_type == 2:
            size, offset = decode_varint(value, offset)
            decoded = value[offset:offset + size]
            if len(decoded) != size:
                raise BackboneLiveFailure("pulsar-protobuf-bytes-truncated")
            offset += size
        elif wire_type == 5:
            decoded = value[offset:offset + 4]
            offset += 4
        elif wire_type == 1:
            decoded = value[offset:offset + 8]
            offset += 8
        else:
            raise BackboneLiveFailure(f"pulsar-protobuf-wire-type:{wire_type}")
        fields.setdefault(field, []).append(decoded)
    return fields


def receive_exact(connection: socket.socket, size: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < size:
        value = connection.recv(size - len(chunks))
        if not value:
            raise BackboneLiveFailure("pulsar-native-connection-closed")
        chunks.extend(value)
    return bytes(chunks)


def receive_pulsar_frame(connection: socket.socket) -> tuple[int, dict[int, list[int | bytes]], bytes | None]:
    total_size = struct.unpack(">I", receive_exact(connection, 4))[0]
    body = receive_exact(connection, total_size)
    if len(body) < 4:
        raise BackboneLiveFailure("pulsar-native-frame-short")
    command_size = struct.unpack(">I", body[:4])[0]
    command = body[4:4 + command_size]
    if len(command) != command_size:
        raise BackboneLiveFailure("pulsar-native-command-short")
    base = proto_fields(command)
    command_type = int(base[1][0])
    nested_raw = base.get(command_type, [b""])[0]
    if not isinstance(nested_raw, bytes):
        raise BackboneLiveFailure(f"pulsar-native-command-payload:{command_type}")
    payload_block = body[4 + command_size:]
    payload: bytes | None = None
    if payload_block:
        if payload_block.startswith(b"\x0e\x01"):
            payload_block = payload_block[6:]
        if len(payload_block) < 4:
            raise BackboneLiveFailure("pulsar-native-payload-metadata-short")
        metadata_size = struct.unpack(">I", payload_block[:4])[0]
        if len(payload_block) < 4 + metadata_size:
            raise BackboneLiveFailure("pulsar-native-payload-short")
        payload = payload_block[4 + metadata_size:]
    return command_type, proto_fields(nested_raw), payload


def wait_for_pulsar_command(connection: socket.socket, accepted: set[int]) -> tuple[int, dict[int, list[int | bytes]], bytes | None]:
    while True:
        command_type, fields, payload = receive_pulsar_frame(connection)
        if command_type == 18:
            connection.sendall(simple_pulsar_frame(base_command(19, 19, b"")))
            continue
        if command_type in {8, 14}:
            raise BackboneLiveFailure(f"pulsar-native-broker-error:{command_type}:{fields}")
        if command_type in accepted:
            return command_type, fields, payload


def native_dedup_probe(topic: str) -> str:
    lookup = pulsar_admin("topics", "lookup", topic)
    match = re.search(r"pulsar://(broker-[0-9]+)\.", lookup)
    if match is None:
        raise BackboneLiveFailure(f"pulsar-topic-owner-unresolved:{lookup}")
    broker_pod = match.group(1)
    cbor_one = bytes([0xa1, 0x65, 0x70, 0x68, 0x61, 0x73, 0x65, 0x18, 0x1e])
    cbor_duplicate = b"duplicate-must-not-arrive"
    cbor_two = bytes([0xa1, 0x63, 0x73, 0x65, 0x71, 0x08])
    producer_name = "phase30-sequenced-producer"
    subscription = f"phase30-dedup-observer-{time.time_ns()}"
    with tcp_port_forward(PULSAR_NAMESPACE, f"pod/{broker_pod}", 16650, 6650):
        with socket.create_connection(("127.0.0.1", 16650), timeout=30) as connection:
            connection.settimeout(30)
            connect = proto_text(1, "amoebius-phase30-native-probe") + proto_varint(4, 21)
            connection.sendall(simple_pulsar_frame(base_command(2, 2, connect)))
            wait_for_pulsar_command(connection, {3})
            subscribe = b"".join([
                proto_text(1, topic), proto_text(2, subscription), proto_varint(3, 0),
                proto_varint(4, 1), proto_varint(5, 1), proto_text(6, "phase30-observer"),
                proto_varint(8, 1), proto_varint(13, 1), proto_varint(15, 0),
            ])
            connection.sendall(simple_pulsar_frame(base_command(4, 4, subscribe)))
            wait_for_pulsar_command(connection, {13})
            producer = b"".join([
                proto_text(1, topic), proto_varint(2, 1), proto_varint(3, 2),
                proto_text(4, producer_name), proto_varint(9, 1),
            ])
            connection.sendall(simple_pulsar_frame(base_command(5, 5, producer)))
            wait_for_pulsar_command(connection, {17})
            for sequence_id, value in ((7, cbor_one), (7, cbor_duplicate), (8, cbor_two)):
                send = proto_varint(1, 1) + proto_varint(2, sequence_id) + proto_varint(3, 1)
                metadata = b"".join([
                    proto_text(1, producer_name), proto_varint(2, sequence_id),
                    proto_varint(3, int(time.time() * 1000)), proto_varint(11, 1),
                ])
                connection.sendall(payload_pulsar_frame(base_command(6, 6, send), metadata, value))
                _, receipt, _ = wait_for_pulsar_command(connection, {7})
                if int(receipt[2][0]) != sequence_id:
                    raise BackboneLiveFailure(f"pulsar-native-receipt-sequence:{receipt}")
            flow = proto_varint(1, 1) + proto_varint(2, 3)
            connection.sendall(simple_pulsar_frame(base_command(11, 11, flow)))
            received: list[bytes] = []
            while len(received) < 2:
                _, _, payload = wait_for_pulsar_command(connection, {9})
                if payload is None:
                    raise BackboneLiveFailure("pulsar-native-message-payload-absent")
                received.append(payload)
            connection.settimeout(3)
            deadline = time.monotonic() + 3
            try:
                while time.monotonic() < deadline:
                    command_type, _, _ = receive_pulsar_frame(connection)
                    if command_type == 9:
                        raise BackboneLiveFailure("pulsar-native-duplicate-delivered")
            except socket.timeout:
                pass
    if set(received) != {cbor_one, cbor_two} or cbor_duplicate in received:
        raise BackboneLiveFailure(f"pulsar-native-cbor-drift:{received}")
    return "platform-backbone-dedup-probe: PASS native=true sequenceIds=7,7,8 delivered=2 cborByteIdentical=true"


def configure_and_drill_pulsar() -> dict[str, Any]:
    pulsar_admin("tenants", "create", "phase30", "--allowed-clusters", "phase30", allow_exists=True)
    pulsar_admin("namespaces", "create", "phase30/drill", "--clusters", "phase30", allow_exists=True)
    pulsar_admin("namespaces", "set-retention", "phase30/drill", "--size", "1M", "--time", "1h")
    pulsar_admin("namespaces", "set-deduplication", "phase30/drill", "--enable")
    pulsar_admin(
        "namespaces", "set-offload-policies", "phase30/drill", "--driver", "aws-s3", "--region", "us-east-1",
        "--bucket", "pulsar-offload", "--endpoint", "http://minio.platform-system.svc.cluster.local:9000",
        "--aws-id", MINIO_ACCESS, "--aws-secret", MINIO_SECRET, "--maxBlockSize", "5M",
        "--offloadAfterThreshold", str(HOT_TIER_CAP), "--offloadAfterElapsed", "0",
    )
    dedup_topic = f"persistent://phase30/drill/dedup-{time.time_ns()}"
    offload_topic = "persistent://phase30/drill/offload"
    pulsar_admin("topics", "create", dedup_topic, allow_exists=True)
    pulsar_admin("topics", "create", offload_topic, allow_exists=True)
    probe_marker = native_dedup_probe(dedup_topic)
    producer = kubectl(
        "-n", PULSAR_NAMESPACE, "exec", "deployment/pulsar-tool", "--", "/pulsar/bin/pulsar-client",
        "--url", "pulsar://broker.pulsar-system.svc.cluster.local:6650", "produce", "--disable-batching",
        "--num-produce", "100", "--messages", "x" * 4096, offload_topic,
        timeout=300,
    )
    producer_output = text(producer)
    producer_marker = "100 messages successfully produced"
    if producer_marker not in producer_output:
        raise BackboneLiveFailure(f"producer-success-marker-absent:{producer_output}")
    deadline = time.monotonic() + 180
    keys: list[str] = []
    hot_bytes = HOT_TIER_CAP + 1
    internal: dict[str, Any] = {}
    with port_forward(PLATFORM_NAMESPACE, "service/minio", MINIO_PORT, 9000):
        while time.monotonic() < deadline:
            keys = list_bucket_keys("pulsar-offload")
            stats_text = pulsar_admin("topics", "stats-internal", offload_topic)
            internal = json.loads(stats_text)
            ledgers = internal.get("ledgers", [])
            hot_bytes = sum(int(ledger.get("size", 0)) for ledger in ledgers if not ledger.get("offloaded", False))
            if keys and hot_bytes <= HOT_TIER_CAP:
                break
            time.sleep(2)
        else:
            raise BackboneLiveFailure(f"offload-not-bounded:objects={len(keys)}:hot={hot_bytes}:stats={internal}")
    return {
        "nativeRoundtrip": True, "deduplicationExercised": True, "sequenceIds": [7, 7, 8], "deliveredMessages": 2,
        "cborByteIdentical": True, "dedupProbeOutput": probe_marker,
        "offload": {
            "topic": offload_topic, "configuredSizeTriggerBytes": HOT_TIER_CAP, "timeOnly": False,
            "producedBytes": 100 * 4096, "objectCount": len(keys), "objectKeys": keys[:20],
            "hotTierBytes": hot_bytes, "hotTierCapBytes": HOT_TIER_CAP, "bounded": hot_bytes <= HOT_TIER_CAP,
            "observer": "broker-admin-stats-internal-plus-minio-s3-list",
        },
        "producerOutputMarker": producer_marker,
        "producerExited": producer.returncode == 0,
    }


def apply_pulsar() -> dict[str, Any]:
    vault = assert_vault_unsealed()
    apply(namespace(PULSAR_NAMESPACE))
    apply({
        "apiVersion": "v1", "kind": "Secret", "metadata": {"name": "pulsar-offload-credentials", "namespace": PULSAR_NAMESPACE},
        "type": "Opaque", "stringData": {"access-key": MINIO_ACCESS, "secret-key": MINIO_SECRET},
    })
    with port_forward(PLATFORM_NAMESPACE, "service/minio", MINIO_PORT, 9000):
        ensure_bucket("pulsar-offload")
    zookeeper_volumes = [prepare_volume(f"phase30-zookeeper-{ordinal}", 128 * MIB) for ordinal in range(3)]
    bookkeeper_volumes = [prepare_volume(f"phase30-bookkeeper-{ordinal}", 256 * MIB) for ordinal in range(3)]
    zookeeper = apply_zookeeper(zookeeper_volumes)
    metadata = apply_pulsar_metadata()
    bookkeeper = apply_bookkeeper(bookkeeper_volumes)
    broker = apply_brokers()
    drill = configure_and_drill_pulsar()
    return {"vaultReadyEdge": vault, "zookeeper": zookeeper, "metadata": metadata, "bookkeeper": bookkeeper, "broker": broker, "drill": drill}


def image_and_resource_evidence() -> dict[str, Any]:
    pods = json.loads(text(kubectl("get", "pods", "-A", "-o", "json")))
    selected = [item for item in pods["items"] if item["metadata"]["namespace"] in {METALLB_NAMESPACE, PLATFORM_NAMESPACE, "pulsar-system"}]
    images: list[str] = []
    image_ids: list[str] = []
    resources_exact = True
    public_refs: list[str] = []
    for pod in selected:
        statuses = {
            status.get("name"): status.get("imageID", "")
            for status in pod.get("status", {}).get("containerStatuses", [])
        }
        for container in pod["spec"].get("containers", []):
            image = container["image"]
            images.append(image)
            if image != PRIVATE_IMAGE:
                public_refs.append(image)
            limits = container.get("resources", {}).get("limits", {})
            requests = container.get("resources", {}).get("requests", {})
            resources_exact = resources_exact and all(key in limits and key in requests for key in ("cpu", "memory", "ephemeral-storage"))
            image_id = statuses.get(container["name"], "")
            image_ids.append(image_id)
            if IMAGE_DIGEST not in image_id:
                raise BackboneLiveFailure(f"runtime-image-id-drift:{pod['metadata']['namespace']}/{pod['metadata']['name']}:{container['name']}:{image_id}")
    if public_refs or not resources_exact or not image_ids:
        raise BackboneLiveFailure(f"image-resource-provenance:{public_refs}:{resources_exact}:{len(image_ids)}")
    return {
        "podCount": len(selected), "images": sorted(set(images)), "runtimeImageIds": sorted(set(image_ids)),
        "allRuntimeImageIdsMatchBaseDigest": True, "publicImageReferences": public_refs,
        "completeResourceFields": resources_exact,
    }


def live_object(kind: str, namespace_name: str, name: str) -> dict[str, Any]:
    arguments = (["-n", namespace_name] if namespace_name else []) + ["get", kind, name, "-o", "json", "--show-managed-fields"]
    return json.loads(text(kubectl(*arguments)))


def projected_like(observed: Any, desired: Any, path: str = "$") -> Any:
    if isinstance(desired, dict):
        if not isinstance(observed, dict):
            raise BackboneLiveFailure(f"ssa-projection-type:{path}")
        missing = sorted(set(desired) - set(observed))
        if missing:
            raise BackboneLiveFailure(f"ssa-projection-missing:{path}:{missing}")
        return {key: projected_like(observed[key], value, f"{path}.{key}") for key, value in desired.items()}
    if isinstance(desired, list):
        if not isinstance(observed, list) or len(observed) < len(desired):
            raise BackboneLiveFailure(f"ssa-projection-list:{path}:{len(desired)}")
        return [projected_like(observed[index], value, f"{path}[{index}]") for index, value in enumerate(desired)]
    return observed


def verify_ssa_projection() -> dict[str, Any]:
    rows: list[dict[str, str]] = []
    for (kind, namespace_name, name), desired in sorted(APPLIED_OBJECTS.items()):
        observed = live_object(kind, namespace_name, name)
        managers = {
            entry.get("manager", "")
            for entry in observed.get("metadata", {}).get("managedFields", [])
        }
        if "amoebius" not in managers:
            raise BackboneLiveFailure(f"ssa-field-manager-absent:{kind}/{namespace_name}/{name}:{sorted(managers)}")
        projection = projected_like(observed, desired)
        desired_bytes = canonical_bytes(desired)
        projection_bytes = canonical_bytes(projection)
        if not hmac.compare_digest(desired_bytes, projection_bytes):
            raise BackboneLiveFailure(f"ssa-byte-projection-drift:{kind}/{namespace_name}/{name}")
        rows.append({
            "identity": f"{kind}/{namespace_name}/{name}",
            "sha256": "sha256:" + hashlib.sha256(desired_bytes).hexdigest(),
        })
    if not rows:
        raise BackboneLiveFailure("ssa-projection-empty")
    return {
        "fieldManager": "amoebius",
        "objectCount": len(rows),
        "allOwnedFieldsByteIdentical": True,
        "objectHashes": rows,
        "aggregateSha256": "sha256:" + hashlib.sha256(canonical_bytes(rows)).hexdigest(),
    }


def quantity(value: str, *, cpu: bool = False) -> int:
    if cpu:
        return int(value[:-1]) if value.endswith("m") else int(value) * 1000
    factors = {"Ki": 1024, "Mi": MIB, "Gi": 1024 * MIB}
    for suffix, factor in factors.items():
        if value.endswith(suffix):
            return int(value[:-len(suffix)]) * factor
    return int(value)


def resource_projection(container: dict[str, Any]) -> dict[str, int]:
    resources = container.get("resources", {})
    requests = resources.get("requests", {})
    limits = resources.get("limits", {})
    return {
        "requestCpuMillis": quantity(requests["cpu"], cpu=True),
        "limitCpuMillis": quantity(limits["cpu"], cpu=True),
        "requestMemoryBytes": quantity(requests["memory"]),
        "limitMemoryBytes": quantity(limits["memory"]),
        "requestEphemeralBytes": quantity(requests["ephemeral-storage"]),
        "limitEphemeralBytes": quantity(limits["ephemeral-storage"]),
    }


def fresh_haskell_render_plan() -> list[dict[str, Any]]:
    binary = text(run(cabal_command("list-bin", "platform-backbone-spec"))).strip()
    if not binary:
        raise BackboneLiveFailure("phase30-haskell-renderer-binary-absent")
    rendered = json.loads(text(run((binary, "--render-plan"))))
    if not isinstance(rendered, list) or not rendered:
        raise BackboneLiveFailure("phase30-haskell-render-plan-empty")
    return rendered


def verify_haskell_render_projection() -> dict[str, Any]:
    expected = fresh_haskell_render_plan()
    actual: list[dict[str, Any]] = []
    for plan_object in expected:
        kind = plan_object["objectKind"]
        namespace_name = plan_object["objectNamespace"]
        name = plan_object["objectName"]
        observed = live_object(kind, namespace_name, name)
        if kind == "Service":
            ingress = observed.get("status", {}).get("loadBalancer", {}).get("ingress", [])
            addresses = [entry.get("ip") or entry.get("hostname") for entry in ingress]
            projected = {
                **plan_object,
                "objectArguments": addresses,
            }
        else:
            pod_spec = observed["spec"]["template"]["spec"]
            container = pod_spec["containers"][0]
            resource_names = set(container.get("resources", {}).get("requests", {})) | set(container.get("resources", {}).get("limits", {}))
            accelerator = sorted(name for name in resource_names if "/" in name)
            cache_volumes = sorted(volume.get("name", "") for volume in pod_spec.get("volumes", []) if "cache" in volume.get("name", "").lower())
            projected = {
                "objectAccelerator": accelerator[0] if accelerator else None,
                "objectArguments": container.get("command", []) + container.get("args", []),
                "objectCache": 0 if cache_volumes else None,
                "objectImage": container["image"],
                "objectKind": kind,
                "objectName": name,
                "objectNamespace": namespace_name,
                "objectReplicas": 1 if kind in {"DaemonSet", "Job"} else observed["spec"].get("replicas", 1),
                "objectResources": resource_projection(container),
            }
        if canonical_bytes(projected) != canonical_bytes(plan_object):
            raise BackboneLiveFailure(
                f"haskell-render-projection-drift:{kind}/{namespace_name}/{name}:"
                f"expected={canonical_bytes(plan_object).decode()}:actual={canonical_bytes(projected).decode()}"
            )
        actual.append(projected)
    rendered_bytes = canonical_bytes(expected)
    return {
        "renderer": "Amoebius.Platform.Backbone.renderBackbone",
        "freshGateProcessOutput": True,
        "objectCount": len(expected),
        "allAppliedProjectionsByteIdentical": True,
        "renderSha256": "sha256:" + hashlib.sha256(rendered_bytes).hexdigest(),
    }


def node_pull_event_evidence(since: datetime.datetime) -> dict[str, Any]:
    since_text = since.astimezone(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    output = text(run(("/usr/bin/docker", "logs", "--since", since_text, NODE), check=False))
    pull_lines = [line for line in output.splitlines() if "pull" in line.lower() and "image" in line.lower()]
    public_lines = [line for line in pull_lines if any(token in line for token in PUBLIC_REGISTRY_TOKENS)]
    if public_lines:
        raise BackboneLiveFailure(f"public-registry-pull-events:{public_lines[:10]}")
    return {
        "observer": "kind-node-containerd-log-window", "since": since_text,
        "pullEventCount": len(pull_lines), "publicPullEventCount": 0,
        "windowSha256": "sha256:" + hashlib.sha256(output.encode()).hexdigest(),
    }


def execute() -> dict[str, Any]:
    gate_started = datetime.datetime.now(datetime.timezone.utc)
    APPLIED_OBJECTS.clear()
    ensure_cluster_image()
    reset_generated_phase30_state()
    volumes = [prepare_volume(f"phase30-minio-{index}", 128 * MIB) for index in range(4)]
    source_dir = RETAINED_ROOT / "mounts/phase30-registry-source"
    source_dir.mkdir(parents=True, exist_ok=True)
    os.chmod(source_dir, 0o777)
    metallb = apply_metallb()
    minio = apply_minio(volumes)
    load_balancer = wait_for_load_balancer()
    with port_forward(PLATFORM_NAMESPACE, "service/minio", MINIO_PORT, 9000):
        roundtrip = minio_roundtrip()
    registry = registry_rehome(source_dir)
    pulsar = apply_pulsar()
    provenance = image_and_resource_evidence()
    provenance["ssaProjection"] = verify_ssa_projection()
    provenance["haskellRenderProjection"] = verify_haskell_render_projection()
    pull_events = node_pull_event_evidence(gate_started)
    evidence = {
        "schema": "amoebius.phase30.backbone-live.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "artifactSource": {"digest": IMAGE_DIGEST, "imagePullPolicy": "Never", "publicPulls": 0, "pullEvents": pull_events},
        "metallb": metallb,
        "minio": minio,
        "minioRoundtrip": roundtrip,
        "registryRehome": registry,
        "pulsar": pulsar,
        "loadBalancer": load_balancer,
        "provenance": provenance,
        "deferred": {"keycloak": "UNVERIFIED", "phase31Services": "UNVERIFIED", "singletonOwnedReconcile": "UNVERIFIED"},
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
    }
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--image-digest", required=True)
    arguments = parser.parse_args(argv)
    resolved = toolchain.resolve(["cabal", "ghc", "kind", "kubectl"])
    globals()["CABAL"] = os.environ.get("AMOEBIUS_CABAL", resolved["cabal"]["path"])
    globals()["KIND"] = os.environ.get("AMOEBIUS_KIND", resolved["kind"]["path"])
    globals()["KUBECTL"] = os.environ.get("AMOEBIUS_KUBECTL", resolved["kubectl"]["path"])
    globals()["IMAGE_ARCHIVE"] = arguments.artifact
    globals()["IMAGE_DIGEST"] = arguments.image_digest
    globals()["PRIVATE_IMAGE"] = f"registry.amoebius.invalid:5000/amoebius/base@{arguments.image_digest}"
    globals()["EVIDENCE"] = arguments.output
    globals()["MINIO_ACCESS"] = "amoebius-" + secrets.token_hex(8)
    globals()["MINIO_SECRET"] = secrets.token_urlsafe(32)
    globals()["MEMBERLIST_SECRET"] = secrets.token_urlsafe(32)
    os.environ["AMOEBIUS_CABAL"] = CABAL
    os.environ["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
    globals()["KIND_CONFIG"] = materialize_kind_config(arguments.output.parent)
    try:
        containment.require_state_path(arguments.output, "build", actor="test")
        predecessor = bootstrap_vault_predecessor()
        address, pool = derive_load_balancer_pool()
        globals()["LOAD_BALANCER_ADDRESS"] = address
        globals()["LOAD_BALANCER_POOL"] = pool
        os.environ["AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_IMAGE"] = PRIVATE_IMAGE
        os.environ["AMOEBIUS_PLATFORM_BACKBONE_RUNTIME_ADDRESS"] = LOAD_BALANCER_ADDRESS
        evidence = execute()
        evidence["vaultPredecessor"] = predecessor
        arguments.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"platform-backbone-live: PASS (MetalLB, four-drive MinIO, registry {evidence['registryRehome']['backend']}, Pulsar HA/offload)")
        return 0
    except (
        BackboneLiveFailure,
        vault.VaultLiveFailure,
        toolchain.ResolutionError,
        containment.ContainmentError,
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
        ElementTree.ParseError,
    ) as problem:
        print(f"platform-backbone-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
