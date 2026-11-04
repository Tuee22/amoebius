#!/usr/bin/env python3
"""Independent matcher amendment arithmetic and optional Java probe source."""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CORPUS = ROOT / 'test/oracle/platform_backbone_zookeeper_capture_registry_matcher.json'
sys.path.insert(0, str(ROOT / 'tools'))
import containment
SHA = '7d2d861c41554221ed0787539ca04bb8216eaf0197994cc4548fd8d6c59c5db0'


def main():
    args = argparse.ArgumentParser()
    args.add_argument('--probe-output', type=Path)
    selected = args.parse_args()
    raw = CORPUS.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == SHA
    value = json.loads(raw)
    lines = [r'''import java.util.*;
import java.security.*;
import org.apache.zookeeper.txn.*;
import org.amoebius.history.*;
public final class MatcherProbe {
 static int assertions=0;
 static byte[] hex(String s){return s==null?null:HexFormat.of().parseHex(s);}
 static void check(boolean b,String name){assertions++;if(!b)throw new AssertionError(name);}
 static String sha(byte[] b)throws Exception{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(b));}
 public static void main(String[] args)throws Exception {
''']
    for row in value['cases']:
        h = row['header']
        head = struct.pack('>qiqqi', h['clientId'], h['cxid'], h['zxid'], h['time'], h['type'])
        encoded = bytearray(head + struct.pack('>i', len(row['children'])))
        changed = bytearray(encoded)
        for n, child in enumerate(row['children']):
            body = None if child['serializedBodyHex'] is None else bytes.fromhex(child['serializedBodyHex'])
            suffix = struct.pack('>i', -1) if body is None else struct.pack('>i', len(body)) + body
            encoded.extend(struct.pack('>i', child['type']) + suffix)
            changed.extend(struct.pack('>i', -1 if n == 0 else child['type']) + suffix)
        expected = row['expectedOriginal']
        assert expected['canonicalHex'] == encoded.hex()
        assert expected['canonicalBytes'] == len(encoded)
        assert expected['canonicalSha256'] == hashlib.sha256(encoded).hexdigest()
        assert expected['uniqueFramedBytes'] == len(encoded) + 25
        assert row['mutation']['expectedCurrentCanonicalHex'] == changed.hex()
        q = lambda x: json.dumps(x)
        header = 'new TxnHeader(%dL,%d,%dL,%dL,%d)' % (h['clientId'], h['cxid'], h['zxid'], h['time'], h['type'])
        children = ','.join('new Txn(%d,hex(%s))' % (c['type'], q(c['serializedBodyHex'])) for c in row['children'])
        lines += ['{ CaptureRegistry registry=new CaptureRegistry(512,1);TxnHeader h=%s;MultiTxn t=new MultiTxn(new ArrayList<>(List.of(%s)));' % (header, children),
            'CapturedTransaction original=registry.forApplication(h,t);',
            'check(Arrays.equals(original.canonicalCopy(),hex(%s)),"exact original literal");' % q(expected['canonicalHex']),
            'check(sha(original.canonicalCopy()).equals(%s),"exact original hash");' % q(expected['canonicalSha256']),
            'check(registry.uniqueFramedBytes()==%d&&registry.uniqueTransactions()==1&&registry.aliasEntries()==1,"initial state");' % expected['uniqueFramedBytes'],
            't.getTxns().get(0).setType(-1);',
            'try {registry.forApplication(h,t);throw new AssertionError("unsupported pinned view admitted");}catch(java.io.IOException e){check(e.getMessage().equals("history-registry-alias-body-changed"),"exact source-family denial");}',
            'check(registry.uniqueFramedBytes()==%d&&registry.uniqueTransactions()==1&&registry.aliasEntries()==1,"denial state unchanged");' % expected['uniqueFramedBytes'],
            'check(Arrays.equals(original.canonicalCopy(),hex(%s)),"retained original unchanged");}' % q(expected['canonicalHex'])]
    lines.append('System.out.println("PASS matcher assertions="+assertions+" cases=3");}}')
    if selected.probe_output:
        selected.probe_output = containment.require_state_path(selected.probe_output, 'build', actor='test')
        selected.probe_output.mkdir(parents=True, exist_ok=True)
        (selected.probe_output / 'MatcherProbe.java').write_text('\n'.join(lines))
    print(json.dumps({'status': 'PASS', 'cases': len(value['cases']), 'corpusSha256': SHA}))


if __name__ == '__main__':
    main()
