#!/usr/bin/env python3
"""Generate Java assertions from the independently frozen capture corpus."""
import argparse
import sys
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('capture_reference', HERE / 'zookeeper_capture_reference.py')
ref = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ref)
ROOT = HERE.parents[2]
corpus = json.loads((ROOT / 'test/oracle/platform_backbone_zookeeper_capture.json').read_text())
sys.path.insert(0, str(ROOT / 'tools'))
import containment
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
OUT = containment.require_state_path(args.output, 'build', actor='test')
OUT.mkdir(parents=True, exist_ok=True)


def text(s):
    return json.dumps(s, ensure_ascii=True)


def lng(n):
    return str(n) + 'L'


def header(h):
    if h is None:
        return 'null'
    return 'new TxnHeader(%s,%s,%s,%s,%s)' % (lng(h['clientId']), h['cxid'], lng(h['zxid']), lng(h['time']), h['type'])


def buf(op):
    if op.get('dataNull'):
        return 'null'
    if 'dataRepeat' in op:
        r = op['dataRepeat']
        return 'repeat(%d,%d)' % (r['byte'], r['count'])
    return 'hex(%s)' % text(op['dataHex'])


def acl(values):
    return 'new ArrayList<>(List.of(%s))' % ','.join(
        'new ACL(%d,new Id(%s,%s))' % (a['perms'], text(a['scheme']), text(a['identity'])) for a in values)


def txn(op, mode='single-byte'):
    if op is None:
        return 'null'
    k = op['kind']
    if k == 'RawSerializer':
        return 'raw(%s,%s)' % (text(op['bytesHex']), str(mode == 'byte-range').lower())
    if k == 'Create':
        return 'new CreateTxn(%s,%s,%s,%s,%d)' % (text(op['path']), buf(op), acl(op['acls']), str(op['ephemeral']).lower(), op['parentCVersion'])
    if k == 'CreateContainer':
        return 'new CreateContainerTxn(%s,%s,%s,%d)' % (text(op['path']), buf(op), acl(op['acls']), op['parentCVersion'])
    if k in ('Delete', 'DeleteContainer'):
        return 'new DeleteTxn(%s)' % text(op['path'])
    if k == 'SetData':
        return 'new SetDataTxn(%s,%s,%d)' % (text(op['path']), buf(op), op['version'])
    if k == 'CheckVersion':
        return 'new CheckVersionTxn(%s,%d)' % (text(op['path']), op['version'])
    if k == 'SetACL':
        return 'new SetACLTxn(%s,%s,%d)' % (text(op['path']), acl(op['acls']), op['version'])
    if k == 'CreateSession':
        return 'new CreateSessionTxn(%d)' % op['timeout']
    if k == 'CloseSession':
        return 'new CloseSessionTxn(new ArrayList<>(List.of(%s)))' % ','.join(text(p) for p in op['paths'])
    if k == 'Error':
        return 'new ErrorTxn(%d)' % op['error']
    if k == 'Multi':
        return 'new MultiTxn(new ArrayList<>(List.of(%s)))' % ','.join(
            'child(%d,%s,%s)' % (ref.OPS[c['kind']], txn(c), text(ref.body(c).hex())) for c in op['children'])
    raise ValueError(k)


def digest(d):
    if d is None:
        return 'null'
    if 'serializerBytesHex' in d:
        return 'rawDigest(%s)' % text(d['serializerBytesHex'])
    return 'new TxnDigest(%d,%s)' % (d['version'], lng(d['treeDigest']))


prefix = r'''import java.io.*;
import java.util.*;
import java.security.*;
import org.apache.jute.Record;
import org.apache.jute.*;
import org.apache.zookeeper.txn.*;
import org.apache.zookeeper.data.*;
import org.apache.zookeeper.server.persistence.Util;
import org.amoebius.history.CapturedTransaction;
public final class CaptureProbe {
 static int assertions=0;
 static byte[] hex(String s) { return HexFormat.of().parseHex(s); }
 static String sha(byte[] b) throws Exception { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(b)); }
 static void check(boolean value,String name) { assertions++; if(!value)throw new AssertionError(name); }
 static byte[] repeat(int value,int count) { byte[] b=new byte[count]; Arrays.fill(b,(byte)value);return b; }
 static Txn child(int type,Record r,String expected) throws Exception {
  ByteArrayOutputStream out=new ByteArrayOutputStream();r.serialize(BinaryOutputArchive.getArchive(out),"txn");
  check(Arrays.equals(out.toByteArray(),hex(expected)),"typed child Jute bytes");return new Txn(type,out.toByteArray());
 }
 static Record raw(String s,boolean range) {
  return new Record() {
   public void deserialize(InputArchive a,String t) throws IOException {throw new IOException("unused");}
   public void serialize(OutputArchive a,String t) throws IOException {
    byte[] b=hex(s);
    if(range && b.length==5) {a.writeByte(b[0],"first");a.writeInt(java.nio.ByteBuffer.wrap(b,1,4).getInt(),"range");}
    else for(byte v:b)a.writeByte(v,"raw");
   }
  };
 }
 static TxnDigest rawDigest(String s) {return new TxnDigest() {
  public void serialize(OutputArchive a,String t) throws IOException {for(byte v:hex(s))a.writeByte(v,"raw");}
 };}
 static void ok(String id,TxnHeader h,Record t,TxnDigest d,int limit,long zxid,int canon,int payload,int physical,int modern,String csha,String psha,String chex,String phex) throws Exception {
  CapturedTransaction c=CapturedTransaction.capture(h,t,d,limit);
  check(c.zxid()==zxid,id+" zxid");check(c.canonicalBytes()==canon,id+" canonical count");
  check(c.payloadCopy().length==payload,id+" payload count");check(c.physicalFramedBytes()==physical,id+" physical count");
  check(c.maximumModernFramedBytes()==modern,id+" modern count");
  check(c.canonicalSha256().equals(csha),id+" canonical SHA");check(sha(c.payloadCopy()).equals(psha),id+" payload SHA");
  if(chex!=null)check(Arrays.equals(c.canonicalCopy(),hex(chex)),id+" canonical literal");
  if(phex!=null)check(Arrays.equals(c.payloadCopy(),hex(phex)),id+" payload literal");
  check(Arrays.equals(c.payloadCopy(),Util.marshallTxnEntry(h,t,d)),id+" upstream Util");
  check(c.canonicalCopy()!=c.canonicalCopy(),id+" new canonical copy");check(c.payloadCopy()!=c.payloadCopy(),id+" new payload copy");
  byte[] a=c.canonicalCopy(),b=c.payloadCopy();a[0]^=1;b[0]^=2;
  check(c.canonicalSha256().equals(sha(c.canonicalCopy())),id+" canonical copy isolation");
  check(sha(c.payloadCopy()).equals(psha),id+" payload copy isolation");
 }
 static void no(String id,TxnHeader h,Record t,TxnDigest d,int limit,String message) throws Exception {
  try {CapturedTransaction.capture(h,t,d,limit);throw new AssertionError(id+" accepted");}
  catch(IOException e) {check(e.getMessage().equals(message),id+" actual="+e.getMessage());}
 }
 static void fault(String stage,TxnHeader original,Record txn,TxnDigest dig,int limit) throws Exception {
  IOException sentinel=new IOException("independent-capture-checked-"+stage);
  TxnHeader h=original;Record t=txn;TxnDigest d=dig;
  if(stage.startsWith("header"))h=new TxnHeader(original.getClientId(),original.getCxid(),original.getZxid(),original.getTime(),original.getType()) {
   public void serialize(OutputArchive a,String tag) throws IOException {if(stage.endsWith("after-write"))super.serialize(a,tag);throw sentinel;}
  };
  if(stage.startsWith("transaction"))t=new Record() {
   public void deserialize(InputArchive a,String tag) throws IOException {throw new IOException("unused");}
   public void serialize(OutputArchive a,String tag) throws IOException {txn.serialize(a,tag);throw sentinel;}
  };
  if(stage.startsWith("digest"))d=new TxnDigest(dig.getVersion(),dig.getTreeDigest()) {
   public void serialize(OutputArchive a,String tag) throws IOException {super.serialize(a,tag);throw sentinel;}
  };
  try {CapturedTransaction.capture(h,t,d,limit);throw new AssertionError("fault accepted");}
  catch(IOException e) {check(e==sentinel,"checked exception identity "+stage);}
 }
 public static void main(String[] args) throws Exception {
'''
lines = [prefix]
tags = {'input-invalid': 'history-capture-input-invalid', 'canonical-zxid-invalid': 'history-canonical-zxid-invalid',
        'canonical-record-too-short': 'history-canonical-record-too-short', 'byte-limit': 'history-canonical-or-digest-byte-limit',
        'digest-profile-unsupported': 'history-digest-profile-unsupported'}
for c in corpus['wireCases'] + corpus['boundaryCases']:
    e = c['expected']
    operands = [text(c['id']), header(c['header']), txn(c['transaction'], c.get('serializerWriteMode')), digest(c['digest']), str(c['maximumCanonicalBytes'])]
    if 'serializerFault' in c:
        lines.append('fault(%s,%s,%s,%s,%d);' % (text(c['serializerFault']['stage']), header(c['header']), txn(c['transaction']), digest(c['digest']), c['maximumCanonicalBytes']))
    elif e['admission'] == 'accept':
        operands += [lng(e['zxid']), str(e['canonicalBytes']), str(e['payloadBytes']), str(e['physicalFramedBytes']), str(e['maximumModernFramedBytes']), text(e['canonicalSha256']), text(e['payloadSha256']), text(e.get('canonicalHex')), text(e.get('payloadHex'))]
        lines.append('ok(%s);' % ','.join(operands))
    else:
        lines.append('no(%s,%s);' % (','.join(operands), text(tags[e['reasonCategory']])))

for mutation in corpus['mutationCases']:
    row = next(r for r in corpus['wireCases'] if r['id'] == mutation['captureCase'])
    e = row['expected']
    lines += ['{ TxnHeader h=%s;Record t=%s;TxnDigest d=%s;' % (header(row['header']), txn(row['transaction']), digest(row['digest'])),
              'CapturedTransaction c=CapturedTransaction.capture(h,t,d,%d);' % row['maximumCanonicalBytes'],
              'h.setZxid(999999L);d.setVersion(3);d.setTreeDigest(-1L);']
    if row['transaction']['kind'] == 'SetData':
        lines.append('SetDataTxn s=(SetDataTxn)t;Arrays.fill(s.getData(),(byte)0);s.setPath("/changed");s.setData(new byte[]{1});')
    elif row['sourceRecord'] == 'txn-8-Multi':
        lines.append('MultiTxn m=(MultiTxn)t;Arrays.fill(m.getTxns().get(0).getData(),(byte)0);m.getTxns().get(0).setType(-1);m.getTxns().clear();m.setTxns(new ArrayList<>());')
    else:
        lines.append('((MultiTxn)t).getTxns().get(0).setType(-1);')
    lines += ['Arrays.fill(c.canonicalCopy(),(byte)0);Arrays.fill(c.payloadCopy(),(byte)0);',
              'check(Arrays.equals(c.canonicalCopy(),hex(%s)),"input mutation canonical");' % text(e['canonicalHex']),
              'check(Arrays.equals(c.payloadCopy(),hex(%s)),"input mutation payload");' % text(e['payloadHex']),
              'check(c.canonicalSha256().equals(%s),"input mutation hash");}' % text(e['canonicalSha256'])]
lines.append('System.out.println("PASS assertions="+assertions+" cases=34+41+3");}}')
(OUT / 'CaptureProbe.java').write_text('\n'.join(lines))
print(OUT / 'CaptureProbe.java')
