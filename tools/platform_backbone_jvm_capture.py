#!/usr/bin/env python3
"""Freshly compile/probe immutable capture against the verified image classpath.

The live caller first authenticates its source pod/image and copies those jars.
This runner pins the independently reviewed core jars and records every dependency.
It tests a serialization primitive; it installs no agent or runtime permission.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import containment
import toolchain

ROOT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            result.update(block)
    return result.hexdigest()


def execute(classpath: Path, output: Path) -> dict:
    classpath = containment.require_state_path(classpath, "build", actor="test")
    output = containment.require_state_path(output, "build", actor="test")
    output.mkdir(parents=True, exist_ok=False)
    classes = output / "classes"
    classes.mkdir()
    corpus = ROOT / "test/oracle/platform_backbone_zookeeper_capture.json"
    if digest(corpus) != "93ef7637c51a978419bb723ceed739083dabe0a8dd86534fdb43498f7f438c19":
        raise ValueError("capture-independent-corpus-mismatch")
    rebound_corpus = ROOT / "test/oracle/platform_backbone_zookeeper_capture_with_digest.json"
    if digest(rebound_corpus) != "c95261b5ae0d3a2127b49a21759a694f1ebc3b1d7eb59f2d8943b6f284141b93":
        raise ValueError("capture-independent-rebinding-corpus-mismatch")
    registry_corpus = ROOT / "test/oracle/platform_backbone_zookeeper_capture_registry.json"
    if digest(registry_corpus) != "d9687941054ff1d205003ae05e1628a37ba3080704b31f80a3a5294a1dfecba7":
        raise ValueError("capture-independent-registry-corpus-mismatch")
    matcher_corpus = ROOT / "test/oracle/platform_backbone_zookeeper_capture_registry_matcher.json"
    if digest(matcher_corpus) != "7d2d861c41554221ed0787539ca04bb8216eaf0197994cc4548fd8d6c59c5db0":
        raise ValueError("capture-independent-registry-matcher-corpus-mismatch")
    expected = json.loads((ROOT / "test/oracle/platform_backbone_zookeeper_capture_classpath.json").read_text())["coreJars"]
    jars = {path.name: path for path in classpath.glob("*.jar")}
    if not set(expected) <= set(jars) or any(not path.is_file() or path.is_symlink() for path in jars.values()):
        raise ValueError("capture-classpath-domain")
    hashes = {name: digest(path) for name, path in jars.items()}
    if any(hashes[name] != value for name, value in expected.items()):
        raise ValueError("capture-core-jar-mismatch")
    ordered = [jars[name] for name in expected] + [jars[name] for name in sorted(set(jars)-set(expected))]
    resolved = toolchain.resolve(["javac"])["javac"]
    compiler = Path(resolved["path"])
    java = compiler.with_name("java")
    environment = toolchain.contained_env()

    def run(arguments: list[str], name: str) -> subprocess.CompletedProcess:
        result = subprocess.run(arguments, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180, check=False)
        (output / name).write_bytes(result.stdout)
        if result.returncode:
            raise ValueError("capture-command-failed:" + name + ":" + str(result.returncode))
        return result

    run([sys.executable, "test/spec/platform/zookeeper_capture_reference.py"], "reference.log")
    run([sys.executable, "test/spec/platform/zookeeper_capture_with_digest_reference.py"], "rebinding-reference.log")
    run([sys.executable, "test/spec/platform/zookeeper_capture_registry_reference.py"], "registry-reference.log")
    run([sys.executable, "test/spec/platform/zookeeper_capture_probe.py", "--output", str(output)], "generator.log")
    run([sys.executable, "test/spec/platform/zookeeper_capture_with_digest_probe.py", "--output", str(output)], "rebinding-generator.log")
    run([sys.executable, "test/spec/platform/zookeeper_capture_registry_probe.py", "--output", str(output)], "registry-generator.log")
    run([sys.executable, "test/spec/platform/zookeeper_capture_registry_matcher_reference.py",
         "--probe-output", str(output)], "matcher-generator.log")
    source = ROOT / "jvm/org/amoebius/history/CapturedTransaction.java"
    registry_source = ROOT / "jvm/org/amoebius/history/CaptureRegistry.java"
    before = digest(source)
    registry_before = digest(registry_source)
    generated = output / "CaptureProbe.java"
    cp = os.pathsep.join(str(path) for path in ordered)
    run([str(compiler), "-J-Xmx128m", "-J-XX:ActiveProcessorCount=2", "--release", "21", "-cp", cp,
         "-d", str(classes), str(source), str(registry_source), str(generated),
         str(output / "CaptureWithDigestProbe.java"), str(output / "CaptureRegistryProbe.java"),
         str(output / "MatcherProbe.java")], "compile.log")
    if digest(source) != before or digest(registry_source) != registry_before:
        raise ValueError("capture-source-changed-during-compilation")
    result = run([str(java), "-Xmx128m", "-XX:ActiveProcessorCount=2", "-Dzookeeper.digest.enabled=true",
                  "-Dzookeeper.closeSessionTxn.enabled=true", "-cp", str(classes)+os.pathsep+cp, "CaptureProbe"], "probe.log")
    match = re.search(rb"^PASS assertions=([0-9]+) cases=34\+41\+3$", result.stdout, re.MULTILINE)
    if match is None:
        raise ValueError("capture-probe-result-absent")
    rebound = run([str(java), "-Xmx128m", "-XX:ActiveProcessorCount=2", "-Dzookeeper.digest.enabled=true",
                   "-Dzookeeper.closeSessionTxn.enabled=true", "-cp", str(classes)+os.pathsep+cp,
                   "CaptureWithDigestProbe"], "rebinding-probe.log")
    rebound_match = re.search(rb"^PASS withDigest assertions=([0-9]+) cases=34\+7\+10\+1$", rebound.stdout, re.MULTILINE)
    if rebound_match is None:
        raise ValueError("capture-rebinding-probe-result-absent")
    registry = run([str(java), "-Xmx128m", "-XX:ActiveProcessorCount=2", "-Dzookeeper.digest.enabled=true",
                    "-Dzookeeper.closeSessionTxn.enabled=true", "-cp", str(classes)+os.pathsep+cp,
                    "CaptureRegistryProbe"], "registry-probe.log")
    registry_match = re.search(rb"^PASS registry assertions=([0-9]+) cases=4\+32\+3$", registry.stdout, re.MULTILINE)
    if registry_match is None:
        raise ValueError("capture-registry-probe-result-absent")
    matcher = run([str(java), "-Xmx128m", "-XX:ActiveProcessorCount=2", "-cp", str(classes)+os.pathsep+cp,
                   "MatcherProbe"], "matcher-probe.log")
    matcher_result = re.search(rb"^PASS matcher assertions=([0-9]+) cases=3$", matcher.stdout, re.MULTILINE)
    if matcher_result is None:
        raise ValueError("capture-registry-matcher-probe-result-absent")
    compiled = classes / "org/amoebius/history/CapturedTransaction.class"
    header = compiled.read_bytes()[:8]
    if header[:4] != b"\xca\xfe\xba\xbe" or int.from_bytes(header[6:8], "big") != 65:
        raise ValueError("capture-classfile-target-mismatch")
    class_files = {str(path.relative_to(classes)): digest(path) for path in classes.rglob("*.class")}
    proof = {"scope": "compiled immutable serialization primitive only; no installed guard/RPC authority",
             "sourceSha256": before, "classSha256": digest(compiled), "generatedProbeSha256": digest(generated),
             "corpusSha256": digest(corpus), "compiler": resolved, "independentAssertions": int(match[1]),
             "wireCases": 34, "boundaryCases": 41, "mutationCases": 3,
             "digestRebinding": {"wireCases": 34, "sequenceCases": 7, "denialCases": 10, "retryCases": 1,
                 "independentAssertions": int(rebound_match[1]), "corpusSha256": digest(rebound_corpus),
                 "generatedProbeSha256": digest(output / "CaptureWithDigestProbe.java"),
                 "classSha256": digest(classes / "CaptureWithDigestProbe.class"),
                 "probeLogSha256": digest(output / "rebinding-probe.log")},
             "registry": {"constructorCases": 4, "sequenceCases": 32, "concurrencyCases": 3,
                 "independentAssertions": int(registry_match[1]), "sourceSha256": registry_before,
                 "corpusSha256": digest(registry_corpus),
                 "generatedProbeSha256": digest(output / "CaptureRegistryProbe.java"),
                 "classSha256": digest(classes / "CaptureRegistryProbe.class"),
                 "probeLogSha256": digest(output / "registry-probe.log")},
             "registryMatcher": {"cases": 3, "independentAssertions": int(matcher_result[1]),
                 "corpusSha256": digest(matcher_corpus),
                 "generatedProbeSha256": digest(output / "MatcherProbe.java"),
                 "classSha256": digest(classes / "MatcherProbe.class"),
                 "probeLogSha256": digest(output / "matcher-probe.log")},
             "jarInputs": [{"name": name, "sha256": hashes[name]} for name in sorted(jars)],
             "probeLogSha256": digest(output / "probe.log"), "freshCompilation": True}
    proof["classFiles"] = class_files
    (output / "provenance.json").write_text(json.dumps(proof, indent=2) + "\n")
    return proof


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--classpath", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = execute(args.classpath, args.output)
    print(json.dumps({**{key: result[key] for key in ("scope", "independentAssertions", "wireCases", "boundaryCases", "mutationCases")},
                      "rebindingAssertions": result["digestRebinding"]["independentAssertions"],
                      "registryAssertions": result["registry"]["independentAssertions"],
                      "matcherAssertions": result["registryMatcher"]["independentAssertions"]}))


if __name__ == "__main__":
    main()
