#!/usr/bin/env python3
"""The authored negative corpora for the Phase-1 provenance and resolution scans.

Every entry below is a synthetic build configuration that carries exactly one seeded
defect, plus a positive control that carries none. `tools/toolchain_spike_gate.py` materializes
them under `.build/test-corpora/phase_01/` and requires each to turn its own check red and no
other — the single-defect discipline of `development_plan_standards.md` section M clause 8.

**This file deliberately contains the very strings the scan rejects**: a developer-home
path, an archive checksum beside a URL, and a fixed dependency revision. That is what
makes it a corpus rather than a description of one, and it is why the scanner declares
this module a corpus seed and steps over it. The exemption is one named file whose whole
purpose is visible in twenty lines, which is the same trade
`artifact_policy.LEDGER_SHAPE_EXEMPT` already makes for the hand-written ledger corpus.
Keeping the bodies inside the gate instead would have meant exempting the gate, and the
gate is exactly where a real resolved path would hide.
"""

from __future__ import annotations

import json

_POSITIVE = (
    "packages:\n  ./probe/probe.cabal\n\n"
    "source-repository-package\n"
    "  type: git\n"
    "  location: https://example.invalid/upstream.git\n"
    "  tag: master\n"
    "  post-checkout-command: apply_supernova_patch patches/supernova_ghc_9_12.patch\n"
)

# name -> (filename, the check it must turn red, body)
NEGATIVES: dict[str, tuple[str, str, str]] = {
    "_positive": ("cabal.project", "", _POSITIVE),
    "resolved-path": (
        "cabal.project",
        "resolved-path",
        _POSITIVE.replace(
            "packages:\n",
            "with-compiler: /home/developer/.ghcup/ghc/9.12.4/bin/ghc\n\npackages:\n",
        ),
    ),
    "fixed-commit": (
        "cabal.project",
        "fixed-commit",
        _POSITIVE.replace("  tag: master\n", "  tag: 602409a18f47a38541ba24f5e885199efd383f48\n"),
    ),
    # The historical defect this seeds was a project consuming a patch from the plan
    # tree's ignored evidence directory. That exact path is not used here, because a gate
    # script naming a migration root is itself a write-location finding — so the seed uses
    # a different ignored root. The check is path-agnostic: it asks whether the token is
    # ignored, not which ignored root it sits under.
    #
    # The root also may not begin with a dot. Path tokens are normalised with `strip("./")`
    # to shed the leading `../` of a relative reference, and that same strip eats the
    # leading dot of `.secrets`, turning the token into a path that is not ignored and a
    # negative that silently stops firing.
    "source-closure": (
        "cabal.project",
        "source-closure",
        _POSITIVE.replace(
            "patches/supernova_ghc_9_12.patch",
            "test/fixture/__pycache__/ignored-upstream.patch",
        ),
    ),
    "patch-under-authored-root": (
        "cabal.project",
        "patch-under-authored-root",
        _POSITIVE.replace("supernova_ghc_9_12.patch", "absent_upstream.patch"),
    ),
    "integrity-pin": (
        "requirements.json",
        "integrity-pin",
        json.dumps(
            {
                "protoc": {
                    "version": "35.1",
                    "url": "https://example.invalid/protoc.zip",
                    "sha256": "a45cda0989c17dd950db55f6fbe1e5814c50fda08e87aa422980ac1f89dddbbc",
                }
            },
            indent=2,
        )
        + "\n",
    ),
}


# --------------------------------------------------------------------------
# resolution behaviour
# --------------------------------------------------------------------------
#
# Resolution had no seeded negatives at all: every check was a positive, so a resolver that
# silently accepted the wrong thing would have passed. These four drive the two *pure*
# selectors — `toolchain.choose_release` over an authored release feed, and
# `toolchain.choose_offer` over an authored provider listing — so no host, no network, and
# no download is involved, and the outcome is the same on every machine.
#
# The architecture negative is the one that matters most. A publisher that ships only
# `amd64` must produce a refusal, never the `amd64` asset: an emulated binary is exactly
# what section S clause 15 exists to reject, and a resolver that picks one hands the gate a
# translated tool while reporting success.

_RELEASE_SPEC = {
    "project": "example/tool",
    "asset_pattern": r"^tool-[0-9.]+-{platform}\.tar\.gz$",
    "platform_map": {"linux-amd64": "x86_64-linux", "darwin-arm64": "aarch64-darwin"},
    "requirement": ">=2 <3",
}


def _release(tag: str, *assets: str) -> dict:
    return {"tag_name": tag, "assets": [{"name": name, "browser_download_url": ""} for name in assets]}


_FEED = [
    _release("2.4.0", "tool-2.4.0-x86_64-linux.tar.gz", "tool-2.4.0-aarch64-darwin.tar.gz"),
    _release("2.3.0", "tool-2.3.0-x86_64-linux.tar.gz", "tool-2.3.0-aarch64-darwin.tar.gz"),
]

# name -> (selector, the check it must turn red, fixture)
#   selector "release"  drives toolchain.choose_release(name, spec, releases, token)
#   selector "offer"    drives toolchain.choose_offer(name, offers, requirement)
# An empty check id marks a positive control, which must resolve rather than refuse; its
# `expect` field is what the selector has to return.
RESOLUTION_NEGATIVES: dict[str, tuple[str, str, dict]] = {
    "_positive-release": (
        "release",
        "",
        {"spec": _RELEASE_SPEC, "releases": _FEED, "token": "darwin-arm64",
         "expect": "tool-2.4.0-aarch64-darwin.tar.gz"},
    ),
    "_positive-offer": (
        "offer",
        "",
        {"offers": ["9.10.1", "9.12.2", "9.12.4"], "requirement": ">=9.12 <9.13", "expect": "9.12.4"},
    ),
    # The provider is reachable and supplies nothing: an absent tool with no install plan
    # behind it, which must refuse rather than fall through to a host lookup.
    "resolution-absent": (
        "offer",
        "resolution-absent",
        {"offers": [], "requirement": ">=9.12 <9.13"},
    ),
    # The provider supplies the tool, at versions the authored requirement excludes.
    "resolution-out-of-range": (
        "offer",
        "resolution-out-of-range",
        {"offers": ["9.6.7", "9.8.4", "9.10.1"], "requirement": ">=9.12 <9.13"},
    ),
    # The publisher builds the tool, and not for this machine. The feed deliberately still
    # carries the complementary architecture's asset, so a resolver that reached for it
    # would succeed here and be caught.
    "resolution-architecture": (
        "release",
        "resolution-architecture",
        {"spec": _RELEASE_SPEC, "releases": _FEED, "token": "linux-arm64"},
    ),
}
