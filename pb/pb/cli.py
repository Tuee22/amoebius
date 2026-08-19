"""The closed command surface.

Three properties are the whole point of this module, and each is checked by
`tools/host_assert_cli_gate.py` rather than asserted here.

**The surface is closed and enumerable.** Every command is registered at import,
so the topology is a fact about the module rather than about which code path ran.
An unknown verb resolves to no command and Click answers `No such command`; it is
never guessed at or partially matched.

**The maintainer surface resolves to nothing outside a development checkout**, and
each maintainer command re-checks that in its own body. Two checks rather than one
is deliberate: hiding a command from `--help` is presentation, and a surface whose
only guard is presentation is not a guard at all.

**`update` is the one command that touches the installation.** An installer that
silently updates itself mid-run makes that run's provenance unanswerable, so the
act is explicit and nothing else consults or mutates the installation.
"""

from __future__ import annotations

import getpass
import json
import sys
from pathlib import Path

import click

from pb import bootstrap, narrow, prereqs, process
from pb.admin import AdminClient, AdminEndpoint, AdminError
from pb.bootstrap import BootstrapError
from pb.bootstrap_toolchain import ResolutionError
from pb.narrow import NarrowError
from pb.prereqs import PrerequisiteError
from pb.process import ProcessError

# Every failure class this program can produce on purpose. One of these becomes a
# single actionable line; anything else is a defect and keeps its traceback,
# because swallowing an unexpected exception is how a bug becomes a support ticket.
KNOWN_FAILURES = (
    AdminError,
    BootstrapError,
    NarrowError,
    PrerequisiteError,
    ProcessError,
    ResolutionError,
    OSError,
)

MAINTAINER_COMMANDS = frozenset({"surface"})

PIPX_CANDIDATES = (
    Path("/opt/homebrew/bin/pipx"),
    Path("/usr/local/bin/pipx"),
    Path("/usr/bin/pipx"),
)


def development_checkout() -> Path | None:
    """The checkout `pb` is running from, or `None` when it is an installed copy.

    A maintainer command exists to act on this repository, so the question is not
    "who is the user" but "is there a repository here at all". The two markers are
    the authored package description and the plan suite; an installed distribution
    has neither.
    """
    root = bootstrap.repository_root()
    if (root / "amoebius.cabal").is_file() and (root / "DEVELOPMENT_PLAN").is_dir():
        return root
    return None


def require_maintainer(name: str) -> Path:
    """The second of the two checks. It runs inside the command it protects."""
    root = development_checkout()
    if root is None:
        raise BootstrapError(f"maintainer-command-unavailable:{name}")
    return root


class ClosedGroup(click.Group):
    """A group whose maintainer half does not resolve outside a checkout."""

    def get_command(self, ctx: click.Context, cmd_name: str) -> click.Command | None:
        if cmd_name in MAINTAINER_COMMANDS and development_checkout() is None:
            return None
        return super().get_command(ctx, cmd_name)

    def list_commands(self, ctx: click.Context) -> list[str]:
        return sorted(
            name for name in super().list_commands(ctx) if name not in MAINTAINER_COMMANDS
        )


@click.group(cls=ClosedGroup)
@click.version_option(package_name="amoebius-pb")
def cli() -> None:
    """Assert the host floor, build the amoebius binary, and hand off to it."""


# --------------------------------------------------------------------------
# consumer surface
# --------------------------------------------------------------------------


@cli.command(name="bootstrap")
@click.option("--distro", type=click.Choice(bootstrap.DISTROS), required=True)
@click.option("--replicas", type=int, default=1, show_default=True)
@click.option(
    "--layout", type=click.Choice(bootstrap.LAYOUTS), default="unified", show_default=True
)
@click.option(
    "--dry-run", is_flag=True, help="Print the handoff argv and stop before any mutation."
)
def bootstrap_host(distro: str, replicas: int, layout: str, dry_run: bool) -> None:
    """Assert the floor, ensure the toolchain, build the binary, and hand off."""
    root = bootstrap.repository_root()
    home = root / ".build" / "toolchain" / "runtime" / "home"
    home.mkdir(parents=True, exist_ok=True)
    ledger = process.Ledger()

    substrate = prereqs.detect()
    refusals = prereqs.assert_floor(substrate, ledger=ledger)
    if refusals:
        # A run that continued past a floor refusal would fail later, on a symptom,
        # having already mutated the host. It stops here, and says what clears it.
        raise PrerequisiteError("floor-refused\n" + prereqs.render(refusals))

    click.echo(prereqs.render_preflight(prereqs.preflight(home)), nl=False)
    argv = bootstrap.bootstrap_arguments(distro, replicas, layout)
    if dry_run:
        click.echo("pb-plan: " + " ".join(argv))
        return

    envelope = narrow.as_mapping(
        narrow.load(root / "pb" / "bootstrap_execution_envelope.json"), "envelope"
    )
    prereqs.assert_authored_envelope(envelope)
    tools = prereqs.ensure_toolchain(root=root, home=home, envelope=envelope, ledger=ledger)
    built = bootstrap.build_binary(root=root, cabal=tools.cabal, ghc=tools.ghc, ledger=ledger)
    stable = bootstrap.stable_binary(root)
    copied = bootstrap.install_binary(built, stable, ledger=ledger)
    click.echo(f"pb-publish: {stable} ({'copied' if copied else 'unchanged'})")
    click.echo(f"pb-handoff: {stable} {' '.join(argv)}")
    raise SystemExit(bootstrap.handoff(stable, argv))


@cli.command()
def preflight() -> None:
    """Report which toolchain members are already present, and mutate nothing."""
    root = bootstrap.repository_root()
    home = root / ".build" / "toolchain" / "runtime" / "home"
    click.echo(prereqs.render_preflight(prereqs.preflight(home)), nl=False)


@cli.command()
@click.option(
    "--substrate",
    type=click.Choice([str(member) for member in prereqs.Substrate]),
    default=None,
    help="Report this substrate's floor instead of the detected one.",
)
def floor(substrate: str | None) -> None:
    """Report the per-substrate floor and what, if anything, refuses this host."""
    problems = prereqs.well_formed()
    if problems:
        raise PrerequisiteError("floor-plan-malformed:" + "; ".join(problems))
    selected = prereqs.Substrate(substrate) if substrate else prereqs.detect()
    for row in prereqs.FLOOR[selected]:
        click.echo(f"{row.identifier}\t{row.probe.render()}\t{row.required_for}")
    refusals = prereqs.evaluate(selected, prereqs.observe(selected))
    if refusals:
        click.echo(prereqs.render(refusals), err=True)
        raise SystemExit(1)


@cli.command(
    context_settings={"ignore_unknown_options": True, "allow_interspersed_args": False},
)
@click.argument("arguments", nargs=-1, type=click.UNPROCESSED)
def amoebius(arguments: tuple[str, ...]) -> None:
    """Forward ARGUMENTS verbatim to the built binary.

    Option parsing stops at the first non-option token, so a flag meant for the
    binary is never intercepted here and never has to be escaped.
    """
    stable = bootstrap.stable_binary(bootstrap.repository_root())
    raise SystemExit(bootstrap.handoff(stable, arguments))


@cli.command()
@click.option("--dry-run", is_flag=True, help="Print the reinstall argv and stop.")
def update(dry_run: bool) -> None:
    """Reinstall this distribution from its source of truth.

    This is the only command that acts on the installation rather than on a host or
    a cluster, and it is explicit for that reason.
    """
    root = development_checkout()
    if root is None:
        raise BootstrapError("update-requires-the-source-checkout")
    pipx = prereqs.first_executable(PIPX_CANDIDATES)
    if pipx is None:
        raise PrerequisiteError(
            "pipx-absent: install pipx, which is how this distribution is installed and updated"
        )
    argv = ["install", "--force", str(root / "pb")]
    if dry_run:
        click.echo(f"pb-update: {pipx} {' '.join(argv)}")
        return
    process.run_checked(pipx, argv, kind=process.Kind.MUTATION)


# --------------------------------------------------------------------------
# admin surface
# --------------------------------------------------------------------------


@cli.group()
@click.option("--endpoint", default="http://127.0.0.1:32034", show_default=True)
@click.option(
    "--reach", type=click.Choice(["NodeLocal", "AuthenticatedFabric"]), default="NodeLocal"
)
@click.option("--password-stdin", is_flag=True, help="Read the operator password from stdin.")
@click.pass_context
def admin(ctx: click.Context, endpoint: str, reach: str, password_stdin: bool) -> None:
    """Drive the control-plane daemon's privileged admin surface."""
    ctx.obj = (AdminEndpoint.parse(endpoint, reach), password_stdin)


def _client(ctx: click.Context) -> tuple[AdminClient, str]:
    endpoint, password_stdin = ctx.obj
    password = (
        sys.stdin.readline().rstrip("\n")
        if password_stdin
        else getpass.getpass("Operator password: ")
    )
    return AdminClient(endpoint), password


def _emit(result: object) -> None:
    click.echo(json.dumps(result, sort_keys=True, default=str))


@admin.group()
def vault() -> None:
    """Initialise or unseal the node-local Vault."""


@vault.command(name="init")
@click.pass_context
def vault_init(ctx: click.Context) -> None:
    """Initialise Vault."""
    client, password = _client(ctx)
    _emit(client.vault_init(password))


@vault.command(name="unseal")
@click.pass_context
def vault_unseal(ctx: click.Context) -> None:
    """Unseal Vault."""
    client, password = _client(ctx)
    _emit(client.vault_unseal(password))


@admin.group()
def dhall() -> None:
    """Update the deployed Dhall configuration."""


@dhall.command(name="update")
@click.argument("source", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option(
    "--probes", type=click.Path(exists=True, dir_okay=False, path_type=Path), required=True
)
@click.pass_context
def dhall_update(ctx: click.Context, source: Path, probes: Path) -> None:
    """Apply SOURCE, gated on the readiness probes in --probes."""
    client, password = _client(ctx)
    parsed = narrow.as_sequence(narrow.load(probes), "probes")
    _emit(
        client.dhall_update(
            password,
            source.read_text(encoding="utf-8"),
            [narrow.as_mapping(probe, "probe") for probe in parsed],
        )
    )


@admin.group()
def kv() -> None:
    """Read and write the operator key-value surface."""


@kv.command(name="put")
@click.argument("name")
@click.option("--value-stdin", is_flag=True, required=True, help="Read the value from stdin.")
@click.pass_context
def kv_put(ctx: click.Context, name: str, value_stdin: bool) -> None:
    """Store NAME, reading its value from stdin."""
    client, password = _client(ctx)
    _emit(client.kv(password, "put", name=name, value=sys.stdin.read() if value_stdin else ""))


@kv.command(name="get")
@click.argument("name")
@click.pass_context
def kv_get(ctx: click.Context, name: str) -> None:
    """Read NAME."""
    client, password = _client(ctx)
    _emit(client.kv(password, "get", name=name))


@kv.command(name="delete")
@click.argument("name")
@click.pass_context
def kv_delete(ctx: click.Context, name: str) -> None:
    """Delete NAME."""
    client, password = _client(ctx)
    _emit(client.kv(password, "delete", name=name))


@kv.command(name="list")
@click.pass_context
def kv_list(ctx: click.Context) -> None:
    """List every stored name."""
    client, password = _client(ctx)
    _emit(client.kv(password, "list"))


# --------------------------------------------------------------------------
# maintainer surface
# --------------------------------------------------------------------------


@cli.command(name="surface", hidden=True)
def surface() -> None:
    """Print the command topology, as the parser itself holds it.

    This is what `tools/host_assert_cli_gate.py` joins against the authored oracle.
    The enumeration is produced by walking the live parser rather than by a table
    kept beside it, because a table beside it is a second statement of the surface
    and the two would diverge on the first added command.
    """
    require_maintainer("surface")
    for row in topology():
        click.echo("\t".join(row))


def topology() -> list[tuple[str, str, str]]:
    """`(command path, comma-separated options, visibility)` for the whole tree."""
    rows: list[tuple[str, str, str]] = []

    def walk(command: click.Command, prefix: tuple[str, ...]) -> None:
        path = " ".join(prefix)
        options = sorted(
            option
            for parameter in command.params
            if isinstance(parameter, click.Option)
            for option in parameter.opts
        )
        visibility = "maintainer" if prefix[-1] in MAINTAINER_COMMANDS else "consumer"
        rows.append((path, ",".join(options), visibility))
        if isinstance(command, click.Group):
            for name in sorted(command.commands):
                walk(command.commands[name], (*prefix, name))

    walk(cli, ("pb",))
    return sorted(rows)


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    """Run the CLI, turning a known failure class into one actionable line."""
    try:
        cli.main(args=argv, prog_name="pb", standalone_mode=False)
    except click.ClickException as problem:
        problem.show()
        return problem.exit_code
    except click.exceptions.Abort:
        click.echo("pb: aborted", err=True)
        return 130
    except SystemExit as exit_request:
        return int(exit_request.code or 0)
    except KNOWN_FAILURES as problem:
        click.echo(f"pb: {problem}", err=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
