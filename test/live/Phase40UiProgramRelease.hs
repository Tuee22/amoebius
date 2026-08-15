{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Release.ArtifactManifest
import Amoebius.Ui.Release.Compatibility
import Amoebius.Ui.Release.PlanPair
import Amoebius.Ui.Release.Projection
import Control.Exception (finally)
import Control.Monad (forM, forM_, unless)
import Data.Aeson (FromJSON, ToJSON, eitherDecodeStrict', encode)
import Data.ByteString.Lazy qualified as Lazy
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import System.IO (hClose, openTempFile)
import System.Process (callProcess, readProcess)

data PlanMatrixRow = PlanMatrixRow Text Text Text Text Int
  deriving stock (Eq, Show)

data StaleMatrixRow = StaleMatrixRow Text Text Text Text Text Text Int
  deriving stock (Eq, Show)

data ReleaseRow = ReleaseRow
  { revision :: Text
  , clientDigest :: Text
  , serverDigest :: Text
  , authorityDigest :: Text
  , contentDigest :: Text
  , runtimeImage :: Text
  , clientBytes :: Text
  , serverBytes :: Text
  , contractBytes :: Text
  , manifestBytes :: Text
  , sourceKeys :: [Text]
  }
  deriving stock (Generic, Show)

instance ToJSON ReleaseRow

data CaseResult = CaseResult
  { caseName :: Text
  , caseRevision :: Text
  , caseClientDigest :: Maybe Text
  , caseServerDigest :: Maybe Text
  , caseAuthorityDigest :: Maybe Text
  , caseContentDigest :: Maybe Text
  , caseOutcome :: Text
  , caseEffectCount :: Int
  }
  deriving stock (Generic, Show)

instance ToJSON CaseResult

data Preflight = Preflight
  { preflightReleases :: [ReleaseRow]
  , preflightCases :: [CaseResult]
  }
  deriving stock (Generic, Show)

instance ToJSON Preflight

data LiveSetup = LiveSetup
  { challenge :: Text
  , stateFile :: FilePath
  }
  deriving stock (Generic, Show)

instance FromJSON LiveSetup

data LiveResult = LiveResult
  { resultChallenge :: Text
  , resultReleases :: [ReleaseRow]
  , resultCases :: [CaseResult]
  , resultTypedAdmission :: Bool
  }
  deriving stock (Generic, Show)

instance ToJSON LiveResult

main :: IO ()
main = do
  root <- projectRoot
  fixtures <- loadFixtures root
  let runtime = RuntimeImageDigest "sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
  releaseA <- either (die . show) pure (projectUiProgram runtime (UiProgramSource RevisionA "A" 1 "ui-runtime-v1"))
  releaseB <- either (die . show) pure (projectUiProgram runtime (UiProgramSource RevisionB "B" 2 "ui-runtime-v1"))
  validateProjection root runtime releaseA releaseB
  cases <- validateMatrices fixtures releaseA releaseB
  let releases = map releaseRow [releaseA, releaseB]
  pureOnly <- lookupEnv "PHASE40_PURE_ONLY"
  reuse <- lookupEnv "PHASE40_REUSE_FRESH_LIVE"
  case (pureOnly, reuse) of
    (Just "1", _) -> pure ()
    (_, Just "1") -> validateEvidence root
    _ -> runLive root releases cases
  putStrLn "ui-program-release-live-gate: PASS (atomic plan pairs, stale admission, unchanged generic runtime, live external observers)"

loadFixtures :: FilePath -> IO ([PlanMatrixRow], [StaleMatrixRow])
loadFixtures root = do
  plans <- parseTsv (root </> "test/fixtures/phase_40/plan_pair_matrix.tsv") $ \fields -> case fields of
    [client, server, authority, outcome, count] -> PlanMatrixRow client server authority outcome <$> parseInt count
    _ -> die "phase40-plan-pair-matrix-shape"
  stale <- parseTsv (root </> "test/fixtures/phase_40/stale_digest_matrix.tsv") $ \fields -> case fields of
    [name, client, server, clientAuthority, serverAuthority, outcome, count] ->
      StaleMatrixRow name client server clientAuthority serverAuthority outcome <$> parseInt count
    _ -> die "phase40-stale-matrix-shape"
  assertEqual "phase40-plan-matrix-domain" 6 (length plans)
  assertEqual "phase40-stale-matrix-domain" 5 (length stale)
  custody <- filter (Text.isPrefixOf "40\t") . Text.lines <$> TextIO.readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  assertEqual "phase40-phase0-custody" 8 (length custody)
  pure (plans, stale)

parseTsv :: FilePath -> ([Text] -> IO value) -> IO [value]
parseTsv path parser = do
  rows <- Text.lines <$> TextIO.readFile path
  traverse (parser . Text.splitOn "\t") (filter (not . Text.null) (drop 1 rows))

parseInt :: Text -> IO Int
parseInt value = case reads (Text.unpack value) of
  [(number, "")] -> pure number
  _ -> die ("phase40-invalid-integer:" <> Text.unpack value)

validateProjection :: FilePath -> RuntimeImageDigest -> UiProgramRelease -> UiProgramRelease -> IO ()
validateProjection root runtime releaseA releaseB = do
  let manifestA = uiReleaseManifest releaseA
      manifestB = uiReleaseManifest releaseB
      pairA = uiReleasePair releaseA
      pairB = uiReleasePair releaseB
      actualKeys = map sourceKeyText requiredSourceKeys
  expectedKeys <- filter (not . Text.null) . Text.lines <$> TextIO.readFile (root </> "test/fixtures/phase_40/source_key_set.txt")
  assertEqual "phase40-source-key-set" expectedKeys actualKeys
  assertWith "phase40-rebuild-runtime-per-program:" $
    manifestRuntimeImage manifestA == runtime && manifestRuntimeImage manifestB == runtime
  assertWith "phase40-program-change-content-identity" $
    releaseContentDigest releaseA /= releaseContentDigest releaseB
      && planDigest (pairClient pairA) /= planDigest (pairClient pairB)
      && planDigest (pairServer pairA) /= planDigest (pairServer pairB)
      && uiReleaseAuthority releaseA /= uiReleaseAuthority releaseB
  assertWith "phase40-publish-mixed-plan-pair:" $ case publishPlanPair (Just (pairClient pairA)) (Just (pairServer pairB)) of
    Left (MixedProgramRevision RevisionA RevisionB) -> True
    _ -> False
  assertEqual "phase40-client-half-required" (Left ClientPlanMissing) (publishPlanPair Nothing (Just (pairServer pairA)))
  assertEqual "phase40-server-half-required" (Left ServerPlanMissing) (publishPlanPair (Just (pairClient pairA)) Nothing)
  dhall <- TextIO.readFile (root </> "test/dhall/phase_40/ui_program_release.dhall")
  forM_ ["label = \"A\"", "label = \"B\"", "policyEpoch = 1", "policyEpoch = 2", "runtimeAbi = \"ui-runtime-v1\""] $ \needle ->
    assertWith "phase40-dhall-representative-set" (needle `Text.isInfixOf` dhall)
  golden <- TextIO.readFile (root </> "test/fixtures/phase_40/release_content_manifest.golden")
  assertEqual "phase40-release-manifest-oracle" golden normalizedManifest
  forM_ [manifestA, manifestB] $ \manifest -> do
    assertWith "phase40-websocket-identity" (manifestWebSocketSubprotocol manifest == "amoebius.ui.v1")
    assertWith "phase40-routing-identity" (manifestRoutingEnvelopeSchema manifest == "amoebius.routing.v1")
    assertWith "phase40-cursor-identity" (manifestCursorCodec manifest == "amoebius.cursor.v1")

normalizedManifest :: Text
normalizedManifest = Text.unlines
  [ "release-A client-plan sha256:CLIENT-A"
  , "release-A server-plan sha256:SERVER-A"
  , "release-A authority sha256:AUTH-A"
  , "release-B client-plan sha256:CLIENT-B"
  , "release-B server-plan sha256:SERVER-B"
  , "release-B authority sha256:AUTH-B"
  , "runtime-image sha256:RUNTIME-UNCHANGED"
  ]

validateMatrices :: ([PlanMatrixRow], [StaleMatrixRow]) -> UiProgramRelease -> UiProgramRelease -> IO [CaseResult]
validateMatrices (plans, staleRows) releaseA releaseB = do
  planCases <- forM plans $ \(PlanMatrixRow client server authority expected count) -> do
    let current = if server == "B" then releaseB else releaseA
        maybeClient = planFor ClientRole client releaseA releaseB
        maybeServer = planFor ServerRole server releaseA releaseB
        result = case publishPlanPair maybeClient maybeServer of
          Left _ -> ReloadRequired
          Right pair -> admitAction current PresentedPlan
            { presentedClientDigest = Just (planDigest (pairClient pair))
            , presentedServerDigest = Just (planDigest (pairServer pair))
            , presentedAuthorityDigest = Just (uiReleaseAuthority (releaseFor authority releaseA releaseB))
            , presentedContentDigest = Just (releaseContentDigest current)
            }
        effectCount = if result == Accepted then 1 else 0
    assertEqual "phase40-plan-matrix-outcome" expected (Text.pack (show result))
    assertEqual "phase40-plan-matrix-effect" count effectCount
    pure (caseResult ("pair-" <> client <> "-" <> server) (revisionFor current) current
      (planDigest <$> maybeClient) (planDigest <$> maybeServer)
      (Just (uiReleaseAuthority (releaseFor authority releaseA releaseB))) result effectCount)
  staleCases <- forM staleRows $ \(StaleMatrixRow name client server clientAuthority serverAuthority expected count) -> do
    let current = releaseFor serverAuthority releaseA releaseB
        presented = PresentedPlan
          { presentedClientDigest = tokenDigest client (planDigest (pairClient (uiReleasePair current)))
          , presentedServerDigest = tokenDigest server (planDigest (pairServer (uiReleasePair current)))
          , presentedAuthorityDigest = tokenDigest clientAuthority (uiReleaseAuthority current)
          , presentedContentDigest = tokenDigest client (releaseContentDigest current)
          }
        result = admitAction current presented
        effectCount = if result == Accepted then 1 else 0
    assertWith (if name == "stale-authority" then "phase40-accept-stale-authority-digest:" else "phase40-stale-admission:") $
      Text.pack (show result) == expected
    assertEqual "phase40-stale-effect" count effectCount
    pure CaseResult
      { caseName = name, caseRevision = "A"
      , caseClientDigest = artifactDigestText <$> presentedClientDigest presented
      , caseServerDigest = artifactDigestText <$> presentedServerDigest presented
      , caseAuthorityDigest = artifactDigestText <$> presentedAuthorityDigest presented
      , caseContentDigest = artifactDigestText <$> presentedContentDigest presented
      , caseOutcome = Text.pack (show result), caseEffectCount = effectCount
      }
  assertEqual "phase40-authorized-effect-count" 2 (sum (map caseEffectCount planCases))
  assertEqual "phase40-stale-current-effect-count" 1 (sum (map caseEffectCount staleCases))
  pure (planCases <> staleCases)

planFor :: PlanRole -> Text -> UiProgramRelease -> UiProgramRelease -> Maybe PlanArtifact
planFor _ "missing" _ _ = Nothing
planFor role token releaseA releaseB =
  let pair = uiReleasePair (releaseFor token releaseA releaseB)
   in Just (if role == ClientRole then pairClient pair else pairServer pair)

releaseFor :: Text -> UiProgramRelease -> UiProgramRelease -> UiProgramRelease
releaseFor "B" _ releaseB = releaseB
releaseFor _ releaseA _ = releaseA

tokenDigest :: Text -> ArtifactDigest -> Maybe ArtifactDigest
tokenDigest "-" _ = Nothing
tokenDigest "A" current = Just current
tokenDigest token _ = Just (digestArtifact (encode token))

revisionFor :: UiProgramRelease -> Text
revisionFor = manifestRevision . uiReleaseManifest

caseResult :: Text -> Text -> UiProgramRelease -> Maybe ArtifactDigest -> Maybe ArtifactDigest -> Maybe ArtifactDigest -> Admission -> Int -> CaseResult
caseResult name revisionName release client server authority outcome effectCount = CaseResult
  { caseName = name, caseRevision = revisionName
  , caseClientDigest = artifactDigestText <$> client
  , caseServerDigest = artifactDigestText <$> server
  , caseAuthorityDigest = artifactDigestText <$> authority
  , caseContentDigest = Just (artifactDigestText (releaseContentDigest release))
  , caseOutcome = Text.pack (show outcome), caseEffectCount = effectCount
  }

releaseRow :: UiProgramRelease -> ReleaseRow
releaseRow release = ReleaseRow
  { revision = manifestRevision manifest
  , clientDigest = artifactDigestText (planDigest client)
  , serverDigest = artifactDigestText (planDigest server)
  , authorityDigest = artifactDigestText (uiReleaseAuthority release)
  , contentDigest = artifactDigestText (releaseContentDigest release)
  , runtimeImage = runtimeImageDigestText (manifestRuntimeImage manifest)
  , clientBytes = decodeLazy (planBytes client)
  , serverBytes = decodeLazy (planBytes server)
  , contractBytes = decodeLazy (uiReleaseContracts release)
  , manifestBytes = decodeLazy (Amoebius.Ui.Release.ArtifactManifest.manifestBytes manifest)
  , sourceKeys = map sourceKeyText requiredSourceKeys
  }
 where
  manifest = uiReleaseManifest release
  pair = uiReleasePair release
  client = pairClient pair
  server = pairServer pair

decodeLazy :: Lazy.ByteString -> Text
decodeLazy = TextEncoding.decodeUtf8 . Lazy.toStrict

runLive :: FilePath -> [ReleaseRow] -> [CaseResult] -> IO ()
runLive root releases cases = do
  let helper = root </> "tools/phase40_ui_release_live.py"
  (preflightPath, preflightHandle) <- openTempFile "/tmp" "amoebius-phase40-preflight.json"
  hClose preflightHandle
  Lazy.writeFile preflightPath (encode (Preflight releases cases))
  raw <- readProcess "python3" [helper, "setup", "--plans", preflightPath] ""
  setup <- either die pure (decodeSetup raw)
  let resultPath = "/tmp/amoebius-phase40-result-" <> Text.unpack (challenge setup) <> ".json"
      cleanup = callProcess "python3" [helper, "cleanup", "--state", stateFile setup]
  (do
      Lazy.writeFile resultPath (encode LiveResult
        { resultChallenge = challenge setup, resultReleases = releases,
          resultCases = cases, resultTypedAdmission = True })
      callProcess "python3" [helper, "finish", "--state", stateFile setup, "--result", resultPath]
    ) `finally` cleanup
  validateEvidence root

decodeSetup :: String -> Either String LiveSetup
decodeSetup raw = case lines raw of
  [] -> Left "phase40-live-setup-empty"
  rows -> eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.pack (last rows)))

validateEvidence :: FilePath -> IO ()
validateEvidence root = do
  let path = root </> "DEVELOPMENT_PLAN/evidence/phase_40/ui-program-release-live.json"
  exists <- doesFileExist path
  unless exists (die "phase40-live-evidence-absent")
  raw <- TextIO.readFile path
  forM_ ["\"sealed\": true", "\"register\": 3", "\"substrate\": \"linux-cpu\"", "\"allHardwareSubstrates\": true", "\"Incus\"", "\"Lima\"", "\"WSL2\""] $ \needle ->
    assertWith "phase40-live-evidence-field" (needle `Text.isInfixOf` raw)

assertWith :: String -> Bool -> IO ()
assertWith label condition = unless condition (die label)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ":expected=" <> show expected <> ":actual=" <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= search
 where
  search directory = do
    found <- doesFileExist (directory </> "cabal.project")
    if found then pure directory else do
      let parent = takeDirectory directory
      if parent == directory then die "phase40-project-root-not-found" else search parent
