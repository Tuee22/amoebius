"""Command-line entry point for the amoebius Bootstrap Coordinator."""

from __future__ import annotations

import argparse
import getpass
import json
import sys
from pathlib import Path

from .admin import AdminClient, AdminEndpoint, AdminError

from .bootstrap_coordinator import (
    BootstrapCoordinatorError,
    bootstrap_arguments,
    build_binary,
    ensure_tools,
    handoff,
    home_directory,
    load_envelope,
    preflight,
    repository_root,
)


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(prog="pb")
    subcommands = value.add_subparsers(dest="command", required=True)
    bootstrap = subcommands.add_parser("bootstrap")
    bootstrap.add_argument("--distro", choices=("kind", "rke2"), required=True)
    bootstrap.add_argument("--replicas", type=int, default=1)
    bootstrap.add_argument("--layout", choices=("unified", "split-runtime", "split-image"), default="unified")
    bootstrap.add_argument("--dry-run", action="store_true")
    subcommands.add_parser("preflight")
    admin = subcommands.add_parser("admin")
    admin.add_argument("--endpoint", default="http://127.0.0.1:32034")
    admin.add_argument("--reach", choices=("NodeLocal", "AuthenticatedFabric"), default="NodeLocal")
    admin.add_argument("--password-stdin", action="store_true")
    admin_commands = admin.add_subparsers(dest="admin_command", required=True)
    vault = admin_commands.add_parser("vault")
    vault_commands = vault.add_subparsers(dest="vault_command", required=True)
    vault_commands.add_parser("init")
    vault_commands.add_parser("unseal")
    dhall = admin_commands.add_parser("dhall")
    dhall_commands = dhall.add_subparsers(dest="dhall_command", required=True)
    update = dhall_commands.add_parser("update")
    update.add_argument("source", type=Path)
    update.add_argument("--probes", type=Path, required=True)
    kv = admin_commands.add_parser("kv")
    kv_commands = kv.add_subparsers(dest="kv_command", required=True)
    put = kv_commands.add_parser("put")
    put.add_argument("name")
    put.add_argument("--value-stdin", action="store_true", required=True)
    for verb in ("get", "delete"):
        command = kv_commands.add_parser(verb)
        command.add_argument("name")
    kv_commands.add_parser("list")
    return value


def _password(arguments: argparse.Namespace) -> str:
    if arguments.password_stdin:
        return sys.stdin.readline().rstrip("\n")
    return getpass.getpass("Operator password: ")


def _admin(arguments: argparse.Namespace) -> int:
    client = AdminClient(AdminEndpoint.parse(arguments.endpoint, arguments.reach))
    password = _password(arguments)
    if arguments.admin_command == "vault":
        result = client.vault_init(password) if arguments.vault_command == "init" else client.vault_unseal(password)
    elif arguments.admin_command == "dhall":
        probes = json.loads(arguments.probes.read_text(encoding="utf-8"))
        if not isinstance(probes, list) or any(not isinstance(probe, dict) for probe in probes):
            raise AdminError("admin-client-probes-invalid")
        result = client.dhall_update(password, arguments.source.read_text(encoding="utf-8"), probes)
    elif arguments.kv_command == "put":
        result = client.kv(password, "put", name=arguments.name, value=sys.stdin.read())
    elif arguments.kv_command == "list":
        result = client.kv(password, "list")
    else:
        result = client.kv(password, arguments.kv_command, name=arguments.name)
    print(json.dumps(result, sort_keys=True))
    return 0


def main(argv: list[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    root = repository_root()
    home = home_directory()
    try:
        if arguments.command == "admin":
            return _admin(arguments)
        if arguments.command == "preflight":
            print(preflight(home).render())
            return 0
        binary_arguments = bootstrap_arguments(arguments.distro, arguments.replicas, arguments.layout)
        initial = preflight(home)
        print("pb-preflight:\n" + initial.render(), flush=True)
        envelope = load_envelope(root)
        if arguments.dry_run:
            print("pb-bootstrap-coordinator-plan: " + " ".join(binary_arguments))
            return 0
        tools = ensure_tools(envelope, root, home)
        binary = build_binary(envelope, root, home, tools)
        print(f"pb-handoff: {binary} {' '.join(binary_arguments)}", flush=True)
        handoff(binary, binary_arguments)
    except (AdminError, BootstrapCoordinatorError, OSError, ValueError, json.JSONDecodeError) as problem:
        print(f"pb: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
