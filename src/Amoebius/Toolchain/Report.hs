{-# LANGUAGE OverloadedStrings #-}

-- | The @amoebius toolchain-report@ subcommand (phase_01, Sprint 1.8).
--
-- The shipped binary reports what it observes: each pin's size and digest,
-- whether the publisher manifests agree with the pins, whether the signatures
-- verify against the operator keyring, the identities the pins name, and the
-- outcome of every in-process probe. With @--acquire ROOT@ it also performs the
-- two contained acquisitions and elaborates their plans. Every observation is a
-- row; a refusal is a row too, and the exit is zero whenever the report was
-- written, because the report is an observation and the oracle holds the verdict.
module Amoebius.Toolchain.Report
  ( ReportOptions (..)
  , parseReportOptions
  , reportRows
  , runToolchainReport
  ) where

import Amoebius.Toolchain.Acquire
import Amoebius.Toolchain.Pins
import Amoebius.Toolchain.Probe
import Amoebius.Toolchain.Provenance
import Amoebius.Toolchain.Resolve
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.IO (hPutStrLn, stderr)

data ReportOptions = ReportOptions
  { optionInputs :: Maybe FilePath
  , optionCompilerManifest :: Maybe FilePath
  , optionPackageToolManifest :: Maybe FilePath
  , optionOutput :: Maybe FilePath
  , optionProbeRoot :: Maybe FilePath
  , optionAcquireRoot :: Maybe FilePath
  }
  deriving (Eq, Show)

-- | @--name value@ pairs; anything else is a usage error.
parseReportOptions :: [String] -> Either Text ReportOptions
parseReportOptions = go (ReportOptions Nothing Nothing Nothing Nothing Nothing Nothing)
 where
  go options arguments = case arguments of
    [] -> Right options
    ("--inputs" : value : rest) -> go options {optionInputs = Just value} rest
    ("--compiler-manifest" : value : rest) -> go options {optionCompilerManifest = Just value} rest
    ("--package-tool-manifest" : value : rest) -> go options {optionPackageToolManifest = Just value} rest
    ("--output" : value : rest) -> go options {optionOutput = Just value} rest
    ("--probe-root" : value : rest) -> go options {optionProbeRoot = Just value} rest
    ("--acquire" : value : rest) -> go options {optionAcquireRoot = Just value} rest
    (word : _) -> Left ("toolchain-report: unknown argument " <> Text.pack word)

runToolchainReport :: [String] -> IO ()
runToolchainReport arguments = case parseReportOptions arguments of
  Left problem -> do
    hPutStrLn stderr (Text.unpack problem)
    hPutStrLn stderr "usage: amoebius toolchain-report [--inputs DIR] [--compiler-manifest PATH] [--package-tool-manifest PATH] [--output PATH] [--probe-root DIR] [--acquire ROOT]"
    exitWith (ExitFailure 2)
  Right options -> do
    rows <- reportRows options
    let rendered = Text.unlines [key <> "\t" <> value | (key, value) <- rows]
    case optionOutput options of
      Nothing -> TextIO.putStr rendered
      Just path -> do
        createDirectoryIfMissing True (takeDirectory path)
        TextIO.writeFile path rendered

-- | The report as rows. Pins and manifests first, then signatures, identities,
-- the probes, the planner, the provenance identity, and the acquisitions.
reportRows :: ReportOptions -> IO [(Text, Text)]
reportRows options = do
  here <- getCurrentDirectory
  inputs <- maybe (fromMaybe (here </> inputsDirectory) <$> locateInputs here) pure (optionInputs options)
  let overrides = [(CompilerManifest, path) | Just path <- [optionCompilerManifest options]] <> [(PackageToolManifest, path) | Just path <- [optionPackageToolManifest options]]
      probeRoot = fromMaybe (takeDirectory inputs </> "probe") (optionProbeRoot options)
  pins <- verifyPinsWith inputs overrides
  (signatures, signatureChildren) <- verifySignatures inputs
  decodes <- decodeProbe (probeRoot </> "decode")
  bridge <- bridgeProbe (probeRoot </> "purs")
  let pinRows = case pins of
        Right verified ->
          [("pins.verdict", "ok")]
            <> [("pin." <> Text.pack (pinName pin), "ok bytes=" <> Text.pack (show (pinBytes pin)) <> " sha256=" <> digest) | (pin, digest) <- verifiedObserved verified]
            <> [("manifest." <> renderPinRole role, "agrees claimed=" <> claimed) | (role, claimed) <- verifiedClaimed verified]
        Left refusals -> ("pins.verdict", "refused") : [("pins.refusal." <> Text.pack (show index), renderRefusal refusal) | (index, refusal) <- zip [1 :: Int ..] refusals]
      identityRows =
        [ ("identity.compiler", toolName compilerIdentity <> " " <> toolVersion compilerIdentity <> " " <> toolSha256 compilerIdentity)
        , ("identity.package-tool", toolName packageToolIdentity <> " " <> toolVersion packageToolIdentity <> " " <> toolSha256 packageToolIdentity)
        , ("identity.platform", renderPlatform platform)
        , ("identity.pins", Text.pack (show (length genesisPins)))
        ]
      signatureRows = [("signature." <> Text.pack (show index), renderSignature result) | (index, result) <- zip [1 :: Int ..] signatures] <> [("signature.child." <> Text.pack (show index), renderChild child) | (index, child) <- zip [1 :: Int ..] signatureChildren]
      probeRows =
        [("probe.decode." <> name, renderDecodeOutcome outcome) | (name, outcome) <- decodes]
          <> [ ("probe.sim.clean", simProbe cleanSchedule)
             , ("probe.sim.perturbed", simProbe perturbedSchedule)
             , ("probe.sim.schedule.clean", renderSchedule cleanSchedule)
             , ("probe.sim.schedule.perturbed", renderSchedule perturbedSchedule)
             , ("probe.codegen.link-token", linkToken)
             , ("probe.bridge.files", Text.intercalate "," (map Text.pack bridge))
             ]
      planRows = case planEnsure platform (Inventory []) probeCatalogue floorTools of
        Right steps -> [("plan.steps", Text.intercalate "; " (map renderStep steps))]
        Left refusals -> [("plan.refused", Text.intercalate "; " (map renderPlanRefusal refusals))]
      provenanceRows =
        [ ("provenance.upstream", upstreamName forkUpstream <> "-" <> upstreamVersion forkUpstream <> " " <> upstreamTreeDigest forkUpstream)
        , ("provenance.fork-modules", Text.pack (show (length forkModules)))
        , ("provenance.requirements", Text.intercalate "; " (map renderRequirement probeRequirements))
        ]
  acquisitionRows <- case (pins, optionAcquireRoot options) of
    (Right verified, Just root) -> do
      acquired <- acquireTwice verified (root </> "a") (root </> "b")
      case acquired of
        Left refusals -> pure [("acquisition.verdict", "refused"), ("acquisition.refusals", Text.intercalate "; " (map renderRefusal refusals))]
        Right (a, b) -> do
          planA <- elaborate a (root </> "a" </> "resolve") probeRequirements
          planB <- elaborate b (root </> "b" </> "resolve") probeRequirements
          _ <- writeAcquisitionReceipt a
          _ <- writeAcquisitionReceipt b
          removeAcquisition a
          removeAcquisition b
          pure
            ( [("acquisition.verdict", "agree")]
                <> [("acquisition.a." <> key, value) | (key, value) <- renderAcquisition a]
                <> [("acquisition.b." <> key, value) | (key, value) <- renderAcquisition b]
                <> [("plan.a", either renderResolveRefusal (planDigest . fst) planA), ("plan.b", either renderResolveRefusal (planDigest . fst) planB)]
            )
    _ -> pure []
  pure (pinRows <> identityRows <> signatureRows <> probeRows <> planRows <> provenanceRows <> acquisitionRows)
