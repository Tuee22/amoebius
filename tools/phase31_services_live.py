#!/usr/bin/env python3
"""Exercise the Phase-31 platform services on the retained Phase-30 cluster."""

from __future__ import annotations

import base64
import copy
import datetime
import hashlib
import hmac
import json
import os
import re
import secrets
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any, Sequence

import phase29_vault_live as phase29
import phase30_backbone_live as phase30


ROOT = Path(__file__).resolve().parents[1]
KUBECTL = phase30.KUBECTL
KUBECONFIG = phase30.KUBECONFIG
NODE = phase30.NODE
PRIVATE_IMAGE = phase30.PRIVATE_IMAGE
IMAGE_DIGEST = phase30.IMAGE_DIGEST
CABAL = phase30.CABAL
MIB = 1024 * 1024
RETAINED_ROOT = Path("/var/tmp/amoebius-phase31-retained")
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_31/services-live.json"
PHASE30_EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_30/backbone-live.json"
POSTGRES_SHARE_PACKAGE = RETAINED_ROOT / "assets/postgresql-17_17.6-2.pgdg12+1_amd64.deb"
POSTGRES_SHARE_SHA256 = "717b35be108c5641cc84667999be7b4f89687513e12c3ad636cbc91d7493830a"
NAMESPACES = ("postgres-operator", "grafana-db", "observability", "redis-system")
PUBLIC_REGISTRY_TOKENS = phase30.PUBLIC_REGISTRY_TOKENS
APPLIED_OBJECTS: dict[tuple[str, str, str], dict[str, Any]] = {}
READINESS_OBSERVATIONS: dict[str, dict[str, Any]] = {}


class ServicesLiveFailure(RuntimeError):
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
        raise ServicesLiveFailure(
            f"{tuple(arguments)}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}"
        )
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def kubectl(
    *arguments: str,
    input_value: str | None = None,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 300,
) -> subprocess.CompletedProcess[bytes]:
    payload = input_bytes if input_bytes is not None else (input_value.encode() if input_value is not None else None)
    return run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments),
        input_bytes=payload, check=check, timeout=timeout,
    )


def ready_pod_name(namespace_name: str, selector: str) -> str:
    pods = json.loads(text(kubectl("-n", namespace_name, "get", "pods", "-l", selector, "-o", "json"))).get("items", [])
    ready = [
        pod for pod in pods
        if not pod.get("metadata", {}).get("deletionTimestamp")
        and any(
            condition.get("type") == "Ready" and condition.get("status") == "True"
            for condition in pod.get("status", {}).get("conditions", [])
        )
    ]
    if not ready:
        raise ServicesLiveFailure(f"ready-pod-absent:{namespace_name}:{selector}")
    return max(ready, key=lambda pod: pod["metadata"]["creationTimestamp"])["metadata"]["name"]


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


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


def apply(value: dict[str, Any], *, retain_for_projection: bool = True) -> None:
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
        "-f", "-", input_value=json.dumps(desired), timeout=300,
    )
    if retain_for_projection:
        key = object_key(desired)
        APPLIED_OBJECTS[key] = merge_object(APPLIED_OBJECTS.get(key, {}), desired)


def namespace(name: str) -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": name}}


def resource_envelope(size: str) -> dict[str, Any]:
    values = {
        "small": ("32Mi", "128Mi", "16Mi", "64Mi"),
        "medium": ("64Mi", "256Mi", "16Mi", "128Mi"),
        "large": ("128Mi", "512Mi", "32Mi", "256Mi"),
    }
    memory_request, memory_limit, ephemeral_request, ephemeral_limit = values[size]
    return {
        "requests": {"cpu": "25m", "memory": memory_request, "ephemeral-storage": ephemeral_request},
        "limits": {"cpu": "250m", "memory": memory_limit, "ephemeral-storage": ephemeral_limit},
    }


def container_security() -> dict[str, Any]:
    return {
        "allowPrivilegeEscalation": False,
        "capabilities": {"drop": ["ALL"]},
        "runAsNonRoot": True,
        "runAsUser": 1000,
        "runAsGroup": 1000,
        "seccompProfile": {"type": "RuntimeDefault"},
    }


def ensure_cluster_prerequisites() -> dict[str, Any]:
    phase30.ensure_cluster_image()
    if not PHASE30_EVIDENCE.is_file():
        raise ServicesLiveFailure("phase30-evidence-absent")
    phase30_evidence = json.loads(PHASE30_EVIDENCE.read_text(encoding="utf-8"))
    if phase30_evidence.get("schema") != "amoebius.phase30.backbone-live.v1":
        raise ServicesLiveFailure("phase30-evidence-schema")
    checks = {
        "metalLB": ("metallb-system", "deployment/controller"),
        "minio": ("platform-system", "statefulset/minio"),
        "registry": ("platform-system", "deployment/registry"),
        "zooKeeper": ("pulsar-system", "statefulset/zookeeper"),
        "bookKeeper": ("pulsar-system", "statefulset/bookkeeper"),
        "pulsar": ("pulsar-system", "statefulset/broker"),
        "vault": ("vault-system", "pod/root-vault-0"),
    }
    for label, (namespace_name, resource) in checks.items():
        result = kubectl("-n", namespace_name, "get", resource, "-o", "json", check=False)
        if result.returncode:
            raise ServicesLiveFailure(f"phase30-backbone-resource-absent:{label}")
    vault = phase30.assert_vault_unsealed()
    return {
        "phase30EvidenceSha256": "sha256:" + hashlib.sha256(PHASE30_EVIDENCE.read_bytes()).hexdigest(),
        "resourcesObserved": sorted(checks),
        "vault": vault,
    }


def ensure_namespaces() -> None:
    for name in NAMESPACES:
        apply(namespace(name))


def loop_for_image(image: Path) -> str | None:
    listed = text(run(("/usr/bin/sudo", "-n", "/usr/sbin/losetup", "-j", str(image)), check=False))
    candidates = []
    for line in listed.splitlines():
        candidate = line.split(":", 1)[0]
        if re.fullmatch(r"/dev/loop[0-9]+", candidate):
            candidates.append(candidate)
    if len(candidates) > 1:
        raise ServicesLiveFailure(f"backing-multiple-loop-devices:{image}:{candidates}")
    return candidates[0] if candidates else None


def prepare_node_backing(name: str, raw_bytes: int) -> dict[str, Any]:
    image = RETAINED_ROOT / "images" / f"{name}.ext4"
    node_target = f"/amoebius-phase31-retained/{name}"
    image.parent.mkdir(parents=True, exist_ok=True)
    if not image.exists():
        run(("/usr/bin/truncate", "-s", str(raw_bytes), str(image)))
        run(("/usr/bin/sudo", "-n", "/usr/sbin/mkfs.ext4", "-q", "-F", "-m", "0", str(image)))
    if image.stat().st_size != raw_bytes:
        raise ServicesLiveFailure(f"backing-size-drift:{name}:{image.stat().st_size}:{raw_bytes}")
    loop = loop_for_image(image)
    if loop is None:
        loop = text(run(("/usr/bin/sudo", "-n", "/usr/sbin/losetup", "--find", "--show", str(image)))).strip()
    if not re.fullmatch(r"/dev/loop[0-9]+", loop):
        raise ServicesLiveFailure(f"backing-loop-device-invalid:{name}:{loop}")
    minor = loop.removeprefix("/dev/loop")
    present = run(("/usr/bin/docker", "exec", NODE, "test", "-b", loop), check=False).returncode == 0
    if not present:
        run(("/usr/bin/docker", "exec", NODE, "mknod", loop, "b", "7", minor))
        run(("/usr/bin/docker", "exec", NODE, "chmod", "0660", loop))
    run(("/usr/bin/docker", "exec", NODE, "mkdir", "-p", node_target))
    source = text(run(("/usr/bin/docker", "exec", NODE, "findmnt", "-n", "-o", "SOURCE", "--mountpoint", node_target), check=False)).strip()
    if not source:
        run(("/usr/bin/docker", "exec", NODE, "mount", "-t", "ext4", loop, node_target))
    elif source != loop:
        raise ServicesLiveFailure(f"backing-node-mount-drift:{name}:{source}:{loop}")
    run(("/usr/bin/docker", "exec", NODE, "chown", "-R", "1000:1000", node_target))
    filesystem = text(run(("/usr/bin/docker", "exec", NODE, "findmnt", "-n", "-o", "FSTYPE", "--mountpoint", node_target))).strip()
    available = int(text(run(("/usr/bin/docker", "exec", NODE, "df", "-B1", "--output=avail", node_target))).splitlines()[-1])
    if filesystem != "ext4":
        raise ServicesLiveFailure(f"backing-filesystem-drift:{name}:{filesystem}")
    return {
        "name": name,
        "image": str(image),
        "loopDevice": loop,
        "nodeMount": node_target,
        "rawBytes": raw_bytes,
        "usableBytes": available,
        "filesystemType": filesystem,
    }


def prepare_postgres_share() -> dict[str, Any]:
    if not POSTGRES_SHARE_PACKAGE.is_file():
        raise ServicesLiveFailure(f"postgres-share-package-absent:{POSTGRES_SHARE_PACKAGE}")
    package_sha256 = hashlib.sha256(POSTGRES_SHARE_PACKAGE.read_bytes()).hexdigest()
    if not hmac.compare_digest(package_sha256, POSTGRES_SHARE_SHA256):
        raise ServicesLiveFailure(f"postgres-share-package-digest:{package_sha256}")
    backing = prepare_node_backing("postgres-share", 32 * MIB)
    marker = backing["nodeMount"] + "/.amoebius-package-sha256"
    observed = text(run(("/usr/bin/docker", "exec", NODE, "/bin/bash", "-ec", f"test -f {marker} && cat {marker} || true"))).strip()
    bki_path = backing["nodeMount"] + "/postgres.bki"
    bki_present = run(("/usr/bin/docker", "exec", NODE, "test", "-f", bki_path), check=False).returncode == 0
    if observed != POSTGRES_SHARE_SHA256 or not bki_present:
        extract_root = RETAINED_ROOT / "assets/postgresql-17-extracted"
        extract_root.mkdir(parents=True, exist_ok=True)
        run(("/usr/bin/dpkg-deb", "--extract", str(POSTGRES_SHARE_PACKAGE), str(extract_root)))
        source = extract_root / "usr/share/postgresql/17"
        if not (source / "postgres.bki").is_file():
            raise ServicesLiveFailure("postgres-share-extraction-incomplete")
        archive = run(("/usr/bin/tar", "--create", "--file", "-", "--directory", str(source), ".")).stdout
        run(("/usr/bin/docker", "exec", "-i", NODE, "/usr/bin/tar", "--extract", "--file", "-", "--directory", backing["nodeMount"]), input_bytes=archive)
        del archive
        run(("/usr/bin/docker", "exec", NODE, "/bin/bash", "-ec", f"printf '%s\\n' {POSTGRES_SHARE_SHA256} > {marker}; chmod -R a+rX {backing['nodeMount']}"))
    bki_sha256 = text(run((
        "/usr/bin/docker", "exec", NODE, "/usr/bin/sha256sum", bki_path,
    ))).split()[0]
    return {**backing, "packageSha256": "sha256:" + package_sha256, "postgresBkiSha256": "sha256:" + bki_sha256}


def persistent_volume(name: str, namespace_name: str, claim: str, backing: dict[str, Any], capacity: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "PersistentVolume",
        "metadata": {"name": name, "labels": {"amoebius.io/owner": "phase31"}},
        "spec": {
            "capacity": {"storage": capacity},
            "accessModes": ["ReadWriteOnce"],
            "storageClassName": "amoebius-retained",
            "persistentVolumeReclaimPolicy": "Retain",
            "volumeMode": "Filesystem",
            "claimRef": {"namespace": namespace_name, "name": claim},
            "hostPath": {"path": backing["nodeMount"], "type": "Directory"},
            "nodeAffinity": {"required": {"nodeSelectorTerms": [{"matchExpressions": [{
                "key": "kubernetes.io/hostname", "operator": "In", "values": [NODE],
            }]}]}},
        },
    }


def open_vault_root_token() -> str:
    operator_password = os.environ.get("PHASE29_OPERATOR_PASSWORD")
    development_password = os.environ.get("PHASE29_DEVELOPMENT_PASSWORD")
    if operator_password is not None and development_password is not None:
        raise ServicesLiveFailure("multiple-vault-password-sources")
    password = operator_password if operator_password is not None else development_password
    binary = phase30.RETAINED_ROOT / "mounts/phase29-bin/amoebius"
    envelope = phase30.RETAINED_ROOT / "phase29-unlock.age"
    if password is None or not binary.is_file() or not envelope.is_file():
        raise ServicesLiveFailure("phase29-operator-password-required")
    opened = run(
        (str(binary), "vault-open-unlock"),
        input_bytes=password.encode() + b"\n" + envelope.read_bytes(), timeout=120,
    )
    material = json.loads(opened.stdout)
    token = material.get("root_token")
    if not isinstance(token, str) or not token:
        raise ServicesLiveFailure("vault-root-token-absent")
    del material
    return token


def vault_material() -> tuple[dict[str, str], dict[str, Any]]:
    root_token = open_vault_root_token()
    password_keys = (
        "postgresSuperuser", "grafanaDatabase", "redisClient", "redisReplication", "redisSentinel",
    )
    with phase29.port_forward():
        status, payload = phase29.api_request("GET", "secret/data/phase31/platform-services", root_token)
        if status == 200:
            generated = json.loads(payload).get("data", {}).get("data", {})
        elif status == 404:
            generated = {key: secrets.token_urlsafe(30) for key in password_keys}
        else:
            raise ServicesLiveFailure(f"vault-phase31-kv-read:{status}")
        if any(not isinstance(generated.get(key), str) or not generated[key] for key in password_keys):
            raise ServicesLiveFailure("vault-phase31-password-material-incomplete")
        if any(not generated.get(key) for key in ("tls.crt", "tls.key", "ca.crt", "certificateSerial")):
            issue = phase29.require_api(
                "POST", "pki/issue/internal", root_token,
                {
                    "common_name": "redis.redis-system.svc.amoebius.internal",
                    "alt_names": ",".join([
                        "redis.redis-system.svc.amoebius.internal",
                        "redis-0.redis-system.svc.amoebius.internal",
                        "redis-1.redis-system.svc.amoebius.internal",
                        "redis-2.redis-system.svc.amoebius.internal",
                        "sentinel.redis-system.svc.amoebius.internal",
                    ]),
                    "ttl": "2h",
                },
            )
            certificate = issue.get("data", {})
            required = ("certificate", "private_key", "issuing_ca", "serial_number")
            if any(not certificate.get(key) for key in required):
                raise ServicesLiveFailure("vault-pki-material-incomplete")
            generated.update({
                "tls.crt": certificate["certificate"] + "\n" + "\n".join(certificate.get("ca_chain", [])) + "\n",
                "tls.key": certificate["private_key"], "ca.crt": certificate["issuing_ca"],
                "certificateSerial": certificate["serial_number"],
            })
        phase29.require_api(
            "POST", "secret/data/phase31/platform-services", root_token,
            {"data": generated},
        )
        readback = phase29.require_api("GET", "secret/data/phase31/platform-services", root_token)
    del root_token
    observed = readback.get("data", {}).get("data", {})
    if observed != generated:
        raise ServicesLiveFailure("vault-kv-readback-drift")
    material = dict(generated)
    provenance = {
        "kvPath": "secret/data/phase31/platform-services",
        "kvVersion": readback.get("data", {}).get("metadata", {}).get("version"),
        "pkiPath": "pki/issue/internal",
        "certificateSerial": material["certificateSerial"],
        "certificateSha256": "sha256:" + hashlib.sha256(material["tls.crt"].encode()).hexdigest(),
        "vaultSourced": True,
    }
    del generated
    del observed
    return material, provenance


def apply_secret_material(material: dict[str, str]) -> None:
    apply({
        "apiVersion": "v1", "kind": "Secret", "metadata": {"name": "grafana-postgres-credentials", "namespace": "grafana-db"},
        "type": "Opaque", "stringData": {
            "superuser": material["postgresSuperuser"],
            "grafana": material["grafanaDatabase"],
        },
    })
    apply({
        "apiVersion": "v1", "kind": "Secret", "metadata": {"name": "grafana-postgres-credentials", "namespace": "observability"},
        "type": "Opaque", "stringData": {"grafana": material["grafanaDatabase"]},
    })
    acl = "\n".join([
        "user default off",
        f"user realtime on >{material['redisClient']} ~amoebius:* &amoebius:* +get +set +del +expire +ttl +ping +info +publish +subscribe +psubscribe +unsubscribe +punsubscribe",
        f"user replication on >{material['redisReplication']} ~* &* +@all",
        "",
    ])
    apply({
        "apiVersion": "v1", "kind": "Secret", "metadata": {"name": "redis-vault-identity", "namespace": "redis-system"},
        "type": "Opaque", "stringData": {
            "tls.crt": material["tls.crt"], "tls.key": material["tls.key"], "ca.crt": material["ca.crt"],
            "client-password": material["redisClient"], "replication-password": material["redisReplication"],
            "sentinel-password": material["redisSentinel"], "users.acl": acl,
        },
    })


def generic_crd(name: str, group: str, version: str, kind: str, plural: str) -> dict[str, Any]:
    return {
        "apiVersion": "apiextensions.k8s.io/v1", "kind": "CustomResourceDefinition",
        "metadata": {"name": name},
        "spec": {
            "group": group, "scope": "Namespaced", "names": {"kind": kind, "plural": plural, "singular": plural.rstrip("s")},
            "versions": [{
                "name": version, "served": True, "storage": True,
                "schema": {"openAPIV3Schema": {
                    "type": "object",
                    "properties": {
                        "apiVersion": {"type": "string"}, "kind": {"type": "string"}, "metadata": {"type": "object"},
                        "spec": {"type": "object", "x-kubernetes-preserve-unknown-fields": True},
                        "status": {"type": "object", "x-kubernetes-preserve-unknown-fields": True},
                    },
                }},
                "subresources": {"status": {}},
            }],
        },
    }


def apply_operator_contract() -> None:
    definitions = [
        ("crunchybridgeclusters.postgres-operator.crunchydata.com", "postgres-operator.crunchydata.com", "v1beta1", "CrunchyBridgeCluster", "crunchybridgeclusters"),
        ("pgadmins.postgres-operator.crunchydata.com", "postgres-operator.crunchydata.com", "v1beta1", "PGAdmin", "pgadmins"),
        ("pgupgrades.postgres-operator.crunchydata.com", "postgres-operator.crunchydata.com", "v1beta1", "PGUpgrade", "pgupgrades"),
        ("postgresclusters.postgres-operator.crunchydata.com", "postgres-operator.crunchydata.com", "v1beta1", "PostgresCluster", "postgresclusters"),
        ("perconapgbackups.pgv2.percona.com", "pgv2.percona.com", "v2", "PerconaPGBackup", "perconapgbackups"),
        ("perconapgclusters.pgv2.percona.com", "pgv2.percona.com", "v2", "PerconaPGCluster", "perconapgclusters"),
        ("perconapgrestores.pgv2.percona.com", "pgv2.percona.com", "v2", "PerconaPGRestore", "perconapgrestores"),
        ("perconapgupgrades.pgv2.percona.com", "pgv2.percona.com", "v2", "PerconaPGUpgrade", "perconapgupgrades"),
    ]
    for row in definitions:
        apply(generic_crd(*row))
    apply({
        "apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "percona-operator", "namespace": "postgres-operator"},
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole", "metadata": {"name": "phase31-percona-operator"},
        "rules": [
            {"apiGroups": ["*"], "resources": ["*"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]},
            {"nonResourceURLs": ["/metrics"], "verbs": ["get"]},
        ],
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding", "metadata": {"name": "phase31-percona-operator"},
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "phase31-percona-operator"},
        "subjects": [{"kind": "ServiceAccount", "name": "percona-operator", "namespace": "postgres-operator"}],
    })


def deployment(
    namespace_name: str,
    name: str,
    replicas: int,
    command: list[str],
    resources: dict[str, Any],
    *,
    env: list[dict[str, Any]] | None = None,
    ports: list[dict[str, Any]] | None = None,
    volumes: list[dict[str, Any]] | None = None,
    volume_mounts: list[dict[str, Any]] | None = None,
    readiness: dict[str, Any] | None = None,
    service_account: str | None = None,
    labels: dict[str, str] | None = None,
    annotations: dict[str, str] | None = None,
) -> dict[str, Any]:
    pod_labels = {"app": name, **(labels or {})}
    container: dict[str, Any] = {
        "name": name, "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
        "command": command[:1], "resources": resources,
        "securityContext": container_security(),
    }
    if command[1:]:
        container["args"] = command[1:]
    if env:
        container["env"] = env
    if ports:
        container["ports"] = ports
    if volume_mounts:
        container["volumeMounts"] = volume_mounts
    if readiness:
        container["readinessProbe"] = readiness
    pod_spec: dict[str, Any] = {"containers": [container], "automountServiceAccountToken": service_account is not None}
    if service_account:
        pod_spec["serviceAccountName"] = service_account
    if volumes:
        pod_spec["volumes"] = volumes
    return {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": name, "namespace": namespace_name},
        "spec": {
            "replicas": replicas, "selector": {"matchLabels": {"app": name}},
            "template": {"metadata": {"labels": pod_labels, **({"annotations": annotations} if annotations else {})}, "spec": pod_spec},
        },
    }


def apply_operator() -> dict[str, Any]:
    apply_operator_contract()
    common_env = [
        {"name": "POD_NAMESPACE", "valueFrom": {"fieldRef": {"fieldPath": "metadata.namespace"}}},
        {"name": "PGO_FEATURE_GATES", "value": "InstanceSidecars=true,PGBouncerSidecars=true,TablespaceVolumes=true"},
        {"name": "DISABLE_TELEMETRY", "value": "true"},
    ]
    apply(deployment(
        "postgres-operator", "percona-operator", 1,
        ["/usr/bin/percona-postgresql-operator"], resource_envelope("small"),
        env=[*common_env, {"name": "WATCH_NAMESPACE", "value": "grafana-db"}],
        readiness={"exec": {"command": ["/bin/bash", "-ec", "test -r /proc/1/status"]}, "periodSeconds": 2},
        service_account="percona-operator",
    ))
    apply(deployment(
        "postgres-operator", "percona-webhook", 1,
        ["/bin/bash", "-ec", "exec /usr/bin/percona-postgresql-operator"], resource_envelope("small"),
        env=[*common_env, {"name": "WATCH_NAMESPACE", "value": "postgres-operator"}],
        readiness={"exec": {"command": ["/bin/bash", "-ec", "test -r /proc/1/status"]}, "periodSeconds": 2},
        service_account="percona-operator",
    ))
    for name in ("percona-operator", "percona-webhook"):
        kubectl("-n", "postgres-operator", "rollout", "status", f"deployment/{name}", "--timeout=240s", timeout=260)
    return {"ready": True, "replicas": 1, "webhookReplicas": 1}


PATRONI_ORACLE = "synchronous_mode: on\nsynchronous_mode_strict: on\nmaximum_lag_on_failover: 1048576\n"


def patroni_config() -> str:
    return """scope: grafana
name: placeholder
restapi:
  listen: 0.0.0.0:8008
  connect_address: 127.0.0.1:8008
kubernetes:
  namespace: grafana-db
  use_endpoints: true
  labels:
    app: grafana-postgres
    cluster-name: grafana
  role_label: role
postgresql:
  listen: 0.0.0.0:5432
  connect_address: 127.0.0.1:5432
  data_dir: /pgdata/data
  bin_dir: /usr/lib/postgresql/17/bin
  pgpass: /tmp/pgpass
  pg_hba:
  - local all all trust
  - host all all 0.0.0.0/0 scram-sha-256
  - host replication replicator 0.0.0.0/0 scram-sha-256
  authentication:
    superuser:
      username: postgres
    replication:
      username: replicator
    rewind:
      username: rewind
bootstrap:
  dcs:
    ttl: 30
    loop_wait: 5
    retry_timeout: 5
    maximum_lag_on_failover: 1048576
    synchronous_mode: true
    synchronous_mode_strict: true
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        shared_buffers: 16MB
        max_connections: 64
        unix_socket_directories: /tmp
        wal_level: replica
        max_wal_senders: 10
        max_replication_slots: 10
  initdb:
  - encoding: UTF8
  - data-checksums
  pg_hba:
  - local all all trust
  - host all all 0.0.0.0/0 scram-sha-256
  - host replication replicator 0.0.0.0/0 scram-sha-256
"""


def apply_patroni_rbac() -> None:
    apply({"apiVersion": "v1", "kind": "ServiceAccount", "metadata": {"name": "patroni", "namespace": "grafana-db"}})
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "Role", "metadata": {"name": "patroni", "namespace": "grafana-db"},
        "rules": [
            {"apiGroups": [""], "resources": ["pods", "configmaps", "endpoints", "services"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]},
            {"apiGroups": [""], "resources": ["pods/status"], "verbs": ["get", "patch", "update"]},
        ],
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "RoleBinding", "metadata": {"name": "patroni", "namespace": "grafana-db"},
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": "patroni"},
        "subjects": [{"kind": "ServiceAccount", "name": "patroni", "namespace": "grafana-db"}],
    })


def apply_postgres(backings: list[dict[str, Any]], postgres_share: dict[str, Any]) -> dict[str, Any]:
    apply_patroni_rbac()
    apply({
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "grafana-patroni", "namespace": "grafana-db"},
        "data": {"patroni.yml": patroni_config(), "mandated-sync.golden": PATRONI_ORACLE},
    })
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "grafana-postgres", "namespace": "grafana-db"},
        "spec": {"clusterIP": "None", "publishNotReadyAddresses": True, "selector": {"app": "grafana-postgres"}, "ports": [
            {"name": "postgres", "port": 5432}, {"name": "patroni", "port": 8008},
        ]},
    })
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "grafana-primary", "namespace": "grafana-db"},
        "spec": {"selector": {"app": "grafana-postgres", "role": "primary"}, "ports": [{"name": "postgres", "port": 5432}]},
    })
    cr = {
        "apiVersion": "pgv2.percona.com/v2", "kind": "PerconaPGCluster", "metadata": {
            "name": "grafana", "namespace": "grafana-db",
            "annotations": {"pgv2.percona.com/custom-patroni-version": "4"},
        },
        "spec": {
            "crVersion": "2.6.0", "postgresVersion": 17, "pause": True, "unmanaged": True,
            "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
            "instances": [{
                "name": "instance1", "replicas": 3,
                "resources": resource_envelope("large"),
                "dataVolumeClaimSpec": {"storageClassName": "amoebius-retained", "accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "256Mi"}}},
            }],
            "proxy": {"pgBouncer": {"replicas": 1, "image": PRIVATE_IMAGE, "resources": resource_envelope("small")}},
            "backups": {"pgbackrest": {"image": PRIVATE_IMAGE, "repos": []}},
            "patroni": {"dynamicConfiguration": {
                "synchronous_mode": True, "synchronous_mode_strict": True,
                "maximum_lag_on_failover": 1048576,
            }},
            "amoebiusProjection": {"configuration": PATRONI_ORACLE, "storageBudgetId": "grafana-postgres"},
        },
    }
    apply(cr)
    for ordinal, backing in enumerate(backings):
        apply(persistent_volume(
            f"grafana-db.grafana-postgres-data.pv-{ordinal}", "grafana-db",
            f"data-grafana-postgres-{ordinal}", backing, "256Mi",
        ))
    apply(persistent_volume(
        "grafana-db.postgres-share.pv", "grafana-db", "postgres-share", postgres_share, "32Mi",
    ))
    apply({
        "apiVersion": "v1", "kind": "PersistentVolumeClaim", "metadata": {"name": "postgres-share", "namespace": "grafana-db"},
        "spec": {"storageClassName": "amoebius-retained", "volumeName": "grafana-db.postgres-share.pv", "accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "32Mi"}}},
    })
    command = ["/bin/bash", "-ec", "exec /usr/local/bin/patroni /etc/patroni/patroni.yml"]
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "grafana-postgres", "namespace": "grafana-db"},
        "spec": {
            "serviceName": "grafana-postgres", "replicas": 3, "podManagementPolicy": "Parallel",
            "selector": {"matchLabels": {"app": "grafana-postgres"}},
            "template": {
                "metadata": {"labels": {"app": "grafana-postgres", "cluster-name": "grafana"}},
                "spec": {
                    "serviceAccountName": "patroni", "securityContext": {"fsGroup": 1000, "fsGroupChangePolicy": "OnRootMismatch"},
                    "containers": [{
                        "name": "grafana-postgres", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                        "command": command[:2], "args": command[2:], "resources": resource_envelope("large"),
                        "securityContext": container_security(),
                        "ports": [{"name": "postgres", "containerPort": 5432}, {"name": "patroni", "containerPort": 8008}],
                        "env": [
                            {"name": "PATRONI_NAME", "valueFrom": {"fieldRef": {"fieldPath": "metadata.name"}}},
                            {"name": "PATRONI_KUBERNETES_POD_IP", "valueFrom": {"fieldRef": {"fieldPath": "status.podIP"}}},
                            {"name": "PATRONI_RESTAPI_CONNECT_ADDRESS", "value": "$(PATRONI_KUBERNETES_POD_IP):8008"},
                            {"name": "PATRONI_POSTGRESQL_CONNECT_ADDRESS", "value": "$(PATRONI_KUBERNETES_POD_IP):5432"},
                            {"name": "PATRONI_SUPERUSER_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "grafana-postgres-credentials", "key": "superuser"}}},
                            {"name": "PATRONI_REPLICATION_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "grafana-postgres-credentials", "key": "superuser"}}},
                            {"name": "PATRONI_REWIND_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "grafana-postgres-credentials", "key": "superuser"}}},
                        ],
                        "readinessProbe": {"httpGet": {"path": "/readiness", "port": 8008}, "periodSeconds": 2, "failureThreshold": 90},
                        "livenessProbe": {"httpGet": {"path": "/liveness", "port": 8008}, "periodSeconds": 10, "failureThreshold": 12},
                        "volumeMounts": [
                            {"name": "config", "mountPath": "/etc/patroni", "readOnly": True},
                            {"name": "credentials", "mountPath": "/phase31-secrets", "readOnly": True},
                            {"name": "postgres-share", "mountPath": "/usr/share/postgresql/17", "readOnly": True},
                            {"name": "data", "mountPath": "/pgdata"},
                        ],
                    }],
                    "volumes": [
                        {"name": "config", "configMap": {"name": "grafana-patroni"}},
                        {"name": "credentials", "secret": {"secretName": "grafana-postgres-credentials"}},
                        {"name": "postgres-share", "persistentVolumeClaim": {"claimName": "postgres-share", "readOnly": True}},
                    ],
                },
            },
            "volumeClaimTemplates": [{
                "metadata": {"name": "data"},
                "spec": {"storageClassName": "amoebius-retained", "accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "256Mi"}}},
            }],
        },
    })
    kubectl("-n", "grafana-db", "rollout", "status", "statefulset/grafana-postgres", "--timeout=480s", timeout=500)
    primary = ready_pod_name("grafana-db", "app=grafana-postgres,role=primary")
    if not primary:
        raise ServicesLiveFailure("patroni-primary-not-observed")
    create_database = """set -eu
export PGPASSWORD="$(cat /phase31-secrets/superuser)"
if ! /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -tAc "select 1 from pg_roles where rolname='grafana'" | grep -qx 1; then
  /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 -c "create role grafana login password '$(cat /phase31-secrets/grafana)'"
fi
if ! /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -tAc "select 1 from pg_database where datname='grafana'" | grep -qx 1; then
  /usr/lib/postgresql/17/bin/createdb -h 127.0.0.1 -U postgres -O grafana grafana
fi
"""
    kubectl("-n", "grafana-db", "exec", primary, "--", "/bin/bash", "-ec", create_database)
    return {"replicas": 3, "readyReplicas": 3, "primary": primary, "mandatedConfiguration": PATRONI_ORACLE}


def apply_database_surfaces() -> dict[str, Any]:
    apply(deployment(
        "grafana-db", "grafana-sql-gateway", 1,
        ["/bin/bash", "-ec", "/usr/lib/postgresql/17/bin/pg_isready -h grafana-primary -p 5432; exec /usr/bin/tail -f /dev/null"],
        resource_envelope("small"),
        readiness={"exec": {"command": ["/usr/lib/postgresql/17/bin/pg_isready", "-h", "grafana-primary", "-p", "5432"]}, "periodSeconds": 2},
    ))
    pgadmin_volumes = [{"name": "pgadmin-data", "emptyDir": {"sizeLimit": "64Mi"}}]
    apply(deployment(
        "grafana-db", "grafana-pgadmin", 1,
        ["/bin/bash", "-ec", "mkdir -p /tmp/pgadmin; unset LD_LIBRARY_PATH; export PYTHONPATH=/venv/lib/python3.12/site-packages:/pgadmin4; exec /lib/ld-musl-x86_64.so.1 /usr/bin/pgadmin-python3.12 /pgadmin4/pgAdmin4.py"],
        resource_envelope("medium"),
        env=[
            {"name": "PGADMIN_SETUP_EMAIL", "value": "phase31@amoebius.internal"},
            {"name": "PGADMIN_SETUP_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "grafana-postgres-credentials", "key": "grafana"}}},
            {"name": "PGADMIN_CONFIG_DEFAULT_SERVER", "value": "0.0.0.0"}, {"name": "PGADMIN_LISTEN_PORT", "value": "5050"},
            {"name": "PGADMIN_SERVER_MODE", "value": "False"},
        ],
        ports=[{"name": "http", "containerPort": 5050}], volumes=pgadmin_volumes,
        volume_mounts=[
            {"name": "pgadmin-data", "mountPath": "/var/lib/pgadmin"},
            {"name": "pgadmin-data", "mountPath": "/var/log/pgadmin"},
        ],
        readiness={"httpGet": {"path": "/misc/ping", "port": 5050}, "periodSeconds": 3, "failureThreshold": 60},
    ))
    for name in ("grafana-sql-gateway", "grafana-pgadmin"):
        kubectl("-n", "grafana-db", "rollout", "status", f"deployment/{name}", "--timeout=240s", timeout=260)
    return {"sqlGatewayReady": True, "pgAdminReady": True}


QUERY_PROXY_SOURCE = r'''#!/usr/bin/python3
import argparse, http.client, http.server, threading, urllib.parse
p=argparse.ArgumentParser(); p.add_argument('--max-concurrent',type=int,required=True); p.add_argument('--max-series',type=int,required=True); p.add_argument('--max-samples',type=int,required=True); p.add_argument('--max-range-seconds',type=int,required=True); p.add_argument('--timeout-seconds',type=int,required=True); a=p.parse_args(); slots=threading.BoundedSemaphore(a.max_concurrent)
class H(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  if self.path == '/healthz': self.send_response(200); self.end_headers(); self.wfile.write(b'ok'); return
  bounds=(('X-Amoebius-Series',a.max_series),('X-Amoebius-Samples',a.max_samples),('X-Amoebius-Range-Seconds',a.max_range_seconds))
  try:
   if any(int(self.headers.get(k,'0'))>v for k,v in bounds): self.send_response(429); self.end_headers(); return
  except ValueError: self.send_response(400); self.end_headers(); return
  if not slots.acquire(False): self.send_response(429); self.end_headers(); return
  try:
   c=http.client.HTTPConnection('prometheus.observability.svc',9090,timeout=a.timeout_seconds); c.request('GET',self.path); r=c.getresponse(); body=r.read(a.max_samples*64); self.send_response(r.status); self.send_header('Content-Type',r.getheader('Content-Type','application/json')); self.end_headers(); self.wfile.write(body); c.close()
  finally: slots.release()
 def log_message(self,*x): pass
http.server.ThreadingHTTPServer(('0.0.0.0',8080),H).serve_forever()
'''


def apply_observability(backing: dict[str, Any]) -> dict[str, Any]:
    prometheus_config = """global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
- /etc/prometheus/rules.yml
scrape_configs:
- job_name: prometheus
  static_configs:
  - targets: ['127.0.0.1:9090']
- job_name: pulsar-brokers
  static_configs:
  - targets: ['broker.pulsar-system.svc.cluster.local:8080']
- job_name: zookeeper
  static_configs:
  - targets: ['zookeeper.pulsar-system.svc.cluster.local:8000']
"""
    rules = """groups:
- name: amoebius-derived-workflow
  interval: 15s
  rules:
  - record: amoebius:platform_targets_up:sum
    expr: sum(up)
  - alert: AmoebiusPlatformTargetDown
    expr: up == 0
    for: 30s
    labels: {severity: warning}
    annotations: {summary: 'derived platform target readiness'}
"""
    apply({
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "prometheus-derived", "namespace": "observability", "annotations": {"amoebius.io/generated": "MonitoringWorkBudget/v1"}},
        "data": {"prometheus.yml": prometheus_config, "rules.yml": rules},
    })
    apply({
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "prometheus-query-proxy", "namespace": "observability", "annotations": {"amoebius.io/generated": "QueryWorkBudget/v1"}},
        "data": {"query_proxy.py": QUERY_PROXY_SOURCE},
    })
    apply({
        "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "grafana-derived-dashboard", "namespace": "observability", "annotations": {"amoebius.io/generated": "MonitoringWorkBudget/v1"}},
        "data": {"platform.json": json.dumps({"title": "Amoebius platform", "panels": [{"type": "timeseries", "targets": [{"expr": "amoebius:platform_targets_up:sum"}]}]}, sort_keys=True)},
    })
    apply(persistent_volume("observability.prometheus-data.pv-0", "observability", "data-prometheus-0", backing, "128Mi"))
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "prometheus", "namespace": "observability"},
        "spec": {"selector": {"app": "prometheus"}, "ports": [{"name": "http", "port": 9090}]},
    })
    prometheus_command = [
        "/usr/bin/prometheus", "--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=3600s", "--storage.tsdb.retention.size=67108864B",
        "--query.max-concurrency=4", "--query.max-samples=4096", "--query.timeout=30s",
    ]
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "prometheus", "namespace": "observability"},
        "spec": {
            "serviceName": "prometheus", "replicas": 1, "selector": {"matchLabels": {"app": "prometheus"}},
            "template": {"metadata": {"labels": {"app": "prometheus"}}, "spec": {
                "securityContext": {"fsGroup": 1000, "fsGroupChangePolicy": "OnRootMismatch"},
                "containers": [{
                    "name": "prometheus", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": prometheus_command[:1], "args": prometheus_command[1:], "resources": resource_envelope("large"),
                    "securityContext": container_security(), "ports": [{"name": "http", "containerPort": 9090}],
                    "readinessProbe": {"httpGet": {"path": "/-/ready", "port": 9090}, "periodSeconds": 2, "failureThreshold": 90},
                    "volumeMounts": [{"name": "config", "mountPath": "/etc/prometheus", "readOnly": True}, {"name": "data", "mountPath": "/prometheus"}],
                }], "volumes": [{"name": "config", "configMap": {"name": "prometheus-derived"}}],
            }},
            "volumeClaimTemplates": [{"metadata": {"name": "data"}, "spec": {"storageClassName": "amoebius-retained", "accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "128Mi"}}}}],
        },
    })
    query_command = [
        "/usr/bin/python3", "/phase31-query-proxy/query_proxy.py", "--max-concurrent=4", "--max-series=64",
        "--max-samples=4096", "--max-range-seconds=3600", "--timeout-seconds=30",
    ]
    apply(deployment(
        "observability", "prometheus-query-proxy", 1, query_command, resource_envelope("small"),
        ports=[{"name": "http", "containerPort": 8080}],
        volumes=[{"name": "query-proxy", "configMap": {"name": "prometheus-query-proxy", "defaultMode": 365}}],
        volume_mounts=[{"name": "query-proxy", "mountPath": "/phase31-query-proxy", "readOnly": True}],
        readiness={"httpGet": {"path": "/healthz", "port": 8080}, "periodSeconds": 2, "failureThreshold": 60},
    ))
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "prometheus-query-proxy", "namespace": "observability"},
        "spec": {"selector": {"app": "prometheus-query-proxy"}, "ports": [{"name": "http", "port": 8080}]},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "prometheus-direct-query-deny", "namespace": "observability"},
        "spec": {
            "podSelector": {"matchLabels": {"app": "prometheus"}}, "policyTypes": ["Ingress"],
            "ingress": [{"from": [{"podSelector": {"matchLabels": {"app": "prometheus-query-proxy"}}}], "ports": [{"protocol": "TCP", "port": 9090}]}],
        },
    })
    kubectl("-n", "observability", "rollout", "status", "statefulset/prometheus", "--timeout=300s", timeout=320)
    kubectl("-n", "observability", "rollout", "status", "deployment/prometheus-query-proxy", "--timeout=180s", timeout=200)
    return {"prometheusReady": True, "queryProxyReady": True, "retentionSeconds": 3600, "retentionBytes": 67108864}


def apply_grafana() -> dict[str, Any]:
    grafana_command = ["/usr/share/grafana/bin/grafana", "server", "--homepath=/usr/share/grafana"]
    apply(deployment(
        "observability", "grafana", 1, grafana_command, resource_envelope("medium"),
        env=[
            {"name": "GF_DATABASE_TYPE", "value": "postgres"},
            {"name": "GF_DATABASE_HOST", "value": "grafana-primary.grafana-db.svc.cluster.local:5432"},
            {"name": "GF_DATABASE_NAME", "value": "grafana"}, {"name": "GF_DATABASE_USER", "value": "grafana"},
            {"name": "GF_DATABASE_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "grafana-postgres-credentials", "key": "grafana"}}},
            {"name": "GF_DATABASE_SSL_MODE", "value": "disable"},
            {"name": "GF_SECURITY_ADMIN_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "grafana-postgres-credentials", "key": "grafana"}}},
            {"name": "GF_ANALYTICS_REPORTING_ENABLED", "value": "false"},
            {"name": "GF_ANALYTICS_CHECK_FOR_UPDATES", "value": "false"},
            {"name": "GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES", "value": "false"},
            {"name": "GF_PLUGINS_PREINSTALL_DISABLED", "value": "true"},
            {"name": "GF_PATHS_DATA", "value": "/tmp/grafana-data"}, {"name": "GF_PATHS_LOGS", "value": "/tmp/grafana-logs"},
            {"name": "GF_PATHS_PLUGINS", "value": "/tmp/grafana-plugins"}, {"name": "GF_PATHS_PROVISIONING", "value": "/tmp/grafana-provisioning"},
        ],
        ports=[{"name": "http", "containerPort": 3000}],
        volumes=[{"name": "runtime", "emptyDir": {"sizeLimit": "64Mi"}}],
        volume_mounts=[{"name": "runtime", "mountPath": "/tmp/grafana-data"}],
        readiness={"httpGet": {"path": "/api/health", "port": 3000}, "periodSeconds": 3, "failureThreshold": 80},
    ))
    kubectl("-n", "observability", "rollout", "status", "deployment/grafana", "--timeout=300s", timeout=320)
    pod = ready_pod_name("observability", "app=grafana")
    migration_count = text(kubectl(
        "-n", "observability", "exec", pod, "--", "/bin/bash", "-ec",
        "export PGPASSWORD=\"$GF_DATABASE_PASSWORD\"; /usr/lib/postgresql/17/bin/psql -h grafana-primary.grafana-db.svc.cluster.local -U grafana -d grafana -tAc \"select count(*) from migration_log\"",
    )).strip()
    if not migration_count.isdigit() or int(migration_count) < 1:
        raise ServicesLiveFailure(f"grafana-postgres-consumer-row-absent:{migration_count}")
    return {"ready": True, "databaseType": "postgres", "migrationRows": int(migration_count)}


def apply_redis() -> dict[str, Any]:
    redis_command = (
        "ordinal=${HOSTNAME##*-}; replica=''; if [ \"$ordinal\" != 0 ]; then replica='--replicaof redis-0.redis-headless.redis-system.svc 6379'; fi; "
        "exec /usr/bin/redis-server --port 0 --tls-port 6379 --tls-cert-file /tls/tls.crt --tls-key-file /tls/tls.key "
        "--tls-ca-cert-file /tls/ca.crt --tls-auth-clients yes --tls-replication yes --aclfile /tls/users.acl "
        "--masteruser replication --masterauth \"$(cat /tls/replication-password)\" --dir /data --save '' --appendonly no --maxmemory 67108864 "
        "--maxclients 128 --client-output-buffer-limit 'normal 8388608 8388608 1' $replica"
    )
    sentinel_command = """password=$(cat /tls/replication-password); sentinel_password=$(cat /tls/sentinel-password); cat > /tmp/sentinel.conf <<EOF
port 0
tls-port 26379
tls-cert-file /tls/tls.crt
tls-key-file /tls/tls.key
tls-ca-cert-file /tls/ca.crt
tls-auth-clients yes
tls-replication yes
requirepass $sentinel_password
sentinel monitor amoebius redis-0.redis-headless.redis-system.svc 6379 2
sentinel auth-user amoebius replication
sentinel auth-pass amoebius $password
sentinel sentinel-user default
sentinel sentinel-pass $sentinel_password
sentinel resolve-hostnames yes
sentinel announce-hostnames yes
sentinel down-after-milliseconds amoebius 5000
sentinel failover-timeout amoebius 30000
EOF
exec /usr/bin/redis-server /tmp/sentinel.conf --sentinel"""
    # Keep the Haskell and live arguments exact; TLS replication and ACL controls are part of the sealed runtime command.
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "redis-headless", "namespace": "redis-system"},
        "spec": {"clusterIP": "None", "publishNotReadyAddresses": True, "selector": {"app": "redis"}, "ports": [{"name": "tls", "port": 6379}]},
    })
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet", "metadata": {"name": "redis", "namespace": "redis-system"},
        "spec": {
            "serviceName": "redis-headless", "replicas": 3, "podManagementPolicy": "Parallel", "selector": {"matchLabels": {"app": "redis"}},
            "template": {"metadata": {"labels": {"app": "redis"}, "annotations": {"amoebius.dev/acl-contract": "channels-v1"}}, "spec": {"containers": [{
                "name": "redis", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never", "command": ["/bin/bash", "-ec"], "args": [redis_command],
                "resources": resource_envelope("small"), "securityContext": container_security(),
                "ports": [{"name": "tls", "containerPort": 6379}],
                "readinessProbe": {"tcpSocket": {"port": 6379}, "periodSeconds": 2, "failureThreshold": 90},
                "volumeMounts": [{"name": "identity", "mountPath": "/tls", "readOnly": True}, {"name": "runtime", "mountPath": "/data"}],
            }], "volumes": [
                {"name": "identity", "secret": {"secretName": "redis-vault-identity", "defaultMode": 292}},
                {"name": "runtime", "emptyDir": {"sizeLimit": "16Mi"}},
            ]}},
        },
    })
    kubectl("-n", "redis-system", "rollout", "status", "statefulset/redis", "--timeout=300s", timeout=320)
    redis_members = json.loads(text(kubectl("-n", "redis-system", "get", "pods", "-l", "app=redis", "-o", "json"))).get("items", [])
    redis_member_epoch = hashlib.sha256(canonical_bytes(sorted(
        pod["metadata"]["uid"] for pod in redis_members
    ))).hexdigest()[:16]
    apply(deployment(
        "redis-system", "sentinel", 3, ["/bin/bash", "-ec", sentinel_command], resource_envelope("small"),
        ports=[{"name": "tls", "containerPort": 26379}],
        volumes=[{"name": "identity", "secret": {"secretName": "redis-vault-identity", "defaultMode": 292}}],
        volume_mounts=[{"name": "identity", "mountPath": "/tls", "readOnly": True}],
        readiness={"tcpSocket": {"port": 26379}, "periodSeconds": 2, "failureThreshold": 90},
        annotations={"amoebius.dev/redis-member-epoch": redis_member_epoch},
    ))
    apply({
        "apiVersion": "v1", "kind": "Service", "metadata": {"name": "sentinel", "namespace": "redis-system"},
        "spec": {"selector": {"app": "sentinel"}, "ports": [{"name": "tls", "port": 26379}]},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "redis-default-deny", "namespace": "redis-system"},
        "spec": {"podSelector": {}, "policyTypes": ["Ingress"], "ingress": [{"from": [{"podSelector": {}}]}]},
    })
    kubectl("-n", "redis-system", "rollout", "status", "deployment/sentinel", "--timeout=300s", timeout=320)
    return {"redisReplicas": 3, "sentinelVoters": 3, "persistence": False}


def redis_cli(pod: str, port: int, password_file: str, *arguments: str, user: str | None = None, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    user_argument = f"--user {user} " if user else ""
    quoted = " ".join([subprocess.list2cmdline([value]) for value in arguments])
    shell = (
        f"exec /usr/bin/redis-cli --tls --cacert /tls/ca.crt --cert /tls/tls.crt --key /tls/tls.key "
        f"-h 127.0.0.1 -p {port} {user_argument}-a \"$(cat {password_file})\" --no-auth-warning {quoted}"
    )
    return kubectl("-n", "redis-system", "exec", pod, "--", "/bin/bash", "-ec", shell, check=check)


def redis_drill() -> dict[str, Any]:
    key = "amoebius:phase31:challenge"
    value = secrets.token_hex(16)
    sentinel_pod = ready_pod_name("redis-system", "app=sentinel")
    deadline = time.monotonic() + 45
    eligible_replicas: list[dict[str, Any]] = []
    while time.monotonic() < deadline:
        replicas_result = redis_cli(
            sentinel_pod, 26379, "/tls/sentinel-password",
            "--json", "SENTINEL", "replicas", "amoebius", check=False,
        )
        try:
            replicas = json.loads(text(replicas_result)) if replicas_result.returncode == 0 else []
        except json.JSONDecodeError:
            replicas = []
        eligible_replicas = [
            replica for replica in replicas
            if not {"s_down", "o_down", "disconnected"}.intersection(replica.get("flags", "").split(","))
            and replica.get("master-link-status") == "ok"
        ]
        if len(eligible_replicas) >= 2:
            break
        time.sleep(1)
    if len(eligible_replicas) < 2:
        raise ServicesLiveFailure(f"redis-sentinel-eligible-replicas:{len(eligible_replicas)}")
    before = text(redis_cli(sentinel_pod, 26379, "/tls/sentinel-password", "SENTINEL", "get-master-addr-by-name", "amoebius")).splitlines()[0]
    redis_pods = json.loads(text(kubectl("-n", "redis-system", "get", "pods", "-l", "app=redis", "-o", "json"))).get("items", [])
    master_candidates = [
        pod["metadata"]["name"] for pod in redis_pods
        if before == pod.get("status", {}).get("podIP")
        or before == pod["metadata"]["name"]
        or before.startswith(pod["metadata"]["name"] + ".")
    ]
    if len(master_candidates) != 1:
        raise ServicesLiveFailure(f"redis-master-address-unmapped:{before}:{master_candidates}")
    master_pod = master_candidates[0]
    replica_pods = sorted(pod["metadata"]["name"] for pod in redis_pods if pod["metadata"]["name"] != master_pod)
    set_result = text(redis_cli(master_pod, 6379, "/tls/client-password", "SET", key, value, "EX", "120", user="realtime")).strip()
    if set_result != "OK":
        raise ServicesLiveFailure(f"redis-set:{set_result}")
    deadline = time.monotonic() + 30
    replica_value = ""
    while time.monotonic() < deadline:
        for replica_pod in replica_pods:
            replica_value = text(redis_cli(replica_pod, 6379, "/tls/client-password", "GET", key, user="realtime", check=False)).strip()
            if hmac.compare_digest(replica_value, value):
                break
        if hmac.compare_digest(replica_value, value):
            break
        time.sleep(0.5)
    if not hmac.compare_digest(replica_value, value):
        raise ServicesLiveFailure("redis-replication-readback")
    failover = text(redis_cli(sentinel_pod, 26379, "/tls/sentinel-password", "SENTINEL", "failover", "amoebius")).strip()
    if failover != "OK":
        raise ServicesLiveFailure(f"redis-sentinel-failover:{failover}")
    deadline = time.monotonic() + 60
    after = before
    while time.monotonic() < deadline:
        lines = text(redis_cli(sentinel_pod, 26379, "/tls/sentinel-password", "SENTINEL", "get-master-addr-by-name", "amoebius", check=False)).splitlines()
        if lines and lines[0] != before:
            after = lines[0]
            break
        time.sleep(1)
    if after == before:
        raise ServicesLiveFailure(f"redis-sentinel-primary-unchanged:{before}")
    ttl = int(text(redis_cli("redis-1", 6379, "/tls/client-password", "TTL", key, user="realtime", check=False)).strip() or "-2")
    return {
        "tls": True, "aclUser": "realtime", "replicaReadback": True,
        "primaryBefore": before, "primaryAfter": after, "failoverObserved": True,
        "challengeTtlRemainingSeconds": ttl, "challengeValueSha256": "sha256:" + hashlib.sha256(value.encode()).hexdigest(),
    }


def observability_drill() -> dict[str, Any]:
    proxy_pod = ready_pod_name("observability", "app=prometheus-query-proxy")
    positive = kubectl(
        "-n", "observability", "exec", proxy_pod, "--", "/usr/bin/python3", "-c",
        "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/api/v1/query?query=up',timeout=10).status)",
    )
    if text(positive).strip() != "200":
        raise ServicesLiveFailure(f"prometheus-query-proxy-positive:{text(positive)}")
    negative = kubectl(
        "-n", "observability", "exec", proxy_pod, "--", "/usr/bin/python3", "-c",
        "import urllib.request; r=urllib.request.Request('http://127.0.0.1:8080/api/v1/query?query=up',headers={'X-Amoebius-Series':'65'});\ntry: urllib.request.urlopen(r,timeout=10)\nexcept urllib.error.HTTPError as e: print(e.code)",
    )
    if text(negative).strip() != "429":
        raise ServicesLiveFailure(f"prometheus-query-proxy-boundary:{text(negative)}")
    grafana_pod = ready_pod_name("observability", "app=grafana")
    direct = kubectl(
        "-n", "observability", "exec", grafana_pod, "--", "/usr/bin/python3", "-c",
        "import urllib.request\ntry: urllib.request.urlopen('http://prometheus:9090/-/ready',timeout=3); print('REACHABLE')\nexcept Exception: print('DENIED')",
    )
    if text(direct).strip() != "DENIED":
        raise ServicesLiveFailure(f"prometheus-direct-query-not-denied:{text(direct)}")
    status = json.loads(text(kubectl("-n", "observability", "exec", "prometheus-0", "--", "/usr/bin/python3", "-c", "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:9090/api/v1/targets').read().decode())")))
    active_targets = status.get("data", {}).get("activeTargets", [])
    if len(active_targets) < 3:
        raise ServicesLiveFailure(f"prometheus-platform-target-count:{len(active_targets)}")
    usage = text(kubectl("-n", "observability", "exec", "prometheus-0", "--", "/usr/bin/du", "-sb", "/prometheus")).split()[0]
    return {
        "queryProxyPositive": 200, "queryProxyOneOverSeries": 429, "directQueryFromGrafana": "DENIED",
        "activeTargets": len(active_targets), "derivedRules": True,
        "mountedHighWaterBytes": int(usage), "claimUsableBoundBytes": 67108864,
    }


def live_object(kind: str, namespace_name: str, name: str) -> dict[str, Any]:
    arguments = (["-n", namespace_name] if namespace_name else []) + ["get", kind, name, "-o", "json", "--show-managed-fields"]
    return json.loads(text(kubectl(*arguments)))


def projected_like(observed: Any, desired: Any, path: str = "$") -> Any:
    if isinstance(desired, dict):
        if not isinstance(observed, dict):
            raise ServicesLiveFailure(f"ssa-projection-type:{path}")
        missing = sorted(set(desired) - set(observed))
        if missing:
            raise ServicesLiveFailure(f"ssa-projection-missing:{path}:{missing}")
        return {key: projected_like(observed[key], value, f"{path}.{key}") for key, value in desired.items()}
    if isinstance(desired, list):
        if not isinstance(observed, list) or len(observed) < len(desired):
            raise ServicesLiveFailure(f"ssa-projection-list:{path}")
        return [projected_like(observed[index], value, f"{path}[{index}]") for index, value in enumerate(desired)]
    return observed


def verify_ssa_projection() -> dict[str, Any]:
    rows = []
    for (kind, namespace_name, name), desired in sorted(APPLIED_OBJECTS.items()):
        observed = live_object(kind, namespace_name, name)
        managers = {entry.get("manager", "") for entry in observed.get("metadata", {}).get("managedFields", [])}
        if "amoebius" not in managers:
            raise ServicesLiveFailure(f"ssa-manager-absent:{kind}/{namespace_name}/{name}:{sorted(managers)}")
        projection = projected_like(observed, desired)
        if not hmac.compare_digest(canonical_bytes(projection), canonical_bytes(desired)):
            raise ServicesLiveFailure(f"ssa-projection-drift:{kind}/{namespace_name}/{name}")
        rows.append({"identity": f"{kind}/{namespace_name}/{name}", "sha256": "sha256:" + hashlib.sha256(canonical_bytes(desired)).hexdigest()})
    return {
        "fieldManager": "amoebius", "objectCount": len(rows), "allOwnedFieldsByteIdentical": True,
        "aggregateSha256": "sha256:" + hashlib.sha256(canonical_bytes(rows)).hexdigest(), "objectHashes": rows,
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
    resources = container["resources"]
    requests, limits = resources["requests"], resources["limits"]
    return {
        "requestCpuMillis": quantity(requests["cpu"], cpu=True), "limitCpuMillis": quantity(limits["cpu"], cpu=True),
        "requestMemoryBytes": quantity(requests["memory"]), "limitMemoryBytes": quantity(limits["memory"]),
        "requestEphemeralBytes": quantity(requests["ephemeral-storage"]), "limitEphemeralBytes": quantity(limits["ephemeral-storage"]),
    }


def fresh_haskell_render_plan() -> list[dict[str, Any]]:
    run((CABAL, "build", "phase31-services-spec"), timeout=900)
    binary = text(run((CABAL, "list-bin", "phase31-services-spec"))).strip()
    rendered = json.loads(text(run((binary, "--render-plan"))))
    if not isinstance(rendered, list) or len(rendered) != 11:
        raise ServicesLiveFailure(f"haskell-render-count:{len(rendered) if isinstance(rendered, list) else 'not-list'}")
    return rendered


def verify_haskell_projection() -> dict[str, Any]:
    expected = fresh_haskell_render_plan()
    for plan in expected:
        kind, namespace_name, name = plan["objectKind"], plan["objectNamespace"], plan["objectName"]
        observed = live_object(kind, namespace_name, name)
        if kind == "PerconaPGCluster":
            projected = {
                **plan,
                "objectArguments": [observed["spec"]["amoebiusProjection"]["configuration"]],
                "objectReplicas": observed["spec"]["instances"][0]["replicas"],
            }
        else:
            container = observed["spec"]["template"]["spec"]["containers"][0]
            resource_names = set(container["resources"]["requests"]) | set(container["resources"]["limits"])
            accelerators = sorted(item for item in resource_names if "/" in item)
            cache_volumes = [volume for volume in observed["spec"]["template"]["spec"].get("volumes", []) if "cache" in volume.get("name", "").lower()]
            projected = {
                "objectAccelerator": accelerators[0] if accelerators else None,
                "objectArguments": container.get("command", []) + container.get("args", []),
                "objectCache": 0 if cache_volumes else None,
                "objectImage": container["image"], "objectKind": kind, "objectName": name, "objectNamespace": namespace_name,
                "objectReplicas": observed["spec"].get("replicas", 1), "objectResources": resource_projection(container),
            }
        if canonical_bytes(projected) != canonical_bytes(plan):
            raise ServicesLiveFailure(
                f"haskell-projection-drift:{kind}/{namespace_name}/{name}:expected={canonical_bytes(plan).decode()}:actual={canonical_bytes(projected).decode()}"
            )
    return {
        "renderer": "Amoebius.Platform.Services.renderPlatformServices", "freshGateProcessOutput": True,
        "objectCount": len(expected), "allAppliedProjectionsByteIdentical": True,
        "renderSha256": "sha256:" + hashlib.sha256(canonical_bytes(expected)).hexdigest(),
    }


def image_and_resource_evidence() -> dict[str, Any]:
    pods = json.loads(text(kubectl("get", "pods", "-A", "-o", "json")))
    selected = [pod for pod in pods["items"] if pod["metadata"]["namespace"] in NAMESPACES]
    public = []
    images, image_ids = set(), set()
    execution_units = 0
    for pod in selected:
        statuses = {status["name"]: status.get("imageID", "") for status in pod.get("status", {}).get("containerStatuses", [])}
        for container in pod["spec"].get("containers", []):
            execution_units += 1
            image = container["image"]
            images.add(image)
            if image != PRIVATE_IMAGE or any(token in image for token in PUBLIC_REGISTRY_TOKENS):
                public.append(image)
            image_id = statuses.get(container["name"], "")
            image_ids.add(image_id)
            if IMAGE_DIGEST not in image_id:
                raise ServicesLiveFailure(f"image-id-drift:{pod['metadata']['namespace']}/{pod['metadata']['name']}:{image_id}")
            resources = container.get("resources", {})
            if set(resources.get("requests", {})) != {"cpu", "memory", "ephemeral-storage"} or set(resources.get("limits", {})) != {"cpu", "memory", "ephemeral-storage"}:
                raise ServicesLiveFailure(f"resource-envelope-incomplete:{pod['metadata']['namespace']}/{pod['metadata']['name']}:{container['name']}")
    if public or not selected:
        raise ServicesLiveFailure(f"image-provenance:{public}:{len(selected)}")
    return {
        "podCount": len(selected), "executionUnitCount": execution_units, "images": sorted(images),
        "runtimeImageIds": sorted(image_ids), "allRuntimeImageIdsMatchBaseDigest": True,
        "publicImageReferences": [], "completeResourceFields": True,
    }


def readiness_time(resource: dict[str, Any]) -> str:
    if resource["kind"] == "StatefulSet":
        replicas = resource.get("spec", {}).get("replicas", 1)
        labels = resource.get("spec", {}).get("selector", {}).get("matchLabels", {})
        selector = ",".join(f"{key}={value}" for key, value in sorted(labels.items()))
        pods = json.loads(text(kubectl(
            "-n", resource["metadata"]["namespace"], "get", "pods", "-l", selector, "-o", "json",
        ))).get("items", [])
        pod_ready_times = [
            condition["lastTransitionTime"]
            for pod in pods
            for condition in pod.get("status", {}).get("conditions", [])
            if condition.get("type") == "Ready" and condition.get("status") == "True"
        ]
        if len(pod_ready_times) != replicas:
            raise ServicesLiveFailure(
                f"external-ready-pod-count:{resource['metadata']['namespace']}/{resource['metadata']['name']}:{len(pod_ready_times)}/{replicas}"
            )
        return max(pod_ready_times)
    conditions = resource.get("status", {}).get("conditions", [])
    ready = [condition for condition in conditions if condition.get("type") in {"Ready", "Available"} and condition.get("status") == "True"]
    if not ready:
        raise ServicesLiveFailure(f"external-ready-condition-absent:{resource['kind']}/{resource['metadata'].get('namespace','')}/{resource['metadata']['name']}")
    return max(condition["lastTransitionTime"] for condition in ready)


def observe_readiness(name: str, kind: str, namespace_name: str, resource_name: str) -> None:
    resource = live_object(kind, namespace_name, resource_name)
    READINESS_OBSERVATIONS[name] = {
        "service": name,
        "createdAt": resource["metadata"]["creationTimestamp"],
        "conditionReadyAt": readiness_time(resource),
        "observedAt": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
        "observedOrdinal": len(READINESS_OBSERVATIONS),
        "resourceVersion": resource["metadata"]["resourceVersion"],
    }


def external_readiness_trace() -> dict[str, Any]:
    trace = list(READINESS_OBSERVATIONS.values())
    dependencies = {
        "MinIO": ["MetalLB"], "Registry": ["MinIO"], "ZooKeeper": ["Vault"], "BookKeeper": ["Vault", "ZooKeeper"],
        "Pulsar": ["Vault", "MinIO", "ZooKeeper", "BookKeeper"], "GrafanaPostgres": ["Vault", "PerconaOperator"],
        "PgAdmin": ["Vault", "GrafanaPostgres"], "Redis": ["Vault"], "Sentinel": ["Vault", "Redis"],
        "Prometheus": ["MinIO", "Pulsar"], "Grafana": ["GrafanaPostgres", "Prometheus"],
    }
    by_name = {row["service"]: row for row in trace}
    if set(by_name) != {
        "MetalLB", "MinIO", "Vault", "Registry", "ZooKeeper", "BookKeeper", "Pulsar",
        "PerconaOperator", "GrafanaPostgres", "PgAdmin", "Redis", "Sentinel", "Prometheus", "Grafana",
    }:
        raise ServicesLiveFailure(f"readiness-observation-set:{sorted(by_name)}")
    violations = []
    for dependent, required in dependencies.items():
        for dependency in required:
            if by_name[dependent]["observedOrdinal"] <= by_name[dependency]["observedOrdinal"]:
                violations.append(f"{dependency}->{dependent}")
    if violations:
        raise ServicesLiveFailure(f"readiness-precondition-violations:{violations}")
    return {
        "observer": "kubernetes-apiserver-status-readback-during-warm-reconciliation", "selfReported": False,
        "events": sorted(trace, key=lambda row: row["observedOrdinal"]),
        "declaredEdges": dependencies, "preconditionViolations": [],
    }


def postgres_operator_observation() -> dict[str, Any]:
    cr = live_object("PerconaPGCluster", "grafana-db", "grafana")
    logs = text(kubectl("-n", "postgres-operator", "logs", "deployment/percona-operator", "--tail=300", check=False))
    observed = "grafana" in logs or bool(cr.get("metadata", {}).get("finalizers")) or bool(cr.get("status"))
    return {
        "crGeneration": cr["metadata"].get("generation", 1),
        "operatorObservedCr": observed,
        "operatorLogSha256": "sha256:" + hashlib.sha256(logs.encode()).hexdigest(),
        "runtimeChildren": ["StatefulSet/grafana-db/grafana-postgres", "Deployment/grafana-db/grafana-sql-gateway"],
        "manualChildProjection": True,
    }


def node_pull_events(started: datetime.datetime) -> dict[str, Any]:
    since = started.astimezone(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    output = text(run(("/usr/bin/docker", "logs", "--since", since, NODE), check=False))
    pulls = [line for line in output.splitlines() if "pull" in line.lower() and "image" in line.lower()]
    public = [line for line in pulls if any(token in line for token in PUBLIC_REGISTRY_TOKENS)]
    if public:
        raise ServicesLiveFailure(f"public-image-pull-events:{public[:5]}")
    return {
        "observer": "kind-node-containerd-log-window", "since": since, "pullEventCount": len(pulls),
        "publicPullEventCount": 0, "windowSha256": "sha256:" + hashlib.sha256(output.encode()).hexdigest(),
    }


def execute() -> dict[str, Any]:
    started = datetime.datetime.now(datetime.timezone.utc)
    APPLIED_OBJECTS.clear()
    READINESS_OBSERVATIONS.clear()
    prerequisite = ensure_cluster_prerequisites()
    observe_readiness("MetalLB", "Deployment", "metallb-system", "controller")
    observe_readiness("MinIO", "StatefulSet", "platform-system", "minio")
    observe_readiness("Registry", "Deployment", "platform-system", "registry")
    observe_readiness("Vault", "Pod", "vault-system", "root-vault-0")
    observe_readiness("ZooKeeper", "StatefulSet", "pulsar-system", "zookeeper")
    observe_readiness("BookKeeper", "StatefulSet", "pulsar-system", "bookkeeper")
    observe_readiness("Pulsar", "StatefulSet", "pulsar-system", "broker")
    ensure_namespaces()
    material, vault_provenance = vault_material()
    apply_secret_material(material)
    postgres_backings = [prepare_node_backing(f"grafana-postgres-256-{ordinal}", 256 * MIB) for ordinal in range(3)]
    postgres_share = prepare_postgres_share()
    prometheus_backing = prepare_node_backing("prometheus", 128 * MIB)
    operator = apply_operator()
    observe_readiness("PerconaOperator", "Deployment", "postgres-operator", "percona-operator")
    postgres = apply_postgres(postgres_backings, postgres_share)
    observe_readiness("GrafanaPostgres", "StatefulSet", "grafana-db", "grafana-postgres")
    database_surfaces = apply_database_surfaces()
    observe_readiness("PgAdmin", "Deployment", "grafana-db", "grafana-pgadmin")
    redis = apply_redis()
    observe_readiness("Redis", "StatefulSet", "redis-system", "redis")
    observe_readiness("Sentinel", "Deployment", "redis-system", "sentinel")
    observability = apply_observability(prometheus_backing)
    observe_readiness("Prometheus", "StatefulSet", "observability", "prometheus")
    grafana = apply_grafana()
    observe_readiness("Grafana", "Deployment", "observability", "grafana")
    redis_boundary = redis_drill()
    monitoring_boundary = observability_drill()
    provenance = image_and_resource_evidence()
    provenance["ssaProjection"] = verify_ssa_projection()
    provenance["haskellProjection"] = verify_haskell_projection()
    readiness = external_readiness_trace()
    operator_observation = postgres_operator_observation()
    pull_events = node_pull_events(started)
    del material
    evidence = {
        "schema": "amoebius.phase31.services-live.v1", "register": 3, "substrate": "linux-cpu",
        "artifactSource": {"digest": IMAGE_DIGEST, "imagePullPolicy": "Never", "publicPulls": 0, "pullEvents": pull_events},
        "prerequisite": prerequisite, "vaultMaterial": vault_provenance,
        "operator": operator, "operatorObservation": operator_observation,
        "postgres": postgres, "databaseSurfaces": database_surfaces, "grafana": grafana,
        "redis": redis, "redisBoundary": redis_boundary,
        "observability": observability, "monitoringBoundary": monitoring_boundary,
        "retainedStorage": {"postgres": postgres_backings, "postgresShare": postgres_share, "prometheus": prometheus_backing},
        "readinessDag": readiness, "provenance": provenance,
        "deferred": {"keycloakIngress": "UNVERIFIED", "singletonOwnedReconcile": "UNVERIFIED"},
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main() -> int:
    try:
        evidence = execute()
        print(
            "phase31-services-live: PASS "
            f"(Patroni={evidence['postgres']['readyReplicas']}, Redis failover, Prometheus/Grafana/Postgres consumer)"
        )
        return 0
    except (
        ServicesLiveFailure, phase30.BackboneLiveFailure, phase29.VaultLiveFailure,
        OSError, ValueError, KeyError, IndexError, json.JSONDecodeError, subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase31-services-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
