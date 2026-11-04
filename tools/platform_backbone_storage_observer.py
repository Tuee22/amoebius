#!/usr/bin/env python3
"""Independent Phase-30 arithmetic and raw retained-filesystem observation.

The reference reads the publisher's artifact/preflight observations and the
declared three-member/four-drive profile. It never calls the Haskell provision,
imports its implementation, or treats its recorded component totals as inputs.
Distribution link paths and contents follow upstream v2.8.3 paths.go/blobstore.go.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import itertools
import json
import os
import stat
import subprocess
from pathlib import Path
from typing import Any

import containment

MIB = 1024**2
OFFLOAD_ORACLE = Path(__file__).resolve().parents[1] / "test/oracle/platform_backbone_offload_profile.json"
HISTORY_STORAGE_ORACLE = Path(__file__).resolve().parents[1] / "test/oracle/platform_backbone_history_store_storage.json"
HISTORY_STORE_ORACLE = Path(__file__).resolve().parents[1] / "test/oracle/platform_backbone_zookeeper_history_store.json"


class StorageObservationFailure(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise StorageObservationFailure(reason)


def history_storage_reference(public: dict[str, Any], parent_raw: int) -> dict[str, Any]:
    """Independent reviewed operands; never reads the native budget projection."""
    amendment = json.loads(HISTORY_STORAGE_ORACLE.read_text())
    operands, expected = amendment["operands"], amendment["expected"]
    store = json.loads(HISTORY_STORE_ORACLE.read_text())
    return {"originalGateway": {"currentBytes": operands["gatewayCurrentBytes"],
                "candidateBytes": operands["gatewayCandidateBytes"], "failedBytes": operands["gatewayFailedBytes"],
                "controlReserveBytes": operands["gatewayControlReserveBytes"],
                "dedicatedUsableBytes": expected["unchangedOriginalGatewayUsableBytes"]},
            "metadataHistory": {"currentSlotBytes": operands["historyCurrentSlotBytes"],
                "candidateSlotBytes": operands["historyCandidateSlotBytes"],
                "extraReaderSlotBytes": operands["historyExtraReaderSlotBytes"],
                "maximumExtraReaders": operands["historyMaximumExtraReaders"],
                "enforcedFileMaximumBytes": store["storeMaximumBytes"],
                "derivedEncodingUpperBoundBytes": store["nativeEncodingUpperBound"]["maximumTotalStateBytes"],
                "reservedEncodingUpperBoundBytes": operands["historyNativeEncodingUpperBoundBytes"],
                "dedicatedUsableBytes": expected["additionalHistoryStoreUsableBytes"], "policy": store["policy"]},
            "combinedFilesystemUsableBytes": expected["combinedGatewayFilesystemUsableBytes"],
            "presentedBytes": expected["presentedBytesAfter500BasisPoints"],
            "requiredRawBytes": expected["rawFilesystemBytes"], "rawSupplyBytes": operands["rawFilesystemSupplyBytes"],
            "parentRequiredRawBytes": parent_raw, "parentSupplyRawBytes": public["backingCapacityBytes"]}


def reference(public: dict[str, Any]) -> dict[str, Any]:
    artifact, preflight, publication = (public[name] for name in ("artifact", "preflight", "publication"))
    records = artifact["registryObjects"]
    objects = {row["digest"]: row["storedBytes"] for row in records}
    require(len(objects) == len(records) and bool(objects), "duplicate-or-empty-image-inventory")
    index = artifact["imageIndexDigest"]
    require(publication["indexDigest"] == index and publication["preflightFingerprint"] == preflight["fingerprint"],
            "publication-identity-mismatch")
    old = preflight["registry"]
    require(old["workspaceModel"] == "largest-compressed-object-per-upload-v1"
            and old["failedUploadModel"] == "three-one-gib-capped-partials-v1", "unsupported-registry-model")
    largest = max(objects.values())
    require(largest <= 512 * MIB and old["uploadConcurrency"] <= 2, "image-exceeds-bounded-minio-execution-profile")
    workspace = old["uploadConcurrency"] * largest
    failures = 3 * min(largest, 1024 * MIB)
    stored = sum(objects.values())
    peak = stored + workspace + failures
    require((stored, workspace, failures, peak, len(objects)) ==
            tuple(old[key] for key in ("storedBytes", "workspaceBytes", "failedUploadBytes", "peakBytes", "objectCount")),
            "original-registry-arithmetic-mismatch")
    prefix = "docker/registry/v2/"
    repository = prefix + "repositories/" + publication["repository"] + "/"
    driver = {}

    def link(key: str, identity: str) -> None:
        driver[key] = {"bytes": len(identity.encode()), "sha256": "sha256:" + hashlib.sha256(identity.encode()).hexdigest()}

    kinds = {row["digest"]: row["kind"] for row in records}
    for identity, size in objects.items():
        require(len(identity) == 71 and identity.startswith("sha256:") and size > 0, "invalid-image-object")
        raw = identity[7:]
        driver[prefix + f"blobs/sha256/{raw[:2]}/{raw}/data"] = {"bytes": size, "sha256": identity}
        kind = kinds[identity]
        require(kind in {"layer", "config-amd64", "config-arm64", "manifest-amd64", "manifest-arm64", "index"}, "unknown-image-kind")
        directory = "_manifests/revisions" if kind.startswith("manifest-") or kind == "index" else "_layers"
        link(repository + f"{directory}/sha256/{raw}/link", identity)
    tag = repository + "_manifests/tags/" + publication["immutableTag"] + "/"
    link(tag + "current/link", index)
    link(tag + "index/sha256/" + index[7:] + "/link", index)
    populations = [
        ("registry", "FutureObjects", "post-cutover-blob", 1, 65536, 0),
        ("registry", "FutureObjects", "post-cutover-link", 1, 71, 0),
        ("registry", "FutureObjects", "registry-driver-metadata", 16, 4096, 0),
        ("registry", "ConcurrentObjects", "registry-upload-workspace", old["uploadConcurrency"], largest, 0),
        ("registry", "FailedOrphanObjects", "registry-failed-upload-window", 3, min(largest, 1024 * MIB), old["gcHorizonSeconds"]),
        ("application-canary", "FutureObjects", "admitted-canary", 1, 4096, 0),
        ("application-canary", "ConcurrentObjects", "canary-inflight", 1, 4096, 0),
        ("application-canary", "FailedOrphanObjects", "canary-failed-window", 1, 4096, 3600),
    ]
    offload = json.loads(OFFLOAD_ORACLE.read_text())
    populations.extend(("pulsar-offload", row["kind"], row["name"], row["count"],
                        row["maximumBytes"], row["windowSeconds"])
                       for row in offload["expected_populations"])
    if largest < 65536:
        populations.append(("registry", "ConcurrentObjects", "registry-future-write-workspace-excess", old["uploadConcurrency"], 65536 - largest, 0))
    if min(largest, 1024 * MIB) < max(65536, largest):
        populations.append(("registry", "FailedOrphanObjects", "registry-future-write-failed-excess", 3,
                            max(65536, largest) - min(largest, 1024 * MIB), old["gcHorizonSeconds"]))
    extents = [(1, row["bytes"]) for row in driver.values()] + [(row[3], row[4]) for row in populations]
    logical = sum(count * size for count, size in extents)
    count = sum(count for count, _ in extents)
    # One erasure set, EC:2 on four drives. Round every physical object
    # separately; reserve the full incoming recovery generation on each drive.
    stripe_cost = lambda size: ((size + 8191) // 8192) * 16384
    resident = sum(number * stripe_cost(size) for number, size in extents)
    metadata = 4 * 8192 * (1 + count)
    healing = 4 * ((resident + 3) // 4 + 8192)
    concurrent_orphan = 2 * stripe_cost(max(65536, largest))
    components = {"stripe-data-parity": resident, "metadata": metadata,
                  "healing": healing, "concurrent-orphan": concurrent_orphan}
    # Derive a named slot directly from individual shard operands. The
    # aggregate components above are independent cross-checks, not slot inputs.
    payload_per_drive = sum(number * ((size + 8191) // 8192) * 4096 for number, size in extents)
    metadata_per_drive = 8192 * (1 + count)
    incoming_per_drive = payload_per_drive + 8192
    write_per_drive = 2 * ((max(65536, largest) + 8191) // 8192) * 4096
    per_drive = payload_per_drive + metadata_per_drive + incoming_per_drive + write_per_drive
    slots = [{"driveId": i, "setId": 0, "claim": f"data{i}-minio-0", "backing": f"phase30-minio-{i}",
              "replacementClaim": "replacement-minio-replacement-0", "replacementDriveId": 4,
              "replacementBacking": "phase30-minio-replacement-0",
              "steadyBytes": payload_per_drive + metadata_per_drive + write_per_drive,
              "incomingRecoveryBytes": incoming_per_drive, "requiredUsableBytes": per_drive,
              "components": {"stripe-data-parity": payload_per_drive, "metadata": metadata_per_drive,
                             "healing": incoming_per_drive, "concurrent-orphan": write_per_drive}}
             for i in range(4)]

    def raw(usable: int, minimum: int = 64 * MIB) -> int:
        presented = (usable * 10500 + 9999) // 10000
        return max(minimum, ((presented + 64 * MIB - 1) // (64 * MIB)) * 64 * MIB)

    claims = {f"phase30-minio-{i}": (raw(per_drive), per_drive) for i in range(4)}
    # Four MiB of finite drill/control serialized history, including the deliberately
    # unsafe time-only case, plus a complete recovery generation and journal/index.
    bookie_usable = 8 * MIB + 48 * MIB
    zk_usable = 69 * MIB
    claims.update({f"phase30-bookkeeper-{i}": (raw(bookie_usable, 128 * MIB), bookie_usable) for i in range(3)})
    claims.update({f"phase30-zookeeper-{i}": (raw(zk_usable), zk_usable) for i in range(3)})
    source_usable = sum(row["bytes"] for row in driver.values()) + workspace + failures
    claims["phase30-registry-source"] = (raw(source_usable), source_usable)
    history_storage = json.loads(HISTORY_STORAGE_ORACLE.read_text())["expected"]
    claims["phase30-gateway-state"] = (history_storage["rawFilesystemBytes"], history_storage["combinedGatewayFilesystemUsableBytes"])
    claims["phase30-minio-replacement-0"] = (raw(per_drive), per_drive)
    claims["phase30-bookkeeper-replacement-0"] = (raw(bookie_usable, 128 * MIB), bookie_usable)
    minio_recovery = [{"failedMembers": failed, "replacements": [{"sourceId": member, "targetId": 4} for member in failed],
                       "incomingBytes": {"4": per_drive} if failed else {}, "segments": []}
                      for failed in ([], [0], [1], [2], [3])]
    bookie_recovery = []
    for writes in ([0, 1], [0, 2], [1, 2]):
        for failed in ([], [0], [1], [2]):
            bookie_recovery.append({"failedMembers": failed, "replacements": [{"sourceId": member, "targetId": 3} for member in failed],
                "incomingBytes": {"3": 4 * MIB} if any(member in writes for member in failed) else {},
                "segments": [{"id": "bounded-serialized-history", "bytes": 4 * MIB, "ensemble": [0, 1, 2], "writeSet": writes}]})
    pool = ((sum(size for size, _ in claims.values()) + 192 * MIB + 4096 + MIB - 1) // MIB) * MIB
    return {"objects": objects, "driver": driver, "originalPeak": peak, "logicalBytes": logical,
            "objectCount": count, "components": components, "populations": populations,
            "minioRecovery": minio_recovery, "bookieRecovery": bookie_recovery,
            "faultScenarios": [[], [0], [1], [2], [3]], "slots": slots, "claims": claims, "pool": pool}


def verify_plan(public: dict[str, Any], native: dict[str, Any]) -> dict[str, Any]:
    expected = reference(public)
    registry = native["registry"]
    require(registry["objectSet"] == expected["objects"] and registry["derivedPeak"] == expected["originalPeak"], "canonical-registry-provision-drift")
    actual_driver = {row["key"]: {key: row[key] for key in ("bytes", "sha256")} for row in registry["driverObjects"]}
    require(len(actual_driver) == len(registry["driverObjects"]) and actual_driver == expected["driver"], "registry-driver-object-map-drift")
    peak = native["objectStorePeak"]
    offload = json.loads(OFFLOAD_ORACLE.read_text())
    require(peak.get("sourceModels") == {"pulsar-offload": offload["expected_model_input_projection"]},
            "structured-source-model-input-drift")
    writers = peak.get("writerAdmissions", {})
    expected_writers = offload["expected_installed_source_join"]
    require(set(writers) == set(expected_writers) and all(
        {key: writers[name].get(key) for key in ("kind", "owner", "budget", "scope")} == row
        for name, row in expected_writers.items()), "installed-writer-owner-budget-scope-drift")
    require((peak["logicalBytes"], peak["objectCount"]) == (expected["logicalBytes"], expected["objectCount"]), "object-store-peak-drift")
    actual_populations = [(row["source"], row["kind"], row["name"], row["count"], row["maximumBytes"], row["windowSeconds"]) for row in peak["populations"]]
    require(sorted(actual_populations) == sorted(expected["populations"]), "structural-population-drift")
    residents = {(row["store"], row["tenant"], row["bucket"], row["key"]): row["bytes"] for row in peak["residents"]}
    require(len(residents) == len(peak["residents"]) and residents ==
            {("root-minio", "platform", "registry", key): row["bytes"] for key, row in expected["driver"].items()}, "physical-resident-identity-drift")
    geometry = native["minio"]
    require(native["minioRuntime"] == {"maximumObjectBytes": 512 * MIB, "maximumRequests": 2,
            "managedHeapBytes": 1280 * MIB, "memoryCeilingBytes": 1536 * MIB}, "minio-execution-profile-drift")
    require(geometry["components"] == expected["components"] and geometry["physicalBytes"] == sum(expected["components"].values()), "minio-physical-geometry-drift")
    require(sorted(geometry["faultScenarios"]) == sorted(expected["faultScenarios"]), "minio-incomplete-drive-failure-subsets")
    require(geometry.get("slots") == expected["slots"], "minio-slot-recovery-map-drift")
    require(geometry.get("replacementPool") == [{"driveId": 4, "claim": "replacement-minio-replacement-0",
            "backing": "phase30-minio-replacement-0", "requiredUsableBytes": expected["claims"]["phase30-minio-replacement-0"][1]}]
            and geometry.get("recoveryCases") == expected["minioRecovery"], "minio-replacement-pool-or-cases-drift")
    recovery = native.get("bookkeeperRecovery", {})
    require(recovery.get("activeMemberIds") == [0, 1, 2] and recovery.get("replacementMemberIds") == [3]
            and recovery.get("slotPeakBytes") == {str(member): 52 * MIB for member in range(4)}
            and recovery.get("recoveryCases") == expected["bookieRecovery"], "bookkeeper-pinned-recovery-cases-drift")
    require(recovery.get("replacement") == {"memberId": 3,
            "bookieId": "bookkeeper-replacement-0.bookkeeper.pulsar-system.svc.cluster.local:3181",
            "claim": "replacement-bookkeeper-replacement-0", "backing": "phase30-bookkeeper-replacement-0",
            "requiredUsableBytes": 56 * MIB}, "bookkeeper-replacement-identity-drift")
    claims = {row["name"]: (row["rawBytes"], row["requiredUsableBytes"]) for row in native["volumes"]}
    require(len(claims) == len(native["volumes"]) and claims == expected["claims"], "uniform-presented-claim-plan-drift")
    require(native["inventory"] == {name: size for name, (size, _) in claims.items()}, "inventory-debit-drift")
    pool = expected["pool"]
    overhead = max(64 * MIB, ((pool * 5 + 100 * MIB - 1) // (100 * MIB)) * MIB)
    require(native["poolCapacityBytes"] == pool and native["physicalPoolRawBytes"] == pool + overhead, "physical-pool-debit-drift")
    require(native["physicalPoolRawBytes"] <= public["backingCapacityBytes"], "physical-parent-overflow")
    require(native.get("gatewayStateStorage") == history_storage_reference(public, pool+overhead), "gateway-history-storage-binding-drift")
    require(native.get("gatewayStateBacking") == {"namespace": "platform-system", "executor": "platform-system/object-gateway",
            "pod": "object-gateway-0", "claimTemplate": "state", "claim": "state-object-gateway-0",
            "backing": "phase30-gateway-state", "parent": "retained-parent", "historySubdirectory": "zookeeper-history"},
            "gateway-history-backing-identity-drift")
    return {"registryObjectCount": len(expected["objects"]), "driverObjectCount": len(actual_driver),
            "logicalBytes": expected["logicalBytes"], "physicalBytes": sum(expected["components"].values()),
            "faultScenarios": expected["faultScenarios"], "independentArithmeticMatch": True}


def verify_negative_controls(public: dict[str, Any], native: dict[str, Any]) -> list[str]:
    """A matching native observation is paired with one-field corruptions.

    These controls exercise the reader, not the implementation's mutant quota.
    They run on the actual handoff and cannot supply a replacement golden.
    """
    controls = []
    for defect in ("registry-driver-map", "structural-population", "physical-identity", "physical-cost", "drive-subset", "ordinal-allocation", "parent-debit", "replacement-pool", "bookkeeper-eligibility", "structured-model-input", "writer-budget", "history-slot", "history-parent", "history-backing"):
        changed = copy.deepcopy(native)
        if defect == "registry-driver-map":
            changed["registry"]["driverObjects"][0]["sha256"] = "sha256:" + "0" * 64
            reason = "registry-driver-object-map-drift"
        elif defect == "structural-population":
            changed["objectStorePeak"]["populations"].pop()
            reason = "structural-population-drift"
        elif defect == "physical-identity":
            changed["objectStorePeak"]["residents"][0]["bucket"] = "foreign"
            reason = "physical-resident-identity-drift"
        elif defect == "physical-cost":
            changed["minio"]["physicalBytes"] = changed["minio"]["logicalBytes"]
            reason = "minio-physical-geometry-drift"
        elif defect == "drive-subset":
            changed["minio"]["faultScenarios"].pop()
            reason = "minio-incomplete-drive-failure-subsets"
        elif defect == "ordinal-allocation":
            changed["volumes"][0]["rawBytes"] -= 1
            reason = "uniform-presented-claim-plan-drift"
        elif defect == "parent-debit":
            changed["physicalPoolRawBytes"] -= 1
            reason = "physical-pool-debit-drift"
        elif defect == "replacement-pool":
            changed["minio"]["replacementPool"][0]["backing"] = "phase30-minio-0"
            reason = "minio-replacement-pool-or-cases-drift"
        elif defect == "structured-model-input":
            changed["objectStorePeak"]["sourceModels"]["pulsar-offload"]["futureLedger"]["customMetadata"].pop("application")
            reason = "structured-source-model-input-drift"
        elif defect == "writer-budget":
            changed["objectStorePeak"]["writerAdmissions"]["pulsar-offload"]["budget"] = "foreign"
            reason = "installed-writer-owner-budget-scope-drift"
        elif defect == "history-slot":
            changed["gatewayStateStorage"]["metadataHistory"]["currentSlotBytes"] -= 1
            reason = "gateway-history-storage-binding-drift"
        elif defect == "history-parent":
            changed["gatewayStateStorage"]["parentRequiredRawBytes"] -= 1
            reason = "gateway-history-storage-binding-drift"
        elif defect == "history-backing":
            changed["gatewayStateBacking"]["parent"] = "foreign"
            reason = "gateway-history-backing-identity-drift"
        else:
            changed["bookkeeperRecovery"]["recoveryCases"][1]["replacements"][0]["targetId"] = 1
            reason = "bookkeeper-pinned-recovery-cases-drift"
        try:
            verify_plan(public, changed)
        except StorageObservationFailure as error:
            require(str(error) == reason, "negative-control-wrong-reason:" + defect)
        else:
            raise StorageObservationFailure("negative-control-admitted:" + defect)
        controls.append(defect)
    return controls


def observe_filesystems(test_root: Path, native: dict[str, Any]) -> dict[str, Any]:
    test_root = containment.require_state_path(test_root, "test", actor="test")
    require((test_root / containment.MARKER).is_file(), "test-root-marker-absent")
    root = test_root / "retained"
    wanted = {**native["inventory"], "vault": 128 * MIB, "vault-audit": 64 * MIB}
    required = {row["name"]: row["requiredUsableBytes"] for row in native["volumes"]}
    rows = []
    devices = set()
    for name, size in sorted(wanted.items()):
        image = root / "images" / (name + ".ext4")
        mounted = root / "mounts" / name
        info = image.stat(follow_symlinks=False)
        require(stat.S_ISREG(info.st_mode) and info.st_size == size and info.st_blocks * 512 >= size, "child-image-not-physically-reserved")
        device = mounted.stat().st_dev
        require(device != root.stat().st_dev and device not in devices, "child-filesystem-not-distinct")
        devices.add(device)
        found = subprocess.run(("/usr/bin/findmnt", "-n", "-o", "SOURCE,FSTYPE", "--target", str(mounted)),
                               check=True, stdout=subprocess.PIPE, text=True).stdout.split()
        require(len(found) == 2 and found[0].startswith("/dev/loop") and found[1] == "ext4", "child-filesystem-identity-invalid")
        backing = Path("/sys/class/block") / Path(found[0]).name / "loop/backing_file"
        require(Path(backing.read_text().strip()).resolve() == image.resolve(), "child-loop-image-mismatch")
        space = os.statvfs(mounted)
        capacity = space.f_blocks * space.f_frsize
        require(capacity >= required.get(name, 0), "child-usable-volume-too-small")
        rows.append({"name": name, "rawBytes": size, "allocatedBytes": info.st_blocks * 512,
                     "filesystemDevice": device, "filesystemCapacityBytes": capacity,
                     "availableBytes": space.f_bavail * space.f_frsize, "filesystemType": "ext4"})
    pool = test_root / "disks/retained-durable-pool.ext4"
    info = pool.stat()
    require(info.st_size == native["physicalPoolRawBytes"] and info.st_blocks * 512 >= info.st_size, "parent-pool-not-physically-reserved")
    require(sum(wanted.values()) + 4096 <= native["poolCapacityBytes"], "aggregate-inventory-overflow")
    return {"volumes": rows, "inventoryDebitBytes": sum(wanted.values()),
            "physicalPoolAllocatedBytes": info.st_blocks * 512, "distinctFilesystems": len(devices)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--test-root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    public, native = (json.loads(path.read_text()) for path in (args.input, args.plan))
    result = verify_plan(public, native)
    result["readerNegativeControls"] = verify_negative_controls(public, native)
    if args.test_root is not None:
        result["physicalObservation"] = observe_filesystems(args.test_root, native)
    containment.require_state_path(args.output, "build", actor="test")
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
