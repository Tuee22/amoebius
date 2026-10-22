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
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-linux-ghcup-0.2.6.2", "linux-amd64", "ghcup", "")
    if system == "Linux" and machine == "aarch64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-linux-ghcup-0.2.6.2", "linux-arm64", "ghcup", "")
    if system == "Darwin" and machine == "arm64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/aarch64-apple-darwin-ghcup-0.2.6.2", "darwin-arm64", "ghcup", "")
    if system == "Windows" and machine == "AMD64":
        return ("https://downloads.haskell.org/~ghcup/0.2.6.2/x86_64-mingw64-ghcup-0.2.6.2.exe", "windows-amd64", "ghcup.exe", ".exe")
    raise RuntimeError("unsupported-platform")
class BootstrapAdapter:
    def repository_root(self):
        return Path(__file__).resolve().parents[1]
    def platform(self):
        return (platform.system(), platform.machine())
    def ensure_ghcup(self, url, target):
        if target.is_file():
            return target
        target.parent.mkdir(parents=True, exist_ok=True)
        response = urllib.request.urlopen(url)
        payload = response.read()
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
        environment["PATH"] = str(toolchain / ".ghcup" / "bin")
        environment["CABAL_DIR"] = str(cache / "cabal")
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
    toolchain = root / ".build" / "toolchain" / artifact[1]
    ghcup_target = toolchain / "bootstrap" / artifact[2]
    ghcup = adapter.ensure_ghcup(artifact[0], ghcup_target)
    environment = adapter.environment(toolchain)
    ghcup_version_bytes = adapter.capture(root, [str(ghcup), "--version"], environment)
    ghcup_version_text = ghcup_version_bytes.decode("utf-8")
    if ghcup_version_text != "The GHCup Haskell installer, version " + GHCUP_VERSION + "\n":
        raise RuntimeError("ghcup-version")
    adapter.run(root, [str(ghcup), "install", "ghc", GHC_VERSION, "--set"], environment)
    adapter.run(root, [str(ghcup), "install", "cabal", CABAL_VERSION, "--set"], environment)
    ghc = toolchain / ".ghcup" / "ghc" / GHC_VERSION / "bin" / ("ghc" + artifact[3])
    cabal = toolchain / ".ghcup" / "bin" / ("cabal" + artifact[3])
    ghc_version_bytes = adapter.capture(root, [str(ghc), "--numeric-version"], environment)
    ghc_version_text = ghc_version_bytes.decode("utf-8")
    if ghc_version_text != GHC_VERSION + "\n":
        raise RuntimeError("ghc-version")
    builddir = toolchain / "dist-newstyle"
    store = toolchain / "cabal-store"
    adapter.run(root, [str(cabal), "--store-dir=" + str(store), "build", "--builddir=" + str(builddir), "--with-compiler=" + str(ghc), "--offline", "--jobs=1", BUILD_TARGET], environment)
    binary_bytes = adapter.capture(root, [str(cabal), "--store-dir=" + str(store), "list-bin", "--builddir=" + str(builddir), "--with-compiler=" + str(ghc), BUILD_TARGET], environment)
    binary_text = binary_bytes.decode("utf-8")
    binary = binary_text.strip()
    adapter.handoff(binary, [binary] + arguments)
def main():
    adapter = BootstrapAdapter()
    bootstrap(adapter, sys.argv[1:])
if __name__ == "__main__":
    main()
