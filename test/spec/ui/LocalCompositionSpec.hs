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
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:))
import qualified Data.ByteString.Lazy.Char8 as Lazy
import Data.List (find, sort)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Generics (Generic)
import System.Directory (canonicalizePath, createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs, getEnvironment, lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

data ApplicationObservation = ApplicationObservation
  { mode :: Text
  , adapter :: Text
  , digest :: Text
  , events :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON ApplicationObservation

data VisibleObservation = VisibleObservation
  { visibleCase :: Text
  , visibleStep :: Text
  , visibleValue :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON VisibleObservation where
  parseJSON = withObject "VisibleObservation" $ \value -> VisibleObservation
    <$> value .: "case" <*> value .: "step" <*> value .: "visible"

data EffectObservation = EffectObservation
  { effectCase :: Text
  , effectBoundary :: Text
  , effectValue :: Text
  , effectTenant :: Text
  , effectSubject :: Text
  , effectAdapter :: Text
  , effectKey :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON EffectObservation where
  parseJSON = withObject "EffectObservation" $ \value -> EffectObservation
    <$> value .: "case" <*> value .: "boundary" <*> value .: "effect"
    <*> value .: "tenant" <*> value .: "subject" <*> value .: "adapter" <*> value .: "key"

data DenialObservation = DenialObservation
  { denialCase :: Text
  , denialStatus :: Text
  , denialTag :: Text
  , denialBody :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON DenialObservation where
  parseJSON = withObject "DenialObservation" $ \value -> DenialObservation
    <$> value .: "case" <*> value .: "status" <*> value .: "tag" <*> value .: "body"

data CompositionObservation = CompositionObservation
  { applications :: [ApplicationObservation]
  , visible :: [VisibleObservation]
  , singleEffects :: [EffectObservation]
  , multiEffects :: [EffectObservation]
  , denials :: [DenialObservation]
  , freshNonce :: Text
  , genericBundleDigest :: Text
  , browserOrigins :: [Text]
  , directBypass :: Text
  , privateByteCount :: Int
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON CompositionObservation

mutants :: [(String, String)]
mutants =
  [ ("M-drop-handle-tenant", "copied-handle-scope")
  , ("M-direct-workflow-fetch", "browser-backend-edge")
  , ("M-mix-client-server-plan", "plan-pair-digest")
  , ("M-ready-before-receipt", "ready-order")
  , ("owner_key_swap", "owner-key-dom")
  ]

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  binary <- resolveBinary root
  case arguments of
    [] -> runGreen root binary
    [argument] | "--mutant=" `prefixOf` argument -> runMutant root binary (drop 9 argument)
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> FilePath -> IO ()
runGreen root binary = do
  checkAuthoredApplications root
  buildBundle root
  observation <- runHarness root binary ""
  checkApplications observation
  checkSurfaceJoin root observation
  checkVisible root observation
  checkEffects root observation
  checkAccess root observation
  checkDenials root observation
  checkFreshness observation
  checkNetworkBoundary observation
  checkMutantFixtures root
  checkCalculus root
  putStrLn "ui-local-composition-calculus: PASS (5 kinds, 55 projected units)"
  putStrLn "ui-local-composition-spec: PASS (2 apps, 5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials, 5 mutants)"

runMutant :: FilePath -> FilePath -> String -> IO ()
runMutant root binary name = case lookup name mutants of
  Nothing -> die ("unknown mutant: " <> name)
  Just locus -> do
    let command = proc "node"
          [ root </> "test/harness/local_ui_composition/composition.mjs", "run", binary
          , root </> ".build/ui/local-composition/ui.js", name
          ]
    (code, output, errors) <- readCreateProcessWithExitCode command ""
    let token = "local-ui-composition-mutant: RED " <> name <> " " <> locus
    assert (code /= ExitSuccess && token `contains` (output <> errors))
      ("mutant survived or missed its red locus: " <> name <> "\n" <> output <> errors)
    putStrLn token
    exitFailure

checkAuthoredApplications :: FilePath -> IO ()
checkAuthoredApplications root = do
  -- Resolved by the gate and passed in; PATH is the fallback. The absolute path this used
  -- to name existed on one machine.
  dhall <- maybe "dhall" id <$> lookupEnv "AMOEBIUS_DHALL"
  forM_ ["single_tenant_workflow.dhall", "multi_tenant_workflow.dhall"] $ \name -> do
    let path = root </> "test/fixture/ui_local_composition" </> name
    (code, _output, errors) <- readCreateProcessWithExitCode
      (proc dhall ["type", "--file", path, "--quiet"]) ""
    assertEqual (name <> " Dhall type") ExitSuccess code
    assertEqual (name <> " Dhall stderr") "" errors

buildBundle :: FilePath -> IO ()
buildBundle root = do
  environment <- getEnvironment
  let bundleRoot = root </> ".build/ui/local-composition"
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
  assert (code == ExitSuccess) ("generic bundle exit: " <> show code <> "\n" <> output <> errors)
  assert ("Bundle succeeded" `contains` (output <> errors)) "generic bundle success token absent"

runHarness :: FilePath -> FilePath -> String -> IO CompositionObservation
runHarness root binary mutant = do
  let arguments =
        [ root </> "test/harness/local_ui_composition/composition.mjs", "run", binary
        , root </> ".build/ui/local-composition/ui.js"
        ] <> [mutant | not (null mutant)]
  (code, output, errors) <- readCreateProcessWithExitCode (proc "node" arguments) ""
  assert (code == ExitSuccess) ("composition harness exit: " <> show code <> "\n" <> output <> errors)
  assertEqual "composition harness stderr" "" errors
  either (die . ("invalid composition observation: " <>)) pure (eitherDecode (Lazy.pack output))

checkApplications :: CompositionObservation -> IO ()
checkApplications observation = do
  let actual = sort [(mode app, adapter app) | app <- applications observation]
  assertEqual "authored application modes/adapters"
    [("multi", "jitML-shaped"), ("single", "infernix-shaped")] actual
  assertEqual "application plan identities" 2 (Set.size (Set.fromList (map digest (applications observation))))
  assert (Text.length (genericBundleDigest observation) == 64) "generic bundle digest is absent"

checkSurfaceJoin :: FilePath -> CompositionObservation -> IO ()
checkSurfaceJoin root observation = do
  interactions <- loadTable (root </> "test/fixture/ui_local_composition/interactions.tsv")
  let authored = Set.fromList [Text.pack action | row <- interactions, action <- fieldAt 3 row]
      generated = Set.fromList (concatMap events (applications observation))
  assertEqual "generated/authored action join" generated authored
  assertEqual "authored interaction count" 5 (length interactions)

checkVisible :: FilePath -> CompositionObservation -> IO ()
checkVisible root observation = do
  expected <- loadTable (root </> "test/fixture/ui_local_composition/expected_visible_states.tsv")
  forM_ expected $ \row -> case row of
    [caseName, step, expectedValue] -> do
      let normalizedExpected = Text.replace "fresh-challenge" (freshNonce observation) (Text.pack expectedValue)
          matches item = visibleCase item == Text.pack caseName
            && visibleStep item == Text.pack step && visibleValue item == normalizedExpected
      assert (any matches (visible observation)) ("visible-state pin absent: " <> show row)
    _ -> die ("invalid visible-state row: " <> show row)

checkEffects :: FilePath -> CompositionObservation -> IO ()
checkEffects root observation = do
  expected <- loadTable (root </> "test/fixture/ui_local_composition/expected_effect_sequence.tsv")
  let actualSingle = singleEffects observation
  forM_ expected $ \row -> case row of
    ["single", ordinalText, boundary, expectedEffect] -> do
      ordinal <- maybe (die ("invalid effect ordinal: " <> ordinalText)) pure (readMaybeInt ordinalText)
      actual <- maybe (die ("missing effect ordinal: " <> ordinalText)) pure (atMay actualSingle (ordinal - 1))
      assertEqual ("effect boundary " <> ordinalText) (Text.pack boundary) (effectBoundary actual)
      assertEqual ("effect value " <> ordinalText)
        (Text.replace "fresh-challenge" (freshNonce observation) (Text.pack expectedEffect)) (effectValue actual)
    ["multi-foreign", "-", "-", "zero-effects"] -> do
      assertEqual "multi foreign denied backend growth" 3 (length (multiEffects observation))
    _ -> die ("invalid expected effect row: " <> show row)
  assert (all ((== "tenant-a") . effectTenant) (singleEffects observation <> multiEffects observation))
    "foreign owner reached a domain fake"

checkAccess :: FilePath -> CompositionObservation -> IO ()
checkAccess root observation = do
  rows <- loadTable (root </> "test/fixture/ui_local_composition/access_matrix.tsv")
  forM_ rows $ \row -> case row of
    [caseName, _subject, _tenant, _resource, decision] -> case caseName of
      "own" -> assertEqual "own access" "allow" decision
      "same-tenant-foreign" -> checkDenied decision caseName
      "foreign-tenant" -> checkDenied decision caseName
      _ -> die ("unknown access case: " <> caseName)
    _ -> die ("invalid access row: " <> show row)
  where
    checkDenied decision caseName = do
      actual <- findDenial caseName (denials observation)
      assertEqual (caseName <> " access fixture") "deny" decision
      assertEqual (caseName <> " access status") "404" (denialStatus actual)

checkDenials :: FilePath -> CompositionObservation -> IO ()
checkDenials root observation = do
  rows <- loadTable (root </> "test/fixture/ui_local_composition/expected_denials.tsv")
  forM_ rows $ \row -> case row of
    ["direct-browser-backend", status, tag, bodyExcludes] -> do
      assertEqual "direct browser status" (Text.pack status) (directBypass observation)
      assertEqual "direct browser tag" "BypassDenied" (Text.pack tag)
      assert (bodyExcludes == "provider-bytes") "direct-browser exclusion pin drifted"
    [caseName, status, tag, bodyExcludes] -> do
      actual <- findDenial caseName (denials observation)
      assertEqual (caseName <> " denial status") (Text.pack status) (denialStatus actual)
      assertEqual (caseName <> " denial tag") (Text.pack tag) (denialTag actual)
      assert (not (Text.pack bodyExcludes `Text.isInfixOf` denialBody actual)) (caseName <> " leaked forbidden bytes")
    _ -> die ("invalid denial row: " <> show row)
  assertEqual "foreign/private byte count" 0 (privateByteCount observation)

checkFreshness :: CompositionObservation -> IO ()
checkFreshness observation = do
  assert (Text.length (freshNonce observation) >= 40) "workflow challenge is fixed or too short"
  assert (any (Text.isInfixOf (freshNonce observation) . visibleValue) (visible observation))
    "fresh challenge did not reach browser DOM"
  assert (all (Text.isInfixOf (freshNonce observation) . effectValue) (singleEffects observation))
    "fresh challenge did not traverse the external effect sequence"

checkNetworkBoundary :: CompositionObservation -> IO ()
checkNetworkBoundary observation = do
  assertEqual "direct browser/backend bypass" "network-denied" (directBypass observation)
  assertEqual "browser UI-server origins" 2 (length (browserOrigins observation))
  assert (all ("http://127.0.0.1:" `Text.isPrefixOf`) (browserOrigins observation))
    "browser left the loopback UI-server edge"

checkMutantFixtures :: FilePath -> IO ()
checkMutantFixtures root = forM_ mutants $ \(name, _locus) -> do
  let path = root </> "test/mutant/local_ui_composition" </> (name <> ".mutant")
  source <- readFile path
  assert ("operator=" `contains` source && "expected=" `contains` source) (name <> " fixture drifted")

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadTable (root </> "test/oracle/local_ui_composition/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "local-composition-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "local-composition-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [1, 3, 42, 4, 5] :: [Int]
          artifact = artifactComponent scope "generic-composition-artifact" (resources 1)
            (RecipeId "local-ui-composition" 1)
          budget = budgetComponent scope "closed-scope-budget" (resources 3)
            (allowance (Bytes 3) (Slots 1) (Bytes 3))
          lift = liftComponent scope "local-composition-corpus" (resources 42) OnHost
          workflow = workflowComponent scope "ordered-effect-workflow" (resources 4) emptyLedger
          evidence = evidenceComponent scope "mutant-evidence" (resources 5) PureRegister
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
      assertEqual "composition calculus projection" expected actual
  action

-- The binary under test is named by the gate, which resolved it. The fallback asks
-- whichever cabal is on PATH; it never names an absolute developer-home path, because a
-- tracked test that hard-codes one passes only on the machine it was written on.
resolveBinary :: FilePath -> IO FilePath
resolveBinary root = do
  configured <- lookupEnv "AMOEBIUS_BIN"
  case configured of
    Just path -> canonicalizePath path
    Nothing -> do
      compiler <- lookupEnv "AMOEBIUS_GHC"
      let arguments =
            [ "--builddir=" <> (root </> ".build/dist-newstyle/local-ui-composition")
            , "--store-dir=" <> (root </> ".build/cabal-store")
            , "list-bin"
            , "exe:amoebius"
            ]
            <> maybe [] (\path -> ["--with-compiler=" <> path]) compiler
      (code, output, errors) <- readCreateProcessWithExitCode (proc "cabal" arguments) ""
      assertEqual "amoebius list-bin exit" ExitSuccess code
      assertEqual "amoebius list-bin stderr" "" errors
      canonicalizePath (trim output)

findDenial :: String -> [DenialObservation] -> IO DenialObservation
findDenial caseName rows = maybe (die ("missing denial: " <> caseName)) pure
  (find ((== Text.pack caseName) . denialCase) rows)

fieldAt :: Int -> [value] -> [value]
fieldAt index values = case drop index values of value : _ -> [value]; [] -> []

atMay :: [value] -> Int -> Maybe value
atMay values index = case drop index values of value : _ -> Just value; [] -> Nothing

readMaybeInt :: String -> Maybe Int
readMaybeInt value = case reads value of [(number, "")] -> Just number; _ -> Nothing

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

trim :: String -> String
trim = reverse . dropWhile (`elem` ['\n', '\r', ' ', '\t']) . reverse

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
assertEqual label expected actual = assert (expected == actual)
  (label <> ": expected " <> show expected <> ", got " <> show actual)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

die :: String -> IO value
die message = putStrLn ("ui-local-composition-spec: FAIL: " <> message) >> exitFailure
