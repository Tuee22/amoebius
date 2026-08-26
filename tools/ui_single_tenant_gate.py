#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,os,shlex,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[1]; E=R/"DEVELOPMENT_PLAN/evidence/phase_55"; ENUM=R/"test/enumeration/phase_55_surfaces.txt"; LEDGER=R/"test/golden/phase_55_ledger.json"; CABAL="/home/matthewnowak/.ghcup/bin/cabal"; GHC="/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
FLAGS=("ui-single-tenant-live-disable-csrf-mutant","ui-single-tenant-live-dispatch-before-auth-mutant","ui-single-tenant-live-local-socket-map-mutant","ui-single-tenant-live-redis-receipt-authority-mutant","ui-single-tenant-live-canned-response-mutant","ui-single-tenant-live-open-provider-edge-mutant","ui-single-tenant-live-drop-networkpolicy-mutant")
UNV={"real-oidc-browser","keycloak-envoy-edge","kubernetes-ui-replicas","retained-redis-fanout","retained-postgres-observer","retained-minio-observer","native-pulsar-observer","infernix-worker-observer","provider-network-observers"}
class F(RuntimeError):pass
def req(x,m):
 if not x: raise F(m)
def fp(v):return "sha256:"+hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":" )).encode()).hexdigest()
def cfg(on=None):return tuple(("-f" if f==on else "-f-")+f for f in FLAGS)
def cmd(on=None):return (CABAL,"test","ui-live:ui-single-tenant-live-ui-single-tenant-live","-w",GHC,*cfg(on),"--test-show-details=direct","-j1","-v0")
def run(n,a):
 p=subprocess.run(a,cwd=R,env=os.environ,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);req(p.returncode==0,n+":"+p.stdout);return {"name":n,"command":shlex.join(a),"output":p.stdout.strip(),"result":"PASS"}
def derive():
 s=[x for x in ENUM.read_text().splitlines() if x and not x.startswith("#")];v={"phase":55,"gate_command":"python3 tools/ui_single_tenant_gate.py","register":"3","substrate":"linux-cpu","date":"2026-08-11","layers":[{"name":"Decision","status":"tested"},{"name":"Protocol","status":"tested"},{"name":"Runtime","status":"tested"}],"coverage":[{"surface":x,"status":"UNVERIFIED" if x in UNV else "tested"} for x in s]};q=dict(v);v["ledger_hash"]=fp(q);return v
def main():
 try:
  if "--derive-ledger" in sys.argv:print(json.dumps(derive(),separators=(",",":")));return 0
  rows=[run("contract",cmd()),run("scoped-live",(sys.executable,"tools/ui_single_tenant_live.py"))]
  live=json.loads((E/"ui-single-tenant-live.json").read_text());req(live["challenge"]["sent"]==live["challenge"]["received"]==live["challenge"]["durableReceipt"],"challenge")
  for f in FLAGS:
   p=subprocess.run(cmd(f),cwd=R,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);req(p.returncode!=0,f+":green");rows.append({"name":f,"command":shlex.join(cmd(f)),"output":"contract red","result":"RED"})
  rows+=[run("restored",cmd()),run("docs",(sys.executable,"tools/doc_lint.py"))];d=derive();req(LEDGER.exists() and json.loads(LEDGER.read_text())==d,"ledger");rows.append(run("ledger",(sys.executable,"tools/ledger_lint.py",str(LEDGER),"--enumeration",str(ENUM))))
  stable={"schema":"amoebius.phase55.receipt.v1","register":3,"substrate":"linux-cpu","result":"PASS-SCOPED","localReplicaProbe":"TESTED","providersBrowser":"UNVERIFIED","mutantsRed":list(FLAGS)};receipt={**stable,"receiptFingerprint":fp(stable)};E.mkdir(parents=True,exist_ok=True);(E/"phase-receipt.json").write_text(json.dumps(receipt,indent=2,sort_keys=True)+"\n");(E/"phase-results.tsv").write_text("check\tresult\n"+"".join(f"{x['name']}\t{x['result']}\n" for x in rows));(E/"phase-gate.log").write_text("\n".join(f"CHECK {x['name']}\nCOMMAND {x['command']}\n{x['output']}\nRESULT {x['result']}" for x in rows)+f"\nPHASE-55-GATE PASS-SCOPED {d['ledger_hash']}\n");print(f"ui-single-tenant-live-gate: PASS-SCOPED ({len(rows)} checks; {d['ledger_hash']}; {receipt['receiptFingerprint']}; providers/browser/Kubernetes UNVERIFIED)");return 0
 except (F,OSError,ValueError,KeyError) as e:print("ui-single-tenant-live-gate: FAIL:",e,file=sys.stderr);return 1
if __name__=="__main__":raise SystemExit(main())
