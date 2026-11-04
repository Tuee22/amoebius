#!/usr/bin/env python3
"""Independent Linux strace ordering predicate for the frozen store-only tests.

This checks real syscall ordering. It does not detect an in-language returned
value, claim power-loss testing, or replace reviewed grant/source ordering.
Fixture setup writes are distinct from exclusive candidate commit cycles.
"""
from pathlib import Path
import argparse,json,re
P=Path(__file__).parent

def check(path):
 lines=path.read_text().splitlines()
 if any('<unfinished' in x or 'resumed>' in x for x in lines):raise ValueError('unsupported-interleaved-syscall-format')
 fd={};shared={};cycles={};renamed=[];abandoned=[];created={};parent_sync={};locks={};owner_sync={};initial_candidates=set();lock_failures=0
 cwd=Path.cwd()
 def absolute(raw,pid):
  m=re.fullmatch(r'/proc/self/fd/(\d+)(?:/(.*))?',raw)
  if m:
   b=fd.get((pid,int(m[1])),shared.get(int(m[1])))
   if b is None:raise ValueError('unresolved-directory-fd:'+raw)
   return str(Path(b)/(m[2] or ''))
  return str(Path(raw) if raw.startswith('/') else cwd/raw)
 def fail(i,why):raise ValueError(f'line{i}:{why}')
 for i,line in enumerate(lines,1):
  m=re.match(r'^(\d+)\s+(.*)$',line)
  if not m:continue
  pid,s=int(m[1]),m[2]
  for num,name in re.findall(r'(\d+)<(/[^>]*)>',s):fd[(pid,int(num))]=name;shared[int(num)]=name
  mk=re.match(r'mkdir\("([^"]+)", 0700\) = 0$',s)
  if mk:
   root=absolute(mk[1],pid)
   if root.endswith('/store'):created[root]=i
  fl=re.match(r'flock\((\d+)<([^>]*/owner\.lock)>, LOCK_EX\|LOCK_NB\) = (.*)$',s)
  if fl:
   root=str(Path(fl[2]).parent)
   if fl[3]=='0':locks[root]=(pid,int(fl[1]))
   else:lock_failures+=1
  unlock=re.match(r'flock\((\d+)<([^>]*/owner\.lock)>, LOCK_UN\) = 0$',s)
  if unlock:
   root=str(Path(unlock[2]).parent)
   if locks.get(root)==(pid,int(unlock[1])):locks.pop(root)
  op=re.match(r'openat\(.*?, "([^"]*/state\.next)", (.*?)\) = (\d+)<([^>]*)>$',s)
  if op and 'O_EXCL' in op[2]:
   target=op[4];root=str(Path(target).parent)
   if root in cycles:
    abandoned.append(cycles.pop(root))
   if not all(flag in op[2] for flag in ('O_RDWR','O_CREAT','O_EXCL','O_NOFOLLOW','O_CLOEXEC')):fail(i,'candidate-open-flags')
   if root not in locks:fail(i,'candidate-without-observed-exclusive-lock')
   if root in created and parent_sync.get(root,0)<=created[root]:fail(i,'initial-parent-directory-not-synced')
   owner=locks[root]
   if root in created and root not in initial_candidates:
    if owner_sync.get(owner,0)<=created[root]:fail(i,'initial-owner-lock-not-synced')
    initial_candidates.add(root)
   cycles[root]={'lockOwner':owner,'root':root,'opened':i,'fd':int(op[3]),'pid':pid,'written':0,'lastWrite':0,'fileSync':0,'closedAfterSync':False,'rename':0,'directorySync':0}
  wr=re.match(r'write\(\d+<([^>]*/state\.next)>,.*?, (\d+)\) = (\d+)$',s)
  if wr:
   root=str(Path(wr[1]).parent);c=cycles.get(root)
   if c and not c['rename']:
    if int(wr[3])>int(wr[2]):fail(i,'write-return-exceeds-request')
    c['written']+=int(wr[3]);c['lastWrite']=i
    if c['written']>1048576:fail(i,'candidate-exceeds-total-limit')
  sy=re.match(r'fsync\(\d+<([^>]*)>\) = 0$',s)
  if sy:
   target=sy[1]
   if target.endswith('/owner.lock'):
    lockRoot=str(Path(target).parent)
    if lockRoot in locks:owner_sync[locks[lockRoot]]=i
   for root in created:
    if str(Path(root).parent)==target:parent_sync[root]=i
   root=str(Path(target).parent)
   if target.endswith('/state.next') and root in cycles:
    c=cycles[root]
    if not(c['written']>0 and c['lastWrite']<i):fail(i,'candidate-sync-before-complete-visible-write')
    c['fileSync']=i
   if target in cycles and cycles[target]['rename']:
    c=cycles[target]
    if locks.get(target)!=c['lockOwner']:fail(i,'directory-sync-without-original-lock')
    if i<=c['rename']:fail(i,'directory-sync-before-rename')
    c['directorySync']=i
  cl=re.match(r'close\((\d+)<([^>]*)>\) = 0$',s)
  if cl:
   num,target=int(cl[1]),cl[2];root=str(Path(target).parent)
   if target.endswith('/state.next') and root in cycles:
    c=cycles[root]
    if c['fileSync'] and num==c['fd']:c['closedAfterSync']=True
   if target.endswith('/owner.lock') and locks.get(root)==(pid,num):locks.pop(root)
   fd.pop((pid,num),None)
  rn=re.match(r'rename\("([^"]+)", "([^"]+)"\) = 0$',s)
  if rn and rn[1].endswith('/state.next'):
   target=absolute(rn[1],pid);root=str(Path(target).parent)
   if absolute(rn[2],pid)!=str(Path(root)/'state'):fail(i,'rename-destination')
   c=cycles.get(root)
   if not c:fail(i,'rename-without-exclusive-candidate')
   if locks.get(root)!=c['lockOwner']:fail(i,'rename-without-original-lock')
   if c['rename']:fail(i,'duplicate-candidate-rename')
   if not(c['fileSync']>c['lastWrite']>c['opened'] and c['closedAfterSync']):fail(i,'rename-without-write-sync-close')
   c['rename']=i;renamed.append(c)
 # Every cycle remains referenced by renamed/abandoned even if replaced later.
 seen={id(c) for c in abandoned}
 for c in cycles.values():
  if id(c) not in seen:abandoned.append(c)
 pending=[c for c in renamed if not c['directorySync']]
 missing_renames=[c for c in abandoned if not c['rename']]
 for c in pending+missing_renames:
  if '/phase30-history-fault-' not in c['root']:raise ValueError('incomplete-cycle-outside-fault-case:'+c['root'])
 # Independently derived from 5 frozen fault frontiers, each run as throw+exit.
 if len(pending)!=2:raise ValueError('expected-two-AfterStateRename-fault-cycles:'+str(len(pending)))
 if len(missing_renames)!=4:raise ValueError('expected-four-pre-rename-fault-prefixes:'+str(len(missing_renames)))
 if not renamed or lock_failures<2:raise ValueError('empty-commit-or-missing-lock-denial-evidence')
 if not any('+++ exited with 0 +++' in s for s in lines[-8:]):raise ValueError('trace-not-complete-successful-exit')
 return {'scope':'real syscall ordering only; source/functional tests bind return/grant ordering; no power-cut or allocated-capacity claim','observedRenames':len(renamed),'directorySyncedRenames':len(renamed)-len(pending),'expectedFaultUnsealedRenames':len(pending),'expectedFaultCandidatePrefixes':len(missing_renames),'observedNonblockingLockDenials':lock_failures,'largestObservedCandidateBytes':max(c['written'] for c in renamed),'allRenamesFollowExclusiveWriteFileSyncClose':True,'initialMkdirParentsSyncedBeforeCandidateCreation':True,'initialOwnerLocksSyncedBeforeCandidateCreation':True,'originalExclusiveLocksRetainedThroughRenameAndDirectorySync':True}

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('trace',type=Path);args=ap.parse_args()
 print(json.dumps(check(args.trace),indent=2))
