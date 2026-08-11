{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (forM_, unless)
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:))
import qualified Data.ByteString.Lazy.Char8 as Lazy
import Data.List (find, sort)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Generics (Generic)
import System.Directory (canonicalizePath, getCurrentDirectory)
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
  binary <- resolveBinary
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
  putStrLn "ui-local-composition-spec: PASS (2 apps, 5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials, 5 mutants)"

runMutant :: FilePath -> FilePath -> String -> IO ()
runMutant root binary name = case lookup name mutants of
  Nothing -> die ("unknown mutant: " <> name)
  Just locus -> do
    let command = proc "node"
          [ root </> "test/ui/local/phase23_local_composition.mjs", "run", binary
          , root </> "ui-runtime/dist/ui.js", name
          ]
    (code, output, errors) <- readCreateProcessWithExitCode command ""
    let token = "phase23-composition-mutant: RED " <> name <> " " <> locus
    assert (code /= ExitSuccess && token `contains` (output <> errors))
      ("mutant survived or missed its red locus: " <> name <> "\n" <> output <> errors)
    putStrLn token
    exitFailure

checkAuthoredApplications :: FilePath -> IO ()
checkAuthoredApplications root = forM_ ["single_tenant_workflow.dhall", "multi_tenant_workflow.dhall"] $ \name -> do
  let path = root </> "test/fixtures/ui_local_composition" </> name
  (code, _output, errors) <- readCreateProcessWithExitCode
    (proc "/home/matthewnowak/.local/bin/dhall" ["type", "--file", path, "--quiet"]) ""
  assertEqual (name <> " Dhall type") ExitSuccess code
  assertEqual (name <> " Dhall stderr") "" errors

buildBundle :: FilePath -> IO ()
buildBundle root = do
  environment <- getEnvironment
  let pathValue = root </> "node_modules/.bin" <> ":/usr/bin:/bin"
      command = (proc "node"
        [ "../node_modules/spago/bin/bundle.js", "bundle", "--offline", "--platform", "browser"
        , "--bundle-type", "app", "--module", "Main", "--outfile", "dist/ui.js", "--strict"
        ])
        { cwd = Just (root </> "ui-runtime")
        , env = Just (("PATH", pathValue) : filter ((/= "PATH") . fst) environment)
        }
  (code, output, errors) <- readCreateProcessWithExitCode command ""
  assertEqual "generic bundle exit" ExitSuccess code
  assert ("Bundle succeeded" `contains` (output <> errors)) "generic bundle success token absent"

runHarness :: FilePath -> FilePath -> String -> IO CompositionObservation
runHarness root binary mutant = do
  let arguments =
        [ root </> "test/ui/local/phase23_local_composition.mjs", "run", binary
        , root </> "ui-runtime/dist/ui.js"
        ] <> [mutant | not (null mutant)]
  (code, output, errors) <- readCreateProcessWithExitCode (proc "node" arguments) ""
  assertEqual "composition harness exit" ExitSuccess code
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
  interactions <- loadTable (root </> "test/fixtures/ui_local_composition/interactions.tsv")
  let authored = Set.fromList [Text.pack action | row <- interactions, action <- fieldAt 3 row]
      generated = Set.fromList (concatMap events (applications observation))
  assertEqual "generated/authored action join" generated authored
  assertEqual "authored interaction count" 5 (length interactions)

checkVisible :: FilePath -> CompositionObservation -> IO ()
checkVisible root observation = do
  expected <- loadTable (root </> "test/fixtures/ui_local_composition/expected_visible_states.tsv")
  forM_ expected $ \row -> case row of
    [caseName, step, expectedValue] -> do
      let normalizedExpected = Text.replace "fresh-challenge" (freshNonce observation) (Text.pack expectedValue)
          matches item = visibleCase item == Text.pack caseName
            && visibleStep item == Text.pack step && visibleValue item == normalizedExpected
      assert (any matches (visible observation)) ("visible-state pin absent: " <> show row)
    _ -> die ("invalid visible-state row: " <> show row)

checkEffects :: FilePath -> CompositionObservation -> IO ()
checkEffects root observation = do
  expected <- loadTable (root </> "test/fixtures/ui_local_composition/expected_effect_sequence.tsv")
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
  rows <- loadTable (root </> "test/fixtures/ui_local_composition/access_matrix.tsv")
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
  rows <- loadTable (root </> "test/fixtures/ui_local_composition/expected_denials.tsv")
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
  let path = root </> "test/mutants" </> (if name == "owner_key_swap" then "phase_23_owner_key_swap.mutant" else "phase_23_" <> name <> ".mutant")
  source <- readFile path
  assert ("operator=" `contains` source && "expected=" `contains` source) (name <> " fixture drifted")

resolveBinary :: IO FilePath
resolveBinary = do
  configured <- lookupEnv "AMOEBIUS_BIN"
  case configured of
    Just path -> canonicalizePath path
    Nothing -> do
      (code, output, errors) <- readCreateProcessWithExitCode
        (proc "/home/matthewnowak/.ghcup/bin/cabal-3.16.1.0" ["list-bin", "exe:amoebius", "--offline"]) ""
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

die :: String -> IO value
die message = putStrLn ("ui-local-composition-spec: FAIL: " <> message) >> exitFailure
