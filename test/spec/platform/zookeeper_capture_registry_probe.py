#!/usr/bin/env python3
"""Independent Java transition assertions for the frozen registry contract."""
import argparse
import ast
import sys
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import containment
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
CORPUS = json.loads((ROOT / 'test/oracle/platform_backbone_zookeeper_capture_registry.json').read_text())
OUT = containment.require_state_path(args.output, 'build', actor='test')
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('capture_reference', HERE / 'zookeeper_capture_reference.py')
ref = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ref)
old = ast.parse((HERE / 'zookeeper_capture_probe.py').read_text())
names = {'text', 'lng', 'header', 'buf', 'acl', 'txn', 'digest'}
env = {'json': json, 'ref': ref}
exec(compile(ast.Module(body=[n for n in old.body if isinstance(n, ast.FunctionDef) and n.name in names], type_ignores=[]), '<independent-Java-constructors>', 'exec'), env)
text, lng, header, txn, digest = [env[n] for n in ['text', 'lng', 'header', 'txn', 'digest']]
prefix = next(ast.literal_eval(n.value) for n in old.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'prefix' for t in n.targets))
prefix = prefix.replace('public final class CaptureProbe', 'public final class CaptureRegistryProbe')
prefix = prefix.removesuffix(' public static void main(String[] args) throws Exception {\n')
rebound_ast = ast.parse((HERE / 'zookeeper_capture_with_digest_probe.py').read_text())
extra = next(ast.literal_eval(n.value.elts[1]) for n in rebound_ast.body if isinstance(n, ast.Assign) and isinstance(n.value, ast.List) and any(isinstance(t, ast.Name) and t.id == 'lines' for t in n.targets))
extra = extra.removesuffix(' public static void main(String[] args) throws Exception {\n')
prefix = prefix.replace('import org.amoebius.history.CapturedTransaction;', 'import org.amoebius.history.CapturedTransaction;\nimport org.amoebius.history.CaptureRegistry;')
lines = [prefix, extra, r'''
 static final class ToggleSession extends CreateSessionTxn {
  IOException failure;
  ToggleSession(int timeout) {super(timeout);}
  public void serialize(OutputArchive a,String tag) throws IOException {super.serialize(a,tag);if(failure!=null)throw failure;}
 }
 static final class Pair {
  final TxnHeader h;final Record t;
  Pair(TxnHeader h,Record t) {this.h=h;this.t=t;}
 }
 static Object field(Object object,String name) throws Exception {
  java.lang.reflect.Field f=object.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(object);
 }
 static void state(CaptureRegistry registry,int maximum,int aliasMaximum,int bytes,int count,int aliasCount,Map<Long,String> expectedOriginals,List<String> expectedAliases,Map<String,Pair> pairs) throws Exception {
  check(registry.uniqueFramedBytes()==bytes,"unique framed debt");check(registry.uniqueTransactions()==count,"unique record count");
  check(registry.aliasEntries()==aliasCount,"alias count");
  check((Integer)field(registry,"maximumUniqueFramedBytes")==maximum,"immutable unique policy");
  check((Integer)field(registry,"maximumAliasEntries")==aliasMaximum,"immutable alias policy");
  Map<?,?> originals=(Map<?,?>)field(registry,"originals");Map<Long,String> observed=new HashMap<>();
  for(Map.Entry<?,?> entry:originals.entrySet()) {
   CapturedTransaction value=(CapturedTransaction)entry.getValue();
   check(Arrays.equals(value.canonicalCopy(),value.payloadCopy()),"intern token digest absent");
   check(value.zxid()==(Long)entry.getKey(),"intern zxid join");
   check(value.canonicalSha256().equals(sha(value.canonicalCopy())),"intern actual bytes hash");
   observed.put((Long)entry.getKey(),value.canonicalSha256());
  }
  check(observed.equals(expectedOriginals),"exact retained original map");
  Map<?,?> aliases=(Map<?,?>)field(registry,"aliases");Set<String> actualAliases=new HashSet<>();
  for(Object key:aliases.keySet()) {
   Object h=((java.lang.ref.Reference<?>)field(key,"header")).get();
   Object t=((java.lang.ref.Reference<?>)field(key,"transaction")).get();boolean found=false;
   for(Map.Entry<String,Pair> p:pairs.entrySet())if(p.getValue().h==h&&p.getValue().t==t){actualAliases.add(p.getKey());found=true;}
   check(found,"alias is actual declared identity pair");
  }
  check(actualAliases.equals(new HashSet<>(expectedAliases)),"exact live identity-pair domain");
 }
 static final class SavedParts {
  final Map<String,Object[]> parts=new HashMap<>();
  void enqueue(CaptureRegistry registry,String name,String endpoint,Pair pair) throws Exception {
   Object[] saved=parts.get(name);
   if(saved==null) {
    Map<?,?> aliases=(Map<?,?>)field(registry,"aliases");
    for(Object key:aliases.keySet()) {
     Object h=field(key,"header"),t=field(key,"transaction");
     if(((java.lang.ref.Reference<?>)h).get()==pair.h&&((java.lang.ref.Reference<?>)t).get()==pair.t){saved=new Object[]{h,t};break;}
    }
    check(saved!=null,"saved exact registered weak references");parts.put(name,saved);
   }
   java.lang.ref.Reference<?> part=(java.lang.ref.Reference<?>)saved[endpoint.equals("header")?0:1];
   part.clear();part.enqueue();
  }
 }
 static void setHeader(TxnHeader target,TxnHeader source) {
  target.setClientId(source.getClientId());target.setCxid(source.getCxid());target.setZxid(source.getZxid());
  target.setTime(source.getTime());target.setType(source.getType());
 }
 static String category(IOException failure) {
  return switch(failure.getMessage()) {
   case "history-registry-unique-byte-limit" -> "unique-byte-limit";
   case "history-registry-alias-entry-limit" -> "alias-entry-limit";
   case "history-registry-zxid-conflict" -> "canonical-conflict";
   case "history-registry-alias-body-changed" -> "alias-mutation-denied";
   case "history-digest-profile-unsupported" -> "digest-profile-unsupported";
   default -> "unexpected:"+failure.getClass().getName()+":"+failure.getMessage();
  };
 }
 public static void main(String[] args) throws Exception {
''']


def verify(identity, var, e):
    args = [text(identity), var, lng(e['zxid'])]
    args += [str(e[k]) for k in ['canonicalBytes', 'payloadBytes', 'physicalFramedBytes', 'maximumModernFramedBytes']]
    args += [text(e['canonicalSha256']), text(e['payloadSha256']), text(e.get('canonicalHex')), text(e.get('payloadHex'))]
    return 'verify(%s);' % ','.join(args)


def typed(record):
    return txn(record['transaction']).replace('new CreateSessionTxn(', 'new ToggleSession(')


def pairs_setup(case):
    out = ['Map<String,Pair> pairs=new LinkedHashMap<>();Map<String,TxnHeader> headers=new HashMap<>();Map<String,Record> transactions=new HashMap<>();']
    for p in case['pairs']:
        record = CORPUS['records'][p['record']]
        out += ['if(!headers.containsKey(%s))headers.put(%s,%s);' %
                (text(p['headerIdentity']), text(p['headerIdentity']), header(record['header'])),
                'if(!transactions.containsKey(%s))transactions.put(%s,%s);' %
                (text(p['transactionIdentity']), text(p['transactionIdentity']), typed(record)),
                'pairs.put(%s,new Pair(headers.get(%s),transactions.get(%s)));' %
                (text(p['pair']), text(p['headerIdentity']), text(p['transactionIdentity']))]
    return out


def map_expr(value):
    return 'Map.ofEntries(%s)' % ','.join('Map.entry(%s,%s)' % (lng(int(k)), text(v)) for k,v in value.items())


def state_expr(e):
    return 'state(registry,%d,%d,%d,%d,%d,%s,List.of(%s),pairs);' % (
        e['uniqueFramedByteLimit'], e['maxAliasEntries'], e['uniqueFramedBytes'],
        e['uniqueRecordCount'], e['aliasEntryCount'], map_expr(e['retainedOriginals']),
        ','.join(text(x) for x in e['liveAliasPairs']))


for case in CORPUS['constructorCases']:
    lines += ['try {new CaptureRegistry(%d,%d);throw new AssertionError("invalid policy accepted");}catch(IllegalArgumentException e){check(e.getMessage().equals("history-registry-policy-invalid"),"invalid policy locus");}' %
              (case['uniqueFramedByteLimit'], case['maxAliasEntries'])]

for case in CORPUS['cases']:
    p = case['policy']
    lines += ['{ CaptureRegistry registry=new CaptureRegistry(%d,%d);' % (p['uniqueFramedByteLimit'], p['maxAliasEntries'])]
    lines += pairs_setup(case)
    lines += ['SavedParts saved=new SavedParts();Retained retained=new Retained();', state_expr(case['expectedInitial'])]
    definitions = {p['pair']: p for p in case['pairs']}
    for n, step in enumerate(case['steps']):
        for action in step['before']:
            if 'enqueueAliasEndpoint' in action:
                name = action['enqueueAliasEndpoint']
                lines.append('saved.enqueue(registry,%s,%s,pairs.get(%s));' % (text(name), text(action['endpoint']), text(name)))
                continue
            name = action['mutatePair']
            target = 'pairs.get(%s)' % text(name)
            kind = action['kind']
            if kind == 'setHeaderField':
                setter = {'zxid': 'setZxid', 'time': 'setTime', 'cxid': 'setCxid'}[action['field']]
                value = lng(action['value']) if action['field'] != 'cxid' else str(action['value'])
                lines.append('%s.h.%s(%s);' % (target, setter, value))
            elif kind == 'setTransactionField':
                lines.append('((CreateSessionTxn)%s.t).setTimeOut(%d);' % (target, action['value']))
            elif kind == 'setMultiChildType':
                lines.append('((MultiTxn)%s.t).getTxns().get(%d).setType(%d);' % (target, action['index'], action['type']))
            elif kind == 'xorMultiChildDataByte':
                lines.append('((MultiTxn)%s.t).getTxns().get(%d).getData()[%d]^=%d;' % (target, action['index'], action['byteOffset'], action['xor']))
            elif kind == 'removeMultiChild':
                lines.append('((MultiTxn)%s.t).getTxns().remove(%d);' % (target, action['index']))
            elif kind == 'swapMultiChildren':
                lines.append('Collections.swap(((MultiTxn)%s.t).getTxns(),%d,%d);' % (target, action['left'], action['right']))
            elif kind == 'restoreOriginalFields':
                original = CORPUS['records'][definitions[name]['record']]
                lines.append('setHeader(%s.h,%s);((MultiTxn)%s.t).setTxns(((MultiTxn)%s).getTxns());' % (target, header(original['header']), target, typed(original)))
            else:
                raise ValueError(kind)
        lines.append('{ Pair pair=pairs.get(%s);' % text(step['pair']))
        if 'serializerFault' in step:
            # Deliberately identical to the bounded sink's message: only the
            # checked exception's type/origin may distinguish it, never text.
            lines.append('IOException sentinel=new IOException("history-canonical-or-digest-byte-limit");((ToggleSession)pair.t).failure=sentinel;')
        invocation = ('registry.forApplication(pair.h,pair.t)' if step['operation'] == 'application' else
                      'registry.forAppend(pair.h,pair.t,%s)' % digest(step['digest']))
        e = step['expected']
        if e['admission'] == 'accept':
            lines += ['CapturedTransaction value=%s;' % invocation,
                      verify(case['id'] + '-' + str(n), 'value', e['capture']), 'retained.add(value);']
        elif e['reasonCategory'] == 'same-checked-IOException':
            lines += ['try {%s;throw new AssertionError("checked serializer accepted");}catch(IOException e){check(e==sentinel,"same arbitrary checked exception instance");}' % invocation,
                      '((ToggleSession)pair.t).failure=null;']
        else:
            lines.append('try {%s;throw new AssertionError(%s);}catch(IOException e){check(category(e).equals(%s),%s+" actual="+category(e));}' %
                         (invocation, text(case['id'] + '-accepted'), text(e['reasonCategory']), text(case['id'])))
        lines += [state_expr(e['state']), 'retained.verifyAll();', '}']
    lines.append('}')

for case in CORPUS['concurrencyCases']:
    p, e = case['policy'], case['expected']
    lines.append('{ CaptureRegistry registry=new CaptureRegistry(%d,%d);' % (p['uniqueFramedByteLimit'], p['maxAliasEntries']))
    lines += pairs_setup(case)
    lines += ['List<CapturedTransaction> accepted=Collections.synchronizedList(new ArrayList<>());',
              'List<Throwable> denied=Collections.synchronizedList(new ArrayList<>());',
              'java.util.concurrent.CountDownLatch start=new java.util.concurrent.CountDownLatch(1);List<Thread> threads=new ArrayList<>();']
    for name in case['concurrentApplications']:
        lines += ['{ Pair pair=pairs.get(%s);Thread thread=new Thread(()->{try{start.await();accepted.add(registry.forApplication(pair.h,pair.t));}catch(Throwable ex){denied.add(ex);}});thread.setDaemon(true);threads.add(thread);thread.start();}' % text(name)]
    lines += ['start.countDown();for(Thread thread:threads){thread.join(10000);check(!thread.isAlive(),"synchronized transition completed");}',
              'check(accepted.size()==%d&&denied.size()==%d,"exact concurrent success/denial count");' % (e['acceptedCalls'], e['deniedCalls']),
              'check(registry.uniqueFramedBytes()==%d&&registry.uniqueTransactions()==%d&&registry.aliasEntries()==%d,"exact concurrent debt/domain sizes");' %
              (e['uniqueFramedBytes'], e['uniqueRecordCount'], e['aliasEntryCount'])]
    if e['deniedCalls']:
        lines.append('for(Throwable ex:denied)check(ex instanceof IOException&&category((IOException)ex).equals(%s),"exact concurrent denial reason");' % text(e['denialReason']))
    allowed = 'Set.of(%s)' % ','.join('Set.of(%s)' % ','.join(lng(z) for z in values) for values in e['permittedRetainedZxidSets'])
    lines.append('check(%s.contains(((Map<?,?>)field(registry,"originals")).keySet()),"permitted concurrent retained zxid set");}' % allowed)

lines.append('System.out.println("PASS registry assertions="+assertions+" cases=4+32+3");}}')
(OUT / 'CaptureRegistryProbe.java').write_text('\n'.join(lines))
print(OUT / 'CaptureRegistryProbe.java')
