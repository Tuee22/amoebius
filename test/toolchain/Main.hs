{-# LANGUAGE OverloadedStrings #-}
-- | Native observations and supplied version/platform fixtures. This producer
-- never needs a Linux host, archive/signature files, devices, or a VM/container.
module Main (main) where
import Amoebius.Toolchain.Acquire
import Amoebius.Toolchain.Versions
import Amoebius.Toolchain.Probe
import Amoebius.Toolchain.Provenance
import Amoebius.Toolchain.Report
import Amoebius.Toolchain.Resolve
import Control.Exception (finally)
import Control.Monad (forM, forM_, when)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectory, createDirectoryIfMissing, copyFile, doesPathExist, findExecutable, getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.Environment (getArgs, getExecutablePath, getProgName)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (dropExtension, takeExtension, takeDirectory, (</>))

main :: IO ()
main = do
  rawProgram <- getProgName
  let program = if takeExtension rawProgram == ".exe" then dropExtension rawProgram else rawProgram
  case program of
    "bad-ghc" -> putStrLn "9.10.1"
    "bad-ghcup" -> putStrLn "0.1.50.1"
    "malformed-ghcup" -> putStrLn "unparseable"
    "failed-ghc" -> exitWith (ExitFailure 9)
    "failed-cabal" -> exitWith (ExitFailure 9)
    "toolchain-report" -> getArgs >>= runToolchainReport
    _ | Just (code, response) <- lookup program admissionResponses -> do
          arguments <- getArgs
          let expected = if "ghcup" `isSuffixOf` program then ["--version"] else ["--numeric-version"]
          if arguments == expected then putStr response >> exitWith (if code == 0 then ExitSuccess else ExitFailure code)
            else exitWith (ExitFailure 2)
      | "admission-" `isPrefixOf` program -> exitWith (ExitFailure 2)
      | otherwise -> do
          arguments <- getArgs
          case arguments of
            ["--native-tool-versions", output] -> writeAdmission output
            ["--probe-source", output] -> writeProbeSource output
            ["--vendor-source", output] -> writeVendorSource output
            _ -> do
              directory <- makeAbsolute (case arguments of [path] -> path; _ -> ".build/components/toolchain-versions")
              createDirectoryIfMissing True directory
              root <- getCurrentDirectory
              rows <- observations root directory
              TextIO.writeFile (directory </> "toolchain.tsv") (Text.unlines [key <> "\t" <> value | (key, value) <- rows])

-- Native boundary inputs only: even a failed command can print a compatible version.
admissionResponses :: [(String, (Int, String))]
admissionResponses =
  [("admission-good-ghcup", (0, "0.2.6.2")), ("admission-good-ghc", (0, "9.12.4"))
  ,("admission-failed-ghcup", (9, "0.2.6.2")), ("admission-failed-ghc", (9, "9.12.4"))
  ,("admission-malformed-ghcup", (0, "unparseable")), ("admission-malformed-ghc", (0, "unparseable"))
  ,("admission-unsupported-ghcup", (0, "0.3.0")), ("admission-unsupported-ghc", (0, "9.10.1"))
  ,("admission-cabal", (9, ""))]

writeAdmission :: FilePath -> IO ()
writeAdmission output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  image <- getExecutablePath
  root <- getCurrentDirectory
  let fixtures = directory </> "admission-tools"
      suffix = if takeExtension image == ".exe" then ".exe" else ""
      toolName :: AdmissionTool -> String
      toolName InstallerTool = "ghcup"
      toolName CompilerTool = "ghc"
      faultName fault = case fault of MissingAdmissionTool -> "missing"; FailedAdmissionCommand -> "failed"; MalformedAdmissionVersion -> "malformed"; UnsupportedAdmissionVersion -> "unsupported"
  present <- doesPathExist fixtures
  when present (fail "AdmissionFixtureRootNotFresh")
  createDirectory fixtures
  observations' <- (do
    forM_ admissionResponses $ \(name, _) -> copyFile image (fixtures </> name <> suffix)
    rows <- concat <$> forM admissionExamples (\(name, tool, fault) -> forM [False, True] $ \negative -> do
      let selected role = fixtures </> "admission-" <> (if negative && role == tool then faultName fault else "good") <> "-" <> toolName role <> suffix
          paths = ToolchainPaths (Just (selected InstallerTool)) (Just (selected CompilerTool)) (Just (fixtures </> "admission-cabal" <> suffix))
          control = if negative then "negative" else "positive"
      result <- selectToolchain root paths
      let rendered = either (Text.intercalate "," . map (Text.takeWhile (/= ':') . renderRefusal)) (const "accepted") result
      pure ([name, Text.pack (toolName tool), control, rendered], (name, toolName tool, control, result)))
    TextIO.writeFile (directory </> "admission-raw.data") (Text.pack (show (map snd rows)))
    pure rows)
    `finally` removePathForcibly fixtures
  removed <- not <$> doesPathExist fixtures
  TextIO.writeFile (directory </> "admission.tsv") (Text.unlines (map (Text.intercalate "\t")
    (map fst observations' <> [["control", "cleanup", "observed", Text.pack (show removed)]])))

-- Run foreign-source reintroductions as files in a copied probe tree. Discovery
-- reads that tree; it never trusts a supplied count or a fixture's claimed role.
writeProbeSource :: FilePath -> IO ()
writeProbeSource output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- probeSourcePaths <$> authoredPaths root
  let fixtures = directory </> "probe-source-tree"
  present <- doesPathExist fixtures
  when present (fail "ProbeSourceFixtureRootNotFresh")
  createDirectory fixtures
  raw <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (fixtures </> path))
      copyFile (root </> path) (fixtures </> path)
    concat <$> forM probeSourceExamples (\(name, variant, fault) -> forM [False, True] $ \negative -> do
      let foreignFile = case fault of ForeignProbeScript path bytes -> Just (path, bytes); ForeignProbeFixture path bytes -> Just (path, bytes); _ -> Nothing
          selected = case fault of OmittedProbeCase value | negative -> filter (/= value) probeCases; _ -> probeCases
          control = if negative then "negative" else "positive"
          generated = directory </> "probe-source-generated" </> Text.unpack name </> Text.unpack variant </> Text.unpack control
      forM_ [entry | Just entry <- [foreignFile], negative] $ \(path, bytes) -> do
        createDirectoryIfMissing True (takeDirectory (fixtures </> path))
        TextIO.writeFile (fixtures </> path) bytes
      observedPaths <- sort <$> authoredPaths fixtures
      observed <- retainedProbeRows generated selected
      bytes <- case foreignFile of Just (path, _) | negative -> TextIO.readFile (fixtures </> path); _ -> pure ""
      let findings = probeSourceFindings observedPaths (map fst observed)
      -- Force observations before removing the generated source input.
      TextIO.writeFile (directory </> "probe-source-current.data") (Text.pack (show (observedPaths, observed, findings, bytes)))
      forM_ [path | Just (path, _) <- [foreignFile], negative] (removePathForcibly . (fixtures </>))
      pure (name, variant, control, observedPaths, observed, findings, bytes)))
    `finally` removePathForcibly fixtures
  let names = map probeCaseName probeCases
      controls = [("empty", probeSourceFindings [] names)]
        <> [(Text.pack path, probeSourceFindings (filter (/= path) paths) names) | path <- probeSourceRequiredPaths]
        <> [("duplicate-case", probeSourceFindings paths (names <> ["decode.positive"]))
           ,("unexpected-case", probeSourceFindings paths (names <> ["unknown"]))]
  removed <- not <$> doesPathExist fixtures
  TextIO.writeFile (directory </> "probe-source.data") (Text.pack (show raw))
  TextIO.writeFile (directory </> "probe-source-controls.data") (Text.pack (show controls))
  TextIO.writeFile (directory </> "probe-source-cleanup.data") (Text.pack (show removed))

writeVendorSource :: FilePath -> IO ()
writeVendorSource output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- vendorSourcePaths <$> authoredPaths root
  let fixtures = directory </> "vendor-source-tree"
      release = HackageRelease "supernova" "0.0.3"
      modulePath name = "src/vendor/" <> Text.unpack (Text.replace "." "/" name) <> ".hs"
  present <- doesPathExist fixtures
  when present (fail "VendorSourceFixtureRootNotFresh")
  createDirectory fixtures
  (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (fixtures </> path))
      copyFile (root </> path) (fixtures </> path)
    rows <- concat <$> forM vendorSourceExamples (\(name, variant, fault) -> forM [False, True] $ \negative -> do
      let foreignFile = case fault of ReintroducedVendorFile path bytes -> Just (path, bytes); _ -> Nothing
          reference = case fault of MutableVendorReference value | negative -> value; _ -> release
          control = if negative then "negative" else "positive" :: Text
      forM_ [entry | Just entry <- [foreignFile], negative] $ \(path, bytes) -> do
        createDirectoryIfMissing True (takeDirectory (fixtures </> path))
        TextIO.writeFile (fixtures </> path) bytes
      observedPaths <- sort <$> authoredPaths fixtures
      bytes <- case foreignFile of Just (path, _) | negative -> TextIO.readFile (fixtures </> path); _ -> pure ""
      let findings = map renderProvenanceRefusal (refuseLayout observedPaths)
            <> either ((: []) . renderProvenanceRefusal) (const []) (admitReference reference)
          row = (name, variant, control, observedPaths, findings, renderReference reference, bytes)
      TextIO.writeFile (directory </> "vendor-source-current.data") (Text.pack (show row))
      forM_ [path | Just (path, _) <- [foreignFile], negative] (removePathForcibly . (fixtures </>))
      pure row)
    clean <- map renderProvenanceRefusal <$> verifyFork fixtures
    missing <- forM forkModules $ \name -> do
      let path = modulePath name
      removePathForcibly (fixtures </> path)
      findings <- map renderProvenanceRefusal <$> verifyFork fixtures
      copyFile (root </> path) (fixtures </> path)
      pure (name, findings)
    TextIO.writeFile (directory </> "vendor-source.data") (Text.pack (show rows))
    TextIO.writeFile (directory </> "vendor-fork.data") (Text.pack (show (forkModules, ("clean", clean) : missing))))
    `finally` removePathForcibly fixtures
  removed <- not <$> doesPathExist fixtures
  TextIO.writeFile (directory </> "vendor-source-cleanup.data") (Text.pack (show removed))

observations :: FilePath -> FilePath -> IO [(Text, Text)]
observations root directory = do
  writeAdmission directory
  writeProbeSource directory
  writeVendorSource directory
  selected <- selectToolchain root defaultToolchainPaths
  decodes <- decodeProbe (directory </> "decode")
  bridge <- bridgeProbe (directory </> "purs")
  paths <- authoredPaths root
  fork <- verifyFork root
  image <- getExecutablePath
  (absent, absentOut, absentErr) <- spawnChild root "amoebius-missing-4391860a" []
  (failedCwd, failedOut, failedErr) <- spawnChild (directory </> "absent-cwd") image ["--version"]
  cli <- cliObservations root directory image
  let versions = [("version.case." <> showT index, Text.intercalate "|" [tool, raw, either (Text.takeWhile (/= ':') . renderVersionRefusal) (const "accepted") (checkVersion (if tool == "ghc" then ghcRequirement else ghcupRequirement) raw)]) | (index, (tool, raw)) <- zip [1 :: Int ..] versionExamples]
      probes = [("probe.decode." <> name, renderDecodeOutcome value) | (name, value) <- decodes]
        <> [("probe.sim.clean", simProbe cleanSchedule), ("probe.sim.perturbed", simProbe perturbedSchedule), ("probe.codegen.link-token", linkToken), ("probe.bridge.files", Text.intercalate "," (map Text.pack bridge)), ("fork.modules", showT (length forkModules)), ("fork.problems", none (map renderProvenanceRefusal fork)), ("layout.problems", none (map renderResolveRefusal (refuseTrackedArtefacts paths)))]
      planned = planEnsure examplePlatform (Inventory []) probeCatalogue floorTools
      pureRows = [("plan.steps", either (Text.intercalate "; " . map renderPlanRefusal) (Text.intercalate "; " . map renderStep) planned)
        , ("child.absent.exit", showT (childExit absent)), ("child.absent.stdout", Text.pack absentOut), ("child.absent.stderr", Text.strip (Text.pack absentErr))
        , ("child.failed-cwd.exit", showT (childExit failedCwd)), ("child.failed-cwd.stdout", Text.pack failedOut), ("child.failed-cwd.stderr", Text.strip (Text.pack failedErr))
        , ("negative.TrackedResolutionOutput", none (map renderResolveRefusal (refuseTrackedArtefacts ["cabal.project.freeze"])))
        , ("negative.TrackedProbeInput", none (map renderResolveRefusal (refuseTrackedArtefacts ["test/probe.dhall"])))
        , ("negative.MutableIdentity", either renderProvenanceRefusal renderReference (admitReference (GitBranch "https://github.com/cr-org/supernova" "main")))
        , ("negative.TopLevelVendor", none (map renderProvenanceRefusal (refuseLayout ["vendor/supernova/src/Pulsar.hs"])))
        , ("negative.AbsentTool", either (Text.intercalate "; " . map renderPlanRefusal) (const "accepted") (planEnsure examplePlatform (Inventory []) probeCatalogue [Tool "absent-tool" [1] [2]]))
        , ("negative.OutOfRangeVersion", either (Text.intercalate "; " . map renderPlanRefusal) (const "accepted") (planEnsure examplePlatform (Inventory [("ghc", [9, 10, 1])]) probeCatalogue (take 1 floorTools)))
        , ("negative.NoPlatformAsset", either (Text.intercalate "; " . map renderPlanRefusal) (const "accepted") (planEnsure (Platform "unsupported" "unknown") (Inventory []) probeCatalogue (take 1 floorTools)))]
  actual <- case selected of
    Left refusals -> pure [("versions.verdict", Text.intercalate "; " (map renderRefusal refusals))]
    Right native -> do
      second <- selectToolchain root defaultToolchainPaths
      let agreementRows = [("second.verdict", either (const "refused") (\other -> none (map renderRefusal (agreement native other))) second)]
      let supplied = native {acquisitionGhcupVersion = "0.1.50.2", acquisitionCompilerVersion = "9.12.4"}
          disagreements = [("second.mismatch.ghcup", none (map renderRefusal (agreement supplied supplied {acquisitionGhcupVersion = "0.2.6.2"}))), ("second.mismatch.compiler", none (map renderRefusal (agreement supplied supplied {acquisitionCompilerVersion = "9.10.1"}))), ("second.cabal-version", none (map renderRefusal (agreement supplied supplied {acquisitionPackageToolVersion = "unreported"})))]
          unavailable = directory </> "failed-cabal"
      copyFile image unavailable
      cabalVersionFailure <- selectToolchain root (ToolchainPaths (Just (acquisitionGhcup native)) (Just (acquisitionCompiler native)) (Just unavailable))
      failures <- forM [("MissingTool", "absent-ghc"), ("UnsupportedVersion", "bad-ghc"), ("UnsupportedGhcupVersion", "bad-ghcup"), ("MalformedVersion", "malformed-ghcup"), ("FailedVersionCommand", "failed-ghc")] $ \(label, file) -> do
        let path = directory </> file
            tools = ToolchainPaths (Just (if label `elem` ["MalformedVersion", "UnsupportedGhcupVersion"] then path else acquisitionGhcup native)) (Just (if label `elem` ["MalformedVersion", "UnsupportedGhcupVersion"] then acquisitionCompiler native else path)) (Just (acquisitionPackageTool native))
        if label == "MissingTool" then pure () else copyFile image path
        value <- selectToolchain root tools
        pure ("negative." <> label, either (Text.intercalate "; " . map renderRefusal) (const "accepted") value)
      plan <- elaborate native (directory </> "resolve") probeRequirements
      missing <- elaborate native (directory </> "missing") [Requirement "amoebius-absent-probe" "1" "2"]
      plugin <- installTool native (directory </> "tools") "proto-lens-protoc" "proto-lens-protoc"
      protoc <- findExecutable "protoc"
      generated <- case (plugin, protoc) of
        (Right (compiler, _), Just executable) -> either renderProbeRefusal (Text.intercalate "," . map Text.pack . fst) <$> codegenProbe executable compiler (directory </> "proto")
        (Left problem, _) -> pure (renderResolveRefusal problem)
        _ -> pure "CodegenToolAbsent: protoc"
      upstream <- acquireUpstream native (directory </> "upstream") forkUpstream
      mismatch <- acquireUpstream native (directory </> "upstream-negative") forkUpstream {upstreamTreeDigest = Text.replicate 64 "0"}
      pure (("versions.verdict", "accepted") : renderAcquisition native <> agreementRows <> disagreements <> [("versions.cabal-report-unavailable", either (const "refused") (const "accepted") cabalVersionFailure)] <> failures <>
        [("probe.codegen.files", generated), ("plan.packages", either renderResolveRefusal (Text.intercalate "," . planPackages . fst) plan)
        , ("negative.MissingDependency", either renderResolveRefusal (const "accepted") missing)
        , ("upstream.verdict", either renderProvenanceRefusal (const "acquired") upstream)
        , ("negative.UpstreamDigestMismatch", either renderProvenanceRefusal (const "accepted") mismatch)])
  let options = ReportOptions defaultToolchainPaths Nothing (Just (directory </> "report-probe")) Nothing Nothing Nothing
      request = directory </> "request.tsv"
  report <- reportRows options
  TextIO.writeFile request "label\tfixture-label\nghc.requested-version\t9.12.4\n"
  supported <- reportRows options {optionRequest = Just request}
  TextIO.writeFile request "label\tfixture-label\nghc.requested-version\t9.10.1\n"
  unsupported <- reportRows options {optionRequest = Just request}
  let pick rows = maybe "absent" id (lookup "request.verdict" rows)
  pure (versions <> probes <> pureRows <> actual <> cli <> [("report." <> key, value) | (key, value) <- report]
    <> [("report.request.positive", pick supported), ("report.request.negative", pick unsupported), ("negative.ReportUnknownArgument", either id (const "accepted") (parseReportOptions ["--bogus"]))])
 where
  none [] = "none"
  none values = Text.intercalate "; " values
  showT = Text.pack . show

cliObservations :: FilePath -> FilePath -> FilePath -> IO [(Text, Text)]
cliObservations root directory image = do
  let cli = directory </> "cli"
      child = cli </> "toolchain-report"
      request = cli </> "request/deep/request.tsv"
      output = cli </> "output/deep/report.tsv"
      authored = cli </> "authored-request.tsv"
  createDirectoryIfMissing True cli
  copyFile image child
  (unknown, _, unknownErr) <- spawnChild root child ["--bogus"]
  (emitted, _, _) <- spawnChild root child ["--write-request", request]
  TextIO.writeFile authored "label\tcli-fixture\nghc.requested-version\t9.10.1\n"
  (rendered, renderedOut, _) <- spawnChild root child ["--output", output, "--probe-root", cli </> "probe", "--request", authored, "--acquire", cli </> "acquired"]
  pure [("report.cli.unknown.exit", Text.pack (show (childExit unknown))), ("report.cli.unknown.stderr", Text.strip (Text.pack unknownErr)), ("report.cli.emit.exit", Text.pack (show (childExit emitted))), ("report.cli.run.exit", Text.pack (show (childExit rendered))), ("report.cli.run.stdout", Text.pack renderedOut)]
