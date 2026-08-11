#!/usr/bin/env python3
"""Run the Phase-1 clean-store buildability and behavioral gate."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import IO, Any


ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / "DEVELOPMENT_PLAN" / "evidence" / "phase_01"
PINS_PATH = ROOT / "toolchain" / "pins.json"
ENUMERATION = ROOT / "test" / "enumeration" / "phase_01_surfaces.txt"
LEDGER = ROOT / "test" / "golden" / "phase_01_ledger.json"
GATE_COMMAND = "python3 tools/phase1_gate.py"

REPRESENTATIVE_DEPENDENCIES = {
    "aeson",
    "base",
    "cryptohash-sha256",
    "dhall",
    "directory",
    "filepath",
    "http-client",
    "http-client-tls",
    "io-classes",
    "io-sim",
    "megaparsec",
    "prettyprinter",
    "proto",
    "proto-lens",
    "purescript-bridge",
    "supernova",
    "tar",
    "template-haskell",
    "typed-process",
    "zlib",
}


class GateFailure(RuntimeError):
    pass


def load_pins() -> dict[str, Any]:
    return json.loads(PINS_PATH.read_text(encoding="utf-8"))


def write_log(path: Path, command: list[str], result: subprocess.CompletedProcess[str]) -> None:
    rendered = " ".join(command)
    path.write_text(
        f"$ {rendered}\nexit_status={result.returncode}\n\n"
        f"[stdout]\n{result.stdout}\n[stderr]\n{result.stderr}",
        encoding="utf-8",
    )


def checked_capture(
    command: list[str],
    *,
    env: dict[str, str] | None = None,
    expected: int = 0,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != expected:
        raise GateFailure(
            f"command exited {result.returncode}, expected {expected}: {' '.join(command)}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result


def stream_command(
    command: list[str],
    log: IO[str],
    *,
    env: dict[str, str] | None = None,
) -> None:
    rendered = " ".join(command)
    print(f"$ {rendered}", flush=True)
    log.write(f"$ {rendered}\n")
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    assert process.stdout is not None
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        log.write(line)
    status = process.wait()
    print(f"exit_status={status}", flush=True)
    log.write(f"exit_status={status}\n")
    log.flush()
    if status != 0:
        raise GateFailure(f"command exited {status}: {rendered}")


def verify_probe_dependencies() -> None:
    text = (ROOT / "probe" / "probe.cabal").read_text(encoding="utf-8")
    match = re.search(
        r"(?ms)^executable probe\n(?P<body>.*?)(?=^executable |\Z)",
        text,
    )
    if match is None:
        raise GateFailure("probe/probe.cabal has no executable probe stanza")
    body = match.group("body")
    depends = re.search(
        r"(?ms)^  build-depends:\n(?P<deps>.*?)(?=^  [a-zA-Z-]+:|\Z)",
        body,
    )
    if depends is None:
        raise GateFailure("probe executable has no build-depends stanza")
    actual = {
        re.match(r"[a-zA-Z0-9-]+", item.strip()).group(0)
        for item in depends.group("deps").split(",")
        if item.strip()
    }
    if actual != REPRESENTATIVE_DEPENDENCIES:
        raise GateFailure(
            "representative build-depends drifted: "
            f"missing={sorted(REPRESENTATIVE_DEPENDENCIES - actual)}, "
            f"extra={sorted(actual - REPRESENTATIVE_DEPENDENCIES)}"
        )


def install_browser_tools(pins: dict[str, Any]) -> None:
    purs = Path(pins["purs"]["path"])
    spago = Path(pins["spago"]["path"])
    log_path = EVIDENCE / "browser_toolchain.log"
    if not purs.is_file() or not spago.is_file():
        result = checked_capture(["npm", "ci"])
        write_log(log_path, ["npm", "ci"], result)
    elif not log_path.is_file():
        log_path.write_text("npm ci previously completed; package-lock.json is the retained resolution.\n", encoding="utf-8")


def install_codegen_tools(
    pins: dict[str, Any],
    cabal: str,
    generator_store: Path,
    generator_build: Path,
    build_log: IO[str],
) -> dict[str, str]:
    protoc = pins["protoc"]
    tool_bin = Path(protoc["path"]).parent
    tool_bin.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="amoebius-phase1-protoc-") as temporary:
        archive = Path(temporary) / "protoc.zip"
        urllib.request.urlretrieve(protoc["url"], archive)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if digest != protoc["sha256"]:
            raise GateFailure(f"protoc archive hash {digest} != pin {protoc['sha256']}")
        with zipfile.ZipFile(archive) as zipped:
            member = zipped.getinfo("bin/protoc")
            member.filename = "protoc"
            zipped.extract(member, tool_bin)
    protoc_path = Path(protoc["path"])
    protoc_path.chmod(0o755)

    install = [
        cabal,
        f"--builddir={generator_build}",
        f"--store-dir={generator_store}",
        "install",
        f"proto-lens-protoc-{pins['proto_lens_protoc']['version']}",
        f"--installdir={tool_bin}",
        "--install-method=copy",
        "--overwrite-policy=always",
    ]
    stream_command(install, build_log)
    generator_path = Path(pins["proto_lens_protoc"]["path"])
    if not generator_path.is_file():
        raise GateFailure(f"code generator was not installed at {generator_path}")

    environment = os.environ.copy()
    environment["PATH"] = str(tool_bin) + os.pathsep + environment["PATH"]
    return environment


def verify_versions(pins: dict[str, Any], environment: dict[str, str], log: IO[str]) -> None:
    commands = [
        ([pins["ghc"]["path"], "--numeric-version"], pins["ghc"]["version"]),
        ([pins["cabal"]["path"], "--numeric-version"], pins["cabal"]["version"]),
        ([pins["dhall"]["path"], "--version"], pins["dhall"]["version"]),
        ([pins["purs"]["path"], "--version"], pins["purs"]["version"]),
        (["node", pins["spago"]["path"], "--version"], pins["spago"]["version"]),
        ([pins["chromium"]["path"], "--version"], pins["chromium"]["version"]),
        ([pins["protoc"]["path"], "--version"], pins["protoc"]["version"]),
    ]
    for command, expected in commands:
        result = checked_capture(command, env=environment)
        combined = result.stdout + result.stderr
        log.write(f"$ {' '.join(command)}\n{combined}exit_status={result.returncode}\n")
        if expected not in combined:
            raise GateFailure(f"version pin {expected!r} absent from output of {' '.join(command)}")
    log.flush()


def retain_generated_modules(build_dir: Path, environment: dict[str, str], pins: dict[str, Any]) -> None:
    candidates = sorted(build_dir.glob("src/supernova-*/proto/src/pulsar_api.proto"))
    if len(candidates) != 1:
        raise GateFailure(f"expected one checked-out pulsar_api.proto, found {len(candidates)}")
    output = EVIDENCE / "generated"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    checked_capture(
        [
            pins["protoc"]["path"],
            f"--plugin=protoc-gen-haskell={pins['proto_lens_protoc']['path']}",
            f"--haskell_out={output}",
            f"--proto_path={candidates[0].parent}",
            candidates[0].name,
        ],
        env=environment,
    )
    modules = [output / "Proto" / "PulsarApi.hs", output / "Proto" / "PulsarApi_Fields.hs"]
    if any(not module.is_file() or module.stat().st_size == 0 for module in modules):
        raise GateFailure("proto-lens did not emit both non-empty PulsarApi modules")
    manifest = "".join(
        f"{hashlib.sha256(module.read_bytes()).hexdigest()}  {module.relative_to(EVIDENCE)}\n"
        for module in modules
    )
    (output / "SHA256SUMS").write_text(manifest, encoding="utf-8")


def run_behavioral_gates(cabal: str, build_dir: Path, store: Path, environment: dict[str, str]) -> None:
    common = [cabal, "-v0", f"--builddir={build_dir}", f"--store-dir={store}"]

    linked_cmd = [*common, "run", "probe:probe"]
    linked = checked_capture(linked_cmd, env=environment)
    write_log(EVIDENCE / "dependency_probe.log", linked_cmd, linked)
    if linked.stdout != "phase-1-dependency-surface-linked\n":
        raise GateFailure("dependency probe stdout did not match its committed terminal value")

    positive_cmd = [*common, "run", "probe:decode", "--", "probe/fixtures/ok.dhall"]
    positive = checked_capture(positive_cmd, env=environment)
    write_log(EVIDENCE / "decode_positive.log", positive_cmd, positive)
    expected_decode = (ROOT / "probe" / "fixtures" / "ok.expected").read_text(encoding="utf-8")
    if positive.stdout != expected_decode:
        raise GateFailure(f"decode mismatch: expected {expected_decode!r}, got {positive.stdout!r}")

    negative_cmd = [*common, "run", "probe:decode", "--", "probe/fixtures/bad-type.dhall"]
    negative = subprocess.run(
        negative_cmd, cwd=ROOT, env=environment, text=True, capture_output=True, check=False
    )
    write_log(EVIDENCE / "decode_negative.log", negative_cmd, negative)
    expected_error = (ROOT / "probe" / "fixtures" / "bad-type.expected-error").read_text(encoding="utf-8").strip()
    if negative.returncode == 0 or expected_error not in negative.stdout + negative.stderr:
        raise GateFailure("bad Dhall fixture did not fail at the committed type-error tag")

    oracle = ROOT / "probe" / "oracle" / "check-sim-terminal"
    sim_cmd = [
        sys.executable,
        str(oracle),
        f"--builddir={build_dir}",
        f"--store-dir={store}",
    ]
    sim = checked_capture(sim_cmd, env=environment)
    write_log(EVIDENCE / "sim_positive.log", sim_cmd, sim)

    mutant_cmd = [*sim_cmd, "--perturbed"]
    mutant = subprocess.run(
        mutant_cmd, cwd=ROOT, env=environment, text=True, capture_output=True, check=False
    )
    write_log(EVIDENCE / "sim_mutant.log", mutant_cmd, mutant)
    if mutant.returncode == 0 or "terminal-state mismatch" not in mutant.stdout + mutant.stderr:
        raise GateFailure("schedule perturbation mutant was not killed at the terminal-state oracle")


def run_dependency_mutant(cabal: str) -> None:
    with tempfile.TemporaryDirectory(prefix="amoebius-phase1-mutant-store-") as store_raw:
        with tempfile.TemporaryDirectory(prefix=".phase1-build-mutant-", dir=ROOT) as build_raw:
            command = [
                cabal,
                "--project-file=probe/mutants/drop-allow-newer.project",
                f"--builddir={build_raw}",
                f"--store-dir={store_raw}",
                "build",
                "all",
                "proto",
            ]
            result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
            write_log(EVIDENCE / "dependency_mutant.log", command, result)
            output = result.stdout + result.stderr
            intended = re.search(r"proto\s*=>\s*base>=4\.13\.0\s*&&\s*<4\.14", output)
            if result.returncode == 0 or intended is None:
                raise GateFailure("dependency mutant did not fail at the intended proto/base bound conflict")


def emit_ledger() -> str:
    from ledger_lint import canonical_hash

    ledger: dict[str, Any] = {
        "phase": 1,
        "gate_command": GATE_COMMAND,
        "register": "1",
        "substrate": "none",
        "date": dt.date.today().isoformat(),
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": [
            {"surface": "toolchain-pins", "status": "tested"},
            {"surface": "browser-toolchain", "status": "tested"},
            {"surface": "representative-haskell-build", "status": "tested"},
            {"surface": "dhall-decode", "status": "tested"},
            {"surface": "iosim-terminal", "status": "tested"},
            {"surface": "supernova-proto-codegen", "status": "tested"},
            {"surface": "dependency-resolution-mutant", "status": "tested"},
            {"surface": "simulation-schedule-mutant", "status": "tested"},
            {"surface": "gate-2-semantics", "status": "UNVERIFIED"},
            {"surface": "runtime-and-cluster-semantics", "status": "UNVERIFIED"},
        ],
        "ledger_hash": "",
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    LEDGER.write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")
    lint = checked_capture(
        [
            sys.executable,
            str(ROOT / "tools" / "ledger_lint.py"),
            str(LEDGER),
            "--enumeration",
            str(ENUMERATION),
        ]
    )
    if lint.stdout:
        print(lint.stdout, end="")
    return ledger["ledger_hash"]


def main() -> int:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    verify_probe_dependencies()
    pins = load_pins()
    install_browser_tools(pins)
    cabal = pins["cabal"]["path"]

    try:
        with tempfile.TemporaryDirectory(prefix="amoebius-phase1-store-") as store_raw:
            with tempfile.TemporaryDirectory(prefix="amoebius-phase1-generator-store-") as generator_store_raw:
                with tempfile.TemporaryDirectory(prefix=".phase1-build-", dir=ROOT) as build_raw:
                    with tempfile.TemporaryDirectory(prefix=".phase1-build-generator-", dir=ROOT) as generator_build_raw:
                        store = Path(store_raw)
                        if any(store.iterdir()):
                            raise GateFailure("new Phase-1 package store was not empty")
                        build_dir = Path(build_raw)
                        build_log_path = EVIDENCE / "consolidated_build.log"
                        with build_log_path.open("w", encoding="utf-8") as build_log:
                            environment = install_codegen_tools(
                                pins,
                                cabal,
                                Path(generator_store_raw),
                                Path(generator_build_raw),
                                build_log,
                            )
                            verify_versions(pins, environment, build_log)
                            stream_command(
                                [
                                    cabal,
                                    f"--builddir={build_dir}",
                                    f"--store-dir={store}",
                                    "build",
                                    "all",
                                    "proto",
                                ],
                                build_log,
                                env=environment,
                            )
                        retain_generated_modules(build_dir, environment, pins)
                        run_behavioral_gates(cabal, build_dir, store, environment)
        run_dependency_mutant(cabal)
        ledger_hash = emit_ledger()
    except (GateFailure, OSError, zipfile.BadZipFile) as error:
        print(f"phase1-gate: FAIL: {error}", file=sys.stderr)
        return 1

    print(f"phase1-gate: PASS ({ledger_hash})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
