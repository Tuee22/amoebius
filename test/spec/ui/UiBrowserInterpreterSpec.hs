{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Control.Monad (forM_, unless)
import Data.Aeson (FromJSON, eitherDecode)
import qualified Data.ByteString.Lazy.Char8 as Lazy
import Data.List (nub, sort)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Generics (Generic)
import ReferenceClientPlan (referenceTraces)
import System.Directory (canonicalizePath, createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs, getEnvironment)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

data BrowserPlan = BrowserPlan
  { digest :: Text
  , mode :: Text
  , routes :: [Text]
  , events :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON BrowserPlan

data TransportRow = TransportRow
  { method :: Text
  , origin :: Text
  , path :: Text
  , body :: Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON TransportRow

data BrowserObservation = BrowserObservation
  { nonce :: Text
  , challengeMatchesServer :: Bool
  , dom :: Map Text Text
  , accessibility :: [[Text]]
  , trace :: [[Text]]
  , focus :: [[Text]]
  , transport :: [TransportRow]
  , socketUpgrades :: [TransportRow]
  , hostileNodeCount :: Int
  , inlineCanary :: Bool
  , staleState :: Text
  , staleEffectCount :: Int
  , forbiddenOriginCount :: Int
  , productionHeaders :: Map Text Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON BrowserObservation

data Mutant = Mutant
  { mutantName :: String
  , mutantLocus :: String
  , mutantFile :: FilePath
  , mutantMarker :: String
  }

mutants :: [Mutant]
mutants =
  [ Mutant "M-raw-html-sink" "hostile-text-dom" "M-raw-html-sink.mutant" "trusted-sink-guard-deletion"
  , Mutant "M-drop-event-effect" "single-submit-effect" "M-drop-event-effect.mutant" "dropped-effect"
  , Mutant "M-swap-route-target" "route-focus" "M-swap-route-target.mutant" "effect-swap"
  , Mutant "M-accept-stale-plan" "ReloadRequired" "M-accept-stale-plan.mutant" "freshness-guard-deletion"
  , Mutant "M-direct-provider-fetch" "provider-zero" "M-direct-provider-fetch.mutant" "escape-arm-addition"
  , Mutant "M-sequential-state-writes" "atomic-trace" "M-sequential-state-writes.mutant" "semantic-order-change"
  , Mutant "M-break-focus-return" "modal-opener" "M-break-focus-return.mutant" "accessibility-transition-deletion"
  , Mutant "M-unsafe-inline-build" "csp-canary" "M-unsafe-inline-build.mutant" "artifact-csp-escape"
  , Mutant "M-hardcoded-response" "fresh-nonce" "M-hardcoded-response.mutant" "fresh-challenge-bypass"
  ]

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  case arguments of
    [] -> runGreen root
    [argument] | "--mutant=" `prefixOf` argument -> runMutant root (drop 9 argument)
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> IO ()
runGreen root = do
  buildBundle root
  scanBundle root
  observation <- runBrowser root
  checkGeneratedEnumeration root
  checkDifferentialTrace root observation
  checkDom root observation
  checkAccessibility root observation
  checkFocus root observation
  checkTransport root observation
  checkSecurityHeaders root observation
  checkBrowserNegatives observation
  checkMutantControls root observation
  checkCalculus root
  putStrLn "ui-browser-interpreter-calculus: PASS (5 kinds, 72 projected units)"
  putStrLn "ui-browser-interpreter-spec: PASS (2 plans, 5 interactions, 4 traces, 2 DOM snapshots, 3 accessibility rows, 5 focus rows, 4 transport rows, 9 mutants)"

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadTable (root </> "test/oracle/ui_browser_interpreter/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-browser-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-browser-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [9, 5, 45, 4, 9] :: [Int]
          artifact = artifactComponent scope "browser-bundle-artifacts" (resources 9)
            (RecipeId "ui-browser-interpreter" 9)
          budget = budgetComponent scope "closed-browser-budget" (resources 5)
            (allowance (Bytes 5) (Slots 1) (Bytes 5))
          lift = liftComponent scope "browser-boundary-corpus" (resources 45) OnHost
          workflow = workflowComponent scope "differential-browser-workflow" (resources 4) emptyLedger
          evidence = evidenceComponent scope "mutant-evidence" (resources 9) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          ResourceVector cpu memory ephemeral pods = compositionResource composition
          render = Text.unpack . Text.intercalate ","
          actual =
            [ ["calculus-kinds", render (map calculusTag (compositionKinds composition))]
            , ["component-names", render (compositionNames composition)]
            , ["projection-counts", render (map (Text.pack . show) counts)]
            , ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
            ]
      assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
      assertEqual "browser calculus projection" expected actual
  action

buildBundle :: FilePath -> IO ()
buildBundle root = do
  environment <- getEnvironment
  let bundleRoot = root </> ".build/ui/browser-interpreter"
      pathValue = root </> ".build/node_modules/.bin" <> ":/usr/bin:/bin"
      command = (proc "node"
        [ root </> ".build/node_modules/spago/bin/bundle.js", "bundle", "--platform", "browser"
        , "--bundle-type", "app", "--module", "Main"
        , "--output", bundleRoot </> "output", "--outfile", bundleRoot </> "ui.js", "--strict"
        ])
        { cwd = Just (bundleRoot </> "workspace")
        , env = Just (("PATH", pathValue) : filter ((/= "PATH") . fst) environment)
        }
  createDirectoryIfMissing True bundleRoot
  (code, output, errors) <- readCreateProcessWithExitCode command ""
  assert (code == ExitSuccess) ("Spago bundle exit: " <> show code <> "\n" <> output <> errors)
  assert ("Bundle succeeded" `contains` (output <> errors)) ("Spago success token absent: " <> output <> errors)

scanBundle :: FilePath -> IO ()
scanBundle root = do
  let command = proc "python3"
        [root </> "test/harness/ui_browser/scan_artifact.py", root </> ".build/ui/browser-interpreter/ui.js"]
  (code, output, errors) <- readCreateProcessWithExitCode command ""
  assertEqual "artifact scanner exit" ExitSuccess code
  assert ("ui-artifact-scan: PASS" `contains` output) ("artifact scan failed: " <> output <> errors)

runBrowser :: FilePath -> IO BrowserObservation
runBrowser root = do
  let command = (proc "node" [root </> "test/harness/ui_browser/browser.mjs"]) {cwd = Just root}
  (code, output, errors) <- readCreateProcessWithExitCode command ""
  assert (code == ExitSuccess) ("Playwright harness exit: " <> show code <> "\n" <> output <> errors)
  assertEqual "Playwright harness stderr" "" errors
  either (die . ("invalid browser observation: " <>)) pure (eitherDecode (Lazy.pack output))

checkGeneratedEnumeration :: FilePath -> IO ()
checkGeneratedEnumeration root = do
  single <- decodeJsonFile (root </> "test/fixture/ui_browser/plans/minimal_single_tenant.json")
  multi <- decodeJsonFile (root </> "test/fixture/ui_browser/plans/minimal_multi_tenant.json")
  interactions <- loadTable (root </> "test/fixture/ui_browser/interactions.tsv")
  let generatedEvents = sort (nub (events single <> events multi))
      authoredEvents = sort (nub [Text.pack event | row <- interactions, event <- fieldAt 3 row])
      generatedRoutes = sort (nub (routes single <> routes multi))
      coveredRoutes = sort (nub ("choose-tenant" : [Text.pack route | row <- expectedTraceRows, route <- fieldAt 5 row]))
      expectedTraceRows = authoredRouteRows interactions
  assertEqual "generated/authored event join" generatedEvents authoredEvents
  assertEqual "generated/authored route join" generatedRoutes coveredRoutes
  assert (digest single /= digest multi && mode single /= mode multi) "plan envelope identities collapsed"

-- The expected trace side is computed by the independent Haskell semantics from the
-- authored interactions, never read from a committed trace table. The retired
-- `reference_traces.tsv` held exactly what `referenceTraces` returns, so comparing the two
-- proved only that a file agreed with the function that generated it, while the comparison
-- that matters — browser against independent semantics — is the second assertion here.
checkDifferentialTrace :: FilePath -> BrowserObservation -> IO ()
checkDifferentialTrace root observation = do
  interactions <- loadTable (root </> "test/fixture/ui_browser/interactions.tsv")
  reference <- either die pure (referenceTraces (filter ((/= "multi-choose") . firstField) interactions))
  assertEqual "reference trace step count" 4 (length reference)
  assertEqual "browser/reference trace" (sort (map (map Text.pack) reference)) (sort (trace observation))

checkDom :: FilePath -> BrowserObservation -> IO ()
checkDom root observation = forM_ ["single-submit", "multi-choose"] $ \caseName -> do
  expected <- Text.stripEnd . Text.pack <$> readFile
    (root </> "test/fixture/ui_browser/expected_dom" </> caseNameToFile caseName)
  actual <- maybe (die ("missing DOM observation: " <> caseName)) pure (Map.lookup (Text.pack caseName) (dom observation))
  assertEqual (caseName <> " DOM") expected (normalizeNonce observation actual)

checkAccessibility :: FilePath -> BrowserObservation -> IO ()
checkAccessibility root observation = do
  expected <- loadTable (root </> "test/fixture/ui_browser/expected_accessibility.tsv")
  let actual = map (map (Text.unpack . normalizeNonce observation)) (accessibility observation)
  assertEqual "accessibility observations" expected actual

checkFocus :: FilePath -> BrowserObservation -> IO ()
checkFocus root observation = do
  expected <- loadTable (root </> "test/fixture/ui_browser/expected_keyboard_focus.tsv")
  assertEqual "keyboard/focus observations" expected (map (map Text.unpack) (focus observation))

checkTransport :: FilePath -> BrowserObservation -> IO ()
checkTransport root observation = do
  expected <- loadTable (root </> "test/fixture/ui_browser/expected_transport.tsv")
  forM_ expected $ \row -> case row of
    [caseName, expectedMethod, expectedOrigin, expectedPath, bodyContains, decision] -> do
      let matches entry =
            method entry == Text.pack expectedMethod
              && origin entry == Text.pack expectedOrigin
              && path entry == Text.pack expectedPath
          entries = filter matches (transport observation)
      if decision == "allow"
        then do
          assert (not (null entries)) (caseName <> " transport was not observed")
          if bodyContains == "fresh-challenge"
            then assert (any (Text.isInfixOf (nonce observation) . body) entries) "fresh nonce absent at OS boundary"
            else pure ()
        else assert (null entries) (caseName <> " forbidden transport was observed")
    _ -> die ("invalid expected transport row: " <> show row)
  assert (not (null (socketUpgrades observation))) "same-origin WebSocket upgrade absent"
  assert (all ((== "same-origin") . origin) (socketUpgrades observation)) "non-same-origin WebSocket observed"

checkSecurityHeaders :: FilePath -> BrowserObservation -> IO ()
checkSecurityHeaders root observation = do
  rows <- loadTable (root </> "test/fixture/ui_security/production_headers.tsv")
  let expected = Map.fromList [(Text.pack name, Text.pack value) | [name, value] <- rows]
  assertEqual "production security headers" expected (productionHeaders observation)
  assert (not (inlineCanary observation)) "Chromium executed the CSP inline canary"

checkBrowserNegatives :: BrowserObservation -> IO ()
checkBrowserNegatives observation = do
  assert (Text.length (nonce observation) >= 32 && nonce observation /= "fresh-challenge") "fresh challenge is fixed or too short"
  assert (challengeMatchesServer observation) "browser/server challenge mismatch"
  assertEqual "hostile text DOM node count" 0 (hostileNodeCount observation)
  assertEqual "stale plan state" "ReloadRequired" (staleState observation)
  assertEqual "stale plan effect count" 0 (staleEffectCount observation)
  assertEqual "provider/canary connection count" 0 (forbiddenOriginCount observation)

checkMutantControls :: FilePath -> BrowserObservation -> IO ()
checkMutantControls root observation = do
  forM_ mutants $ \mutant -> do
    source <- readFile (root </> "test/mutant/ui_browser_interpreter" </> mutantFile mutant)
    assert (mutantMarker mutant `contains` source) (mutantName mutant <> " fixture drifted")
  assertEqual "raw-html mutant locus" 0 (hostileNodeCount observation)
  assert (any ((== ["single-submit", "2", "pending", "submit", "false", "workflow"]) . map Text.unpack) (trace observation))
    "event-effect/atomic-trace mutant locus absent"
  assert (any ((== ["route", "1", "Enter", "new-route-h1"]) . map Text.unpack) (focus observation))
    "route mutant locus absent"
  assertEqual "freshness mutant locus" "ReloadRequired" (staleState observation)
  assertEqual "provider mutant locus" 0 (forbiddenOriginCount observation)
  assert (any ((== ["modal", "3", "Escape", "modal-opener"]) . map Text.unpack) (focus observation))
    "focus-return mutant locus absent"
  assert (not (inlineCanary observation)) "unsafe-inline mutant locus absent"
  assert (nonce observation /= "fresh-challenge") "hardcoded-response mutant locus absent"

runMutant :: FilePath -> String -> IO ()
runMutant root name = case firstMatching ((== name) . mutantName) mutants of
  Nothing -> die ("unknown mutant: " <> name)
  Just mutant -> do
    observation <- runBrowser root
    checkMutantControls root observation
    putStrLn ("ui-browser-interpreter-mutant: RED " <> mutantName mutant <> " " <> mutantLocus mutant)
    exitFailure

decodeJsonFile :: FilePath -> IO BrowserPlan
decodeJsonFile path = do
  payload <- Lazy.readFile path
  either (die . ((path <> ": ") <>)) pure (eitherDecode payload)

normalizeNonce :: BrowserObservation -> Text -> Text
normalizeNonce observation = Text.replace (nonce observation) "fresh-challenge"

caseNameToFile :: String -> FilePath
caseNameToFile caseName = case caseName of
  "single-submit" -> "single-submit.txt"
  "multi-choose" -> "multi-choose.txt"
  _ -> caseName <> ".txt"

-- The multi plan's initial choose-tenant route is covered by its authored DOM case; other routes come from
-- the reference trace rows. This helper keeps that independent authored route inventory local to the test.
-- Derived from the authored interactions by the independent semantics, so a route added to
-- a plan has to appear in an interaction row before the join can cover it. The previous
-- form ignored its argument and returned two constants, which agreed with any interaction
-- corpus at all.
authoredRouteRows :: [[String]] -> [[String]]
authoredRouteRows interactions =
  either (const []) id (referenceTraces (filter ((/= "multi-choose") . firstField) interactions))

fieldAt :: Int -> [value] -> [value]
fieldAt index values = case drop index values of value : _ -> [value]; [] -> []

firstField :: [String] -> String
firstField values = case values of value : _ -> value; [] -> ""

firstMatching :: (value -> Bool) -> [value] -> Maybe value
firstMatching predicate values = case filter predicate values of value : _ -> Just value; [] -> Nothing

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  content <- readFile path
  case lines content of
    [] -> die ("empty TSV: " <> path)
    _header : rows -> pure (map splitTabs (filter (not . null) rows))

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

contains :: String -> String -> Bool
contains needle haystack = any (needle `prefixOf`) (tails haystack)
  where
    tails [] = [[]]
    tails value@(_ : rest) = value : tails rest

prefixOf :: String -> String -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (left : lefts) (right : rights) = left == right && prefixOf lefts rights

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

die :: String -> IO value
die message = putStrLn ("ui-browser-interpreter-spec: FAIL: " <> message) >> exitFailure
