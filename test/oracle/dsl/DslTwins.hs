{-# LANGUAGE OverloadedStrings #-}

-- | The compile-negative twins. Each pair is authored here, written beneath the suite
-- directory, and handed to the compiler: the legal twin must compile clean, and the illegal
-- twin must draw exactly one error at the pinned line and column with the pinned code and
-- message. Nothing here is tracked.
module DslTwins
  ( twinRows
  , Diagnostic (..), compileWithLibraries
  ) where

import Control.Exception (SomeException, try)
import Data.Aeson (Result (Success), Value (..), eitherDecodeStrict', fromJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.Foldable (toList)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslParse (Row, check)
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
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

twinRows :: Maybe FilePath -> FilePath -> FilePath -> IO [Row]
twinRows compiler buildDirectory suite = mapM (observe compiler buildDirectory suite) twins

observe :: Maybe FilePath -> FilePath -> FilePath -> Twin -> IO Row
observe compiler buildDirectory suite twin = do
  let directory = suite </> "compiler-negative" </> Text.unpack (twinName twin)
  createDirectoryIfMissing True directory
  legal <- compile compiler buildDirectory directory "Legal" (twinLegal twin)
  illegal <- compile compiler buildDirectory directory "Illegal" (twinIllegal twin)
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

compile :: Maybe FilePath -> FilePath -> FilePath -> Text -> Text -> IO (Maybe (ExitCode, [Diagnostic]))
compile = compileWithLibraries testedLibraries

compileWithLibraries :: [Text] -> Maybe FilePath -> FilePath -> FilePath -> Text -> Text -> IO (Maybe (ExitCode, [Diagnostic]))
compileWithLibraries libraries compiler buildDirectory directory name source = do
  let path = directory </> Text.unpack name <> ".hs"
  createDirectoryIfMissing True (directory </> Text.unpack name <> "-out")
  writeFile path (Text.unpack source)
  packageIds <- acquiredPackageIds libraries (buildDirectory </> "cache" </> "plan.json")
  let compilerOptions = maybe [] (\executable -> ["--with-compiler=" <> executable]) compiler
      compilerExecutable = maybe "ghc" id compiler
      arguments ids = ["exec", "--jobs=1", "--builddir=" <> buildDirectory] <> compilerOptions <> ["--", compilerExecutable, "-j1", "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"] <> concatMap (\identity -> ["-package-id", identity]) ids <> ["-outputdir", directory </> Text.unpack name <> "-out", path]
  outcome <- try (case packageIds of
    Left problem -> fail (Text.unpack problem)
    Right ids -> readProcessWithExitCode "cabal" (arguments ids) "") :: IO (Either SomeException (ExitCode, String, String))
  workingDirectory <- getCurrentDirectory
  writeFile (directory </> Text.unpack name <> ".cwd") workingDirectory
  case outcome of
    Right (_, output, errors) -> do
      writeFile (directory </> Text.unpack name <> ".stdout") output
      writeFile (directory </> Text.unpack name <> ".stderr") errors
    Left problem -> writeFile (directory </> Text.unpack name <> ".stderr") (show problem)
  pure $ case outcome of
    Left _ -> Nothing
    Right (code, _, errors) -> Just (code, [item | line <- Text.lines (Text.pack errors), Just item <- [diagnosticOf line]])

-- | The compiler tests these shipped public libraries as subjects. The
-- independent oracle executable itself imports none of them. Cabal's exec
-- environment can register a public sublibrary without exposing it; relying
-- on that ambient exposure would mistake a hidden-package error for a type
-- restriction. Non-exposed Internal modules remain inaccessible.
testedLibraries :: [Text]
testedLibraries =
  ["vocabulary", "capacity-topology", "capability-bind", "dsl-spine", "dsl-core", "kernel-steps", "manifest-render", "provision-seal", "storage-geometry-folds"]

-- | Build metadata supplies unit identities, never a semantic expectation.
-- Every independently named library must join exactly once; GHC still checks
-- that the selected unit exists and exposes the imported public module.
acquiredPackageIds :: [Text] -> FilePath -> IO (Either Text [String])
acquiredPackageIds libraries path = do
  bytes <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  pure $ case bytes of
    Left problem -> Left (Text.pack (show problem))
    Right contents -> case eitherDecodeStrict' contents of
      Right (Object root) | Just (Array units) <- KeyMap.lookup "install-plan" root -> traverse (unique (toList units)) libraries
      _ -> Left "compiler package plan absent or malformed"
 where
  unique units library = case
    [ Text.unpack identity
    | Object unit <- units
    , KeyMap.lookup "pkg-name" unit == Just (String "amoebius")
    , KeyMap.lookup "component-name" unit == Just (String ("lib:" <> library))
    , Just (String identity) <- [KeyMap.lookup "id" unit]
    , not (Text.null identity)
    ] of
      [identity] -> Right identity
      _ -> Left ("compiler package plan has no unique unit for " <> library)

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
  , Twin "profile-outside-catalog"
      (Text.unlines ["module Legal where", "import Amoebius.Vocabulary", "", "value :: SubstrateProfile", "value = substrateProfile Apple"])
      (Text.unlines ["module Illegal where", "import Amoebius.Vocabulary", "", "value :: SubstrateProfile", "value = SubstrateProfile"])
      1928 5 9 ["Illegal term-level use of the type constructor `SubstrateProfile'", "Amoebius.Vocabulary"]
  , Twin "base-channel-outside-catalog"
      (Text.unlines ["{-# LANGUAGE OverloadedStrings #-}", "module Legal where", "import Amoebius.Image.BaseChannel", "", "value :: Either BaseChannelError BaseChannel", "value = mkBaseChannel \"ubuntu:24.04\""])
      (Text.unlines ["module Illegal where", "import Amoebius.Image.BaseChannel", "", "value :: BaseChannel", "value = BaseChannel"])
      1928 5 9 ["Illegal term-level use of the type constructor `BaseChannel'", "Amoebius.Image.BaseChannel"]
  , Twin "profile-record-update"
      (Text.unlines ["module Legal where", "import Amoebius.Vocabulary", "", "value :: Maybe Architecture", "value = profileRequiredArchitecture (substrateProfile Apple)"])
      (Text.unlines ["module Illegal where", "import Amoebius.Vocabulary", "", "value = (substrateProfile Apple)", "  { profileRequiredArchitecture = Nothing }"])
      22385 5 5 ["Not in scope: record field `profileRequiredArchitecture'"]
  , Twin "base-channel-record-update"
      (Text.unlines ["module Legal where", "import Amoebius.Image.BaseChannel", "import Data.Text (Text)", "render :: BaseChannel -> Text", "render = renderBaseChannel"])
      (Text.unlines ["module Illegal where", "import Amoebius.Image.BaseChannel", "", "update value = value", "  { renderBaseChannel = undefined }"])
      22385 5 5 ["Not in scope: record field `renderBaseChannel'"]
  , Twin "base-resolution-outside-factory"
      (Text.unlines ["module Legal where", "import Amoebius.Image.BaseChannel", "import Data.Text (Text)", "make :: BaseChannel -> Text -> ResolutionSource -> Either BaseChannelError BaseResolution", "make = mkBaseResolution"])
      (Text.unlines ["module Illegal where", "import Amoebius.Image.BaseChannel", "", "value :: BaseResolution", "value = BaseResolution"])
      1928 5 9 ["Illegal term-level use of the type constructor `BaseResolution'", "Amoebius.Image.BaseChannel"]
  , Twin "base-resolution-record-update"
      (Text.unlines ["module Legal where", "import Amoebius.Image.BaseChannel", "import Data.Text (Text)", "digest :: BaseResolution -> Text", "digest = resolvedDigest"])
      (Text.unlines ["module Illegal where", "import Amoebius.Image.BaseChannel", "", "update value = value", "  { resolvedDigest = undefined }"])
      22385 5 5 ["Not in scope: record field `resolvedDigest'"]
  , Twin "detected-generic"
      (Text.unlines ["module Legal where", "import Amoebius.Vocabulary", "", "value :: Detected", "value = linuxCpuDetected Amd64"])
      (Text.unlines ["module Illegal where", "import Amoebius.Vocabulary", "import GHC.Generics (to)", "", "value :: Detected", "value = to undefined"])
      39999 6 9 ["Generic Detected"]
  , Twin "profile-generic"
      (Text.unlines ["module Legal where", "import Amoebius.Vocabulary", "", "value :: SubstrateProfile", "value = substrateProfile Apple"])
      (Text.unlines ["module Illegal where", "import Amoebius.Vocabulary", "import GHC.Generics (to)", "", "value :: SubstrateProfile", "value = to undefined"])
      39999 6 9 ["Generic SubstrateProfile"]
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
      (Text.unlines ["module Legal where", "import Amoebius.Dsl.Topology", "", "legal :: Rke2Quorum Int", "legal = Three 1 2 3"])
      (Text.unlines ["module Illegal where", "import Amoebius.Dsl.Topology", "", "forged :: Rke2Quorum Int", "forged = Two 1 2"])
      88464 5 10 ["Two"]
  , Twin "unit-mismatch"
      (Text.unlines ["{-# LANGUAGE DataKinds #-}", "module Legal where", "import Amoebius.Capacity.Vector", "import Amoebius.Vocabulary", "", "twoProcessors :: ResourceVector -> Quantity 'CpuUnit", "twoProcessors vector = resourceCpu vector + resourceCpu vector"])
      (Text.unlines ["{-# LANGUAGE DataKinds #-}", "module Illegal where", "import Amoebius.Capacity.Vector", "import Amoebius.Vocabulary", "", "mixed :: ResourceVector -> Quantity 'CpuUnit", "mixed vector = resourceCpu vector + resourceMemory vector"])
      83865 7 37 ["MemoryUnit", "CpuUnit"]
  , Twin "render-without-witness"
      (Text.unlines ["module Legal where", "import Amoebius.Capacity.RenderSource (ProvisionedRenderSourceSet)", "import Amoebius.Manifest.K8sObject (K8sObject)", "import Amoebius.Manifest.Render (RenderRefusal, ScopeAuthorities, renderCandidates)", "import Amoebius.Placement.Witness (Epoch, Placed)", "", "render :: ScopeAuthorities -> Placed -> Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]", "render = renderCandidates"])
      (Text.unlines ["module Illegal where", "import Amoebius.Capacity.RenderSource (ProvisionedRenderSourceSet)", "import Amoebius.Manifest.K8sObject (K8sObject)", "import Amoebius.Manifest.Render (RenderRefusal, ScopeAuthorities, renderCandidates)", "import Amoebius.Placement.Witness (Epoch)", "", "render :: ScopeAuthorities -> Epoch -> ProvisionedRenderSourceSet -> Either RenderRefusal [K8sObject]", "render = renderCandidates"])
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
