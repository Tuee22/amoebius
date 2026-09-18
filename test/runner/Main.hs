{-# LANGUAGE OverloadedStrings #-}

-- | The runner suite: a byte producer for the runner oracle. It exercises the
-- gate-specification constructor, specification verification against a fixture
-- package description, the operator catalogue, deterministic sampling, mutant
-- application with its witness, the kill table, the hygiene row over a fixture
-- tree, and candidate capture. It prints no verdict; the oracle under
-- test/oracle/runner/Main.hs judges the rows from literals.
module Main (main) where

import Amoebius.Doc.Check (checkTree, discoverDocuments)
import Amoebius.Doc.Types (CheckResult (..), Finding (..))
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.Custody.Preflight
import Amoebius.Validation.Custody.Status
import Amoebius.Validation.Custody.Store
import Amoebius.Validation.GateSpec
import Amoebius.Validation.Runner.Capture
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteArray (convert)
import Data.ByteString qualified as ByteString
import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Runner.Mutants
import Amoebius.Validation.Runner.Spec
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist)
import System.Environment (getArgs)
import System.FilePath ((</>))

main :: IO ()
main = do
  arguments <- getArgs
  let output = case arguments of
        [path] -> path
        _ -> ".build/runs/phase-00/runner"
  createDirectoryIfMissing True output
  rows <- concat <$> sequence [constructorRows, verifyRows output, operatorRows output, killRows', hygieneRows output, captureRows, preflightRows, storeRows output, statusRows output, tripwireRows, packageRows]
  TextIO.writeFile (output </> "runner.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
  putStrLn ("runner projection written: " <> (output </> "runner.tsv"))

-- * Fixtures

legalInput :: GateSpecInput
legalInput =
  GateSpecInput
    { inputCapability = "typed_spine"
    , inputClaim = "one spec reaches fake-applied bytes"
    , inputSubjects = [ProductionModule "Amoebius.Dsl.Spec", ProductionModule "Amoebius.Dsl.Lower"]
    , inputSuite = CabalTarget "dsl-suite"
    , inputOracle = OracleExecutable "oracle-dsl"
    , inputCases = [PositiveControl "kind-single-objectstore" "root.dhall" "manifest-delta", PairedNegative "unbound-need" "unbound.dhall" "UnboundNeed" "lower"]
    , inputMutants = defaultMutantPolicy [ProductionModule "Amoebius.Dsl.Spec"]
    , inputBinaryFact = Just (BinaryFact ["compile", "{input}"] "examples/root.dhall" (SentinelToNonce "SENTINEL") ["{run}/out/manifest.yaml"])
    , inputSpineFact = Nothing
    , inputSubstrate = HardwareFree
    , inputSeed = Nothing
    }

constructorRows :: IO [[Text]]
constructorRows =
  pure
    [ ["refusal", "legal-ordinary", outcome OrdinaryGate legalInput]
    , ["refusal", "kernel-subject", outcome OrdinaryGate legalInput {inputSubjects = [ProductionModule "Amoebius.Validation.Runner"], inputMutants = defaultMutantPolicy []}]
    , ["refusal", "missing-binary-fact", outcome OrdinaryGate legalInput {inputBinaryFact = Nothing}]
    , ["refusal", "barrier-without-spine", outcome BarrierGate legalInput]
    , ["refusal", "seed-with-binary-fact", outcome SeedGate legalInput {inputSeed = Just (SeedSpec ["clean"] ["p1"])}]
    , ["refusal", "hardware-substrate-ordinary", outcome OrdinaryGate legalInput {inputSubstrate = LinuxCpu}]
    , ["refusal", "hardware-role-without-substrate", outcome HardwareGate legalInput]
    , ["refusal", "stage-not-subject", outcome OrdinaryGate legalInput {inputMutants = defaultMutantPolicy [ProductionModule "Amoebius.Dsl.Other"]}]
    , ["refusal", "duplicate-case", outcome OrdinaryGate legalInput {inputCases = [PositiveControl "a" "x" "y", PositiveControl "a" "x" "z"]}]
    , ["refusal", "legal-seed", outcome SeedGate legalInput {inputBinaryFact = Nothing, inputSeed = Just (SeedSpec ["clean", "digest-equality-bypass"] ["probe-1"])}]
    , ["render", "legal-ordinary", either (const "refused") (Text.pack . show . length . Text.lines . renderGateSpec) (mkGateSpec OrdinaryGate legalInput)]
    ]
 where
  outcome role input = either (Text.intercalate "," . sort . map renderSpecRefusal) (const "ok") (mkGateSpec role input)

fixtureCabal :: Text
fixtureCabal =
  Text.unlines
    [ "cabal-version: 3.0"
    , "name: amoebius"
    , "version: 0.1.0.0"
    , "build-type: Simple"
    , ""
    , "library dsl-core"
    , "    exposed-modules: Amoebius.Dsl.Spec Amoebius.Dsl.Lower"
    , "    hs-source-dirs: src"
    , "    build-depends: base, amoebius:vocabulary"
    , "    default-language: GHC2024"
    , ""
    , "library vocabulary"
    , "    exposed-modules: Amoebius.Vocabulary"
    , "    hs-source-dirs: src"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    , ""
    , "library validation-runner"
    , "    exposed-modules: Amoebius.Validation.Runner"
    , "    hs-source-dirs: src"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    , ""
    , "library parked"
    , "    exposed-modules: Amoebius.Parked.Thing"
    , "    hs-source-dirs: src"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    , ""
    , "executable amoebius"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: app"
    , "    build-depends: base, amoebius:dsl-core"
    , "    default-language: GHC2024"
    , ""
    , "test-suite dsl-suite"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/dsl"
    , "    build-depends: base, amoebius:dsl-core"
    , "    default-language: GHC2024"
    , ""
    , "test-suite oracle-dsl"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/oracle/dsl"
    , "    build-depends: base, text"
    , "    default-language: GHC2024"
    , ""
    , "test-suite oracle-leaky"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/oracle/leaky"
    , "    build-depends: base, amoebius:dsl-core"
    , "    default-language: GHC2024"
    , ""
    , "test-suite oracle-cpp"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/oracle/cpp"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    ]

verifyRows :: FilePath -> IO [[Text]]
verifyRows output = do
  let root = output </> "fixture-package"
  createDirectoryIfMissing True (root </> "test/oracle/dsl")
  createDirectoryIfMissing True (root </> "test/oracle/leaky")
  createDirectoryIfMissing True (root </> "test/oracle/cpp")
  TextIO.writeFile (root </> "test/oracle/dsl/Main.hs") "module Main (main) where\nmain :: IO ()\nmain = pure ()\n"
  TextIO.writeFile (root </> "test/oracle/leaky/Main.hs") "module Main (main) where\nmain :: IO ()\nmain = pure ()\n"
  TextIO.writeFile (root </> "test/oracle/cpp/Main.hs") "\nmodule Main (main) where\n#if defined(X)\nmain :: IO ()\nmain = pure ()\n#endif\n"
  case parsePackageGraph (TextEncoding.encodeUtf8 fixtureCabal) of
    Left problem -> pure [["verify", "parse", renderSpecProblem problem]]
    Right graph -> do
      let closure = maybe "absent" (Text.intercalate "," . Set.toAscList) (executableClosure graph "amoebius")
          check name role input = do
            result <- case mkGateSpec role input of
              Left refusals -> pure (Left (map renderSpecRefusal refusals))
              Right spec -> either (Left . map renderSpecProblem) (const (Right ())) <$> verifySpecAgainst root graph spec
            pure ["verify", name, either (Text.intercalate "," . sort) (const "ok") result]
      rows <-
        sequence
          [ check "legal" OrdinaryGate legalInput
          , check "outside-closure" OrdinaryGate legalInput {inputSubjects = [ProductionModule "Amoebius.Parked.Thing"], inputMutants = defaultMutantPolicy []}
          , check "not-in-package" OrdinaryGate legalInput {inputSubjects = [ProductionModule "Amoebius.Nowhere"], inputMutants = defaultMutantPolicy []}
          , check "oracle-depends-on-product" OrdinaryGate legalInput {inputOracle = OracleExecutable "oracle-leaky"}
          , check "oracle-cpp" OrdinaryGate legalInput {inputOracle = OracleExecutable "oracle-cpp"}
          , check "oracle-missing" OrdinaryGate legalInput {inputOracle = OracleExecutable "oracle-absent"}
          , check "suite-missing" OrdinaryGate legalInput {inputSuite = CabalTarget "no-suite"}
          ]
      pure (["verify", "closure", closure] : rows)

fixtureModule :: Text
fixtureModule =
  Text.unlines
    [ "module Amoebius.Dsl.Fixture (limit, fits, pick, record, items) where"
    , ""
    , "import Data.List (sort)"
    , ""
    , "limit :: Int"
    , "limit = 3"
    , ""
    , "fits :: Int -> Bool"
    , "fits n = n < limit"
    , ""
    , "pick :: Int -> Int"
    , "pick n = if n == 0 then 1 else 2"
    , ""
    , "record :: Record"
    , "record ="
    , "  Record"
    , "    { alpha = 1"
    , "    , beta = 2"
    , "    }"
    , ""
    , "items :: [Int]"
    , "items = [1, 2, 3]"
    ]

operatorRows :: FilePath -> IO [[Text]]
operatorRows output = do
  let allLoci = [(operator, enumerateLoci "Amoebius.Dsl.Fixture" "src/Amoebius/Dsl/Fixture.hs" operator fixtureModule) | operator <- allOperators]
      lociRows = [["loci", renderOperator operator, Text.pack (show (length loci)), Text.intercalate "," (map (Text.pack . show . locusLine) loci)] | (operator, loci) <- allLoci]
      pool = concatMap snd allLoci
      sampleA = sampleLoci "seed-a" 4 pool
      sampleB = sampleLoci "seed-a" 4 pool
      sampleC = sampleLoci "seed-b" 4 pool
      render sample = Text.intercalate "," [Text.pack (show (locusLine locus)) <> ":" <> renderOperator (locusOperator locus) | locus <- sample]
  let copyRoot = output </> "fixture-copy"
  createDirectoryIfMissing True (copyRoot </> "src/Amoebius/Dsl")
  TextIO.writeFile (copyRoot </> "src/Amoebius/Dsl/Fixture.hs") fixtureModule
  applied <- case [locus | locus <- pool, locusOperator locus == ConstantFlip, locusLine locus == 6] of
    (locus : _) -> do
      result <- applyLocus copyRoot locus
      rewritten <- TextIO.readFile (copyRoot </> "src/Amoebius/Dsl/Fixture.hs")
      pure
        [ ["apply", "witness", either id (\w -> if witnessBeforeDigest w /= witnessAfterDigest w then "changed" else "unchanged") result]
        , ["apply", "line-6", Text.strip (Text.lines rewritten !! 5)]
        ]
    [] -> pure [["apply", "witness", "no-locus"]]
  stale <- case [locus | locus <- pool, locusOperator locus == ConstantFlip, locusLine locus == 6] of
    (locus : _) -> do
      result <- applyLocus copyRoot locus
      pure [["apply", "stale-locus", either (const "refused") (const "applied") result]]
    [] -> pure []
  pure
    ( lociRows
        <> [ ["sample", "deterministic", if render sampleA == render sampleB then "equal" else "differs"]
           , ["sample", "seed-sensitive", if render sampleA /= render sampleC then "differs" else "equal"]
           , ["sample", "size", Text.pack (show (length sampleA))]
           , ["sample", "cap", Text.pack (show (length (sampleLoci "seed-a" 100 pool)))]
           ]
        <> applied
        <> stale
    )

killRows' :: IO [[Text]]
killRows' = do
  let locus n = Locus "Amoebius.Dsl.Fixture" "src/Amoebius/Dsl/Fixture.hs" n ConstantFlip "a" "b"
      table =
        killTable
          [ (locus 1, Nothing, Killed "lower")
          , (locus 2, Nothing, Killed "lower")
          , (locus 3, Nothing, Killed "encode")
          , (locus 4, Nothing, Survived)
          , (locus 5, Nothing, Stillborn "parse error")
          , (locus 6, Nothing, Stillborn "type error")
          , (locus 7, Nothing, Unapplied "line mismatch")
          ]
  pure
    [ ["kill", "killed", Text.pack (show (killedCount table))]
    , ["kill", "viable", Text.pack (show (viableCount table))]
    , ["kill", "stillborn", Text.pack (show (stillbornCount table))]
    , ["kill", "ratio", Text.pack (show (killRatioObserved table))]
    , ["kill", "rows", Text.pack (show (length (renderKillTable table)))]
    ]

hygieneRows :: FilePath -> IO [[Text]]
hygieneRows output = do
  let root = output </> "fixture-tree"
  createDirectoryIfMissing True (root </> "src/validation-kernel/Amoebius/Validation/FooRun")
  createDirectoryIfMissing True (root </> "src/gate-spec")
  createDirectoryIfMissing True (root </> "src/doc-check")
  createDirectoryIfMissing True (root </> "src/product")
  TextIO.writeFile (root </> "src/validation-kernel/Amoebius/Validation/Core.hs") "module Core where\n#if defined(X)\nx = 1\n#endif\ny = \"phase-03\"\ncanonicalPhaseIdentities :: Int\ncanonicalPhaseIdentities = 1\n"
  TextIO.writeFile (root </> "src/validation-kernel/Amoebius/Validation/FooRun/Internal.hs") "module FooRun.Internal where\nz = 2\n"
  TextIO.writeFile (root </> "src/gate-spec/Spec.hs") "module Spec where\ndata Substrate = A | B\n"
  TextIO.writeFile (root </> "src/validation-kernel/Amoebius/Validation/Vocab.hs") "module Vocab where\ndata Substrate = E | F\n"
  TextIO.writeFile (root </> "src/product/Vocabulary.hs") "module Vocabulary where\ndata Substrate = C | D\n"
  TextIO.writeFile (root </> "src/doc-check/Check.hs") "module Check where\nw = 3\n"
  report <- hygieneRow root (Just 5) 7000
  clean <- do
    let cleanRoot = output </> "fixture-tree-clean"
    createDirectoryIfMissing True (cleanRoot </> "src/validation-kernel")
    TextIO.writeFile (cleanRoot </> "src/validation-kernel/Core.hs") "module Core where\nx = 1\n"
    hygieneRow cleanRoot Nothing 7000
  realExists <- doesDirectoryExist "src/validation-kernel"
  real <- if realExists then Just <$> hygieneRow "." Nothing 7000 else pure Nothing
  pure
    ( [ ["hygiene", "fixture.kernel-lines", Text.pack (show (hygieneKernelLines report))]
      , ["hygiene", "fixture.cap", Text.pack (show (hygieneKernelCap report))]
      , ["hygiene", "fixture.cpp", Text.pack (show (length (hygieneConditionalCompilation report)))]
      , ["hygiene", "fixture.run-modules", Text.pack (show (hygieneRunModules report))]
      , ["hygiene", "fixture.phase-literals", Text.pack (show (length (hygienePhaseLiterals report)))]
      , ["hygiene", "fixture.phase-tables", Text.pack (show (length (hygienePhaseTables report)))]
      , ["hygiene", "fixture.duplicates", Text.intercalate "," (map fst (hygieneDuplicateVocabulary report))]
      , ["hygiene", "fixture.product-duplicates", Text.intercalate "," (map fst (hygieneProductDuplicateVocabulary report))]
      , ["hygiene", "fixture.problems", Text.pack (show (length (hygieneProblems report)))]
      , ["hygiene", "clean.green", Text.pack (show (hygieneGreen clean))]
      , ["hygiene", "clean.cap", Text.pack (show (hygieneKernelCap clean))]
      ]
        <> maybe [] (\r -> [["hygiene", "real.kernel-lines", Text.pack (show (hygieneKernelLines r))], ["hygiene", "real.green", Text.pack (show (hygieneGreen r))], ["hygiene", "real.doc-check-lines", Text.pack (show (hygieneDocCheckLines r))]]) real
    )

captureRows :: IO [[Text]]
captureRows = do
  let green = Candidate 3 "typed_spine" "d" "n" "c" [CandidateRow category Green [("k", "v")] | category <- allGateCategories]
      oneRed = green {candidateRows = [CandidateRow category (if category == Mutants then Red else Green) [("k", "v")] | category <- allGateCategories]}
      emptyObservation = green {candidateRows = [CandidateRow category Green [] | category <- allGateCategories]}
      reordered = green {candidateRows = reverse (candidateRows green)}
  pure
    [ ["capture", "all-green", Text.pack (show (candidateGreen green))]
    , ["capture", "one-red", Text.pack (show (candidateGreen oneRed))]
    , ["capture", "empty-observation", Text.pack (show (candidateGreen emptyObservation))]
    , ["capture", "reordered", Text.pack (show (candidateGreen reordered))]
    , ["capture", "rows", Text.pack (show (length (Text.lines (renderCandidate green))))]
    , ["capture", "categories", Text.pack (show (Map.size (Map.fromList [(renderGateCategory c, ()) | c <- allGateCategories])))]
    ]

-- * Custody

cleanFacts :: GateSpec -> PreflightFacts
cleanFacts spec =
  PreflightFacts
    { factsSpec = spec
    , factsSurfaceDigest = "surface"
    , factsAcceptedPostimage = Just "surface"
    , factsGenerationPresent = True
    , factsPredecessorCommitted = Just True
    , factsDoneWithoutReceipt = []
    , factsVerifierDigest = "verifier"
    , factsSeedVerifierDigest = Just "verifier"
    , factsGovernanceDigest = "governance"
    , factsSeedGovernanceDigest = Just "governance"
    , factsFrozenFindings = []
    , factsBarrierReceipt = False
    , factsHost = HostFacts [HardwareFree, LinuxCpu]
    , factsHygieneProblems = []
    , factsPreviousSpec = Nothing
    }

preflightRows :: IO [[Text]]
preflightRows = case (mkGateSpec OrdinaryGate legalInput, mkGateSpec HardwareGate legalInput {inputSubstrate = LinuxCpu}, mkGateSpec OrdinaryGate legalInput {inputCases = take 1 (inputCases legalInput)}) of
  (Right spec, Right hardware, Right weaker) ->
    let clean = cleanFacts spec
        row name facts = ["preflight", name, Text.intercalate "," (map (Text.takeWhile (/= ':') . renderPreflightRefusal) (preflight facts))]
     in pure
          [ row "clean" clean
          , row "status-surface-dirty" clean {factsSurfaceDigest = "other"}
          , row "predecessor-not-committed" clean {factsPredecessorCommitted = Just False}
          , row "status-without-receipt" clean {factsDoneWithoutReceipt = [1]}
          , row "verifier-diverged" clean {factsVerifierDigest = "other"}
          , row "governance-unaccepted" clean {factsGovernanceDigest = "other"}
          , row "frozen-finding" clean {factsFrozenFindings = ["DOC-FROZEN-BODY-CHANGED"]}
          , row "hardware-before-barrier" (cleanFacts hardware) {factsBarrierReceipt = False}
          , row "hardware-after-barrier" (cleanFacts hardware) {factsBarrierReceipt = True}
          , row "substrate-absent" (cleanFacts hardware) {factsBarrierReceipt = True, factsHost = HostFacts [HardwareFree, Apple]}
          , row "kernel-over-budget" clean {factsHygieneProblems = ["KernelOverBudget: 15000 lines against a cap of 14000"]}
          , row "spec-weakened" (cleanFacts weaker) {factsPreviousSpec = Just spec}
          , row "spec-unchanged" clean {factsPreviousSpec = Just spec}
          , row "generation-absent" clean {factsGenerationPresent = False, factsAcceptedPostimage = Nothing, factsSeedVerifierDigest = Nothing, factsSeedGovernanceDigest = Nothing}
          , ["preflight", "weakened-detail", Text.intercalate ";" (specWeakened spec weaker)]
          ]
  _ -> pure [["preflight", "fixtures", "refused"]]

storeRows :: FilePath -> IO [[Text]]
storeRows output = do
  let store = Store (output </> "fixture-store")
  createDirectoryIfMissing True (storeRoot store)
  secret <- Ed25519.generateSecretKey
  ByteString.writeFile (storeRoot store </> "issuer.key") (convert secret)
  let seed = SeedRecord "abc123" "DL-0007" "abc123" "gov" "surface" "commit" "now"
      receipt = Receipt 0 "documentation_suite" "abc123" "spec" "rendered\nspec" "cand" "kill" "closure" "abc123" "gov" "post" "commit" ["w1", "w2"] Nothing Nothing "2026-09-18 00:00:01 UTC"
      resetReceipt = receipt {receiptResetCause = Just ("gap", "LTD-DSL-001"), receiptIssuedAt = "2026-09-18 00:00:00 UTC"}
  wroteSeed <- writeSeed store seed
  wroteReceipt <- writeReceipt store receipt
  wroteReset <- writeReceipt store resetReceipt
  readBack <- readSeed store "abc123"
  receipts <- readReceipts store "abc123"
  latest <- latestGeneration store "abc123"
  other <- latestGeneration store "zzz"
  -- tamper with the receipt payload and read again
  let receiptPath = generationDirectory store "abc123" </> "receipts" </> "phase-00.tsv"
  original <- TextIO.readFile receiptPath
  TextIO.writeFile receiptPath (Text.replace "documentation_suite" "documentation_suitx" original)
  tampered <- readReceipts store "abc123"
  TextIO.writeFile receiptPath original
  restored <- readReceipts store "abc123"
  pure
    [ ["store", "write-seed", either id (const "ok") wroteSeed]
    , ["store", "write-receipt", either id (const "ok") wroteReceipt]
    , ["store", "seed-roundtrip", either id (\s -> if s == seed then "equal" else "differs") readBack]
    , ["store", "receipt-roundtrip", if [r | r <- receipts, receiptResetCause r == Nothing] == [receipt] then "equal" else "differs:" <> Text.pack (show (length receipts))]
    , ["store", "reset-receipt", either id (const (if resetReceipt `elem` receipts then "kept-beside-pass" else "lost")) wroteReset]
    , ["store", "latest-generation", maybe "absent" seedDecision latest]
    , ["store", "other-generation", maybe "absent" seedDecision other]
    , ["store", "tampered-receipt", Text.pack (show (length tampered))]
    , ["store", "restored-receipt", Text.pack (show (length restored))]
    , ["store", "generation-directory", Text.pack (generationDirectory (Store "/s") "abcdef0123456789zzzz")]
    ]

statusRows :: FilePath -> IO [[Text]]
statusRows output = do
  let copyRoot = output </> "fixture-plan"
  (documents, _, _) <- discoverDocuments "."
  removeAndWrite copyRoot documents
  surface <- statusSurface copyRoot
  case surface of
    Left problem -> pure [["status", "surface", problem]]
    Right recorded -> do
      let frontier = recordedFrontier recorded
          next = frontier >>= \f -> Status.frontierAfterPass f 0
      patch <- maybe (pure []) (patchToFrontier copyRoot) next
      mapM_ (\(path, contents) -> TextIO.writeFile (copyRoot </> path) contents) patch
      after <- statusSurface copyRoot
      result <- checkTree [] copyRoot
      let afterFrontier = either (const Nothing) recordedFrontier after
          afterTracker = either (const []) (\s -> [Text.pack (show phase) <> "=" <> status | (phase, _, status) <- surfaceTracker s, phase `elem` [0, 1, 2]]) after
          afterPhase0 = either (const "") (\s -> maybe "" (\(_, _, line) -> line) (lookupPhase 0 (surfacePhaseLines s))) after
          afterSprint = either (const []) (\s -> [Text.pack (show sprint) <> "=" <> heading <> "|" <> status | (phase, sprint, _, heading, status) <- surfaceSprints s, phase == 0, sprint `elem` [1, 2]]) after
      pure
        [ ["status", "recorded-frontier", Text.pack (show (fmap (\f -> Status.phaseStatusAt f 0) frontier))]
        , ["status", "surface-digest-stable", if surfaceDigest recorded == either (const "") surfaceDigest after then "same" else "changed"]
        , ["status", "patched-files", Text.pack (show (length patch))]
        , ["status", "after-tracker", Text.intercalate ";" afterTracker]
        , ["status", "after-phase-0", afterPhase0]
        , ["status", "after-sprints", Text.intercalate ";" afterSprint]
        , ["status", "after-frontier", Text.pack (show (fmap (\f -> Status.phaseStatusAt f 1) afterFrontier))]
        , ["status", "doc-check-findings", Text.intercalate "," (nubText (map findingCode (checkFindings result)))]
        ]
 where
  lookupPhase phase entries = case [entry | entry@(p, _, _) <- entries, p == phase] of
    (entry : _) -> Just entry
    [] -> Nothing
  removeAndWrite root documents = mapM_ (\(path, contents) -> do
    createDirectoryIfMissing True (root </> takeDirectoryText path)
    TextIO.writeFile (root </> path) contents) documents
  takeDirectoryText path = reverse (drop 1 (dropWhile (/= '/') (reverse path)))
  nubText = foldr (\item seen -> if item `elem` seen then seen else item : seen) []

tripwireRows :: IO [[Text]]
tripwireRows =
  pure
    [ ["tripwire", "agent-shell", Text.intercalate "," (markersIn [("CLAUDECODE", "1"), ("HOME", "/h"), ("AI_AGENT", "x")])]
    , ["tripwire", "human-shell", Text.intercalate "," (markersIn [("HOME", "/h"), ("PATH", "/usr/bin")])]
    , ["tripwire", "markers", Text.intercalate "," (map Text.pack agentMarkers)]
    ]

-- * The package description

packageRows :: IO [[Text]]
packageRows = do
  exists <- doesFileExist "amoebius.cabal"
  if not exists
    then pure [["package", "present", "False"]]
    else do
      bytes <- ByteString.readFile "amoebius.cabal"
      contents <- TextIO.readFile "amoebius.cabal"
      let flags = length [() | line <- Text.lines contents, "flag " `Text.isPrefixOf` line]
          executables = [Text.drop 11 line | line <- Text.lines contents, "executable " `Text.isPrefixOf` line]
      pure $ case parsePackageGraph bytes of
        Left problem -> [["package", "parse", renderSpecProblem problem]]
        Right graph ->
          let closure = maybe Set.empty id (executableClosure graph "amoebius")
              validatorStanzas = ["validation-kernel", "validation-runner", "doc-check", "plan-decisions", "gate-spec"]
              leaks = [stanza | stanza <- validatorStanzas, Set.member stanza closure]
              verifier = maybe Set.empty id (executableClosure graph "amoebius-validate")
           in [ ["package", "product-closure-validator-free", Text.pack (show (null leaks))]
              , ["package", "product-closure-size", Text.pack (show (Set.size closure))]
              , ["package", "verifier-links-runner", Text.pack (show (Set.member "validation-runner" verifier))]
              , ["package", "flags", Text.pack (show flags)]
              , ["package", "executables", Text.intercalate "," (sort executables)]
              , ["package", "libraries", Text.pack (show (Map.size (graphLibraries graph)))]
              ]
