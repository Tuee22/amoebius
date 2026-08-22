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
import Amoebius.Ui.Server.Dispatch
  ( BoundaryMutant (NoBoundaryMutant)
  , HandlerBinding (..)
  , HandlerContract (..)
  , UiServerAbi (..)
  , admitServerPlan
  )
import Control.Monad (forM_, unless)
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:))
import qualified Data.ByteString.Lazy.Char8 as Lazy
import Data.List (find, sort)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Generics (Generic)
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

data HttpObservation = HttpObservation
  { httpCase :: Text
  , httpStatus :: Int
  , httpTag :: Text
  , httpBody :: Text
  , httpHeaders :: Map Text Text
  }
  deriving stock (Eq, Show)

instance FromJSON HttpObservation where
  parseJSON = withObject "HttpObservation" $ \value -> HttpObservation
    <$> value .: "case" <*> value .: "status" <*> value .: "tag" <*> value .: "body" <*> value .: "headers"

data EffectObservation = EffectObservation
  { effectCase :: Text
  , effectHandler :: Text
  , effectTenant :: Text
  , effectSubject :: Text
  , effectKey :: Text
  , effectBody :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON EffectObservation where
  parseJSON = withObject "EffectObservation" $ \value -> EffectObservation
    <$> value .: "case" <*> value .: "handler" <*> value .: "tenant" <*> value .: "subject"
    <*> value .: "key" <*> value .: "body"

data WebSocketObservation = WebSocketObservation
  { websocketCase :: Text
  , websocketStatus :: Int
  }
  deriving stock (Eq, Show)

instance FromJSON WebSocketObservation where
  parseJSON = withObject "WebSocketObservation" $ \value -> WebSocketObservation
    <$> value .: "case" <*> value .: "status"

data StartupObservation = StartupObservation
  { startupCase :: Text
  , startupReady :: Bool
  }
  deriving stock (Eq, Show)

instance FromJSON StartupObservation where
  parseJSON = withObject "StartupObservation" $ \value -> StartupObservation
    <$> value .: "case" <*> value .: "ready"

data BoundaryObservation = BoundaryObservation
  { freshNonce :: Text
  , http :: [HttpObservation]
  , replay :: HttpObservation
  , revoked :: HttpObservation
  , effects :: [EffectObservation]
  , audits :: [Text]
  , publicAssets :: [HttpObservation]
  , privateProbes :: [HttpObservation]
  , websocket :: [WebSocketObservation]
  , startup :: [StartupObservation]
  , authorityProcesses :: Int
  , handlerProcessObserved :: Bool
  , privateCanaryCount :: Int
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON BoundaryObservation

mutants :: [(String, String)]
mutants =
  [ ("M-trust-tenant-header", "foreign-token-spoof")
  , ("M-dispatch-before-authorize", "zero-denied-handler-bytes")
  , ("M-skip-current-epoch", "stale-epoch")
  , ("M-disable-origin-check", "origin-denial")
  , ("M-drop-csp-header", "security-header")
  , ("M-ready-with-unresolved-handler", "missing-handler-readiness")
  , ("M-server-first-handler-wins", "duplicate-handler-readiness")
  , ("M-serve-server-plan-as-client-asset", "private-plan-probe")
  , ("M-new-idempotency-key-on-retry", "idempotent-replay")
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
  observation <- runHarness root binary ""
  checkHttp root observation
  checkAccess root observation
  checkEffects root observation
  checkAudit root observation
  checkHeaders root observation
  checkAssets root observation
  checkStartup root observation
  checkWebSocket root observation
  checkIdempotency root observation
  checkAuthorityBoundary observation
  checkStartupFunction root
  checkMutantFixtures root
  checkCalculus root
  putStrLn "ui-server-boundary-calculus: PASS (5 kinds, 80 projected units)"
  putStrLn "ui-server-boundary-spec: PASS (7 HTTP rows, 5 access rows, 5 audits, 5 effects, 6 startup rows, 5 public assets, 5 private probes, 7 WebSocket rows, 9 mutants)"

runMutant :: FilePath -> FilePath -> String -> IO ()
runMutant root binary name = case lookup name mutants of
  Nothing -> die ("unknown mutant: " <> name)
  Just locus -> do
    let command = proc "node" [root </> "test/harness/ui_server/server_boundary.mjs", "run", binary, name]
    (code, output, errors) <- readCreateProcessWithExitCode command ""
    let token = "ui-server-boundary-mutant: RED " <> name <> " " <> locus
    assert (code /= ExitSuccess && token `contains` (output <> errors))
      ("mutant survived or missed its red locus: " <> name <> "\n" <> output <> errors)
    putStrLn token
    exitFailure

runHarness :: FilePath -> FilePath -> String -> IO BoundaryObservation
runHarness root binary mutant = do
  let arguments = [root </> "test/harness/ui_server/server_boundary.mjs", "run", binary]
        <> [mutant | not (null mutant)]
      command = proc "node" arguments
  (code, output, errors) <- readCreateProcessWithExitCode command ""
  assert (code == ExitSuccess) ("server harness exit: " <> show code <> "\n" <> output <> errors)
  assertEqual "server harness stderr" "" errors
  either (die . ("invalid server observation: " <>)) pure (eitherDecode (Lazy.pack output))

checkHttp :: FilePath -> BoundaryObservation -> IO ()
checkHttp root observation = do
  expected <- loadTable (root </> "test/fixture/ui_server/expected_http.tsv")
  assertEqual "expected HTTP row count" 7 (length expected)
  forM_ expected $ \row -> case row of
    [caseName, statusText, tag, bodyContains] -> do
      actual <- findHttp caseName (http observation)
      expectedStatus <- maybe (die ("invalid HTTP status pin: " <> statusText)) pure (readMaybe statusText)
      assertEqual (caseName <> " status") expectedStatus (httpStatus actual)
      assertEqual (caseName <> " tag") (Text.pack tag) (httpTag actual)
      case bodyContains of
        "-" -> pure ()
        "fresh-challenge" -> assert (freshNonce observation `Text.isInfixOf` httpBody actual) (caseName <> " fresh nonce absent")
        value -> assert (Text.pack value `Text.isInfixOf` httpBody actual) (caseName <> " body pin absent")
    _ -> die ("invalid expected HTTP row: " <> show row)

checkAccess :: FilePath -> BoundaryObservation -> IO ()
checkAccess root observation = do
  rows <- loadTable (root </> "test/fixture/ui_server/access_matrix.tsv")
  forM_ rows $ \row -> case row of
    caseName : _permission : _scope : _grant : _epoch : decision : _ -> do
      actual <- findHttp caseName (http observation)
      let actualDecision = if httpStatus actual >= 200 && httpStatus actual < 300 then "allow" else "deny"
      assertEqual (caseName <> " access decision") decision actualDecision
    _ -> die ("invalid access row: " <> show row)

checkEffects :: FilePath -> BoundaryObservation -> IO ()
checkEffects root observation = do
  rows <- loadTable (root </> "test/fixture/ui_server/expected_effects.tsv")
  forM_ rows $ \row -> case row of
    [caseName, handler, countText, bodyContains] -> do
      expectedCount <- maybe (die ("invalid effect count: " <> countText)) pure (readMaybe countText)
      let matching = if handler == "-" then [] else filter ((== Text.pack handler) . effectHandler) (effects observation)
      assertEqual (caseName <> " handler count") expectedCount (length matching)
      whenPinned bodyContains $ assert (all (Text.isInfixOf (freshNonce observation) . effectBody) matching)
        (caseName <> " effect nonce absent")
    _ -> die ("invalid effect row: " <> show row)
  assertEqual "external handler effect total" 2 (length (effects observation))
  assert (handlerProcessObserved observation) "fresh challenge was not recovered by the handler process"
  assert (all ((== "tenant-a") . effectTenant) (effects observation)) "foreign tenant reached the handler"

checkAudit :: FilePath -> BoundaryObservation -> IO ()
checkAudit root observation = do
  rows <- loadTable (root </> "test/fixture/ui_server/expected_audit.tsv")
  let indexes = Map.fromList [("read-own", 1), ("read-foreign", 2), ("mutate-own", 3), ("bad-origin", 5), ("stale", 6)]
  forM_ rows $ \row -> case row of
    [caseName, expectedClass, "true", expectedScope] -> do
      index <- maybe (die ("missing audit index: " <> caseName)) pure (Map.lookup caseName indexes)
      actual <- maybe (die ("missing audit row: " <> caseName)) pure (atMay (audits observation) index)
      case splitTabs (Text.unpack actual) of
        [_path, actualClass, actualScope, _effect] -> do
          assertEqual (caseName <> " audit class") expectedClass actualClass
          assertEqual (caseName <> " audit scope") expectedScope actualScope
          assert (not (Text.isInfixOf (freshNonce observation) actual)) (caseName <> " audit leaked request content")
        _ -> die ("invalid audit row: " <> Text.unpack actual)
    _ -> die ("invalid expected audit row: " <> show row)

checkHeaders :: FilePath -> BoundaryObservation -> IO ()
checkHeaders root observation = do
  rows <- loadTable (root </> "test/fixture/ui_security/production_headers.tsv")
  clientPlan <- findHttp "client-plan" (http observation)
  forM_ rows $ \row -> case row of
    [name, expected] -> assertEqual (name <> " header") (Just (Text.pack expected))
      (Map.lookup (Text.toLower (Text.pack name)) (httpHeaders clientPlan))
    _ -> die ("invalid security-header row: " <> show row)

checkAssets :: FilePath -> BoundaryObservation -> IO ()
checkAssets root observation = do
  allowed <- loadTable (root </> "test/fixture/ui_server/public_asset_allowlist.tsv") >>= mapM singleColumn
  forbidden <- loadTable (root </> "test/fixture/ui_server/forbidden_server_manifest_paths.tsv") >>= mapM singleColumn
  assertEqual "public asset set" (sort allowed) (sort (map (Text.unpack . httpCase) (publicAssets observation)))
  assert (all ((== 200) . httpStatus) (publicAssets observation)) "a public asset was unavailable"
  forM_ forbidden $ \path -> do
    probe <- findHttp path (privateProbes observation)
    assertEqual (path <> " private status") 404 (httpStatus probe)
    assert (not ("private-canary" `Text.isInfixOf` httpBody probe)) (path <> " leaked private bytes")
  assertEqual "private canary count" 0 (privateCanaryCount observation)

checkStartup :: FilePath -> BoundaryObservation -> IO ()
checkStartup root observation = do
  rows <- loadTable (root </> "test/fixture/ui_server/startup_plan_matrix.tsv")
  forM_ rows $ \row -> case row of
    [caseName, _count, _unreferenced, _contract, _abi, expected] -> do
      actual <- maybe (die ("missing startup case: " <> caseName)) pure
        (find ((== Text.pack caseName) . startupCase) (startup observation))
      assertEqual (caseName <> " readiness") (expected == "true") (startupReady actual)
    _ -> die ("invalid startup row: " <> show row)

checkWebSocket :: FilePath -> BoundaryObservation -> IO ()
checkWebSocket root observation = do
  rows <- loadTable (root </> "test/fixture/ui_server/websocket_registration.tsv")
  forM_ rows $ \row -> case row of
    [caseName, statusText, _coordinatorCount] -> do
      expectedStatus <- maybe (die ("invalid WebSocket status: " <> statusText)) pure (readMaybe statusText)
      actual <- maybe (die ("missing WebSocket case: " <> caseName)) pure
        (find ((== Text.pack caseName) . websocketCase) (websocket observation))
      assertEqual (caseName <> " WebSocket status") expectedStatus (websocketStatus actual)
    _ -> die ("invalid WebSocket row: " <> show row)
  assertEqual "accepted WebSocket registrations" 1
    (length (filter (Text.isPrefixOf "websocket-register\taccepted") (audits observation)))

checkIdempotency :: FilePath -> BoundaryObservation -> IO ()
checkIdempotency root observation = do
  rows <- loadTable (root </> "test/fixture/ui_server/idempotency.tsv")
  assertEqual "idempotency fixture rows" [["mutation-retry", "mutation-key", "2", "1"]] rows
  assertEqual "retry HTTP status" 202 (httpStatus (replay observation))
  assertEqual "idempotent handler count" 1
    (length (filter ((== "mutation-key") . effectKey) (effects observation)))

checkAuthorityBoundary :: BoundaryObservation -> IO ()
checkAuthorityBoundary observation = do
  assert (Text.length (freshNonce observation) >= 40) "fresh challenge is fixed or too short"
  assertEqual "separate authority process count" 3 (authorityProcesses observation)
  assertEqual "revoked grant status" 404 (httpStatus (revoked observation))
  foreignRow <- findHttp "read-foreign" (http observation)
  assertEqual "forged tenant header status" 404 (httpStatus foreignRow)

checkStartupFunction :: FilePath -> IO ()
checkStartupFunction root = do
  rows <- loadTable (root </> "test/fixture/ui_server/startup_plan_matrix.tsv")
  forM_ rows $ \row -> case row of
    [caseName, countText, unreferencedText, contractText, abiText, expectedText] -> do
      count <- maybe (die ("invalid identity count: " <> countText)) pure (readMaybe countText)
      unreferenced <- maybe (die ("invalid unreferenced count: " <> unreferencedText)) pure
        (readMaybe unreferencedText)
      let expectedContract = HandlerContract "request-v1" "response-v1"
          actualContract = if contractText == "match" then expectedContract else HandlerContract "wrong" "wrong"
          bindings = replicate count (HandlerBinding "handler-main" actualContract)
            <> replicate unreferenced (HandlerBinding "handler-extra" expectedContract)
          abi = if abiText == "ui-server-v1" then UiServerV1 else UnsupportedUiServerAbi (Text.pack abiText)
          admitted = either (const False) (const True)
            (admitServerPlan NoBoundaryMutant abi [("handler-main", expectedContract)] bindings)
      assertEqual (caseName <> " pure startup admission") (expectedText == "true") admitted
    _ -> die ("invalid startup row: " <> show row)

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadTable (root </> "test/oracle/ui_server_boundary/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-server-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-server-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [5, 5, 55, 6, 9] :: [Int]
          artifact = artifactComponent scope "public-boundary-artifacts" (resources 5)
            (RecipeId "ui-server-boundary" 5)
          budget = budgetComponent scope "closed-authority-budget" (resources 5)
            (allowance (Bytes 5) (Slots 1) (Bytes 5))
          lift = liftComponent scope "server-boundary-corpus" (resources 55) OnHost
          workflow = workflowComponent scope "startup-admission-workflow" (resources 6) emptyLedger
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
      assertEqual "server calculus projection" expected actual
  action

checkMutantFixtures :: FilePath -> IO ()
checkMutantFixtures root = forM_ mutants $ \(name, _locus) -> do
  let path = root </> "test/mutant/ui_server_boundary" </> (name <> ".mutant")
  source <- readFile path
  assert ("operator=" `contains` source && "expected=" `contains` source) (name <> " fixture drifted")

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
            [ "--builddir=" <> (root </> ".build/dist-newstyle/ui-server-boundary")
            , "--store-dir=" <> (root </> ".build/cabal-store")
            , "list-bin"
            , "exe:amoebius"
            ]
            <> maybe [] (\path -> ["--with-compiler=" <> path]) compiler
      (code, output, errors) <- readCreateProcessWithExitCode (proc "cabal" arguments) ""
      assertEqual "amoebius list-bin exit" ExitSuccess code
      assertEqual "amoebius list-bin stderr" "" errors
      canonicalizePath (trim output)

findHttp :: String -> [HttpObservation] -> IO HttpObservation
findHttp caseName rows = maybe (die ("missing HTTP observation: " <> caseName)) pure
  (find ((== Text.pack caseName) . httpCase) rows)

whenPinned :: String -> IO () -> IO ()
whenPinned value action = if value == "fresh-challenge" then action else pure ()

atMay :: [value] -> Int -> Maybe value
atMay values index = case drop index values of value : _ -> Just value; [] -> Nothing

singleColumn :: [String] -> IO String
singleColumn row = case row of
  [value] -> pure value
  _ -> die ("expected one-column row: " <> show row)

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
die message = putStrLn ("ui-server-boundary-spec: FAIL: " <> message) >> exitFailure
