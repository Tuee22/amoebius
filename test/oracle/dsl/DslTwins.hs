{-# LANGUAGE OverloadedStrings #-}

-- | The compile-negative twins. Each pair is authored here, written beneath the suite
-- directory, and handed to the compiler: the legal twin must compile clean, and the illegal
-- twin must draw exactly one error at the pinned line and column with the pinned code and
-- message. Nothing here is tracked.
module DslTwins
  ( twinRows
  ) where

import Control.Exception (SomeException, try)
import Data.Aeson (Result (Success), Value (..), eitherDecodeStrict', fromJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Foldable (toList)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslParse (Row, check)
import System.Directory (createDirectoryIfMissing)
import System.Exit (ExitCode (ExitSuccess))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

data Diagnostic = Diagnostic
  { diagnosticSeverity :: Text
  , diagnosticCode :: Int
  , diagnosticLine :: Int
  , diagnosticColumn :: Int
  , diagnosticMessage :: Text
  }

-- | A twin pair: the name, the legal source, the illegal source, and what the illegal one must draw.
data Twin = Twin
  { twinName :: Text
  , twinLegal :: Text
  , twinIllegal :: Text
  , twinCode :: Int
  , twinLine :: Int
  , twinColumn :: Int
  , twinFragments :: [Text]
  }

twinRows :: FilePath -> IO [Row]
twinRows suite = mapM (observe suite) twins

observe :: FilePath -> Twin -> IO Row
observe suite twin = do
  let directory = suite </> "compiler-negative" </> Text.unpack (twinName twin)
  createDirectoryIfMissing True directory
  legal <- compile directory "Legal" (twinLegal twin)
  illegal <- compile directory "Illegal" (twinIllegal twin)
  let legalClean = case legal of
        Just (code, diagnostics) -> code == ExitSuccess && null [() | item <- diagnostics, diagnosticSeverity item == "Error"]
        Nothing -> False
      illegalPinned = case illegal of
        Just (code, [item]) ->
          code /= ExitSuccess
            && diagnosticSeverity item == "Error"
            && diagnosticCode item == twinCode twin
            && diagnosticLine item == twinLine twin
            && diagnosticColumn item == twinColumn twin
            && all (`Text.isInfixOf` diagnosticMessage item) (twinFragments twin)
        _ -> False
  pure (check ("twin." <> twinName twin) (legalClean && illegalPinned) (Text.pack (show (legalClean, illegalPinned, fmap (map diagnosticCode . snd) illegal))))

compile :: FilePath -> Text -> Text -> IO (Maybe (ExitCode, [Diagnostic]))
compile directory name source = do
  let path = directory </> Text.unpack name <> ".hs"
  createDirectoryIfMissing True (directory </> Text.unpack name <> "-out")
  writeFile path (Text.unpack source)
  outcome <- try (readProcessWithExitCode "cabal" ["exec", "--jobs=1", "--", "ghc", "-j1", "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024", "-outputdir", directory </> Text.unpack name <> "-out", path] "") :: IO (Either SomeException (ExitCode, String, String))
  pure $ case outcome of
    Left _ -> Nothing
    Right (code, _, errors) -> Just (code, [item | line <- Text.lines (Text.pack errors), Just item <- [diagnosticOf line]])

diagnosticOf :: Text -> Maybe Diagnostic
diagnosticOf line = case eitherDecodeStrict' (Encoding.encodeUtf8 line) of
  Right (Object root) -> do
    severity <- textAt "severity" root
    code <- numberAt "code" root
    start <- KeyMap.lookup "span" root >>= objectOf >>= KeyMap.lookup "start" >>= objectOf
    row <- numberAt "line" start
    column <- numberAt "column" start
    messages <- KeyMap.lookup "message" root
    pure (Diagnostic severity code row column (messageText messages))
  _ -> Nothing
 where
  objectOf value = case value of
    Object fields -> Just fields
    _ -> Nothing
  textAt name fields = case KeyMap.lookup (Key.fromText name) fields of
    Just (String text) -> Just text
    _ -> Nothing
  numberAt name fields = case KeyMap.lookup (Key.fromText name) fields of
    Just number@(Number _) -> case fromJSON number of
      Success value -> Just value
      _ -> Nothing
    _ -> Nothing
  messageText value = case value of
    Array items -> Text.intercalate "\n" [text | String text <- toList items]
    String text -> text
    _ -> ""

twins :: [Twin]
twins =
  [ Twin "detected-apple-amd64"
      (Text.unlines ["module Legal where", "import Amoebius.Vocabulary", "", "value :: Either HostRefusal Detected", "value = mkDetected Apple Arm64"])
      (Text.unlines ["module Illegal where", "import Amoebius.Vocabulary", "", "value :: Detected", "value = Detected Apple Amd64"])
      1928 5 9 ["Illegal term-level use of the type constructor `Detected'", "Amoebius.Vocabulary"]
  , Twin "bound-deployment-outside-lower"
      (Text.unlines ["module Legal where", "import Amoebius.Capability.Types (BoundDeployment)", "import Amoebius.Dsl.Lower", "import Amoebius.Dsl.Spec (RootInForceSpec)", "", "fromRoot :: RootInForceSpec -> Either LowerRefusal BoundDeployment", "fromRoot root = loweredDeployment <$> lowerDeployment root"])
      (Text.unlines ["module Illegal where", "import Amoebius.Capability.Types", "", "forged :: BoundDeployment", "forged = BoundDeployment { boundDeploymentApps = [] }"])
      1928 5 28 ["Illegal term-level use of the type constructor `BoundDeployment'", "Amoebius.Capability.Types"]
  , Twin "bound-deployment-internal-hidden"
      (Text.unlines ["module Legal where", "import Amoebius.Capability.Types (BoundDeployment)", "", "value :: Maybe BoundDeployment", "value = Nothing"])
      (Text.unlines ["module Illegal where", "import Amoebius.Capability.Types.Internal (BoundDeployment (..))", "", "value :: Maybe BoundDeployment", "value = Nothing"])
      87110 2 1 ["Amoebius.Capability.Types.Internal"]
  , Twin "step-carries-io"
      (Text.unlines ["{-# LANGUAGE OverloadedStrings #-}", "module Legal where", "import Amoebius.Kernel.Step", "", "legal :: Either StepRefusal Step", "legal = mkStep \"x\" ImmediateFrame DockerBuild []"])
      (Text.unlines ["{-# LANGUAGE OverloadedStrings #-}", "module Illegal where", "import Amoebius.Kernel.Step", "", "forged :: Either StepRefusal Step", "forged = mkStep \"x\" ImmediateFrame (ApplyObjects (putStrLn \"x\")) []"])
      83865 6 37 ["IO () -> StepKind", "ApplyObjects"]
  , Twin "two-server-quorum"
      (Text.unlines ["module Legal where", "import Amoebius.Dsl.Topology", "", "legal :: ServerQuorum", "legal = mkServerQuorum OddThreeToken"])
      (Text.unlines ["module Illegal where", "import Amoebius.Dsl.Topology", "", "forged :: ServerQuorum", "forged = mkServerQuorum OddTwoToken"])
      88464 5 25 ["OddTwoToken"]
  , Twin "unit-mismatch"
      (Text.unlines ["{-# LANGUAGE DataKinds #-}", "module Legal where", "import Amoebius.Capacity.Vector", "import Amoebius.Vocabulary", "", "twoProcessors :: ResourceVector -> Quantity 'CpuUnit", "twoProcessors vector = resourceCpu vector + resourceCpu vector"])
      (Text.unlines ["{-# LANGUAGE DataKinds #-}", "module Illegal where", "import Amoebius.Capacity.Vector", "import Amoebius.Vocabulary", "", "mixed :: ResourceVector -> Quantity 'CpuUnit", "mixed vector = resourceCpu vector + resourceMemory vector"])
      83865 7 37 ["MemoryUnit", "CpuUnit"]
  , Twin "render-without-witness"
      (Text.unlines ["module Legal where", "import Amoebius.Capacity.RenderSource (ProvisionedRenderSourceSet)", "import Amoebius.Manifest.K8sObject (K8sObject)", "import Amoebius.Manifest.Render (RenderRefusal, renderCandidates)", "import Amoebius.Placement.Witness (Epoch, Placed)", "", "render :: Placed -> Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]", "render = renderCandidates"])
      (Text.unlines ["module Illegal where", "import Amoebius.Capacity.RenderSource (ProvisionedRenderSourceSet)", "import Amoebius.Manifest.K8sObject (K8sObject)", "import Amoebius.Manifest.Render (RenderRefusal, renderCandidates)", "import Amoebius.Placement.Witness (Epoch)", "", "render :: Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]", "render = renderCandidates"])
      83865 8 10 ["Placed", "Epoch"]
  , Twin "placed-outside-fold"
      (Text.unlines ["module Legal where", "import Amoebius.Capacity.Types (PlacementError, Workload)", "import Amoebius.Dsl.Topology (Topology)", "import Amoebius.Placement.Witness (Placed, place)", "", "placed :: Topology -> [Workload] -> Either PlacementError Placed", "placed = place"])
      (Text.unlines ["module Illegal where", "import Amoebius.Capacity.Types (Placement)", "import Amoebius.Placement.Witness (Placed)", "", "forged :: Placement -> Placed", "forged = Placed"])
      1928 6 10 ["Illegal term-level use of the type constructor `Placed'", "Amoebius.Placement.Witness"]
  , Twin "claim-outside-statefulset"
      (Text.unlines ["module Legal where", "import Amoebius.Manifest.Types (ObjectSpec (..))", "", "isClaim :: ObjectSpec -> Bool", "isClaim spec = case spec of", "  ClaimSpec _ -> True", "  _ -> False"])
      (Text.unlines ["{-# LANGUAGE OverloadedStrings #-}", "module Illegal where", "import Amoebius.Manifest.Types (ClaimBody, ObjectSpec (..))", "", "forged :: ObjectSpec", "forged = ClaimSpec (ClaimBody \"class\" 1 \"volume\" \"owner\")"])
      1928 6 21 ["Illegal term-level use of the type constructor `ClaimBody'", "Amoebius.Manifest.Types"]
  , Twin "volume-outside-witness"
      (Text.unlines ["module Legal where", "import Amoebius.Storage.Witness (VolumeRefusal, VolumeWitness, mkVolumeWitness)", "import Amoebius.Vocabulary (Quantity (Quantity))", "import Data.Text (Text)", "", "volume :: Text -> Text -> Either VolumeRefusal VolumeWitness", "volume namespace statefulSet = mkVolumeWitness namespace statefulSet 0 (Quantity 1)"])
      (Text.unlines ["module Illegal where", "import Amoebius.Storage.Witness (VolumeWitness)", "", "forged :: VolumeWitness", "forged = VolumeWitness"])
      1928 5 10 ["Illegal term-level use of the type constructor `VolumeWitness'", "Amoebius.Storage.Witness"]
  ]
