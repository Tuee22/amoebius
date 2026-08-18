#!/usr/bin/env python3
"""Exercise the Phase-32 Keycloak-owned edge on the retained linux-cpu cluster."""

from __future__ import annotations

import base64
import contextlib
import datetime
import hashlib
import http.client
import json
import os
import re
import secrets
import socket
import ssl
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any, Iterator, Sequence

import yaml

import phase29_vault_live as phase29
import phase30_backbone_live as phase30
import phase31_services_live as phase31


ROOT = Path(__file__).resolve().parents[1]
KUBECTL = phase30.KUBECTL
KUBECONFIG = phase30.KUBECONFIG
NODE = phase30.NODE
PRIVATE_IMAGE = phase30.PRIVATE_IMAGE
IMAGE_DIGEST = phase30.IMAGE_DIGEST
EDGE_NAMESPACE = "edge-system"
KEYCLOAK_DB_NAMESPACE = "keycloak-db"
EDGE_HOST = "phase32.amoebius.internal"
EDGE_VIP = "172.18.255.201"
EDGE_PORT = 443
HOST_LOCAL_NODE_PORT = 32033
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_32/keycloak-ingress-live.json"
PLATFORM_SERVICES_2_EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_31/services-live.json"
ROUTE_ORACLE = ROOT / "test/fixture/keycloak_ingress/route-inventory.golden"
REALM_FIXTURE = ROOT / "test/fixture/keycloak_ingress/realm.json"
BACKDOOR_SEED = ROOT / "test/fixture/keycloak_ingress/backdoor-seed.yaml"
MARKER_ROW = ROOT / "test/fixture/keycloak_ingress/marker-row.sql"
MARKER_OBJECT = ROOT / "test/fixture/keycloak_ingress/marker-object.bin"
POLICY_ORACLE = ROOT / "test/fixture/keycloak_ingress/netpol-expected.golden"
PUBLIC_REGISTRY_TOKENS = phase30.PUBLIC_REGISTRY_TOKENS
APPLIED_OBJECTS: dict[tuple[str, str, str], dict[str, Any]] = {}


class EdgeLiveFailure(RuntimeError):
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
        raise EdgeLiveFailure(
            f"{tuple(arguments)}:exit-{result.returncode}:"
            f"{result.stdout.decode(errors='replace')}"
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
    payload = input_bytes if input_bytes is not None else (
        input_value.encode() if input_value is not None else None
    )
    return run(
        (KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments),
        input_bytes=payload, check=check, timeout=timeout,
    )


def object_key(value: dict[str, Any]) -> tuple[str, str, str]:
    metadata = value["metadata"]
    return value["kind"], metadata.get("namespace", ""), metadata["name"]


def apply(value: dict[str, Any], *, retain: bool = True) -> None:
    desired = json.loads(json.dumps(value))
    desired.setdefault("metadata", {}).setdefault("labels", {})[
        "app.kubernetes.io/managed-by"
    ] = "amoebius"
    if desired.get("kind") == "Secret" and "stringData" in desired:
        desired["data"] = {
            key: base64.b64encode(raw.encode()).decode()
            for key, raw in desired.pop("stringData").items()
        }
    kubectl(
        "apply", "--server-side", "--field-manager=amoebius", "--force-conflicts",
        "-f", "-", input_value=json.dumps(desired), timeout=300,
    )
    if retain:
        APPLIED_OBJECTS[object_key(desired)] = desired


def namespace(name: str, **labels: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Namespace",
        "metadata": {"name": name, "labels": labels},
    }


def resources(size: str) -> dict[str, Any]:
    table = {
        "tiny": ("16Mi", "64Mi", "8Mi", "64Mi"),
        "small": ("32Mi", "128Mi", "16Mi", "128Mi"),
        "medium": ("128Mi", "512Mi", "32Mi", "256Mi"),
        "large": ("256Mi", "1Gi", "64Mi", "512Mi"),
    }
    memory_request, memory_limit, ephemeral_request, ephemeral_limit = table[size]
    return {
        "requests": {
            "cpu": "25m", "memory": memory_request,
            "ephemeral-storage": ephemeral_request,
        },
        "limits": {
            "cpu": "500m", "memory": memory_limit,
            "ephemeral-storage": ephemeral_limit,
        },
    }


def security_context(uid: int = 1000) -> dict[str, Any]:
    return {
        "allowPrivilegeEscalation": False,
        "capabilities": {"drop": ["ALL"]},
        "runAsNonRoot": True, "runAsUser": uid, "runAsGroup": uid,
        "seccompProfile": {"type": "RuntimeDefault"},
    }


def ensure_prerequisites() -> dict[str, Any]:
    phase30.ensure_cluster_image()
    if not PLATFORM_SERVICES_2_EVIDENCE.is_file():
        raise EdgeLiveFailure("platform-services-2-live-evidence-absent")
    phase31_live = json.loads(PLATFORM_SERVICES_2_EVIDENCE.read_text(encoding="utf-8"))
    if phase31_live.get("schema") != "amoebius.phase31.services-live.v1":
        raise EdgeLiveFailure("platform-services-2-live-evidence-schema")
    expected = {
        "MetalLB": ("metallb-system", "deployment/controller"),
        "MinIO": ("platform-system", "statefulset/minio"),
        "Vault": ("vault-system", "pod/root-vault-0"),
        "Patroni": ("grafana-db", "statefulset/grafana-postgres"),
        "Grafana": ("observability", "deployment/grafana"),
    }
    ready: dict[str, str] = {}
    for name, (ns, object_name) in expected.items():
        result = kubectl("-n", ns, "get", object_name, "-o", "json", check=False)
        if result.returncode:
            raise EdgeLiveFailure(f"platform-services-2-prerequisite-absent:{name}")
        ready[name] = "observed"
    if phase31_live.get("postgres", {}).get("readyReplicas") != 3:
        raise EdgeLiveFailure("platform-services-2-patroni-not-three-ready")
    return {
        "phase31ReceiptObserved": True, "services": ready,
        "patroniReplicas": 3,
    }


def vault_material() -> tuple[dict[str, str], dict[str, Any]]:
    root_token = phase31.open_vault_root_token()
    with phase29.port_forward():
        status, payload = phase29.api_request(
            "GET", "secret/data/phase32/keycloak-edge", root_token,
        )
        if status == 200:
            generated = json.loads(payload).get("data", {}).get("data", {})
        elif status == 404:
            generated = {}
        else:
            raise EdgeLiveFailure(f"vault-keycloak-ingress-kv-read:{status}")
        for key in (
            "keycloakDatabase", "keycloakPostgresSuperuser", "keycloakAdmin",
            "eabKid", "eabHmac",
        ):
            if not generated.get(key):
                generated[key] = secrets.token_urlsafe(32)
        if any(not generated.get(key) for key in ("tls.crt", "tls.key", "ca.crt", "certificateSerial")):
            issue = phase29.require_api(
                "POST", "pki/issue/internal", root_token,
                {
                    "common_name": EDGE_HOST,
                    "alt_names": EDGE_HOST,
                    "ttl": "2h",
                },
            )
            certificate = issue.get("data", {})
            required = ("certificate", "private_key", "issuing_ca", "serial_number")
            if any(not certificate.get(key) for key in required):
                raise EdgeLiveFailure("vault-keycloak-ingress-pki-material-incomplete")
            generated.update({
                "tls.crt": certificate["certificate"] + "\n"
                + "\n".join(certificate.get("ca_chain", [])) + "\n",
                "tls.key": certificate["private_key"],
                "ca.crt": certificate["issuing_ca"],
                "certificateSerial": certificate["serial_number"],
            })
        phase29.require_api(
            "POST", "secret/data/phase32/keycloak-edge", root_token,
            {"data": generated},
        )
        readback = phase29.require_api(
            "GET", "secret/data/phase32/keycloak-edge", root_token,
        )
    del root_token
    observed = readback.get("data", {}).get("data", {})
    if observed != generated:
        raise EdgeLiveFailure("vault-keycloak-ingress-readback-drift")
    material = dict(generated)
    provenance = {
        "kvPath": "secret/data/phase32/keycloak-edge",
        "kvVersion": readback.get("data", {}).get("metadata", {}).get("version"),
        "pkiPath": "pki/issue/internal",
        "certificateSerial": material["certificateSerial"],
        "certificateSha256": "sha256:" + hashlib.sha256(
            material["tls.crt"].encode()
        ).hexdigest(),
        "eabSecretRef": "vault:secret/phase32/keycloak-edge#eabKid,eabHmac",
        "vaultSourced": True,
        "literalRecorded": False,
    }
    del generated
    del observed
    return material, provenance


def apply_secret_material(material: dict[str, str]) -> None:
    apply({
        "apiVersion": "v1", "kind": "Secret",
        "metadata": {
            "name": "keycloak-ingress-edge-secrets", "namespace": EDGE_NAMESPACE,
            "annotations": {
                "amoebius.io/source-secret-ref":
                    "vault:secret/phase32/keycloak-edge",
            },
        },
        "type": "Opaque",
        "stringData": {
            "keycloak-database": material["keycloakDatabase"],
            "keycloak-admin": material["keycloakAdmin"],
            "tls.crt": material["tls.crt"], "tls.key": material["tls.key"],
            "ca.crt": material["ca.crt"],
            "eab-kid": material["eabKid"], "eab-hmac": material["eabHmac"],
        },
    })


def keycloak_patroni_config() -> str:
    return """scope: keycloak
name: placeholder
restapi:
  listen: 0.0.0.0:8008
  connect_address: 127.0.0.1:8008
kubernetes:
  namespace: keycloak-db
  use_endpoints: true
  labels:
    app: keycloak-postgres
    cluster-name: keycloak
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


def keycloak_persistent_volume(
    name: str, claim: str, backing: dict[str, Any], capacity: str,
) -> dict[str, Any]:
    value = phase31.persistent_volume(
        name, KEYCLOAK_DB_NAMESPACE, claim, backing, capacity,
    )
    value["metadata"]["labels"]["amoebius.io/owner"] = "phase32"
    return value


def apply_keycloak_database_network_policy() -> None:
    # A prior Phase-32 run may already have default-deny active.  Reconcile the
    # new per-consumer database edge before Keycloak is restarted against it.
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "allow-keycloak-to-patroni", "namespace": EDGE_NAMESPACE},
        "spec": {
            "podSelector": {"matchLabels": {"app": "keycloak"}},
            "policyTypes": ["Egress"],
            "egress": [{
                "to": [{
                    "namespaceSelector": {"matchLabels": {
                        "kubernetes.io/metadata.name": KEYCLOAK_DB_NAMESPACE,
                    }},
                    "podSelector": {"matchLabels": {"app": "keycloak-postgres"}},
                }],
                "ports": [{"protocol": "TCP", "port": 5432}],
            }],
        },
    })


def prepare_keycloak_database(
    password: str, superuser_password: str,
) -> dict[str, Any]:
    if not re.fullmatch(r"[A-Za-z0-9_-]+", password):
        raise EdgeLiveFailure("keycloak-database-password-alphabet")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", superuser_password):
        raise EdgeLiveFailure("keycloak-superuser-password-alphabet")
    apply(namespace(KEYCLOAK_DB_NAMESPACE, **{"amoebius.io/phase": "32"}))
    backings = [
        phase31.prepare_node_backing(
            f"keycloak-ingress-keycloak-postgres-256-{ordinal}", 256 * phase31.MIB,
        )
        for ordinal in range(3)
    ]
    postgres_share = phase31.prepare_postgres_share()
    apply({
        "apiVersion": "v1", "kind": "Secret",
        "metadata": {
            "name": "keycloak-postgres-credentials",
            "namespace": KEYCLOAK_DB_NAMESPACE,
            "annotations": {
                "amoebius.io/source-secret-ref":
                    "vault:secret/phase32/keycloak-edge",
            },
        },
        "type": "Opaque",
        "stringData": {
            "superuser": superuser_password, "keycloak": password,
        },
    })
    apply({
        "apiVersion": "v1", "kind": "ServiceAccount",
        "metadata": {"name": "patroni", "namespace": KEYCLOAK_DB_NAMESPACE},
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "Role",
        "metadata": {"name": "patroni", "namespace": KEYCLOAK_DB_NAMESPACE},
        "rules": [
            {
                "apiGroups": [""],
                "resources": ["pods", "configmaps", "endpoints", "services"],
                "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"],
            },
            {
                "apiGroups": [""], "resources": ["pods/status"],
                "verbs": ["get", "patch", "update"],
            },
        ],
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "RoleBinding",
        "metadata": {"name": "patroni", "namespace": KEYCLOAK_DB_NAMESPACE},
        "roleRef": {
            "apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": "patroni",
        },
        "subjects": [{
            "kind": "ServiceAccount", "name": "patroni",
            "namespace": KEYCLOAK_DB_NAMESPACE,
        }],
    })
    apply({
        "apiVersion": "v1", "kind": "ConfigMap",
        "metadata": {"name": "keycloak-patroni", "namespace": KEYCLOAK_DB_NAMESPACE},
        "data": {
            "patroni.yml": keycloak_patroni_config(),
            "mandated-sync.golden": phase31.PATRONI_ORACLE,
        },
    })
    apply({
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": "keycloak-postgres", "namespace": KEYCLOAK_DB_NAMESPACE},
        "spec": {
            "clusterIP": "None", "publishNotReadyAddresses": True,
            "selector": {"app": "keycloak-postgres"},
            "ports": [
                {"name": "postgres", "port": 5432},
                {"name": "patroni", "port": 8008},
            ],
        },
    })
    apply({
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": "keycloak-primary", "namespace": KEYCLOAK_DB_NAMESPACE},
        "spec": {
            "selector": {"app": "keycloak-postgres", "role": "primary"},
            "ports": [{"name": "postgres", "port": 5432}],
        },
    })
    apply({
        "apiVersion": "pgv2.percona.com/v2", "kind": "PerconaPGCluster",
        "metadata": {
            "name": "keycloak", "namespace": KEYCLOAK_DB_NAMESPACE,
            "annotations": {"pgv2.percona.com/custom-patroni-version": "4"},
        },
        "spec": {
            "crVersion": "2.6.0", "postgresVersion": 17,
            "pause": True, "unmanaged": True,
            "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
            "instances": [{
                "name": "instance1", "replicas": 3,
                "resources": phase31.resource_envelope("large"),
                "dataVolumeClaimSpec": {
                    "storageClassName": "amoebius-retained",
                    "accessModes": ["ReadWriteOnce"],
                    "resources": {"requests": {"storage": "256Mi"}},
                },
            }],
            "proxy": {"pgBouncer": {
                "replicas": 1, "image": PRIVATE_IMAGE,
                "resources": phase31.resource_envelope("small"),
            }},
            "backups": {"pgbackrest": {"image": PRIVATE_IMAGE, "repos": []}},
            "patroni": {"dynamicConfiguration": {
                "synchronous_mode": True, "synchronous_mode_strict": True,
                "maximum_lag_on_failover": 1048576,
            }},
            "amoebiusProjection": {
                "configuration": phase31.PATRONI_ORACLE,
                "storageBudgetId": "keycloak-postgres",
            },
        },
    })
    for ordinal, backing in enumerate(backings):
        apply(keycloak_persistent_volume(
            f"keycloak-db.keycloak-postgres-data.pv-{ordinal}",
            f"data-keycloak-postgres-{ordinal}", backing, "256Mi",
        ))
    apply(keycloak_persistent_volume(
        "keycloak-db.postgres-share.pv", "postgres-share",
        postgres_share, "32Mi",
    ))
    apply({
        "apiVersion": "v1", "kind": "PersistentVolumeClaim",
        "metadata": {"name": "postgres-share", "namespace": KEYCLOAK_DB_NAMESPACE},
        "spec": {
            "storageClassName": "amoebius-retained",
            "volumeName": "keycloak-db.postgres-share.pv",
            "accessModes": ["ReadWriteOnce"],
            "resources": {"requests": {"storage": "32Mi"}},
        },
    })
    command = [
        "/bin/bash", "-ec",
        "exec /usr/local/bin/patroni /etc/patroni/patroni.yml",
    ]
    apply({
        "apiVersion": "apps/v1", "kind": "StatefulSet",
        "metadata": {"name": "keycloak-postgres", "namespace": KEYCLOAK_DB_NAMESPACE},
        "spec": {
            "serviceName": "keycloak-postgres", "replicas": 3,
            "podManagementPolicy": "Parallel",
            "selector": {"matchLabels": {"app": "keycloak-postgres"}},
            "template": {
                "metadata": {"labels": {
                    "app": "keycloak-postgres", "cluster-name": "keycloak",
                }},
                "spec": {
                    "serviceAccountName": "patroni",
                    "securityContext": {
                        "fsGroup": 1000, "fsGroupChangePolicy": "OnRootMismatch",
                    },
                    "containers": [{
                        "name": "keycloak-postgres", "image": PRIVATE_IMAGE,
                        "imagePullPolicy": "Never", "command": command[:2],
                        "args": command[2:],
                        "resources": phase31.resource_envelope("large"),
                        "securityContext": phase31.container_security(),
                        "ports": [
                            {"name": "postgres", "containerPort": 5432},
                            {"name": "patroni", "containerPort": 8008},
                        ],
                        "env": [
                            {"name": "PATRONI_NAME", "valueFrom": {"fieldRef": {"fieldPath": "metadata.name"}}},
                            {"name": "PATRONI_KUBERNETES_POD_IP", "valueFrom": {"fieldRef": {"fieldPath": "status.podIP"}}},
                            {"name": "PATRONI_RESTAPI_CONNECT_ADDRESS", "value": "$(PATRONI_KUBERNETES_POD_IP):8008"},
                            {"name": "PATRONI_POSTGRESQL_CONNECT_ADDRESS", "value": "$(PATRONI_KUBERNETES_POD_IP):5432"},
                            {"name": "PATRONI_SUPERUSER_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "keycloak-postgres-credentials", "key": "superuser"}}},
                            {"name": "PATRONI_REPLICATION_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "keycloak-postgres-credentials", "key": "superuser"}}},
                            {"name": "PATRONI_REWIND_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "keycloak-postgres-credentials", "key": "superuser"}}},
                        ],
                        "readinessProbe": {
                            "httpGet": {"path": "/readiness", "port": 8008},
                            "periodSeconds": 2, "failureThreshold": 90,
                        },
                        "livenessProbe": {
                            "httpGet": {"path": "/liveness", "port": 8008},
                            "periodSeconds": 10, "failureThreshold": 12,
                        },
                        "volumeMounts": [
                            {"name": "config", "mountPath": "/etc/patroni", "readOnly": True},
                            {"name": "credentials", "mountPath": "/keycloak-ingress-secrets", "readOnly": True},
                            {"name": "postgres-share", "mountPath": "/usr/share/postgresql/17", "readOnly": True},
                            {"name": "data", "mountPath": "/pgdata"},
                        ],
                    }],
                    "volumes": [
                        {"name": "config", "configMap": {"name": "keycloak-patroni"}},
                        {"name": "credentials", "secret": {"secretName": "keycloak-postgres-credentials"}},
                        {"name": "postgres-share", "persistentVolumeClaim": {"claimName": "postgres-share", "readOnly": True}},
                    ],
                },
            },
            "volumeClaimTemplates": [{
                "metadata": {"name": "data"},
                "spec": {
                    "storageClassName": "amoebius-retained",
                    "accessModes": ["ReadWriteOnce"],
                    "resources": {"requests": {"storage": "256Mi"}},
                },
            }],
        },
    })
    kubectl(
        "-n", KEYCLOAK_DB_NAMESPACE, "rollout", "status",
        "statefulset/keycloak-postgres", "--timeout=480s", timeout=500,
    )
    primary = phase31.ready_pod_name(
        KEYCLOAK_DB_NAMESPACE, "app=keycloak-postgres,role=primary",
    )
    program = r'''set -eu
IFS= read -r KC_DATABASE_PASSWORD
export PGPASSWORD="$(cat /keycloak-ingress-secrets/superuser)"
if ! /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -tAc "select 1 from pg_roles where rolname='keycloak'" | grep -qx 1; then
  /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 -c "create role keycloak login password '${KC_DATABASE_PASSWORD}'"
else
  /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 -c "alter role keycloak password '${KC_DATABASE_PASSWORD}'"
fi
if ! /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -tAc "select 1 from pg_database where datname='keycloak'" | grep -qx 1; then
  /usr/lib/postgresql/17/bin/createdb -h 127.0.0.1 -U postgres -O keycloak keycloak
fi
'''
    kubectl(
        "-n", KEYCLOAK_DB_NAMESPACE, "exec", "-i", primary, "--",
        "/bin/bash", "-ec", program, input_bytes=password.encode() + b"\n",
    )
    verification = kubectl(
        "-n", KEYCLOAK_DB_NAMESPACE, "exec", primary, "--", "/bin/bash", "-ec",
        "export PGPASSWORD=\"$(cat /keycloak-ingress-secrets/superuser)\"; "
        "/usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d keycloak "
        "-Atqc \"select current_database() || ':' || pg_is_in_recovery()\"",
    )
    observed = text(verification).strip()
    if observed != "keycloak:false":
        raise EdgeLiveFailure(f"keycloak-database-verification:{observed}")
    apply_keycloak_database_network_policy()
    return {
        "database": "keycloak", "role": "keycloak", "primary": primary,
        "namespace": KEYCLOAK_DB_NAMESPACE,
        "backingPatroniCluster": "keycloak", "readyReplicas": 3,
        "strictSynchronous": True, "maximumLagOnFailoverBytes": 1048576,
        "dedicatedPerConsumerCluster": True,
        "perconaCrObserved": True, "manualChildProjection": True,
    }


def generic_crd(
    name: str, group: str, kind: str, plural: str, *, namespaced: bool,
) -> dict[str, Any]:
    singular = plural[:-1] if plural.endswith("s") else plural
    return {
        "apiVersion": "apiextensions.k8s.io/v1",
        "kind": "CustomResourceDefinition", "metadata": {
            "name": name,
            "annotations": {
                "api-approved.kubernetes.io": "https://github.com/kubernetes-sigs/gateway-api",
            },
        },
        "spec": {
            "group": group, "scope": "Namespaced" if namespaced else "Cluster",
            "names": {"plural": plural, "singular": singular, "kind": kind},
            "versions": [{
                "name": "v1", "served": True, "storage": True,
                "schema": {"openAPIV3Schema": {
                    "type": "object", "x-kubernetes-preserve-unknown-fields": True,
                }},
                "subresources": {"status": {}},
            }],
        },
    }


def gateway_crd_version(
    name: str, kind: str, plural: str, version: str,
) -> dict[str, Any]:
    return {
        "apiVersion": "apiextensions.k8s.io/v1",
        "kind": "CustomResourceDefinition",
        "metadata": {
            "name": name,
            "annotations": {
                "api-approved.kubernetes.io": "https://github.com/kubernetes-sigs/gateway-api",
            },
        },
        "spec": {
            "group": "gateway.networking.k8s.io", "scope": "Namespaced",
            "names": {"plural": plural, "singular": plural[:-1], "kind": kind},
            "versions": [{
                "name": version, "served": True, "storage": True,
                "schema": {"openAPIV3Schema": {
                    "type": "object", "x-kubernetes-preserve-unknown-fields": True,
                }},
                "subresources": {"status": {}},
            }],
        },
    }


def apply_gateway_api_projection() -> dict[str, Any]:
    crds = (
        generic_crd(
            "gatewayclasses.gateway.networking.k8s.io",
            "gateway.networking.k8s.io", "GatewayClass", "gatewayclasses",
            namespaced=False,
        ),
        generic_crd(
            "gateways.gateway.networking.k8s.io",
            "gateway.networking.k8s.io", "Gateway", "gateways",
            namespaced=True,
        ),
        generic_crd(
            "httproutes.gateway.networking.k8s.io",
            "gateway.networking.k8s.io", "HTTPRoute", "httproutes",
            namespaced=True,
        ),
        gateway_crd_version(
            "referencegrants.gateway.networking.k8s.io",
            "ReferenceGrant", "referencegrants", "v1beta1",
        ),
        gateway_crd_version(
            "backendtlspolicies.gateway.networking.k8s.io",
            "BackendTLSPolicy", "backendtlspolicies", "v1alpha3",
        ),
    )
    for crd in crds:
        apply(crd)
    apply({
        "apiVersion": "gateway.networking.k8s.io/v1", "kind": "GatewayClass",
        "metadata": {"name": "amoebius-envoy"},
        "spec": {"controllerName": "amoebius.io/manual-envoy-projection"},
    })
    apply({
        "apiVersion": "gateway.networking.k8s.io/v1", "kind": "Gateway",
        "metadata": {"name": "keycloak-edge", "namespace": EDGE_NAMESPACE},
        "spec": {
            "gatewayClassName": "amoebius-envoy",
            "listeners": [{
                "name": "https", "protocol": "HTTPS", "port": 443,
                "hostname": EDGE_HOST,
                "tls": {
                    "mode": "Terminate",
                    "certificateRefs": [{"kind": "Secret", "name": "keycloak-ingress-edge-secrets"}],
                },
                "allowedRoutes": {"namespaces": {"from": "Same"}},
            }],
        },
    })
    paths = [
        line.split("|", 1)[1] for line in ROUTE_ORACLE.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    apply({
        "apiVersion": "gateway.networking.k8s.io/v1", "kind": "HTTPRoute",
        "metadata": {
            "name": "keycloak-owned-routes", "namespace": EDGE_NAMESPACE,
            "annotations": {
                "amoebius.io/auth-owner": "Keycloak",
                "amoebius.io/data-plane-projection": "static-envoy-v1",
            },
        },
        "spec": {
            "parentRefs": [{"name": "keycloak-edge"}],
            "hostnames": [EDGE_HOST],
            "rules": [{
                "matches": [{"path": {"type": "PathPrefix", "value": path}}],
                "backendRefs": [{"name": "envoy", "port": 8443}],
            } for path in paths],
        },
    })
    observed = json.loads(text(kubectl(
        "-n", EDGE_NAMESPACE, "get", "httproute", "keycloak-owned-routes",
        "-o", "json",
    )))
    observed_paths = [
        rule["matches"][0]["path"]["value"]
        for rule in observed.get("spec", {}).get("rules", [])
    ]
    if observed_paths != paths:
        raise EdgeLiveFailure("gateway-api-route-projection-drift")
    return {
        "apiVersion": "gateway.networking.k8s.io/v1", "gateway": "keycloak-edge",
        "httpRoute": "keycloak-owned-routes", "routes": observed_paths,
        "controller": "Envoy Gateway v1.4.2 binary provenance",
        "manualDataPlaneProjection": True,
        "reason": "the baked Envoy data plane is reconciled from the typed Gateway/HTTPRoute without a public controller image",
    }


def apply_envoy_gateway_controller() -> dict[str, Any]:
    apply(namespace("envoy-gateway-system", **{"amoebius.io/phase": "32"}))
    apply({
        "apiVersion": "v1", "kind": "ServiceAccount",
        "metadata": {"name": "envoy-gateway", "namespace": EDGE_NAMESPACE},
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRole",
        "metadata": {"name": "keycloak-ingress-envoy-gateway-observer"},
        "rules": [{
            "apiGroups": ["*"], "resources": ["*"],
            "verbs": ["get", "list", "watch", "create", "update", "patch", "delete", "deletecollection"],
        }],
    })
    apply({
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding",
        "metadata": {"name": "keycloak-ingress-envoy-gateway-observer"},
        "roleRef": {
            "apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole",
            "name": "keycloak-ingress-envoy-gateway-observer",
        },
        "subjects": [{
            "kind": "ServiceAccount", "name": "envoy-gateway",
            "namespace": EDGE_NAMESPACE,
        }],
    })
    existing_hmac = kubectl(
        "-n", "envoy-gateway-system", "get", "secret", "envoy-oidc-hmac",
        check=False,
    )
    if existing_hmac.returncode:
        apply({
            "apiVersion": "v1", "kind": "Secret",
            "metadata": {"name": "envoy-oidc-hmac", "namespace": "envoy-gateway-system"},
            "type": "Opaque", "stringData": {"hmac-secret": secrets.token_urlsafe(32)},
        })
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": "envoy-gateway", "namespace": EDGE_NAMESPACE},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": "envoy-gateway"}},
            "template": {
                "metadata": {"labels": {"app": "envoy-gateway", "role": "gateway-controller"}},
                "spec": {
                    "serviceAccountName": "envoy-gateway",
                    "securityContext": {"fsGroup": 1000, "fsGroupChangePolicy": "OnRootMismatch"},
                    "containers": [{
                        "name": "envoy-gateway", "image": PRIVATE_IMAGE,
                        "imagePullPolicy": "Never", "command": ["/usr/bin/envoy-gateway"],
                        "args": ["server"], "resources": resources("small"),
                        "securityContext": security_context(),
                        "ports": [{"name": "metrics", "containerPort": 19001}],
                        "volumeMounts": [
                            {"name": "xds-certs", "mountPath": "/certs", "readOnly": True},
                            {"name": "wasm-cache", "mountPath": "/var/lib/eg"},
                        ],
                    }],
                    "volumes": [
                        {"name": "xds-certs", "secret": {"secretName": "keycloak-ingress-edge-secrets"}},
                        {"name": "wasm-cache", "emptyDir": {"sizeLimit": "32Mi"}},
                    ],
                },
            },
        },
    })
    kubectl("-n", EDGE_NAMESPACE, "rollout", "restart", "deployment/envoy-gateway")
    kubectl(
        "-n", EDGE_NAMESPACE, "rollout", "status", "deployment/envoy-gateway",
        "--timeout=180s", timeout=200,
    )
    time.sleep(3)
    newest = phase31.ready_pod_name(EDGE_NAMESPACE, "app=envoy-gateway")
    startup_logs = text(kubectl(
        "-n", EDGE_NAMESPACE, "logs", newest, "--tail=160",
        check=False,
    ))
    if "Failed to start runner" in startup_logs or "failed to start runners" in startup_logs:
        raise EdgeLiveFailure(f"envoy-gateway-runner-failed:{startup_logs}")
    if "created gatewayapi controller" not in startup_logs:
        raise EdgeLiveFailure(f"envoy-gateway-controller-start-not-observed:{startup_logs}")
    return {
        "binary": "/usr/bin/envoy-gateway", "version": "v1.4.2",
        "ready": True, "runnerStarted": True,
    }


def route_probe_program() -> str:
    return r'''import base64
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NONCES = set()
ORIGIN = "https://phase32.amoebius.internal"
SUBPROTOCOL = "amoebius.v1"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(json.dumps({"client": self.client_address[0], "path": self.path, "status": args[1]}), flush=True)

    def do_GET(self):
        if self.path.startswith("/platform/"):
            body = b'{"surface":"platform-api","phase":32}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if not self.path.startswith("/ws"):
            self.send_error(404)
            return
        if self.headers.get("Upgrade", "").lower() != "websocket":
            self.send_error(426)
            return
        if self.headers.get("Origin") != ORIGIN:
            self.send_error(403)
            return
        if self.headers.get("Sec-WebSocket-Protocol") != SUBPROTOCOL:
            self.send_error(426)
            return
        nonce = self.headers.get("X-Amoebius-Nonce", "")
        if not nonce or nonce in NONCES:
            self.send_error(409)
            return
        key = self.headers.get("Sec-WebSocket-Key", "")
        if not key:
            self.send_error(400)
            return
        NONCES.add(nonce)
        accept = base64.b64encode(hashlib.sha1(
            (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
        ).digest()).decode()
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.send_header("Sec-WebSocket-Protocol", SUBPROTOCOL)
        self.end_headers()
        challenge = b"keycloak-ingress-challenge"
        self.wfile.write(bytes([0x81, len(challenge)]) + challenge)
        self.wfile.flush()

ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
'''


def apply_route_probe() -> None:
    apply({
        "apiVersion": "v1", "kind": "ConfigMap",
        "metadata": {"name": "keycloak-ingress-route-probe", "namespace": EDGE_NAMESPACE},
        "data": {"server.py": route_probe_program()},
    })
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": "keycloak-ingress-route-probe", "namespace": EDGE_NAMESPACE},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": "keycloak-ingress-route-probe"}},
            "template": {
                "metadata": {"labels": {"app": "keycloak-ingress-route-probe", "surface": "platform-api-websocket"}},
                "spec": {"containers": [{
                    "name": "probe", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/usr/bin/python3", "/app/server.py"],
                    "resources": resources("small"), "securityContext": security_context(),
                    "ports": [{"name": "http", "containerPort": 8080}],
                    "readinessProbe": {"tcpSocket": {"port": 8080}, "periodSeconds": 1, "failureThreshold": 60},
                    "volumeMounts": [{"name": "program", "mountPath": "/app", "readOnly": True}],
                }], "volumes": [{"name": "program", "configMap": {"name": "keycloak-ingress-route-probe"}}]},
            },
        },
    })
    apply({
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": "keycloak-ingress-route-probe", "namespace": EDGE_NAMESPACE},
        "spec": {
            "type": "ClusterIP", "selector": {"app": "keycloak-ingress-route-probe"},
            "ports": [{"name": "http", "port": 8080, "targetPort": 8080}],
        },
    })
    kubectl(
        "-n", EDGE_NAMESPACE, "rollout", "status", "deployment/keycloak-ingress-route-probe",
        "--timeout=180s", timeout=200,
    )


def apply_grafana_edge_service() -> None:
    apply({
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": "grafana", "namespace": "observability"},
        "spec": {
            "type": "ClusterIP", "selector": {"app": "grafana"},
            "ports": [{"name": "http", "port": 3000, "targetPort": 3000}],
        },
    })


def apply_keycloak() -> dict[str, Any]:
    realm = REALM_FIXTURE.read_text(encoding="utf-8")
    parsed = json.loads(realm)
    if parsed.get("realm") != "amoebius":
        raise EdgeLiveFailure("keycloak-realm-fixture-drift")
    apply({
        "apiVersion": "v1", "kind": "ConfigMap",
        "metadata": {"name": "keycloak-ingress-keycloak-realm", "namespace": EDGE_NAMESPACE},
        "data": {"amoebius-realm.json": realm},
    })
    apply({
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": "keycloak", "namespace": EDGE_NAMESPACE},
        "spec": {
            "type": "ClusterIP", "selector": {"app": "keycloak"},
            "ports": [{"name": "http", "port": 8080, "targetPort": 8080}],
        },
    })
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": "keycloak", "namespace": EDGE_NAMESPACE},
        "spec": {
            "replicas": 1,
            "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": "keycloak"}},
            "template": {
                "metadata": {"labels": {"app": "keycloak", "auth-owner": "wild-ingress"}},
                "spec": {
                    "securityContext": {"fsGroup": 1000, "fsGroupChangePolicy": "OnRootMismatch"},
                    "containers": [{
                        "name": "keycloak", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                        "command": ["/opt/keycloak/bin/kc.sh"],
                        "args": [
                            "start-dev", "--import-realm", "--http-port=8080",
                            "--http-relative-path=/keycloak", "--health-enabled=true",
                        ],
                        "env": [
                            {"name": "KC_DB", "value": "postgres"},
                            {"name": "KC_DB_URL", "value": "jdbc:postgresql://keycloak-primary.keycloak-db.svc.cluster.local:5432/keycloak"},
                            {"name": "KC_DB_USERNAME", "value": "keycloak"},
                            {"name": "KC_DB_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "keycloak-ingress-edge-secrets", "key": "keycloak-database"}}},
                            {"name": "KC_BOOTSTRAP_ADMIN_USERNAME", "value": "keycloak-ingress-admin"},
                            {"name": "KC_BOOTSTRAP_ADMIN_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "keycloak-ingress-edge-secrets", "key": "keycloak-admin"}}},
                            {"name": "KC_HOSTNAME", "value": f"https://{EDGE_HOST}/keycloak"},
                            {"name": "KC_HOSTNAME_STRICT", "value": "true"},
                            {"name": "KC_PROXY_HEADERS", "value": "xforwarded"},
                            {"name": "JAVA_OPTS_KC_HEAP", "value": "-Xms128m -Xmx640m"},
                        ],
                        "resources": resources("large"), "securityContext": security_context(),
                        "ports": [{"name": "http", "containerPort": 8080}],
                        "readinessProbe": {"tcpSocket": {"port": 8080}, "periodSeconds": 2, "failureThreshold": 120},
                        "livenessProbe": {"tcpSocket": {"port": 8080}, "periodSeconds": 10, "failureThreshold": 18},
                        "volumeMounts": [{"name": "realm", "mountPath": "/opt/keycloak/data/import", "readOnly": True}],
                    }],
                    "volumes": [{"name": "realm", "configMap": {"name": "keycloak-ingress-keycloak-realm"}}],
                },
            },
        },
    })
    kubectl(
        "-n", EDGE_NAMESPACE, "rollout", "status", "deployment/keycloak",
        "--timeout=480s", timeout=500,
    )
    pod = phase31.ready_pod_name(EDGE_NAMESPACE, "app=keycloak")
    status = kubectl(
        "-n", EDGE_NAMESPACE, "exec", pod, "--", "/usr/bin/python3", "-c",
        "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/keycloak/realms/amoebius/.well-known/openid-configuration', timeout=10).status)",
    )
    if text(status).strip() != "200":
        raise EdgeLiveFailure("keycloak-oidc-discovery-not-ready")
    update_user = r'''set -eu
/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://127.0.0.1:8080/keycloak --realm master \
  --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" >/dev/null
USER_ID="$(/opt/keycloak/bin/kcadm.sh get users -r amoebius -q username=keycloak-ingress-tester --fields id --format csv --noquotes | head -n 1)"
test -n "$USER_ID"
/opt/keycloak/bin/kcadm.sh update "users/${USER_ID}" -r amoebius \
  -s firstName=Phase32 -s lastName=Tester \
  -s email=keycloak-ingress-tester@amoebius.invalid -s emailVerified=true \
  -s 'requiredActions=[]' >/dev/null
'''
    kubectl("-n", EDGE_NAMESPACE, "exec", pod, "--", "/bin/bash", "-ec", update_user)
    return {
        "ready": True, "realm": "amoebius", "fixture": str(REALM_FIXTURE.relative_to(ROOT)),
        "database": "dedicated Phase-32 three-member strict-sync Patroni",
        "wildIngressOwner": True,
    }


def envoy_config() -> str:
    return f'''static_resources:
  listeners:
  - name: keycloak_owned_https
    address:
      socket_address: {{address: 0.0.0.0, port_value: 8443}}
    filter_chains:
    - transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
          common_tls_context:
            tls_certificates:
            - certificate_chain: {{filename: /tls/tls.crt}}
              private_key: {{filename: /tls/tls.key}}
      filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: phase32_edge
          upgrade_configs:
          - upgrade_type: websocket
          route_config:
            name: keycloak_owned_routes
            virtual_hosts:
            - name: phase32
              domains: ["{EDGE_HOST}", "{EDGE_HOST}:*"]
              routes:
              - match: {{prefix: "/keycloak/realms/"}}
                route: {{cluster: keycloak, timeout: 30s}}
              - match: {{path: "/keycloak/"}}
                route: {{cluster: keycloak, prefix_rewrite: "/keycloak/admin/master/console/", timeout: 30s}}
              - match: {{prefix: "/grafana/"}}
                route: {{cluster: grafana, prefix_rewrite: "/api/health", timeout: 30s}}
              - match: {{prefix: "/vault/"}}
                route: {{cluster: vault, prefix_rewrite: "/v1/sys/health", timeout: 30s}}
              - match: {{prefix: "/minio/"}}
                route: {{cluster: minio, prefix_rewrite: "/minio/health/ready", timeout: 30s}}
              - match: {{prefix: "/platform/"}}
                route: {{cluster: route_probe, timeout: 30s}}
              - match: {{prefix: "/ws"}}
                route: {{cluster: route_probe, timeout: 30s}}
          http_filters:
          - name: envoy.filters.http.jwt_authn
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
              providers:
                keycloak:
                  issuer: "https://{EDGE_HOST}/keycloak/realms/amoebius"
                  forward: true
                  remote_jwks:
                    http_uri:
                      uri: http://keycloak.{EDGE_NAMESPACE}.svc.cluster.local:8080/keycloak/realms/amoebius/protocol/openid-connect/certs
                      cluster: keycloak_jwks
                      timeout: 10s
                    cache_duration: 300s
              rules:
              - match: {{prefix: "/keycloak/"}}
              - match: {{prefix: "/"}}
                requires: {{provider_name: keycloak}}
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
  - name: keycloak
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: keycloak
      endpoints: [{{lb_endpoints: [{{endpoint: {{address: {{socket_address: {{address: keycloak.{EDGE_NAMESPACE}.svc.cluster.local, port_value: 8080}}}}}}}}]}}]
  - name: keycloak_jwks
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: keycloak_jwks
      endpoints: [{{lb_endpoints: [{{endpoint: {{address: {{socket_address: {{address: keycloak.{EDGE_NAMESPACE}.svc.cluster.local, port_value: 8080}}}}}}}}]}}]
  - name: grafana
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: grafana
      endpoints: [{{lb_endpoints: [{{endpoint: {{address: {{socket_address: {{address: grafana.observability.svc.cluster.local, port_value: 3000}}}}}}}}]}}]
  - name: vault
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: vault
      endpoints: [{{lb_endpoints: [{{endpoint: {{address: {{socket_address: {{address: root-vault.vault-system.svc.cluster.local, port_value: 8200}}}}}}}}]}}]
  - name: minio
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: minio
      endpoints: [{{lb_endpoints: [{{endpoint: {{address: {{socket_address: {{address: minio.platform-system.svc.cluster.local, port_value: 9000}}}}}}}}]}}]
  - name: route_probe
    connect_timeout: 5s
    type: STRICT_DNS
    load_assignment:
      cluster_name: route_probe
      endpoints: [{{lb_endpoints: [{{endpoint: {{address: {{socket_address: {{address: keycloak-ingress-route-probe.{EDGE_NAMESPACE}.svc.cluster.local, port_value: 8080}}}}}}}}]}}]
admin:
  address:
    socket_address: {{address: 0.0.0.0, port_value: 9901}}
'''


def edge_service(load_balancer: bool) -> dict[str, Any]:
    spec: dict[str, Any] = {
        "type": "LoadBalancer" if load_balancer else "ClusterIP",
        "selector": {"app": "envoy"},
        "ports": [{"name": "https", "port": EDGE_PORT, "targetPort": 8443}],
    }
    return {
        "apiVersion": "v1", "kind": "Service",
        "metadata": {
            "name": "envoy", "namespace": EDGE_NAMESPACE,
            "annotations": {"metallb.universe.tf/loadBalancerIPs": EDGE_VIP},
        },
        "spec": spec,
    }


def apply_envoy(*, load_balancer: bool) -> None:
    config = envoy_config()
    yaml.safe_load(config)
    apply({
        "apiVersion": "v1", "kind": "ConfigMap",
        "metadata": {"name": "keycloak-ingress-envoy", "namespace": EDGE_NAMESPACE},
        "data": {"envoy.yaml": config},
    })
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": "envoy", "namespace": EDGE_NAMESPACE},
        "spec": {
            "replicas": 2,
            "strategy": {"type": "RollingUpdate", "rollingUpdate": {"maxUnavailable": 1, "maxSurge": 1}},
            "selector": {"matchLabels": {"app": "envoy"}},
            "template": {
                "metadata": {"labels": {"app": "envoy", "wild-ingress": "keycloak-owned"}},
                "spec": {"containers": [{
                    "name": "envoy", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/usr/bin/envoy"], "args": ["-c", "/etc/envoy/envoy.yaml", "--log-level", "warning"],
                    "resources": resources("medium"), "securityContext": security_context(),
                    "ports": [{"name": "https", "containerPort": 8443}, {"name": "admin", "containerPort": 9901}],
                    "readinessProbe": {"httpGet": {"path": "/ready", "port": 9901}, "periodSeconds": 1, "failureThreshold": 120},
                    "livenessProbe": {"httpGet": {"path": "/ready", "port": 9901}, "periodSeconds": 10, "failureThreshold": 18},
                    "volumeMounts": [
                        {"name": "config", "mountPath": "/etc/envoy", "readOnly": True},
                        {"name": "tls", "mountPath": "/tls", "readOnly": True},
                    ],
                }], "volumes": [
                    {"name": "config", "configMap": {"name": "keycloak-ingress-envoy"}},
                    {"name": "tls", "secret": {"secretName": "keycloak-ingress-edge-secrets"}},
                ]},
            },
        },
    })
    apply(edge_service(load_balancer))
    kubectl(
        "-n", EDGE_NAMESPACE, "rollout", "status", "deployment/envoy",
        "--timeout=240s", timeout=260,
    )


def apply_acme_recording_job() -> dict[str, Any]:
    job_name = "keycloak-ingress-acme-provenance"
    kubectl(
        "-n", EDGE_NAMESPACE, "delete", "job", job_name,
        "--ignore-not-found=true", "--wait=true", "--timeout=120s",
        timeout=140,
    )
    program = r'''import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--eab-secret-ref", required=True)
args = parser.parse_args()
kid = Path("/vault-material/eab-kid").read_text().strip()
hmac = Path("/vault-material/eab-hmac").read_text().strip()
if not kid or not hmac:
    raise SystemExit("EAB material absent")
print(json.dumps({
    "argv": ["acme-recording-shim", "--eab-secret-ref", args.eab_secret_ref],
    "environmentKeys": ["EAB_KID_FILE", "EAB_HMAC_FILE"],
    "valueTransport": "Kubernetes Secret volume projected from Vault readback",
    "eabMaterialPresent": True,
    "eabValuesRecorded": False,
    "stagingStandIn": True,
}, sort_keys=True))
'''
    apply({
        "apiVersion": "v1", "kind": "ConfigMap",
        "metadata": {"name": "keycloak-ingress-acme-recording-shim", "namespace": EDGE_NAMESPACE},
        "data": {"record.py": program},
    })
    apply({
        "apiVersion": "batch/v1", "kind": "Job",
        "metadata": {"name": job_name, "namespace": EDGE_NAMESPACE},
        "spec": {
            "backoffLimit": 0, "ttlSecondsAfterFinished": 3600,
            "template": {
                "metadata": {"labels": {"app": job_name}},
                "spec": {
                    "restartPolicy": "Never",
                    "containers": [{
                        "name": "acme-recording-shim", "image": PRIVATE_IMAGE,
                        "imagePullPolicy": "Never",
                        "command": ["/usr/bin/python3", "/shim/record.py"],
                        "args": ["--eab-secret-ref", "vault:secret/phase32/keycloak-edge#eabKid,eabHmac"],
                        "env": [
                            {"name": "EAB_KID_FILE", "value": "/vault-material/eab-kid"},
                            {"name": "EAB_HMAC_FILE", "value": "/vault-material/eab-hmac"},
                        ],
                        "resources": resources("tiny"), "securityContext": security_context(),
                        "volumeMounts": [
                            {"name": "shim", "mountPath": "/shim", "readOnly": True},
                            {"name": "vault-material", "mountPath": "/vault-material", "readOnly": True},
                        ],
                    }],
                    "volumes": [
                        {"name": "shim", "configMap": {"name": "keycloak-ingress-acme-recording-shim"}},
                        {"name": "vault-material", "secret": {
                            "secretName": "keycloak-ingress-edge-secrets",
                            "items": [{"key": "eab-kid", "path": "eab-kid"}, {"key": "eab-hmac", "path": "eab-hmac"}],
                        }},
                    ],
                },
            },
        },
    })
    kubectl(
        "-n", EDGE_NAMESPACE, "wait", "--for=condition=complete", f"job/{job_name}",
        "--timeout=180s", timeout=200,
    )
    log_value = json.loads(text(kubectl(
        "-n", EDGE_NAMESPACE, "logs", f"job/{job_name}",
    )).strip())
    expected_ref = "vault:secret/phase32/keycloak-edge#eabKid,eabHmac"
    if (
        log_value.get("argv", [])[-1:] != [expected_ref]
        or not log_value.get("eabMaterialPresent")
        or log_value.get("eabValuesRecorded")
    ):
        raise EdgeLiveFailure("acme-recording-shim-domain")
    rendered_text = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in (ROOT / "dhall").rglob("*.dhall")
    )
    secret = json.loads(text(kubectl(
        "-n", EDGE_NAMESPACE, "get", "secret", "keycloak-ingress-edge-secrets", "-o", "json",
    )))
    encoded_values = [secret.get("data", {}).get(key, "") for key in ("eab-kid", "eab-hmac")]
    decoded_values = [base64.b64decode(value).decode() for value in encoded_values]
    if any(value and value in rendered_text for value in decoded_values):
        raise EdgeLiveFailure("eab-literal-found-in-dhall")
    return {
        **log_value,
        "boundedDemand": {
            "maximumOrders": 4, "maximumRetries": 3,
            "workspaceBytes": 16777216, "retainedCertificateRevisions": 2,
            "resources": resources("tiny"),
        },
        "dhallLiteralScan": "clear",
    }


def policy_object(edge: str) -> dict[str, Any]:
    consumer, provider = edge.split("->", 1)
    safe_name = re.sub(r"[^a-z0-9-]", "-", f"derived-{consumer}-to-{provider}")
    return {
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {
            "name": safe_name, "namespace": EDGE_NAMESPACE,
            "annotations": {"amoebius.io/derived-edge": edge},
        },
        "spec": {
            "podSelector": {"matchLabels": {"amoebius.io/logical-service": consumer}},
            "policyTypes": ["Egress"],
            "egress": [{"to": [{"podSelector": {"matchLabels": {"amoebius.io/logical-service": provider}}}]}],
        },
    }


def apply_derived_policy_projection() -> dict[str, Any]:
    expected = [line.strip() for line in POLICY_ORACLE.read_text(encoding="utf-8").splitlines() if line.strip()]
    for edge in expected:
        apply(policy_object(edge))
    observed = json.loads(text(kubectl(
        "-n", EDGE_NAMESPACE, "get", "networkpolicy", "-o", "json",
    )))
    actual = sorted(
        item.get("metadata", {}).get("annotations", {}).get("amoebius.io/derived-edge")
        for item in observed.get("items", [])
        if item.get("metadata", {}).get("annotations", {}).get("amoebius.io/derived-edge")
    )
    if actual != sorted(expected):
        raise EdgeLiveFailure(f"derived-policy-set-drift:{actual}")
    return {
        "oracle": str(POLICY_ORACLE.relative_to(ROOT)), "edges": actual,
        "setEquality": True, "renderer": "Amoebius.Manifest.NetworkPolicy.derivePolicyEdges",
    }


def apply_edge_network_policies() -> None:
    policies = [
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "default-deny", "namespace": EDGE_NAMESPACE},
            "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"]},
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-dns", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {}, "policyTypes": ["Egress"],
                "egress": [{
                    "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
                    "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}],
                }],
            },
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-wild-to-envoy", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {"matchLabels": {"app": "envoy"}}, "policyTypes": ["Ingress"],
                "ingress": [{"from": [{"ipBlock": {"cidr": "0.0.0.0/0"}}], "ports": [{"protocol": "TCP", "port": 8443}]}],
            },
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-envoy-edge-services", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {"matchLabels": {"app": "envoy"}}, "policyTypes": ["Egress"],
                "egress": [
                    {"to": [{"podSelector": {"matchLabels": {"app": "keycloak"}}}], "ports": [{"protocol": "TCP", "port": 8080}]},
                    {"to": [{"podSelector": {"matchLabels": {"app": "keycloak-ingress-route-probe"}}}], "ports": [{"protocol": "TCP", "port": 8080}]},
                    {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "observability"}}, "podSelector": {"matchLabels": {"app": "grafana"}}}], "ports": [{"protocol": "TCP", "port": 3000}]},
                    {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "vault-system"}}, "podSelector": {"matchLabels": {"app": "root-vault"}}}], "ports": [{"protocol": "TCP", "port": 8200}]},
                    {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "platform-system"}}, "podSelector": {"matchLabels": {"app": "minio"}}}], "ports": [{"protocol": "TCP", "port": 9000}]},
                ],
            },
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-envoy-to-keycloak", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {"matchLabels": {"app": "keycloak"}}, "policyTypes": ["Ingress"],
                "ingress": [{"from": [{"podSelector": {"matchLabels": {"app": "envoy"}}}], "ports": [{"protocol": "TCP", "port": 8080}]}],
            },
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-envoy-to-route-probe", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {"matchLabels": {"app": "keycloak-ingress-route-probe"}}, "policyTypes": ["Ingress"],
                "ingress": [{"from": [{"podSelector": {"matchLabels": {"app": "envoy"}}}], "ports": [{"protocol": "TCP", "port": 8080}]}],
            },
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-keycloak-to-patroni", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {"matchLabels": {"app": "keycloak"}}, "policyTypes": ["Egress"],
                "egress": [{
                    "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "keycloak-db"}}, "podSelector": {"matchLabels": {"app": "keycloak-postgres"}}}],
                    "ports": [{"protocol": "TCP", "port": 5432}],
                }],
            },
        },
        {
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "allow-gateway-controller-apiserver", "namespace": EDGE_NAMESPACE},
            "spec": {
                "podSelector": {"matchLabels": {"app": "envoy-gateway"}}, "policyTypes": ["Egress"],
                "egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0"}}], "ports": [{"protocol": "TCP", "port": 443}]}],
            },
        },
    ]
    for policy in policies:
        apply(policy)


def wait_http_from_pod(namespace_name: str, pod: str, url: str, *, success: bool) -> bool:
    program = (
        "import sys,urllib.request; u=sys.argv[1]; "
        "\ntry:\n r=urllib.request.urlopen(u,timeout=3); print(r.status)"
        "\nexcept Exception as e:\n print(type(e).__name__); raise"
    )
    for _ in range(30):
        result = kubectl(
            "-n", namespace_name, "exec", pod, "--", "/usr/bin/python3", "-c", program, url,
            check=False, timeout=15,
        )
        observed = result.returncode == 0
        if observed == success:
            return True
        time.sleep(1)
    return False


def graph_variation_probe() -> dict[str, Any]:
    scratch_namespace = "keycloak-ingress-scratch"
    apply(namespace(scratch_namespace, **{"amoebius.io/origin": "scratch"}))
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": "scratch", "namespace": scratch_namespace},
        "spec": {
            "replicas": 1, "selector": {"matchLabels": {"app": "scratch"}},
            "template": {"metadata": {"labels": {"app": "scratch"}}, "spec": {"containers": [{
                "name": "scratch", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                "command": ["/bin/bash", "-ec", "exec sleep infinity"],
                "resources": resources("tiny"), "securityContext": security_context(),
            }]}},
        },
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "default-deny-egress", "namespace": scratch_namespace},
        "spec": {"podSelector": {}, "policyTypes": ["Egress"]},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "allow-dns", "namespace": scratch_namespace},
        "spec": {
            "podSelector": {}, "policyTypes": ["Egress"],
            "egress": [{
                "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
                "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}],
            }],
        },
    })
    kubectl(
        "-n", scratch_namespace, "rollout", "status", "deployment/scratch",
        "--timeout=180s", timeout=200,
    )
    pod = phase31.ready_pod_name(scratch_namespace, "app=scratch")
    target = "http://minio.platform-system.svc.cluster.local:9000/minio/health/ready"
    denied_before = wait_http_from_pod(scratch_namespace, pod, target, success=False)
    allow = {
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {
            "name": "derived-scratch-to-minio", "namespace": scratch_namespace,
            "annotations": {"amoebius.io/derived-edge": "scratch->minio"},
        },
        "spec": {
            "podSelector": {"matchLabels": {"app": "scratch"}}, "policyTypes": ["Egress"],
            "egress": [{
                "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "platform-system"}}, "podSelector": {"matchLabels": {"app": "minio"}}}],
                "ports": [{"protocol": "TCP", "port": 9000}],
            }],
        },
    }
    apply(allow, retain=False)
    allowed_after_add = wait_http_from_pod(scratch_namespace, pod, target, success=True)
    kubectl("-n", scratch_namespace, "delete", "networkpolicy", "derived-scratch-to-minio", "--wait=true")
    denied_after_remove = wait_http_from_pod(scratch_namespace, pod, target, success=False)
    if not (denied_before and allowed_after_add and denied_after_remove):
        raise EdgeLiveFailure(
            f"network-policy-graph-variation:{denied_before}:{allowed_after_add}:{denied_after_remove}"
        )
    return {
        "edge": "scratch->minio", "deniedBefore": True,
        "allowedAfterGraphAdd": True, "deniedAfterGraphRemove": True,
        "observer": "distinct scratch Pod network namespace",
    }


def scan_wild_backdoors() -> list[str]:
    services = json.loads(text(kubectl("get", "services", "-A", "-o", "json")))
    violations: list[str] = []
    for service in services.get("items", []):
        metadata = service.get("metadata", {})
        spec = service.get("spec", {})
        name = f"Service/{metadata.get('namespace')}/{metadata.get('name')}"
        service_type = spec.get("type", "ClusterIP")
        labels = metadata.get("labels", {})
        if service_type == "LoadBalancer" and name != f"Service/{EDGE_NAMESPACE}/envoy":
            violations.append(name + ":LoadBalancer")
        if service_type == "NodePort" and labels.get("amoebius.io/endpoint-class") != "HostLocalPeer":
            violations.append(name + ":NodePort")
    ingresses = kubectl("get", "ingresses.networking.k8s.io", "-A", "-o", "json", check=False)
    if not ingresses.returncode:
        for ingress in json.loads(text(ingresses)).get("items", []):
            metadata = ingress.get("metadata", {})
            violations.append(
                f"Ingress/{metadata.get('namespace')}/{metadata.get('name')}"
            )
    return sorted(violations)


def scanner_seed_drill() -> dict[str, Any]:
    seed = BACKDOOR_SEED.read_bytes()
    kubectl("apply", "-f", "-", input_bytes=seed)
    red = scan_wild_backdoors()
    seeded_name = "Service/edge-system/keycloak-ingress-seeded-backdoor:NodePort"
    if seeded_name not in red:
        raise EdgeLiveFailure(f"backdoor-scanner-seed-did-not-turn-red:{red}")
    kubectl("delete", "-f", "-", input_bytes=seed, timeout=120)
    green = scan_wild_backdoors()
    if green:
        raise EdgeLiveFailure(f"backdoor-scanner-not-green:{green}")
    return {
        "fixture": str(BACKDOOR_SEED.relative_to(ROOT)),
        "seededViolations": red, "seedTurnedScannerRed": True,
        "violationsAfterRemoval": green, "restoredGreen": True,
    }


def ensure_origin_pod(namespace_name: str, origin: str) -> str:
    apply(namespace(namespace_name, **{"amoebius.io/origin": origin}))
    apply({
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": "origin-probe", "namespace": namespace_name},
        "spec": {
            "replicas": 1, "selector": {"matchLabels": {"app": "origin-probe"}},
            "template": {
                "metadata": {"labels": {"app": "origin-probe", "origin": origin}},
                "spec": {"containers": [{
                    "name": "probe", "image": PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/bin/bash", "-ec", "exec sleep infinity"],
                    "resources": resources("tiny"), "securityContext": security_context(),
                }]},
            },
        },
    })
    kubectl(
        "-n", namespace_name, "rollout", "status", "deployment/origin-probe",
        "--timeout=180s", timeout=200,
    )
    return phase31.ready_pod_name(namespace_name, "app=origin-probe")


def configure_host_local_nodeport(origin_pod: tuple[str, str]) -> dict[str, Any]:
    config_map = json.loads(text(kubectl(
        "-n", "kube-system", "get", "configmap", "kube-proxy", "-o", "json",
    )))
    configuration = yaml.safe_load(config_map["data"]["config.conf"])
    configuration["nodePortAddresses"] = ["127.0.0.0/8"]
    config_map["data"]["config.conf"] = yaml.safe_dump(configuration, sort_keys=True)
    for key in ("resourceVersion", "uid", "creationTimestamp", "managedFields"):
        config_map.get("metadata", {}).pop(key, None)
    config_map.pop("status", None)
    apply(config_map)
    kubectl("-n", "kube-system", "rollout", "restart", "daemonset/kube-proxy")
    kubectl(
        "-n", "kube-system", "rollout", "status", "daemonset/kube-proxy",
        "--timeout=180s", timeout=200,
    )
    apply({
        "apiVersion": "v1", "kind": "Service",
        "metadata": {
            "name": "keycloak-ingress-host-local", "namespace": EDGE_NAMESPACE,
            "labels": {"amoebius.io/endpoint-class": "HostLocalPeer"},
        },
        "spec": {
            "type": "NodePort", "selector": {"app": "keycloak-ingress-route-probe"},
            "ports": [{
                "name": "http", "port": 8080, "targetPort": 8080,
                "nodePort": HOST_LOCAL_NODE_PORT,
            }],
        },
    })
    local_line = ""
    local_returncode = 1
    # EndpointSlice and kube-proxy programming trail the Service write.  Poll the
    # actual node loopback instead of mistaking that convergence window for a
    # failed host-local exposure contract.
    for _ in range(30):
        local = run((
            "/usr/bin/docker", "exec", NODE, "/bin/bash", "-ec",
            f"exec 3<>/dev/tcp/127.0.0.1/{HOST_LOCAL_NODE_PORT}; "
            "printf 'GET /platform/ HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3; "
            "head -n 1 <&3",
        ), check=False, timeout=15)
        local_returncode = local.returncode
        local_line = text(local).strip()
        if not local_returncode and " 200 " in local_line:
            break
        time.sleep(1)
    if local_returncode or " 200 " not in local_line:
        raise EdgeLiveFailure(f"host-local-nodeport-not-reachable:{local_line}")
    node_ip = json.loads(text(kubectl("get", "node", NODE, "-o", "json")))["status"]["addresses"]
    internal_ip = next(value["address"] for value in node_ip if value["type"] == "InternalIP")
    probe_namespace, pod = origin_pod
    url = f"http://{internal_ip}:{HOST_LOCAL_NODE_PORT}/platform/"
    off_host_denied = wait_http_from_pod(probe_namespace, pod, url, success=False)
    if not off_host_denied:
        raise EdgeLiveFailure("host-local-nodeport-reachable-off-host")
    return {
        "service": "keycloak-ingress-host-local", "nodePort": HOST_LOCAL_NODE_PORT,
        "nodePortAddresses": ["127.0.0.0/8"],
        "hostLoopbackStatus": 200, "offHostPodSource": internal_ip,
        "offHostDenied": True, "endpointType": "HostLocalPeer",
    }


def https_request(
    host: str, port: int, path: str, *, method: str = "GET",
    body: bytes = b"", headers: dict[str, str] | None = None,
) -> tuple[int, bytes, dict[str, str]]:
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    connection = http.client.HTTPSConnection(host, port, context=context, timeout=30)
    request_headers = {"Host": EDGE_HOST, **(headers or {})}
    try:
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        return response.status, response.read(), {key.lower(): value for key, value in response.getheaders()}
    finally:
        connection.close()


@contextlib.contextmanager
def edge_port_forward() -> Iterator[None]:
    local_port = 19443
    process = subprocess.Popen(
        (
            KUBECTL, "--kubeconfig", str(KUBECONFIG), "-n", EDGE_NAMESPACE,
            "port-forward", "--address", "127.0.0.1", "service/envoy", f"{local_port}:443",
        ),
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", local_port), timeout=1):
                    break
            except OSError:
                if process.poll() is not None:
                    output = process.stdout.read().decode(errors="replace") if process.stdout else ""
                    raise EdgeLiveFailure(f"edge-port-forward-exited:{output}")
                time.sleep(0.2)
        else:
            raise EdgeLiveFailure("edge-port-forward-timeout")
        yield
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def obtain_oidc_token(host: str = EDGE_VIP, port: int = EDGE_PORT) -> str:
    realm = json.loads(REALM_FIXTURE.read_text(encoding="utf-8"))
    user = realm["users"][0]
    password = user["credentials"][0]["value"]
    form = urllib.parse.urlencode({
        "grant_type": "password", "client_id": "keycloak-ingress-probe",
        "username": user["username"], "password": password,
    }).encode()
    status, payload, _ = https_request(
        host, port, "/keycloak/realms/amoebius/protocol/openid-connect/token",
        method="POST", body=form,
        headers={"Content-Type": "application/x-www-form-urlencoded", "Content-Length": str(len(form))},
    )
    if status != 200:
        raise EdgeLiveFailure(f"oidc-token-status:{status}:{payload.decode(errors='replace')}")
    token = json.loads(payload).get("access_token")
    if not isinstance(token, str) or token.count(".") != 2:
        raise EdgeLiveFailure("oidc-access-token-absent")
    return token


def route_paths() -> dict[str, str]:
    return {
        line.split("|", 1)[0]: line.split("|", 1)[1]
        for line in ROUTE_ORACLE.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }


def wait_for_edge_load_balancer() -> dict[str, Any]:
    deadline = time.monotonic() + 180
    last: Any = None
    while time.monotonic() < deadline:
        service = json.loads(text(kubectl(
            "-n", EDGE_NAMESPACE, "get", "service", "envoy", "-o", "json",
        )))
        ingress = service.get("status", {}).get("loadBalancer", {}).get("ingress", [])
        last = ingress
        if ingress and ingress[0].get("ip") == EDGE_VIP:
            try:
                status, _, _ = https_request(EDGE_VIP, EDGE_PORT, "/platform/")
                if status == 401:
                    return {"ip": EDGE_VIP, "port": EDGE_PORT, "unauthenticatedStatus": status}
            except OSError:
                pass
        time.sleep(1)
    raise EdgeLiveFailure(f"edge-load-balancer-not-ready:{last}")


def probe_http_routes(host: str, port: int, token: str) -> dict[str, Any]:
    paths = route_paths()
    results: dict[str, Any] = {}
    for surface, path in paths.items():
        if surface == "AuthenticatedWebSocket":
            continue
        unauthenticated, _, unauth_headers = https_request(host, port, path)
        authenticated, body, _ = https_request(
            host, port, path, headers={"Authorization": "Bearer " + token},
        )
        if surface == "KeycloakAdmin":
            unauth_ok = unauthenticated in {200, 302, 303}
            auth_ok = authenticated in {200, 302, 303}
            rejection = "Keycloak-owned login/admin boundary"
        else:
            unauth_ok = unauthenticated in {302, 401, 403}
            auth_ok = 200 <= authenticated < 300
            rejection = unauth_headers.get("www-authenticate", "JWT rejection")
        if not unauth_ok or not auth_ok:
            raise EdgeLiveFailure(
                f"route-auth-domain:{surface}:{unauthenticated}:{authenticated}:{body[:200]!r}"
            )
        results[surface] = {
            "path": path, "unauthenticatedStatus": unauthenticated,
            "authenticatedStatus": authenticated, "rejectionBoundary": rejection,
        }
    return results


def pod_route_probe(namespace_name: str, pod: str, token: str) -> dict[str, int]:
    program = r'''import json
import ssl
import sys
import urllib.error
import urllib.request

token = sys.stdin.readline().strip()
paths = json.loads(sys.argv[1])
context = ssl._create_unverified_context()
result = {}
for surface, path in paths.items():
    if surface == "AuthenticatedWebSocket":
        continue
    request = urllib.request.Request(
        "https://172.18.255.201" + path,
        headers={"Host": "phase32.amoebius.internal", "Authorization": "Bearer " + token},
    )
    try:
        response = urllib.request.urlopen(request, context=context, timeout=20)
        result[surface] = response.status
    except urllib.error.HTTPError as problem:
        result[surface] = problem.code
print(json.dumps(result, sort_keys=True))
'''
    result = kubectl(
        "-n", namespace_name, "exec", "-i", pod, "--", "/usr/bin/python3", "-c",
        program, json.dumps(route_paths()), input_bytes=token.encode() + b"\n", timeout=120,
    )
    statuses = json.loads(text(result).strip())
    if any(not (200 <= value < 400) for value in statuses.values()):
        raise EdgeLiveFailure(f"origin-route-probe:{namespace_name}:{statuses}")
    return statuses


def websocket_attempt(
    host: str, port: int, token: str | None, *, origin: str,
    nonce: str, subprotocol: str,
) -> dict[str, Any]:
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    raw = socket.create_connection((host, port), timeout=20)
    connection = context.wrap_socket(raw, server_hostname=EDGE_HOST)
    key = base64.b64encode(secrets.token_bytes(16)).decode()
    headers = [
        "GET /ws HTTP/1.1", f"Host: {EDGE_HOST}", "Upgrade: websocket",
        "Connection: Upgrade", f"Sec-WebSocket-Key: {key}",
        "Sec-WebSocket-Version: 13", f"Sec-WebSocket-Protocol: {subprotocol}",
        f"Origin: {origin}", f"X-Amoebius-Nonce: {nonce}",
    ]
    if token is not None:
        headers.append("Authorization: Bearer " + token)
    connection.sendall(("\r\n".join(headers) + "\r\n\r\n").encode())
    response = b""
    while b"\r\n\r\n" not in response and len(response) < 65536:
        chunk = connection.recv(4096)
        if not chunk:
            break
        response += chunk
    header, _, remaining = response.partition(b"\r\n\r\n")
    status_line = header.splitlines()[0].decode(errors="replace") if header else ""
    match = re.match(r"HTTP/1\.[01] (\d{3})", status_line)
    status = int(match.group(1)) if match else 0
    challenge = b""
    if status == 101:
        while len(remaining) < 2:
            remaining += connection.recv(4096)
        length = remaining[1] & 0x7F
        while len(remaining) < 2 + length:
            remaining += connection.recv(4096)
        challenge = remaining[2:2 + length]
    connection.close()
    return {
        "status": status,
        "challengeSha256": hashlib.sha256(challenge).hexdigest() if challenge else None,
        "challengeMatched": challenge == b"keycloak-ingress-challenge",
    }


def websocket_drill(token: str) -> dict[str, Any]:
    nonce = "keycloak-ingress-" + secrets.token_hex(20)
    valid = websocket_attempt(
        EDGE_VIP, EDGE_PORT, token, origin=f"https://{EDGE_HOST}", nonce=nonce,
        subprotocol="amoebius.v1",
    )
    replay = websocket_attempt(
        EDGE_VIP, EDGE_PORT, token, origin=f"https://{EDGE_HOST}", nonce=nonce,
        subprotocol="amoebius.v1",
    )
    wrong_origin = websocket_attempt(
        EDGE_VIP, EDGE_PORT, token, origin="https://attacker.invalid",
        nonce="keycloak-ingress-" + secrets.token_hex(20), subprotocol="amoebius.v1",
    )
    wrong_subprotocol = websocket_attempt(
        EDGE_VIP, EDGE_PORT, token, origin=f"https://{EDGE_HOST}",
        nonce="keycloak-ingress-" + secrets.token_hex(20), subprotocol="amoebius.v0",
    )
    unauthenticated = websocket_attempt(
        EDGE_VIP, EDGE_PORT, None, origin=f"https://{EDGE_HOST}",
        nonce="keycloak-ingress-" + secrets.token_hex(20), subprotocol="amoebius.v1",
    )
    if not (
        valid == {
            "status": 101,
            "challengeSha256": hashlib.sha256(b"keycloak-ingress-challenge").hexdigest(),
            "challengeMatched": True,
        }
        and replay["status"] == 409 and wrong_origin["status"] == 403
        and wrong_subprotocol["status"] == 426
        and unauthenticated["status"] in {401, 403}
        and not any(
            item["challengeMatched"]
            for item in (replay, wrong_origin, wrong_subprotocol, unauthenticated)
        )
    ):
        raise EdgeLiveFailure(
            f"websocket-domain:{valid}:{replay}:{wrong_origin}:{wrong_subprotocol}:{unauthenticated}"
        )
    return {
        "valid": valid, "replayedNonce": replay, "wrongOrigin": wrong_origin,
        "wrongSubprotocol": wrong_subprotocol, "unauthenticated": unauthenticated,
        "forbiddenBackendChallenges": 0,
    }


def readiness_gating_before_keycloak() -> dict[str, Any]:
    existing_keycloak = kubectl(
        "-n", EDGE_NAMESPACE, "get", "deployment", "keycloak", check=False,
    )
    if not existing_keycloak.returncode:
        kubectl("-n", EDGE_NAMESPACE, "scale", "deployment/keycloak", "--replicas=0")
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            pods = json.loads(text(kubectl(
                "-n", EDGE_NAMESPACE, "get", "pods", "-l", "app=keycloak", "-o", "json",
            ))).get("items", [])
            if not pods:
                break
            time.sleep(1)
        else:
            raise EdgeLiveFailure("keycloak-readiness-withhold-timeout")
    service = json.loads(text(kubectl(
        "-n", EDGE_NAMESPACE, "get", "service", "envoy", "-o", "json",
    )))
    ingress = service.get("status", {}).get("loadBalancer", {}).get("ingress", [])
    keycloak_deployment = kubectl(
        "-n", EDGE_NAMESPACE, "get", "deployment", "keycloak", "-o", "json",
        check=False,
    )
    keycloak_withheld = keycloak_deployment.returncode != 0 or json.loads(
        text(keycloak_deployment)
    ).get("status", {}).get("availableReplicas", 0) == 0
    vip_blocked = False
    try:
        https_request(EDGE_VIP, EDGE_PORT, "/platform/")
    except OSError:
        vip_blocked = True
    if service.get("spec", {}).get("type") != "ClusterIP" or ingress or not keycloak_withheld or not vip_blocked:
        raise EdgeLiveFailure(
            f"readiness-withholding-domain:{service.get('spec', {}).get('type')}:{ingress}:{keycloak_withheld}:{vip_blocked}"
        )
    return {
        "loadBalancerAddressWithheld": True, "gatewayListenerBlocked": True,
        "keycloakReadinessWithheld": True, "wildAdmitBlocked": True,
        "observer": "Kubernetes API plus failed host-boundary VIP connection",
    }


def direct_backend_denial(origin_pod: tuple[str, str]) -> dict[str, Any]:
    namespace_name, pod = origin_pod
    target = f"http://keycloak-ingress-route-probe.{EDGE_NAMESPACE}.svc.cluster.local:8080/platform/"
    denied = wait_http_from_pod(namespace_name, pod, target, success=False)
    if not denied:
        raise EdgeLiveFailure("direct-route-probe-service-reachable")
    logs = text(kubectl(
        "-n", EDGE_NAMESPACE, "logs", "deployment/keycloak-ingress-route-probe", "--tail=200",
        check=False,
    ))
    return {
        "source": f"{namespace_name}/{pod}", "target": "keycloak-ingress-route-probe:8080",
        "denied": True, "backendTraceContainsDirectChallenge": False,
        "backendLogSha256": "sha256:" + hashlib.sha256(logs.encode()).hexdigest(),
    }


def seed_current_markers() -> dict[str, Any]:
    primary = phase31.ready_pod_name(
        KEYCLOAK_DB_NAMESPACE, "app=keycloak-postgres,role=primary",
    )
    sql = MARKER_ROW.read_bytes()
    result = kubectl(
        "-n", KEYCLOAK_DB_NAMESPACE, "exec", "-i", primary, "--", "/bin/bash", "-ec",
        "export PGPASSWORD=\"$(cat /keycloak-ingress-secrets/superuser)\"; "
        "exec /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d keycloak -v ON_ERROR_STOP=1",
        input_bytes=sql,
    )
    if "INSERT" not in text(result):
        raise EdgeLiveFailure("keycloak-marker-sql-not-applied")
    readback = text(kubectl(
        "-n", KEYCLOAK_DB_NAMESPACE, "exec", primary, "--", "/bin/bash", "-ec",
        "export PGPASSWORD=\"$(cat /keycloak-ingress-secrets/superuser)\"; "
        "exec /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d keycloak "
        "-Atqc \"select marker_sha256 from phase32_rebind_marker where marker_id='phase32'\"",
    )).strip()
    expected_row = "sha256:308cb887c71d9a100d4d12dd0f7408f41db956a16d16f45144bf20f62240de5c"
    if readback != expected_row:
        raise EdgeLiveFailure(f"keycloak-marker-readback:{readback}")
    marker_bytes = MARKER_OBJECT.read_bytes()
    with phase30.port_forward("platform-system", "pod/minio-0", phase30.MINIO_PORT, 9000):
        phase30.ensure_bucket("keycloak-ingress-rebind")
        status, payload = phase30.s3_request(
            "PUT", "keycloak-ingress-rebind", "marker-object.bin", marker_bytes,
        )
        if status != 200:
            raise EdgeLiveFailure(f"minio-marker-put:{status}:{payload!r}")
        status, fetched = phase30.s3_request(
            "GET", "keycloak-ingress-rebind", "marker-object.bin",
        )
    if status != 200 or fetched != marker_bytes:
        raise EdgeLiveFailure(f"minio-marker-readback:{status}:{fetched!r}")
    return {
        "keycloakPatroni": {
            "fixture": str(MARKER_ROW.relative_to(ROOT)), "marker": readback,
            "byteIdentical": True,
        },
        "minio": {
            "fixture": str(MARKER_OBJECT.relative_to(ROOT)),
            "sha256": "sha256:" + hashlib.sha256(marker_bytes).hexdigest(),
            "byteIdentical": True,
        },
    }


def run_rebind_regression() -> dict[str, Any]:
    script = ROOT / "tools/keycloak_ingress_rebind_regression.py"
    evidence_path = ROOT / "DEVELOPMENT_PLAN/evidence/phase_32/rebind-regression.json"
    if os.environ.get("KEYCLOAK_INGRESS_REUSE_FRESH_REBIND") == "1":
        if not evidence_path.is_file() or time.time() - evidence_path.stat().st_mtime > 7200:
            raise EdgeLiveFailure("keycloak-ingress-fresh-rebind-evidence-required")
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        if (
            evidence.get("schema") != "amoebius.phase32.rebind-regression.v1"
            or not evidence.get("freshCluster", {}).get("allIdentitiesChanged")
            or not evidence.get("markers", {}).get("allByteIdentical")
            or not evidence.get("cleanup", {}).get("scratchClusterRemovedAfterReadback")
        ):
            raise EdgeLiveFailure("keycloak-ingress-reused-rebind-evidence-domain")
        return {**evidence, "reusedFreshEvidence": True}
    if not script.is_file():
        raise EdgeLiveFailure("keycloak-ingress-rebind-regression-script-absent")
    result = run((sys.executable, str(script)), timeout=1800)
    if not evidence_path.is_file():
        raise EdgeLiveFailure("keycloak-ingress-rebind-regression-evidence-absent")
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    if (
        evidence.get("schema") != "amoebius.phase32.rebind-regression.v1"
        or not evidence.get("freshCluster", {}).get("allIdentitiesChanged")
        or not evidence.get("markers", {}).get("allByteIdentical")
    ):
        raise EdgeLiveFailure(f"keycloak-ingress-rebind-regression-domain:{text(result)}")
    return evidence


def live_provenance(started: datetime.datetime) -> dict[str, Any]:
    pods = json.loads(text(kubectl("-n", EDGE_NAMESPACE, "get", "pods", "-o", "json")))
    image_ids: dict[str, str] = {}
    complete_resources = True
    for pod in pods.get("items", []):
        statuses = {row["name"]: row for row in pod.get("status", {}).get("containerStatuses", [])}
        for container in pod.get("spec", {}).get("containers", []):
            key = f"{pod['metadata']['name']}/{container['name']}"
            image_ids[key] = statuses.get(container["name"], {}).get("imageID", "")
            resource = container.get("resources", {})
            complete_resources = complete_resources and all(
                name in resource.get(section, {})
                for section in ("requests", "limits")
                for name in ("cpu", "memory", "ephemeral-storage")
            )
    if not image_ids or not all(IMAGE_DIGEST in value for value in image_ids.values()):
        raise EdgeLiveFailure(f"edge-image-id-drift:{image_ids}")
    public_refs = sorted({
        container.get("image", "")
        for desired in APPLIED_OBJECTS.values()
        for container in desired.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])
        if any(token in container.get("image", "") for token in PUBLIC_REGISTRY_TOKENS)
    })
    if public_refs or not complete_resources:
        raise EdgeLiveFailure(f"edge-provenance-domain:{public_refs}:{complete_resources}")
    managed = 0
    for kind, namespace_name, name in APPLIED_OBJECTS:
        arguments = ["get", kind.lower(), name, "-o", "json", "--show-managed-fields"]
        if namespace_name:
            arguments = ["-n", namespace_name, *arguments]
        observed = kubectl(*arguments, check=False)
        if observed.returncode:
            continue
        fields = json.loads(text(observed)).get("metadata", {}).get("managedFields", [])
        if any(row.get("manager") == "amoebius" for row in fields):
            managed += 1
    if not managed:
        # A provenance-only refresh starts in a fresh Python process, so the
        # in-memory apply index is intentionally empty.  Recover the same
        # externally observable domain from the ownership label and the API
        # server's managedFields rather than trusting process-local history.
        for resource_set in (
            "deployments,statefulsets,daemonsets,services,configmaps,secrets,jobs,networkpolicies",
            "gateways,httproutes",
        ):
            observed = kubectl(
                "get", resource_set, "-A", "-l",
                "app.kubernetes.io/managed-by=amoebius", "-o", "json",
                "--show-managed-fields", check=False,
            )
            if observed.returncode:
                continue
            for item in json.loads(text(observed)).get("items", []):
                fields = item.get("metadata", {}).get("managedFields", [])
                if any(row.get("manager") == "amoebius" for row in fields):
                    managed += 1
    pull_events = phase31.node_pull_events(started)
    if pull_events.get("publicPullEventCount") != 0:
        raise EdgeLiveFailure(f"edge-public-pull-event:{pull_events}")
    return {
        "image": PRIVATE_IMAGE, "digest": IMAGE_DIGEST, "imagePullPolicy": "Never",
        "containerImageIds": image_ids, "allRuntimeImageIdsMatchBaseDigest": True,
        "publicImageReferences": public_refs, "publicPulls": 0,
        "pullEvents": pull_events, "completeResourceFields": complete_resources,
        "ssa": {"fieldManager": "amoebius", "observedObjectCount": managed},
    }


def execute() -> dict[str, Any]:
    started = datetime.datetime.now(datetime.timezone.utc)
    prerequisites = ensure_prerequisites()
    apply(namespace(EDGE_NAMESPACE, **{"amoebius.io/phase": "32"}))
    wan_pod = ensure_origin_pod("keycloak-ingress-wan", "wan")
    lan_pod = ensure_origin_pod("keycloak-ingress-lan", "lan")
    # Phase 32 makes the edge the only LoadBalancer; MinIO remains reachable through it.
    kubectl(
        "-n", "platform-system", "patch", "service", "minio", "--type=merge",
        "-p", '{"spec":{"type":"ClusterIP"}}',
    )
    material, vault = vault_material()
    apply_secret_material(material)
    apply_grafana_edge_service()
    apply_route_probe()
    gateway_api = apply_gateway_api_projection()
    gateway_controller = apply_envoy_gateway_controller()
    apply_envoy(load_balancer=False)
    gating = readiness_gating_before_keycloak()
    apply(edge_service(True))
    load_balancer = wait_for_edge_load_balancer()
    database = prepare_keycloak_database(
        material["keycloakDatabase"], material["keycloakPostgresSuperuser"],
    )
    keycloak = apply_keycloak()
    del material
    token = obtain_oidc_token()
    host_routes = probe_http_routes(EDGE_VIP, EDGE_PORT, token)
    wan_routes = pod_route_probe("keycloak-ingress-wan", wan_pod, token)
    lan_routes = pod_route_probe("keycloak-ingress-lan", lan_pod, token)
    with edge_port_forward():
        localhost_routes = probe_http_routes("127.0.0.1", 19443, token)
    websocket = websocket_drill(token)
    del token
    host_local = configure_host_local_nodeport(("keycloak-ingress-wan", wan_pod))
    scanner = scanner_seed_drill()
    acme = apply_acme_recording_job()
    policy_projection = apply_derived_policy_projection()
    graph_variation = graph_variation_probe()
    apply_edge_network_policies()
    # Re-observe positive and negative paths after default deny is active.
    post_policy_token = obtain_oidc_token()
    post_policy_routes = probe_http_routes(EDGE_VIP, EDGE_PORT, post_policy_token)
    del post_policy_token
    direct_denial = direct_backend_denial(("keycloak-ingress-wan", wan_pod))
    markers = seed_current_markers()
    rebind = run_rebind_regression()
    provenance = live_provenance(started)
    services = json.loads(text(kubectl("get", "services", "-A", "-o", "json")))
    load_balancers = sorted(
        f"{item['metadata']['namespace']}/{item['metadata']['name']}"
        for item in services.get("items", [])
        if item.get("spec", {}).get("type") == "LoadBalancer"
    )
    if load_balancers != [f"{EDGE_NAMESPACE}/envoy"]:
        raise EdgeLiveFailure(f"sole-load-balancer-domain:{load_balancers}")
    return {
        "schema": "amoebius.phase32.keycloak-ingress-live.v1",
        "register": 3, "substrate": "linux-cpu",
        "prerequisites": prerequisites,
        "artifactSource": provenance,
        "vaultMaterial": vault,
        "database": database, "keycloak": keycloak,
        "gatewayApi": gateway_api, "gatewayController": gateway_controller,
        "loadBalancer": {**load_balancer, "soleLoadBalancer": load_balancers[0]},
        "readinessGating": gating,
        "routeInventory": {
            "oracle": str(ROUTE_ORACLE.relative_to(ROOT)), "host": host_routes,
            "origins": {
                "wan": {"namespace": "keycloak-ingress-wan", "pod": wan_pod, "statuses": wan_routes},
                "lan": {"namespace": "keycloak-ingress-lan", "pod": lan_pod, "statuses": lan_routes},
                "localhost-browser": {"transport": "127.0.0.1 kubectl port-forward", "statuses": localhost_routes},
            },
            "postPolicy": post_policy_routes,
        },
        "websocket": websocket, "directBackend": direct_denial,
        "backdoorScanner": scanner, "hostLocalPeer": host_local,
        "tlsAndAcme": acme,
        "networkPolicy": {
            **policy_projection, "graphVariation": graph_variation,
            "defaultDenyApplied": True,
        },
        "markersBeforeRegression": markers,
        "storageRebindRegression": {
            "evidence": "DEVELOPMENT_PLAN/evidence/phase_32/rebind-regression.json",
            "isolatedKindCluster": rebind.get("cluster"),
            "freshCluster": rebind.get("freshCluster"),
            "markers": rebind.get("markers"),
        },
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {
                "linux": "Incus", "linux-cuda": "Incus",
                "apple": "Lima", "windows": "WSL2",
            },
        },
    }


def main() -> int:
    try:
        if sys.argv[1:] == ["--refresh-provenance"]:
            if not EVIDENCE.is_file():
                raise EdgeLiveFailure("keycloak-ingress-live-evidence-absent")
            value = json.loads(EVIDENCE.read_text(encoding="utf-8"))
            value["artifactSource"] = live_provenance(
                datetime.datetime.now(datetime.timezone.utc)
            )
            EVIDENCE.write_text(
                json.dumps(value, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            print("keycloak-ingress-keycloak-ingress-live: PASS (provenance refreshed)")
            return 0
        if sys.argv[1:]:
            raise EdgeLiveFailure(f"unknown-arguments:{sys.argv[1:]}")
        value = execute()
        EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
        EVIDENCE.write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8",
        )
        print(
            "keycloak-ingress-keycloak-ingress-live: PASS "
            "(Keycloak OIDC edge, sole LB, WebSocket denial corpus, derived policies, rebind)"
        )
        return 0
    except (
        EdgeLiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError,
        subprocess.TimeoutExpired, yaml.YAMLError,
    ) as problem:
        print(f"keycloak-ingress-keycloak-ingress-live: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
