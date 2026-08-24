import hashlib
import os
import platform
import subprocess
import sys
import urllib.request
from pathlib import Path
GHCUP_VERSION = "0.2.6.2"
GHC_VERSION = "9.12.4"
CABAL_VERSION = "3.16.1.0"
BUILD_TARGET = "exe:amoebius"
def select_artifact(system, machine):
    if system == "Linux" and machine == "x86_64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-linux-ghcup-0.2.6.2", "9ed5da5449b48043a0d17e767c05d2ef585e25a639bb934329496c6d2fad9cf8", "linux-amd64", "ghcup", "")
    if system == "Linux" and machine == "aarch64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2", "65a5f05120288ee4f1a81d28825374b6af317456a351a586adfce90c6dc29e3b", "linux-arm64", "ghcup", "")
    if system == "Darwin" and machine == "arm64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-apple-darwin-ghcup-0.2.6.2", "4e521e008fe0813db6db4b91cfeebd0c44c80c68afb458ea32a1c94cf5c7cc1d", "darwin-arm64", "ghcup", "")
    if system == "Windows" and machine == "AMD64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-mingw64-ghcup-0.2.6.2.exe", "94da902a2853b1de1df509d04da900a05258480759efdb4f654e66956b6f30db", "windows-amd64", "ghcup.exe", ".exe")
    raise RuntimeError("unsupported-platform")
class BootstrapAdapter:
    def repository_root(self):
        return Path(__file__).resolve().parents[1]
    def platform(self):
        return (platform.system(), platform.machine())
    def ensure_ghcup(self, url, digest, target):
        if target.is_file():
            existing_payload = target.read_bytes()
            existing_hash_value = hashlib.sha256(existing_payload)
            existing_digest = existing_hash_value.hexdigest()
            if existing_digest == digest:
                return target
            raise RuntimeError("ghcup-existing-sha256")
        target.parent.mkdir(parents=True, exist_ok=True)
        response = urllib.request.urlopen(url)
        payload = response.read()
        hash_value = hashlib.sha256(payload)
        observed = hash_value.hexdigest()
        if observed != digest:
            raise RuntimeError("ghcup-sha256")
        target.write_bytes(payload)
        target.chmod(448)
        return target
    def environment(self, toolchain):
        home = toolchain / "home"
        cache = toolchain / "cache"
        temporary = toolchain / "tmp"
        home.mkdir(parents=True, exist_ok=True)
        cache.mkdir(parents=True, exist_ok=True)
        temporary.mkdir(parents=True, exist_ok=True)
        environment = {}
        environment["GHCUP_INSTALL_BASE_PREFIX"] = str(toolchain)
        environment["GHCUP_SKIP_UPDATE_CHECK"] = "yes"
        environment["HOME"] = str(home)
        environment["XDG_CACHE_HOME"] = str(cache)
        environment["TMPDIR"] = str(temporary)
        environment["TEMP"] = str(temporary)
        environment["TMP"] = str(temporary)
        return environment
    def run(self, root, arguments, environment):
        subprocess.run(arguments, cwd=root, env=environment, check=True, shell=False)
    def capture(self, root, arguments, environment):
        return subprocess.run(arguments, cwd=root, env=environment, check=True, shell=False, stdout=subprocess.PIPE).stdout
    def handoff(self, binary, arguments):
        os.execv(binary, arguments)
def bootstrap(adapter, arguments):
    root = adapter.repository_root()
    observed_platform = adapter.platform()
    artifact = select_artifact(observed_platform[0], observed_platform[1])
    toolchain = root / ".build" / "toolchain" / artifact[2]
    ghcup_target = toolchain / "bootstrap" / artifact[3]
    ghcup = adapter.ensure_ghcup(artifact[0], artifact[1], ghcup_target)
    environment = adapter.environment(toolchain)
    adapter.run(root, [str(ghcup), "install", "ghc", GHC_VERSION, "--set"], environment)
    adapter.run(root, [str(ghcup), "install", "cabal", CABAL_VERSION, "--set"], environment)
    ghc = toolchain / ".ghcup" / "ghc" / GHC_VERSION / "bin" / ("ghc" + artifact[4])
    cabal = toolchain / ".ghcup" / "bin" / ("cabal" + artifact[4])
    builddir = toolchain / "dist-newstyle"
    store = toolchain / "cabal-store"
    adapter.run(root, [str(cabal), "--store-dir=" + str(store), "build", "--builddir=" + str(builddir), "--with-compiler=" + str(ghc), BUILD_TARGET], environment)
    binary_bytes = adapter.capture(root, [str(cabal), "--store-dir=" + str(store), "list-bin", "--builddir=" + str(builddir), "--with-compiler=" + str(ghc), BUILD_TARGET], environment)
    binary_text = binary_bytes.decode("utf-8")
    binary = binary_text.strip()
    adapter.handoff(binary, [binary] + arguments)
def main():
    adapter = BootstrapAdapter()
    bootstrap(adapter, sys.argv[1:])
if __name__ == "__main__":
    main()
