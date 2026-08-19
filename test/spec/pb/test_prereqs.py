"""The floor as a plan, the floor on a host, and the ensure driver."""

from __future__ import annotations

import dataclasses
import hashlib
import io
import json
from pathlib import Path

import pytest
from pb import bootstrap_toolchain as toolchain
from pb import narrow, prereqs, process
from pb.narrow import NarrowError
from pb.prereqs import (
    Acquisition,
    HostObservation,
    Prerequisite,
    PrerequisiteError,
    Probe,
    ProbeKind,
    Refusal,
    Substrate,
    ValidatedExecution,
)

# --------------------------------------------------------------------------
# the vocabulary
# --------------------------------------------------------------------------


def test_enums_render_as_their_values() -> None:
    assert str(Substrate.LINUX_CUDA) == "linux-cuda"
    assert str(ProbeKind.COMMAND) == "command"


def test_probe_renders_with_and_without_argv() -> None:
    assert (
        Probe(ProbeKind.EXECUTABLE, "/usr/bin/brew").render()
        == "executable:/usr/bin/brew"
    )
    assert (
        Probe(ProbeKind.COMMAND, "/usr/bin/xcode-select", ("-p",)).render()
        == "command:/usr/bin/xcode-select -p"
    )


def test_refusal_carries_the_remedy() -> None:
    rendered = Refusal(
        Substrate.APPLE, "apple.package-manager-root", "install Homebrew"
    ).render()
    assert "apple.package-manager-root" in rendered
    assert "remedy: install Homebrew" in rendered
    assert prereqs.render([]) == ""


# --------------------------------------------------------------------------
# the floor as a plan
# --------------------------------------------------------------------------


def test_every_catalogue_member_declares_a_floor() -> None:
    assert set(prereqs.FLOOR) == set(Substrate)


def test_the_authored_floor_is_well_formed() -> None:
    assert prereqs.well_formed() == ()


def test_linux_cuda_extends_the_linux_floor_rather_than_forking_it() -> None:
    cpu = set(prereqs.FLOOR[Substrate.LINUX_CPU])
    assert cpu < set(prereqs.FLOOR[Substrate.LINUX_CUDA])


ROW = Prerequisite(
    "x.id", "something", Probe(ProbeKind.EXECUTABLE, "/usr/bin/x"), "do a thing"
)


def _floor(monkeypatch: pytest.MonkeyPatch, rows: tuple[Prerequisite, ...]) -> None:
    monkeypatch.setattr(prereqs, "FLOOR", dict.fromkeys(Substrate, rows))


@pytest.mark.parametrize(
    ("row", "expected"),
    [
        (dataclasses.replace(ROW, identifier=""), "carries no prerequisite id"),
        (dataclasses.replace(ROW, required_for=""), "does not say what needs it"),
        (dataclasses.replace(ROW, remedy=""), "carries no remedy"),
        (
            dataclasses.replace(ROW, probe=Probe(ProbeKind.COMMAND, "/usr/bin/x")),
            "command probe issues no argv",
        ),
        (
            dataclasses.replace(ROW, probe=Probe(ProbeKind.EXECUTABLE, "brew")),
            "not an absolute path",
        ),
    ],
)
def test_well_formed_reports_each_malformed_row(
    monkeypatch: pytest.MonkeyPatch, row: Prerequisite, expected: str
) -> None:
    _floor(monkeypatch, (row,))
    assert any(expected in problem for problem in prereqs.well_formed())


def test_well_formed_reports_a_substrate_with_no_floor(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _floor(monkeypatch, ())
    assert any("declares no floor" in problem for problem in prereqs.well_formed())


def test_well_formed_reports_a_forked_row(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        prereqs,
        "FLOOR",
        {
            **dict.fromkeys(Substrate, (ROW,)),
            Substrate.WINDOWS: (dataclasses.replace(ROW, remedy="a different remedy"),),
        },
    )
    assert any("different content" in problem for problem in prereqs.well_formed())


def test_a_windows_drive_letter_counts_as_absolute(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _floor(
        monkeypatch,
        (
            dataclasses.replace(
                ROW, probe=Probe(ProbeKind.EXECUTABLE, "C:/Windows/x.exe")
            ),
        ),
    )
    assert prereqs.well_formed() == ()


# --------------------------------------------------------------------------
# the floor on a host
# --------------------------------------------------------------------------


def test_evaluate_refuses_what_was_not_observed() -> None:
    refusals = prereqs.evaluate(Substrate.APPLE, {})
    assert {refusal.identifier for refusal in refusals} == {
        row.identifier for row in prereqs.FLOOR[Substrate.APPLE]
    }


def test_evaluate_is_silent_when_everything_holds() -> None:
    facts = {row.identifier: True for row in prereqs.FLOOR[Substrate.APPLE]}
    assert prereqs.evaluate(Substrate.APPLE, facts) == ()


def test_a_non_refusing_row_never_refuses() -> None:
    refusals = prereqs.evaluate(Substrate.LINUX_CUDA, {})
    assert "linux-cuda.accelerator" not in {refusal.identifier for refusal in refusals}


def test_observe_probe_decides_each_kind(tmp_path: Path, executable) -> None:
    tool = executable("t")
    assert prereqs.observe_probe(Probe(ProbeKind.EXECUTABLE, str(tool))) is True
    assert (
        prereqs.observe_probe(Probe(ProbeKind.EXECUTABLE, str(tmp_path / "no")))
        is False
    )
    ok = executable("ok", "#!/bin/sh\nexit 0\n")
    bad = executable("bad", "#!/bin/sh\nexit 1\n")
    assert prereqs.observe_probe(Probe(ProbeKind.COMMAND, str(ok), ("-p",))) is True
    assert prereqs.observe_probe(Probe(ProbeKind.COMMAND, str(bad), ("-p",))) is False
    assert (
        prereqs.observe_probe(Probe(ProbeKind.COMMAND, str(tmp_path / "no"), ("-p",)))
        is False
    )
    assert (
        prereqs.observe_probe(Probe(ProbeKind.WRITABLE_DEVICE, str(tmp_path))) is True
    )
    assert (
        prereqs.observe_probe(Probe(ProbeKind.WRITABLE_DEVICE, str(tmp_path / "no")))
        is False
    )
    assert prereqs.observe_probe(Probe(ProbeKind.FIRMWARE_FLAG, "Anything")) is False


def test_architecture_probe_accepts_every_alias(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(prereqs.platform, "machine", lambda: "aarch64")
    assert prereqs.observe_probe(Probe(ProbeKind.ARCHITECTURE, "arm64")) is True
    assert prereqs.observe_probe(Probe(ProbeKind.ARCHITECTURE, "amd64")) is False


def test_observe_covers_every_row_of_the_named_substrate() -> None:
    assert set(prereqs.observe(Substrate.WINDOWS)) == {
        row.identifier for row in prereqs.FLOOR[Substrate.WINDOWS]
    }


@pytest.mark.parametrize(
    ("system", "machine", "expected"),
    [
        ("Darwin", "arm64", Substrate.APPLE),
        ("Windows", "AMD64", Substrate.WINDOWS),
    ],
)
def test_detect_classifies_each_host(
    monkeypatch: pytest.MonkeyPatch, system: str, machine: str, expected: Substrate
) -> None:
    monkeypatch.setattr(prereqs.platform, "system", lambda: system)
    monkeypatch.setattr(prereqs.platform, "machine", lambda: machine)
    assert prereqs.detect() is expected


def test_detect_refuses_macos_on_another_architecture(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(prereqs.platform, "system", lambda: "Darwin")
    monkeypatch.setattr(prereqs.platform, "machine", lambda: "x86_64")
    with pytest.raises(PrerequisiteError, match="requires-apple-silicon"):
        prereqs.detect()


def test_detect_promotes_linux_to_cuda_only_with_the_driver(
    monkeypatch: pytest.MonkeyPatch, executable
) -> None:
    monkeypatch.setattr(prereqs.platform, "system", lambda: "Linux")
    monkeypatch.setattr(prereqs.platform, "machine", lambda: "x86_64")
    monkeypatch.setattr(process, "executable_problem", lambda _path: "missing")
    assert prereqs.detect() is Substrate.LINUX_CPU
    monkeypatch.setattr(process, "executable_problem", lambda _path: None)
    assert prereqs.detect() is Substrate.LINUX_CUDA


def test_detect_refuses_an_unsupported_system(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(prereqs.platform, "system", lambda: "Plan9")
    with pytest.raises(PrerequisiteError, match="unsupported-host-system"):
        prereqs.detect()


def test_assert_floor_refuses_a_malformed_plan(monkeypatch: pytest.MonkeyPatch) -> None:
    _floor(monkeypatch, (dataclasses.replace(ROW, remedy=""),))
    with pytest.raises(PrerequisiteError, match="floor-plan-malformed"):
        prereqs.assert_floor(Substrate.APPLE)


def test_assert_floor_returns_the_hosts_refusals() -> None:
    assert prereqs.assert_floor(Substrate.WINDOWS)


# --------------------------------------------------------------------------
# the one acquisition
# --------------------------------------------------------------------------


def test_download_verified_refuses_a_non_https_url(tmp_path: Path) -> None:
    with pytest.raises(PrerequisiteError, match="non-https"):
        prereqs.download_verified("http://x/y", "0" * 64, tmp_path / "t")


def test_download_verified_writes_only_a_vouched_for_asset(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    payload = b"binary contents"
    monkeypatch.setattr(
        prereqs.urllib.request, "urlopen", lambda *_a, **_k: io.BytesIO(payload)
    )
    target = tmp_path / "sub" / "tool"
    observed = prereqs.download_verified(
        "https://x/y", hashlib.sha256(payload).hexdigest(), target
    )
    assert observed == hashlib.sha256(payload).hexdigest()
    assert target.read_bytes() == payload


def test_download_verified_refuses_a_digest_mismatch(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        prereqs.urllib.request, "urlopen", lambda *_a, **_k: io.BytesIO(b"x")
    )
    target = tmp_path / "tool"
    with pytest.raises(PrerequisiteError, match="download-digest-mismatch"):
        prereqs.download_verified("https://x/y", "0" * 64, target)
    assert not target.exists()
    assert list(tmp_path.iterdir()) == []


def test_download_verified_cleans_up_after_a_transport_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def refuse(*_a: object, **_k: object) -> None:
        raise OSError("cut")

    monkeypatch.setattr(prereqs.urllib.request, "urlopen", refuse)
    with pytest.raises(OSError, match="cut"):
        prereqs.download_verified("https://x/y", "0" * 64, tmp_path / "tool")
    assert list(tmp_path.iterdir()) == []


# --------------------------------------------------------------------------
# capacity admission
# --------------------------------------------------------------------------

ENVELOPE: dict[str, object] = {
    "schema": 1,
    "installer": {
        "cpu_count": 1,
        "memory_bytes": 10,
        "tool_install_backing_bytes": 5,
        "steps": [
            {"tool": tool, "installed_bytes": 1, "workspace_bytes": 2}
            for tool in prereqs.EXPECTED_STEP_TOOLS
        ],
    },
    "build": {
        "cpu_count": 1,
        "memory_bytes": 10,
        "scratch_bytes": 3,
        "cache_write_bytes": 4,
    },
}

ROOMY = HostObservation(
    cpu_count=8,
    memory_available_bytes=1 << 40,
    disk_available_bytes=1 << 40,
    fingerprint="f",
)


def test_validated_execution_is_one_shot_and_host_bound() -> None:
    token = ValidatedExecution("f")
    token.consume(ROOMY)
    with pytest.raises(PrerequisiteError, match="already-consumed"):
        token.consume(ROOMY)
    other = ValidatedExecution("f")
    with pytest.raises(PrerequisiteError, match="host-fingerprint-changed"):
        other.consume(dataclasses.replace(ROOMY, fingerprint="g"))


def test_the_authored_envelope_is_accepted() -> None:
    prereqs.assert_authored_envelope(ENVELOPE)


def test_the_shipped_envelope_is_authored_only() -> None:
    root = Path(__file__).resolve().parents[3]
    envelope = narrow.as_mapping(
        narrow.load(root / "pb" / "bootstrap_execution_envelope.json"), "envelope"
    )
    prereqs.assert_authored_envelope(envelope)


def test_an_envelope_with_the_wrong_steps_is_refused() -> None:
    broken = json.loads(json.dumps(ENVELOPE))
    broken["installer"]["steps"] = broken["installer"]["steps"][:2]
    with pytest.raises(PrerequisiteError, match="exact-join-failed"):
        prereqs.assert_authored_envelope(broken)


def test_an_envelope_carrying_resolver_output_is_refused() -> None:
    with pytest.raises(PrerequisiteError, match="carries-resolver-output"):
        prereqs.assert_authored_envelope({**ENVELOPE, "resolved": {"ghc": "9.12.4"}})


def test_required_disk_takes_the_ordered_peak_not_the_sum() -> None:
    # Five steps of 1 installed + 2 workspace: the peak is 4+1+2 = 7, not 15.
    assert prereqs.required_disk(ENVELOPE, "installer") == 7
    assert prereqs.required_disk(ENVELOPE, "build") == 7


def test_required_disk_honours_the_backing_floor() -> None:
    envelope = json.loads(json.dumps(ENVELOPE))
    envelope["installer"]["tool_install_backing_bytes"] = 99
    assert prereqs.required_disk(envelope, "installer") == 99


@pytest.mark.parametrize(
    ("observation", "expected"),
    [
        (dataclasses.replace(ROOMY, cpu_count=0), "installer-cpu-overdraw"),
        (
            dataclasses.replace(ROOMY, memory_available_bytes=0),
            "installer-memory-overdraw",
        ),
        (dataclasses.replace(ROOMY, disk_available_bytes=0), "installer-disk-overdraw"),
    ],
)
def test_validate_envelope_names_the_axis_it_refuses(
    observation: HostObservation, expected: str
) -> None:
    with pytest.raises(PrerequisiteError, match=expected):
        prereqs.validate_envelope(ENVELOPE, observation, "installer")


def test_validate_envelope_admits_a_roomy_host() -> None:
    assert prereqs.validate_envelope(ENVELOPE, ROOMY, "build").fingerprint == "f"


def test_a_malformed_envelope_node_is_named() -> None:
    with pytest.raises(NarrowError, match="expected an object"):
        prereqs.validate_envelope({"installer": []}, ROOMY, "installer")


def test_observe_host_reads_this_machine(tmp_path: Path) -> None:
    observation = prereqs.observe_host(tmp_path)
    assert observation.cpu_count >= 1
    assert observation.disk_available_bytes > 0
    assert len(observation.fingerprint) == 64
    assert prereqs.observe_host(tmp_path).fingerprint == observation.fingerprint


# --------------------------------------------------------------------------
# the toolchain
# --------------------------------------------------------------------------


def test_candidate_paths_are_absolute_and_unversioned(tmp_path: Path) -> None:
    for name, candidates in prereqs.candidate_paths(tmp_path).items():
        assert candidates, name
        for candidate in candidates:
            assert candidate.is_absolute()
            assert not any(part[:1].isdigit() for part in candidate.parts)


def test_first_executable_skips_what_it_cannot_run(tmp_path: Path, executable) -> None:
    tool = executable("t")
    assert prereqs.first_executable([Path("t"), tmp_path / "no", tool]) == tool
    assert prereqs.first_executable([]) is None


def test_preflight_reports_every_member(tmp_path: Path) -> None:
    state = prereqs.preflight(tmp_path)
    assert set(state) == set(prereqs.TOOLCHAIN)
    assert not any(state.values())
    assert "ghc\tabsent\n" in prereqs.render_preflight(state)


def test_toolchain_renders_every_resolved_path() -> None:
    chain = prereqs.Toolchain(*(Path(f"/usr/bin/{name}") for name in prereqs.TOOLCHAIN))
    rendered = chain.render()
    assert all(f"{name}\t/usr/bin/{name}" in rendered for name in prereqs.TOOLCHAIN)


def _laid_down(home: Path, names: tuple[str, ...]) -> None:
    """Place executables where `candidate_paths` looks for them."""
    for name in names:
        target = prereqs.install_target(home, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        target.chmod(0o755)


def test_ensure_toolchain_is_a_no_op_when_everything_is_present(tmp_path: Path) -> None:
    home = tmp_path / "home"
    _laid_down(home, prereqs.TOOLCHAIN)
    ledger = process.Ledger()

    def refuse(*_a: object, **_k: object) -> dict[str, toolchain.Resolved]:
        raise AssertionError("a converged run must resolve nothing")

    chain = prereqs.ensure_toolchain(
        root=tmp_path,
        home=home,
        envelope=ENVELOPE,
        ledger=ledger,
        acquisition=Acquisition(resolve_acquired=refuse, resolve_managed=refuse),
    )
    assert chain.ghc.is_absolute()
    assert ledger.mutations == ()
    assert not (tmp_path / toolchain.RESOLUTION).exists()


def _resolved(name: str) -> toolchain.Resolved:
    return toolchain.Resolved(
        name=name,
        source="github-release",
        version="1.0.0",
        requirement=">=1",
        url=f"https://x/{name}",
        publisher_sha256="0" * 64,
    )


def test_ensure_toolchain_acquires_only_what_is_absent(tmp_path: Path) -> None:
    home = tmp_path / "home"
    downloaded: list[Path] = []

    def download(_url: str, _digest: str, target: Path) -> str:
        downloaded.append(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        target.chmod(0o755)
        return "0" * 64

    def managed(
        root: Path, ghcup: Path, home_dir: Path
    ) -> dict[str, toolchain.Resolved]:
        del root, ghcup, home_dir
        return {name: _resolved(name) for name in ("ghc", "cabal")}

    # `ghcup install --set` is what lays the compiler down, so the stub that stands
    # in for ghcup must do that or the post-condition probe would fail -- which is
    # exactly the property being relied on.
    ghcup_path = prereqs.install_target(home, "ghcup")
    ghc_path = prereqs.install_target(home, "ghc")
    cabal_path = prereqs.install_target(home, "cabal")

    def download_ghcup(url: str, digest: str, target: Path) -> str:
        download(url, digest, target)
        target.write_text(
            f"#!/bin/sh\nmkdir -p {ghc_path.parent}\n"
            f'printf "#!/bin/sh\\nexit 0\\n" > {ghc_path}\n'
            f'printf "#!/bin/sh\\nexit 0\\n" > {cabal_path}\n'
            f"chmod 755 {ghc_path} {cabal_path}\nexit 0\n",
            encoding="utf-8",
        )
        target.chmod(0o755)
        return "0" * 64

    ledger = process.Ledger()
    chain = prereqs.ensure_toolchain(
        root=tmp_path,
        home=home,
        envelope=ENVELOPE,
        ledger=ledger,
        acquisition=Acquisition(
            resolve_acquired=lambda _root: {
                name: _resolved(name) for name in toolchain.ACQUIRED
            },
            resolve_managed=managed,
            download=download_ghcup,
        ),
    )
    assert chain.ghcup == ghcup_path
    assert ledger.mutations
    assert (tmp_path / toolchain.RESOLUTION).is_file()


def test_ensure_toolchain_reports_what_did_not_converge(tmp_path: Path) -> None:
    home = tmp_path / "home"
    _laid_down(home, ("ghcup", "ghc", "cabal"))

    def download(_url: str, _digest: str, _target: Path) -> str:
        return "0" * 64  # lays nothing down, so the post-condition probe must fail

    with pytest.raises(
        PrerequisiteError, match="tool-install-did-not-converge:kind,kubectl"
    ):
        prereqs.ensure_toolchain(
            root=tmp_path,
            home=home,
            envelope=ENVELOPE,
            acquisition=Acquisition(
                resolve_acquired=lambda _root: {
                    name: _resolved(name) for name in toolchain.ACQUIRED
                },
                download=download,
            ),
        )


def test_the_admission_is_spent_on_a_second_reading(tmp_path: Path) -> None:
    readings: list[int] = []

    def observe(path: Path) -> HostObservation:
        del path
        readings.append(1)
        return ROOMY

    prereqs._admit(ENVELOPE, tmp_path, "build", Acquisition(observe=observe))
    assert len(readings) == 2


def test_a_host_that_changes_between_the_two_readings_refuses(tmp_path: Path) -> None:
    seen: list[int] = []

    def observe(path: Path) -> HostObservation:
        del path
        seen.append(1)
        return ROOMY if len(seen) == 1 else dataclasses.replace(ROOMY, fingerprint="g")

    with pytest.raises(PrerequisiteError, match="host-fingerprint-changed"):
        prereqs._admit(ENVELOPE, tmp_path, "build", Acquisition(observe=observe))


def test_every_install_target_is_inside_the_run_home(tmp_path: Path) -> None:
    """Discovery may reach a shared location; installation may not."""
    for name in prereqs.TOOLCHAIN:
        assert prereqs.install_target(tmp_path, name).is_relative_to(tmp_path)


def test_install_target_refuses_a_shared_host_location(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        prereqs,
        "candidate_paths",
        lambda _home: {"kind": (Path("/usr/local/bin/kind"),)},
    )
    with pytest.raises(PrerequisiteError, match="install-target-outside-the-run-home"):
        prereqs.install_target(tmp_path, "kind")


def test_available_memory_uses_the_portable_spelling_where_it_exists(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(prereqs.os, "sysconf_names", {"SC_AVPHYS_PAGES": 1})
    monkeypatch.setattr(prereqs.os, "sysconf", lambda _name: 512)
    assert prereqs.available_memory(4096) == 512 * 4096


def test_available_memory_falls_through_to_vm_stat(
    monkeypatch: pytest.MonkeyPatch, executable
) -> None:
    stub = executable(
        "vm_stat",
        "#!/bin/sh\n"
        "echo 'Mach Virtual Memory Statistics: (page size of 4096 bytes)'\n"
        "echo 'Pages free:                               10.'\n"
        "echo 'Pages active:                           9999.'\n"
        "echo 'Pages inactive:                            5.'\n"
        "echo 'Pages speculative:                         1.'\n",
    )
    monkeypatch.setattr(prereqs.os, "sysconf_names", {})
    monkeypatch.setattr(prereqs, "VM_STAT", stub)
    assert prereqs.available_memory(4096) == 16 * 4096


def test_available_memory_refuses_when_it_cannot_be_read(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, executable
) -> None:
    monkeypatch.setattr(prereqs.os, "sysconf_names", {})
    monkeypatch.setattr(prereqs, "VM_STAT", tmp_path / "absent")
    with pytest.raises(PrerequisiteError, match="memory-observation-unavailable"):
        prereqs.available_memory(4096)
    monkeypatch.setattr(
        prereqs, "VM_STAT", executable("vm_stat", "#!/bin/sh\nexit 1\n")
    )
    with pytest.raises(PrerequisiteError, match="memory-observation-unavailable"):
        prereqs.available_memory(4096)


def test_the_provider_is_asked_once_for_both_managed_tools(tmp_path: Path) -> None:
    """`ghc` and `cabal` come from one ghcup listing, not two."""
    home = tmp_path / "home"
    _laid_down(home, ("kubectl", "kind"))
    asked: list[int] = []

    def managed(
        _root: Path, _ghcup: Path, _home: Path
    ) -> dict[str, toolchain.Resolved]:
        asked.append(1)
        return {name: _resolved(name) for name in ("ghc", "cabal")}

    ghc_path = prereqs.install_target(home, "ghc")
    cabal_path = prereqs.install_target(home, "cabal")

    def download(_url: str, _digest: str, target: Path) -> str:
        target.parent.mkdir(parents=True, exist_ok=True)
        # A ghcup that lays down only the tool it was asked for, so both loop
        # iterations perform an install and the second finds `managed` populated.
        target.write_text(
            f"#!/bin/sh\nmkdir -p {ghc_path.parent}\n"
            f'case "$2" in ghc) t={ghc_path} ;; cabal) t={cabal_path} ;; esac\n'
            'printf "#!/bin/sh\\nexit 0\\n" > "$t"\nchmod 755 "$t"\nexit 0\n',
            encoding="utf-8",
        )
        target.chmod(0o755)
        return "0" * 64

    prereqs.ensure_toolchain(
        root=tmp_path,
        home=home,
        envelope=ENVELOPE,
        acquisition=Acquisition(
            resolve_acquired=lambda _root: {
                name: _resolved(name) for name in toolchain.ACQUIRED
            },
            resolve_managed=managed,
            download=download,
        ),
    )
    assert asked == [1]
