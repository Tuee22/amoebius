import sys
import subprocess

def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: ameobctl <subcommand> [args...]")
        sys.exit(1)

    subcommand = sys.argv[1]
    subcommand_args = sys.argv[2:]

    cmd = [sys.executable, "-m", f"amoebius.cli.{subcommand}"] + subcommand_args
    sys.exit(subprocess.call(cmd))