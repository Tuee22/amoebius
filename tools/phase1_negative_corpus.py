#!/usr/bin/env python3
"""The authored negative corpus for the Phase-1 provenance scan.

Every entry below is a synthetic build configuration that carries exactly one seeded
defect, plus a positive control that carries none. `tools/phase1_gate.py` materializes
them under `gen/test-corpora/phase_01/` and requires each to turn its own check red and no
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
    "  post-checkout-command: git apply ../../../patches/supernova_ghc_9_12.patch\n"
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
            "../../../patches/supernova_ghc_9_12.patch",
            "../../../test-results/upstream.patch",
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
