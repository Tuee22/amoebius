#!/usr/bin/env python3
"""Independent Jute arithmetic for the immutable JVM capture corpus.

Imports no subject code and executes no Java serializer. Existing operands come
from independently authored, hash-pinned wire corpora; all added bytes follow
release-3.9.3 zookeeper.jute/BinaryOutputArchive primitive encodings.
"""
import copy
import hashlib
import json
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parents[2] / 'oracle'
CORPUS = HERE / 'platform_backbone_zookeeper_capture.json'
INPUT_PATHS = {'zookeeper-wire-corpus-v4.json': 'platform_backbone_zookeeper_wire.json',
               'zookeeper-optional-digest-corpus.json': 'platform_backbone_zookeeper_optional_digest.json'}
INPUTS = {
    'zookeeper-wire-corpus-v4.json': '20f299fee6edfe344581987c64d7ddd802b3f5521b99daaa4985de78bd87b341',
    'zookeeper-optional-digest-corpus.json': '6f8318f7ad19a3ad73cc2e32a599b8e802281c986514346f6cad665f36673af1',
}
OPS = {'Create': 1, 'Delete': 2, 'SetData': 5, 'SetACL': 7,
       'CheckVersion': 13, 'Multi': 14, 'CreateContainer': 19,
       'DeleteContainer': 20, 'CreateSession': -10, 'CloseSession': -11, 'Error': -1}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def i(value):
    return struct.pack('>i', value)


def q(value):
    return struct.pack('>q', value)


def blob(data):
    return i(-1) if data is None else i(len(data)) + data


def jute_string(value):
    # Upstream encodes each Java UTF-16 code unit independently, including both
    # surrogate halves. This is deliberately not Python's ordinary UTF-8.
    if value is None:
        return i(-1)
    units = value.encode('utf-16-be', 'surrogatepass')
    encoded = bytearray()
    for offset in range(0, len(units), 2):
        c = int.from_bytes(units[offset:offset + 2], 'big')
        if c < 0x80:
            encoded.append(c)
        elif c < 0x800:
            encoded.extend((0xc0 | (c >> 6), 0x80 | (c & 0x3f)))
        else:
            encoded.extend((0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f)))
    return blob(bytes(encoded))


def acls(values):
    return i(-1) if values is None else i(len(values)) + b''.join(
        i(a['perms']) + jute_string(a['scheme']) + jute_string(a['identity']) for a in values)


def data(op):
    if op.get('dataNull'):
        return None
    if 'dataRepeat' in op:
        return bytes([op['dataRepeat']['byte']]) * op['dataRepeat']['count']
    return bytes.fromhex(op['dataHex'])


def body(op):
    kind = op['kind']
    if kind == 'RawSerializer':
        return bytes.fromhex(op['bytesHex'])
    if kind in ('Create', 'CreateContainer'):
        out = jute_string(op['path']) + blob(data(op)) + acls(op['acls'])
        if kind == 'Create':
            out += bytes([int(op['ephemeral'])])
        return out + i(op['parentCVersion'])
    if kind in ('Delete', 'DeleteContainer'):
        return jute_string(op['path'])
    if kind == 'SetData':
        return jute_string(op['path']) + blob(data(op)) + i(op['version'])
    if kind == 'CheckVersion':
        return jute_string(op['path']) + i(op['version'])
    if kind == 'SetACL':
        return jute_string(op['path']) + acls(op['acls']) + i(op['version'])
    if kind == 'CreateSession':
        return i(op['timeout'])
    if kind == 'CloseSession':
        return i(len(op['paths'])) + b''.join(jute_string(p) for p in op['paths'])
    if kind == 'Error':
        return i(op['error'])
    if kind == 'Multi':
        return i(len(op['children'])) + b''.join(i(OPS[c['kind']]) + blob(body(c)) for c in op['children'])
    raise ValueError(kind)


def encoded(hdr, txn, digest):
    canonical = q(hdr['clientId']) + i(hdr['cxid']) + q(hdr['zxid']) + q(hdr['time']) + i(hdr['type']) + body(txn)
    suffix = b'' if digest is None else i(digest['version']) + q(digest['treeDigest'])
    return canonical, canonical + suffix


def expected(hdr, txn, digest, literal=True):
    canonical, payload = encoded(hdr, txn, digest)
    result = {'admission': 'accept', 'zxid': hdr['zxid'],
              'canonicalBytes': len(canonical), 'payloadBytes': len(payload),
              'canonicalSha256': sha(canonical), 'payloadSha256': sha(payload),
              'physicalFramedBytes': len(payload) + 13,
              'maximumModernFramedBytes': len(canonical) + 25}
    if literal:
        result.update(canonicalHex=canonical.hex(), payloadHex=payload.hex())
    return result


def make():
    inputs = {}
    for name, digest in INPUTS.items():
        raw = (HERE / INPUT_PATHS[name]).read_bytes()
        assert sha(raw) == digest, name
        inputs[name] = json.loads(raw)
    wire_cases = []
    for name, source in inputs.items():
        for record in source['records']:
            e = record['expected']
            h, t, d = copy.deepcopy(e['header']), copy.deepcopy(e['operation']), copy.deepcopy(e['digest'])
            c, p = encoded(h, t, d)
            wire = bytes.fromhex(record['wireHex'])
            assert len(wire) == len(p) + 13 and wire[12:-1] == p and wire[-1] == 0x42
            wire_cases.append({'id': name + ':' + record['id'], 'sourceCorpus': name,
                'sourceRecord': record['id'], 'header': h, 'transaction': t, 'digest': d,
                'maximumCanonicalBytes': len(c), 'expected': expected(h, t, d)})
    base = wire_cases[0]
    h, t = copy.deepcopy(base['header']), copy.deepcopy(base['transaction'])
    v2 = copy.deepcopy(base['digest'])
    cases = []

    def accept(identity, header=h, txn=t, digest=None, limit=None, literal=True):
        c, _ = encoded(header, txn, digest)
        cases.append({'id': identity, 'header': copy.deepcopy(header), 'transaction': copy.deepcopy(txn),
                      'digest': copy.deepcopy(digest), 'maximumCanonicalBytes': len(c) if limit is None else limit,
                      'expected': expected(header, txn, digest, literal)})

    def deny(identity, category, header=h, txn=t, digest=None, limit=36, **extra):
        cases.append({'id': identity, 'header': copy.deepcopy(header), 'transaction': copy.deepcopy(txn),
                      'digest': copy.deepcopy(digest), 'maximumCanonicalBytes': limit,
                      'expected': {'admission': 'deny', 'reasonCategory': category, 'returnedCapture': False}, **extra})

    accept('minimum-36-no-digest')
    accept('minimum-36-digest-has-independent-12-byte-suffix', digest=v2)
    accept('limit-one-above-canonical', limit=37)
    accept('largest-safe-integer-limit-small-input', limit=2147483622)
    for limit in [35, 0, -1, 2147483623, 2147483647]:
        deny('invalid-canonical-limit-' + str(limit), 'input-invalid', limit=limit)
    deny('null-header', 'input-invalid', header=None)
    deny('null-transaction-selected-modern-profile', 'input-invalid', txn=None)
    for zxid in [0, -1, -9223372036854775808]:
        changed = {**h, 'zxid': zxid}
        deny('nonpositive-zxid-' + str(zxid), 'canonical-zxid-invalid', header=changed)
    accept('largest-positive-signed-zxid', header={**h, 'zxid': 9223372036854775807}, digest=v2)
    for length in [0, 3]:
        deny('serialized-body-too-short-' + str(length), 'canonical-record-too-short',
             txn={'kind': 'RawSerializer', 'bytesHex': '00' * length})
    accept('serialized-body-minimum-exact', txn={'kind': 'RawSerializer', 'bytesHex': '00007530'})
    deny('single-write-one-byte-over-limit', 'byte-limit',
         txn={'kind': 'RawSerializer', 'bytesHex': '00' * 5}, serializerWriteMode='single-byte')
    deny('range-write-one-byte-over-limit', 'byte-limit',
         txn={'kind': 'RawSerializer', 'bytesHex': '00' * 5}, serializerWriteMode='byte-range')
    for version in [-1, 0, 1, 3]:
        deny('unsupported-digest-version-' + str(version), 'digest-profile-unsupported',
             digest={'version': version, 'treeDigest': 68323592})
    for value in [-9223372036854775808, 9223372036854775807]:
        accept('v2-digest-signed-long-' + str(value), digest={'version': 2, 'treeDigest': value})
    for raw in ['', '00000002', '0000000200000000000000']:
        deny('short-digest-' + str(len(raw)//2), 'digest-profile-unsupported',
             digest={'serializerBytesHex': raw})
    deny('digest-thirteenth-byte-over-suffix-limit', 'byte-limit',
         digest={'serializerBytesHex': '00000002' + '00' * 9})
    deny('digest-thirteenth-byte-with-loose-limit-still-profile-denied', 'digest-profile-unsupported',
         limit=64, digest={'serializerBytesHex': '00000002' + '00' * 9})
    for stage in ['header-before-write', 'header-after-write', 'transaction-after-write', 'digest-after-write']:
        deny('checked-serializer-exception-' + stage, 'same-checked-IOException',
             digest=v2 if stage.startswith('digest') else None,
             serializerFault={'stage': stage, 'sentinelMessage': 'independent-capture-checked-' + stage,
                              'requireSameExceptionInstance': True})
    large_h = {**h, 'type': 5}
    large_t = {'kind': 'SetData', 'path': '/x', 'dataRepeat': {'byte': 97, 'count': 349113},
               'dataNull': False, 'version': 1}
    # 32 header + (4+2) path + 4 buffer prefix + N payload + 4 version = 46+N.
    accept('native-policy-canonical-exact-349159-no-digest', header=large_h, txn=large_t,
           limit=349159, literal=False)
    accept('native-policy-canonical-exact-349159-v2-digest', header=large_h, txn=large_t,
           digest=v2, limit=349159, literal=False)
    for d, suffix in [(None, 'absent'), (v2, 'v2')]:
        over = copy.deepcopy(large_t)
        over['dataRepeat']['count'] += 1
        deny('native-policy-canonical-plus-one-' + suffix, 'byte-limit', header=large_h,
             txn=over, digest=d, limit=349159)
    for path, label in [('/\u03c0', 'pi'), ('/\U0001f600', 'supplementary-two-surrogates')]:
        accept('jute-UTF16-' + label, header={**h, 'type': 5},
               txn={'kind': 'SetData', 'path': path, 'dataHex': 'ff00', 'dataNull': False, 'version': 1})

    mutations = []
    for record_id, actions in [
        ('txn-5-SetData', ['set header.zxid=999999', 'set digest.version=3 and treeDigest=-1',
                          'overwrite original transaction data array in place with 00',
                          'replace transaction path and data using setters']),
        ('txn-8-Multi', ['overwrite original child buffer in place', 'set first child type=-1',
                        'clear original Multi child list', 'replace Multi child list']),
        ('txn-15-Multi', ['apply pinned DataTree failed-Multi mutation: first child type=-1',
                         'keep original child data buffer unchanged']),
    ]:
        source = next(row for row in wire_cases if row['sourceRecord'] == record_id)
        mutations.append({'id': 'capture-isolation-' + record_id, 'captureCase': source['id'],
            'afterCaptureActions': actions,
            'alsoMutateReturnedCopies': ['canonicalCopy', 'payloadCopy'],
            'expectedAfterMutation': copy.deepcopy(source['expected']),
            'requireFreshReturnedArrayEachCall': True})

    return {'schema': 'phase30-independent-zookeeper-capture-v1',
        'scope': 'Checked immutable serialization only; no permit, owning Request registry, interception, RPC, history adequacy or runtime-installation claim.',
        'sourceCorporaSha256': INPUTS,
        'sources': [
            'https://github.com/apache/zookeeper/blob/release-3.9.3/zookeeper-server/src/main/java/org/apache/zookeeper/server/persistence/Util.java',
            'https://github.com/apache/zookeeper/blob/release-3.9.3/zookeeper-server/src/main/java/org/apache/zookeeper/server/Request.java',
            'https://github.com/apache/zookeeper/blob/release-3.9.3/zookeeper-jute/src/main/java/org/apache/jute/BinaryOutputArchive.java',
            'https://github.com/apache/zookeeper/blob/release-3.9.3/zookeeper-jute/src/main/resources/zookeeper.jute',
            'https://github.com/apache/zookeeper/blob/release-3.9.3/zookeeper-server/src/main/java/org/apache/zookeeper/server/DataTree.java'],
        'rules': [
            'Canonical bytes are exactly 32-byte TxnHeader then generated transaction bytes, with no framing or digest.',
            'Nullable digest is absent or exactly int32 version2 plus int64 treeDigest; canonical identity must be identical under either digest choice.',
            'Physical framing adds 8-byte Adler value, 4-byte payload length and one B terminator; maximum modern charge is canonicalBytes+25.',
            'This selected modern profile rejects null transaction/header-only legacy close; no opaque bytes are a protocol permit.',
            'Positive signed zxid is read from serialized header bytes12..19; zero/negative reject.',
            'Every source record must be reconstructed from header+typed transaction operands, compared to literal bytes and SHA, and independently compared to Util.marshallTxnEntry.',
            'Maximum canonical policy349159 is global349184 minus25; exact limit may still take the separate12-byte digest suffix.',
            'Checked serializer exceptions propagate as the same IOException instance with no returned capture; never accept Request fallback zero32.',
            'Captured arrays must remain unchanged under subsequent input mutation and returned-array mutation. Do not recapture after DataTree mutates Multi child types.',
            'The bounded output sink limits copied output, not upstream Jute string temporary allocation or arbitrary serializer computation. Owning hooks must bound/control inputs and serialize capture before mutation.'],
        'wireCases': wire_cases, 'boundaryCases': cases, 'mutationCases': mutations,
        'crossCaseAssertions': [
            {'id': 'digest-independent-identity', 'left': 'zookeeper-wire-corpus-v4.json:txn-7-Error',
             'right': 'zookeeper-optional-digest-corpus.json:optional-error-absent',
             'equal': ['zxid', 'canonicalBytes', 'canonicalHex', 'canonicalSha256', 'maximumModernFramedBytes'],
             'leftPhysicalBytesMinusRight': 12},
            {'id': 'minimum-modern-framing', 'case': 'minimum-36-digest-has-independent-12-byte-suffix',
             'expectedCanonicalBytes': 36, 'expectedPayloadBytes': 48, 'expectedPhysicalFramedBytes': 61},
            {'id': 'native-maximum-charge', 'case': 'native-policy-canonical-exact-349159-v2-digest',
             'expectedCanonicalBytes': 349159, 'expectedPayloadBytes': 349171,
             'expectedPhysicalFramedBytes': 349184}]
        }


def main():
    value = make()
    assert json.loads(CORPUS.read_text()) == value
    print(json.dumps({'status': 'PASS', 'wireCases': len(value['wireCases']),
        'boundaryCases': len(value['boundaryCases']), 'mutationCases': len(value['mutationCases']),
        'corpusSha256': sha(CORPUS.read_bytes())}, sort_keys=True))


if __name__ == '__main__':
    main()
