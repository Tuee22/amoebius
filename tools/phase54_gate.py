#!/usr/bin/env python3
"""Seal the scoped Phase-54 topology-testing gate."""
from __future__ import annotations
import hashlib, json, os, shlex, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]; E=ROOT/"DEVELOPMENT_PLAN/evidence/phase_54"
ENUM=ROOT/"test/enumeration/phase_54_surfaces.txt"; LEDGER=ROOT/"test/golden/phase_54_ledger.json"
CABAL="/home/matthewnowak/.ghcup/bin/cabal"; GHC="/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"; DHALL="/home/matthewnowak/.local/bin/dhall"
FLAGS=("phase54-skip-teardown-mutant","phase54-tag-query-mutant","phase54-all-tested-mutant","phase54-wrong-subscription-mutant")
MARKERS={FLAGS[0]:"teardown on failure",FLAGS[1]:"untagged leak escaped",FLAGS[2]:"derived applicable coverage",FLAGS[3]:"DelegatedFailoverRequired"}
UNVERIFIED={"kubernetes-test-topology","retained-pv-backing-delete","pulsar-broker-failover-stats","live-vault-flagged-credential","aws-service-native-inventory","provider-cloud-leak-mutant","real-suggest-test-host-probe","operator-reviewed-provenance-diff","live-kubernetes-rbac-denial","host-retained-root-os-denial","cloud-delete-access-denied","full-failover-resource-readback"}
class Failure(RuntimeError): pass
def require(ok,msg):
    if not ok: raise Failure(msg)
def fp(v): return "sha256:"+hashlib.sha256(json.dumps(v,sort_keys=True,separators=(",",":")).encode()).hexdigest()
def canon(v):
    x=dict(v); x.pop("ledger_hash",None); return fp(x)
def config(enabled=None): return tuple(("-f" if f==enabled else "-f-")+f for f in FLAGS)
def contract(enabled=None): return (CABAL,"test","test-topology:test-topology-contract","-w",GHC,*config(enabled),"--test-show-details=direct","-j1","-v0")
def invoke(name,argv,timeout=1800):
    p=subprocess.run(argv,cwd=ROOT,env=os.environ,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    require(p.returncode==0,f"{name}:{p.stdout}"); return {"name":name,"command":shlex.join(argv),"output":p.stdout.strip(),"result":"PASS"}
def mutant(flag,marker):
    argv=contract(flag); p=subprocess.run(argv,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    require(p.returncode!=0 and marker in p.stdout,f"{flag}:green-or-wrong:{p.stdout}"); return {"name":flag,"command":shlex.join(argv),"output":marker,"result":"RED"}
def derive():
    surfaces=[x for x in ENUM.read_text().splitlines() if x and not x.startswith("#")]; require(UNVERIFIED<=set(surfaces),"enum")
    v={"phase":54,"gate_command":"python3 tools/phase54_gate.py","register":"3","substrate":"per generated test","date":"2026-08-11","layers":[{"name":"Decision","status":"tested"},{"name":"Protocol","status":"tested"},{"name":"Runtime","status":"tested"}],"coverage":[{"surface":s,"status":"UNVERIFIED" if s in UNVERIFIED else "tested"} for s in surfaces]}; v["ledger_hash"]=canon(v); return v
def main():
  try:
    if "--derive-ledger" in sys.argv: print(json.dumps(derive(),separators=(",",":"))); return 0
    rows=[invoke("build",(CABAL,"build","test-topology:lib:test-topology","test-topology:test-topology-contract","test-topology:test-topology-live-gate","-w",GHC,*config(),"-j1","-v0"))]
    manifest=[x for x in (ROOT/"test/oracle/preimplementation_artifacts.tsv").read_text().splitlines() if x.startswith("54\t")]; require(len(manifest)==20,"custody")
    rows.append({"name":"phase0-custody","command":"read manifest","output":"12 oracles; 8 mutants","result":"PASS"})
    rows.append(invoke("topology-dhall",(DHALL,"type","--file","test/dhall/phase_54_failover.dhall","--quiet")))
    bad=subprocess.run((DHALL,"type","--file","test/dhall/phase_54_pvc_binding_illegal.dhall","--quiet"),cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); require(bad.returncode!=0 and "Assertion failed" in bad.stdout,"illegal-pvc")
    rows.append({"name":"illegal-pvc","command":"dhall type illegal","output":"Assertion failed","result":"RED"})
    rows.append(invoke("contract",contract())); rows.append(invoke("live",(sys.executable,"tools/phase54_test_topology_live.py")))
    rows.append(invoke("reader",(CABAL,"test","test-topology:test-topology-live-gate","-w",GHC,"--test-show-details=direct","-j1","-v0")))
    rows.extend(mutant(f,m) for f,m in MARKERS.items()); rows.append(invoke("restored",contract()))
    rows.append(invoke("docs",(sys.executable,"tools/doc_lint.py")))
    d=derive(); require(LEDGER.exists() and json.loads(LEDGER.read_text())==d,"ledger-diff")
    rows.append(invoke("ledger",(sys.executable,"tools/ledger_lint.py",str(LEDGER),"--enumeration",str(ENUM))))
    stable={"schema":"amoebius.phase54.receipt.v1","register":3,"substrate":"linux-cpu","result":"PASS-SCOPED","hostTeardown":"TESTED","kubernetesPulsarCloud":"UNVERIFIED","mutantsRed":list(FLAGS)}; receipt={**stable,"receiptFingerprint":fp(stable)}
    E.mkdir(parents=True,exist_ok=True); (E/"phase-receipt.json").write_text(json.dumps(receipt,indent=2,sort_keys=True)+"\n"); (E/"phase-results.tsv").write_text("check\tresult\n"+"".join(f"{r['name']}\t{r['result']}\n" for r in rows)); (E/"phase-gate.log").write_text("\n".join(f"CHECK {r['name']}\nCOMMAND {r['command']}\n{r['output']}\nRESULT {r['result']}" for r in rows)+f"\nPHASE-54-GATE PASS-SCOPED {d['ledger_hash']}\n")
    print(f"phase54-gate: PASS-SCOPED ({len(rows)} checks; {d['ledger_hash']}; {receipt['receiptFingerprint']}; Kubernetes/Pulsar/retained-PV/Vault/AWS UNVERIFIED)"); return 0
  except (Failure,OSError,ValueError,KeyError,subprocess.TimeoutExpired) as e: print(f"phase54-gate: FAIL: {e}",file=sys.stderr); return 1
if __name__=="__main__": raise SystemExit(main())
