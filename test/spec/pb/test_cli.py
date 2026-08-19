"""The closed topology: what resolves, what refuses, and what the surface reports."""

from __future__ import annotations

import io
import json
from pathlib import Path

import click
import pytest
from click.testing import CliRunner
from pb import bootstrap, cli, prereqs, process
from pb.admin import AdminError
from pb.bootstrap import BootstrapError
from pb.prereqs import PrerequisiteError


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


# --------------------------------------------------------------------------
# the surface itself
# --------------------------------------------------------------------------


def test_the_topology_is_enumerable_and_rooted_at_pb() -> None:
    rows = cli.topology()
    paths = {path for path, _options, _visibility in rows}
    assert "pb" in paths
    assert "pb bootstrap" in paths
    assert "pb admin kv put" in paths
    assert rows == sorted(rows)


def test_every_maintainer_row_is_marked_as_one() -> None:
    marked = {
        path.split()[-1]
        for path, _options, visibility in cli.topology()
        if visibility == "maintainer"
    }
    assert marked == set(cli.MAINTAINER_COMMANDS)


def test_the_bootstrap_options_are_the_authored_ones() -> None:
    options = {path: opts for path, opts, _visibility in cli.topology()}
    assert options["pb bootstrap"] == "--distro,--dry-run,--layout,--replicas"


def test_an_unknown_verb_is_a_refusal_not_a_guess(runner: CliRunner) -> None:
    result = runner.invoke(cli.cli, ["nosuchverb"])
    assert result.exit_code != 0
    assert "No such command" in result.output


def test_a_prefix_of_a_real_verb_is_still_unknown(runner: CliRunner) -> None:
    assert "No such command" in runner.invoke(cli.cli, ["boot"]).output


def test_the_maintainer_surface_is_absent_from_help(runner: CliRunner) -> None:
    """The command *names*, not the whole page: a summary line may use the word."""
    output = runner.invoke(cli.cli, ["--help"]).output
    listed = {
        line.split()[0]
        for line in output.split("Commands:", 1)[1].splitlines()
        if line.startswith("  ") and line.split()
    }
    assert listed.isdisjoint(cli.MAINTAINER_COMMANDS)
    assert "preflight" in listed


def test_the_maintainer_surface_resolves_inside_the_checkout(runner: CliRunner) -> None:
    assert runner.invoke(cli.cli, ["surface"]).exit_code == 0


def test_the_maintainer_surface_does_not_resolve_outside_one(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(cli, "development_checkout", lambda: None)
    assert "No such command" in runner.invoke(cli.cli, ["surface"]).output


def test_the_maintainer_body_rechecks_its_own_authority(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Hiding a command is presentation; the body's own check is the guard."""
    monkeypatch.setattr(cli, "development_checkout", lambda: None)
    with pytest.raises(BootstrapError, match="maintainer-command-unavailable"):
        cli.require_maintainer("surface")


def test_development_checkout_needs_both_markers(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(bootstrap, "repository_root", lambda: tmp_path)
    assert cli.development_checkout() is None
    (tmp_path / "amoebius.cabal").write_text("", encoding="utf-8")
    assert cli.development_checkout() is None
    (tmp_path / "DEVELOPMENT_PLAN").mkdir()
    assert cli.development_checkout() == tmp_path


# --------------------------------------------------------------------------
# consumer commands
# --------------------------------------------------------------------------


def test_preflight_reports_and_mutates_nothing(runner: CliRunner) -> None:
    result = runner.invoke(cli.cli, ["preflight"])
    assert result.exit_code == 0
    assert "ghc\t" in result.output


def test_floor_lists_a_named_substrate(runner: CliRunner) -> None:
    result = runner.invoke(cli.cli, ["floor", "--substrate", "windows"])
    assert result.exit_code == 1
    assert "windows.firmware-virtualization" in result.output


def test_floor_uses_the_detected_substrate_by_default(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(prereqs, "detect", lambda: prereqs.Substrate.APPLE)
    monkeypatch.setattr(
        prereqs,
        "observe",
        lambda substrate: {row.identifier: True for row in prereqs.FLOOR[substrate]},
    )
    result = runner.invoke(cli.cli, ["floor"])
    assert result.exit_code == 0
    assert "apple.silicon" in result.output


def test_floor_refuses_a_malformed_plan(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(prereqs, "well_formed", lambda: ("x: broken",))
    result = runner.invoke(cli.cli, ["floor", "--substrate", "apple"])
    assert isinstance(result.exception, PrerequisiteError)


def test_bootstrap_dry_run_stops_before_any_mutation(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(prereqs, "detect", lambda: prereqs.Substrate.APPLE)
    monkeypatch.setattr(prereqs, "assert_floor", lambda _s, **_k: ())
    result = runner.invoke(cli.cli, ["bootstrap", "--distro=kind", "--dry-run"])
    assert result.exit_code == 0
    assert (
        "pb-plan: bootstrap --distro=kind --replicas=1 --layout=unified"
        in result.output
    )


def test_bootstrap_stops_at_a_floor_refusal(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A run that continued past a refusal would fail later, having already mutated."""
    refusal = prereqs.Refusal(
        prereqs.Substrate.APPLE, "apple.package-manager-root", "install brew"
    )
    monkeypatch.setattr(prereqs, "detect", lambda: prereqs.Substrate.APPLE)
    monkeypatch.setattr(prereqs, "assert_floor", lambda _s, **_k: (refusal,))
    reached: list[str] = []
    monkeypatch.setattr(
        prereqs, "ensure_toolchain", lambda **_k: reached.append("ensure")
    )
    result = runner.invoke(cli.cli, ["bootstrap", "--distro=kind"])
    assert isinstance(result.exception, PrerequisiteError)
    assert "install brew" in str(result.exception)
    assert reached == []


def test_bootstrap_publishes_then_hands_off(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch, executable
) -> None:
    built = executable("amoebius")
    handed: list[tuple[Path, tuple[str, ...]]] = []
    monkeypatch.setattr(prereqs, "detect", lambda: prereqs.Substrate.APPLE)
    monkeypatch.setattr(prereqs, "assert_floor", lambda _s, **_k: ())
    monkeypatch.setattr(
        prereqs,
        "ensure_toolchain",
        lambda **_k: prereqs.Toolchain(*(built for _ in prereqs.TOOLCHAIN)),
    )
    monkeypatch.setattr(bootstrap, "build_binary", lambda **_k: built)
    monkeypatch.setattr(bootstrap, "install_binary", lambda *_a, **_k: True)
    monkeypatch.setattr(
        bootstrap,
        "handoff",
        lambda binary, argv: handed.append((binary, tuple(argv))) or 0,
    )
    result = runner.invoke(cli.cli, ["bootstrap", "--distro=rke2", "--replicas=2"])
    assert result.exit_code == 0
    assert "pb-publish" in result.output
    assert handed[0][1] == (
        "bootstrap",
        "--distro=rke2",
        "--replicas=2",
        "--layout=unified",
    )


def test_amoebius_forwards_verbatim(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    handed: list[tuple[str, ...]] = []
    monkeypatch.setattr(
        bootstrap, "handoff", lambda _binary, argv: handed.append(tuple(argv)) or 0
    )
    result = runner.invoke(cli.cli, ["amoebius", "deploy", "--flag", "-x", "value"])
    assert result.exit_code == 0
    assert handed == [("deploy", "--flag", "-x", "value")]


def test_update_refuses_outside_the_checkout(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(cli, "development_checkout", lambda: None)
    result = runner.invoke(cli.cli, ["update"])
    assert isinstance(result.exception, BootstrapError)


def test_update_reports_an_absent_pipx(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(cli, "development_checkout", lambda: tmp_path)
    monkeypatch.setattr(cli, "PIPX_CANDIDATES", (tmp_path / "absent",))
    result = runner.invoke(cli.cli, ["update"])
    assert isinstance(result.exception, PrerequisiteError)
    assert "pipx-absent" in str(result.exception)


def test_update_dry_run_prints_the_reinstall(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, executable
) -> None:
    monkeypatch.setattr(cli, "development_checkout", lambda: tmp_path)
    monkeypatch.setattr(cli, "PIPX_CANDIDATES", (executable("pipx"),))
    result = runner.invoke(cli.cli, ["update", "--dry-run"])
    assert result.exit_code == 0
    assert "install --force" in result.output


def test_update_reinstalls_the_distribution(
    runner: CliRunner, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, recorder
) -> None:
    pipx = recorder.make("pipx")
    monkeypatch.setattr(cli, "development_checkout", lambda: tmp_path)
    monkeypatch.setattr(cli, "PIPX_CANDIDATES", (pipx,))
    assert runner.invoke(cli.cli, ["update"]).exit_code == 0
    assert recorder.argv() == [f"install --force {tmp_path / 'pb'}"]


# --------------------------------------------------------------------------
# admin commands
# --------------------------------------------------------------------------


class _Client:
    def __init__(self) -> None:
        self.calls: list[tuple[str, tuple[object, ...]]] = []

    def _record(self, name: str, *arguments: object) -> dict[str, object]:
        self.calls.append((name, arguments))
        return {"ok": name}

    def vault_init(self, password: str) -> dict[str, object]:
        return self._record("vault_init", password)

    def vault_unseal(self, password: str) -> dict[str, object]:
        return self._record("vault_unseal", password)

    def dhall_update(
        self, password: str, source: str, probes: object
    ) -> dict[str, object]:
        return self._record("dhall_update", password, source, probes)

    def kv(self, password: str, verb: str, **fields: object) -> dict[str, object]:
        return self._record("kv", password, verb, fields)


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> _Client:
    fake = _Client()
    monkeypatch.setattr(cli, "_client", lambda _ctx: (fake, "pw"))
    return fake


@pytest.mark.parametrize(
    ("argv", "expected"),
    [
        (["admin", "vault", "init"], "vault_init"),
        (["admin", "vault", "unseal"], "vault_unseal"),
        (["admin", "kv", "list"], "kv"),
        (["admin", "kv", "get", "k"], "kv"),
        (["admin", "kv", "delete", "k"], "kv"),
    ],
)
def test_each_admin_verb_reaches_the_client(
    runner: CliRunner, client: _Client, argv: list[str], expected: str
) -> None:
    result = runner.invoke(cli.cli, argv)
    assert result.exit_code == 0, result.output
    assert client.calls[0][0] == expected


def test_kv_put_reads_its_value_from_stdin(runner: CliRunner, client: _Client) -> None:
    result = runner.invoke(
        cli.cli, ["admin", "kv", "put", "k", "--value-stdin"], input="secret"
    )
    assert result.exit_code == 0
    assert client.calls[0][1][2]["value"] == "secret"


def test_dhall_update_narrows_its_probe_document(
    runner: CliRunner, client: _Client, tmp_path: Path
) -> None:
    source = tmp_path / "s.dhall"
    source.write_text("let x = 1 in x", encoding="utf-8")
    probes = tmp_path / "p.json"
    probes.write_text(json.dumps([{"name": "ready"}]), encoding="utf-8")
    result = runner.invoke(
        cli.cli, ["admin", "dhall", "update", str(source), "--probes", str(probes)]
    )
    assert result.exit_code == 0
    assert client.calls[0][1][2] == [{"name": "ready"}]


def test_the_admin_group_parses_its_endpoint(runner: CliRunner) -> None:
    result = runner.invoke(cli.cli, ["admin", "--endpoint", "https://x", "kv", "list"])
    assert isinstance(result.exception, AdminError)


def test_the_client_helper_reads_a_password_from_stdin(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    endpoint = cli.AdminEndpoint.parse("http://127.0.0.1:1", "NodeLocal")
    context = click.Context(cli.cli)
    context.obj = (endpoint, True)
    monkeypatch.setattr(cli.sys, "stdin", io.StringIO("pw\n"))
    _client_object, password = cli._client(context)
    assert password == "pw"


def test_the_client_helper_prompts_when_not_given_stdin(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    endpoint = cli.AdminEndpoint.parse("http://127.0.0.1:1", "NodeLocal")
    context = click.Context(cli.cli)
    context.obj = (endpoint, False)
    monkeypatch.setattr(cli.getpass, "getpass", lambda _prompt: "typed")
    _client_object, password = cli._client(context)
    assert password == "typed"


# --------------------------------------------------------------------------
# the friendly-error layer
# --------------------------------------------------------------------------


def test_main_turns_a_known_failure_into_one_line(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(
        prereqs,
        "detect",
        lambda: (_ for _ in ()).throw(
            PrerequisiteError("unsupported-host-system:plan9")
        ),
    )
    assert cli.main(["bootstrap", "--distro=kind"]) == 1
    captured = capsys.readouterr()
    assert captured.err.strip() == "pb: unsupported-host-system:plan9"
    assert "Traceback" not in captured.err


def test_main_reports_a_click_usage_error(capsys: pytest.CaptureFixture[str]) -> None:
    assert cli.main(["nosuchverb"]) == 2
    assert "No such command" in capsys.readouterr().err


def test_main_returns_zero_on_success(capsys: pytest.CaptureFixture[str]) -> None:
    assert cli.main(["preflight"]) == 0
    assert "ghc\t" in capsys.readouterr().out


def test_main_propagates_an_explicit_exit(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(prereqs, "well_formed", lambda: ())
    monkeypatch.setattr(prereqs, "detect", lambda: prereqs.Substrate.WINDOWS)
    assert cli.main(["floor"]) == 1


def test_main_reports_an_abort(monkeypatch: pytest.MonkeyPatch, capsys) -> None:
    def abort(*_a: object, **_k: object) -> None:
        raise click.exceptions.Abort

    monkeypatch.setattr(cli.cli, "main", abort)
    assert cli.main([]) == 130
    assert "aborted" in capsys.readouterr().err


def test_the_choke_point_is_the_only_route_to_a_child() -> None:
    """`update` runs pipx, and it does so through `pb.process`, by absolute path."""
    assert cli.process is process
