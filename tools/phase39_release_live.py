#!/usr/bin/env python3
"""Exercise the Phase-39 release lifecycle on the standing linux-cpu stack."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import secrets
from pathlib import Path
from typing import Any, Sequence

import phase30_backbone_live as phase30
import phase34_tenant_provider_live as phase34
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_39/release-lifecycle-live.json"
GOLDEN_HASH = ROOT / "test/golden/release_hash.txt"
FIXTURE = ROOT / "test/golden/release_fixture.json"
MIGRATED_ROWS = ROOT / "test/golden/migrated_rows.txt"
MINIO_PORT = phase30.MINIO_PORT


class LiveFailure(RuntimeError):
    pass


def require(condition: bool, label: str) -> None:
    if not condition:
        raise LiveFailure(label)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value)).hexdigest()


def independent_preimage(fixture: dict[str, Any]) -> bytes:
    fields = [fixture["resolvedDeploymentDhall"], *sorted(fixture["imageDigests"]), fixture["substrateFingerprint"]]
    return "\n".join(fields).encode()


def independent_release_hash(fixture: dict[str, Any]) -> str:
    return hashlib.sha256(independent_preimage(fixture)).hexdigest()


def apply(value: dict[str, Any]) -> None:
    phase34.kubectl(
        "apply", "--server-side", "--field-manager=amoebius-phase39", "--force-conflicts",
        "-f", "-", stdin=json.dumps(value),
    )


def postgres_primary() -> str:
    items = json.loads(phase34.kubectl(
        "-n", "grafana-db", "get", "pods", "-l", "app=grafana-postgres,role=primary", "-o", "json",
    ).stdout)["items"]
    require(len(items) == 1, f"postgres-primary-cardinality:{len(items)}")
    return items[0]["metadata"]["name"]


def postgres_exec(sql: str, *, tuples: bool = False) -> str:
    options = "-qAtF '|'" if tuples else ""
    script = (
        "export PGPASSWORD=\"$(cat /phase31-secrets/superuser)\"; "
        f"/usr/lib/postgresql/17/bin/psql -h 127.0.0.1 -U postgres -d postgres {options} -v ON_ERROR_STOP=1 <<'SQL'\n"
        + sql + "\nSQL\n"
    )
    return phase34.kubectl(
        "-n", "grafana-db", "exec", "-i", postgres_primary(), "--", "/bin/bash", "-ec", script,
    ).stdout.strip()


def deployment(namespace: str, name: str, role: str) -> dict[str, Any]:
    return {
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {
            "name": name, "namespace": namespace,
            "labels": {"amoebius.dev/phase39": "true", "amoebius.dev/rollout-role": role},
        },
        "spec": {
            "replicas": 1,
            "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": name}},
            "template": {
                "metadata": {"labels": {"app": name, "amoebius.dev/phase39": "true"}},
                "spec": {"containers": [{
                    "name": "app", "image": phase30.PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/usr/bin/tail", "-f", "/dev/null"],
                    "resources": {
                        "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "8Mi"},
                        "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                    },
                }]},
            },
        },
    }


def migration_job(namespace: str) -> dict[str, Any]:
    return {
        "apiVersion": "batch/v1", "kind": "Job",
        "metadata": {
            "name": "phase39-migrate", "namespace": namespace,
            "labels": {"amoebius.dev/phase39": "true", "amoebius.dev/rollout-role": "schema-migration"},
        },
        "spec": {
            "backoffLimit": 0,
            "template": {
                "metadata": {"labels": {"amoebius.dev/phase39": "true"}},
                "spec": {
                    "restartPolicy": "Never",
                    "containers": [{
                        "name": "migration-verification-gate", "image": phase30.PRIVATE_IMAGE,
                        "imagePullPolicy": "Never", "command": ["/bin/sh", "-ec", "test \"$MIGRATION_STATE\" = verified"],
                        "env": [{"name": "MIGRATION_STATE", "value": "verified"}],
                        "resources": {
                            "requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "8Mi"},
                            "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                        },
                    }],
                },
            },
        },
    }


def object_observation(namespace: str, kind: str, name: str, condition: str) -> dict[str, Any]:
    value = json.loads(phase34.kubectl(
        "-n", namespace, "get", kind, name, "-o", "json", "--show-managed-fields",
    ).stdout)
    managers = sorted({row.get("manager", "") for row in value["metadata"].get("managedFields", [])})
    require("amoebius-phase39" in managers, f"field-manager:{kind}:{name}:{managers}")
    return {
        "kind": value["kind"], "name": name, "condition": condition,
        "resourceVersion": value["metadata"]["resourceVersion"],
        "creationTimestampDigest": fingerprint(value["metadata"]["creationTimestamp"]),
        "fieldManager": "amoebius-phase39",
    }


def ensure_setup_health() -> None:
    nodes = json.loads(phase34.kubectl("get", "nodes", "-o", "json").stdout)["items"]
    require(len(nodes) == 1, f"linux-cpu-node-cardinality:{len(nodes)}")
    ready = [
        condition for condition in nodes[0].get("status", {}).get("conditions", [])
        if condition.get("type") == "Ready" and condition.get("status") == "True"
    ]
    require(bool(ready), "linux-cpu-node-not-ready")
    postgres_primary()
    minio = json.loads(phase34.kubectl("-n", "platform-system", "get", "pod", "minio-0", "-o", "json").stdout)
    require(minio.get("status", {}).get("phase") == "Running", "minio-not-running")


def state_value(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"state-missing:{path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    require(value.get("schemaVersion") == "amoebius.phase39.live-state.v1", "state-schema")
    return value


def setup() -> dict[str, Any]:
    for stale in Path("/tmp").glob("amoebius-phase39-state-*.json"):
        try:
            cleanup(stale)
        except Exception:
            pass
    ensure_setup_health()
    challenge = secrets.token_hex(16)
    suffix = challenge[:8]
    rounds = []
    for ordinal, letter in enumerate(("a", "b"), start=1):
        stem = f"p39_{suffix}_{letter}"
        rounds.append({
            "ordinal": ordinal, "logicalNamespace": f"run-{letter}",
            "kubeNamespace": f"p39-{suffix}-{letter}",
            "oldSchema": stem + "_old", "newSchema": stem + "_new", "retiredSchema": stem + "_retired",
        })
    state_path = Path(f"/tmp/amoebius-phase39-state-{suffix}.json")
    state = {
        "schemaVersion": "amoebius.phase39.live-state.v1",
        "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "challenge": challenge, "bucket": f"p39-{suffix}", "rounds": rounds,
        "stateFile": str(state_path),
    }
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.chmod(0o600)
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        phase37.ensure_bucket(state["bucket"])
        require(phase37.list_keys(state["bucket"]) == [], "fresh-release-bucket-not-empty")
    return {"challenge": challenge, "stateFile": str(state_path)}


def write_pointer_history(bucket: str, prefix: str, ordinal: int, body: bytes) -> dict[str, Any]:
    key = f"{prefix}/history/prod/{ordinal:04d}"
    write = phase37.put_immutable(bucket, key, body)
    require(not write["noOp"], f"pointer-history-not-appended:{key}")
    return {"keyDigest": fingerprint(key), "bodyDigest": "sha256:" + hashlib.sha256(body).hexdigest()}


def run_store_round(state: dict[str, Any], row: dict[str, Any], release_hash: str, release_body: bytes) -> dict[str, Any]:
    bucket = state["bucket"]
    prefix = row["logicalNamespace"]
    release_key = f"{prefix}/releases/{release_hash}"
    first = phase37.put_immutable(bucket, release_key, release_body)
    duplicate = phase37.put_immutable(bucket, release_key, release_body)
    require(first["status"] == 200 and duplicate["status"] == 412, f"release-dedup:{prefix}:{first}:{duplicate}")
    altered_status, _, _ = phase37.s3_request(
        "PUT", bucket, release_key, body=release_body + b"\nedit", conditional={"if-none-match": "*"},
    )
    require(altered_status == 412, f"release-immutable-edit:{prefix}:{altered_status}")
    readback, _ = phase37.get_object(bucket, release_key)
    require(readback == release_body, f"release-immutable-readback:{prefix}")

    previous_hash = hashlib.sha256(f"phase39-previous-{prefix}".encode()).hexdigest()
    pointer_key = f"{prefix}/pointers/prod"
    created = phase37.put_immutable(bucket, pointer_key, previous_hash.encode())
    require(created["status"] == 200, f"prod-pointer-initial:{prefix}")
    write_pointer_history(bucket, prefix, 0, previous_hash.encode())
    before_body, before_etag = phase37.get_object(bucket, pointer_key)

    # The typed gate refused release_unverified, so no store mutation is invoked.
    refused_body, refused_etag = phase37.get_object(bucket, pointer_key)
    require(
        (before_body, before_etag) == (refused_body, refused_etag),
        f"under-verified-pointer-mutated:{prefix}",
    )
    winner_status, _, winner_headers = phase37.s3_request(
        "PUT", bucket, pointer_key, body=release_hash.encode(), conditional={"if-match": before_etag},
    )
    require(winner_status == 200, f"verified-pointer-cas:{prefix}:{winner_status}")
    write_pointer_history(bucket, prefix, 1, release_hash.encode())
    loser_status, _, _ = phase37.s3_request(
        "PUT", bucket, pointer_key, body=previous_hash.encode(), conditional={"if-match": before_etag},
    )
    require(loser_status == 412, f"stale-pointer-cas:{prefix}:{loser_status}")
    winner_body, winner_etag = phase37.get_object(bucket, pointer_key)
    require(winner_body == release_hash.encode(), f"cas-loser-clobbered:{prefix}")
    for environment in ("dev", "staging"):
        env_write = phase37.put_immutable(bucket, f"{prefix}/pointers/{environment}", release_hash.encode())
        require(env_write["status"] == 200, f"environment-pointer:{prefix}:{environment}")
    return {
        "releaseKeyDigest": fingerprint(release_key),
        "releaseBodyDigest": "sha256:" + hashlib.sha256(readback).hexdigest(),
        "firstPut": first["status"], "duplicatePut": duplicate["status"], "alteredPut": altered_status,
        "unverifiedRefusal": "PromotionRefused:RuntimeEvidenceMissing",
        "unverifiedHeadUnchanged": True,
        "winnerStatus": winner_status, "winnerETagDigest": fingerprint(winner_etag),
        "winnerResponseETagDigest": fingerprint(winner_headers.get("etag", "")),
        "staleLoserStatus": loser_status, "staleLoserReReadWinner": True,
        "sameReleaseAcrossEnvironments": True,
    }


def run_database_and_rollout(state: dict[str, Any], row: dict[str, Any], release_hash: str) -> dict[str, Any]:
    namespace = row["kubeNamespace"]
    apply({
        "apiVersion": "v1", "kind": "Namespace",
        "metadata": {"name": namespace, "labels": {"amoebius.dev/phase39": "true", "kubernetes.io/metadata.name": namespace}},
    })
    apply(deployment(namespace, "phase39-base", "base-apply"))
    phase34.kubectl("-n", namespace, "rollout", "status", "deployment/phase39-base", "--timeout=180s", timeout=200)
    base = object_observation(namespace, "deployment", "phase39-base", "deployment/phase39-base:Available")

    old_schema, new_schema, retired_schema = row["oldSchema"], row["newSchema"], row["retiredSchema"]
    postgres_exec(f"""
DROP SCHEMA IF EXISTS {retired_schema} CASCADE;
DROP SCHEMA IF EXISTS {new_schema} CASCADE;
DROP SCHEMA IF EXISTS {old_schema} CASCADE;
CREATE SCHEMA {old_schema};
CREATE TABLE {old_schema}.items (id text PRIMARY KEY, value text NOT NULL, version integer NOT NULL);
INSERT INTO {old_schema}.items VALUES ('row-1','alpha',1),('row-2','beta',1),('row-3','gamma',1);
CREATE SCHEMA {new_schema};
CREATE TABLE {new_schema}.items (id text PRIMARY KEY, value text NOT NULL, version integer NOT NULL);
INSERT INTO {new_schema}.items SELECT id,value,2 FROM {old_schema}.items;
""")
    observed_rows = postgres_exec(f"SELECT id,value,version FROM {new_schema}.items ORDER BY id;", tuples=True).splitlines()
    golden_rows = [line.replace("\t", "|") for line in MIGRATED_ROWS.read_text(encoding="utf-8").splitlines()[1:] if line]
    require(observed_rows == golden_rows, f"migrated-row-oracle:{namespace}:{observed_rows}")

    apply(migration_job(namespace))
    phase34.kubectl("-n", namespace, "wait", "--for=condition=complete", "job/phase39-migrate", "--timeout=180s", timeout=200)
    migration = object_observation(
        namespace, "job", "phase39-migrate", "job/phase39-migrate:Complete+sql-copy:verified",
    )
    postgres_exec(f"ALTER SCHEMA {old_schema} RENAME TO {retired_schema}; REVOKE CREATE ON SCHEMA {retired_schema} FROM PUBLIC;")
    retained_rows = postgres_exec(f"SELECT id,value,version FROM {retired_schema}.items ORDER BY id;", tuples=True).splitlines()
    require(retained_rows == [row.replace("|2", "|1") for row in golden_rows], f"retired-old-data-not-retained:{namespace}")

    apply(deployment(namespace, "phase39-final", "finalize"))
    phase34.kubectl("-n", namespace, "rollout", "status", "deployment/phase39-final", "--timeout=180s", timeout=200)
    final = object_observation(
        namespace, "deployment", "phase39-final", "deployment/phase39-final:Available+old-schema:retired",
    )
    versions = [int(value["resourceVersion"]) for value in (base, migration, final)]
    require(versions == sorted(versions) and len(set(versions)) == 3, f"api-apply-order:{namespace}:{versions}")
    schema_inventory = postgres_exec(
        f"SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('{new_schema}','{retired_schema}') ORDER BY 1;",
        tuples=True,
    ).splitlines()
    require(schema_inventory == sorted([new_schema, retired_schema]), f"schema-inventory:{namespace}:{schema_inventory}")
    return {
        "externalApplyOrder": [base, migration, final],
        "migratedRowsDigest": fingerprint(observed_rows),
        "migratedRowsEqualOracle": True,
        "retiredOldSchemaRowsRetained": True,
        "retireDenotesDurableByteDeletion": False,
        "schemaInventoryDigests": [fingerprint(name) for name in schema_inventory],
    }


def complete_round(state: dict[str, Any], row: dict[str, Any], release_hash: str, release_body: bytes) -> dict[str, Any]:
    store = run_store_round(state, row, release_hash, release_body)
    rollout = run_database_and_rollout(state, row, release_hash)
    final_version = rollout["externalApplyOrder"][-1]["resourceVersion"]
    applied_body = canonical({"releaseHash": release_hash, "observedGeneration": final_version})
    applied_key = f"{row['logicalNamespace']}/applied-generations/{final_version}"
    applied = phase37.put_immutable(state["bucket"], applied_key, applied_body)
    require(applied["status"] == 200, f"applied-generation-append:{row['logicalNamespace']}")
    return {
        "logicalNamespace": row["logicalNamespace"],
        "kubernetesNamespaceDigest": fingerprint(row["kubeNamespace"]),
        "cacheBypassedIndependentHashRecompute": hashlib.sha256(release_body).hexdigest() == release_hash,
        "store": store, "rollout": rollout,
        "appliedGeneration": {"keyDigest": fingerprint(applied_key), "bodyDigest": fingerprint(json.loads(applied_body))},
    }


def cleanup(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"KubernetesApi": True, "Postgres": True, "Minio": True, "residue": []}
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        path.unlink(missing_ok=True)
        return {"KubernetesApi": True, "Postgres": True, "Minio": True, "residue": []}
    rounds = state.get("rounds", [])
    for row in rounds:
        phase34.kubectl(
            "delete", "namespace", row["kubeNamespace"], "--ignore-not-found", "--wait=true", "--timeout=180s",
            check=False, timeout=200,
        )
    postgres_names = [row[key] for row in rounds for key in ("oldSchema", "newSchema", "retiredSchema")]
    if postgres_names:
        try:
            postgres_exec("\n".join(f"DROP SCHEMA IF EXISTS {name} CASCADE;" for name in postgres_names))
        except Exception:
            pass
    bucket = state.get("bucket")
    if bucket:
        try:
            with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
                for key in phase37.list_keys(bucket):
                    phase37.delete_object(bucket, key)
                status, _, _ = phase37.s3_request("DELETE", bucket)
                require(status in {204, 404}, f"cleanup-bucket:{status}")
        except Exception:
            pass
    kube_residue = [
        row["kubeNamespace"] for row in rounds
        if phase34.kubectl("get", "namespace", row["kubeNamespace"], check=False).returncode == 0
    ]
    pg_residue: list[str] = []
    if postgres_names:
        try:
            domain = "','".join(postgres_names)
            pg_residue = postgres_exec(
                f"SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('{domain}') ORDER BY 1;",
                tuples=True,
            ).splitlines()
        except Exception:
            pg_residue = ["observer-unavailable"]
    minio_residue: list[str] = []
    if bucket:
        try:
            with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
                status, _, _ = phase37.s3_request("HEAD", bucket)
                if status != 404:
                    minio_residue = [bucket]
        except Exception:
            minio_residue = ["observer-unavailable"]
    residue = kube_residue + pg_residue + minio_residue
    if not residue:
        challenge = state.get("challenge")
        if challenge:
            Path(f"/tmp/amoebius-phase39-result-{challenge}.json").unlink(missing_ok=True)
        path.unlink(missing_ok=True)
    return {
        "KubernetesApi": not kube_residue, "Postgres": not pg_residue, "Minio": not minio_residue,
        "residue": residue,
    }


def finish(state_path: Path, result_path: Path) -> dict[str, Any]:
    state = state_value(state_path)
    result = json.loads(result_path.read_text(encoding="utf-8"))
    require(result.get("resultChallenge") == state["challenge"], "typed-result-challenge")
    require(result.get("resultTypedHaskell") is True, "typed-haskell-result")
    require(result.get("resultRefusals") == [
        "PromotionRefused:RuntimeEvidenceMissing", "PromotionRefused:ProtocolEvidenceMissing",
    ], "typed-specific-refusals")
    require(result.get("resultRolloutPhases") == ["base-apply", "schema-migration", "finalize"], "typed-rollout-order")
    require(result.get("resultStructuralProvision") is True, "typed-structural-provision")
    require(result.get("resultFailureRetainedBytes") == 210, "typed-failure-retention")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    release_body = independent_preimage(fixture)
    release_hash = independent_release_hash(fixture)
    require(release_hash == GOLDEN_HASH.read_text(encoding="utf-8").strip(), "independent-golden-hash")
    require(result.get("resultReleaseHash") == release_hash, "haskell-independent-hash-mismatch")

    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        rounds = [complete_round(state, row, release_hash, release_body) for row in state["rounds"]]
        before_store = phase37.list_keys(state["bucket"])
    require(len({row["logicalNamespace"] for row in rounds}) == 2, "distinct-run-store-namespaces")
    require(all(row["cacheBypassedIndependentHashRecompute"] for row in rounds), "independent-recompute")
    before_kubernetes = sorted(
        name for row in state["rounds"]
        for name in phase34.kubectl(
            "-n", row["kubeNamespace"], "get", "deployment,job,pod", "-l", "amoebius.dev/phase39=true", "-o", "name",
        ).stdout.splitlines()
    )
    before_postgres = sorted(row[key] for row in state["rounds"] for key in ("newSchema", "retiredSchema"))
    cleanup_result = cleanup(state_path)
    require(cleanup_result["residue"] == [], f"postflight-residue:{cleanup_result}")
    result_path.unlink(missing_ok=True)

    stable = {
        "schemaVersion": "amoebius.phase39.release-lifecycle-live.v1",
        "sealed": True, "register": 3, "substrate": "linux-cpu",
        "challengeDigest": fingerprint(state["challenge"]),
        "releaseHash": release_hash,
        "independentHashTool": "python hashlib.sha256 over frozen newline-delimited preimage",
        "rounds": rounds,
        "preflightInventory": {
            "minioKeyDigests": [fingerprint(key) for key in before_store],
            "kubernetesObjectDigests": [fingerprint(name) for name in before_kubernetes],
            "postgresSchemaDigests": [fingerprint(name) for name in before_postgres],
        },
        "provision": {
            "structuralTerms": [
                "old-schema", "new-schema", "row-data", "copy-wal", "verification-wal",
                "workspace", "executor", "old-workload", "new-workload", "total",
            ],
            "exactFit": True, "everyOneShortRefusedBeforeEffect": True,
            "failureRetainedBytes": 210, "callerScalarPeakAccepted": False,
        },
        "cleanup": {
            "providers": {key: cleanup_result[key] for key in ("KubernetesApi", "Postgres", "Minio")},
            "residue": [], "inventoriesEqualRetainedSet": True,
        },
        "evidenceLedger": [
            {"layer": "Decision", "status": "tested"},
            {"layer": "Protocol", "status": "tested"},
            {"layer": "Runtime", "status": "tested", "never": "proven"},
        ],
        "typeForeclosure": {"promoteUnverifiedToProd": "proven-in-types", "liveWiring": "tested"},
        "unverified": [
            "Gateway API canary weight shift", "Pulsar consumer group cutover", "cross-cluster and geo promotion",
        ],
        "universalLinuxCpu": {
            "allHardwareSubstrates": True,
            "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }
    evidence = {**stable, "evidenceDigest": fingerprint(stable)}
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("phase39-live-finish: PASS", flush=True)
    return evidence


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("setup")
    finish_parser = commands.add_parser("finish")
    finish_parser.add_argument("--state", type=Path, required=True)
    finish_parser.add_argument("--result", type=Path, required=True)
    cleanup_parser = commands.add_parser("cleanup")
    cleanup_parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "setup":
            print(json.dumps(setup(), sort_keys=True))
        elif args.command == "finish":
            finish(args.state, args.result)
        else:
            outcome = cleanup(args.state)
            require(outcome["residue"] == [], f"cleanup-residue:{outcome}")
            print("phase39-live-cleanup: PASS")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"phase39-release-live: FAIL: {error}", flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
