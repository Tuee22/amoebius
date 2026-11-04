#!/usr/bin/env python3
"""Read retained service files outside the pods; never credit ledger deletion.

The fixed limits are reviewed finite-fixture inputs. Raw file census validates
their premises; an observed low-water mark never becomes a capacity operand.
BookKeeper4.17.2 formats: DefaultEntryLogger, Journal/JournalChannel, FileInfo.
ZooKeeper3.9.3 formats: FileTxnLog and Jute Util transaction framing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import struct
import time
import zlib
from pathlib import Path
from typing import Any

import containment
import platform_backbone_zookeeper_observer as zookeeper_wire

MIB = 1048576
ZK_PREALLOCATION_KIB = 16380
ZK_INITIAL_LOG_BYTES = 16 + ZK_PREALLOCATION_KIB * 1024
ZK_NEXT_PAD_POSITION = ZK_INITIAL_LOG_BYTES - 4096


class CensusFailure(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise CensusFailure(reason)


def bookkeeper_records(data: bytes, journal: bool) -> dict[str, Any]:
    """Count every retained normal record, including dead/offloaded ledgers.

    Journal control records and entry-log ledger-map records remain separately
    charged. Zero preallocation and sector padding are not logical messages.
    """
    require(len(data) >= 8 and data[:4] == (b"BKLG" if journal else b"BKLO"), "bookkeeper-file-signature")
    version = struct.unpack_from(">i", data, 4)[0]
    require(version in ((5, 6) if journal else (0, 1)), "bookkeeper-file-version")
    position = 512 if journal else 1024
    require(len(data) >= position, "bookkeeper-header-truncated")
    entries: dict[tuple[int, int], tuple[int, str]] = {}
    serialized = control = duplicates = 0
    while position + 4 <= len(data):
        size = struct.unpack_from(">i", data, position)[0]
        if size == 0:
            require(not any(data[position:]), "bookkeeper-nonzero-after-preallocation")
            break
        if journal and size == -256:
            require(position + 8 <= len(data), "bookkeeper-padding-truncated")
            padding = struct.unpack_from(">i", data, position + 4)[0]
            require(padding >= 0 and position + 8 + padding <= len(data), "bookkeeper-padding-invalid")
            position += 8 + padding
            continue
        require(size >= 16 and position + 4 + size <= len(data), "bookkeeper-record-truncated-or-invalid")
        body = data[position + 4:position + 4 + size]
        ledger, entry = struct.unpack_from(">qq", body)
        if ledger < 0 or entry < 0:
            control += size + 4
        else:
            require(entry < 1024, "bookkeeper-entry-id-exceeds-index-page")
            key, extent = (ledger, entry), (size + 4, hashlib.sha256(body).hexdigest())
            require(key not in entries or entries[key] == extent, "bookkeeper-conflicting-entry-identity")
            duplicates += int(key in entries)
            entries[key] = extent
            serialized += size + 4
        position += size + 4
    require(not any(data[position:]), "bookkeeper-unframed-trailer")
    return {"entries": entries, "serializedBytes": serialized, "controlBytes": control,
            "duplicateRecordCount": duplicates, "version": version}


def zookeeper_transactions(data: bytes) -> dict[str, int]:
    require(len(data) >= 16 and data[:4] == b"ZKLG" and struct.unpack_from(">i", data, 4)[0] == 2,
            "zookeeper-log-signature-or-version")
    position, count, serialized = 16, 0, 0
    while position + 12 <= len(data):
        checksum, size = struct.unpack_from(">Qi", data, position)
        if size == 0:
            require(checksum == 0 and not any(data[position:]), "zookeeper-nonzero-after-preallocation")
            break
        require(32 <= size <= MIB and position + 13 + size <= len(data), "zookeeper-transaction-extent")
        body = data[position + 12:position + 12 + size]
        require(zlib.adler32(body) & 0xffffffff == checksum, "zookeeper-transaction-checksum")
        require(data[position + 12 + size] == 0x42, "zookeeper-transaction-terminator")
        serialized += size + 13
        count += 1
        position += size + 13
    require(not any(data[position:]), "zookeeper-unframed-trailer")
    require(zookeeper_history_below_next_padding(serialized), "zookeeper-log-near-preallocation-boundary")
    return {"transactionCount": count, "serializedTransactionBytes": serialized}


def zookeeper_history_below_next_padding(serialized_bytes: int) -> bool:
    return 0 <= serialized_bytes and serialized_bytes + 16 < ZK_NEXT_PAD_POSITION


def zookeeper_snapshot(data: bytes) -> dict[str, int]:
    # A complete decode is stronger than an outer checksum. An ordinary
    # fuzzy snapshot still supplies no current-state/history witness.
    try:
        snapshot = zookeeper_wire.parse_snapshot(data)
    except zookeeper_wire.ZooKeeperObservationFailure as problem:
        raise CensusFailure("zookeeper-complete-snapshot:" + str(problem)) from problem
    return {"snapshotBytes": snapshot.wire_bytes, "sessionCount": len(snapshot.sessions)}


def stable_bytes(path: Path, maximum: int) -> bytes:
    for _attempt in range(3):
        before = path.stat()
        require(before.st_size <= maximum, "service-file-extent-bound:" + path.name)
        with path.open("rb") as stream:
            data = stream.read(maximum + 1)
        after = path.stat()
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) == \
           (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            require(len(data) == before.st_size, "service-file-short-read")
            return data
    raise CensusFailure("service-file-not-stable:" + path.name)


def inventory(root: Path) -> dict[str, Any]:
    files = {}
    def unreadable(problem):
        if not isinstance(problem, FileNotFoundError): raise problem
    for directory, directories, names in os.walk(root, followlinks=False, onerror=unreadable):
        for name in directories + names:
            path = Path(directory) / name
            try:
                observed = path.lstat()
            except FileNotFoundError:
                continue  # Concurrent GC is represented by the next delta.
            require(stat.S_ISDIR(observed.st_mode) or stat.S_ISREG(observed.st_mode), "service-census-special-file")
            if stat.S_ISREG(observed.st_mode):
                files[str(path.relative_to(root))] = {"sizeBytes": observed.st_size, "allocatedBytes": observed.st_blocks * 512,
                    "device": observed.st_dev, "inode": observed.st_ino, "modifiedNs": observed.st_mtime_ns}
    space = os.statvfs(root)
    return {"files": files, "device": root.stat().st_dev,
            "usedBytes": (space.f_blocks - space.f_bfree) * space.f_frsize,
            "availableBytes": space.f_bavail * space.f_frsize}


def validate_extents(name: str, files: dict[str, Any]) -> dict[str, int]:
    allocated = sum(row["allocatedBytes"] for row in files.values())
    charged = sum(max(row["sizeBytes"], row["allocatedBytes"]) for row in files.values())
    if "bookkeeper" in name:
        journals = [row for path, row in files.items() if path.endswith(".txn")]
        indexes = [row for path, row in files.items() if path.endswith(".idx")]
        require(len(journals) <= 2 and all(row["sizeBytes"] <= 16 * MIB and row["allocatedBytes"] <= 16 * MIB for row in journals),
                "bookkeeper-journal-generations-or-extent")
        require(len(indexes) <= 512 and all(max(row["sizeBytes"], row["allocatedBytes"]) <= 16384 for row in indexes),
                "bookkeeper-index-count-or-extent")
        journal_charge = sum(max(row["sizeBytes"], row["allocatedBytes"]) for row in journals)
        index_charge = sum(max(row["sizeBytes"], row["allocatedBytes"]) for row in indexes)
        # This drill performs no member-recovery transition. Keep its4MiB
        # incoming generation unavailable to ordinary steady-state files.
        require(charged - journal_charge - index_charge <= 12 * MIB, "bookkeeper-data-and-auxiliary-bound")
        require(charged <= 52 * MIB, "bookkeeper-steady-profile-exceeded")
        return {"journalGenerations": len(journals), "indexFiles": len(indexes),
                "allocatedBytes": allocated}
    if "zookeeper" in name:
        logs = [row for path, row in files.items() if Path(path).name.startswith("log.")]
        snapshots = [row for path, row in files.items() if Path(path).name.startswith("snapshot.")]
        require(len(logs) <= 2 and all(max(row["sizeBytes"], row["allocatedBytes"]) <= 16 * MIB for row in logs),
                "zookeeper-log-generations-or-extent")
        require(len(snapshots) <= 3 and all(max(row["sizeBytes"], row["allocatedBytes"]) <= MIB for row in snapshots),
                "zookeeper-snapshot-generations-or-extent")
        log_charge = sum(max(row["sizeBytes"], row["allocatedBytes"]) for row in logs)
        snapshot_charge = sum(max(row["sizeBytes"], row["allocatedBytes"]) for row in snapshots)
        require(charged - log_charge - snapshot_charge <= MIB, "zookeeper-path-system-allowance")
        require(charged <= 36 * MIB, "zookeeper-steady-profile-exceeded")
        return {"logGenerations": len(logs), "snapshotGenerations": len(snapshots),
                "allocatedBytes": allocated}
    history_names = {"zookeeper-history/state", "zookeeper-history/state.next", "zookeeper-history/owner.lock"}
    gateway_names = {"state.json", "state.json.next", "owner.lock"}
    require(set(files) <= history_names | gateway_names, "gateway-state-file-domain")
    require(all(max(row["sizeBytes"], row["allocatedBytes"]) <= MIB for path, row in files.items()
                if path not in {"owner.lock", "zookeeper-history/owner.lock"}), "gateway-state-profile-exceeded")
    require(all(row["sizeBytes"] == 0 for path, row in files.items() if path.endswith("owner.lock")),
            "gateway-state-lock-extent")
    history_charge = sum(max(row["sizeBytes"], row["allocatedBytes"]) for path, row in files.items() if path in history_names)
    require(history_charge <= 2*MIB and charged-history_charge <= 3*MIB and charged <= 8*MIB,
            "gateway-state-profile-exceeded")
    return {"allocatedBytes": allocated}


def gateway_filesystem_growth(initial_used: int, current_used: int) -> int:
    require(type(initial_used) is int and type(current_used) is int and initial_used >= 0 and current_used >= 0,
            "gateway-whole-filesystem-observation")
    growth = max(0, current_used-initial_used)
    require(growth <= 8*MIB, "gateway-whole-filesystem-growth")
    return growth


def final_records(name: str, root: Path, files: dict[str, Any], *, capture: Path | None = None) -> dict[str, Any]:
    history: dict[tuple[int, int], tuple[int, str]] = {}
    journal_bytes = entry_bytes = control_bytes = txn_count = txn_bytes = 0
    journal_controls = entrylog_metadata = snapshot_count = maximum_snapshot = 0
    raw_files: dict[str, dict[str, Any]] = {}
    def read(relative: str, maximum: int) -> bytes:
        require(not Path(relative).is_absolute() and ".." not in Path(relative).parts, "service-census-raw-path")
        path = root / relative
        require(not path.is_symlink(), "service-census-raw-symlink")
        def metadata():
            observed = path.stat()
            return {"sizeBytes": observed.st_size, "allocatedBytes": observed.st_blocks * 512,
                    "device": observed.st_dev, "inode": observed.st_ino, "modifiedNs": observed.st_mtime_ns}
        if capture is not None:
            require(metadata() == files[relative], "service-census-source-changed-after-final-sample")
        data = stable_bytes(path, maximum)
        if capture is not None:
            require(metadata() == files[relative] and len(data) == files[relative]["sizeBytes"],
                    "service-census-source-changed-during-final-capture")
            target = capture / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as saved:
                saved.write(data)
            raw_files[relative] = {"bytes": len(data), "sha256": "sha256:" + hashlib.sha256(data).hexdigest()}
        return data
    for relative in sorted(files):
        path = root / relative
        if "bookkeeper" in name and path.suffix in {".log", ".txn"}:
            parsed = bookkeeper_records(read(relative, 32 * MIB), path.suffix == ".txn")
            for identity, extent in parsed["entries"].items():
                require(identity not in history or history[identity] == extent, "bookkeeper-journal-entrylog-conflict")
                history[identity] = extent
            if path.suffix == ".txn":
                journal_bytes += parsed["serializedBytes"]
                journal_controls += parsed["controlBytes"]
            else:
                entry_bytes += parsed["serializedBytes"]
                entrylog_metadata += parsed["controlBytes"]
            control_bytes += parsed["controlBytes"]
        elif "bookkeeper" in name and path.suffix == ".idx":
            data = read(relative, 16384)
            require(len(data) >= 1024 and data[:4] == b"BKLE" and struct.unpack_from(">i", data, 4)[0] in (0, 1),
                    "bookkeeper-index-signature-or-version")
        elif "zookeeper" in name and path.name.startswith("log."):
            data = read(relative, 16 * MIB)
            parsed = zookeeper_transactions(data)
            try:
                decoded = zookeeper_wire.parse_transaction_log(data)
            except zookeeper_wire.ZooKeeperObservationFailure as problem:
                raise CensusFailure("zookeeper-complete-log:" + str(problem)) from problem
            require(len(decoded) == parsed["transactionCount"]
                    and sum(record.framed_bytes for record in decoded) == parsed["serializedTransactionBytes"],
                    "zookeeper-complete-log-framing-mismatch")
            txn_count += parsed["transactionCount"]
            txn_bytes += parsed["serializedTransactionBytes"]
        elif "zookeeper" in name and path.name.startswith("snapshot."):
            parsed = zookeeper_snapshot(read(relative, MIB))
            snapshot_count += 1
            maximum_snapshot = max(maximum_snapshot, parsed["snapshotBytes"])
    if "bookkeeper" in name:
        require(bool(history), "bookkeeper-durable-history-unavailable")
        require(len({ledger for ledger, _ in history}) <= 512, "bookkeeper-history-ledger-count")
        require(sum(size for size, _ in history.values()) + journal_controls <= 4 * MIB, "bookkeeper-serialized-history-bound")
        require(entry_bytes + journal_controls <= 4 * MIB, "bookkeeper-retained-physical-history-bound")
    result = {"durableUniqueEntries": len(history), "durableLedgerIds": sorted({ledger for ledger, _ in history}),
            "serializedHistoryBytes": sum(size for size, _ in history.values()) + journal_controls,
            "normalEntryHistoryBytes": sum(size for size, _ in history.values()),
            "journalControlRecordBytes": journal_controls, "entryLogMetadataRecordBytes": entrylog_metadata,
            "retainedEntryLogRecordBytes": entry_bytes, "retainedJournalRecordBytes": journal_bytes,
            "controlRecordBytes": control_bytes, "transactionCount": txn_count, "serializedTransactionBytes": txn_bytes,
            "sealedSnapshotCount": snapshot_count, "maximumSealedSnapshotBytes": maximum_snapshot}
    if capture is not None:
        result["rawFiles"] = raw_files
    return result


def verify_final_records(directory: Path, volume: str, expected: dict[str, Any], files: dict[str, Any]) -> None:
    """Recompute counters from saved individually captured durable files.

    This is not an atomic cross-file snapshot or complete lifetime history.
    """
    require(Path(volume).name == volume, "service-census-raw-volume")
    raw = expected.get("rawFiles")
    require(isinstance(raw, dict), "service-census-raw-inventory-absent")
    selected = {relative for relative in files
                if ("bookkeeper" in volume and Path(relative).suffix in {".log", ".txn", ".idx"})
                or ("zookeeper" in volume and Path(relative).name.startswith(("log.", "snapshot.")))}
    require(set(raw) == selected, "service-census-raw-inventory-mismatch")
    root = directory / "raw" / volume
    for relative, entry in raw.items():
        require(not Path(relative).is_absolute() and ".." not in Path(relative).parts, "service-census-raw-path")
        target = root / relative
        require(target.resolve().is_relative_to(root.resolve()) and not target.is_symlink(), "service-census-raw-path")
        data = stable_bytes(target, 32 * MIB)
        require(len(data) == files[relative]["sizeBytes"], "service-census-raw-final-extent-mismatch")
        require(entry == {"bytes": len(data), "sha256": "sha256:" + hashlib.sha256(data).hexdigest()},
                "service-census-raw-digest")
    actual = final_records(volume, root, raw)
    require(actual == {key: value for key, value in expected.items() if key != "rawFiles"},
            "service-census-final-record-drift")


def watch(root: Path, output: Path, summary: Path, stop: Path) -> None:
    volumes = {"phase30-" + service + "-" + str(ordinal): root / "retained/mounts" / ("phase30-" + service + "-" + str(ordinal))
               for service in ("bookkeeper", "zookeeper") for ordinal in range(3)}
    volumes["phase30-gateway-state"] = root / "retained/mounts/phase30-gateway-state"
    require(len({path.stat().st_dev for path in volumes.values()}) == 7, "service-census-filesystem-alias")
    previous = {name: {} for name in volumes}
    peaks: dict[str, dict[str, int]] = {name: {} for name in volumes}
    count = 0
    charged_peaks = {name: 0 for name in volumes}
    gateway_initial, gateway_growth = {}, {}
    with output.open("x") as trace:
        while True:
            current = {name: inventory(path) for name, path in volumes.items()}
            changes = {}
            for name, row in current.items():
                metrics = validate_extents(name, row["files"])
                if name == "phase30-gateway-state":
                    if count == 0:
                        require(not row["files"], "gateway-filesystem-not-empty-before-writers")
                        gateway_initial[name] = row["usedBytes"]
                    growth = gateway_filesystem_growth(gateway_initial[name], row["usedBytes"])
                    gateway_growth[name] = max(gateway_growth.get(name, 0), growth)
                charged_peaks[name] = max(charged_peaks[name], sum(max(value["sizeBytes"], value["allocatedBytes"]) for value in row["files"].values()))
                peaks[name] = {key: max(peaks[name].get(key, 0), value) for key, value in metrics.items()}
                changed = {key: value for key, value in row["files"].items() if previous[name].get(key) != value}
                deleted = sorted(set(previous[name]) - set(row["files"]))
                changes[name] = {"changed": changed, "deleted": deleted, "device": row["device"], "metrics": metrics,
                                 "usedBytes": row["usedBytes"]}
                previous[name] = row["files"]
            trace.write(json.dumps({"timeNs": time.time_ns(), "volumes": changes}, sort_keys=True) + "\n")
            trace.flush()
            count += 1
            require(trace.tell() <= 32 * MIB, "service-census-trace-bound")
            if stop.exists(): break
            time.sleep(.25)
    records = {name: final_records(name, path, previous[name], capture=output.parent / "raw" / name)
               for name, path in volumes.items()}
    summary.write_text(json.dumps({"schema": "amoebius.backbone-service-census.v1", "samples": count,
        "peakMetrics": peaks, "peakChargedExtentBytes": charged_peaks, "finalRecords": records, "tracePath": output.name,
        "gatewayInitialFilesystemUsedBytes": gateway_initial, "gatewayPeakFilesystemGrowthBytes": gateway_growth,
        "traceSha256": "sha256:" + hashlib.sha256(output.read_bytes()).hexdigest()}, sort_keys=True, indent=2) + "\n")


def verify_trace(directory: Path, summary: dict[str, Any], devices: dict[str, int]) -> dict[str, Any]:
    name = summary.get("tracePath", "")
    require(Path(name).name == name and name.endswith(".jsonl"), "service-census-trace-path")
    path = directory / name
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 32 * MIB, "service-census-trace-unavailable")
    encoded = path.read_bytes()
    require(summary.get("traceSha256") == "sha256:" + hashlib.sha256(encoded).hexdigest(), "service-census-trace-digest")
    files: dict[str, dict[str, Any]] = {name: {} for name in devices}
    peaks: dict[str, dict[str, int]] = {name: {} for name in devices}
    count, previous_time = 0, 0
    charged_peaks = {name: 0 for name in devices}
    gateway_initial, gateway_growth = {}, {}
    for line in encoded.splitlines():
        sample = json.loads(line)
        require(type(sample["timeNs"]) is int and sample["timeNs"] > previous_time, "service-census-trace-time")
        previous_time = sample["timeNs"]
        require(set(sample["volumes"]) == set(devices), "service-census-trace-inventory")
        for volume, row in sample["volumes"].items():
            require(row["device"] == devices[volume], "service-census-filesystem-provenance")
            for deleted in row["deleted"]:
                require(deleted in files[volume], "service-census-unobserved-deletion")
                del files[volume][deleted]
            for relative, observed in row["changed"].items():
                require(not Path(relative).is_absolute() and ".." not in Path(relative).parts
                    and observed["device"] == devices[volume]
                    and all(type(observed[field]) is int and observed[field] >= 0
                            for field in ("sizeBytes", "allocatedBytes", "inode", "modifiedNs")), "service-census-invalid-file-metadata")
                files[volume][relative] = observed
            metrics = validate_extents(volume, files[volume])
            if volume == "phase30-gateway-state":
                if count == 0:
                    require(not files[volume], "gateway-filesystem-not-empty-before-writers")
                    gateway_initial[volume] = row["usedBytes"]
                growth = gateway_filesystem_growth(gateway_initial[volume], row["usedBytes"])
                gateway_growth[volume] = max(gateway_growth.get(volume, 0), growth)
            charged_peaks[volume] = max(charged_peaks[volume], sum(max(value["sizeBytes"], value["allocatedBytes"]) for value in files[volume].values()))
            require(metrics == row["metrics"], "service-census-metric-drift")
            peaks[volume] = {key: max(peaks[volume].get(key, 0), value) for key, value in metrics.items()}
        count += 1
    require(charged_peaks == summary.get("peakChargedExtentBytes"), "service-census-charged-extent-drift")
    require(gateway_initial == summary.get("gatewayInitialFilesystemUsedBytes", {})
            and gateway_growth == summary.get("gatewayPeakFilesystemGrowthBytes", {}), "gateway-filesystem-growth-summary-drift")
    require(count >= 2 and count == summary.get("samples") and peaks == summary.get("peakMetrics"), "service-census-summary-drift")
    require(set(summary.get("finalRecords", {})) == set(devices), "service-census-final-record-inventory")
    for volume, row in summary["finalRecords"].items():
        verify_final_records(directory, volume, row, files[volume])
        if "bookkeeper" in volume:
            require(row["durableUniqueEntries"] > 0 and row["serializedHistoryBytes"] <= 4 * MIB
                    and 0 < len(row["durableLedgerIds"]) <= 512, "service-census-history-bound")
        if "zookeeper" in volume:
            require(row["transactionCount"] > 0 and row["serializedTransactionBytes"] < 4 * 16 * MIB
                    and row["sealedSnapshotCount"] > 0 and row["maximumSealedSnapshotBytes"] <= MIB,
                    "service-census-transactions-unavailable")
    return {"rawTraceVerified": True, "samples": count, "peakMetrics": peaks, "peakChargedExtentBytes": charged_peaks,
            "historyEvidence": "current-durable-journal-and-entrylog-union; no metadata-deletion credit"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("test-root", "output", "summary", "stop"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    root = containment.require_state_path(args.test_root, "test", actor="test")
    require((root / containment.MARKER).read_bytes() == containment._marker_bytes(root.name), "service-census-owner-marker")
    for path in (args.output, args.summary, args.stop): containment.require_state_path(path, "build", actor="test")
    watch(root, args.output, args.summary, args.stop)


if __name__ == "__main__":
    main()
