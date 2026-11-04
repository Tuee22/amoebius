"""Publisher checks precede installation, including cached downloaded archives."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import toolchain

# The published SHA-256 "abc" vector, authored independently of the resolver.
ABC_SHA256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

class PublisherChecksumTests(unittest.TestCase):
    def setUp(self):
        temporary = ROOT / ".build/tmp/toolchain-checksum-tests"
        temporary.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=temporary)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "tool"
        self.archive.write_bytes(b"abc")
        self.asset = {"name": "tool", "browser_download_url": "https://publisher.invalid/tool"}
        self.checksum = {"name": "tool.sha256", "browser_download_url": "https://publisher.invalid/tool.sha256"}
        self.release = {"tag_name": "v1.2", "assets": [self.asset, self.checksum]}
        self.spec = {"project": "publisher/project", "requirement": ">=1 <2",
                     "checksum_asset": "{asset}.sha256", "install_name": "verified-tool"}
        self.output = self.root / "bin"
        self.patches = [
            patch.object(toolchain, "select_release", return_value=(self.release, self.asset)),
            patch.object(toolchain, "materialize", return_value=self.archive),
            patch.object(toolchain, "TOOL_BIN", self.output),
        ]
        for current in self.patches:
            current.start()
            self.addCleanup(current.stop)

    def resolve(self, checksum):
        with patch.object(toolchain, "fetch", return_value=checksum.encode("ascii")):
            return toolchain.resolve_github_release("tool", self.spec)

    def test_standalone_publisher_checksum(self):
        result = self.resolve(ABC_SHA256 + "\n")
        self.assertEqual(result["publisherChecksum"]["sha256"], ABC_SHA256)
        self.assertEqual((self.output / "verified-tool").read_bytes(), b"abc")

    def test_named_checksum_selects_only_its_asset(self):
        result = self.resolve("0" * 64 + "  another-tool\n" + ABC_SHA256 + " *tool\n")
        self.assertEqual(result["publisherChecksum"]["sha256"], ABC_SHA256)

    def assert_denied_without_install(self, checksum):
        with self.assertRaisesRegex(toolchain.ResolutionError, "does not match the publisher checksum"):
            self.resolve(checksum)
        self.assertFalse(self.output.exists())

    def test_wrong_digest_rejects_before_install(self):
        self.assert_denied_without_install("0" * 64 + "  tool\n")

    def test_foreign_filename_cannot_authorize_cached_archive(self):
        self.assert_denied_without_install(ABC_SHA256 + "  foreign\n")

    def test_ambiguous_rows_reject(self):
        self.assert_denied_without_install((ABC_SHA256 + "  tool\n") * 2)

    def test_missing_publisher_checksum_rejects(self):
        self.release["assets"] = [self.asset]
        with self.assertRaisesRegex(toolchain.ResolutionError, "missing or ambiguous"):
            self.resolve(ABC_SHA256)
        self.assertFalse(self.output.exists())

if __name__ == "__main__":
    unittest.main()
