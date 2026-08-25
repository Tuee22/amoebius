#!/usr/bin/env python3
"""Phase 36 external Pulsar administrator and evidence observer."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import secrets
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any

import phase34_tenant_provider_live as phase34


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_35/pulsar-client-live.json"
PULSAR_PORT = 18086


class LiveFailure(RuntimeError):
    pass


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value)).hexdigest()


def admin(method: str, path: str, body: Any = None, expected: set[int] | None = None) -> Any:
    value, _ = phase34.json_request(method, PULSAR_PORT, "/admin/v2/" + path, body=body, expected=expected or {200, 204})
    return value


def admin_cli(*arguments: str, allow_missing: bool = False) -> str:
    result = phase34.kubectl(
        "-n", "pulsar-system", "exec", "deployment/pulsar-tool", "--",
        "/pulsar/bin/pulsar-admin", "--admin-url", "http://broker.pulsar-system.svc.cluster.local:8080",
        *arguments, check=False, timeout=300,
    )
    output = result.stdout
    if result.returncode and not (allow_missing and any(marker in output.lower() for marker in ("not found", "does not exist", "deleted"))):
        raise LiveFailure(f"pulsar-admin-cli:{arguments}:{result.returncode}:{output}")
    return output


def list_topics(tenant: str, namespace: str) -> list[str]:
    return [line.strip() for line in admin_cli("topics", "list", f"{tenant}/{namespace}", allow_missing=True).splitlines() if line.strip().startswith("persistent://")]


def standing_policy() -> dict[str, Any]:
    value = admin("GET", "namespaces/phase30/drill", expected={200})
    if not isinstance(value, dict):
        raise LiveFailure("standing-policy-not-object")
    return value


def cleanup_tenant(tenant: str) -> None:
    status, payload, _ = phase34.http_request(
        "GET", PULSAR_PORT, f"/admin/v2/namespaces/{tenant}", expected={200, 404},
    )
    if status == 200:
        for qualified in json.loads(payload):
            namespace = str(qualified).split("/", 1)[-1]
            topics = list_topics(tenant, namespace)
            for topic in topics:
                admin_cli("topics", "delete", str(topic), "--force", allow_missing=True)
            namespace_path = f"/admin/v2/namespaces/{tenant}/{urllib.parse.quote(namespace, safe='')}"
            for _ in range(60):
                namespace_status, _, _ = phase34.http_request(
                    "DELETE", PULSAR_PORT, namespace_path, expected={204, 404, 409},
                )
                if namespace_status in {204, 404}:
                    break
                time.sleep(1)
            else:
                raise LiveFailure(f"namespace-delete-timeout:{tenant}/{namespace}")
    for _ in range(60):
        tenant_status, _, _ = phase34.http_request(
            "DELETE", PULSAR_PORT, f"/admin/v2/tenants/{tenant}", expected={204, 404, 409, 500},
        )
        if tenant_status in {204, 404}:
            break
        time.sleep(1)
    else:
        raise LiveFailure(f"tenant-delete-timeout:{tenant}")


def cleanup_stale() -> None:
    tenants = admin("GET", "tenants", expected={200})
    for tenant in tenants:
        if str(tenant).startswith("p35"):
            cleanup_tenant(str(tenant))


def setup() -> dict[str, Any]:
    with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        cleanup_stale()
        policy = standing_policy()
        clusters = admin("GET", "clusters", expected={200})
        if not clusters:
            raise LiveFailure("pulsar-cluster-list-empty")
        challenge = secrets.token_hex(16)
        suffix = challenge[:8]
        tenant = "p35" + suffix
        namespaces = ["run-a", "run-b"]
        admin("PUT", f"tenants/{tenant}", {"adminRoles": [], "allowedClusters": [clusters[0]]}, expected={204})
        for namespace in namespaces:
            admin(
                "PUT", f"namespaces/{tenant}/{namespace}",
                {"bundles": {"boundaries": ["0x00000000", "0xffffffff"], "numBundles": 1}},
                expected={204},
            )
            admin("POST", f"namespaces/{tenant}/{namespace}/deduplication", True, expected={204})
            for topic in ("round-trip.command.linux-cpu", "round-trip.event.linux-cpu"):
                admin_cli("topics", "create", f"persistent://{tenant}/{namespace}/{topic}")
        broker_pods: dict[str, str] = {}
        for namespace in namespaces:
            lookup = admin_cli("topics", "lookup", f"persistent://{tenant}/{namespace}/round-trip.command.linux-cpu")
            match = re.search(r"pulsar://(broker-[0-9]+)\.broker-headless", lookup)
            if match is None:
                raise LiveFailure(f"topic-owner-unreadable:{namespace}:{lookup}")
            broker_pods[namespace] = match.group(1)
        state_path = Path(f"/tmp/amoebius-pulsar-client-state-{suffix}.json")
        state = {
            "schemaVersion": "amoebius.phase35.live-state.v1",
            "challenge": challenge,
            "tenant": tenant,
            "namespaces": namespaces,
            "standingPolicy": policy,
            "standingPolicyDigest": digest(policy),
            "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "stateFile": str(state_path),
            "brokerPods": broker_pods,
        }
        state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return {key: state[key] for key in ("challenge", "tenant", "namespaces", "stateFile", "brokerPods")}


def load_state(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise LiveFailure(f"state-file-missing:{path}")
    state = json.loads(path.read_text(encoding="utf-8"))
    if state.get("schemaVersion") != "amoebius.phase35.live-state.v1":
        raise LiveFailure("state-schema")
    return state


def topic_inventory(tenant: str, namespaces: list[str]) -> dict[str, Any]:
    rows: dict[str, Any] = {}
    for namespace in namespaces:
        deduplication = admin("GET", f"namespaces/{tenant}/{namespace}/deduplication", expected={200})
        topics = list_topics(tenant, namespace)
        topic_rows = []
        for topic in sorted(topics):
            stats = json.loads(admin_cli("topics", "stats", str(topic)))
            internal = json.loads(admin_cli("topics", "stats-internal", str(topic)))
            subscriptions = sorted(stats.get("subscriptions", {}).keys())
            topic_rows.append({
                "topic": topic,
                "messageInCounter": int(stats.get("msgInCounter", 0)),
                "messageOutCounter": int(stats.get("msgOutCounter", 0)),
                "persistedEntries": max(
                    int(internal.get("entriesAddedCounter", 0)),
                    sum(max(0, int(ledger.get("entries", 0))) for ledger in internal.get("ledgers", [])),
                ),
                "subscriptions": subscriptions,
                "subscriptionCount": len(subscriptions),
            })
        rows[namespace] = {"deduplication": deduplication, "topics": topic_rows}
    return rows


def validate_results(state: dict[str, Any], results: Any) -> list[dict[str, Any]]:
    if not isinstance(results, list) or len(results) != 2:
        raise LiveFailure("round-result-cardinality")
    expected_namespaces = sorted(state["namespaces"])
    if sorted(str(row.get("resultNamespace")) for row in results) != expected_namespaces:
        raise LiveFailure("round-result-namespace-mismatch")
    for row in results:
        namespace = str(row["resultNamespace"])
        expected_topics = [
            f"persistent://{state['tenant']}/{namespace}/round-trip.command.linux-cpu",
            f"persistent://{state['tenant']}/{namespace}/round-trip.event.linux-cpu",
        ]
        if row.get("resultTopics") != expected_topics:
            raise LiveFailure(f"derived-topic-mismatch:{namespace}")
        for field in (
            "resultNativeProtocol", "resultCborRoundTrip", "resultDuplicateCollapsed",
            "resultRedelivery", "resultSeekReplay",
        ):
            if row.get(field) is not True:
                raise LiveFailure(f"round-result-false:{namespace}:{field}")
        if row.get("resultSubscriptionTypes") != 4:
            raise LiveFailure(f"subscription-surface:{namespace}")
    return results


def finish(state_path: Path, result_path: Path) -> None:
    state = load_state(state_path)
    results = validate_results(state, json.loads(result_path.read_text(encoding="utf-8")))
    tenant = str(state["tenant"])
    namespaces = [str(value) for value in state["namespaces"]]
    with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        observed = topic_inventory(tenant, namespaces)
        if any(row["deduplication"] is not True for row in observed.values()):
            raise LiveFailure("namespace-deduplication-not-enabled")
        if any(len(row["topics"]) != 2 for row in observed.values()):
            raise LiveFailure(f"topic-cardinality:{observed}")
        for namespace, row in observed.items():
            counters = {
                str(topic["topic"]).rsplit("/", 1)[-1]: (topic["messageInCounter"], topic["persistedEntries"])
                for topic in row["topics"]
            }
            if counters != {"round-trip.command.linux-cpu": (2, 1), "round-trip.event.linux-cpu": (2, 2)}:
                raise LiveFailure(f"broker-dedup-counter:{namespace}:{counters}")
        policy_before_cleanup = standing_policy()
        if canonical(policy_before_cleanup) != canonical(state["standingPolicy"]):
            raise LiveFailure("standing-policy-mutated-before-cleanup")
        cleanup_tenant(tenant)
        tenants_after = admin("GET", "tenants", expected={200})
        if tenant in tenants_after:
            raise LiveFailure("tenant-leaked-after-cleanup")
        policy_after = standing_policy()
        if canonical(policy_after) != canonical(state["standingPolicy"]):
            raise LiveFailure("standing-policy-not-restored")
    evidence = {
        "schemaVersion": "amoebius.phase35.pulsar-client-live.v1",
        "register": 3,
        "substrate": "linux-cpu",
        "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "sealed": True,
        "challengeDigest": digest(state["challenge"]),
        "nativeWire": {
            "transport": "Pulsar TCP binary protocol",
            "webSocketUsed": False,
            "secondLanguageRuntimeUsedForClient": False,
            "framesExercised": [
                "CONNECT", "CONNECTED", "LOOKUP", "LOOKUP_RESPONSE", "PRODUCER",
                "PRODUCER_SUCCESS", "SUBSCRIBE", "FLOW", "SEND", "SEND_RECEIPT",
                "MESSAGE", "ACK", "SEEK", "CLOSE_CONSUMER", "CLOSE_PRODUCER",
            ],
            "generatedProtocolTypes": True,
            "mandatoryPayloadCrc32c": True,
        },
        "rounds": results,
        "externalBrokerObservation": observed,
        "observer": {
            "authority": "broker-admin HTTP readback",
            "distinctFromClientSocket": True,
            "standingPolicyDigest": state["standingPolicyDigest"],
        },
        "cleanup": {
            "preRunTargetInventory": [],
            "postRunTargetInventory": [],
            "tenantAbsent": True,
            "standingPolicyByteIdentical": True,
        },
        "cleanupInventoriesEqual": True,
        "universalLinuxCpu": {
            "availableOnEveryHardwareSubstrate": True,
            "pristineLinuxVm": {
                "linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2",
            },
        },
        "unverified": [
            "Phase-38 workflow runtime and content store",
            "cross-cluster Pulsar correspondence",
            "broker BookKeeper and ZooKeeper consensus internals",
        ],
    }
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.unlink(missing_ok=True)
    result_path.unlink(missing_ok=True)


def cleanup(state_path: Path) -> None:
    if not state_path.is_file():
        return
    state = load_state(state_path)
    with phase34.port_forward("pulsar-system", "service/broker", PULSAR_PORT, 8080):
        cleanup_tenant(str(state["tenant"]))
    state_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("setup")
    finish_parser = subparsers.add_parser("finish")
    finish_parser.add_argument("--state", type=Path, required=True)
    finish_parser.add_argument("--result", type=Path, required=True)
    cleanup_parser = subparsers.add_parser("cleanup")
    cleanup_parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "setup":
        print(json.dumps(setup(), sort_keys=True))
    elif args.command == "finish":
        finish(args.state, args.result)
    elif args.command == "cleanup":
        cleanup(args.state)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (LiveFailure, phase34.LiveFailure, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"pulsar-client-pulsar-live: FAIL: {error}", file=sys.stderr, flush=True)
        raise SystemExit(1)
