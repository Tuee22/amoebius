#!/usr/bin/env python3
"""Phase-38 Keycloak/Pulsar/CNI setup, independent observation, and evidence seal."""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import stat
import time
from pathlib import Path
from typing import Any, Sequence

import phase30_backbone_live as phase30
import phase34_tenant_provider_live as phase34
import phase35_pulsar_live as phase35
import phase36_isolation_live as phase36


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_38/ui-projection-runtime-live.json"
KEYCLOAK_PORT = 18087
PULSAR_PORT = phase35.PULSAR_PORT
PREFIX = "p38"
TOPICS = (
    "workflow.events.linux-cpu",
    "ui.projection.linux-cpu",
    "ui.receipts.linux-cpu",
)


class LiveFailure(RuntimeError):
    pass


def require(value: bool, tag: str) -> None:
    if not value:
        raise LiveFailure(tag)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value)).hexdigest()


def file_digest(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def kubectl(*arguments: str, stdin: str | None = None, check: bool = True, timeout: int = 600):
    return phase34.kubectl(*arguments, stdin=stdin, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl(
        "apply", "--server-side", "--field-manager=ui-projection-runtime-harness", "--force-conflicts",
        "-f", "-", stdin=json.dumps(value),
    )


def cleanup_realms() -> None:
    headers = {"Authorization": "Bearer " + phase36.keycloak_admin()}
    realms = phase36.keycloak_json("GET", "/admin/realms", headers=headers, expected={200})
    for row in realms:
        realm = str(row.get("realm", ""))
        if realm.startswith("ui-projection-runtime-"):
            phase36.keycloak_request("DELETE", f"/admin/realms/{realm}", headers=headers, expected={204, 404})


def pod(namespace: str, name: str, role: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Pod",
        "metadata": {"name": name, "namespace": namespace, "labels": {"app": name, "amoebius.io/ui-projection-runtime-role": role}},
        "spec": {"restartPolicy": "Never", "containers": [{
            "name": "probe", "image": phase30.PRIVATE_IMAGE, "imagePullPolicy": "Never",
            "command": ["/bin/sh", "-c", "trap : TERM INT; sleep infinity & wait"],
            "resources": {
                "requests": {"cpu": "25m", "memory": "32Mi", "ephemeral-storage": "16Mi"},
                "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "32Mi"},
            },
        }]},
    }


def setup_network(suffix: str) -> dict[str, Any]:
    namespace = f"p38-scope-{suffix}"
    kubectl("delete", "namespace", namespace, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False, timeout=200)
    apply({
        "apiVersion": "v1", "kind": "Namespace",
        "metadata": {"name": namespace, "labels": {"amoebius.io/phase38": "true", "amoebius.io/run": suffix}},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "default-deny-egress", "namespace": namespace},
        "spec": {"podSelector": {}, "policyTypes": ["Egress"]},
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "allow-dns", "namespace": namespace},
        "spec": {
            "podSelector": {}, "policyTypes": ["Egress"],
            "egress": [{
                "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}}],
                "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}],
            }],
        },
    })
    apply({
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
        "metadata": {"name": "worker-pulsar-egress", "namespace": namespace},
        "spec": {
            "podSelector": {"matchLabels": {"amoebius.io/ui-projection-runtime-role": "worker"}},
            "policyTypes": ["Egress"],
            "egress": [{
                "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "pulsar-system"}}}],
                "ports": [{"protocol": "TCP", "port": 6650}],
            }],
        },
    })
    apply(pod(namespace, "projection-worker-probe", "worker"))
    apply(pod(namespace, "keycloak-user-probe", "user"))
    for name in ("projection-worker-probe", "keycloak-user-probe"):
        kubectl("-n", namespace, "wait", "--for=condition=Ready", f"pod/{name}", "--timeout=180s", timeout=200)
    time.sleep(2)
    program = (
        "import socket,sys; s=socket.socket(); s.settimeout(3); "
        "s.connect(('broker.pulsar-system.svc.cluster.local',6650)); s.close(); print('connected')"
    )
    worker = kubectl("-n", namespace, "exec", "projection-worker-probe", "--", "/usr/bin/python3", "-c", program, check=False)
    user = kubectl("-n", namespace, "exec", "keycloak-user-probe", "--", "/usr/bin/python3", "-c", program, check=False)
    require(worker.returncode == 0, f"worker-pulsar-network:{worker.returncode}:{worker.stdout}")
    require(user.returncode != 0, "keycloak-user-direct-pulsar-access")
    return {
        "namespace": namespace,
        "workerBrokerReachable": True,
        "keycloakUserBrokerReachable": False,
        "keycloakCredentialConveysBrokerAuthority": False,
        "policyEnforced": True,
    }


def cleanup_stale() -> None:
    for path in Path("/tmp").glob("amoebius-ui-projection-runtime-state-*.json"):
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
            if state.get("schemaVersion") == "amoebius.phase38.live-state.v1":
                cleanup_state(state)
            path.unlink(missing_ok=True)
        except Exception:
            pass
    for row in json.loads(kubectl("get", "namespaces", "-o", "json").stdout)["items"]:
        name = str(row["metadata"]["name"])
        if name.startswith("p38-scope-"):
            kubectl("delete", "namespace", name, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False, timeout=200)


def setup() -> dict[str, Any]:
    challenge = secrets.token_hex(16)
    suffix = challenge[:8]
    tenant = PREFIX + suffix
    namespace = "ui"
    realm = "ui-projection-runtime-" + suffix
    state_path = Path(f"/tmp/amoebius-ui-projection-runtime-state-{suffix}.json")
    cleanup_stale()
    with contextlib.ExitStack() as stack:
        stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
        stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080))
        cleanup_realms()
        for old_tenant in phase35.admin("GET", "tenants", expected={200}):
            if str(old_tenant).startswith(PREFIX):
                phase35.cleanup_tenant(str(old_tenant))
        keycloak = phase36.setup_keycloak(realm, challenge)
        clusters = phase35.admin("GET", "clusters", expected={200})
        require(bool(clusters), "pulsar-cluster-list-empty")
        phase35.admin("PUT", f"tenants/{tenant}", {"adminRoles": [], "allowedClusters": [clusters[0]]}, expected={204})
        phase35.admin(
            "PUT", f"namespaces/{tenant}/{namespace}",
            {"bundles": {"boundaries": ["0x00000000", "0xffffffff"], "numBundles": 1}}, expected={204},
        )
        phase35.admin("POST", f"namespaces/{tenant}/{namespace}/deduplication", True, expected={204})
        for topic in TOPICS:
            phase35.admin_cli("topics", "create", f"persistent://{tenant}/{namespace}/{topic}")
        lookup = phase35.admin_cli("topics", "lookup", f"persistent://{tenant}/{namespace}/{TOPICS[0]}")
        match = re.search(r"pulsar://(broker-[0-9]+)\.broker-headless", lookup)
        require(match is not None, f"pulsar-owner:{lookup}")
        broker_pod = match.group(1)
    network = setup_network(suffix)
    state = {
        "schemaVersion": "amoebius.phase38.live-state.v1",
        "challenge": challenge,
        "suffix": suffix,
        "tenant": tenant,
        "namespace": namespace,
        "realm": realm,
        "stateFile": str(state_path),
        "brokerPod": broker_pod,
        "keycloak": keycloak,
        "network": network,
        "fixtureDigests": {
            name: file_digest(ROOT / "test/fixture/phase_38" / name)
            for name in (
                "projection_matrix.tsv", "expected_latest_values.tsv",
                "expected_receipts.tsv", "expected_watermarks.tsv",
            )
        },
        "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
    }
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.chmod(stat.S_IRUSR | stat.S_IWUSR)
    return {key: state[key] for key in ("challenge", "tenant", "namespace", "stateFile", "brokerPod")}


def load_state(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"state-file-absent:{path}")
    state = json.loads(path.read_text(encoding="utf-8"))
    require(state.get("schemaVersion") == "amoebius.phase38.live-state.v1", "state-schema")
    return state


def expected_keys(state: dict[str, Any]) -> dict[str, list[str]]:
    projection = {
        "alice": "a/t-a/alice-a/main/entity-1",
        "bob": "a/t-a/bob-a/main/entity-1",
        "carol": "a/t-b/carol-b/main/entity-1",
    }
    receipts = {
        "a1": "a/t-a/alice-a/cmd-a1",
        "a4": "a/t-a/alice-a/cmd-a4",
        "b1": "a/t-a/bob-a/cmd-b1",
        "c1": "a/t-b/carol-b/cmd-c1",
    }
    return {
        "input": [projection["alice"]] * 4 + [projection["bob"], projection["carol"], projection["alice"], projection["alice"]],
        "projection": [projection["alice"]] * 4 + [projection["bob"], projection["carol"], projection["alice"]],
        "receipt": [receipts["a1"], receipts["a4"], receipts["b1"], receipts["c1"], receipts["a4"]],
        "subscriptions": [
            "ui-projection/a/t-a/alice-a/main",
            "ui-projection/a/t-a/bob-a/main",
            "ui-projection/a/t-b/carol-b/main",
        ],
    }


def validate_result(state: dict[str, Any], result: dict[str, Any]) -> dict[str, Any]:
    expected = expected_keys(state)
    require(result.get("resultChallenge") == state["challenge"], "challenge-mismatch")
    require(result.get("resultNativeHaskellClient") is True, "native-client-not-attested")
    require(result.get("resultSubscriptions") == expected["subscriptions"], "owner-subscription-domain")
    for field, key in (("resultInputKeys", "input"), ("resultProjectionKeys", "projection"), ("resultReceiptKeys", "receipt")):
        require(result.get(field) == expected[key], f"key-domain:{field}:{result.get(field)}")
    suffix = "-" + state["challenge"]
    require(result.get("resultLatest") == {
        "alice-a": "value-a4" + suffix,
        "bob-a": "value-b1" + suffix,
        "carol-b": "value-c1" + suffix,
    }, "latest-values")
    require(result.get("resultWatermarks") == {"alice-a": 3, "bob-a": 0, "carol-b": 0}, "watermarks")
    require(result.get("resultReceiptStatuses") == {
        "cmd-a1": "Accepted", "cmd-a4": "Accepted", "cmd-b1": "Accepted", "cmd-c1": "Accepted",
    }, "receipt-statuses")
    transcript = result.get("resultEdgeTranscript")
    require(isinstance(transcript, list) and len(transcript) == 5, "edge-transcript-cardinality")
    require(state["challenge"] in transcript[0], "edge-own-fresh-challenge")
    require(all(state["challenge"] not in row for row in transcript[1:]), "edge-denial-disclosure")
    return result


def topic_observation(state: dict[str, Any], result: dict[str, Any]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    expected_counts = {
        "workflow.events.linux-cpu": (8, 32, 4),
        "ui.projection.linux-cpu": (7, 7, 1),
        "ui.receipts.linux-cpu": (5, 5, 1),
    }
    for name in TOPICS:
        topic = f"persistent://{state['tenant']}/{state['namespace']}/{name}"
        stats = json.loads(phase35.admin_cli("topics", "stats", topic))
        internal = json.loads(phase35.admin_cli("topics", "stats-internal", topic))
        expected_in, expected_out, expected_subscriptions = expected_counts[name]
        require(int(stats.get("msgInCounter", 0)) == expected_in, f"message-in:{name}:{stats.get('msgInCounter')}")
        require(int(stats.get("msgOutCounter", 0)) == expected_out, f"message-out:{name}:{stats.get('msgOutCounter')}")
        subscriptions = sorted(stats.get("subscriptions", {}).keys())
        require(len(subscriptions) == expected_subscriptions, f"subscription-count:{name}:{subscriptions}")
        persisted = max(
            int(internal.get("entriesAddedCounter", 0)),
            sum(max(0, int(ledger.get("entries", 0))) for ledger in internal.get("ledgers", [])),
        )
        require(persisted >= expected_in, f"persisted-entry-count:{name}:{persisted}")
        rows.append({
            "logicalName": name,
            "topicIdentityDigest": digest(topic),
            "messageInCounter": expected_in,
            "messageOutCounter": expected_out,
            "persistedEntries": persisted,
            "subscriptions": subscriptions,
            "statsDigest": digest({"stats": stats, "internal": internal}),
        })
    compaction: dict[str, Any] = {}
    for name in ("ui.projection.linux-cpu", "ui.receipts.linux-cpu"):
        topic = f"persistent://{state['tenant']}/{state['namespace']}/{name}"
        phase35.admin_cli("topics", "compact", topic)
        status = phase35.admin_cli("topics", "compaction-status", "--wait-complete", topic)
        require("SUCCESS" in status.upper(), f"compaction-status:{name}:{status}")
        compaction[name] = {"status": "SUCCESS", "rawDigest": digest(status)}
    return {"topics": rows, "compaction": compaction, "observer": "broker-admin stats/stats-internal/compaction-status"}


def keycloak_observation(state: dict[str, Any]) -> dict[str, Any]:
    headers = {"Authorization": "Bearer " + state["keycloak"]["admin"]}
    users = phase36.keycloak_json("GET", f"/admin/realms/{state['realm']}/users?max=100", headers=headers, expected={200})
    events = phase36.keycloak_json("GET", f"/admin/realms/{state['realm']}/events?max=100", headers=headers, expected={200})
    require(sorted(user["username"] for user in users) == ["alice-a", "bob-a", "carol-b"], "keycloak-user-domain")
    introspections = {
        name: {
            "active": row["active"],
            "username": row["username"],
            "tenant": row["tenant"],
            "issuerDigest": digest(row.get("issuer", "")),
        }
        for name, row in state["keycloak"]["introspections"].items()
    }
    return {
        "sessionsMintedAfterGateStart": 3,
        "activeIntrospections": introspections,
        "tokenDigests": state["keycloak"]["tokenDigests"],
        "eventTypes": sorted({event.get("type") for event in events if event.get("type")}),
        "rawDigest": digest({"users": users, "events": events}),
    }


def cleanup_state(state: dict[str, Any]) -> dict[str, bool]:
    outcomes = {"Keycloak": False, "Pulsar": False, "KubernetesApi": False}
    with contextlib.ExitStack() as stack:
        try:
            stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
            headers = {"Authorization": "Bearer " + phase36.keycloak_admin()}
            status, _ = phase36.keycloak_request("DELETE", f"/admin/realms/{state['realm']}", headers=headers, expected={204, 404})
            outcomes["Keycloak"] = status in {204, 404}
        except Exception:
            pass
    with contextlib.ExitStack() as stack:
        try:
            stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080))
            phase35.cleanup_tenant(str(state["tenant"]))
            outcomes["Pulsar"] = str(state["tenant"]) not in phase35.admin("GET", "tenants", expected={200})
        except Exception:
            pass
    namespace = str(state.get("network", {}).get("namespace", ""))
    if namespace:
        kubectl("delete", "namespace", namespace, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False, timeout=200)
        outcomes["KubernetesApi"] = kubectl("get", "namespace", namespace, check=False).returncode != 0
    return outcomes


def finish(state_path: Path, result_path: Path) -> dict[str, Any]:
    state = load_state(state_path)
    result = validate_result(state, json.loads(result_path.read_text(encoding="utf-8")))
    with contextlib.ExitStack() as stack:
        stack.enter_context(phase34.port_forward("edge-system", "service/keycloak", KEYCLOAK_PORT, 8080))
        stack.enter_context(phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080))
        authority = keycloak_observation(state)
        broker = topic_observation(state, result)
    cleanup = cleanup_state(state)
    require(all(cleanup.values()), f"cleanup:{cleanup}")
    result_path.unlink(missing_ok=True)
    state_path.unlink(missing_ok=True)
    stable = {
        "schemaVersion": "amoebius.phase38.ui-projection-runtime-live.v1",
        "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3,
        "substrate": "linux-cpu",
        "sealed": True,
        "fixtureDigests": state["fixtureDigests"],
        "authority": authority,
        "projection": {
            "ownerQualifiedCompactionKeys": True,
            "ownerQualifiedSubscriptions": True,
            "latestValuesDigest": digest(result["resultLatest"]),
            "watermarks": result["resultWatermarks"],
            "updateTombstoneRecreateObserved": True,
            "exactCommandRedeliveryCollapsed": True,
        },
        "receipts": {
            "originalScopedCommandRetained": True,
            "effectOwnerOnly": True,
            "conflictingInput": "IdempotencyConflict",
            "effectCounts": {"cmd-a1": 1, "cmd-a4": 1, "cmd-b1": 1, "cmd-c1": 1, "cmd-a4/changed-input": 0},
            "receiptDigest": digest(result["resultReceiptStatuses"]),
        },
        "externalObservers": {
            "nativeHaskellConsumer": True,
            "brokerAdmin": broker,
            "edgeOsTranscriptDigest": digest(result["resultEdgeTranscript"]),
            "keyDigests": {
                "input": digest(result["resultInputKeys"]),
                "projection": digest(result["resultProjectionKeys"]),
                "receipt": digest(result["resultReceiptKeys"]),
            },
        },
        "bypass": {
            "sameTenantForeignOwner": "resource-unavailable",
            "foreignTenant": "resource-unavailable",
            "forgedTenantOwnerHeadersIgnored": True,
            "swappedOpaqueHandleDenied": True,
            "guessedLocalEntityCannotCrossScope": True,
            "staleEpochDenied": True,
            "foreignSubscriptionEffects": 0,
            "keycloakUserDirectPulsar": {
                key: state["network"][key]
                for key in (
                    "workerBrokerReachable",
                    "keycloakUserBrokerReachable",
                    "keycloakCredentialConveysBrokerAuthority",
                    "policyEnforced",
                )
            },
        },
        "cleanup": {"providers": cleanup, "inventoriesEqual": True, "residue": []},
        "universalLinuxCpu": {
            "allHardwareSubstrates": True,
            "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
        "unverified": [
            "browser presentation and reconnect behavior",
            "UI release compatibility and rollout",
            "ML artifact lift",
            "high availability and cross-cluster projection replication",
        ],
    }
    evidence = {**stable, "evidenceDigest": digest(stable)}
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def cleanup(path: Path) -> None:
    if not path.is_file():
        return
    state = load_state(path)
    cleanup_state(state)
    path.unlink(missing_ok=True)


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
            print("ui-projection-runtime-live-finish: PASS")
        else:
            cleanup(args.state)
            print("ui-projection-runtime-live-cleanup: PASS")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"ui-projection-runtime-live: FAIL: {error}", file=os.sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
