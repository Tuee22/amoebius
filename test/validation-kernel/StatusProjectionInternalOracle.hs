{-# LANGUAGE OverloadedStrings #-}

module StatusProjectionInternalOracle (
    runStatusProjectionInternalOracle,
) where

import Amoebius.Validation.PhaseIdentity (
    allPhaseIdentities,
    phaseIdentityOrdinal,
    phaseIdentityPath,
 )
import Amoebius.Validation.SourceClosure.Internal (
    GitObjectFormat (GitObjectSha256),
    IndexEntry (..),
    IndexMode (RegularFile),
    SourceSnapshot (..),
    TrackedEntry (..),
    computeBlobObjectId,
    computeSourceSnapshotIdentity,
 )
import Amoebius.Validation.StatusProjection.Internal (
    JournalCutpoint (..),
    StatusAtomicCutpoint (..),
    statusProjectionInternalTestAtomicReplaceAtCutpoint,
    statusProjectionInternalTestAtomicReplaceExact,
    statusProjectionInternalTestDiscoverJournal,
    statusProjectionInternalTestFinalizeJournal,
    statusProjectionInternalTestJournalAtCutpoint,
    statusProjectionInternalTestJournalName,
    statusProjectionInternalTestMarkerReplacement,
    statusProjectionInternalTestMixedPhases,
    statusProjectionInternalTestPrepare,
    statusProjectionInternalTestRecoveryClassification,
    statusProjectionInternalTestRecoveryRebind,
    statusProjectionInternalTestRecoveryStates,
    statusProjectionInternalTestWritePlan,
 )
import Control.Monad (forM_, unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Numeric (showHex)
import PhaseContractOracle (phaseContractValidCorpus)
import System.Directory (createDirectory, createDirectoryLink, listDirectory)
import System.FilePath (takeDirectory, takeExtension, takeFileName, (</>))
import System.IO.Temp (withSystemTempDirectory)

runStatusProjectionInternalOracle :: IO ()
runStatusProjectionInternalOracle =
    withSystemTempDirectory "amoebius-status-projection-atomic" $ \root -> do
        let target = root </> "status.md"
        ByteString.writeFile target "before"
        applied <- statusProjectionInternalTestAtomicReplaceExact target "before" "after"
        afterApply <- ByteString.readFile target
        idempotent <- statusProjectionInternalTestAtomicReplaceExact target "before" "after"
        ByteString.writeFile target "independent"
        conflict <- statusProjectionInternalTestAtomicReplaceExact target "after" "before"
        afterConflict <- ByteString.readFile target
        targetDirectoryEntries <- listDirectory root
        exchangeDirectoryEntries <- listDirectory (root </> ".build" </> "runs" </> "status-projection-exchanges")
        cutpointProblems <- fmap concat (mapM (runAtomicCutpoint root) [minBound .. maxBound])
        journalCutpointProblems <- fmap concat (mapM (runJournalCutpoint root) [minBound .. maxBound])
        journalPruningProblems <- runJournalPruning root
        journalDiscoveryProblems <- runJournalDiscovery root
        journalReplacementProblems <- runJournalReplacement root
        journalFinalizationProblems <- runJournalFinalizationFailure root
        directoryAdversaryProblems <- runDirectoryAdversaries root
        emittedPlanProblems <- runEmittedPlanChecks root
        finishDiagnostics
            "StatusProjectionInternalOracle"
            ( problems
                <> expectEqual "the fd-relative atomic replacement succeeds" (Right ()) applied
                <> expectEqual "the replacement installs exact bytes" "after" afterApply
                <> expectEqual "an already-installed exact postimage is idempotent" (Right ()) idempotent
                <> expectLeft "an independently changed target refuses rollback" conflict
                <> expectEqual "a refused rollback preserves independent bytes" "independent" afterConflict
                <> expectEqual
                    "the tracked target directory contains no source-adjacent exchange temporary"
                    [".build", "status.md"]
                    (sort targetDirectoryEntries)
                <> expectEqual
                    "successful and refused exchanges clear their ignored transaction names"
                    []
                    exchangeDirectoryEntries
                <> cutpointProblems
                <> journalCutpointProblems
                <> journalPruningProblems
                <> journalDiscoveryProblems
                <> journalReplacementProblems
                <> journalFinalizationProblems
                <> directoryAdversaryProblems
                <> emittedPlanProblems
                <> journalNameProblems
            )
  where
    problems = case statusProjectionInternalTestPrepare 0 preimage of
        Left findings -> ["the canonical Phase-0 projection was refused: " <> show findings]
        Right files ->
            let mixedSnapshot = snapshotWithImages preimage files [expectedTrackerPath]
                conflictSnapshot = snapshotWithConflict preimage files expectedTrackerPath
                canonicalClassification = statusProjectionInternalTestRecoveryClassification preimage
                mixedClassification = statusProjectionInternalTestRecoveryClassification mixedSnapshot
                conflictClassification = statusProjectionInternalTestRecoveryClassification conflictSnapshot
             in expectEqual
                    "the projection has the exact three-file nonterminal target set"
                    expectedPaths
                    (map first files)
                    <> expectEqual
                        "an all-before frontier is not an interrupted mixed write"
                        []
                        (statusProjectionInternalTestMixedPhases preimage)
                    <> expectEqual
                        "an all-before frontier has a compiled recovery classification"
                        (Just ["before", "before", "before"])
                        (lookup 0 (statusProjectionInternalTestRecoveryStates preimage))
                    <> expectEqual
                        "an all-before frontier is structurally canonical without semantic preparation"
                        "canonical"
                        (classificationKind canonicalClassification)
                    <> expectEqual
                        "exactly one compiled phase explains a one-file-applied crash"
                        [0]
                        (statusProjectionInternalTestMixedPhases mixedSnapshot)
                    <> expectEqual
                        "the shared classifier retains the exact unique mixed phase"
                        ("unique-mixed", [0])
                        (classificationKindAndPhases mixedClassification)
                    <> expectEqual
                        "the shared analysis retains non-selected derivation failures beside a unique mixed result"
                        True
                        (not (null (classificationFailures mixedClassification)))
                    <> expectEqual
                        "an all-after frontier is not demoted from ignored state"
                        []
                        (statusProjectionInternalTestMixedPhases (snapshotWithImages preimage files expectedPaths))
                    <> expectEqual
                        "a within-file conflict cannot be treated as an interrupted atomic replacement"
                        []
                        (statusProjectionInternalTestMixedPhases conflictSnapshot)
                    <> expectEqual
                        "a within-file conflict is unclassifiable rather than clean"
                        []
                        (statusProjectionInternalTestRecoveryStates conflictSnapshot)
                    <> expectEqual
                        "the shared classifier distinguishes conflict from an empty clean result"
                        "conflict"
                        (classificationKind conflictClassification)
                    <> expectEqual
                        "the shared classifier retains failed phase derivations for conflict diagnostics"
                        True
                        (not (null (classificationFailures conflictClassification)))
                    <> invalidUtf8RecoveryProblems preimage
    preimage = snapshotFromDocuments "/synthetic/status-projection" canonicalCorpus

runEmittedPlanChecks :: FilePath -> IO [String]
runEmittedPlanChecks root = do
    let sentinel = root </> "tracked-sentinel.md"
        snapshot = snapshotFromDocuments root canonicalCorpus
    ByteString.writeFile sentinel "tracked-before"
    first <- statusProjectionInternalTestWritePlan 0 snapshot
    case first of
        Left findings -> pure ["the emitted-only canonical projection was refused: " <> show findings]
        Right path -> do
            bytes <- ByteString.readFile path
            second <- statusProjectionInternalTestWritePlan 0 snapshot
            sentinelAfter <- ByteString.readFile sentinel
            ByteString.writeFile path "tampered-plan"
            collision <- statusProjectionInternalTestWritePlan 0 snapshot
            tampered <- ByteString.readFile path
            pure
                ( expectEqual
                    "the emitted plan uses the exact ignored phase directory"
                    (root </> ".build" </> "runs" </> "phase-00" </> "status-projection-plans")
                    (takeDirectory path)
                    <> expectEqual
                        "the emitted plan uses a content-addressed projection leaf"
                        (64 + length (".projection" :: String))
                        (length (takeFileName path))
                    <> [ "the emitted plan does not use the canonical schema frame"
                       | not ("34:amoebius-status-projection-plan-v1" `ByteString.isPrefixOf` bytes)
                       ]
                    <> [ "the emitted plan omits a projected status target: " <> expected
                       | expected <- expectedPaths
                       , not (TextEncoding.encodeUtf8 (Text.pack expected) `ByteString.isInfixOf` bytes)
                       ]
                    <> expectEqual "identical plan emission is idempotent" (Right path) second
                    <> expectEqual "plan emission leaves a tracked sentinel unchanged" "tracked-before" sentinelAfter
                    <> expectLeft "a changed file at the content address refuses replacement" collision
                    <> expectEqual "a refused collision preserves the independently changed plan" "tampered-plan" tampered
                )

journalNameProblems :: [String]
journalNameProblems =
    expectEqual
        "an exact lowercase digest pending leaf is admitted"
        (True, False)
        (statusProjectionInternalTestJournalName (replicate 64 'a' <> ".journal"))
        <> expectEqual
            "an exact lowercase digest finalized leaf is admitted"
            (False, True)
            (statusProjectionInternalTestJournalName (replicate 64 'f' <> ".rolled-back"))
        <> expectEqual
            "an uppercase digest is not a finalized journal leaf"
            (False, False)
            (statusProjectionInternalTestJournalName (replicate 64 'A' <> ".applied"))
        <> expectEqual
            "a short digest is not a pending journal leaf"
            (False, False)
            (statusProjectionInternalTestJournalName (replicate 63 'a' <> ".journal"))
        <> expectEqual
            "a lowercase non-hex digest is not a finalized journal leaf"
            (False, False)
            (statusProjectionInternalTestJournalName (replicate 63 'a' <> "g.applied"))
        <> expectEqual
            "a suffixed finalized-looking name is not a finalized journal leaf"
            (False, False)
            (statusProjectionInternalTestJournalName (replicate 64 'a' <> ".applied.extra"))

invalidUtf8RecoveryProblems :: SourceSnapshot -> [String]
invalidUtf8RecoveryProblems preimage =
    case statusProjectionInternalTestPrepare 0 invalidPreimage of
        Left findings ->
            [ "structural recovery decoded unrelated invalid UTF-8 Markdown: "
                <> show findings
            ]
        Right files ->
            let mixed = snapshotWithImages invalidPreimage files [expectedTrackerPath]
                conflict = snapshotWithConflict invalidPreimage files expectedTrackerPath
                independentlyChanged = snapshotWithRawEntry mixed "UNRELATED.bin" "changed"
             in expectEqual
                    "unrelated invalid UTF-8 Markdown does not prevent structural mixed-frontier analysis"
                    ("unique-mixed", [0])
                    (classificationKindAndPhases (statusProjectionInternalTestRecoveryClassification mixed))
                    <> expectEqual
                        "an unchanged full recapture rebinds the exact unique mixed candidate"
                        ("unique-mixed", True)
                        (statusProjectionInternalTestRecoveryRebind mixed mixed)
                    <> expectEqual
                        "an all-before recapture cannot retain mixed recovery authority"
                        ("canonical", False)
                        (statusProjectionInternalTestRecoveryRebind mixed invalidPreimage)
                    <> expectEqual
                        "a conflicting recapture cannot retain mixed recovery authority"
                        ("conflict", False)
                        (statusProjectionInternalTestRecoveryRebind mixed conflict)
                    <> expectEqual
                        "an independently changed full snapshot cannot rebind an otherwise identical mixed frontier"
                        ("unique-mixed", False)
                        (statusProjectionInternalTestRecoveryRebind mixed independentlyChanged)
  where
    invalidPreimage = snapshotWithRawEntry preimage "UNRELATED.md" (ByteString.pack [255])

runAtomicCutpoint :: FilePath -> StatusAtomicCutpoint -> IO [String]
runAtomicCutpoint root cutpoint = do
    let directory = root </> ("cutpoint-" <> show (fromEnum cutpoint))
        target = directory </> "status.md"
        scratch = directory </> ".build" </> "runs" </> "status-projection-exchanges"
    createDirectory directory
    ByteString.writeFile target "before"
    result <- statusProjectionInternalTestAtomicReplaceAtCutpoint cutpoint target "before" "after"
    targetBytes <- ByteString.readFile target
    scratchEntries <- listDirectory scratch
    let expectedTarget =
            if cutpoint == StatusTemporaryDurable
                then "before"
                else "after"
        expectedScratchCount =
            if cutpoint == StatusDisplacedUnlinked
                then 0
                else 1
    pure
        ( expectLeft ("the injected cutpoint refuses: " <> show cutpoint) result
            <> expectEqual
                ("the injected cutpoint retains its exact target state: " <> show cutpoint)
                expectedTarget
                targetBytes
            <> expectEqual
                ("the injected cutpoint retains only its expected ignored quarantine: " <> show cutpoint)
                expectedScratchCount
                (length scratchEntries)
        )

runJournalCutpoint :: FilePath -> JournalCutpoint -> IO [String]
runJournalCutpoint root cutpoint = do
    let directory = root </> ("journal-cutpoint-" <> show (fromEnum cutpoint))
    createDirectory directory
    result <- statusProjectionInternalTestJournalAtCutpoint cutpoint directory
    entries <- fmap sort (listDirectory directory)
    let pending = replicate 64 'a' <> ".journal"
        finalized = replicate 64 'a' <> ".applied"
    let expectedEntries = case cutpoint of
            JournalTemporaryDurable -> []
            JournalPendingLinked -> [pending]
            JournalPendingDurable -> [pending]
            JournalFinalLinked -> [finalized, pending]
            JournalFinalDurable -> [finalized, pending]
            JournalPendingUnlinked -> [finalized]
            JournalFinalizedDurable -> [finalized]
    pure
        ( expectLeft ("the injected journal cutpoint refuses: " <> show cutpoint) result
            <> expectEqual
                ("the injected journal cutpoint leaves only its exact recoverable residue: " <> show cutpoint)
                expectedEntries
                entries
        )

runJournalPruning :: FilePath -> IO [String]
runJournalPruning root = do
    let directory = root </> "journal-pruning"
    createDirectory directory
    forM_ [0 :: Int .. 69] $ \ordinal ->
        ByteString.writeFile
            (directory </> canonicalFinalizedLeaf ordinal)
            "bounded-finalized-journal"
    result <- statusProjectionInternalTestJournalAtCutpoint JournalFinalizedDurable directory
    entries <- listDirectory directory
    let finalized =
            [ entry
            | entry <- entries
            , takeExtension entry == ".applied" || takeExtension entry == ".rolled-back"
            ]
    pure
        ( expectLeft "the post-prune durability cutpoint is injected" result
            <> expectEqual "finalized journal retention is bounded" 64 (length finalized)
            <> expectEqual
                "bounded pruning retains the current typed outcome record"
                True
                ((replicate 64 'a' <> ".applied") `elem` finalized)
        )

runJournalDiscovery :: FilePath -> IO [String]
runJournalDiscovery root = do
    let directory = root </> "journal-discovery"
        malformedDirectory = root </> "journal-malformed"
        boundedDirectory = root </> "journal-bounded"
        pending = replicate 64 'b' <> ".journal"
    createDirectory directory
    createDirectory malformedDirectory
    createDirectory boundedDirectory
    forM_ [0 :: Int .. 69] $ \ordinal ->
        ByteString.writeFile
            (directory </> canonicalFinalizedLeaf ordinal)
            "discovery-finalized-journal"
    ByteString.writeFile (directory </> pending) "pending-journal"
    discovered <- statusProjectionInternalTestDiscoverJournal directory
    entries <- listDirectory directory
    let finalized = filter ((== (False, True)) . statusProjectionInternalTestJournalName) entries
    ByteString.writeFile (malformedDirectory </> "short.applied") "malformed-finalized-journal"
    malformed <- statusProjectionInternalTestDiscoverJournal malformedDirectory
    forM_ [0 :: Int .. 1024] $ \ordinal ->
        ByteString.writeFile (boundedDirectory </> ("unrelated-" <> show ordinal)) "entry"
    overLimit <- statusProjectionInternalTestDiscoverJournal boundedDirectory
    pure
        ( expectEqual "descriptor discovery returns only exact pending markers" (Right [pending]) discovered
            <> expectEqual "recovery discovery also bounds finalized journal retention" 64 (length finalized)
            <> expectLeft "a recognized suffix with a noncanonical digest fails discovery closed" malformed
            <> expectLeft "descriptor enumeration refuses before retaining an unbounded directory" overLimit
        )

runJournalReplacement :: FilePath -> IO [String]
runJournalReplacement root = do
    let directory = root </> "journal-replacement"
        marker = directory </> (replicate 64 'a' <> ".journal")
    createDirectory directory
    cleared <- statusProjectionInternalTestMarkerReplacement directory
    observed <- ByteString.readFile marker
    pure
        ( expectLeft "a replaced captured pending marker cannot be removed" cleared
            <> expectEqual "identity-safe marker removal preserves the replacement" "replaced-marker-bytes" observed
        )

runJournalFinalizationFailure :: FilePath -> IO [String]
runJournalFinalizationFailure root = do
    let directory = root </> "journal-finalization-failure"
        pending = replicate 64 'a' <> ".journal"
        finalized = replicate 64 'a' <> ".applied"
    createDirectory directory
    ByteString.writeFile (directory </> finalized) "independent-final-record"
    result <- statusProjectionInternalTestFinalizeJournal directory
    entries <- listDirectory directory
    pendingBytes <- ByteString.readFile (directory </> pending)
    finalBytes <- ByteString.readFile (directory </> finalized)
    pure
        ( expectLeft "a final-record collision is returned to the caller" result
            <> expectEqual "a refused finalization retains the recoverable pending marker" True (pending `elem` entries)
            <> expectEqual
                "the recoverable pending marker retains its exact journal bytes"
                "amoebius-status-projection-test-journal"
                pendingBytes
            <> expectEqual "a refused finalization preserves the independent final record" "independent-final-record" finalBytes
        )

runDirectoryAdversaries :: FilePath -> IO [String]
runDirectoryAdversaries root = do
    let writeRoot = root </> "directory-symlink-write"
        redirectedBuild = root </> "redirected-build"
        target = writeRoot </> "status.md"
        journalDirectory = root </> "descriptor-journal"
        journalAlias = root </> "descriptor-journal-alias"
    createDirectory writeRoot
    createDirectory redirectedBuild
    ByteString.writeFile target "before"
    createDirectoryLink redirectedBuild (writeRoot </> ".build")
    writeResult <- statusProjectionInternalTestAtomicReplaceExact target "before" "after"
    targetBytes <- ByteString.readFile target
    createDirectory journalDirectory
    createDirectoryLink journalDirectory journalAlias
    discoveryResult <- statusProjectionInternalTestDiscoverJournal journalAlias
    pure
        ( expectLeft "a symbolic-link directory component cannot receive status temporaries" writeResult
            <> expectEqual "a refused symbolic-link directory walk preserves tracked bytes" "before" targetBytes
            <> expectLeft "journal enumeration refuses a symbolic-link directory alias" discoveryResult
        )

canonicalFinalizedLeaf :: Int -> FilePath
canonicalFinalizedLeaf ordinal =
    replicate (64 - length rendered) '0' <> rendered <> ".applied"
  where
    rendered = showHex ordinal ""

canonicalCorpus :: [(FilePath, Text)]
canonicalCorpus =
    [ (canonicalPath path, canonicalContents contents)
    | (path, contents) <- phaseContractValidCorpus
    ]
  where
    pathReplacements =
        [ ( syntheticPhasePath (phaseIdentityOrdinal identity)
          , phaseIdentityPath identity
          )
        | identity <- allPhaseIdentities
        ]
    textReplacements =
        pathReplacements
            <> [(takeFileName synthetic, takeFileName actual) | (synthetic, actual) <- pathReplacements]
    canonicalPath path = Map.findWithDefault path path (Map.fromList pathReplacements)
    canonicalContents original =
        foldr
            (\(synthetic, actual) accumulated -> Text.replace (Text.pack synthetic) (Text.pack actual) accumulated)
            original
            textReplacements

syntheticPhasePath :: Int -> FilePath
syntheticPhasePath phase =
    "DEVELOPMENT_PLAN/phase_"
        <> (if phase < 10 then "0" else "")
        <> show phase
        <> "_synthetic_capability.md"

expectedPaths :: [FilePath]
expectedPaths =
    [ expectedTrackerPath
    , "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
    , "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md"
    ]

expectedTrackerPath :: FilePath
expectedTrackerPath = "DEVELOPMENT_PLAN/README.md"

snapshotFromDocuments :: FilePath -> [(FilePath, Text)] -> SourceSnapshot
snapshotFromDocuments root documents = snapshotFromEntries root entries
  where
    entries =
        [ tracked path (TextEncoding.encodeUtf8 contents)
        | (path, contents) <- documents
        ]

snapshotWithImages ::
    SourceSnapshot ->
    [(FilePath, ByteString, ByteString)] ->
    [FilePath] ->
    SourceSnapshot
snapshotWithImages snapshot files afterPaths =
    snapshotFromEntries
        (snapshotRoot snapshot)
        [ case Map.lookup path images of
            Nothing -> entry
            Just (before, after) -> tracked path (if path `elem` afterPaths then after else before)
        | entry <- snapshotEntries snapshot
        , let path = indexPath (trackedIndex entry)
        ]
  where
    images = Map.fromList [(path, (before, after)) | (path, before, after) <- files]

snapshotWithConflict ::
    SourceSnapshot ->
    [(FilePath, ByteString, ByteString)] ->
    FilePath ->
    SourceSnapshot
snapshotWithConflict snapshot files conflictPath =
    snapshotFromEntries
        (snapshotRoot snapshot)
        [ case Map.lookup path images of
            Nothing -> entry
            Just (before, _) ->
                tracked
                    path
                    ( if path == conflictPath
                        then
                            replaceOnce
                                (TextEncoding.encodeUtf8 "🔄 Active — NOT VALIDATED")
                                (TextEncoding.encodeUtf8 "⏸️ Blocked — NOT VALIDATED")
                                before
                        else before
                    )
        | entry <- snapshotEntries snapshot
        , let path = indexPath (trackedIndex entry)
        ]
  where
    images = Map.fromList [(path, (before, after)) | (path, before, after) <- files]

snapshotWithRawEntry :: SourceSnapshot -> FilePath -> ByteString -> SourceSnapshot
snapshotWithRawEntry snapshot path bytes =
    snapshotFromEntries
        (snapshotRoot snapshot)
        ( filter ((/= path) . indexPath . trackedIndex) (snapshotEntries snapshot)
            <> [tracked path bytes]
        )

replaceOnce :: ByteString -> ByteString -> ByteString -> ByteString
replaceOnce needle replacement bytes =
    case ByteString.breakSubstring needle bytes of
        (prefix, suffix)
            | ByteString.null suffix -> bytes
            | otherwise -> prefix <> replacement <> ByteString.drop (ByteString.length needle) suffix

snapshotFromEntries :: FilePath -> [TrackedEntry] -> SourceSnapshot
snapshotFromEntries root entries =
    SourceSnapshot
        { snapshotRoot = root
        , snapshotIdentity = computeSourceSnapshotIdentity GitObjectSha256 entries
        , snapshotEntries = entries
        }

tracked :: FilePath -> ByteString -> TrackedEntry
tracked path bytes =
    TrackedEntry
        { trackedIndex =
            IndexEntry
                { indexPath = path
                , indexMode = RegularFile
                , indexObjectId = computeBlobObjectId GitObjectSha256 bytes
                }
        , trackedBytes = bytes
        }

first :: (first, second, third) -> first
first (value, _, _) = value

classificationKind :: (Text, [Int], [(Int, Int)]) -> Text
classificationKind (kind, _, _) = kind

classificationKindAndPhases :: (Text, [Int], [(Int, Int)]) -> (Text, [Int])
classificationKindAndPhases (kind, phases, _) = (kind, phases)

classificationFailures :: (Text, [Int], [(Int, Int)]) -> [(Int, Int)]
classificationFailures (_, _, failures) = failures

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
    | expected == actual = []
    | otherwise = [label <> ": expected=" <> show expected <> "; observed=" <> show actual]

expectLeft :: String -> Either left right -> [String]
expectLeft _ (Left _) = []
expectLeft label (Right _) = [label <> ": unexpectedly succeeded"]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name diagnostics =
    unless
        (null diagnostics)
        (fail (name <> " failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack diagnostics))))
