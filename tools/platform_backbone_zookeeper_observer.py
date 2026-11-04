#!/usr/bin/env python3
"""Independent pinned ZooKeeper3.9.3 CHECKED/plain wire reader.

Parse limits bound the reader, not the deployed producer inventory or history.
Raw payloads stay in memory; public projections contain lengths and hashes.
This module does not infer a current tree from a checksum-valid old snapshot.
"""

from __future__ import annotations

import copy
import hashlib
import struct
import zlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

MIB = 1024**2
CONTAINER_OWNER = -(1 << 63)
STAT_FIELDS = ("czxid", "mzxid", "ctime", "mtime", "version", "cversion", "aversion", "ephemeralOwner", "pzxid")
OP_NAMES = {1: "Create", 15: "Create2", 19: "CreateContainer", 2: "Delete", 20: "DeleteContainer",
            5: "SetData", 7: "SetACL", 13: "CheckVersion", -10: "CreateSession", -11: "CloseSession",
            -1: "Error", 14: "Multi"}


class ZooKeeperObservationFailure(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ZooKeeperObservationFailure(reason)


@dataclass(frozen=True)
class EncodingProfile:
    stream_mode: str = "checked"
    snapshot_digest: bool = True
    snapshot_last_zxid: bool = True
    transaction_digest: bool = True
    close_session_paths: bool = True


class Reader:
    def __init__(self, data: bytes):
        self.data, self.position = data, 0

    @property
    def remaining(self) -> int:
        return len(self.data) - self.position

    def take(self, count: int) -> bytes:
        require(0 <= count <= self.remaining, "zookeeper-wire-truncated")
        result = self.data[self.position:self.position + count]
        self.position += count
        return result

    def number(self, form: str) -> int:
        return struct.unpack(">" + form, self.take(struct.calcsize(">" + form)))[0]

    def integer(self) -> int:
        return self.number("i")

    def long(self) -> int:
        return self.number("q")

    def count(self, maximum: int = 4096) -> int:
        count = self.integer()
        require(0 <= count <= maximum, "zookeeper-vector-count-outside-reader-profile")
        return count

    def buffer(self, maximum: int = MIB) -> bytes | None:
        length = self.integer()
        if length == -1:
            return None
        require(0 <= length <= maximum, "zookeeper-buffer-length-outside-reader-profile")
        return self.take(length)

    def text(self, maximum: int = 4096) -> str:
        raw = self.buffer(maximum)
        # Pinned Java readString uses UTF8 decoding, while Jute writeString
        # encodes UTF16 units. The selected ASCII domain avoids conflating
        # those two operations for surrogate/non-ASCII identities.
        require(raw is not None and all(32 <= byte < 127 for byte in raw), "zookeeper-non-ascii-or-null-identity")
        return raw.decode("ascii")

    def finish(self) -> None:
        require(self.remaining == 0, "zookeeper-wire-unparsed-trailer")


Acl = tuple[int, str, str]


def read_acls(reader: Reader) -> tuple[Acl, ...]:
    entries = []
    for _ in range(reader.count()):
        permissions, scheme, identity = reader.integer(), reader.text(), reader.text()
        require(0 <= permissions <= 31 and bool(scheme), "zookeeper-acl-invalid")
        entries.append((permissions, scheme, identity))
    return tuple(entries)


def valid_path(path: str, *, serialized: bool = False) -> bool:
    if serialized and path == "":
        return True
    if path == "/":
        return not serialized
    return (path.startswith("/") and not path.endswith("/")
            and all(part not in {"", ".", ".."} for part in path[1:].split("/")))


def node_path(path: str) -> str:
    return "" if path == "/" else path


@dataclass
class Node:
    data: bytes | None
    acl_id: int
    stat: dict[str, int]

    def projection(self) -> dict[str, Any]:
        return {"dataBytes": len(self.data or b""), "dataNull": self.data is None,
                "dataSha256": hashlib.sha256(self.data or b"").hexdigest(),
                "aclId": self.acl_id, "stat": dict(self.stat)}


@dataclass
class Snapshot:
    nodes: dict[str, Node]
    sessions: dict[int, int]
    acl_cache: dict[int, tuple[Acl, ...]]
    components: dict[str, int]
    digest_zxid: int | None
    digest_version: int | None
    tree_digest: int | None
    last_processed_zxid: int | None
    wire_bytes: int
    database_id: int = -1
    seals: list[dict[str, int]] = field(default_factory=list)

    def validate_tree(self) -> None:
        require("" in self.nodes and "/" not in self.nodes, "zookeeper-missing-or-aliased-root")
        for identity, timeout in self.sessions.items():
            require(identity not in {0, CONTAINER_OWNER} and timeout > 0, "zookeeper-session-invalid")
        for path, node in self.nodes.items():
            require(valid_path(path, serialized=True), "zookeeper-serialized-path-invalid")
            require(node.acl_id == -1 or node.acl_id in self.acl_cache, "zookeeper-node-acl-missing")
            owner = node.stat["ephemeralOwner"]
            require(owner in {0, CONTAINER_OWNER} or owner in self.sessions, "zookeeper-ephemeral-owner-missing")
            require(path != "" or owner == 0, "zookeeper-nonpersistent-root")
            if path:
                parent = path.rpartition("/")[0]
                require(parent in self.nodes, "zookeeper-node-parent-missing")
                require(self.nodes[parent].stat["ephemeralOwner"] in {0, CONTAINER_OWNER}, "zookeeper-session-ephemeral-has-child")

    def state_projection(self) -> dict[str, Any]:
        return {"nodes": {path: node.projection() for path, node in sorted(self.nodes.items())},
                "sessions": {str(owner): timeout for owner, timeout in sorted(self.sessions.items())},
                "aclCache": {str(identity): [{"perms": p, "scheme": s, "identity": i} for p, s, i in entries]
                             for identity, entries in sorted(self.acl_cache.items())},
                "lastProcessedZxid": self.last_processed_zxid, "treeDigest": tree_digest(self.nodes)}

    def projection(self) -> dict[str, Any]:
        component_names = {"file-header": "fileHeader", "sessions": "sessions", "acl-cache": "aclCache",
                           "node-rows": "nodeRows", "tree-end": "treeEnd", "base-seal": "baseSeal",
                           "digest-and-seal": "digestAndSeal", "last-zxid-and-seal": "lastZxidAndSeal"}
        return {"header": {"magic": "ZKSN", "version": 2, "dbid": self.database_id},
                "state": self.state_projection(),
                "digest": None if self.digest_version is None else {"zxid": self.digest_zxid,
                    "version": self.digest_version, "treeDigest": self.tree_digest},
                "serializedLastZxid": self.last_processed_zxid, "seals": self.seals,
                "bytes": self.wire_bytes, "componentBytes": {component_names[key]: value for key, value in self.components.items()}}


def read_seal(reader: Reader) -> dict[str, int]:
    prefix = reader.position
    expected = reader.number("Q")
    require(expected == zlib.adler32(reader.data[:prefix]) & 0xffffffff, "zookeeper-snapshot-checksum")
    require(reader.text() == "/", "zookeeper-snapshot-seal-marker")
    return {"offset": prefix, "adler32": expected}


def parse_snapshot(data: bytes, profile: EncodingProfile = EncodingProfile()) -> Snapshot:
    require(profile.stream_mode == "checked", "zookeeper-unsupported-snapshot-stream")
    require(33 <= len(data) <= MIB, "zookeeper-snapshot-extent")
    reader = Reader(data)
    require(reader.take(4) == b"ZKSN" and reader.integer() == 2, "zookeeper-snapshot-format")
    database_id = reader.long()
    components = {"file-header": 16}
    start = reader.position
    sessions = {}
    for _ in range(reader.count(1024)):
        identity, timeout = reader.long(), reader.integer()
        require(identity not in sessions, "zookeeper-duplicate-session")
        sessions[identity] = timeout
    components["sessions"] = reader.position-start
    start = reader.position
    cache = {}
    for _ in range(reader.count()):
        identity = reader.long()
        require(identity >= 0 and identity not in cache, "zookeeper-duplicate-or-invalid-acl-id")
        cache[identity] = read_acls(reader)
    components["acl-cache"] = reader.position-start
    start = reader.position
    nodes = {}
    while True:
        row_start = reader.position
        path = reader.text()
        if path == "/":
            components["node-rows"] = row_start-start
            components["tree-end"] = reader.position-row_start
            break
        require(path not in nodes and valid_path(path, serialized=True), "zookeeper-duplicate-or-invalid-node-path")
        require(len(nodes) < 4096, "zookeeper-node-count-outside-reader-profile")
        payload, acl_id = reader.buffer(), reader.long()
        stat = dict(zip(STAT_FIELDS, struct.unpack(">qqqqiiiqq", reader.take(60))))
        nodes[path] = Node(payload, acl_id, stat)
    seals = [read_seal(reader)]
    components["base-seal"] = 13
    digest_zxid = digest_version = digest = last_zxid = None
    if profile.snapshot_digest:
        digest_zxid, digest_version, digest = reader.long(), reader.integer(), reader.long()
        require(digest_version == 2, "zookeeper-unsupported-tree-digest-version")
        seals.append(read_seal(reader))
    components["digest-and-seal"] = 33 if profile.snapshot_digest else 0
    if profile.snapshot_last_zxid:
        last_zxid = reader.long()
        seals.append(read_seal(reader))
    components["last-zxid-and-seal"] = 21 if profile.snapshot_last_zxid else 0
    reader.finish()
    result = Snapshot(nodes, sessions, cache, components, digest_zxid, digest_version, digest, last_zxid, len(data), database_id, seals)
    result.validate_tree()
    require(sum(components.values()) == len(data), "zookeeper-snapshot-component-drift")
    return result


def validate_native_genesis(snapshot: Snapshot, *, file_name: str, snapshot_file_zxid: int) -> None:
    """Validate the selected static three-participant bootstrap wire shape.

    QuorumPeerMain sets config data/mtime directly before the initial save;
    those mutations are not client transactions. A valid shape is not fresh
    filesystem provenance, a committed endpoint or complete history. In
    particular Pulsar enables snapshot.trust.empty in its wrapper.
    """
    require(file_name == "snapshot.0" and snapshot_file_zxid == 0, "zookeeper-genesis-file-identity")
    require(snapshot.database_id == -1 and snapshot.wire_bytes == 742, "zookeeper-genesis-file-profile")
    require(snapshot.last_processed_zxid == 0 and snapshot.digest_zxid == 0
            and snapshot.digest_version == 2 and snapshot.tree_digest == 0, "zookeeper-genesis-marker")
    paths = {"", "/zookeeper", "/zookeeper/config", "/zookeeper/quota"}
    require(set(snapshot.nodes) == paths and not snapshot.sessions, "zookeeper-genesis-node-session-domain")
    require(snapshot.acl_cache == {1: ((1, "world", "anyone"),)}, "zookeeper-genesis-acl-cache")
    zero_stat = dict.fromkeys(STAT_FIELDS, 0)
    for path in paths - {"/zookeeper/config"}:
        node = snapshot.nodes[path]
        require(node.data == b"" and node.acl_id == -1 and node.stat == zero_stat,
                "zookeeper-genesis-builtin-node")
    config = snapshot.nodes["/zookeeper/config"]
    expected_stat = {**zero_stat, "version": -1, "aversion": -1, "mtime": config.stat["mtime"]}
    require(config.acl_id == 1 and config.stat == expected_stat and config.stat["mtime"] >= 0,
            "zookeeper-genesis-config-stat")
    require(config.data is not None, "zookeeper-genesis-config-null")
    rows = config.data.split(b"\n")
    servers = {("server." + str(ordinal+1) + "=zookeeper-" + str(ordinal)
                + ".zookeeper.pulsar-system.svc.cluster.local:2888:3888:participant").encode("ascii")
               for ordinal in range(3)}
    require(len(rows) == 4 and rows[-1] == b"version=0" and set(rows[:-1]) == servers,
            "zookeeper-genesis-static-config")


def verify_native_genesis_capture(directory: Path, evidence: dict[str, Any], devices: dict[str, int]) -> dict[str, Any]:
    """Revalidate saved bootstrap bytes and join independent device evidence."""
    require(evidence.get("capturedBeforeMetadataWriters") is True
            and evidence.get("sourceBackingsEmptyBeforeStart") is True
            and evidence.get("currentStateProof") is False, "zookeeper-genesis-capture-scope")
    members = evidence.get("members", [])
    require(len(members) == 3 and all(type(row.get("ordinal")) is int for row in members)
            and {row.get("ordinal") for row in members} == {0, 1, 2},
            "zookeeper-genesis-capture-member-domain")
    require(directory.is_dir() and not directory.is_symlink(), "zookeeper-genesis-capture-directory")
    seen_devices = set()
    for row in members:
        ordinal = row["ordinal"]
        backing = "phase30-zookeeper-" + str(ordinal)
        name = "member-" + str(ordinal) + "-snapshot.0"
        require(row.get("backing") == backing and row.get("file") == name, "zookeeper-genesis-capture-file-identity")
        path = directory / name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == 742,
                "zookeeper-genesis-capture-file-extent")
        data = path.read_bytes()
        require(row.get("sha256") == "sha256:" + hashlib.sha256(data).hexdigest(), "zookeeper-genesis-capture-digest")
        source = row.get("source", {})
        require(all(type(source.get(field)) is int and source[field] >= 0
                    for field in ("device", "inode", "sizeBytes", "allocatedBytes", "modifiedNs"))
                and source["inode"] > 0 and source["sizeBytes"] == len(data)
                and len(data) <= source["allocatedBytes"] <= MIB and source["device"] == devices.get(backing),
                "zookeeper-genesis-capture-device-identity")
        seen_devices.add(source["device"])
        snapshot = parse_snapshot(data)
        validate_native_genesis(snapshot, file_name="snapshot.0", snapshot_file_zxid=0)
        require(row.get("bootstrap") == snapshot.projection(), "zookeeper-genesis-capture-projection")
    require(len(seen_devices) == 3, "zookeeper-genesis-capture-device-alias")
    return {"rawBootstrapVerified": True, "members": 3, "bytesPerMember": 742, "completeCurrentStateProof": False}


@dataclass(frozen=True)
class Operation:
    opcode: int
    fields: dict[str, Any] = field(default_factory=dict)

    def projection(self) -> dict[str, Any]:
        result = {"kind": OP_NAMES[self.opcode]}
        for name, value in self.fields.items():
            if name == "data":
                result.update(dataBytes=len(value or b""), dataNull=value is None,
                              dataSha256=hashlib.sha256(value or b"").hexdigest())
            elif name == "children":
                result[name] = [child.projection() for child in value]
            elif name == "acls":
                result[name] = [{"perms": p, "scheme": s, "identity": i} for p, s, i in value]
            else:
                result[name] = value
        return result


def read_operation(reader: Reader, opcode: int, profile: EncodingProfile, *, child: bool = False) -> Operation:
    if child:
        require(opcode in {1, 2, 5, 13, -1}, "zookeeper-unsupported-selected-multi-child")
    fields: dict[str, Any] = {}
    if opcode in {1, 15, 19}:
        fields.update(path=reader.text(), data=reader.buffer(), acls=read_acls(reader))
        if opcode != 19:
            flag = reader.take(1)
            require(flag in {b"\x00", b"\x01"}, "zookeeper-create-boolean-invalid")
            fields["ephemeral"] = flag == b"\x01"
        fields["parentCVersion"] = reader.integer()
    elif opcode in {2, 20}:
        fields["path"] = reader.text()
    elif opcode == 5:
        fields.update(path=reader.text(), data=reader.buffer(), version=reader.integer())
    elif opcode == 7:
        fields.update(path=reader.text(), acls=read_acls(reader), version=reader.integer())
    elif opcode == 13 and child:
        fields.update(path=reader.text(), version=reader.integer())
    elif opcode == -10:
        fields["timeout"] = reader.integer()
    elif opcode == -11:
        require(profile.close_session_paths, "zookeeper-legacy-close-session-outside-profile")
        fields["paths"] = [reader.text() for _ in range(reader.count())]
        require(len(fields["paths"]) == len(set(fields["paths"])), "zookeeper-duplicate-close-session-path")
    elif opcode == -1:
        fields["error"] = reader.integer()
    elif opcode == 14 and not child:
        children = []
        for _ in range(reader.count(1000)):
            kind, encoded = reader.integer(), reader.buffer()
            require(encoded is not None, "zookeeper-null-multi-operation")
            nested = Reader(encoded)
            children.append(read_operation(nested, kind, profile, child=True))
            nested.finish()
        require(bool(children), "zookeeper-empty-multi-operation")
        fields["children"] = tuple(children)
    else:
        raise ZooKeeperObservationFailure("zookeeper-unsupported-transaction-opcode:"+str(opcode))
    for path in [fields["path"]] if "path" in fields else fields.get("paths", []):
        require(valid_path(path), "zookeeper-transaction-path-invalid")
    return Operation(opcode, fields)


@dataclass(frozen=True)
class Transaction:
    client_id: int
    cxid: int
    zxid: int
    time: int
    operation: Operation
    digest_version: int | None
    tree_digest: int | None
    framed_bytes: int
    payload_sha256: str
    body_bytes: int
    adler32: int

    def projection(self) -> dict[str, Any]:
        return {"header": {"clientId": self.client_id, "cxid": self.cxid, "zxid": self.zxid, "time": self.time,
                    "type": self.operation.opcode}, "operation": self.operation.projection(),
                "digest": None if self.digest_version is None else {"version": self.digest_version, "treeDigest": self.tree_digest},
                "framedBytes": self.framed_bytes, "payloadBytes": self.framed_bytes-13,
                "bodyBytes": self.body_bytes, "adler32": self.adler32}


def parse_transaction_payload(data: bytes, profile: EncodingProfile = EncodingProfile()) -> Transaction:
    require(32 <= len(data) <= MIB, "zookeeper-transaction-extent")
    reader = Reader(data)
    client, cxid, zxid, time, opcode = reader.long(), reader.integer(), reader.long(), reader.long(), reader.integer()
    require(zxid >= 0, "zookeeper-negative-zxid-outside-profile")
    operation = read_operation(reader, opcode, profile)
    body_bytes = reader.position-32
    version = digest = None
    if profile.transaction_digest:
        # The feature flag enables nullable TxnDigest support. Error and
        # other source-supported records can omit it even while enabled.
        # Partial/trailing digests remain outside the selected wire profile.
        require(reader.remaining in {0, 12}, "zookeeper-transaction-digest-extent")
        if reader.remaining:
            version, digest = reader.integer(), reader.long()
            require(version == 2, "zookeeper-unsupported-transaction-digest-version")
    reader.finish()
    return Transaction(client, cxid, zxid, time, operation, version, digest, 13+len(data),
                       hashlib.sha256(data).hexdigest(), body_bytes, zlib.adler32(data) & 0xffffffff)


def parse_transaction_record(data: bytes, profile: EncodingProfile = EncodingProfile()) -> Transaction:
    require(profile.stream_mode == "checked", "zookeeper-unsupported-record-stream")
    reader = Reader(data)
    checksum, length = reader.number("Q"), reader.integer()
    require(32 <= length <= MIB, "zookeeper-transaction-extent")
    payload = reader.take(length)
    require(checksum == zlib.adler32(payload) & 0xffffffff, "zookeeper-transaction-checksum")
    require(reader.take(1) == b"B", "zookeeper-transaction-end-marker")
    reader.finish()
    return parse_transaction_payload(payload, profile)


def parse_transaction_log(data: bytes, profile: EncodingProfile = EncodingProfile()) -> list[Transaction]:
    require(profile.stream_mode == "checked", "zookeeper-unsupported-log-stream")
    require(16 <= len(data) <= 16*MIB, "zookeeper-log-extent")
    reader = Reader(data)
    require(reader.take(4) == b"ZKLG" and reader.integer() == 2, "zookeeper-log-format")
    reader.long()
    transactions = []
    while reader.remaining:
        if reader.remaining < 12:
            require(not any(reader.take(reader.remaining)), "zookeeper-log-nonzero-truncated-tail")
            break
        checksum, length = reader.number("Q"), reader.integer()
        if length == 0:
            require(checksum == 0 and not any(reader.take(reader.remaining)), "zookeeper-log-nonzero-padding")
            break
        require(32 <= length <= MIB, "zookeeper-transaction-extent")
        payload = reader.take(length)
        require(checksum == zlib.adler32(payload) & 0xffffffff, "zookeeper-transaction-checksum")
        require(reader.take(1) == b"B", "zookeeper-transaction-end-marker")
        transaction = parse_transaction_payload(payload, profile)
        require(not transactions or transaction.zxid > transactions[-1].zxid, "zookeeper-log-zxid-not-increasing")
        transactions.append(transaction)
    return transactions


def tree_digest(nodes: dict[str, Node]) -> int:
    """Pinned DigestCalculator v2 CRC32 per node, then NodeHashMap sum."""
    total = 0
    for path, node in nodes.items():
        if path.startswith("/zookeeper/"):
            continue
        stat = node.stat
        encoded = struct.pack(">qqqqqiiiq", *(stat[key] for key in
            ("czxid", "mzxid", "pzxid", "ctime", "mtime", "version", "cversion", "aversion", "ephemeralOwner")))
        total += zlib.crc32(path.encode("ascii")+(node.data or b"")+encoded) & 0xffffffff
    unsigned = total & ((1 << 64)-1)
    return unsigned if unsigned < 1 << 63 else unsigned-(1 << 64)


def replay_from_genesis(snapshot: Snapshot, transactions: list[Transaction]) -> Snapshot:
    """Replay an explicitly established zero-zxid genesis; reject fuzzy input.

    The caller must independently establish real builtins/configuration and
    complete committed log coverage. A synthetic unit genesis supplies neither.
    """
    require(snapshot.last_processed_zxid == 0 and snapshot.digest_zxid in {None, 0}, "zookeeper-genesis-zxid-required")
    require(all(node.stat[key] == 0 for node in snapshot.nodes.values() for key in ("czxid", "mzxid", "pzxid")),
            "zookeeper-fuzzy-genesis-rejected")
    return _replay(snapshot, transactions, 0)


def replay_from_checked_anchor(snapshot: Snapshot, transactions: list[Transaction], *, snapshot_file_zxid: int) -> Snapshot:
    """Check a declared quiescent anchor's file/serialized/digest node state.

    This is deliberately stricter than loading a general fuzzy snapshot. The
    caller still establishes snapshot-time quiescence, committed suffix
    completeness and file provenance. Node digests do not cover sessions: a
    session-only commit can race snapshot copying without changing these node
    checks. They cannot supply the missing session/history witness.
    """
    require(snapshot_file_zxid > 0 and snapshot.last_processed_zxid == snapshot_file_zxid
            and snapshot.digest_zxid == snapshot_file_zxid and snapshot.digest_version == 2,
            "zookeeper-nonfuzzy-anchor-zxid-mismatch")
    require(all(node.stat[key] <= snapshot_file_zxid for node in snapshot.nodes.values()
                for key in ("czxid", "mzxid", "pzxid")), "zookeeper-anchor-has-future-node-state")
    require(tree_digest(snapshot.nodes) == snapshot.tree_digest, "zookeeper-anchor-tree-digest-mismatch")
    return _replay(snapshot, transactions, snapshot_file_zxid)


def _replay(snapshot: Snapshot, transactions: list[Transaction], anchor_zxid: int) -> Snapshot:
    result = copy.deepcopy(snapshot)
    # A freshly constructed server can serialize an empty zxid0/digest0
    # marker. Upstream treats that marker as no loaded digest. Subsequent
    # transaction digests still check the replayed state including genesis.
    if snapshot.tree_digest not in {None, 0}:
        require(tree_digest(result.nodes) == snapshot.tree_digest, "zookeeper-genesis-tree-digest-mismatch")

    next_acl_index = max(result.acl_cache, default=0)

    def acl_id(entries: tuple[Acl, ...]) -> int:
        nonlocal next_acl_index
        for identity, previous in result.acl_cache.items():
            if previous == entries:
                return identity
        next_acl_index += 1
        identity = next_acl_index
        result.acl_cache[identity] = entries
        return identity

    def release_acl(identity: int) -> None:
        if identity != -1 and not any(node.acl_id == identity for node in result.nodes.values()):
            result.acl_cache.pop(identity, None)

    def apply(operation: Operation, transaction: Transaction) -> None:
        kind, fields = operation.opcode, operation.fields
        zxid, timestamp, owner = transaction.zxid, transaction.time, transaction.client_id
        path = node_path(fields.get("path", ""))
        if kind in {1, 15, 19}:
            require(bool(path) and path not in result.nodes, "zookeeper-replay-create-conflict")
            parent_path = path.rpartition("/")[0]
            require(parent_path in result.nodes, "zookeeper-replay-parent-missing")
            parent = result.nodes[parent_path]
            require(parent.stat["ephemeralOwner"] in {0, CONTAINER_OWNER}, "zookeeper-replay-ephemeral-parent")
            ephemeral = CONTAINER_OWNER if kind == 19 else owner if fields.get("ephemeral") else 0
            require(ephemeral in {0, CONTAINER_OWNER} or ephemeral in result.sessions, "zookeeper-replay-session-missing")
            version = fields["parentCVersion"]
            require(version > parent.stat["cversion"], "zookeeper-replay-parent-create-version")
            parent.stat.update(cversion=version, pzxid=zxid)
            stat = dict(czxid=zxid, mzxid=zxid, ctime=timestamp, mtime=timestamp,
                        version=0, cversion=0, aversion=0, ephemeralOwner=ephemeral, pzxid=zxid)
            result.nodes[path] = Node(fields["data"], acl_id(fields["acls"]), stat)
        elif kind in {2, 20}:
            require(bool(path) and path in result.nodes, "zookeeper-replay-delete-missing")
            require(not any(child.rpartition("/")[0] == path for child in result.nodes if child), "zookeeper-replay-delete-has-children")
            if kind == 20:
                require(result.nodes[path].stat["ephemeralOwner"] == CONTAINER_OWNER, "zookeeper-replay-container-delete-kind")
            removed = result.nodes.pop(path)
            release_acl(removed.acl_id)
            # Persisted cversion is create-count, not the API copyStat value.
            result.nodes[path.rpartition("/")[0]].stat["pzxid"] = zxid
        elif kind == 5:
            require(path in result.nodes, "zookeeper-replay-set-data-missing")
            node = result.nodes[path]
            require(fields["version"] == node.stat["version"]+1, "zookeeper-replay-data-version")
            node.data = fields["data"]
            node.stat.update(version=fields["version"], mzxid=zxid, mtime=timestamp)
        elif kind == 7:
            require(path in result.nodes, "zookeeper-replay-set-acl-missing")
            node = result.nodes[path]
            require(fields["version"] == node.stat["aversion"]+1, "zookeeper-replay-acl-version")
            previous_acl = node.acl_id
            node.acl_id = -1
            release_acl(previous_acl)
            node.acl_id = acl_id(fields["acls"])
            node.stat["aversion"] = fields["version"]
        elif kind == 13:
            # PrepRequestProcessor has already validated the requested
            # version and stores current+1. DataTree replay deliberately
            # performs no version check or mutation for this record.
            pass
        elif kind == -10:
            require(owner not in {0, CONTAINER_OWNER} and owner not in result.sessions and fields["timeout"] > 0,
                    "zookeeper-replay-create-session")
            result.sessions[owner] = fields["timeout"]
        elif kind == -11:
            require(owner in result.sessions, "zookeeper-replay-close-session-missing")
            expected = {path for path, node in result.nodes.items() if node.stat["ephemeralOwner"] == owner}
            require(set(fields["paths"]) == expected, "zookeeper-replay-close-session-paths")
            for target in fields["paths"]:
                apply(Operation(2, {"path": target}), transaction)
            del result.sessions[owner]
        elif kind == 14:
            children = fields["children"]
            if not any(child.opcode == -1 for child in children):
                for child in children:
                    apply(child, transaction)
        elif kind != -1:
            raise ZooKeeperObservationFailure("zookeeper-replay-unsupported-operation")

    previous = anchor_zxid
    for transaction in transactions:
        require(transaction.zxid > previous, "zookeeper-replay-zxid-not-increasing")
        epoch, counter = transaction.zxid >> 32, transaction.zxid & 0xffffffff
        previous_epoch, previous_counter = previous >> 32, previous & 0xffffffff
        require(counter == (previous_counter+1 if epoch == previous_epoch else 1), "zookeeper-replay-log-gap")
        apply(transaction.operation, transaction)
        result.validate_tree()
        if transaction.tree_digest is not None:
            require(tree_digest(result.nodes) == transaction.tree_digest, "zookeeper-replay-tree-digest-mismatch")
        previous = transaction.zxid
    result.last_processed_zxid = previous
    result.digest_zxid, result.digest_version, result.tree_digest = previous, 2, tree_digest(result.nodes)
    return result
