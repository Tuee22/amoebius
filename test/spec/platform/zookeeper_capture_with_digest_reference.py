#!/usr/bin/env python3
"""Independent per-attempt digest rebinding expectations; no JVM subject use."""
import copy
import hashlib
import json
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parents[2] / 'oracle'
SOURCE = HERE / 'platform_backbone_zookeeper_capture.json'
TARGET = HERE / 'platform_backbone_zookeeper_capture_with_digest.json'
SOURCE_SHA = '93ef7637c51a978419bb723ceed739083dabe0a8dd86534fdb43498f7f438c19'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def rebind(original, digest):
    result = copy.deepcopy(original)
    canonical = bytes.fromhex(original['canonicalHex'])
    suffix = b'' if digest is None else struct.pack('>iq', digest['version'], digest['treeDigest'])
    payload = canonical + suffix
    result.update(payloadHex=payload.hex(), payloadBytes=len(payload), payloadSha256=sha(payload),
                  physicalFramedBytes=len(payload) + 13)
    return result


def make():
    raw = SOURCE.read_bytes()
    assert sha(raw) == SOURCE_SHA
    source = json.loads(raw)
    rows = {r['id']: r for r in source['wireCases'] + source['boundaryCases']}
    wire = []
    for r in source['wireCases']:
        wire.append({'id': 'canonical-first-' + r['id'], 'captureCase': r['id'],
            'initialDigest': None, 'expectedInitial': rebind(r['expected'], None),
            'steps': [{'digest': copy.deepcopy(r['digest']), 'expected': copy.deepcopy(r['expected'])}],
            'expectedEquivalentDirectCapture': r['id']})

    multi = rows['zookeeper-wire-corpus-v4.json:txn-15-Multi']
    session = rows['zookeeper-wire-corpus-v4.json:txn-1-CreateSession']
    mutable = rows['zookeeper-wire-corpus-v4.json:txn-8-Multi']
    base_digest = copy.deepcopy(session['digest'])
    changed_digest = {'version': 2, 'treeDigest': -9223372036854775808}
    other_digest = {'version': 2, 'treeDigest': 9223372036854775807}
    sequences = []

    def sequence(identity, row, initial, digests, actions=(), **extra):
        sequences.append({'id': identity, 'captureCase': row['id'], 'initialDigest': copy.deepcopy(initial),
            'expectedInitial': rebind(row['expected'], initial), 'afterInitialCaptureActions': list(actions),
            'steps': [{'digest': copy.deepcopy(d), 'expected': rebind(row['expected'], d)} for d in digests],
            'requireAllPriorCapturesUnchanged': True, 'requireFreshReturnedArrays': True, **extra})

    sequence('add-change-remove-restore-digest', session, None,
             [base_digest, changed_digest, None, base_digest])
    sequence('remove-present-digest', session, base_digest, [None, None])
    sequence('retain-original-failed-Multi-body-after-DataTree-mutation', multi, None,
             [multi['digest'], changed_digest, None],
             ['set original first child Txn.type=-1 without replacing its original serialized data',
              'set original header.zxid=999999 and header.type=-1',
              'mutate any original digest object version to3 and treeDigest to-1'])
    sequence('retain-original-Multi-after-arbitrary-input-mutation', mutable, mutable['digest'],
             [None, other_digest, mutable['digest']],
             ['overwrite original child data arrays', 'clear original child list',
              'replace original Multi child list', 'mutate original header fields',
              'overwrite returned canonicalCopy and payloadCopy arrays'])
    sequence('no-original-serializer-reconsult', session, None, [base_digest, None, other_digest],
             ['arm original header and transaction serializers to throw after first successful serialization'],
             expectedOriginalSerializerCalls={'header': 1, 'transaction': 1})
    sequence('supplied-digest-is-snapshotted-per-attempt', session, None,
             [base_digest, changed_digest, None],
             ['reuse the same mutable TxnDigest object for nonnull steps, update its fields before each call',
              'overwrite that TxnDigest after each successful call'],
             reuseOneDigestObject=True)

    # The large row omits literal bytes by design. Its canonical hash/length are
    # already frozen; compute only the exact appended suffix and payload SHA.
    large = rows['native-policy-canonical-exact-349159-no-digest']
    h = large['header']
    c = (struct.pack('>qiqqi', h['clientId'], h['cxid'], h['zxid'], h['time'], h['type'])
         + struct.pack('>i', 2) + b'/x' + struct.pack('>i', 349113)
         + b'a' * 349113 + struct.pack('>i', 1))
    assert len(c) == 349159 and sha(c) == large['expected']['canonicalSha256']
    large_steps = []
    for d in [base_digest, None, changed_digest]:
        suffix = b'' if d is None else struct.pack('>iq', d['version'], d['treeDigest'])
        e = copy.deepcopy(large['expected'])
        e.update(payloadBytes=len(c) + len(suffix), payloadSha256=sha(c + suffix),
                 physicalFramedBytes=len(c) + len(suffix) + 13)
        large_steps.append({'digest': copy.deepcopy(d), 'expected': e})
    sequences.append({'id': 'native-limit-rebinding-suffix-exact', 'captureCase': large['id'],
        'initialDigest': None, 'expectedInitial': copy.deepcopy(large['expected']), 'steps': large_steps,
        'requireAllPriorCapturesUnchanged': True, 'requireFreshReturnedArrays': True})

    denials = []

    def deny(identity, digest, reason, **extra):
        denials.append({'id': identity, 'captureCase': session['id'], 'initialDigest': None,
            'initialMaximumCanonicalBytes': 64,
            'expectedInitial': rebind(session['expected'], None), 'digest': digest,
            'expected': {'admission': 'deny', 'reasonCategory': reason, 'returnedCapture': False},
            'requireOriginalCaptureUnchanged': True, **extra})

    for version in [-1, 0, 1, 3]:
        deny('unsupported-rebound-version-' + str(version), {'version': version, 'treeDigest': 68323592},
             'digest-profile-unsupported')
    for length in [0, 4, 11]:
        raw = '' if length == 0 else '00000002' + '00' * (length - 4)
        deny('short-rebound-suffix-' + str(length), {'serializerBytesHex': raw}, 'digest-profile-unsupported')
    # The loose initial64-byte limit must NOT enlarge the rebound payload cap.
    deny('thirteenth-rebound-byte-loose-original-limit', {'serializerBytesHex': '00000002' + '00' * 9},
         'byte-limit')
    for stage in ['digest-before-write', 'digest-after-write']:
        deny('checked-rebound-exception-' + stage, base_digest, 'same-checked-IOException',
             serializerFault={'stage': stage, 'sentinelMessage': 'independent-rebind-checked-' + stage,
                              'requireSameExceptionInstance': True})

    retry = {'id': 'denied-rebind-does-not-poison-pure-capture', 'captureCase': session['id'],
        'initialDigest': None, 'expectedInitial': rebind(session['expected'], None),
        'steps': [
            {'digest': {'version': 3, 'treeDigest': 1},
             'expected': {'admission': 'deny', 'reasonCategory': 'digest-profile-unsupported', 'returnedCapture': False}},
            {'digest': changed_digest, 'expected': rebind(session['expected'], changed_digest)},
            {'digest': None, 'expected': rebind(session['expected'], None)}],
        'requireAllPriorCapturesUnchanged': True}
    return {'schema': 'phase30-independent-zookeeper-capture-with-digest-v1',
        'sourceCaptureCorpusSha256': SOURCE_SHA,
        'scope': 'Per-attempt payload materialization only; no Request registry, append permission, debt, RPC, interception or runtime claim.',
        'sources': copy.deepcopy(source['sources']),
        'rules': [
            'withDigest serializes only its supplied digest, never original header/transaction or an earlier payload suffix.',
            'The canonical bytes, zxid, SHA256 and maximumModernFramedBytes remain exactly original across all attempts.',
            'A null argument removes any earlier suffix. A present argument must serialize exactly12bytes with version2.',
            'The rebound output cap is canonicalLength+12, even when the original capture allowed a looser maximum.',
            'A returned per-attempt payload must be passed to the actual append; reserializing original mutable Multi would invalidate the canonical identity join.',
            'Every returned instance and all earlier instances remain immutable under input/returned-array mutations.',
            'Rejected rebinding and checked digest exceptions change neither original capture nor prior results; checked failure preserves exception identity.',
            'All34canonical-first rows must also match direct capture(header,transaction,targetDigest) from the unchanged frozen original inputs.',
            'A same-object return for no-change is not forbidden; public arrays must remain distinct defensive copies.'],
        'wireCases': wire, 'sequenceCases': sequences, 'denialCases': denials,
        'retryCases': [retry]}


def main():
    value = make()
    assert json.loads(TARGET.read_text()) == value
    print(json.dumps({'status': 'PASS', 'wireCases': len(value['wireCases']),
        'sequenceCases': len(value['sequenceCases']), 'denialCases': len(value['denialCases']),
        'retryCases': len(value['retryCases']), 'corpusSha256': sha(TARGET.read_bytes())}, sort_keys=True))


if __name__ == '__main__':
    main()
