{-# LANGUAGE OverloadedStrings #-}

-- | The runner-area oracle executable. It depends on no @amoebius@ library. It
-- reads the rows the runner suite wrote and prints a ledger derived from the
-- literals below; it exits non-zero when any row is red.
module Main (main) where

import Control.Monad (unless)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  input <- case arguments of
    [path] -> do
      directory <- doesDirectoryExist path
      pure (if directory then path <> "/runner.tsv" else path)
    _ -> pure ".build/runs/phase-00/runner/runner.tsv"
  contents <- TextIO.readFile input
  let rows = map (Text.splitOn "\t") (filter (not . Text.null) (Text.lines contents))
      ledger = judge rows
  mapM_ (TextIO.putStrLn . renderRow) ledger
  unless (all rowGreen ledger) exitFailure

data LedgerRow = LedgerRow {rowName :: Text, rowGreen :: Bool, rowObserved :: Text}

renderRow :: LedgerRow -> Text
renderRow row = Text.intercalate "\t" [rowName row, if rowGreen row then "green" else "red", rowObserved row]

judge :: [[Text]] -> [LedgerRow]
judge rows =
  [ expect "refusal.legal-ordinary" "ok" (value "refusal" "legal-ordinary")
  , expect "refusal.kernel-subject" "SUBJECT-NOT-SHIPPED: Amoebius.Validation.Runner" (value "refusal" "kernel-subject")
  , expect "refusal.missing-binary-fact" "BINARY-FACT-MISSING" (value "refusal" "missing-binary-fact")
  , expect "refusal.barrier-without-spine" "SPINE-FACT-MISSING" (value "refusal" "barrier-without-spine")
  , expect "refusal.seed-with-binary-fact" "SEED-CARRIES-BINARY-FACT" (value "refusal" "seed-with-binary-fact")
  , expect "refusal.hardware-substrate-ordinary" "HARDWARE-BEFORE-BARRIER: linux-cpu" (value "refusal" "hardware-substrate-ordinary")
  , expect "refusal.hardware-role-without-substrate" "SUBSTRATE-ABSENT" (value "refusal" "hardware-role-without-substrate")
  , expect "refusal.stage-not-subject" "STAGE-MODULE-NOT-SUBJECT: Amoebius.Dsl.Other" (value "refusal" "stage-not-subject")
  , expect "refusal.duplicate-case" "CASE-DUPLICATE: a" (value "refusal" "duplicate-case")
  , expect "refusal.legal-seed" "ok" (value "refusal" "legal-seed")
  , expect "render.lines" "11" (value "render" "legal-ordinary")
  , expect "verify.closure" "dsl-core,vocabulary" (value "verify" "closure")
  , expect "verify.legal" "ok" (value "verify" "legal")
  , expect "verify.outside-closure" "SUBJECT-NOT-SHIPPED: Amoebius.Parked.Thing (parked)" (value "verify" "outside-closure")
  , expect "verify.not-in-package" "SUBJECT-NOT-IN-PACKAGE: Amoebius.Nowhere" (value "verify" "not-in-package")
  , expect "verify.oracle-depends-on-product" "ORACLE-DEPENDS-ON-PRODUCT: oracle-leaky" (value "verify" "oracle-depends-on-product")
  , expectPrefix "verify.oracle-cpp" "ORACLE-CPP: " (value "verify" "oracle-cpp")
  , expect "verify.oracle-missing" "ORACLE-MISSING: oracle-absent" (value "verify" "oracle-missing")
  , expect "verify.suite-missing" "SUITE-MISSING: no-suite" (value "verify" "suite-missing")
  , expect "loci.constant-flip" "6,12,17,18,22" (value3 "loci" "constant-flip")
  , expect "loci.boundary-shift" "9" (value3 "loci" "boundary-shift")
  , expect "loci.branch-swap" "12" (value3 "loci" "branch-swap")
  , expect "loci.field-drop" "18" (value3 "loci" "field-drop")
  , expect "loci.list-truncation" "22" (value3 "loci" "list-truncation")
  , expect "sample.deterministic" "equal" (value "sample" "deterministic")
  , expect "sample.seed-sensitive" "differs" (value "sample" "seed-sensitive")
  , expect "sample.size" "4" (value "sample" "size")
  , expect "sample.cap" "9" (value "sample" "cap")
  , expect "apply.witness" "changed" (value "apply" "witness")
  , expect "apply.line-6" "limit = 4" (value "apply" "line-6")
  , expect "apply.stale-locus" "refused" (value "apply" "stale-locus")
  , expect "kill.killed" "3" (value "kill" "killed")
  , expect "kill.viable" "4" (value "kill" "viable")
  , expect "kill.stillborn" "2" (value "kill" "stillborn")
  , expect "kill.ratio" "3 % 4" (value "kill" "ratio")
  , expect "kill.rows" "8" (value "kill" "rows")
  , expect "hygiene.fixture.kernel-lines" "13" (value "hygiene" "fixture.kernel-lines")
  , expect "hygiene.fixture.cap" "5" (value "hygiene" "fixture.cap")
  , expect "hygiene.fixture.cpp" "2" (value "hygiene" "fixture.cpp")
  , expect "hygiene.fixture.run-modules" "[\"src/validation-kernel/Amoebius/Validation/FooRun/Internal.hs\"]" (value "hygiene" "fixture.run-modules")
  , expect "hygiene.fixture.phase-literals" "1" (value "hygiene" "fixture.phase-literals")
  , expect "hygiene.fixture.phase-tables" "1" (value "hygiene" "fixture.phase-tables")
  , expect "hygiene.fixture.duplicates" "Substrate" (value "hygiene" "fixture.duplicates")
  , expect "hygiene.fixture.product-duplicates" "Substrate" (value "hygiene" "fixture.product-duplicates")
  , expect "hygiene.fixture.problems" "5" (value "hygiene" "fixture.problems")
  , expect "hygiene.clean.green" "True" (value "hygiene" "clean.green")
  , expect "hygiene.clean.cap" "14000" (value "hygiene" "clean.cap")
  , expect "capture.all-green" "True" (value "capture" "all-green")
  , expect "capture.one-red" "False" (value "capture" "one-red")
  , expect "capture.empty-observation" "False" (value "capture" "empty-observation")
  , expect "capture.reordered" "False" (value "capture" "reordered")
  , expect "capture.rows" "40" (value "capture" "rows")
  , expect "capture.categories" "18" (value "capture" "categories")
  , expect "preflight.clean" "" (value "preflight" "clean")
  , expect "preflight.status-surface-dirty" "StatusSurfaceDirty" (value "preflight" "status-surface-dirty")
  , expect "preflight.predecessor-not-committed" "PredecessorNotCommitted" (value "preflight" "predecessor-not-committed")
  , expect "preflight.status-without-receipt" "STATUS-WITHOUT-RECEIPT" (value "preflight" "status-without-receipt")
  , expect "preflight.verifier-diverged" "KERNEL-VERIFIER-DIVERGED" (value "preflight" "verifier-diverged")
  , expect "preflight.governance-unaccepted" "GOVERNANCE-UNACCEPTED" (value "preflight" "governance-unaccepted")
  , expect "preflight.frozen-finding" "GOVERNANCE-UNACCEPTED" (value "preflight" "frozen-finding")
  , expect "preflight.hardware-before-barrier" "HARDWARE-BEFORE-BARRIER" (value "preflight" "hardware-before-barrier")
  , expect "preflight.hardware-after-barrier" "" (value "preflight" "hardware-after-barrier")
  , expect "preflight.substrate-absent" "SUBSTRATE-ABSENT" (value "preflight" "substrate-absent")
  , expect "preflight.kernel-over-budget" "KernelOverBudget" (value "preflight" "kernel-over-budget")
  , expect "preflight.spec-weakened" "SPEC-WEAKENED" (value "preflight" "spec-weakened")
  , expect "preflight.spec-unchanged" "" (value "preflight" "spec-unchanged")
  , expect "preflight.generation-absent" "GENERATION-ABSENT" (value "preflight" "generation-absent")
  , expect "preflight.weakened-detail" "case unbound-need" (value "preflight" "weakened-detail")
  , expect "store.write-seed" "ok" (value "store" "write-seed")
  , expect "store.write-receipt" "ok" (value "store" "write-receipt")
  , expect "store.seed-roundtrip" "equal" (value "store" "seed-roundtrip")
  , expect "store.receipt-roundtrip" "equal" (value "store" "receipt-roundtrip")
  , expect "store.reset-receipt" "kept-beside-pass" (value "store" "reset-receipt")
  , expect "store.latest-generation" "DL-0007" (value "store" "latest-generation")
  , expect "store.other-generation" "absent" (value "store" "other-generation")
  , expect "store.tampered-receipt" "1" (value "store" "tampered-receipt")
  , expect "store.restored-receipt" "2" (value "store" "restored-receipt")
  , expect "store.generation-directory" "/s/generation-abcdef0123456789" (value "store" "generation-directory")
  , expect "status.recorded-frontier" "Just ActiveNotValidated" (value "status" "recorded-frontier")
  , expect "status.surface-digest-stable" "changed" (value "status" "surface-digest-stable")
  , expect "status.patched-files" "3" (value "status" "patched-files")
  , expect "status.after-tracker" "0=✅ Done;1=🔄 Active — NOT VALIDATED;2=⏸️ Blocked — NOT VALIDATED" (value "status" "after-tracker")
  , expect "status.after-phase-0" "✅ Done." (value "status" "after-phase-0")
  , expect "status.after-sprints" "1=## Sprint 0.1: Governance surface ✅|**Status**: Done;2=## Sprint 0.2: Checker reconciliation ✅|**Status**: Done" (value "status" "after-sprints")
  , expect "status.after-frontier" "Just ActiveNotValidated" (value "status" "after-frontier")
  , expect "status.doc-check-findings" "DOC-HONESTY-OWED-DONE" (value "status" "doc-check-findings")
  , expect "tripwire.agent-shell" "CLAUDECODE,AI_AGENT" (value "tripwire" "agent-shell")
  , expect "tripwire.human-shell" "" (value "tripwire" "human-shell")
  , expect "tripwire.markers" "CLAUDECODE,CLAUDE_CODE_SESSION_ID,CLAUDE_CODE_CHILD_SESSION,CLAUDE_PID,AI_AGENT" (value "tripwire" "markers")
  , expect "package.product-closure-validator-free" "True" (value "package" "product-closure-validator-free")
  , expect "package.verifier-links-runner" "True" (value "package" "verifier-links-runner")
  , expectAtMost "package.flags" 20 (value "package" "flags")
  , expect "package.executables" "amoebius,amoebius-validate" (value "package" "executables")
  ]
 where
  value kind key = case [rest | (k : name : rest) <- rows, k == kind, name == key] of
    ((observed : _) : _) -> observed
    _ -> "absent"
  value3 kind key = case [rest | (k : name : rest) <- rows, k == kind, name == key] of
    ((_ : lines' : _) : _) -> lines'
    _ -> "absent"

expect :: Text -> Text -> Text -> LedgerRow
expect name expected observed = LedgerRow name (expected == observed) observed

expectAtMost :: Text -> Int -> Text -> LedgerRow
expectAtMost name limit observed = LedgerRow name (maybe False (<= limit) (readInt observed)) observed
 where
  readInt text = case reads (Text.unpack text) :: [(Int, String)] of
    [(value, "")] -> Just value
    _ -> Nothing

expectPrefix :: Text -> Text -> Text -> LedgerRow
expectPrefix name prefix observed = LedgerRow name (prefix `Text.isPrefixOf` observed) observed
