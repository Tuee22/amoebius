{-# LANGUAGE OverloadedStrings #-}
-- | Portable version observations and retained pure probes. Toolchain version
-- admission is deliberately independent of OS, architecture and executable bytes.
module Amoebius.Toolchain.Report (ReportOptions (..), parseReportOptions, reportRows, runToolchainReport) where
import Amoebius.Toolchain.Acquire
import Amoebius.Toolchain.Versions
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
  { optionTools :: ToolchainPaths, optionOutput :: Maybe FilePath
  , optionProbeRoot :: Maybe FilePath, optionAcquireRoot :: Maybe FilePath
  , optionRequest :: Maybe FilePath, optionWriteRequest :: Maybe FilePath
  } deriving (Eq, Show)
parseReportOptions :: [String] -> Either Text ReportOptions
parseReportOptions = go (ReportOptions defaultToolchainPaths Nothing Nothing Nothing Nothing Nothing)
 where
  go options arguments = case arguments of
    [] -> Right options
    ("--ghcup" : value : rest) -> go options {optionTools = (optionTools options) {pathGhcup = Just value}} rest
    ("--ghc" : value : rest) -> go options {optionTools = (optionTools options) {pathGhc = Just value}} rest
    ("--cabal" : value : rest) -> go options {optionTools = (optionTools options) {pathCabal = Just value}} rest
    ("--output" : value : rest) -> go options {optionOutput = Just value} rest
    ("--probe-root" : value : rest) -> go options {optionProbeRoot = Just value} rest
    ("--acquire" : value : rest) -> go options {optionAcquireRoot = Just value} rest
    ("--request" : value : rest) -> go options {optionRequest = Just value} rest
    ("--write-request" : value : rest) -> go options {optionWriteRequest = Just value} rest
    (word : _) -> Left ("toolchain-report: unknown argument " <> Text.pack word)
runToolchainReport :: [String] -> IO ()
runToolchainReport arguments = case parseReportOptions arguments of
  Left problem -> hPutStrLn stderr (Text.unpack problem) >> exitWith (ExitFailure 2)
  Right options -> case optionWriteRequest options of
    Just path -> do
      createDirectoryIfMissing True (takeDirectory path)
      TextIO.writeFile path "label\t0b5e17e11a0c0ffee0de1e9a7e5ba5ed\nghc.requested-version\t9.12.4\n"
    Nothing -> do
      rows <- reportRows options
      let rendered = Text.unlines [key <> "\t" <> value | (key, value) <- rows]
      case optionOutput options of
        Nothing -> TextIO.putStr rendered
        Just path -> createDirectoryIfMissing True (takeDirectory path) >> TextIO.writeFile path rendered
reportRows :: ReportOptions -> IO [(Text, Text)]
reportRows options = do
  here <- getCurrentDirectory
  let probeRoot = fromMaybe (here </> ".build" </> "toolchain-probe") (optionProbeRoot options)
  observed <- selectToolchain here (optionTools options)
  retained <- retainedProbeRows probeRoot probeCases
  paths <- authoredPaths here
  resolutionFindings <- inspectTrackedArtefacts here
  request <- case optionRequest options of
    Nothing -> pure []
    Just path -> do
      rows <- map (Text.splitOn "\t") . Text.lines <$> TextIO.readFile path
      let labels = [value | ["label", value] <- rows]
          versions = [value | ["ghc.requested-version", value] <- rows]
          verdict = case (labels, versions) of
            ([_], [version]) -> either renderVersionRefusal (const "accepted") (checkVersion ghcRequirement version)
            _ -> "RequestMalformed"
      pure [("request.label", Text.intercalate "," labels), ("request.verdict", verdict)]
  let admission = case observed of
        Left refusals -> [("versions.verdict", "refused"), ("versions.refusals", Text.intercalate "; " (map renderRefusal refusals))]
        Right selected -> ("versions.verdict", "accepted") : renderAcquisition selected
      probes = [("probe." <> name, value) | (name, value) <- retained]
        <> [("probe.source.findings", Text.intercalate ";" (probeSourceFindings paths (map fst retained)))]
      planning = [("plan.steps", either (Text.intercalate "; " . map renderPlanRefusal) (Text.intercalate "; " . map renderStep) (planEnsure examplePlatform (Inventory []) probeCatalogue floorTools)), ("resolution.source.findings", Text.intercalate ";" (map renderResolveRefusal resolutionFindings))]
      provenance = [("provenance.upstream", upstreamName forkUpstream <> "-" <> upstreamVersion forkUpstream <> " " <> upstreamTreeDigest forkUpstream), ("provenance.fork-modules", Text.pack (show (length forkModules))), ("provenance.layout", Text.intercalate ";" (map renderProvenanceRefusal (refuseLayout paths)))]
  acquired <- case optionAcquireRoot options of
    Nothing -> pure []
    Just root -> do
      admitted <- admitGeneratedRoot root
      case admitted of
        Left problem -> pure [("acquisition.verdict", renderResolveRefusal problem)]
        Right owned -> do
          result <- acquireTwice (optionTools options) (owned </> "a") (owned </> "b")
          case result of
            Left problems -> pure [("acquisition.verdict", Text.intercalate "; " (map renderRefusal problems))]
            Right (first, second) -> do
              firstPlan <- elaborateProbe first (owned </> "plan-a") probeRequirements
              secondPlan <- elaborateProbe second (owned </> "plan-b") probeRequirements
              let planVerdict = case (firstPlan, secondPlan) of
                    (Right (a, _), Right (b, _)) -> case planAgreement a b of
                      [] -> "agree"
                      problems -> Text.intercalate "; " (map renderResolveRefusal problems)
                    _ -> "plans-unavailable"
                  observations name plan =
                    [(name <> ".verdict", either renderResolveRefusal (const "accepted") plan)
                    ,(name <> ".sha256", either (const "absent") (planDigest . fst) plan)
                    ,(name <> ".units", either (const "absent") (Text.intercalate "," . planUnits . fst) plan)
                    ,(name <> ".packages", either (const "absent") (Text.intercalate "," . planPackages . fst) plan)
                    ,(name <> ".child", either (const "absent") (Text.pack . show . snd) plan)]
              pure ([("acquisition.verdict", "agree"), ("acquisition.plans.verdict", planVerdict)]
                <> observations "acquisition.plan-a" firstPlan <> observations "acquisition.plan-b" secondPlan)
  pure (admission <> request <> probes <> planning <> provenance <> acquired)
