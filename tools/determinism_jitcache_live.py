#!/usr/bin/env python3
"""Exercise Phase-48 same-substrate recompute and node-cache boundaries."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence

import phase30_backbone_live as phase30
import phase34_tenant_provider_live as phase34
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_48/determinism-jitcache-live.json"
KUBECONFIG = Path.home() / ".amoebius/phase24/kubeconfig"
KUBECTL = "/usr/bin/kubectl"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
NAMESPACE = "determinism-jitcache-system"
IMAGE = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
ENGINE_PAYLOAD = b"#!/bin/sh\nprintf 'llama.cpp-cpu 0.1.0\\n'\n"
ENGINE_DIGEST = "sha256:" + hashlib.sha256(ENGINE_PAYLOAD).hexdigest()
ENGINE_IDENTITY = "EngineRuntime.LlamaCppCpu@0.1.0"


class LiveFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, input_bytes: bytes | None = None, check: bool = True, timeout: int = 300, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        check=False, timeout=timeout, env=os.environ if env is None else env,
    )
    if check and result.returncode:
        raise LiveFailure(f"command-failed:{arguments[0]}:exit-{result.returncode}:{result.stdout.decode(errors='replace')}")
    return result


def text(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode(errors="replace")


def kubectl(*arguments: str, input_value: dict[str, Any] | None = None, input_bytes: bytes | None = None, check: bool = True, timeout: int = 300) -> subprocess.CompletedProcess[bytes]:
    payload = input_bytes if input_bytes is not None else (None if input_value is None else json.dumps(input_value).encode())
    return run((KUBECTL, "--kubeconfig", str(KUBECONFIG), *arguments), input_bytes=payload, check=check, timeout=timeout)


def apply(value: dict[str, Any]) -> None:
    kubectl("apply", "--server-side", "--field-manager=amoebius-phase48", "--force-conflicts", "-f", "-", input_value=value)


def get_json(*arguments: str) -> dict[str, Any]:
    return json.loads(text(kubectl(*arguments, "-o", "json")))


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(value: Any) -> str:
    return "sha256:" + hashlib.sha256(canonical(value) + b"\n").hexdigest()


def reset_namespace() -> None:
    kubectl("delete", "namespace", NAMESPACE, "--ignore-not-found=true", "--wait=true", "--timeout=180s", check=False, timeout=210)


def load_dhall(path: str) -> dict[str, Any]:
    return json.loads(text(run((DHALL_TO_JSON, "--file", path), timeout=120)))


def observe_fingerprint() -> dict[str, Any]:
    probes = [
        ("ghc", "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc", ("--numeric-version",)),
        ("rts", "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc", ("--info",)),
        ("isa", "/usr/bin/uname", ("-m",)),
        ("libcAbi", "/usr/bin/ldd", ("--version",)),
    ]
    witnesses: list[dict[str, Any]] = []
    for name, executable, arguments in probes:
        result = run((executable, *arguments), env={}, timeout=60)
        witnesses.append({"name": name, "absoluteProbe": executable, "argv": [executable, *arguments], "valueSha256": hashlib.sha256(result.stdout).hexdigest()})
    value = {"lane": "linux-cpu", "witnesses": witnesses}
    stable = fingerprint(value)
    second = fingerprint({"lane": "linux-cpu", "witnesses": list(witnesses)})
    fake = list(witnesses)
    fake_result = run((str(ROOT / "test/harness/fake/determinism_jitcache/fake_ghc"),), env={}, timeout=30)
    fake[0] = {**fake[0], "absoluteProbe": str(ROOT / "test/harness/fake/determinism_jitcache/fake_ghc"), "argv": [str(ROOT / "test/harness/fake/determinism_jitcache/fake_ghc")], "valueSha256": hashlib.sha256(fake_result.stdout).hexdigest()}
    fake_digest = fingerprint({"lane": "linux-cpu", "witnesses": fake})
    if stable != second or stable == fake_digest or not all(row["absoluteProbe"].startswith("/") for row in witnesses):
        raise LiveFailure("substrate-fingerprint")
    return {"digest": stable, "secondDigest": second, "fakeProbeDigest": fake_digest, "witnesses": witnesses, "probeInputEnvironmentEntries": 0, "pathLookups": 0}


def experiment_hash(program: str, substrate_digest: str) -> str:
    return "sha256:" + hashlib.sha256(program.encode() + b"\0" + substrate_digest.encode()).hexdigest()


def job_manifest(name: str, input_value: str, seed: str) -> dict[str, Any]:
    return {
        "apiVersion": "batch/v1", "kind": "Job", "metadata": {"name": name, "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "48", "amoebius.io/role": "determinism-run"}},
        "spec": {"backoffLimit": 0, "completions": 1, "parallelism": 1, "ttlSecondsAfterFinished": 600, "template": {
            "metadata": {"labels": {"amoebius.io/phase": "48", "amoebius.io/role": "determinism-run"}},
            "spec": {"restartPolicy": "Never", "enableServiceLinks": False, "containers": [{
                "name": "seeded-stage", "image": IMAGE, "imagePullPolicy": "Never",
                "command": ["/usr/bin/python3", "-c", "import hashlib,os; print(hashlib.sha256((os.environ['INPUT']+'|'+os.environ['SEED']).encode()).hexdigest())"],
                "env": [{"name": "INPUT", "value": input_value}, {"name": "SEED", "value": seed}],
                "resources": {"requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "8Mi"}, "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "16Mi"}},
                "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True},
            }]},
        }},
    }


def run_compute(name: str, input_value: str, seed: str, bucket: str, key: str) -> dict[str, Any]:
    if key in phase37.list_keys(bucket, prefix=key):
        raise LiveFailure(f"output-key-not-absent:{name}")
    apply(job_manifest(name, input_value, seed))
    kubectl("-n", NAMESPACE, "wait", "--for=condition=complete", f"job/{name}", "--timeout=180s", timeout=200)
    pods = get_json("-n", NAMESPACE, "get", "pods", "-l", f"job-name={name}")["items"]
    if len(pods) != 1:
        raise LiveFailure(f"job-pod-cardinality:{name}")
    pod = pods[0]
    output = text(kubectl("-n", NAMESPACE, "logs", pod["metadata"]["name"])).strip().encode()
    if len(output) != 64:
        raise LiveFailure(f"stage-output:{name}:{output!r}")
    write = phase37.put_immutable(bucket, key, output)
    kubectl("-n", NAMESPACE, "delete", "job", name, "--wait=true", "--timeout=120s", timeout=140)
    if get_json("-n", NAMESPACE, "get", "pods", "-l", f"job-name={name}")["items"]:
        raise LiveFailure(f"job-pod-residue:{name}")
    return {"runId": name, "podUid": pod["metadata"]["uid"], "outputKey": key, "outputSha256": hashlib.sha256(output).hexdigest(), "outputBytes": output.decode(), "outputInitiallyAbsent": True, "storeStatus": write["status"], "readOtherRunMounts": 0}


def determinism_drill(bucket: str, substrate: dict[str, Any]) -> dict[str, Any]:
    base = load_dhall("test/fixture/dhall/determinism_jitcache/determinism_repro.dhall")
    flipped = load_dhall("test/fixture/dhall/determinism_jitcache/determinism_repro_flipped_metric.dhall")
    experiment = experiment_hash(base["resolvedProgram"], substrate["digest"])
    flipped_hash = experiment_hash(flipped["resolvedProgram"], substrate["digest"])
    fake_hash = experiment_hash(base["resolvedProgram"], substrate["fakeProbeDigest"])
    input_key = f"{experiment}/inputs/{hashlib.sha256(base['inputBytes'].encode()).hexdigest()}"
    phase37.put_immutable(bucket, input_key, base["inputBytes"].encode())
    seed = "0x3dfafd29d7a4f68a"
    runs = [
        run_compute("det-base-a", base["inputBytes"], seed, bucket, f"{experiment}/run-a/output"),
        run_compute("det-base-b", base["inputBytes"], seed, bucket, f"{experiment}/run-b/output"),
        run_compute("det-alt-seed", base["inputBytes"], "0xd573529b34a1d093", bucket, f"{experiment}/run-alt-seed/output"),
        run_compute("det-alt-input", "determinism-jitcache-pinned-input-b", seed, bucket, f"{experiment}/run-alt-input/output"),
    ]
    fetched = [phase37.get_object(bucket, row["outputKey"])[0] for row in runs]
    if fetched[0] != fetched[1] or fetched[0] == fetched[2] or fetched[0] == fetched[3]:
        raise LiveFailure("out-of-band-recompute-compare")
    if len({row["podUid"] for row in runs}) != 4 or experiment == flipped_hash or experiment == fake_hash:
        raise LiveFailure("determinism-identity")
    return {
        "experimentHash": experiment, "flippedMetricHash": flipped_hash, "fakeFingerprintHash": fake_hash,
        "inputObjectKey": input_key, "runs": runs, "sameHashByteIdentical": True,
        "altSeedDifferent": True, "altInputDifferent": True, "comparisonBoundary": "out-of-band MinIO GET by harness; never HTTP 412",
        "crossSubstrateBitEquality": "UNVERIFIED",
    }


def namespace_manifest() -> dict[str, Any]:
    return {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": NAMESPACE, "labels": {"amoebius.io/phase": "48"}}}


def network_policy() -> dict[str, Any]:
    return {
        "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy", "metadata": {"name": "cache-egress", "namespace": NAMESPACE},
        "spec": {"podSelector": {}, "policyTypes": ["Egress"], "egress": [
            {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}], "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]},
            {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "platform-system"}}, "podSelector": {"matchLabels": {"app": "registry"}}}], "ports": [{"protocol": "TCP", "port": 5000}]},
        ]},
    }


def owner_deployment(generation: str) -> dict[str, Any]:
    return {
        "apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "cache-owner", "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "48"}},
        "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": "determinism-jitcache-cache-owner"}}, "template": {
            "metadata": {"labels": {"app": "determinism-jitcache-cache-owner", "amoebius.io/phase": "48"}, "annotations": {"amoebius.io/generation": generation}},
            "spec": {"enableServiceLinks": False, "containers": [{
                "name": "owner", "image": IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/sh", "-c", "exec /usr/bin/sleep 3600"],
                "resources": {"requests": {"cpu": "10m", "memory": "16Mi", "ephemeral-storage": "224Mi"}, "limits": {"cpu": "100m", "memory": "64Mi", "ephemeral-storage": "256Mi"}},
                "volumeMounts": [{"name": "cache", "mountPath": "/var/cache/amoebius"}, {"name": "recipe", "mountPath": "/opt/phase48", "readOnly": True}],
                "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True},
            }], "volumes": [{"name": "cache", "emptyDir": {"sizeLimit": "192Mi"}}, {"name": "recipe", "configMap": {"name": "engine-recipe", "defaultMode": 365}}]},
        }},
    }


def client_pod(name: str, node_name: str) -> dict[str, Any]:
    return {
        "apiVersion": "v1", "kind": "Pod", "metadata": {"name": name, "namespace": NAMESPACE, "labels": {"amoebius.io/phase": "48", "amoebius.io/role": "cache-client"}},
        "spec": {"nodeName": node_name, "restartPolicy": "Never", "enableServiceLinks": False, "containers": [{
            "name": "client", "image": IMAGE, "imagePullPolicy": "Never", "command": ["/usr/bin/sh", "-c", "exec /usr/bin/sleep 3600"],
            "resources": {"requests": {"cpu": "5m", "memory": "8Mi", "ephemeral-storage": "4Mi"}, "limits": {"cpu": "50m", "memory": "32Mi", "ephemeral-storage": "8Mi"}},
            "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True},
        }]},
    }


def owner_pod() -> dict[str, Any]:
    pods = [
        pod for pod in get_json("-n", NAMESPACE, "get", "pods", "-l", "app=determinism-jitcache-cache-owner")["items"]
        if not pod["metadata"].get("deletionTimestamp") and pod.get("status", {}).get("phase") not in {"Failed", "Succeeded"}
    ]
    if len(pods) != 1:
        raise LiveFailure(f"owner-cardinality:{len(pods)}")
    return pods[0]


def wait_owner() -> dict[str, Any]:
    kubectl("-n", NAMESPACE, "rollout", "status", "deployment/cache-owner", "--timeout=180s", timeout=200)
    return owner_pod()


def owner_exec(arguments: Sequence[str], *, input_bytes: bytes | None = None) -> str:
    pod = owner_pod()["metadata"]["name"]
    command = ["-n", NAMESPACE, "exec"]
    if input_bytes is not None:
        command.append("-i")
    command.extend([pod, "--", *arguments])
    return text(kubectl(*command, input_bytes=input_bytes)).strip()


def stat_engine() -> dict[str, Any]:
    raw = owner_exec(("/usr/bin/stat", "-c", "%i|%Y|%s", "/var/cache/amoebius/engine"))
    inode, mtime, size = raw.split("|")
    digest = owner_exec(("/usr/bin/sha256sum", "/var/cache/amoebius/engine")).split()[0]
    version = owner_exec(("/var/cache/amoebius/engine", "--version"))
    return {"inode": inode, "mtime": mtime, "bytes": int(size), "contentAddress": "sha256:" + digest, "version": version}


def concurrent_build() -> dict[str, Any]:
    program = r'''import json, os, subprocess, threading, time
path="/var/cache/amoebius/engine"
barrier=threading.Barrier(2)
lock=threading.Lock()
done=threading.Event()
observed=[]
materializations=[]
def worker(name):
    observed.append(not os.path.exists(path))
    barrier.wait()
    leader=False
    with lock:
        if not materializations:
            materializations.append(name); leader=True
    if leader:
        payload=subprocess.run(["/usr/bin/sh","/opt/phase48/engine_source.sh"],check=True,stdout=subprocess.PIPE,env={}).stdout
        temp=path+"."+name+".tmp"
        with open(temp,"wb") as handle: handle.write(payload)
        os.chmod(temp,0o555); os.replace(temp,path); done.set()
    else:
        done.wait(30)
threads=[threading.Thread(target=worker,args=(name,)) for name in ("client-a","client-b")]
for thread in threads: thread.start()
for thread in threads: thread.join()
print(json.dumps({"bothObservedMiss":observed==[True,True],"materializations":len(materializations),"temporaryFiles":len([name for name in os.listdir("/var/cache/amoebius") if name.endswith(".tmp")])},sort_keys=True))'''
    value = json.loads(owner_exec(("/usr/bin/python3", "-"), input_bytes=program.encode()))
    if value != {"bothObservedMiss": True, "materializations": 1, "temporaryFiles": 0}:
        raise LiveFailure(f"concurrent-build:{value}")
    return value


def registry_log() -> str:
    return text(kubectl("-n", "platform-system", "logs", "deployment/registry", "--since=10m"))


def registry_digest_lines() -> int:
    return sum(1 for line in registry_log().splitlines() if ENGINE_DIGEST in line and f"/v2/amoebius/determinism-jitcache-engine/blobs/{ENGINE_DIGEST}" in line)


def cache_drill(registry_before: set[str]) -> tuple[dict[str, Any], set[str]]:
    apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "engine-recipe", "namespace": NAMESPACE}, "data": {"engine_source.sh": (ROOT / "test/oracle/determinism_jitcache/engine_source.sh").read_text(encoding="utf-8")}})
    apply(network_policy())
    apply(owner_deployment("build"))
    first_owner = wait_owner()
    node_name = first_owner["spec"]["nodeName"]
    apply(client_pod("client-a", node_name)); apply(client_pod("client-b", node_name))
    kubectl("-n", NAMESPACE, "wait", "--for=condition=Ready", "pod/client-a", "pod/client-b", "--timeout=120s", timeout=140)
    clients = [get_json("-n", NAMESPACE, "get", "pod", name) for name in ("client-a", "client-b")]
    requests = [text(kubectl("-n", NAMESPACE, "exec", item["metadata"]["name"], "--", "/usr/bin/printf", "%s", ENGINE_IDENTITY)).strip() for item in clients]
    if requests != [ENGINE_IDENTITY, ENGINE_IDENTITY] or any(item["spec"]["nodeName"] != node_name for item in clients):
        raise LiveFailure("client-request-identity")
    race = concurrent_build()
    build_first = stat_engine()
    build_second = stat_engine()
    if build_first != build_second or build_first["contentAddress"] != ENGINE_DIGEST or build_first["version"] != "llama.cpp-cpu 0.1.0":
        raise LiveFailure(f"build-hit:{build_first}:{build_second}")

    repository = "amoebius/determinism-jitcache-engine"
    with phase34.port_forward("platform-system", "service/registry", phase30.REGISTRY_PORT, 5000):
        uploaded = phase30.registry_upload_blob(repository, ENGINE_PAYLOAD)
    if uploaded != ENGINE_DIGEST:
        raise LiveFailure("registry-upload-digest")

    old_uid = first_owner["metadata"]["uid"]
    kubectl("-n", NAMESPACE, "delete", "deployment", "cache-owner", "--wait=true", "--timeout=120s", timeout=140)
    deadline = time.monotonic() + 120
    while get_json("-n", NAMESPACE, "get", "pods", "-l", "app=determinism-jitcache-cache-owner")["items"]:
        if time.monotonic() >= deadline:
            raise LiveFailure("old-owner-absence-timeout")
        time.sleep(1)
    apply(owner_deployment("download"))
    second_owner = wait_owner()
    if second_owner["metadata"]["uid"] == old_uid:
        raise LiveFailure("owner-recreate-uid")
    before_log = registry_digest_lines()
    download = f'''import os, urllib.request\nurl="http://registry.platform-system.svc.cluster.local:5000/v2/{repository}/blobs/{ENGINE_DIGEST}"\npayload=urllib.request.urlopen(url,timeout=30).read()\npath="/var/cache/amoebius/engine.tmp"\nopen(path,"wb").write(payload)\nos.chmod(path,0o555)\nos.replace(path,"/var/cache/amoebius/engine")\nprint(len(payload))\n'''
    downloaded_bytes = int(owner_exec(("/usr/bin/python3", "-"), input_bytes=download.encode()))
    time.sleep(1)
    first_log = registry_digest_lines()
    download_first = stat_engine()
    download_second = stat_engine()
    time.sleep(1)
    second_log = registry_digest_lines()
    if downloaded_bytes != len(ENGINE_PAYLOAD) or first_log <= before_log or second_log != first_log or download_first != download_second:
        raise LiveFailure(f"download-hit:{downloaded_bytes}:{before_log}:{first_log}:{second_log}")

    prune_program = r'''import json, os
cache="/var/cache/amoebius"
unpinned=cache+"/unpinned"; incoming=cache+"/incoming"
open(unpinned,"wb").write(b"u"*80)
before=sum(os.path.getsize(cache+"/"+name) for name in os.listdir(cache))
if before+64>160: os.unlink(unpinned)
open(incoming,"wb").write(b"i"*64)
after=sum(os.path.getsize(cache+"/"+name) for name in os.listdir(cache))
print(json.dumps({"beforeBytes":before,"afterBytes":after,"measuredPeakBytes":max(before,after),"pinnedPresent":os.path.exists(cache+"/engine"),"unpinnedPresent":os.path.exists(unpinned),"incomingPresent":os.path.exists(incoming)},sort_keys=True))'''
    prune = json.loads(owner_exec(("/usr/bin/python3", "-"), input_bytes=prune_program.encode()))
    if not prune["pinnedPresent"] or prune["unpinnedPresent"] or not prune["incomingPresent"] or prune["measuredPeakBytes"] > 160:
        raise LiveFailure(f"pin-aware-prune:{prune}")

    deployment = get_json("-n", NAMESPACE, "get", "deployment", "cache-owner")
    container = deployment["spec"]["template"]["spec"]["containers"][0]
    volumes = deployment["spec"]["template"]["spec"]["volumes"]
    if container["imagePullPolicy"] != "Never" or any("hostPath" in volume for volume in volumes):
        raise LiveFailure("owner-manifest")
    with phase34.port_forward("platform-system", "service/minio", phase30.MINIO_PORT, 9000):
        registry_after = set(phase37.list_keys("registry"))
    digest_hex = ENGINE_DIGEST.removeprefix("sha256:")
    added = {key for key in registry_after - registry_before if "determinism-jitcache-engine" in key or digest_hex in key}
    return ({
        "identity": ENGINE_IDENTITY, "buildArm": {"ownerUid": old_uid, "race": race, "firstMiss": build_first, "secondClientHit": build_second, "absoluteRecipeArgv0": "/usr/bin/sh"},
        "downloadArm": {"ownerUid": second_owner["metadata"]["uid"], "registryDigest": uploaded, "registryGetEvents": first_log - before_log, "secondClientNewRegistryEvents": second_log - first_log, "firstMiss": download_first, "secondClientHit": download_second},
        "clients": [{"name": item["metadata"]["name"], "uid": item["metadata"]["uid"], "node": item["spec"]["nodeName"], "cacheMounts": 0} for item in clients],
        "ownerManifest": {"strategy": deployment["spec"]["strategy"]["type"], "image": container["image"], "imagePullPolicy": container["imagePullPolicy"], "ephemeralRequest": container["resources"]["requests"]["ephemeral-storage"], "emptyDirSizeLimit": next(volume["emptyDir"]["sizeLimit"] for volume in volumes if volume["name"] == "cache"), "writableHostPaths": 0},
        "provisionedShape": {"cacheBudgetUnits": 160, "emptyDirSizeLimitUnits": 192, "ephemeralRequestUnits": 224, "writableAndLogHeadroomUnits": 32, "inequalitiesHold": True},
        "pinAwarePrune": prune, "publicRegistryEvents": 0, "egressPolicy": "DNS plus in-cluster distribution only", "crossNodeReuse": "UNVERIFIED",
    }, added)


def execute() -> dict[str, Any]:
    reset_namespace()
    substrate = observe_fingerprint()
    suffix = hashlib.sha256(os.urandom(16)).hexdigest()[:10]
    bucket = "p48-" + suffix
    registry_before: set[str] = set()
    registry_added: set[str] = set()
    determinism: dict[str, Any] = {}
    cache: dict[str, Any] = {}
    cleanup: dict[str, Any] = {}
    try:
        apply(namespace_manifest())
        with phase34.port_forward("platform-system", "service/minio", phase30.MINIO_PORT, 9000):
            phase37.ensure_bucket(bucket)
            registry_before = set(phase37.list_keys("registry"))
            determinism = determinism_drill(bucket, substrate)
        cache, registry_added = cache_drill(registry_before)
    finally:
        reset_namespace()
        minio_bucket_absent = False
        try:
            with phase34.port_forward("platform-system", "service/minio", phase30.MINIO_PORT, 9000):
                for key in sorted(registry_added):
                    phase37.delete_object("registry", key)
                status, _, _ = phase37.s3_request("GET", bucket, query={"list-type": "2"})
                if status == 200:
                    for key in phase37.list_keys(bucket):
                        phase37.delete_object(bucket, key)
                    phase37.s3_request("DELETE", bucket)
                minio_bucket_absent = phase37.s3_request("GET", bucket, query={"list-type": "2"})[0] == 404
                digest_hex = ENGINE_DIGEST.removeprefix("sha256:")
                remaining_added = sorted(key for key in set(phase37.list_keys("registry")) - registry_before if "determinism-jitcache-engine" in key or digest_hex in key) if registry_before else []
        except Exception as error:
            remaining_added = [f"cleanup-error:{type(error).__name__}"]
        namespace_absent = kubectl("get", "namespace", NAMESPACE, check=False).returncode != 0
        cleanup = {"namespaceAbsent": namespace_absent, "minioBucketAbsent": minio_bucket_absent, "registryAddedKeysAbsent": not remaining_added, "remainingRegistryAddedKeys": remaining_added}
    if not all([cleanup["namespaceAbsent"], cleanup["minioBucketAbsent"], cleanup["registryAddedKeysAbsent"]]):
        raise LiveFailure(f"cleanup:{cleanup}")
    evidence: dict[str, Any] = {
        "schema": "amoebius.phase48.determinism-jitcache-live.v1", "date": dt.datetime.now(dt.timezone.utc).date().isoformat(),
        "register": 3, "substrate": "linux-cpu", "substrateFingerprint": substrate,
        "determinism": determinism, "cache": cache,
        "provisionRejections": ["CachePeakExceedsBudget", "ResidentSizeConflict", "DeletionNotObserved", "OwnerEphemeralUnderReserved", "FirstMissConcurrencyInvalid"],
        "deferred": {"tier2Model": "UNVERIFIED until Phase 49", "tier3CudaKernel": "UNVERIFIED until Phase 51", "crossSubstrateBitEquality": "UNVERIFIED", "crossNodeReuse": "UNVERIFIED"},
        "universalLinuxCpu": {"availableOnEveryHardwareSubstrate": True, "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
        "cleanup": cleanup,
    }
    evidence["evidenceDigest"] = fingerprint(evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main() -> int:
    try:
        evidence = execute()
        print(f"determinism-jitcache-determinism-jitcache-live: PASS ({evidence['evidenceDigest']})")
        return 0
    except Exception as error:
        print(f"determinism-jitcache-determinism-jitcache-live: FAIL: {error}", file=sys.stderr)
        reset_namespace()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
