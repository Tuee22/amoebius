#!/usr/bin/env python3
import hashlib,json,os,shlex,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[1];E=R/"DEVELOPMENT_PLAN/evidence/phase_56";N=R/"test/enumeration/phase_57_surfaces.txt";L=R/"test/golden/phase_57_ledger.json";C="/home/matthewnowak/.ghcup/bin/cabal";G="/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc";F=("ui-multi-tenant-live-accept-unlisted-choice-mutant","ui-multi-tenant-live-drop-tenant-key-mutant","ui-multi-tenant-live-drop-user-key-mutant","ui-multi-tenant-live-drop-scope-epoch-mutant");U={"keycloak-real-sessions","real-browser-tenant-switch","provider-zero-delta-observers","kubernetes-audit","foreign-pod-cni-probe","redis-realtime-scope-change"}
def fp(v):return "sha256:"+hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":" )).encode()).hexdigest()
def cfg(x=None):return tuple(("-f" if a==x else "-f-")+a for a in F)
def cmd(x=None):return (C,"test","ui-live:ui-multi-tenant-live","-w",G,*cfg(x),"--test-show-details=direct","-j1","-v0")
def run(a):return subprocess.run(a,cwd=R,env=os.environ,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
def derive():
 s=[x for x in N.read_text().splitlines() if x];v={"phase":56,"gate_command":"python3 tools/ui_multi_tenant_gate.py","register":"3","substrate":"linux-cpu","date":"2026-08-11","layers":[{"name":"Decision","status":"tested"},{"name":"Protocol","status":"tested"},{"name":"Runtime","status":"tested"}],"coverage":[{"surface":x,"status":"UNVERIFIED" if x in U else "tested"} for x in s]};v["ledger_hash"]=fp(v);return v
def main():
 if "--derive-ledger" in sys.argv:print(json.dumps(derive(),separators=(",",":")));return 0
 rows=[];p=run(cmd());
 if p.returncode:print(p.stdout);return 1
 rows.append(("contract","PASS"));p=run((sys.executable,"tools/ui_multi_tenant_live.py"));
 if p.returncode:print(p.stdout);return 1
 rows.append(("scoped-live","PASS"))
 for f in F:
  p=run(cmd(f));
  if p.returncode==0:print(f+" green",file=sys.stderr);return 1
  rows.append((f,"RED"))
 p=run(cmd());
 if p.returncode:return 1
 rows.append(("restored","PASS"));p=run((sys.executable,"tools/doc_lint.py"));
 if p.returncode:print(p.stdout);return 1
 d=derive();
 if not L.exists() or json.loads(L.read_text())!=d:print("ledger diff",file=sys.stderr);return 1
 p=run((sys.executable,"tools/ledger_lint.py",str(L),"--enumeration",str(N)));
 if p.returncode:print(p.stdout);return 1
 rows += [("docs","PASS"),("ledger","PASS")];stable={"schema":"amoebius.phase56.receipt.v1","register":3,"substrate":"linux-cpu","result":"PASS-SCOPED","opaqueScopeKernel":"TESTED","providersBrowser":"UNVERIFIED","mutantsRed":list(F)};q={**stable,"receiptFingerprint":fp(stable)};E.mkdir(parents=True,exist_ok=True);(E/"phase-receipt.json").write_text(json.dumps(q,indent=2,sort_keys=True)+"\n");(E/"phase-results.tsv").write_text("check\tresult\n"+"".join(f"{a}\t{b}\n" for a,b in rows));print(f"ui-multi-tenant-live-gate: PASS-SCOPED ({len(rows)} checks; {d['ledger_hash']}; {q['receiptFingerprint']}; Keycloak/browser/providers UNVERIFIED)");return 0
if __name__=="__main__":raise SystemExit(main())
