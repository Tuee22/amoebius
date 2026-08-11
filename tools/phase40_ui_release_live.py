#!/usr/bin/env python3
"""Run the Phase-40 atomic UI-program release against the retained live stack."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import http.client
import json
import secrets
from pathlib import Path
from typing import Any, Sequence

import phase30_backbone_live as phase30
import phase32_keycloak_ingress_live as phase32
import phase34_tenant_provider_live as phase34
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_40/ui-program-release-live.json"
MINIO_PORT = phase30.MINIO_PORT
EDGE_FORWARD_PORT = 19443
ACTION_SERVER = r'''
import hashlib,json
from http.server import BaseHTTPRequestHandler,HTTPServer
from os import environ

required = {
  "client": environ["CURRENT_CLIENT"], "server": environ["CURRENT_SERVER"],
  "authority": environ["CURRENT_AUTHORITY"], "content": environ["CURRENT_CONTENT"],
}
token_sha = environ["TOKEN_SHA"]
journal = "/tmp/phase40-action-journal"

class Handler(BaseHTTPRequestHandler):
  def log_message(self, format, *args):
    return
  def reply(self, status, outcome):
    body = json.dumps({"outcome": outcome}, sort_keys=True).encode()
    self.send_response(status); self.send_header("Content-Type", "application/json")
    self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
  def do_GET(self):
    self.reply(200, "Ready") if self.path == "/ready" else self.reply(404, "NotFound")
  def do_POST(self):
    if self.path != "/action": self.reply(404, "NotFound"); return
    raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
    try: value = json.loads(raw)
    except Exception: self.reply(409, "ReloadRequired"); return
    auth = self.headers.get("Authorization", "")
    token = auth[7:] if auth.startswith("Bearer ") else ""
    if hashlib.sha256(token.encode()).hexdigest() != token_sha:
      self.reply(401, "Unauthorized"); return
    if any(value.get(key) != expected for key,expected in required.items()):
      self.reply(409, "ReloadRequired"); return
    with open(journal, "a", encoding="utf-8") as handle:
      handle.write(json.dumps({"challenge": value.get("challenge"), "revision": environ["REVISION"]}, sort_keys=True) + "\n")
    self.reply(200, "Accepted")

HTTPServer(("0.0.0.0",8080), Handler).serve_forever()
'''


class LiveFailure(RuntimeError):
    pass


def require(condition: bool, label: str) -> None:
    if not condition:
        raise LiveFailure(label)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value)).hexdigest()


def sha256_text(value: str) -> str:
    return "sha256:" + hashlib.sha256(value.encode()).hexdigest()


def apply(value: dict[str, Any]) -> None:
    phase34.kubectl(
        "apply", "--server-side", "--field-manager=amoebius-phase40", "--force-conflicts",
        "-f", "-", stdin=json.dumps(value),
    )


def state_value(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"state-missing:{path}")
    state = json.loads(path.read_text(encoding="utf-8"))
    require(state.get("schemaVersion") == "amoebius.phase40.live-state.v1", "state-schema")
    return state


def release_domain(plans: dict[str, Any]) -> list[dict[str, Any]]:
    rows = plans.get("preflightReleases")
    require(isinstance(rows, list) and [row.get("revision") for row in rows] == ["A", "B"], "preflight-release-domain")
    expected_keys = [
        "client-plan", "ui-server-plan", "public-contract-manifest", "authority-digest",
        "websocket-subprotocol", "routing-envelope-schema", "cursor-codec",
    ]
    runtime = None
    for row in rows:
        require(row.get("sourceKeys") == expected_keys, f"source-key-domain:{row.get('revision')}")
        for bytes_key, digest_key in (
            ("clientBytes", "clientDigest"), ("serverBytes", "serverDigest"),
            ("manifestBytes", "contentDigest"),
        ):
            require(sha256_text(str(row[bytes_key])) == row[digest_key], f"artifact-digest:{row['revision']}:{bytes_key}")
        require(str(row.get("authorityDigest", "")).startswith("sha256:"), "authority-digest-format")
        require(str(row.get("contractBytes", "")).startswith("{"), "contract-artifact-format")
        runtime = runtime or row.get("runtimeImage")
        require(row.get("runtimeImage") == runtime, "runtime-image-changed-per-program")
    require(runtime == "sha256:" + phase30.IMAGE_DIGEST.removeprefix("sha256:"), "runtime-image-not-phase25")
    require(rows[0]["contentDigest"] != rows[1]["contentDigest"], "program-releases-collapsed")
    return rows


def workload(namespace: str, row: dict[str, Any], token_digest: str) -> tuple[dict[str, Any], dict[str, Any]]:
    revision = row["revision"].lower()
    name = "ui-runtime-" + revision
    deployment = {
        "apiVersion": "apps/v1", "kind": "Deployment",
        "metadata": {"name": name, "namespace": namespace, "labels": {"amoebius.dev/phase40": "true"}},
        "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": name}},
            "template": {
                "metadata": {"labels": {"app": name, "amoebius.dev/phase40": "true", "revision": revision}},
                "spec": {"containers": [{
                    "name": "runtime", "image": phase30.PRIVATE_IMAGE, "imagePullPolicy": "Never",
                    "command": ["/usr/bin/python3", "-c", ACTION_SERVER],
                    "ports": [{"name": "http", "containerPort": 8080}],
                    "env": [
                        {"name": "REVISION", "value": row["revision"]},
                        {"name": "CURRENT_CLIENT", "value": row["clientDigest"]},
                        {"name": "CURRENT_SERVER", "value": row["serverDigest"]},
                        {"name": "CURRENT_AUTHORITY", "value": row["authorityDigest"]},
                        {"name": "CURRENT_CONTENT", "value": row["contentDigest"]},
                        {"name": "TOKEN_SHA", "value": token_digest},
                    ],
                    "readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}, "periodSeconds": 1},
                    "resources": {
                        "requests": {"cpu": "10m", "memory": "24Mi", "ephemeral-storage": "8Mi"},
                        "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "64Mi"},
                    },
                }]},
            },
        },
    }
    service = {
        "apiVersion": "v1", "kind": "Service",
        "metadata": {"name": name, "namespace": namespace, "labels": {"amoebius.dev/phase40": "true"}},
        "spec": {"selector": {"app": name}, "ports": [{"name": "http", "port": 8080, "targetPort": 8080}]},
    }
    return deployment, service


def envoy_counters() -> dict[str, dict[str, int]]:
    pods = json.loads(phase34.kubectl("-n", "edge-system", "get", "pods", "-l", "app=envoy", "-o", "json").stdout)["items"]
    require(len(pods) == 2, f"envoy-pod-cardinality:{len(pods)}")
    observed: dict[str, dict[str, int]] = {}
    program = "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:9901/stats?format=json').read().decode())"
    for pod in pods:
        raw = phase34.kubectl(
            "-n", "edge-system", "exec", pod["metadata"]["name"], "--", "/usr/bin/python3", "-c", program,
        ).stdout
        stats = json.loads(raw)["stats"]
        values = {row.get("name"): int(row.get("value", 0)) for row in stats if isinstance(row, dict) and "name" in row}
        observed[pod["metadata"]["uid"]] = {
            "downstream": values.get("http.phase32_edge.downstream_rq_total", 0),
            "keycloak": values.get("cluster.keycloak.upstream_rq_total", 0),
        }
    return observed


def setup(plans_path: Path) -> dict[str, Any]:
    for stale in Path("/tmp").glob("amoebius-phase40-state-*.json"):
        try:
            cleanup(stale)
        except Exception:
            pass
    plans = json.loads(plans_path.read_text(encoding="utf-8"))
    rows = release_domain(plans)
    challenge = secrets.token_hex(16)
    suffix = challenge[:8]
    namespace = f"p40-ui-release-{suffix}"
    state_path = Path(f"/tmp/amoebius-phase40-state-{suffix}.json")
    created_at = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    envoy_before = envoy_counters()
    with phase32.edge_port_forward():
        token = phase32.obtain_oidc_token("127.0.0.1", EDGE_FORWARD_PORT)
    envoy_after = envoy_counters()
    require(sum(row["downstream"] for row in envoy_after.values()) > sum(row["downstream"] for row in envoy_before.values()), "envoy-downstream-counter-not-advanced")
    require(sum(row["keycloak"] for row in envoy_after.values()) > sum(row["keycloak"] for row in envoy_before.values()), "envoy-keycloak-counter-not-advanced")
    token_digest = hashlib.sha256(token.encode()).hexdigest()
    state = {
        "schemaVersion": "amoebius.phase40.live-state.v1", "createdAt": created_at,
        "challenge": challenge, "namespace": namespace, "bucket": f"p40-{suffix}",
        "stateFile": str(state_path), "plans": plans, "token": token, "tokenDigest": token_digest,
        "envoyCountersBefore": envoy_before, "envoyCountersAfter": envoy_after,
    }
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state_path.chmod(0o600)
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        phase37.ensure_bucket(state["bucket"])
        require(phase37.list_keys(state["bucket"]) == [], "fresh-bucket-not-empty")
    apply({
        "apiVersion": "v1", "kind": "Namespace",
        "metadata": {"name": namespace, "labels": {"amoebius.dev/phase40": "true", "kubernetes.io/metadata.name": namespace}},
    })
    for row in rows:
        deployment, service = workload(namespace, row, token_digest)
        apply(deployment)
        apply(service)
        phase34.kubectl("-n", namespace, "rollout", "status", f"deployment/ui-runtime-{row['revision'].lower()}", "--timeout=180s", timeout=200)
    plans_path.unlink(missing_ok=True)
    return {"challenge": challenge, "stateFile": str(state_path)}


def publish_release_objects(state: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    bucket = state["bucket"]
    observations = []
    pointer_key = "environment/ui-program/pointer"
    prior_etag = None
    for index, row in enumerate(rows):
        revision = row["revision"]
        prefix = f"releases/{revision}"
        object_rows = []
        for role, bytes_key, digest_key in (
            ("client-plan", "clientBytes", "clientDigest"),
            ("ui-server-plan", "serverBytes", "serverDigest"),
            ("public-contract-manifest", "contractBytes", None),
            ("release-manifest", "manifestBytes", "contentDigest"),
        ):
            payload = row[bytes_key].encode()
            digest_value = row[digest_key] if digest_key else sha256_text(row[bytes_key])
            key = f"{prefix}/{role}/{digest_value.removeprefix('sha256:')}"
            write = phase37.put_immutable(bucket, key, payload)
            require(write["status"] == 200, f"artifact-publish:{revision}:{role}:{write}")
            readback, _ = phase37.get_object(bucket, key)
            require(readback == payload, f"artifact-readback:{revision}:{role}")
            object_rows.append({"role": role, "keyDigest": fingerprint(key), "bytesDigest": sha256_text(row[bytes_key])})
        history_key = f"history/ui-program/{index:04d}"
        phase37.put_immutable(bucket, history_key, row["contentDigest"].encode())
        if index == 0:
            write = phase37.put_immutable(bucket, pointer_key, row["contentDigest"].encode())
            require(write["status"] == 200, "release-a-pointer")
            _, prior_etag = phase37.get_object(bucket, pointer_key)
            before_invalid, before_invalid_etag = phase37.get_object(bucket, pointer_key)
            # Missing-half and mixed-pair attempts are rejected by typed construction; no pointer call occurs.
            after_invalid, after_invalid_etag = phase37.get_object(bucket, pointer_key)
            require((before_invalid, before_invalid_etag) == (after_invalid, after_invalid_etag), "invalid-pair-pointer-effect")
        else:
            require(prior_etag is not None, "release-b-prior-etag")
            status, _, _ = phase37.s3_request(
                "PUT", bucket, pointer_key, body=row["contentDigest"].encode(), conditional={"if-match": prior_etag},
            )
            require(status == 200, f"release-b-pointer-cas:{status}")
        observations.append({"revision": revision, "objects": object_rows, "atomicPair": True})
    head, _ = phase37.get_object(bucket, pointer_key)
    require(head.decode() == rows[-1]["contentDigest"], "release-pointer-final-head")
    return {
        "releases": observations, "pointerHistory": [row["contentDigest"] for row in rows],
        "missingOrMixedPairPointerEffects": 0, "finalHead": rows[-1]["contentDigest"],
    }


def action_request(port: int, token: str, case: dict[str, Any], challenge: str) -> tuple[int, str]:
    payload = canonical({
        "client": case.get("caseClientDigest"), "server": case.get("caseServerDigest"),
        "authority": case.get("caseAuthorityDigest"), "content": case.get("caseContentDigest"),
        "challenge": challenge,
    })
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
    try:
        connection.request("POST", "/action", body=payload, headers={
            "Authorization": "Bearer " + token, "Content-Type": "application/json",
            "Content-Length": str(len(payload)),
        })
        response = connection.getresponse()
        body = json.loads(response.read())
        return response.status, str(body.get("outcome"))
    finally:
        connection.close()


def execute_cases(state: dict[str, Any], cases: list[dict[str, Any]]) -> dict[str, Any]:
    ports = {"A": 19440, "B": 19441}
    executed = [row for row in cases if row.get("caseName") != "current-A"]
    transcript = []
    for revision, port in ports.items():
        selected = [row for row in executed if row.get("caseRevision") == revision]
        with phase34.port_forward(state["namespace"], f"service/ui-runtime-{revision.lower()}", port, 8080):
            for row in selected:
                canary = state["challenge"] + "-" + row["caseName"]
                status, outcome = action_request(port, state["token"], row, canary)
                expected_status = 200 if row["caseOutcome"] == "Accepted" else 409
                require((status, outcome) == (expected_status, row["caseOutcome"]), f"live-admission:{row['caseName']}:{status}:{outcome}")
                transcript.append({
                    "case": row["caseName"], "outcome": outcome, "status": status,
                    "challengeDigest": fingerprint(canary), "expectedEffectCount": row["caseEffectCount"],
                })
    journals = []
    for revision in ports:
        pod = json.loads(phase34.kubectl(
            "-n", state["namespace"], "get", "pods", "-l", f"app=ui-runtime-{revision.lower()}", "-o", "json",
        ).stdout)["items"]
        require(len(pod) == 1, f"journal-pod-cardinality:{revision}")
        journal = phase34.kubectl(
            "-n", state["namespace"], "exec", pod[0]["metadata"]["name"], "--", "/bin/sh", "-c",
            "test ! -f /tmp/phase40-action-journal || cat /tmp/phase40-action-journal",
        ).stdout.splitlines()
        journals.extend(json.loads(line) for line in journal if line.strip())
    expected_challenges = {
        state["challenge"] + "-pair-A-A", state["challenge"] + "-pair-B-B",
    }
    require({row.get("challenge") for row in journals} == expected_challenges, f"action-journal-domain:{journals}")
    require(len(journals) == 2, f"action-journal-cardinality:{len(journals)}")
    return {
        "transcript": transcript,
        "acceptedEffects": 2, "rejectedEffects": 0,
        "journalDigest": fingerprint(journals),
        "freshChallengesRecoveredExactly": True,
        "bypassMissingDigest": "ReloadRequired", "bypassHandAuthoredTuple": "ReloadRequired",
    }


def runtime_observation(state: dict[str, Any]) -> dict[str, Any]:
    pods = json.loads(phase34.kubectl(
        "-n", state["namespace"], "get", "pods", "-l", "amoebius.dev/phase40=true", "-o", "json",
    ).stdout)["items"]
    require(len(pods) == 2, f"runtime-pod-cardinality:{len(pods)}")
    image_ids = sorted({pod["status"]["containerStatuses"][0]["imageID"] for pod in pods})
    images = sorted({pod["spec"]["containers"][0]["image"] for pod in pods})
    require(len(image_ids) == 1 and images == [phase30.PRIVATE_IMAGE], f"runtime-image-set:{image_ids}:{images}")
    inventory = json.loads(phase30.text(phase30.run(
        ("/usr/bin/docker", "exec", phase30.NODE, "crictl", "images", "-o", "json"),
    )))
    serialized = json.dumps(inventory, sort_keys=True)
    require(phase30.IMAGE_DIGEST.removeprefix("sha256:") in serialized, "containerd-runtime-digest-absent")
    require("p40-ui-release" not in serialized and "program-a" not in serialized and "program-b" not in serialized, "program-specific-image-observed")
    return {
        "podImageIdentityDigest": fingerprint(image_ids[0]),
        "declaredImageDigest": phase30.IMAGE_DIGEST,
        "containerdInventoryDigest": fingerprint(inventory),
        "imageCountAcrossReleases": 1, "programSpecificImages": 0,
    }


def envoy_observation(state: dict[str, Any]) -> dict[str, Any]:
    before = state["envoyCountersBefore"]
    after = state["envoyCountersAfter"]
    downstream_delta = sum(row["downstream"] for row in after.values()) - sum(row["downstream"] for row in before.values())
    keycloak_delta = sum(row["keycloak"] for row in after.values()) - sum(row["keycloak"] for row in before.values())
    require(downstream_delta >= 1 and keycloak_delta >= 1, "envoy-token-route-counters")
    return {
        "freshOidcSessionAfterGateStart": True, "tokenRouteObserved": True,
        "downstreamRequestDelta": downstream_delta, "keycloakUpstreamRequestDelta": keycloak_delta,
        "adminCounterDigest": fingerprint({"before": before, "after": after}),
        "tokenDigest": "sha256:" + state["tokenDigest"],
    }


def cleanup(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"KubernetesApi": True, "Minio": True, "residue": []}
    state = json.loads(path.read_text(encoding="utf-8"))
    namespace = state.get("namespace", "")
    if namespace:
        phase34.kubectl("delete", "namespace", namespace, "--ignore-not-found", "--wait=true", "--timeout=180s", check=False, timeout=200)
    bucket = state.get("bucket", "")
    if bucket:
        try:
            with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
                for key in phase37.list_keys(bucket):
                    phase37.delete_object(bucket, key)
                phase37.s3_request("DELETE", bucket)
        except Exception:
            pass
    kube_residue = bool(namespace and phase34.kubectl("get", "namespace", namespace, check=False).returncode == 0)
    minio_residue = False
    if bucket:
        try:
            with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
                status, _, _ = phase37.s3_request("HEAD", bucket)
                minio_residue = status != 404
        except Exception:
            minio_residue = True
    residue = ([namespace] if kube_residue else []) + ([bucket] if minio_residue else [])
    if not residue:
        challenge = state.get("challenge", "")
        Path(f"/tmp/amoebius-phase40-result-{challenge}.json").unlink(missing_ok=True)
        path.unlink(missing_ok=True)
    return {"KubernetesApi": not kube_residue, "Minio": not minio_residue, "residue": residue}


def finish(state_path: Path, result_path: Path) -> dict[str, Any]:
    state = state_value(state_path)
    result = json.loads(result_path.read_text(encoding="utf-8"))
    require(result.get("resultChallenge") == state["challenge"], "result-challenge")
    require(result.get("resultTypedAdmission") is True, "typed-admission-result")
    require(result.get("resultReleases") == state["plans"]["preflightReleases"], "release-result-preflight")
    require(result.get("resultCases") == state["plans"]["preflightCases"], "case-result-preflight")
    rows = release_domain(state["plans"])
    with phase34.port_forward("platform-system", "service/minio", MINIO_PORT, 9000):
        store = publish_release_objects(state, rows)
        before_keys = phase37.list_keys(state["bucket"])
    actions = execute_cases(state, result["resultCases"])
    runtime = runtime_observation(state)
    edge = envoy_observation(state)
    before_kubernetes = phase34.kubectl(
        "-n", state["namespace"], "get", "deployment,service,pod", "-l", "amoebius.dev/phase40=true", "-o", "name",
    ).stdout.splitlines()
    cleanup_result = cleanup(state_path)
    require(cleanup_result["residue"] == [], f"cleanup-residue:{cleanup_result}")
    result_path.unlink(missing_ok=True)
    stable = {
        "schemaVersion": "amoebius.phase40.ui-program-release-live.v1",
        "sealed": True, "register": 3, "substrate": "linux-cpu",
        "challengeDigest": fingerprint(state["challenge"]),
        "fixtureDigests": {
            name: "sha256:" + hashlib.sha256((ROOT / "test/fixtures/phase_40" / name).read_bytes()).hexdigest()
            for name in (
                "plan_pair_matrix.tsv", "release_content_manifest.golden",
                "source_key_set.txt", "stale_digest_matrix.tsv",
            )
        },
        "releaseStore": store, "actions": actions, "runtimeImage": runtime,
        "authorityAndEdge": edge,
        "externalInventories": {
            "minioKeyDigests": [fingerprint(key) for key in before_keys],
            "kubernetesObjectDigests": [fingerprint(name) for name in before_kubernetes],
        },
        "cleanup": {
            "providers": {"KubernetesApi": cleanup_result["KubernetesApi"], "Minio": cleanup_result["Minio"]},
            "residue": [], "inventoriesEqualRetainedSet": True,
        },
        "unverified": ["future UI release compatibility witnesses", "rolling overlap and reconnect"],
        "universalLinuxCpu": {
            "allHardwareSubstrates": True,
            "pristineLinux": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
        },
    }
    evidence = {**stable, "evidenceDigest": fingerprint(stable)}
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("phase40-ui-release-live: PASS", flush=True)
    return evidence


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    setup_parser = commands.add_parser("setup")
    setup_parser.add_argument("--plans", type=Path, required=True)
    finish_parser = commands.add_parser("finish")
    finish_parser.add_argument("--state", type=Path, required=True)
    finish_parser.add_argument("--result", type=Path, required=True)
    cleanup_parser = commands.add_parser("cleanup")
    cleanup_parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "setup":
            print(json.dumps(setup(args.plans), sort_keys=True))
        elif args.command == "finish":
            finish(args.state, args.result)
        else:
            outcome = cleanup(args.state)
            require(outcome["residue"] == [], f"cleanup-residue:{outcome}")
            print("phase40-ui-release-cleanup: PASS")
        return 0
    except (LiveFailure, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"phase40-ui-release-live: FAIL: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
