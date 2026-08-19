"""The one choke point: what it refuses, what it records, and what it becomes."""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from pb import process
from pb.process import Completed, Invocation, Kind, Ledger, ProcessError


def test_kind_renders_as_its_value() -> None:
    assert str(Kind.PROBE) == "probe"
    assert str(Kind.MUTATION) == "mutation"


def test_invocation_and_completed_render() -> None:
    invocation = Invocation(Kind.PROBE, "/bin/echo", ("a", "b"))
    assert invocation.render() == "probe\t/bin/echo\ta b"
    assert Invocation(Kind.PROBE, "/bin/echo", ()).render() == "probe\t/bin/echo"
    assert Completed(invocation, 0, "").ok
    assert not Completed(invocation, 1, "").ok


def test_ledger_separates_probes_from_mutations() -> None:
    ledger = Ledger()
    ledger.record(Invocation(Kind.PROBE, "/a", ()))
    ledger.record(Invocation(Kind.MUTATION, "/b", ("x",)))
    assert len(ledger.entries) == 2
    assert [entry.executable for entry in ledger.mutations] == ["/b"]
    assert [entry.executable for entry in ledger.probes] == ["/a"]
    assert ledger.render() == "probe\t/a\nmutation\t/b\tx\n"


def test_executable_problem_names_each_refusal(tmp_path: Path, executable) -> None:
    assert process.executable_problem(Path("echo")).startswith(
        "non-absolute-executable"
    )
    assert process.executable_problem(tmp_path / "absent").startswith(
        "missing-executable"
    )
    plain = tmp_path / "plain"
    plain.write_text("", encoding="utf-8")
    plain.chmod(0o600)
    assert process.executable_problem(plain).startswith("not-executable")
    assert process.executable_problem(executable("ok")) is None


def test_environment_overlays_rather_than_replaces() -> None:
    merged = process.environment({"PB_ONLY": "1"})
    assert merged["PB_ONLY"] == "1"
    assert "PATH" in merged
    assert process.environment()["PATH"] == os.environ["PATH"]


def test_run_refuses_a_bare_name() -> None:
    with pytest.raises(ProcessError, match="non-absolute-executable"):
        process.run(Path("kind"), [], kind=Kind.PROBE)


def test_run_records_before_it_starts_and_captures_output(recorder) -> None:
    ledger = Ledger()
    tool = recorder.make("tool")
    completed = process.run(
        tool, ["a", "b"], kind=Kind.MUTATION, ledger=ledger, mirror=False
    )
    assert completed.ok
    assert recorder.argv() == ["a b"]
    assert ledger.mutations[0].arguments == ("a", "b")


def test_run_mirrors_when_asked(executable, capsys: pytest.CaptureFixture[str]) -> None:
    tool = executable("say", "#!/bin/sh\necho hello\n")
    completed = process.run(tool, [], kind=Kind.PROBE, mirror=True)
    assert "hello" in completed.output
    assert "hello" in capsys.readouterr().out


def test_run_reports_a_non_zero_child(executable) -> None:
    tool = executable("bad", "#!/bin/sh\nexit 3\n")
    assert process.run(tool, [], kind=Kind.PROBE, mirror=False).returncode == 3


def test_run_wraps_a_start_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    tool = tmp_path / "ok"
    tool.write_text("#!/bin/sh\n", encoding="utf-8")
    tool.chmod(0o700)

    def refuse(*_args: object, **_kwargs: object) -> None:
        raise OSError("no fork")

    monkeypatch.setattr(process.subprocess, "Popen", refuse)
    with pytest.raises(ProcessError, match="could-not-start"):
        process.run(tool, [], kind=Kind.PROBE)


def test_run_checked_returns_output_or_refuses(executable) -> None:
    assert "hi" in process.run_checked(
        executable("say", "#!/bin/sh\necho hi\n"), [], kind=Kind.PROBE, mirror=False
    )
    with pytest.raises(ProcessError, match="command-failed"):
        process.run_checked(
            executable("bad", "#!/bin/sh\nexit 2\n"), [], kind=Kind.PROBE, mirror=False
        )


def test_become_refuses_a_bare_name() -> None:
    with pytest.raises(ProcessError, match="non-absolute-executable"):
        process.become(Path("amoebius"), [])


def test_become_execs_on_posix(executable, monkeypatch: pytest.MonkeyPatch) -> None:
    """The one call that replaces the process, observed rather than performed."""
    tool = executable("bin")
    seen: list[tuple[str, list[str]]] = []
    monkeypatch.setattr(os, "name", "posix")
    monkeypatch.setattr(os, "execv", lambda path, argv: seen.append((path, argv)))
    with pytest.raises(ProcessError, match="execv-returned"):
        process.become(tool, ["bootstrap", "--distro=kind"])
    assert seen == [(str(tool), [str(tool), "bootstrap", "--distro=kind"])]


def test_become_propagates_the_child_code_on_windows(
    recorder, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(os, "name", "nt")
    tool = recorder.make("bin", code=7)
    assert process.become(tool, ["x"]) == 7
    assert recorder.argv() == ["x"]
