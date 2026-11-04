#!/usr/bin/env python3
"""Generate literal withDigest assertions without invoking the subject.

The original independently authored capture generator supplies only Java
constructor/serializer helpers; the frozen new corpus supplies every result.
"""
import argparse
import sys
import ast
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ORACLES = ROOT / 'test/oracle'
CORPUS = json.loads((ORACLES / 'platform_backbone_zookeeper_capture_with_digest.json').read_text())
ORIGINAL = json.loads((ORACLES / 'platform_backbone_zookeeper_capture.json').read_text())
ROWS = {row['id']: row for row in ORIGINAL['wireCases'] + ORIGINAL['boundaryCases']}
sys.path.insert(0, str(ROOT / 'tools'))
import containment
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args = parser.parse_args()
OUT = containment.require_state_path(args.output,'build',actor='test')
OUT.mkdir(parents=True,exist_ok=True)
spec = importlib.util.spec_from_file_location('capture_reference', HERE / 'zookeeper_capture_reference.py')
ref = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ref)
old = ast.parse((HERE / 'zookeeper_capture_probe.py').read_text())
helper_names = {'text', 'lng', 'header', 'buf', 'acl', 'txn', 'digest'}
nodes = [node for node in old.body if isinstance(node, ast.FunctionDef) and node.name in helper_names]
helpers = {'json': json, 'ref': ref}
exec(compile(ast.Module(body=nodes, type_ignores=[]), '<independent-capture-Java-constructors>', 'exec'), helpers)
text, lng, header, txn, digest = [helpers[name] for name in ['text', 'lng', 'header', 'txn', 'digest']]
prefix = next(ast.literal_eval(node.value) for node in old.body
              if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'prefix' for t in node.targets))
prefix = prefix.replace('public final class CaptureProbe', 'public final class CaptureWithDigestProbe')
prefix = prefix.removesuffix(' public static void main(String[] args) throws Exception {\n')
lines = [prefix, r'''
 static void verify(String id,CapturedTransaction c,long zxid,int canon,int payload,int physical,int modern,String csha,String psha,String chex,String phex) throws Exception {
  check(c.zxid()==zxid,id+" zxid");check(c.canonicalBytes()==canon,id+" canonical count");
  check(c.payloadCopy().length==payload,id+" payload count");check(c.physicalFramedBytes()==physical,id+" physical count");
  check(c.maximumModernFramedBytes()==modern,id+" modern count");
  check(c.canonicalSha256().equals(csha),id+" canonical SHA");check(sha(c.canonicalCopy()).equals(csha),id+" canonical bytes SHA");
  check(sha(c.payloadCopy()).equals(psha),id+" payload SHA");
  if(chex!=null)check(Arrays.equals(c.canonicalCopy(),hex(chex)),id+" canonical literal");
  if(phex!=null)check(Arrays.equals(c.payloadCopy(),hex(phex)),id+" payload literal");
  check(c.canonicalCopy()!=c.canonicalCopy(),id+" canonical defensive copy");
  check(c.payloadCopy()!=c.payloadCopy(),id+" payload defensive copy");
  byte[] a=c.canonicalCopy(),b=c.payloadCopy();a[0]^=1;b[0]^=2;
  check(sha(c.canonicalCopy()).equals(csha),id+" canonical returned-copy isolation");
  check(sha(c.payloadCopy()).equals(psha),id+" payload returned-copy isolation");
 }
 static final class Retained {
  final List<CapturedTransaction> values=new ArrayList<>();
  final List<byte[]> canonical=new ArrayList<>(),payload=new ArrayList<>();
  final List<String> hashes=new ArrayList<>();final List<Long> zxids=new ArrayList<>();
  final List<int[]> counts=new ArrayList<>();
  void add(CapturedTransaction c) {
   values.add(c);canonical.add(c.canonicalCopy());payload.add(c.payloadCopy());hashes.add(c.canonicalSha256());zxids.add(c.zxid());
   counts.add(new int[]{c.canonicalBytes(),c.physicalFramedBytes(),c.maximumModernFramedBytes()});
  }
  void verifyAll() {
   for(int n=0;n<values.size();n++) {
    CapturedTransaction c=values.get(n);int[] sizes=counts.get(n);
    check(Arrays.equals(c.canonicalCopy(),canonical.get(n)),"retained canonical");
    check(Arrays.equals(c.payloadCopy(),payload.get(n)),"retained payload");
    check(c.canonicalSha256().equals(hashes.get(n)),"retained hash");check(c.zxid()==zxids.get(n),"retained zxid");
    check(c.canonicalBytes()==sizes[0] && c.physicalFramedBytes()==sizes[1] && c.maximumModernFramedBytes()==sizes[2],"retained counts");
   }
  }
 }
 static TxnHeader watchedHeader(TxnHeader h,int[] calls,boolean[] armed) {
  return new TxnHeader(h.getClientId(),h.getCxid(),h.getZxid(),h.getTime(),h.getType()) {
   public void serialize(OutputArchive a,String tag) throws IOException {
    calls[0]++;if(armed[0])throw new IOException("original-header-reconsulted");super.serialize(a,tag);
   }
  };
 }
 static Record watchedTxn(Record t,int[] calls,boolean[] armed) {
  return new Record() {
   public void deserialize(InputArchive a,String tag) throws IOException {throw new IOException("unused");}
   public void serialize(OutputArchive a,String tag) throws IOException {
    calls[1]++;if(armed[0])throw new IOException("original-transaction-reconsulted");t.serialize(a,tag);
   }
  };
 }
 static void rebindNo(CapturedTransaction c,TxnDigest d,String expected) throws Exception {
  try {c.withDigest(d);throw new AssertionError("withDigest unexpectedly accepted");}
  catch(IOException e) {check(e.getMessage().equals(expected),"withDigest rejection actual="+e.getMessage());}
 }
 public static void main(String[] args) throws Exception {
''']


def verify(identity, variable, e):
    args = [text(identity), variable, lng(e['zxid'])]
    args += [str(e[k]) for k in ['canonicalBytes', 'payloadBytes', 'physicalFramedBytes', 'maximumModernFramedBytes']]
    args += [text(e['canonicalSha256']), text(e['payloadSha256']), text(e.get('canonicalHex')), text(e.get('payloadHex'))]
    return 'verify(%s);' % ','.join(args)


tags = {'digest-profile-unsupported': 'history-digest-profile-unsupported',
        'byte-limit': 'history-canonical-or-digest-byte-limit'}
for row in CORPUS['wireCases'] + CORPUS['sequenceCases'] + CORPUS['retryCases']:
    source = ROWS[row['captureCase']]
    lines += ['{ TxnHeader h=%s;Record t=%s;TxnDigest initialDigest=%s;' %
              (header(source['header']), txn(source['transaction']), digest(row['initialDigest'])),
              'int[] originalCalls={0,0};boolean[] armed={false};']
    watched = 'expectedOriginalSerializerCalls' in row
    if watched:
        lines.append('h=watchedHeader(h,originalCalls,armed);t=watchedTxn(t,originalCalls,armed);')
    lines += ['CapturedTransaction original=CapturedTransaction.capture(h,t,initialDigest,%d);' % source['maximumCanonicalBytes'],
              verify(row['id'] + '-initial', 'original', row['expectedInitial']),
              'Retained retained=new Retained();retained.add(original);CapturedTransaction cursor=original;']
    if watched:
        lines.append('armed[0]=true;')
    for action in row.get('afterInitialCaptureActions', []):
        if action.startswith('set original first child'):
            lines.append('((MultiTxn)t).getTxns().get(0).setType(-1);')
        elif action.startswith('set original header'):
            lines.append('h.setZxid(999999L);h.setType(-1);')
        elif action.startswith('mutate any original digest'):
            lines.append('if(initialDigest!=null){initialDigest.setVersion(3);initialDigest.setTreeDigest(-1L);}')
        elif action.startswith('overwrite original child data'):
            lines.append('for(Txn child:((MultiTxn)t).getTxns())Arrays.fill(child.getData(),(byte)0);')
        elif action.startswith('clear original child list'):
            lines.append('((MultiTxn)t).getTxns().clear();')
        elif action.startswith('replace original Multi'):
            lines.append('((MultiTxn)t).setTxns(new ArrayList<>());')
        elif action.startswith('mutate original header'):
            lines.append('h.setZxid(999999L);h.setCxid(-100);h.setType(-1);')
        elif action.startswith('overwrite returned'):
            lines.append('Arrays.fill(original.canonicalCopy(),(byte)0);Arrays.fill(original.payloadCopy(),(byte)0);')
    reuse = row.get('reuseOneDigestObject', False)
    if reuse:
        lines.append('TxnDigest sharedDigest=new TxnDigest();')
    for index, step in enumerate(row['steps']):
        value = step['digest']
        name = 'attempt%d' % index
        if reuse and value is not None:
            lines.append('sharedDigest.setVersion(%d);sharedDigest.setTreeDigest(%s);' % (value['version'], lng(value['treeDigest'])))
            expression = 'sharedDigest'
        else:
            expression = digest(value)
        if step['expected']['admission'] == 'deny':
            lines.append('rebindNo(cursor,%s,%s);' % (expression, text(tags[step['expected']['reasonCategory']])))
        else:
            lines += ['CapturedTransaction %s=cursor.withDigest(%s);' % (name, expression),
                      verify(row['id'] + '-step' + str(index), name, step['expected']),
                      'cursor=%s;retained.add(cursor);' % name]
            if row in CORPUS['wireCases']:
                lines.append('check(Arrays.equals(cursor.payloadCopy(),CapturedTransaction.capture(h,t,%s,%d).payloadCopy()),"canonical-first equals direct capture");' % (expression, source['maximumCanonicalBytes']))
        if reuse and value is not None:
            lines.append('sharedDigest.setVersion(3);sharedDigest.setTreeDigest(-1L);')
        lines.append('retained.verifyAll();')
        if watched:
            lines.append('check(originalCalls[0]==1 && originalCalls[1]==1,"original serializers called exactly once");')
    lines.append('}')

for row in CORPUS['denialCases']:
    source = ROWS[row['captureCase']]
    lines += ['{ CapturedTransaction original=CapturedTransaction.capture(%s,%s,%s,%d);' %
              (header(source['header']), txn(source['transaction']), digest(row['initialDigest']), row['initialMaximumCanonicalBytes']),
              verify(row['id'] + '-initial', 'original', row['expectedInitial'])]
    if 'serializerFault' in row:
        f = row['serializerFault']
        d = row['digest']
        lines += ['IOException sentinel=new IOException(%s);' % text(f['sentinelMessage']),
                  'TxnDigest throwing=new TxnDigest(%d,%s) {' % (d['version'], lng(d['treeDigest'])),
                  'public void serialize(OutputArchive a,String tag) throws IOException {',
                  'super.serialize(a,tag);' if f['stage'].endswith('after-write') else '',
                  'throw sentinel;}};',
                  'try {original.withDigest(throwing);throw new AssertionError("checked rebind accepted");}catch(IOException e){check(e==sentinel,"checked rebind exception identity");}']
    else:
        lines.append('rebindNo(original,%s,%s);' % (digest(row['digest']), text(tags[row['expected']['reasonCategory']])))
    lines += [verify(row['id'] + '-after-denial', 'original', row['expectedInitial']),
              verify(row['id'] + '-valid-null-after-denial', 'original.withDigest(null)', row['expectedInitial']), '}']
lines.append('System.out.println("PASS withDigest assertions="+assertions+" cases=34+7+10+1");}}')
(OUT / 'CaptureWithDigestProbe.java').write_text('\n'.join(lines))
print(OUT / 'CaptureWithDigestProbe.java')
