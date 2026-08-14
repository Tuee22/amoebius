#!/usr/bin/env python3
"""The authored negative corpus for the external-attestation store.

Each entry is a run bundle a conforming store must refuse, together with the locus the
refusal must happen at. `tools/attestation.py` runs them in its self-test and
`tools/artifact_policy_selftest.py` reuses them as the `r9` mutant, so a store that
silently starts accepting a malformed bundle reddens both.

**This module deliberately names a plan-tree evidence path.** A bundle that carries an
undeclared key is only a negative if the key is the kind a gate might really add, and a
generated evidence path beneath an authored root is exactly that mistake. Keeping the
body here rather than inside the adapter is what confines the `r5` exemption of
repository-layout doctrine section 3.6 to twenty visible lines: the adapter itself stays
fully scanned, and the adapter is where a real write-location defect would hide.
"""

from __future__ import annotations

import copy


def negative_corpus(positive: dict) -> list[tuple[str, dict, str]]:
    """(name, bundle a conforming store must refuse, the locus it must be refused at)."""
    corpus: list[tuple[str, dict, str]] = []

    missing = copy.deepcopy(positive)
    missing.pop("commit")
    corpus.append(("missing_commit", missing, "schema"))

    unbound_source = copy.deepcopy(positive)
    unbound_source["source_digest"] = ""
    corpus.append(("unbound_source", unbound_source, "schema"))

    empty = copy.deepcopy(positive)
    empty["checks"] = []
    corpus.append(("no_checks", empty, "schema"))

    unbound_contract = copy.deepcopy(positive)
    unbound_contract["contract_digest"] = ""
    corpus.append(("unbound_contract", unbound_contract, "schema"))

    stray = copy.deepcopy(positive)
    stray["evidence_path"] = "DEVELOPMENT_PLAN/evidence/phase_00"
    corpus.append(("extra_key", stray, "schema"))

    return corpus
