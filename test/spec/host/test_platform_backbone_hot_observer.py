from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from platform_backbone_hot_observer import hot_bytes, verify_coverage, HotObservationFailure

class HotObserverTests(unittest.TestCase):
    def observation(self):
        return {"brokerStats": {"currentLedgerSize": 7, "ledgers": [
            {"ledgerId": 1, "size": 11, "offloaded": True},
            {"ledgerId": 2, "size": 0, "offloaded": False}]},
            "ledgers": [
                {"ledgerId": 1, "bytes": 11, "offloaded": True, "bookkeeperMetadataExists": True, "deletionCredited": False,
                 "bookkeeperClosed": True, "bookkeeperLengthBytes": 11},
                {"ledgerId": 2, "bytes": 7, "offloaded": False, "bookkeeperMetadataExists": True, "deletionCredited": False,
                 "bookkeeperClosed": False, "bookkeeperLengthBytes": 0}], "hotTierBytes": 18}

    def test_active_ledger_and_offloaded_but_present_are_both_charged(self):
        self.assertEqual(hot_bytes(self.observation()), 18)

    def test_only_metadata_absence_releases_offloaded_extent(self):
        row=self.observation()
        row["ledgers"][0].update(bookkeeperMetadataExists=False, deletionCredited=True, bookkeeperClosed=False, bookkeeperLengthBytes=-1)
        row["hotTierBytes"]=7
        self.assertEqual(hot_bytes(row), 7)

    def test_dropped_active_ledger_counter_is_rejected(self):
        row=self.observation();row["ledgers"][1]["bytes"]=0;row["hotTierBytes"]=11
        with self.assertRaisesRegex(HotObservationFailure,"ledger-counter-drift"):hot_bytes(row)

    def test_unobserved_lookup_is_rejected(self):
        row=self.observation();row["ledgers"].pop()
        with self.assertRaisesRegex(HotObservationFailure,"incomplete-bookkeeper"):hot_bytes(row)

    def test_missing_live_ledger_is_not_a_deletion_credit(self):
        row=self.observation();row["ledgers"][1]["bookkeeperMetadataExists"]=False
        with self.assertRaisesRegex(HotObservationFailure,"live-ledger-missing"):hot_bytes(row)

    def test_broker_size_cannot_replace_actual_closed_ledger_length(self):
        row=self.observation();row["ledgers"][0]["bookkeeperLengthBytes"]=10
        with self.assertRaisesRegex(HotObservationFailure,"bookkeeper-length-drift"):hot_bytes(row)

    def test_sampling_covers_both_producer_boundaries(self):
        rows = [{"observationStartedSeconds": begin, "observationFinishedSeconds": begin + .1}
                for begin in (0, 1, 2, 3)]
        self.assertEqual(verify_coverage(rows, .2, 2.9),
                         {"maximumSampleGapSeconds": max(1.1, 2.1-1, 3.1-2), "maximumObservationDurationSeconds": max(.1, 1.1-1, 2.1-2, 3.1-3)})
        with self.assertRaisesRegex(HotObservationFailure, "coverage-incomplete"):
            verify_coverage(rows[:-1], .2, 2.9)
        with self.assertRaisesRegex(HotObservationFailure, "coverage-incomplete"):
            verify_coverage(rows[1:], .2, 2.9)

    def test_stalled_lookup_and_large_gap_reject(self):
        for rows in ([{"observationStartedSeconds": 0, "observationFinishedSeconds": .1},
                      {"observationStartedSeconds": 1, "observationFinishedSeconds": 4}],
                     [{"observationStartedSeconds": 0, "observationFinishedSeconds": .1},
                      {"observationStartedSeconds": 4, "observationFinishedSeconds": 4.1}]):
            with self.assertRaisesRegex(HotObservationFailure, "sampling-gap-exceeded"):
                verify_coverage(rows, .2, .9)

    def test_completion_times_cannot_hide_broker_snapshot_gap(self):
        rows = [{"observationStartedSeconds": begin, "observationFinishedSeconds": finish}
                for begin, finish in [(0,.1),(.8,.9),(1,2.9),(4.7,4.8),(6.6,6.7)]]
        with self.assertRaisesRegex(HotObservationFailure, "sampling-gap-exceeded"):
            verify_coverage(rows, .2, 6.5)

if __name__ == "__main__":unittest.main()
