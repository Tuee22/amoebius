#!/usr/bin/env python3
"""Derive hot occupancy from raw broker extents and BookKeeper lookups.

The active ledger is the greatest id in Pulsar's ordered ledger map. Its
persisted ledger-info size is not updated until close, so charge the separate
currentLedgerSize too. Offload alone never proves BookKeeper deletion.
"""
from __future__ import annotations

from typing import Any
import math


class HotObservationFailure(ValueError):
    pass


def verify_coverage(samples: list[dict[str, Any]], producer_started: float,
                    producer_finished: float) -> dict[str, float]:
    """Bound the sampled claim, including SDK stalls and the entire producer.

    This establishes two-second observation coverage; it does not infer
    unsampled occupancy or a worst-case asynchronous offload latency.
    """
    def timestamp(value: Any) -> float:
        if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
            raise HotObservationFailure("hot-observer-invalid-time")
        return float(value)

    begin, end = timestamp(producer_started), timestamp(producer_finished)
    intervals = [(timestamp(row["observationStartedSeconds"]), timestamp(row["observationFinishedSeconds"]))
                 for row in samples]
    if len(intervals) < 2 or end <= begin or intervals[0][1] > begin or intervals[-1][0] < end:
        raise HotObservationFailure("hot-observer-producer-coverage-incomplete")
    durations = [finish - start for start, finish in intervals]
    gaps = [following[1] - previous[0] for previous, following in zip(intervals, intervals[1:])]
    if any(duration < 0 or duration > 2 for duration in durations) or any(gap <= 0 or gap > 2 for gap in gaps):
        raise HotObservationFailure("hot-observer-sampling-gap-exceeded")
    if any(following[0] < previous[1] for previous, following in zip(intervals, intervals[1:])):
        raise HotObservationFailure("hot-observer-time-order-invalid")
    return {"maximumSampleGapSeconds": max(gaps), "maximumObservationDurationSeconds": max(durations)}


def hot_bytes(observation: dict[str, Any], *, verify_counter: bool = True) -> int:
    stats = observation["brokerStats"]
    raw = stats["ledgers"]
    lookups = observation["ledgers"]
    current = stats["currentLedgerSize"]
    if type(current) is not int or current < 0 or not raw or len(raw) > 128:
        raise HotObservationFailure("hot-observer-invalid-current-extent")
    ids = [item["ledgerId"] for item in raw]
    if any(type(identity) is not int or identity < 0 for identity in ids) or ids != sorted(set(ids)):
        raise HotObservationFailure("hot-observer-invalid-ledger-identities")
    observed = {item["ledgerId"]: item for item in lookups}
    if len(observed) != len(lookups) or set(observed) != set(ids):
        raise HotObservationFailure("hot-observer-incomplete-bookkeeper-lookups")
    result = 0
    for ledger in raw:
        identity, extent = ledger["ledgerId"], ledger["size"]
        if type(extent) is not int or extent < -1 or type(ledger["offloaded"]) is not bool:
            raise HotObservationFailure("hot-observer-invalid-ledger-extent")
        exists = observed[identity]["bookkeeperMetadataExists"]
        if type(exists) is not bool:
            raise HotObservationFailure("hot-observer-unauthenticated-bookkeeper-result")
        if not exists and not ledger["offloaded"]:
            raise HotObservationFailure("hot-observer-live-ledger-missing")
        if observed[identity].get("bookkeeperClosed") and exists and extent > 0:
            if observed[identity].get("bookkeeperLengthBytes") != extent:
                raise HotObservationFailure("hot-observer-bookkeeper-length-drift")
        charged = max(0, extent, current if identity == ids[-1] else 0)
        credited = ledger["offloaded"] and not exists
        if verify_counter and (observed[identity].get("bytes") != charged
            or observed[identity].get("deletionCredited") is not credited):
            raise HotObservationFailure("hot-observer-ledger-counter-drift")
        if not credited:
            result += charged
    if verify_counter and observation.get("hotTierBytes") != result:
        raise HotObservationFailure("hot-observer-total-counter-drift")
    return result
