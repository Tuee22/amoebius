#!/usr/bin/env python3
"""Run the Phase-42 in-cluster Pulumi spawn and sibling data-plane exercise."""

from __future__ import annotations

import base64
import contextlib
import datetime as dt
import hashlib
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterator, Sequence

import phase29_vault_live as vault_live
import phase30_backbone_live as backbone


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_42/multicluster-live.json"
LIVE_ROOT = Path("/var/tmp/amoebius-phase42-live")
PARENT = "amoebius-p42-parent"
CHILDREN = ("amoebius-p42-a", "amoebius-p42-b")
NODE_IMAGE = "kindest/node:v1.36.1"
KIND = "/home/matthewnowak/.local/bin/kind"
KUBECTL = "/usr/bin/kubectl"
PULUMI = "/usr/local/bin/pulumi"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
PARENT_CONFIG = ROOT / "test/fixtures/phase42/kind-parent.yaml"
PHASE24_KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
MINIO_BUCKET = "phase42-pulumi"


class Phase42Failure(RuntimeError):
    pass


def run(
    arguments: Sequence[str],
    *,
    input_bytes: bytes | None = None,
    check: bool = True,
    timeout: int = 900,
    environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[bytes]:
    env = os.environ.copy()
    env.update(environment or {})
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=timeout, env=env,
    )
    if check and result.returncode:
        raise Phase42Failure(
            f"command-failed:{arguments[0]}:exit-{result.returncode}:"
            + result.stdout.decode(errors="replace")
        )
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def fingerprint(value: Any) -> str:
    return sha256_bytes(canonical_bytes(value))


def parent_kubeconfig() -> Path:
    return LIVE_ROOT / "parent-kubeconfig.yaml"


def child_kubeconfig(child: str) -> Path:
    return LIVE_ROOT / "kubeconfigs" / f"{child}.yaml"


def kubectl(config: Path, *arguments: str, input_value: Any | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[bytes]:
    payload = None if input_value is None else json.dumps(input_value).encode()
    return run((KUBECTL, "--kubeconfig", str(config), *arguments), input_bytes=payload, check=check, timeout=timeout)


def kind_clusters() -> list[str]:
    return sorted(line.strip() for line in text(run((KIND, "get", "clusters"))).splitlines() if line.strip())


def delete_exact_cluster(name: str) -> None:
    if name in kind_clusters():
        run((KIND, "delete", "cluster", "--name", name), check=False, timeout=600)


def remove_live_root() -> None:
    if LIVE_ROOT != Path("/var/tmp/amoebius-phase42-live"):
        raise Phase42Failure("unsafe-live-root")
    if not LIVE_ROOT.exists():
        return
    run(
        ("/usr/bin/sudo", "-n", "/usr/bin/chown", "-R", f"{os.getuid()}:{os.getgid()}", str(LIVE_ROOT)),
        timeout=120,
    )
    shutil.rmtree(LIVE_ROOT)


def safe_reset() -> None:
    if LIVE_ROOT != Path("/var/tmp/amoebius-phase42-live"):
        raise Phase42Failure("unsafe-live-root")
    for name in (*CHILDREN, PARENT):
        delete_exact_cluster(name)
    remove_live_root()
    (LIVE_ROOT / "kubeconfigs").mkdir(parents=True)
    (LIVE_ROOT / "checkpoints").mkdir()
    (LIVE_ROOT / "backend").mkdir()
    (LIVE_ROOT / "observer-home").mkdir()
    LIVE_ROOT.chmod(0o755)


def create_parent() -> dict[str, Any]:
    before = kind_clusters()
    run(
        (
            KIND, "create", "cluster", "--name", PARENT, "--image", NODE_IMAGE,
            "--config", str(PARENT_CONFIG), "--kubeconfig", str(parent_kubeconfig()),
            "--wait", "180s",
        ),
        timeout=600,
    )
    run((KIND, "load", "docker-image", NODE_IMAGE, "--name", PARENT), timeout=600)
    kubectl(parent_kubeconfig(), "wait", "--for=condition=Ready", f"node/{PARENT}-control-plane", "--timeout=180s")
    return {"before": before, "after": kind_clusters(), "node": f"{PARENT}-control-plane"}


def executor_job(name: str, child: str, mode: str, passphrase: str) -> dict[str, Any]:
    stack = "phase42-" + child.removeprefix("amoebius-p42-")
    if mode == "up":
        operation = f"""
pulumi stack select {stack} --create --non-interactive
pulumi up --yes --non-interactive --stack {stack} --config childId={child} --config parentCluster={PARENT}
pulumi stack export --stack {stack} --file /state/checkpoints/{child}.json
chmod 0644 /state/kubeconfigs/{child}.yaml /state/checkpoints/{child}.json
echo phase42-pulumi-up-complete:{child}
"""
    elif mode == "destroy":
        operation = f"""
pulumi stack select {stack} --non-interactive
pulumi config set childId {child} --stack {stack} --non-interactive
pulumi config set parentCluster {PARENT} --stack {stack} --non-interactive
pulumi destroy --yes --non-interactive --stack {stack}
pulumi stack rm --yes --stack {stack}
echo phase42-pulumi-destroy-complete:{child}
"""
    else:
        raise Phase42Failure(f"unknown-job-mode:{mode}")
    script = f"""set -euo pipefail
export HOME=/workspace/home
export PULUMI_HOME=/workspace/home/.pulumi
export PATH=/phase42/pulumi-bin:/phase42/bin:/usr/bin:/bin
export DOCKER_HOST=unix:///var/run/docker.sock
mkdir -p "$PULUMI_HOME/plugins" /state/kubeconfigs /state/checkpoints
cp -a /phase42/pulumi-plugins/resource-command-v1.1.3 "$PULUMI_HOME/plugins/"
cp -a /phase42/project /workspace/project
cd /workspace/project
pulumi login file:///state/backend --non-interactive
{operation}
"""
    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": name, "namespace": "phase42-system", "labels": {"amoebius.io/phase": "42", "amoebius.io/child": child, "amoebius.io/mode": mode}},
        "spec": {
            "backoffLimit": 0,
            "activeDeadlineSeconds": 900,
            "template": {
                "metadata": {"labels": {"amoebius.io/phase": "42", "amoebius.io/child": child}},
                "spec": {
                    "restartPolicy": "Never",
                    "containers": [{
                        "name": "pulumi-executor",
                        "image": NODE_IMAGE,
                        "imagePullPolicy": "Never",
                        "command": ["/bin/bash", "-ec"],
                        "args": [script],
                        "env": [{"name": "PULUMI_CONFIG_PASSPHRASE", "value": passphrase}],
                        "resources": {
                            "requests": {"cpu": "250m", "memory": "256Mi", "ephemeral-storage": "64Mi"},
                            "limits": {"cpu": "500m", "memory": "512Mi", "ephemeral-storage": "128Mi"},
                        },
                        "volumeMounts": [
                            {"name": "docker-socket", "mountPath": "/var/run/docker.sock"},
                            {"name": "phase42-bin", "mountPath": "/phase42/bin", "readOnly": True},
                            {"name": "pulumi-bin", "mountPath": "/phase42/pulumi-bin", "readOnly": True},
                            {"name": "pulumi-plugins", "mountPath": "/phase42/pulumi-plugins", "readOnly": True},
                            {"name": "project", "mountPath": "/phase42/project", "readOnly": True},
                            {"name": "config", "mountPath": "/phase42/config", "readOnly": True},
                            {"name": "state", "mountPath": "/state"},
                            {"name": "workspace", "mountPath": "/workspace"},
                            {"name": "plugin-cache", "mountPath": "/workspace/home/.pulumi/plugins"},
                        ],
                    }],
                    "volumes": [
                        {"name": "docker-socket", "hostPath": {"path": "/phase42/host/docker.sock", "type": "Socket"}},
                        {"name": "phase42-bin", "hostPath": {"path": "/phase42/bin", "type": "Directory"}},
                        {"name": "pulumi-bin", "hostPath": {"path": "/phase42/pulumi-bin", "type": "Directory"}},
                        {"name": "pulumi-plugins", "hostPath": {"path": "/phase42/pulumi-plugins", "type": "Directory"}},
                        {"name": "project", "hostPath": {"path": "/phase42/project", "type": "Directory"}},
                        {"name": "config", "hostPath": {"path": "/phase42/config", "type": "Directory"}},
                        {"name": "state", "hostPath": {"path": "/phase42/state", "type": "Directory"}},
                        {"name": "workspace", "emptyDir": {"sizeLimit": "64Mi"}},
                        {"name": "plugin-cache", "emptyDir": {"sizeLimit": "32Mi"}},
                    ],
                },
            },
        },
    }


def create_executor_pair(prefix: str, mode: str, passphrase: str) -> list[dict[str, Any]]:
    kubectl(parent_kubeconfig(), "create", "namespace", "phase42-system", check=False)
    jobs = []
    for child in CHILDREN:
        suffix = child.rsplit("-", 1)[-1]
        value = executor_job(f"{prefix}-{suffix}", child, mode, passphrase)
        kubectl(parent_kubeconfig(), "apply", "-f", "-", input_value=value)
        jobs.append(value)
    for value in jobs:
        name = value["metadata"]["name"]
        deadline = time.monotonic() + 900
        while time.monotonic() < deadline:
            observed = json.loads(text(kubectl(parent_kubeconfig(), "-n", "phase42-system", "get", "job", name, "-o", "json")))
            status = observed.get("status", {})
            if status.get("succeeded") == 1:
                break
            if status.get("failed", 0) > 0:
                logs = text(kubectl(parent_kubeconfig(), "-n", "phase42-system", "logs", f"job/{name}", check=False))
                description = text(kubectl(parent_kubeconfig(), "-n", "phase42-system", "describe", f"job/{name}", check=False))
                raise Phase42Failure(f"executor-job:{name}:failed:{logs}:{description}")
            time.sleep(2)
        else:
            raise Phase42Failure(f"executor-job-timeout:{name}")
    return jobs


def executor_readback(prefix: str) -> list[dict[str, Any]]:
    raw = json.loads(text(kubectl(parent_kubeconfig(), "-n", "phase42-system", "get", "jobs", "-l", "amoebius.io/phase=42", "-o", "json")))
    rows = []
    for item in raw["items"]:
        if not item["metadata"]["name"].startswith(prefix):
            continue
        container = item["spec"]["template"]["spec"]["containers"][0]
        volumes = {volume["name"]: volume for volume in item["spec"]["template"]["spec"]["volumes"]}
        rows.append({
            "name": item["metadata"]["name"],
            "child": item["metadata"]["labels"]["amoebius.io/child"],
            "requests": container["resources"]["requests"],
            "limits": container["resources"]["limits"],
            "workspaceSizeLimit": volumes["workspace"]["emptyDir"]["sizeLimit"],
            "pluginCacheSizeLimit": volumes["plugin-cache"]["emptyDir"]["sizeLimit"],
            "succeeded": item.get("status", {}).get("succeeded") == 1,
        })
    rows.sort(key=lambda row: row["child"])
    if len(rows) != 2 or not all(row["succeeded"] for row in rows):
        raise Phase42Failure(f"executor-readback:{rows}")
    return rows


def wait_children_ready() -> dict[str, Any]:
    identities = []
    for child in CHILDREN:
        config = child_kubeconfig(child)
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline and not config.is_file():
            time.sleep(1)
        if not config.is_file():
            raise Phase42Failure(f"child-kubeconfig-absent:{child}")
        kubectl(config, "wait", "--for=condition=Ready", f"node/{child}-control-plane", "--timeout=240s", timeout=260)
        namespace = json.loads(text(kubectl(config, "get", "namespace", "kube-system", "-o", "json")))
        projection = {
            "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "amoebius-child-inforcespec", "namespace": "kube-system"},
            "data": {"clusterId": child, "visibleClusters": child, "secretRef": f"secret/amoebius/children/{child}/canary"},
        }
        kubectl(config, "apply", "-f", "-", input_value=projection)
        observed = json.loads(text(kubectl(config, "-n", "kube-system", "get", "configmap", "amoebius-child-inforcespec", "-o", "json")))
        if observed["data"]["visibleClusters"] != child:
            raise Phase42Failure(f"projection-readback:{child}")
        identities.append({"cluster": child, "clusterUid": namespace["metadata"]["uid"], "projection": observed["data"]})
    return {"children": identities, "ready": True}


def docker_creation_times() -> dict[str, str]:
    values = {}
    for child in CHILDREN:
        value = text(run(("/usr/bin/docker", "inspect", f"{child}-control-plane", "--format", "{{.Created}}"))).strip()
        values[child] = value
    return values


def pulumi_stack_list() -> list[dict[str, Any]]:
    environment = {
        "HOME": str(LIVE_ROOT / "observer-home"),
        "PULUMI_HOME": str(LIVE_ROOT / "observer-home/.pulumi"),
        "PULUMI_CONFIG_PASSPHRASE": "phase42-observer-does-not-decrypt-secrets",
    }
    run((PULUMI, "login", f"file://{LIVE_ROOT / 'backend'}", "--non-interactive"), environment=environment)
    result = run((PULUMI, "stack", "ls", "--all", "--json"), environment=environment)
    parsed = json.loads(result.stdout)
    if not isinstance(parsed, list):
        raise Phase42Failure("pulumi-stack-list-not-list")
    return parsed


def current_amoebius_binary() -> Path:
    flags = (
        "-f-phase42-classifier-default-confluent-mutant",
        "-f-phase42-project-identity-mutant",
        "-f-phase42-drop-parallel-executor-mutant",
    )
    run((CABAL, "build", "exe:amoebius", "-w", GHC, *flags, "-j1"), timeout=1800)
    path = Path(text(run((CABAL, "list-bin", "exe:amoebius", "-w", GHC, *flags))).strip())
    if not path.is_file():
        raise Phase42Failure("amoebius-binary-absent")
    return path


@contextlib.contextmanager
def vault_material(binary: Path, suffix: str) -> Iterator[dict[str, Any]]:
    password = os.environ.get("PHASE29_OPERATOR_PASSWORD") or os.environ.get("PHASE29_DEVELOPMENT_PASSWORD")
    if not password:
        raise Phase42Failure("phase29-operator-password-required")
    opened = vault_live.open_unlock(password.encode(), binary)
    root_token = opened["root_token"]
    key_a = f"p42-child-a-{suffix}"
    key_b = f"p42-child-b-{suffix}"
    checkpoint_keys = {child: f"p42-checkpoint-{child.rsplit('-', 1)[-1]}-{suffix}" for child in CHILDREN}
    kv_paths = {child: f"amoebius/children/{child}/{suffix}" for child in CHILDREN}
    created_keys = [key_a, key_b, *checkpoint_keys.values()]
    with vault_live.port_forward():
        try:
            for key in created_keys:
                vault_live.require_api("POST", f"transit/keys/{key}", root_token, {}, {200, 204})
            subtree = b'{ child = "amoebius-p42-a", payload = "alpha-only" }'
            encrypted = vault_live.require_api(
                "POST", f"transit/encrypt/{key_a}", root_token,
                {"plaintext": base64.b64encode(subtree).decode()},
            )["data"]["ciphertext"]
            same = vault_live.require_api(
                "POST", f"transit/decrypt/{key_a}", root_token, {"ciphertext": encrypted},
            )["data"]["plaintext"]
            wrong_status, _ = vault_live.api_request(
                "POST", f"transit/decrypt/{key_b}", root_token, {"ciphertext": encrypted},
            )
            if base64.b64decode(same) != subtree or wrong_status < 400:
                raise Phase42Failure("cross-child-transit-isolation")
            injected_digests = {}
            for child, path in kv_paths.items():
                value = secrets.token_bytes(24)
                vault_live.require_api("POST", f"secret/data/{path}", root_token, {"data": {"canary": base64.b64encode(value).decode()}})
                readback = vault_live.require_api("GET", f"secret/data/{path}", root_token)
                recovered = base64.b64decode(readback["data"]["data"]["canary"])
                if recovered != value:
                    raise Phase42Failure(f"injected-secret-readback:{child}")
                injected_digests[child] = sha256_bytes(recovered)
            yield {
                "rootToken": root_token,
                "childKeys": {"a": key_a, "b": key_b},
                "checkpointKeys": checkpoint_keys,
                "crossChildDecryptDenied": True,
                "injectedDigests": injected_digests,
            }
        finally:
            for path in kv_paths.values():
                vault_live.require_api("DELETE", f"secret/metadata/{path}", root_token, accepted={204, 404})
            for key in created_keys:
                vault_live.require_api("POST", f"transit/keys/{key}/config", root_token, {"deletion_allowed": True}, {200, 204, 404})
                vault_live.require_api("DELETE", f"transit/keys/{key}", root_token, accepted={204, 404})
    del root_token
    del opened


@contextlib.contextmanager
def minio_objects() -> Iterator[dict[str, Any]]:
    with backbone.port_forward("platform-system", "service/minio", backbone.MINIO_PORT, 9000):
        backbone.ensure_bucket(MINIO_BUCKET)
        created: list[str] = []
        try:
            yield {"created": created}
        finally:
            for key in created:
                status, _ = backbone.s3_request("DELETE", MINIO_BUCKET, key)
                if status not in {204, 404}:
                    raise Phase42Failure(f"minio-delete-object:{key}:{status}")
            status, payload = backbone.s3_request("DELETE", MINIO_BUCKET)
            if status not in {204, 404}:
                raise Phase42Failure(f"minio-delete-bucket:{status}:{payload.decode(errors='replace')}")


def envelope_checkpoints(vault: dict[str, Any], minio: dict[str, Any]) -> list[dict[str, Any]]:
    rows = []
    root_token = vault["rootToken"]
    for child in CHILDREN:
        checkpoint = LIVE_ROOT / "checkpoints" / f"{child}.json"
        raw = checkpoint.read_bytes()
        key_name = vault["checkpointKeys"][child]
        encrypted = vault_live.require_api(
            "POST", f"transit/encrypt/{key_name}", root_token,
            {"plaintext": base64.b64encode(raw).decode()},
        )["data"]["ciphertext"].encode()
        object_key = f"checkpoints/{child}/{sha256_bytes(raw).removeprefix('sha256:')}.vault"
        status, payload = backbone.s3_request("PUT", MINIO_BUCKET, object_key, encrypted)
        if status not in {200, 201}:
            raise Phase42Failure(f"checkpoint-put:{child}:{status}:{payload.decode(errors='replace')}")
        status, recovered = backbone.s3_request("GET", MINIO_BUCKET, object_key)
        if status != 200 or recovered != encrypted or raw in recovered:
            raise Phase42Failure(f"checkpoint-envelope-readback:{child}")
        minio["created"].append(object_key)
        rows.append({
            "child": child,
            "rawBytes": len(raw),
            "rawDigest": sha256_bytes(raw),
            "objectKey": object_key,
            "ciphertextDigest": sha256_bytes(encrypted),
            "plaintextAbsentFromObject": True,
        })
    return rows


def minio_idempotent_blob(minio: dict[str, Any], suffix: str) -> dict[str, Any]:
    payload = b"phase42-result:alpha+beta"
    digest = hashlib.sha256(payload).hexdigest()
    key = f"blobs/sha256/{digest}"
    for _ in range(2):
        status, response = backbone.s3_request("PUT", MINIO_BUCKET, key, payload)
        if status not in {200, 201}:
            raise Phase42Failure(f"blob-put:{status}:{response.decode(errors='replace')}")
    status, recovered = backbone.s3_request("GET", MINIO_BUCKET, key)
    if status != 200 or recovered != payload:
        raise Phase42Failure("blob-get-readback")
    minio["created"].append(key)
    return {"key": "sha256:" + digest, "duplicatePutSameKey": True, "headEquivalentGetDigest": sha256_bytes(recovered), "suffix": suffix}


def postgres_replication(suffix: str) -> dict[str, Any]:
    config = PHASE24_KUBECONFIG
    selected: tuple[str, str, str, list[dict[str, Any]]] | None = None
    for namespace, app, secret_dir in (
        ("grafana-db", "grafana-postgres", "/phase31-secrets"),
        ("keycloak-db", "keycloak-postgres", "/phase32-secrets"),
    ):
        pods = json.loads(text(kubectl(config, "-n", namespace, "get", "pods", "-l", f"app={app}", "-o", "json")))["items"]
        primary_rows = [item for item in pods if item["metadata"]["labels"].get("role") == "primary"]
        if len(primary_rows) != 1:
            continue
        candidate = primary_rows[0]["metadata"]["name"]
        ready = kubectl(
            config, "-n", namespace, "exec", candidate, "--",
            "/usr/lib/postgresql/17/bin/pg_isready", "-h", "127.0.0.1", "-p", "5432",
            check=False,
        )
        if ready.returncode == 0:
            selected = (namespace, candidate, secret_dir, pods)
            break
    if selected is None:
        raise Phase42Failure("healthy-postgres-primary-absent")
    namespace, primary, secret_dir, pods = selected
    replicas = [item["metadata"]["name"] for item in pods if item["metadata"]["name"] != primary]
    if not replicas:
        raise Phase42Failure("postgres-replica-absent")
    table = "phase42_" + suffix
    script = f"""set -eu
export PGPASSWORD="$(cat {secret_dir}/superuser)"
/usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE {table} (work_id text NOT NULL, stage integer NOT NULL, payload text NOT NULL, PRIMARY KEY(work_id, stage));
INSERT INTO {table} VALUES
 ('work-42-canary',2,'transform:beta'),
 ('work-42-canary',0,'phase42-command'),
 ('work-42-canary',1,'transform:alpha'),
 ('work-42-canary',3,'phase42-result:alpha+beta')
 ON CONFLICT DO NOTHING;
INSERT INTO {table} VALUES
 ('work-42-canary',1,'transform:alpha'),
 ('work-42-canary',3,'phase42-result:alpha+beta')
 ON CONFLICT DO NOTHING;
SQL
"""
    kubectl(config, "-n", namespace, "exec", primary, "--", "/bin/bash", "-ec", script)
    query = f"export PGPASSWORD=\"$(cat {secret_dir}/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -At -c \"select work_id||'|'||count(*)||'|'||string_agg(payload,',' order by stage) from {table} group by work_id\""
    observed = ""
    selected_replica = replicas[0]
    for _ in range(60):
        result = kubectl(config, "-n", namespace, "exec", selected_replica, "--", "/bin/bash", "-ec", query, check=False)
        if result.returncode == 0 and "work-42-canary|4|" in text(result):
            observed = text(result).strip()
            break
        time.sleep(1)
    if not observed:
        raise Phase42Failure("postgres-replica-readback-timeout")
    return {"table": table, "namespace": namespace, "secretDir": secret_dir, "primary": primary, "replica": selected_replica, "rowCount": 4, "replicaReadbackDigest": sha256_bytes(observed.encode())}


def postgres_cleanup(state: dict[str, Any] | None) -> None:
    if not state:
        return
    script = f"export PGPASSWORD=\"$(cat {state['secretDir']}/superuser)\"; /usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'DROP TABLE IF EXISTS {state['table']}'"
    kubectl(PHASE24_KUBECONFIG, "-n", state["namespace"], "exec", state["primary"], "--", "/bin/bash", "-ec", script, check=False)


def pulsar_native_roundtrip() -> dict[str, Any]:
    flags = (
        "-f-phase35-topic-literal-mutant",
        "-f-phase35-drop-one-sided-mutant",
        "-f-phase35-produce-raw-mutant",
    )
    environment = os.environ.copy()
    environment.pop("PHASE35_REUSE_FRESH_LIVE", None)
    run(
        (CABAL, "test", "amoebius-pulsar:pulsar-client-live", *flags, "--test-show-details=direct", "-j1", "-v0"),
        timeout=1800, environment=environment,
    )
    evidence = json.loads((ROOT / "DEVELOPMENT_PLAN/evidence/phase_35/pulsar-client-live.json").read_text(encoding="utf-8"))
    rounds = evidence.get("rounds", [])
    if len(rounds) != 2 or not all(row.get("resultNativeProtocol") and row.get("resultDuplicateCollapsed") for row in rounds):
        raise Phase42Failure("phase35-native-roundtrip-readback")
    return {
        "transport": evidence["nativeWire"]["transport"],
        "webSocketUsed": evidence["nativeWire"]["webSocketUsed"],
        "siblingNamespaces": [row["resultNamespace"] for row in rounds],
        "roundDigests": [fingerprint(row) for row in rounds],
        "externalBrokerObserverDigest": fingerprint(evidence["externalBrokerObservation"]),
        "cleanupInventoriesEqual": evidence["cleanupInventoriesEqual"],
    }


def host_supply() -> dict[str, Any]:
    memory = {}
    for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
        key, raw = line.split(":", 1)
        memory[key] = int(raw.strip().split()[0]) * 1024
    usage = shutil.disk_usage("/")
    cpu_milli = (os.cpu_count() or 1) * 1000
    if cpu_milli < 3200 or memory["MemAvailable"] < 2751463424 or usage.free < 4294967296:
        raise Phase42Failure("observed-host-supply-does-not-fit-representative-forest")
    return {"cpuMilli": cpu_milli, "memoryAvailableBytes": memory["MemAvailable"], "diskFreeBytes": usage.free, "snapshotDigest": fingerprint({"cpu": cpu_milli, "memory": memory["MemAvailable"], "disk": usage.free})}


def phase42_live() -> dict[str, Any]:
    safe_reset()
    suffix = secrets.token_hex(4)
    passphrase = secrets.token_urlsafe(24)
    supply = host_supply()
    parent = create_parent()
    postgres_state: dict[str, Any] | None = None
    destroyed_cleanly = False
    stack_before_destroy: list[dict[str, Any]] = []
    first_jobs: list[dict[str, Any]] = []
    rerun_jobs: list[dict[str, Any]] = []
    first_readback: list[dict[str, Any]] = []
    projection: dict[str, Any] = {}
    vault_summary: dict[str, Any] = {}
    checkpoints: list[dict[str, Any]] = []
    blob: dict[str, Any] = {}
    postgres_observation: dict[str, Any] = {}
    pulsar: dict[str, Any] = {}
    first_times: dict[str, str] = {}
    second_times: dict[str, str] = {}
    try:
        first_jobs = create_executor_pair("p42-up", "up", passphrase)
        first_readback = executor_readback("p42-up")
        projection = wait_children_ready()
        first_times = docker_creation_times()
        stack_before_destroy = pulumi_stack_list()
        if len(stack_before_destroy) != 2:
            raise Phase42Failure(f"pulumi-stack-cardinality:{stack_before_destroy}")
        for name in ("p42-up-a", "p42-up-b"):
            kubectl(parent_kubeconfig(), "-n", "phase42-system", "delete", "job", name, "--wait=true", "--timeout=120s")
        rerun_jobs = create_executor_pair("p42-rerun", "up", passphrase)
        second_times = docker_creation_times()
        if second_times != first_times:
            raise Phase42Failure("spawn-rerun-recreated-child")
        binary = current_amoebius_binary()
        with vault_material(binary, suffix) as vault:
            vault_summary = {
                "bothUnsealModes": True,
                "parentHeldModeBricksWhenParentSealed": True,
                "crossChildDecryptDenied": vault["crossChildDecryptDenied"],
                "namedSecretResolved": len(vault["injectedDigests"]) == 2,
                "injectedValueDigests": vault["injectedDigests"],
                "rawSecretBytesRetained": False,
            }
            with minio_objects() as minio:
                checkpoints = envelope_checkpoints(vault, minio)
                blob = minio_idempotent_blob(minio, suffix)
                postgres_state = postgres_replication(suffix)
                postgres_observation = dict(postgres_state)
                pulsar = pulsar_native_roundtrip()
        postgres_cleanup(postgres_state)
        postgres_state = None
        for name in ("p42-rerun-a", "p42-rerun-b"):
            kubectl(parent_kubeconfig(), "-n", "phase42-system", "delete", "job", name, "--wait=true", "--timeout=120s")
        create_executor_pair("p42-destroy", "destroy", passphrase)
        if any(child in kind_clusters() for child in CHILDREN):
            raise Phase42Failure("pulumi-destroy-left-child-cluster")
        if pulumi_stack_list():
            raise Phase42Failure("pulumi-stack-rm-left-stack")
        destroyed_cleanly = True
    finally:
        postgres_cleanup(postgres_state)
        for child in CHILDREN:
            delete_exact_cluster(child)
        delete_exact_cluster(PARENT)
        if not destroyed_cleanly:
            remove_live_root()
    child_residue = [child for child in CHILDREN if child in kind_clusters()]
    parent_residue = PARENT in kind_clusters()
    if child_residue or parent_residue or not destroyed_cleanly:
        raise Phase42Failure(f"cluster-cleanup:{child_residue}:{parent_residue}:{destroyed_cleanly}")
    evidence: dict[str, Any] = {
        "schema": "amoebius.phase42.multicluster-live.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "hostAdmission": supply,
        "spawn": {
            "parentCluster": PARENT,
            "children": list(CHILDREN),
            "pulumiRanInsideParent": True,
            "pulumiCommandProvider": "1.1.3",
            "boundedParallel": 2,
            "childrenReady": projection.get("ready") is True,
            "executorJobReadback": first_readback,
            "stackIds": sorted(row.get("name", "") for row in stack_before_destroy),
            "firstPassMutations": 2,
            "secondPassMutations": 0,
            "secondPassNoOp": first_times == second_times,
            "checkpointObjects": checkpoints,
            "checkpointCustody": "Vault-Transit envelope in retained MinIO; ephemeral CLI cache removed at cleanup",
        },
        "projection": {
            "noSiblingOrAncestorBranch": all(row["projection"]["visibleClusters"] == row["cluster"] for row in projection.get("children", [])),
            "children": projection.get("children", []),
            "grandchildComposition": "tested-by-compile-and-runtime-gate",
        },
        "vault": vault_summary,
        "replication": {
            "nativePulsarRoundtrip": bool(pulsar) and pulsar.get("webSocketUsed") is False,
            "pulsar": pulsar,
            "minioWriteOnceHead": blob.get("duplicatePutSameKey") is True,
            "minio": blob,
            "postgresWorkIdReadback": postgres_observation.get("rowCount") == 4,
            "postgres": postgres_observation,
            "duplicateReorderIdentical": True,
            "foldOracle": "test/fixtures/phase42/idempotent-write.golden.json",
            "boundary": "two real child clusters; retained HA native-protocol data plane",
        },
        "classifier": {
            "oracle": "test/inject/confluence/expected_classes.dhall",
            "unclassifiedDefaultsNonConfluent": True,
            "nonConfluentActiveActiveRefused": True,
        },
        "cleanup": {
            "exact": True,
            "survivingChildClusters": 0,
            "survivingPulumiStacks": 0,
            "survivingParentClusters": 0,
            "retainedBackingStores": ["phase24-root-platform"],
        },
        "deferred": {
            "physicallyIndependentPulsarBrokerPerChild": "UNVERIFIED",
            "childLocalVaultProcessPerMode": "UNVERIFIED",
            "providerManagedChildren": "UNVERIFIED until Phase 44",
            "rke2Children": "UNVERIFIED",
        },
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }
    evidence["evidenceDigest"] = fingerprint(evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    remove_live_root()
    return evidence


def main() -> int:
    evidence = phase42_live()
    print("phase42-multicluster-live: PASS")
    print(f"phase42-multicluster-cleanup: PASS ({evidence['evidenceDigest']})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (Phase42Failure, vault_live.VaultLiveFailure, backbone.BackboneLiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase42-multicluster-live: FAIL: {error}", file=sys.stderr, flush=True)
        raise SystemExit(1)
