{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Compiler.CompileFailHarness
import Control.Exception (IOException, try)
import Control.Monad (forM, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (isAbsolute, takeDirectory, (</>))
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Observation = Observation Text Text Text Int deriving (Eq, Show)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [compiler, outputRoot] -> run compiler outputRoot
    _ -> refuse "usage: compile-fail-harness-spec ABSOLUTE_GHC OUTPUT_ROOT"

run :: FilePath -> FilePath -> IO ()
run compiler outputRoot
  | not (isAbsolute compiler) = refuse "compiler path is not absolute"
  | otherwise = do
#ifdef COMPILE_FAIL_ACCEPT_ANY_FAILURE_MUTANT
      wrongReasonChallenge compiler outputRoot
#elif defined(COMPILE_FAIL_DROPS_POSITIVE_COUNTERPART_MUTANT)
      unless positiveCounterpartRequired (refuse "drop-positive-counterpart-locus: positive prerequisite was deleted")
#elif defined(COMPILE_FAIL_IMPOSSIBLE_PIN_MUTANT)
      impossiblePinChallenge
#else
      cleanRun compiler outputRoot
#endif

cleanRun :: FilePath -> FilePath -> IO ()
cleanRun compiler outputRoot = do
  verifyInventory
  exists <- doesFileExist compiler
  unless exists (refuse "absolute compiler does not exist")
  observations <- forM corpus (evaluatePair compiler outputRoot)
  wrongReasonMustBeRejected compiler outputRoot
  missingDiagnosticMustBeRejected
  unboundNameMustBeRejected compiler outputRoot
  writeResults outputRoot observations
  putStrLn "compile-fail-harness-spec: PASS (10 legal/illegal twins, 4 diagnostic codes, 5 owner phases, 3 specific negatives)"

evaluatePair :: FilePath -> FilePath -> Pair -> IO Observation
evaluatePair compiler outputRoot pair = do
  legalSource <- readText (pairLegal pair)
  illegalSource <- readText (pairIllegal pair)
  either (refuse . Text.unpack) pure (validateTwinSources pair legalSource illegalSource)
  legal <- compileSource compiler outputRoot (Text.unpack (pairClaim pair) <> "-legal") (pairLegal pair)
  when (processExit legal /= ExitSuccess || not (null (parseDiagnostics (processOutput legal))))
    (refuse (Text.unpack (pairClaim pair) <> ": legal counterpart failed\n" <> Text.unpack (processOutput legal)))
  illegal <- compileSource compiler outputRoot (Text.unpack (pairClaim pair) <> "-illegal") (pairIllegal pair)
  count <- either (refuse . Text.unpack) pure (validateNegative pair (processExit illegal) (processOutput illegal))
  legalDigest <- digestFile (pairLegal pair)
  illegalDigest <- digestFile (pairIllegal pair)
  pure (Observation (pairClaim pair) legalDigest illegalDigest count)

data ProcessObservation = ProcessObservation ExitCode Text deriving (Eq, Show)

processExit :: ProcessObservation -> ExitCode
processExit (ProcessObservation status _) = status

processOutput :: ProcessObservation -> Text
processOutput (ProcessObservation _ output) = output

compileSource :: FilePath -> FilePath -> FilePath -> FilePath -> IO ProcessObservation
compileSource compiler outputRoot label source = do
  let objects = outputRoot </> "objects" </> label
  createDirectoryIfMissing True objects
  outcome <- try (readCreateProcessWithExitCode ((proc compiler
    ["-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"
    ,"-isrc/calculus-composition", "-isrc/capacity-topology", "-isrc"
    ,"-outputdir", objects, "-package", "base", "-package", "bytestring"
    ,"-package", "containers", "-package", "deepseq", "-package", "text", source]) {cwd = Just "."}) "")
    :: IO (Either IOException (ExitCode, String, String))
  case outcome of
    Left problem -> refuse ("compiler invocation failed: " <> show problem)
    Right (status, stdoutText, stderrText) -> pure (ProcessObservation status (Text.pack (stdoutText <> stderrText)))

wrongReasonMustBeRejected :: FilePath -> FilePath -> IO ()
wrongReasonMustBeRejected compiler outputRoot = do
  observation <- compileWrongReason compiler outputRoot
  case validateNegative (head corpus) (processExit observation) (processOutput observation) of
    Left _ -> pure ()
    Right _ -> refuse "wrong-reason-negative: unrelated parse failure was accepted"

wrongReasonChallenge :: FilePath -> FilePath -> IO ()
wrongReasonChallenge compiler outputRoot = do
  observation <- compileWrongReason compiler outputRoot
  case validateNegative (head corpus) (processExit observation) (processOutput observation) of
    Left _ -> refuse "accept-any-failure-locus: mutant did not accept the wrong reason"
    Right _ -> refuse "accept-any-failure-locus: wrong diagnostic was accepted"

compileWrongReason :: FilePath -> FilePath -> IO ProcessObservation
compileWrongReason compiler outputRoot = do
  let source = outputRoot </> "WrongReason.hs"
  createDirectoryIfMissing True outputRoot
  writeFile source "module WrongReason where\nvalue =\n"
  compileSource compiler outputRoot "wrong-reason" source

missingDiagnosticMustBeRejected :: IO ()
missingDiagnosticMustBeRejected =
  case validateNegative (head corpus) (ExitFailure 1) "ordinary unstructured failure" of
    Left _ -> pure ()
    Right _ -> refuse "missing-diagnostic-negative: absent JSON diagnostic was accepted"

unboundNameMustBeRejected :: FilePath -> FilePath -> IO ()
unboundNameMustBeRejected compiler outputRoot = do
  let source = outputRoot </> "UnboundName.hs"
  createDirectoryIfMissing True outputRoot
  writeFile source "module UnboundName where\nvalue = absentName\n"
  observation <- compileSource compiler outputRoot "unbound-name" source
  case validateNegative (head corpus) (processExit observation) (processOutput observation) of
    Left _ -> pure ()
    Right _ -> refuse "unbound-name-negative: unrelated name failure was accepted"

impossiblePinChallenge :: IO ()
impossiblePinChallenge = do
  let fake = "{\"span\":{\"start\":{\"line\":40,\"column\":3}},\"severity\":\"Error\",\"code\":0,\"message\":[\"impossible\"]}\n"
  case validateNegative (head corpus) (ExitFailure 1) fake of
    Left _ -> refuse "impossible-diagnostic-pin-locus: mutant accepted an impossible code"
    Right _ -> refuse "impossible-diagnostic-pin-locus: impossible code unexpectedly matched"

verifyInventory :: IO ()
verifyInventory = do
  assert (length corpus == 10 && length (nub (map pairClaim corpus)) == 10) "corpus must bind ten unique claims"
  assert (sort (nub (map pairOwnerPhase corpus)) == [4,5,6,7,10]) "owner tranche must be phases 4, 5, 6, 7, and 10"
  assert (sort (nub (map pairCode corpus)) == [1928,25897,64725,83865]) "diagnostic vocabulary must contain four exact GHC codes"
  assert positiveCounterpartRequired "drop-positive-counterpart-locus: positive prerequisite was deleted"

writeResults :: FilePath -> [Observation] -> IO ()
writeResults outputRoot observations = do
  let target = outputRoot </> "results.tsv"
      metricRows =
        [("pair-count", 10), ("claim-count", 10), ("owner-count", 5)
        ,("legal-green-count", length observations), ("illegal-red-count", length observations)
        ,("diagnostic-code-pin-count", length observations), ("source-span-pin-count", length observations)
        ,("message-pin-count", length observations), ("twin-probe-count", length observations)
        ,("source-digest-count", sum [fromEnum (Text.length legalDigest == 64) + fromEnum (Text.length illegalDigest == 64) | Observation _ legalDigest illegalDigest _ <- observations])
        ,("structured-diagnostic-count", sum [count | Observation _ _ _ count <- observations])]
  createDirectoryIfMissing True (takeDirectory target)
  writeFile target (unlines ("metric\tvalue" : [Text.unpack key <> "\t" <> show value | (key, value) <- metricRows]))

readText :: FilePath -> IO Text
readText path = Text.pack <$> readFile path

digestFile :: FilePath -> IO Text
digestFile path = sha256 <$> ByteString.readFile path

sha256 :: ByteString.ByteString -> Text
sha256 = Text.pack . concatMap hexByte . ByteString.unpack . SHA256.hash
 where hexByte byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

assert :: Bool -> String -> IO ()
assert condition problem = unless condition (refuse problem)

refuse :: String -> IO value
refuse problem = putStrLn ("compile-fail-harness-spec: FAIL: " <> problem) >> exitFailure

corpus :: [Pair]
corpus =
  [ pair "grant-cannot-be-forged" 4 "budget_calculus/grant_comes_from_the_issuer.hs" "budget_calculus/grant_forged_unbounded.hs" "hidden-grant-constructor" 1928 40 3 ["Illegal term-level use of the type constructor", "Grant"] "authorised :: Pool" "Allowance (Bytes maxBound)"
  , pair "retention-names-reaper" 4 "budget_calculus/retention_names_its_reaper.hs" "budget_calculus/retention_omits_its_reaper.hs" "reaper-argument" 83865 18 14 ["retain", "applied to too few arguments"] "EvictionPolicy \"least-recently-used\"" "import Amoebius.Calculus.Budget.Retention (RetentionGrant, retain)"
  , pair "lift-paths-meet" 5 "lift_calculus/paths_meet_at_a_layer.hs" "lift_calculus/paths_do_not_meet.hs" "meeting-layer-index" 83865 21 59 ["Couldn't match type", "InContainer"] "pure (reached frame engine)" "Path 'InFrame 'InFrame"
  , pair "lift-witness-is-observed" 5 "lift_calculus/witness_comes_from_an_observation.hs" "lift_calculus/witness_asserted.hs" "hidden-witness-constructor" 1928 23 12 ["Illegal term-level use of the type constructor", "Witness"] "observe SOnHost SInFrame" "Witness \"asserted\""
  , pair "workflow-ends-empty" 6 "workflow_calculus/workflow_discharges_its_obligation.hs" "workflow_calculus/workflow_ends_owing_a_teardown.hs" "outstanding-set" 83865 17 20 ["Couldn't match type", "db-volume"] "teardown (Proxy @\"db-volume\")" "runWorkflow (provision"
  , pair "transfer-names-condition" 6 "workflow_calculus/transfer_names_its_condition.hs" "workflow_calculus/transfer_without_a_condition.hs" "condition-argument" 83865 20 63 ["Condition", "transfer"] "Condition \"when the retained deployment is deleted\"" "transfer (Proxy @\"cluster-lease\"))"
  , pair "teardown-is-held" 6 "workflow_calculus/teardown_discharges_what_was_provisioned.hs" "workflow_calculus/teardown_of_an_unheld_obligation.hs" "held-obligation" 64725 19 59 ["workflow holds no teardown obligation", "never-provisioned"] "teardown (Proxy @\"db-volume\")" "teardown (Proxy @\"never-provisioned\")"
  , pair "claim-names-fixture" 7 "evidence_calculus/claim_names_its_fixture.hs" "evidence_calculus/claim_without_a_fixture.hs" "fixture-argument" 83865 17 75 ["Couldn't match expected type", "Fixture"] "bound discharge =" "bound = claim"
  , pair "gate-declares-register" 7 "evidence_calculus/gate_declares_its_register.hs" "evidence_calculus/gate_without_a_register.hs" "register-argument" 83865 16 19 ["declareGate", "applied to too few arguments"] "GateRegisterOne" "module EvidenceCalculusGateWithoutARegister"
  , pair "composition-shares-scope" 10 "calculus_composition/same_scope_composes.hs" "calculus_composition/different_scopes_do_not_compose.hs" "request-scope-index" 25897 34 36 ["Couldn't match type", "scope1"] "artifactComponent scope" "artifactComponent leftScope"
  ]
 where
  pair claim owner legal illegal dimension diagnosticCode diagnosticLine diagnosticColumn fragments legalProbe illegalProbe = Pair
    claim owner (root <> legal) (root <> illegal) dimension diagnosticCode diagnosticLine diagnosticColumn fragments legalProbe illegalProbe
  root = "test/negative/compile_fail/"
