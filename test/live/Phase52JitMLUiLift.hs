{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

data Evidence = Evidence Int Text Text Authority Browser Workflow Cuda (Map Text Text) (Map Text Bool) Universal (Map Text Text) Prerequisite
data Authority = Authority (Map Text Identity) (Map Text Text) Bool Bool
data Identity = Identity Bool Text Text Text
data Browser = Browser Text [Text] [Int] Text Text Text Int
data Workflow = Workflow Text Text Text (Map Text Int) (Map Text Int) Int Text Text
data Cuda = Cuda Int Int Int Int Bool Bool Bool Text
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Prerequisite = Prerequisite Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value -> Evidence
    <$> value .: "register" <*> value .: "substrate" <*> value .: "result"
    <*> value .: "authority" <*> value .: "browser" <*> value .: "workflow"
    <*> value .: "cuda" <*> value .: "providers" <*> value .: "cleanup"
    <*> value .: "universalLinuxCpu" <*> value .: "honesty" <*> value .: "prerequisite"

instance FromJSON Authority where
  parseJSON = withObject "Authority" $ \value -> Authority
    <$> value .: "scopedIdentityFixtures" <*> value .: "tokenDigests"
    <*> value .: "freshKeycloakSessions" <*> value .: "rawTokensStored"

instance FromJSON Identity where
  parseJSON = withObject "Identity" $ \value -> Identity
    <$> value .: "active" <*> value .: "username" <*> value .: "tenant" <*> value .: "source"

instance FromJSON Browser where
  parseJSON = withObject "Browser" $ \value -> Browser
    <$> value .: "engine" <*> value .: "origins" <*> value .: "positiveStatuses"
    <*> value .: "visibleResult" <*> value .: "hostileText" <*> value .: "hostileHtml"
    <*> value .: "hostileScriptCount"

instance FromJSON Workflow where
  parseJSON = withObject "Workflow" $ \value -> Workflow
    <$> value .: "commandId" <*> value .: "workId" <*> value .: "terminalOutcome"
    <*> value .: "effects" <*> value .: "denials" <*> value .: "forbiddenEffectDelta"
    <*> value .: "receiptOriginReplica" <*> value .: "receiptRepairSource"

instance FromJSON Cuda where
  parseJSON = withObject "Cuda" $ \value -> Cuda
    <$> value .: "parameters" <*> value .: "optimizerSteps" <*> value .: "kernelLaunches"
    <*> value .: "checkpointBytes" <*> value .: "physicalDevice" <*> value .: "cpuFallback"
    <*> value .: "allocationReleased" <*> value .: "driverApi"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal
    <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine
    <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Prerequisite where
  parseJSON = withObject "Prerequisite" $ \value -> Prerequisite
    <$> value .: "phase50ReceiptFingerprint" <*> value .: "phase50Result"
    <*> value .: "phase51ReceiptFingerprint" <*> value .: "phase51Result"

main :: IO ()
main = do
  root <- projectRoot
  let path = root </> "DEVELOPMENT_PLAN/evidence/phase_52/jitml-ui-live.json"
  bytes <- ByteString.readFile path
  evidence <- either die pure (eitherDecodeStrict' bytes)
  validate evidence
  putStrLn "jitml-ui-lift-live-gate: PASS-SCOPED (Chrome, identity matrix, two local origins, durable-file repair, physical host CUDA)"

validate :: Evidence -> IO ()
validate (Evidence register substrate result authority browser workflow cuda providers cleanup universal honesty prerequisite) = do
  assert (register == 3 && substrate == "linux-cuda" && result == "PASS-SCOPED") "register/substrate/result"
  validateAuthority authority
  validateBrowser browser
  validateWorkflow workflow
  validateCuda cuda
  assert (providers Map.! "Keycloak" == "UNVERIFIED" && providers Map.! "Minio" == "UNVERIFIED"
    && providers Map.! "Pulsar" == "UNVERIFIED" && providers Map.! "Redis" == "UNVERIFIED") "provider honesty"
  assert (not (Map.null cleanup) && and (Map.elems cleanup)) "cleanup"
  validateUniversal universal
  assert (honesty Map.! "typedUiAdapter" == "TESTED" && honesty Map.! "realBrowser" == "TESTED"
    && honesty Map.! "physicalHostCuda" == "TESTED" && honesty Map.! "freshKeycloakSessions" == "UNVERIFIED"
    && honesty Map.! "retainedMinioReceipt" == "UNVERIFIED" && honesty Map.! "retainedRedisRoute" == "UNVERIFIED") "honesty matrix"
  validatePrerequisite prerequisite

validateAuthority :: Authority -> IO ()
validateAuthority (Authority identities digests fresh raw) = do
  assert (not fresh && not raw) "authority boundary"
  assert (Map.keysSet identities == Map.keysSet digests && Map.size identities == 3) "identity cardinality"
  assert (all (Text.isPrefixOf "sha256:") (Map.elems digests)) "token digests"
  case (Map.lookup "alice" identities, Map.lookup "bob" identities, Map.lookup "carol" identities) of
    (Just (Identity True "alice" "t-a" "scoped-identity-fixture"),
     Just (Identity True "bob" "t-a" "scoped-identity-fixture"),
     Just (Identity True "carol" "t-b" "scoped-identity-fixture")) -> pure ()
    _ -> die "identity matrix"

validateBrowser :: Browser -> IO ()
validateBrowser (Browser engine origins statuses visible hostileText hostileHtml scripts) = do
  assert (engine == "google-chrome/playwright-core" && length origins == 2 && length (Map.fromList (zip origins [1 :: Int ..])) == 2) "browser origins"
  assert (statuses == [200, 200, 200, 200] && visible == "stable-reference-vector") "browser positive flow"
  assert (hostileText == "<SCRIPT>PORT:ADMIN</SCRIPT>" && "&lt;SCRIPT&gt;" `Text.isInfixOf` hostileHtml && scripts == 0) "escaped output"

validateWorkflow :: Workflow -> IO ()
validateWorkflow (Workflow command work outcome effects denials forbidden origin repair) = do
  assert (command == work && "cmd:" `Text.isPrefixOf` command && outcome == "TerminalSucceeded") "workflow identity"
  assert (effects == Map.fromList [("trainingStarts", 1), ("cudaInvocations", 1), ("checkpointReads", 1), ("resultWrites", 1), ("pointerAdvances", 0)]) "effect counts"
  assert (denials == Map.fromList [("sameTenantNonOwner", 404), ("foreignTenant", 404), ("inflight", 409), ("failed", 409)] && forbidden == 0) "denial matrix"
  assert (origin == "ui-B" && repair == "independent temporary durable-file observer") "repair source"

validateCuda :: Cuda -> IO ()
validateCuda (Cuda parameters steps launches bytes physical cpuFallback released driver) =
  assert (parameters == 10000000 && steps == 200 && launches == 200 && bytes == 40000000
    && physical && not cpuFallback && released && driver == "libcuda.so.1") "CUDA evidence"

validateUniversal :: Universal -> IO ()
validateUniversal (Universal available (Pristine linux linuxCuda apple windows)) =
  assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal CPU/VM routing"

validatePrerequisite :: Prerequisite -> IO ()
validatePrerequisite (Prerequisite p50 r50 p51 r51) =
  assert (Text.isPrefixOf "sha256:" p50 && r50 == "PASS-SCOPED" && Text.isPrefixOf "sha256:" p51 && r51 == "PASS-SCOPED") "prerequisite receipts"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else
      let parent = takeDirectory path
       in if parent == path then die "phase52-project-root-absent" else ascend parent
