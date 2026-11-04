#!/usr/bin/env python3
"""Independent proposed registry inputs/states, before its implementation.

This authors literal state transitions and validates only wire arithmetic. No
subject registry, wrapper output, runtime observation or implementation import.
"""
import copy
import hashlib
import importlib.util
import json
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parents[2] / 'oracle'
TARGET = HERE / 'platform_backbone_zookeeper_capture_registry.json'
CAPTURE_SHA = '93ef7637c51a978419bb723ceed739083dabe0a8dd86534fdb43498f7f438c19'
spec = importlib.util.spec_from_file_location('capture_reference', Path(__file__).with_name('zookeeper_capture_reference.py'))
ref = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ref)


def make():
    raw = (HERE / 'platform_backbone_zookeeper_capture.json').read_bytes()
    assert hashlib.sha256(raw).hexdigest() == CAPTURE_SHA
    frozen = json.loads(raw)
    source = {r['sourceRecord']: r for r in frozen['wireCases']}
    s = source['txn-1-CreateSession']
    records = {}

    def add(identity, header, txn):
        records[identity] = {'header': copy.deepcopy(header), 'transaction': copy.deepcopy(txn),
                             'expectedOriginal': ref.expected(header, txn, None)}

    add('session1', s['header'], s['transaction'])
    add('session1-conflict', s['header'], {**s['transaction'], 'timeout': 30001})
    for n in [2, 3]:
        add('session' + str(n), {**s['header'], 'cxid': n, 'zxid': n, 'time': 1000 * n}, s['transaction'])
    good = source['txn-8-Multi']
    add('successful-multi', good['header'], good['transaction'])
    failed_h = {**s['header'], 'cxid': 15, 'zxid': 15, 'time': 15000, 'type': 14}
    failed_t = {'kind': 'Multi', 'children': [
        {'kind': 'SetData', 'path': '/x', 'dataHex': '61', 'dataNull': False, 'version': 1},
        {'kind': 'Error', 'error': -103},
        {'kind': 'SetData', 'path': '/y', 'dataHex': '62', 'dataNull': False, 'version': 1}]}
    add('failed-multi-three-children', failed_h, failed_t)
    large = next(r for r in frozen['boundaryCases'] if r['id'] == 'native-policy-canonical-exact-349159-no-digest')
    records['native-maximum'] = {'header': large['header'], 'transaction': large['transaction'],
                                'expectedOriginal': large['expected']}
    assert records['session1']['expectedOriginal']['maximumModernFramedBytes'] == 61
    assert records['successful-multi']['expectedOriginal']['maximumModernFramedBytes'] == 144
    assert records['failed-multi-three-children']['expectedOriginal']['canonicalBytes'] == 94
    assert records['failed-multi-three-children']['expectedOriginal']['maximumModernFramedBytes'] == 119

    d2 = {'version': 2, 'treeDigest': 68323592}
    changed = {'version': 2, 'treeDigest': -9223372036854775808}

    def state(limit, alias_limit, retained=(), aliases=()):
        # Expected retained sets/aliases are explicitly authored per transition.
        # Arithmetic uses independently frozen canonical extents only.
        return {'uniqueFramedByteLimit': limit, 'maxAliasEntries': alias_limit,
            'uniqueFramedBytes': sum(records[name]['expectedOriginal']['maximumModernFramedBytes'] for name in retained),
            'uniqueRecordCount': len(retained), 'aliasEntryCount': len(aliases),
            'retainedOriginals': {str(records[name]['header']['zxid']):
                records[name]['expectedOriginal']['canonicalSha256'] for name in retained},
            'liveAliasPairs': list(aliases)}

    def result(record, digest):
        r = records[record]
        return ref.expected(r['header'], r['transaction'], digest,
                            literal=record != 'native-maximum')

    def pair(identity, record='session1', hdr=None, txn=None):
        return {'pair': identity, 'record': record, 'headerIdentity': hdr or 'h-' + identity,
                'transactionIdentity': txn or 't-' + identity}

    def app(pair_id, record, retained, aliases, before=(), deny=None, **extra):
        return {'operation': 'application', 'pair': pair_id, 'before': list(before),
            'expected': {'admission': 'accept', 'capture': result(record, None),
                         'state': [list(retained), list(aliases)]} if deny is None else
                        {'admission': 'deny', 'reasonCategory': deny, 'returnedCapture': False,
                         'state': [list(retained), list(aliases)]}, **extra}

    def append(pair_id, record, digest, retained, aliases, before=(), deny=None, **extra):
        step = app(pair_id, record, retained, aliases, before, deny, **extra)
        step.update(operation='append', digest=copy.deepcopy(digest))
        if deny is None:
            step['expected']['capture'] = result(record, digest)
        return step

    cases = []

    def case(identity, limit, aliases, pairs, steps):
        for step in steps:
            retained, live = step['expected']['state']
            step['expected']['state'] = state(limit, aliases, retained, live)
        cases.append({'id': identity, 'policy': {'uniqueFramedByteLimit': limit, 'maxAliasEntries': aliases},
                      'pairs': pairs, 'expectedInitial': state(limit, aliases), 'steps': steps})

    case('minimum-row-exact-and-repeat', 61, 1, [pair('A')], [
        app('A', 'session1', ['session1'], ['A']), app('A', 'session1', ['session1'], ['A'])])
    case('minimum-row-one-byte-short', 60, 1, [pair('A')], [
        app('A', 'session1', [], [], deny='unique-byte-limit')])
    case('two-unique-records-exact', 122, 2, [pair('A'), pair('B', 'session2')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session2', ['session1', 'session2'], ['A', 'B'])])
    case('second-unique-one-byte-short-no-alias-insertion', 121, 2, [pair('A'), pair('B', 'session2')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session2', ['session1'], ['A'], deny='unique-byte-limit')])
    case('new-object-same-bytes-no-unique-recharge', 61, 2, [pair('A'), pair('B')], [
        app('A', 'session1', ['session1'], ['A']), app('B', 'session1', ['session1'], ['A', 'B'])])
    for shared in ['header', 'transaction']:
        b = pair('B', hdr='h-A' if shared == 'header' else None,
                 txn='t-A' if shared == 'transaction' else None)
        case('identity-pair-distinguishes-shared-' + shared, 61, 1, [pair('A'), b], [
            app('A', 'session1', ['session1'], ['A']),
            app('B', 'session1', ['session1'], ['A'], deny='alias-entry-limit')])
    case('alias-full-new-unique-denial-does-not-charge', 122, 1, [pair('A'), pair('B', 'session2')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session2', ['session1'], ['A'], deny='alias-entry-limit'),
        app('A', 'session1', ['session1'], ['A'])])
    case('new-object-same-zxid-conflict', 122, 2, [pair('A'), pair('B', 'session1-conflict')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session1-conflict', ['session1'], ['A'], deny='canonical-conflict')])
    for edit in [{'kind': 'setHeaderField', 'field': 'zxid', 'value': 2},
                 {'kind': 'setHeaderField', 'field': 'time', 'value': 1001},
                 {'kind': 'setTransactionField', 'field': 'timeout', 'value': 30001}]:
        case('same-alias-rejects-' + edit['field'], 122, 2, [pair('A')], [
            app('A', 'session1', ['session1'], ['A']),
            app('A', 'session1', ['session1'], ['A'], before=[{'mutatePair': 'A', **edit}],
                deny='alias-mutation-denied')])
    case('invalid-first-append-digest-has-zero-state-effect', 61, 1, [pair('A')], [
        append('A', 'session1', {'version': 3, 'treeDigest': 1}, [], [], deny='digest-profile-unsupported'),
        append('A', 'session1', d2, ['session1'], ['A'])])
    case('append-application-materialize-distinct-payloads', 61, 1, [pair('A')], [
        append('A', 'session1', d2, ['session1'], ['A']),
        app('A', 'session1', ['session1'], ['A']),
        append('A', 'session1', changed, ['session1'], ['A']),
        append('A', 'session1', None, ['session1'], ['A'])])
    case('invalid-duplicate-append-digest-preserves-state', 61, 2, [pair('A'), pair('B')], [
        app('A', 'session1', ['session1'], ['A']),
        append('B', 'session1', {'version': 1, 'treeDigest': 1}, ['session1'], ['A'], deny='digest-profile-unsupported'),
        app('B', 'session1', ['session1'], ['A', 'B'])])
    case('weak-alias-cleanup-does-not-refund-strong-debt', 61, 1, [pair('A'), pair('B'), pair('C', 'session2')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session1', ['session1'], ['B'], before=[{'enqueueAliasEndpoint': 'A', 'endpoint': 'header'}]),
        app('C', 'session2', ['session1'], ['B'], deny='unique-byte-limit')])
    case('housekeeping-may-remove-dead-alias-on-denial', 61, 1, [pair('A'), pair('B', 'session1-conflict')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session1-conflict', ['session1'], [],
            before=[{'enqueueAliasEndpoint': 'A', 'endpoint': 'transaction'}], deny='canonical-conflict')])
    case('late-second-endpoint-queue-is-idempotent', 61, 1, [pair('A'), pair('B')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session1', ['session1'], ['B'], before=[{'enqueueAliasEndpoint': 'A', 'endpoint': 'header'}]),
        app('B', 'session1', ['session1'], ['B'], before=[{'enqueueAliasEndpoint': 'A', 'endpoint': 'transaction'}])])
    case('uncollected-live-alias-conservatively-denies', 61, 1, [pair('A'), pair('B')], [
        app('A', 'session1', ['session1'], ['A']),
        app('B', 'session1', ['session1'], ['A'], deny='alias-entry-limit')])

    failed = 'failed-multi-three-children'
    first_error = {'mutatePair': 'F', 'kind': 'setMultiChildType', 'index': 0, 'type': -1}
    last_error = {'mutatePair': 'F', 'kind': 'setMultiChildType', 'index': 2, 'type': -1}
    case('original-failed-Multi-views-return-original', 119, 1, [pair('F', failed)], [
        app('F', failed, [failed], ['F']),
        app('F', failed, [failed], ['F'], before=[first_error]),
        append('F', failed, d2, [failed], ['F'], before=[last_error]),
        app('F', failed, [failed], ['F'], before=[{'mutatePair': 'F', 'kind': 'restoreOriginalFields'}])])
    case('successful-Multi-type-to-Error-is-not-pinned-failed-view', 144, 1,
        [pair('G', 'successful-multi')], [
        app('G', 'successful-multi', ['successful-multi'], ['G']),
        app('G', 'successful-multi', ['successful-multi'], ['G'],
            before=[{'mutatePair': 'G', 'kind': 'setMultiChildType', 'index': 0, 'type': -1}],
            deny='alias-mutation-denied')])
    case('new-object-mutated-failed-Multi-is-conflict', 238, 2, [pair('F', failed), pair('N', failed)], [
        app('F', failed, [failed], ['F']),
        app('N', failed, [failed], ['F'],
            before=[{'mutatePair': 'N', 'kind': 'setMultiChildType', 'index': 0, 'type': -1}],
            deny='canonical-conflict')])
    edits = [
        ('header', {'kind': 'setHeaderField', 'field': 'cxid', 'value': 16}),
        ('changed-buffer', {'kind': 'xorMultiChildDataByte', 'index': 0, 'byteOffset': 0, 'xor': 1}),
        ('changed-count', {'kind': 'removeMultiChild', 'index': 2}),
        ('changed-order', {'kind': 'swapMultiChildren', 'left': 0, 'right': 2}),
        ('original-Error-to-other-type', {'kind': 'setMultiChildType', 'index': 1, 'type': 5}),
        ('other-non-Error-type', {'kind': 'setMultiChildType', 'index': 0, 'type': 2})]
    for label, edit in edits:
        case('failed-Multi-rejects-' + label, 238, 2, [pair('F', failed)], [
            app('F', failed, [failed], ['F']),
            app('F', failed, [failed], ['F'], before=[{'mutatePair': 'F', **edit}], deny='alias-mutation-denied')])
    case('checked-first-serializer-failure-has-no-debt', 61, 1, [pair('A')], [
        app('A', 'session1', [], [], deny='same-checked-IOException',
            serializerFault={'stage': 'transaction-after-write', 'requireSameExceptionInstance': True}),
        app('A', 'session1', ['session1'], ['A'])])
    case('checked-alias-serializer-failure-does-not-use-cached-permit', 61, 1, [pair('A')], [
        app('A', 'session1', ['session1'], ['A']),
        app('A', 'session1', ['session1'], ['A'], deny='same-checked-IOException',
            serializerFault={'stage': 'transaction-after-write', 'requireSameExceptionInstance': True}),
        app('A', 'session1', ['session1'], ['A'])])
    case('native-unique-exact', 349184, 1, [pair('L', 'native-maximum')], [
        app('L', 'native-maximum', ['native-maximum'], ['L'])])
    case('native-unique-one-byte-short', 349183, 1, [pair('L', 'native-maximum')], [
        app('L', 'native-maximum', [], [], deny='unique-byte-limit')])
    constructors = []
    for limit, aliases in [(0, 1), (-1, 1), (61, 0), (61, -1)]:
        constructors.append({'id': 'invalid-policy-%d-%d' % (limit, aliases),
            'uniqueFramedByteLimit': limit, 'maxAliasEntries': aliases,
            'expected': {'admission': 'deny', 'reasonCategory': 'policy-invalid'}})
    concurrency = [
        {'id': 'two-unique-requests-compete-for-last-byte-slot', 'policy': {'uniqueFramedByteLimit': 61, 'maxAliasEntries': 2},
         'pairs': [pair('A'), pair('B', 'session2')], 'concurrentApplications': ['A', 'B'],
         'expected': {'acceptedCalls': 1, 'deniedCalls': 1, 'denialReason': 'unique-byte-limit',
             'uniqueFramedBytes': 61, 'uniqueRecordCount': 1, 'aliasEntryCount': 1,
             'permittedRetainedZxidSets': [[1], [2]]}},
        {'id': 'two-equal-new-pairs-compete-for-last-alias-slot', 'policy': {'uniqueFramedByteLimit': 61, 'maxAliasEntries': 1},
         'pairs': [pair('A'), pair('B')], 'concurrentApplications': ['A', 'B'],
         'expected': {'acceptedCalls': 1, 'deniedCalls': 1, 'denialReason': 'alias-entry-limit',
             'uniqueFramedBytes': 61, 'uniqueRecordCount': 1, 'aliasEntryCount': 1,
             'permittedRetainedZxidSets': [[1]]}},
        {'id': 'same-identity-pair-concurrent-repeat-idempotent', 'policy': {'uniqueFramedByteLimit': 61, 'maxAliasEntries': 1},
         'pairs': [pair('A')], 'concurrentApplications': ['A', 'A'],
         'expected': {'acceptedCalls': 2, 'deniedCalls': 0,
             'uniqueFramedBytes': 61, 'uniqueRecordCount': 1, 'aliasEntryCount': 1,
             'permittedRetainedZxidSets': [[1]]}}]
    return {'schema': 'phase30-independent-capture-registry-v1',
        'scope': 'In-memory original identity/debt and weak alias metadata only; no durable/global permit, physical-attempt charge, interception, RPC or heap adequacy claim.',
        'sourceCaptureCorpusSha256': CAPTURE_SHA,
        'sources': frozen['sources'],
        'rules': [
            'Constructor policy is immutable and positive; a positive limit below61 is valid empty policy but cannot fund a minimum row.',
            'Unique debt is original canonicalBytes+25 per zxid, including nullable-digest cases; no refunds, eviction or reset.',
            'A new identity pair with exact original bytes may add an alias without adding unique debt; conflicting new-object same-zxid bytes reject.',
            'Aliases are weak identity pairs, never equals-based keys; collecting either endpoint frees that alias metadata only.',
            'Dead-alias queue cleanup may occur before a denied command. After that housekeeping, denial changes neither debt nor live aliases.',
            'Every call freshly serializes/checks current input. An alias hit is not a cached permission to skip checked serialization.',
            'Application returns the retained original with no digest. Append returns original.withDigest(current supplied digest), with no physical permission.',
            'Only ORIGINAL Multi containing an Error child admits the pinned failed view: exact header/count/order/all child data, original Error types unchanged, other original child types unchanged or Error.',
            'Each comparison is against the original, so exact original bytes remain valid even after a previously observed failed view; no monotonic observed-view state is invented.',
            'New-object mutated Multi does not inherit the same-pair exception. Header/data/count/order/other opcode changes reject.',
            'Digest/serializer/quota/alias validation precedes any new debt/alias commit. All state transitions are synchronized.',
            'GC test actions explicitly clear/enqueue only saved private weak references; they are test-only queue simulation, not a production remove/reset API or GC timing guarantee.',
            'A stale second endpoint queue event must not remove a later unrelated alias or decrement alias count twice.',
            'Weak aliases may conservatively deny while old objects remain live or GC has not delivered queue events.'],
        'records': records, 'constructorCases': constructors, 'cases': cases, 'concurrencyCases': concurrency}


def main():
    value = make()
    assert json.loads(TARGET.read_text()) == value
    print(json.dumps({'status': 'PASS', 'constructorCases': len(value['constructorCases']),
        'sequenceCases': len(value['cases']), 'concurrencyCases': len(value['concurrencyCases']),
        'corpusSha256': hashlib.sha256(TARGET.read_bytes()).hexdigest()}, sort_keys=True))


if __name__ == '__main__':
    main()
