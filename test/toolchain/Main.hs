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
import Amoebius.Build.Serial (serialCabalArguments, serialGhcArguments)
import Amoebius.Internal.Process.EmptyInput (tryReadEmptyInput)
import Control.Exception (IOException, evaluate, finally)
import Control.Monad (forM, forM_, when, filterM)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectory, createDirectoryIfMissing, createDirectoryLink, copyFile, doesDirectoryExist, doesFileExist, doesPathExist, findExecutable, getCurrentDirectory, listDirectory, makeAbsolute, removeDirectoryLink, removePathForcibly)
import System.Environment (getArgs, getEnvironment, getExecutablePath, getProgName, lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (dropExtension, makeRelative, takeExtension, takeDirectory, (</>))
import System.Mem.StableName (makeStableName)
import Text.Read (readMaybe)

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
            ["--native-config-origin", output] -> do
              directory <- makeAbsolute output
              createDirectoryIfMissing True directory
              writeNativeConfigPairs directory
            ["--native-config-attempt", name, owner] -> observeNativeConfigOrigin (Text.pack name) owner >>= print
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
  paths <- probeSourcePaths <$> fixtureSourcePaths root
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
  paths <- vendorSourcePaths <$> fixtureSourcePaths root
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
      fixtureFilePresent <- doesFileExist (fixtures </> path)
      when fixtureFilePresent (removePathForcibly (fixtures </> path))
      findings <- map renderProvenanceRefusal <$> verifyFork fixtures
      when fixtureFilePresent (copyFile (root </> path) (fixtures </> path))
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
  writeSemanticPairs directory
  writeResolutionSources directory
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
      before <- sourceIdentity root
      plan <- elaborateProbe native (directory </> "resolve-a") probeRequirements
      other <- selectToolchain root defaultToolchainPaths
      secondPlan <- case other of
        Left refusals -> fail (Text.unpack (Text.intercalate "; " (map renderRefusal refusals)))
        Right independent -> elaborateProbe independent (directory </> "resolve-b") probeRequirements
      dropped <- elaborateProbe native (directory </> "resolve-dropped") (filter ((/= "dhall") . requirementPackage) probeRequirements)
      droppedRoot <- doesPathExist (directory </> "resolve-dropped")
      after <- sourceIdentity root
      generatedPaths <- concat <$> mapM filesBelow [directory </> "resolve-a", directory </> "resolve-b"]
      (ignored, ignoredOut, ignoredErr) <- spawnChild root "git" (["check-ignore", "--"] <> generatedPaths)
      let projectPlan result = either (Left . renderResolveRefusal) (\(value, child) -> Right (planUnits value, planPackages value, planDigest value, childExit child, childArgv child)) result
          compared = case (plan, secondPlan) of (Right (a, _), Right (b, _)) -> map renderResolveRefusal (planAgreement a b); _ -> ["ResolutionUnavailable"]
          disagreement = case (plan, secondPlan) of
            (Right (a, _), Right (b, _)) -> map renderResolveRefusal (planAgreement a (b
              {planUnits = planUnits b <> ["unexpected-unit"], planPackages = planPackages b <> ["unexpected-package"], planDigest = Text.replicate 64 "0"}))
            _ -> ["ResolutionUnavailable"]
      TextIO.writeFile (directory </> "resolution.data") (Text.pack (show (projectPlan plan, projectPlan secondPlan, compared, disagreement, either (Left . renderResolveRefusal) (const (Right ())) dropped, droppedRoot, before, after, generatedPaths, childExit ignored)))
      TextIO.writeFile (directory </> "resolution-raw.data") (Text.pack (show (native, plan, other, secondPlan, dropped, ignored, ignoredOut, ignoredErr)))
      let forbiddenRoot = root </> "amoebius-resolution-refused"
      occupied <- doesPathExist forbiddenRoot
      when occupied (fail "ResolutionRefusalSentinelAlreadyPresent")
      outside <- elaborateProbe native forbiddenRoot probeRequirements
      outsideCreated <- doesPathExist forbiddenRoot
      TextIO.writeFile (directory </> "resolution-root.data") (Text.pack (show
        (forbiddenRoot, either (Left . renderResolveRefusal) (const (Right ())) outside, outsideCreated)))
      missing <- elaborate native (directory </> "missing") [Requirement "amoebius-absent-probe" "1" "2"]
      plugin <- installTool native (directory </> "tools") "proto-lens-protoc" "proto-lens-protoc"
      TextIO.writeFile (directory </> "install-positive.data") (Text.pack (show (either (Left . renderResolveRefusal) Right plugin)))
      let missingPackage = "amoebius-absent-tool-4391860a"
          missingTools = directory </> "tools-missing"
      availableMissing <- findExecutable missingPackage
      when (availableMissing /= Nothing) (fail "FallbackExecutableMustBeAbsent")
      fallback <- installTool native missingTools (Text.pack missingPackage) (Text.pack missingPackage)
      fallbackExecutable <- doesPathExist (missingTools </> missingPackage)
      let fallbackRefusal :: (Text,Text,Text)
          fallbackRefusal = case fallback of
            Left (ToolInstallFailed package detail) -> ("ToolInstallFailed",package,detail)
            Left problem -> ("OtherRefusal",renderResolveRefusal problem,"")
            Right _ -> ("accepted","","")
      TextIO.writeFile (directory </> "install-fallback.data") (Text.pack (show (fallbackRefusal,fallbackExecutable)))
      TextIO.writeFile (directory </> "install-fallback-raw.data") (Text.pack (show fallback))
      protoc <- findExecutable "protoc"
      generated <- case (plugin, protoc) of
        (Right (compiler, _), Just executable) -> do
          result <- codegenProbe executable compiler (directory </> "proto")
          recordCodegen directory (either (Left . renderProbeRefusal) Right result)
        (Left problem, _) -> recordCodegen directory (Left (renderResolveRefusal problem))
        _ -> recordCodegen directory (Left "CodegenToolAbsent: protoc")
      upstream <- acquireUpstream native (directory </> "upstream") forkUpstream
      mismatch <- acquireUpstream native (directory </> "upstream-negative") forkUpstream {upstreamTreeDigest = Text.replicate 64 "0"}
      repeated <- case upstream of
        Right acquired -> acquireUpstreamFromArchive (acquiredArchive acquired) (directory </> "upstream-second") forkUpstream
        Left problem -> pure (Left problem)
      let renderedUpstream = either (Left . renderProvenanceRefusal) (Right . renderAcquiredUpstream)
          invalidIdentity = forkUpstream {upstreamName = "amoebius-other"}
          invalidRoot = directory </> "upstream-invalid"
      TextIO.writeFile (directory </> "upstream-rendered.data") (Text.pack (show (renderedUpstream upstream, renderedUpstream repeated)))
      invalidUpstream <- case upstream of
        Right acquired -> acquireUpstreamFromArchive (acquiredArchive acquired) invalidRoot invalidIdentity
        Left problem -> pure (Left problem)
      invalidCreated <- doesPathExist invalidRoot
      TextIO.writeFile (directory </> "upstream-invalid.data") (Text.pack (show
        (upstreamName invalidIdentity, either renderProvenanceRefusal (const "accepted") invalidUpstream, invalidCreated)))
      TextIO.writeFile (directory </> "upstream-invalid-raw.data") (Text.pack (show invalidUpstream))
      let missingArchive = directory </> "absent-upstream.tar.gz"
          missingRoot = directory </> "upstream-missing"
      missingUpstream <- acquireUpstreamFromArchive missingArchive missingRoot forkUpstream
      missingCreated <- doesPathExist missingRoot
      mismatchCreated <- doesPathExist (directory </> "upstream-negative")
      let projectUpstream = either (Left . renderProvenanceRefusal) (\value -> Right
            (upstreamName (acquiredIdentity value), upstreamVersion (acquiredIdentity value), acquiredDigest value, acquiredFiles value,
             acquiredArchive value, acquiredArchiveDigest value, acquiredRoot value,
             fmap (\child -> (childExit child, childArgv child)) (acquiredCacheQuery value),
             [case action of CachedArchiveRead path digest -> ("read" :: Text,path,digest); ArchiveDirectoryCreated path -> ("directory",path,""); ArchiveFileWritten path digest -> ("file",path,digest) | action <- acquiredActions value]))
      TextIO.writeFile (directory </> "upstream.data") (Text.pack (show
        (projectUpstream upstream, projectUpstream repeated, either (Left . renderProvenanceRefusal) (const (Right ())) mismatch,
         mismatchCreated, either (Left . renderProvenanceRefusal) (const (Right ())) missingUpstream, missingCreated)))
      TextIO.writeFile (directory </> "upstream-raw.data") (Text.pack (show (upstream,repeated,mismatch,missingUpstream)))
      identities <- forM [("empty-name",forkUpstream {upstreamName = ""}), ("empty-version",forkUpstream {upstreamVersion = ""})] $ \(name, identity) -> do
        let destination = directory </> "upstream-identity" </> name
        value <- acquireUpstream native destination identity
        created <- doesPathExist destination
        pure (name, either renderProvenanceRefusal (const "accepted") value, created)
      TextIO.writeFile (directory </> "upstream-identities.data") (Text.pack (show identities))
      let outsideUpstream = root </> "amoebius-upstream-refused"
          linkedTarget = root </> "amoebius-upstream-link-refused"
          link = directory </> "upstream-root-link"
          linkedRequest = link </> "amoebius-upstream-link-refused"
      occupiedOutside <- doesPathExist outsideUpstream
      occupiedLinked <- doesPathExist linkedTarget
      when (occupiedOutside || occupiedLinked) (fail "UpstreamRefusalSentinelAlreadyPresent")
      rootPairs <- case upstream of
        Left problem -> pure [("outside" :: Text,renderProvenanceRefusal problem,True),("symlink",renderProvenanceRefusal problem,True)]
        Right acquired -> do
          outsideUpstreamResult <- acquireUpstreamFromArchive (acquiredArchive acquired) outsideUpstream forkUpstream
          outsideUpstreamCreated <- doesPathExist outsideUpstream
          createDirectoryLink root link
          (do
            linked <- acquireUpstreamFromArchive (acquiredArchive acquired) linkedRequest forkUpstream
            linkedCreated <- doesPathExist linkedTarget
            pure [("outside",either renderProvenanceRefusal (const "accepted") outsideUpstreamResult,outsideUpstreamCreated)
                 ,("symlink",either renderProvenanceRefusal (const "accepted") linked,linkedCreated)])
            `finally` removeDirectoryLink link
      TextIO.writeFile (directory </> "upstream-roots.data") (Text.pack (show rootPairs))
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

recordCodegen :: FilePath -> Either Text ([FilePath],ChildRecord) -> IO Text
recordCodegen directory result = do
  let schema = directory </> "proto/probe.proto"
      output = directory </> "proto/generated"
  schemaPresent <- doesPathExist schema
  schemaBytes <- if schemaPresent then TextIO.readFile schema else pure ""
  paths <- sort <$> filesBelow output
  generated <- forM paths $ \path -> do
    digest <- sha256File path
    bytes <- TextIO.readFile path
    pure (makeRelative output path,digest,bytes)
  TextIO.writeFile (directory </> "codegen.data") (Text.pack (show (result,schemaBytes,generated)))
  pure (either id (Text.intercalate "," . map Text.pack . fst) result)

writeNativeConfigPairs :: FilePath -> IO ()
writeNativeConfigPairs directory = do
  let owner = directory </> "native-config-cases"
      existing = owner </> "explicit.config"
      missing = owner </> "explicit-missing.config"
      implicit = owner </> "implicit-missing"
  createDirectory owner
  TextIO.writeFile existing "-- supplied read-only native configuration\n"
  configObservations <- forM [("existing",Just existing),("implicit-missing",Nothing),("explicit-missing",Just missing)] $ \(name,explicit) ->
    withEnvironment [("CABAL_CONFIG",explicit),("CABAL_DIR",Just implicit)] $ do
      selected <- nativeCabalConfig owner
      contents <- either (const (pure "")) TextIO.readFile selected
      implicitCreated <- doesPathExist implicit
      missingCreated <- doesPathExist missing
      pure (name,selected,contents,implicitCreated,missingCreated)
  TextIO.writeFile (directory </> "native-config.data") (Text.pack (show (configObservations :: [(Text,Either Text FilePath,Text,Bool,Bool)])))
  root <- getCurrentDirectory
  image <- getExecutablePath
  environment <- getEnvironment
  raw <- forM [("explicit-present",owner,Just existing),("implicit-fresh",owner,Nothing)
    ,("explicit-missing",owner,Just missing),("explicit-empty",owner,Just "")
    ,("owner-outside",root,Just existing)] $ \(name,selectedOwner,explicit) -> do
      let selectedEnvironment = [(key,value) | (key,value) <- environment, key `notElem` ["CABAL_CONFIG","CABAL_DIR"]]
            <> [("CABAL_DIR",implicit)] <> maybe [] (\value -> [("CABAL_CONFIG",value)]) explicit
      child <- tryReadEmptyInput root image ["--native-config-attempt",name,selectedOwner] (Just selectedEnvironment)
      case child of
        Right (ExitSuccess,out,"") | Just row <- readMaybe out -> pure row
        _ -> fail "NativeConfigControlChildUnavailable"
  TextIO.writeFile (directory </> "native-config-origin.data") (Text.pack (show (raw :: [NativeConfigOriginRow])))

type NativeConfigOriginRow = (Text,FilePath,[(String,Maybe (Either String String))],Maybe String,Maybe FilePath,Maybe String,Either String FilePath,Either Text FilePath,Bool)
observeNativeConfigOrigin :: Text -> FilePath -> IO NativeConfigOriginRow
observeNativeConfigOrigin name owner = do
  attempt <- acquireNativeCabalConfigAttempt owner
  let view = projectNativeCabalConfigAttempt attempt
      result = actualNativeCabalConfigResult attempt
      observations' = configAttemptObservations view
      failures = [problem | NativeConfigObservation _ (Just (Left problem)) <- observations']
  sameCause <- case (result,failures) of
    (Left original,[recorded]) -> sameException original recorded
    (Right _,[]) -> pure True
    _ -> pure False
  pure (name,configAttemptOwnerInput view
    ,[(show step,fmap (either (Left . show) (Right . show)) returned) | NativeConfigObservation step returned <- observations']
    ,show <$> configAttemptSelection view,configAttemptSelectedOperand view
    ,show <$> configAttemptOrigin view,either (Left . show) Right result
    ,projectNativeCabalConfigCompatibility attempt,sameCause)

sameException :: IOException -> IOException -> IO Bool
sameException original recorded = do
  a <- evaluate original >>= makeStableName
  b <- evaluate recorded >>= makeStableName
  pure (a == b)

withEnvironment :: [(String,Maybe String)] -> IO a -> IO a
withEnvironment values action = do
  previous <- forM values (\(key,_) -> (key,) <$> lookupEnv key)
  let apply = mapM_ (\(key,value) -> maybe (unsetEnv key) (setEnv key) value)
  (apply values >> action) `finally` apply previous

-- Actual pure-domain observations, including a successful simulator run with
-- no terminal value. These are observations, never alternate subject modes.
writeSemanticPairs :: FilePath -> IO ()
writeSemanticPairs directory = do
  writeNativeConfigPairs directory
  let schedules :: [(Text, Schedule)]
      schedules = [("positive", cleanSchedule), ("negative", Schedule [])]
      simulations = [(role, [(writerName w, writerDelay w, writerValue w) | w <- scheduleWriters schedule],
        simulationTerminal schedule, either (Left . renderProbeRefusal) Right (simulateSchedule schedule), simProbe schedule)
        | (role, schedule) <- schedules]
      renderPlan result = either (Left . map renderPlanRefusal) (Right . map renderStep) result
      cases :: [(Text,Text,Platform,Inventory,Catalogue)]
      cases = [("absent-tool", role, examplePlatform, Inventory [], if negative then Catalogue [] else probeCatalogue)
              | (role, negative) <- [("positive", False), ("negative", True)]]
        <> [("out-of-range", role, examplePlatform, Inventory [("ghc", version)], probeCatalogue)
              | (role, version) <- [("positive", [9,12,4]), ("negative", [9,10,1])]]
        <> [("platform-asset", role, platform, Inventory [], probeCatalogue)
              | (role, platform) <- [("positive", examplePlatform), ("negative", Platform "unsupported" "unknown")]]
      plans = [(name, role, renderPlatform platform, inventoryTools inventory,
        [assetTool asset <> "@" <> renderVersion (assetVersion asset) <> ":" <> renderPlatform (assetPlatform asset)
          | asset <- catalogueAssets catalogue], renderPlan (planEnsure platform inventory catalogue (take 1 floorTools)))
        | (name, role, platform, inventory, catalogue) <- cases]
  TextIO.writeFile (directory </> "simulation.data") (Text.pack (show simulations))
  TextIO.writeFile (directory </> "planner-pairs.data") (Text.pack (show plans))
  TextIO.writeFile (directory </> "planner-pairs-raw.data") (Text.pack (show
    [(name, role, platform, inventory, catalogue, take 1 floorTools, planEnsure platform inventory catalogue (take 1 floorTools))
      | (name, role, platform, inventory, catalogue) <- cases]))
  let cabalInputs = [["build","--dry-run"], ["build","-j","16","--jobs=8","--ghc-options=-O0 -j4","--","-j7"],
        ["run","--with-compiler=/foreign/ghc","--with-ghc","foreign","-wother","-j8","--","--jobs=12"], ["build","-j","--jobs"],
        ["build","--offline=False","--online","true","--no-offline","--offline","False","--online=False","--no-offline=true","--","--online"]]
      ghcInputs = [["-fno-code"], ["-fno-code","-j","12","--","-j9"], ["-j","-O0"]]
  TextIO.writeFile (directory </> "serial-arguments.data") (Text.pack (show
    ([(input,serialCabalArguments "/native/ghc" input) | input <- cabalInputs], [(input,serialGhcArguments input) | input <- ghcInputs])))

-- The source admission pairs inspect real files and their actual discovery,
-- including an ignored generated freeze versus its tracked-root twin.
writeResolutionSources :: FilePath -> IO ()
writeResolutionSources directory = do
  let fixture = directory </> "resolution-source-tree"
      examples :: [(Text, FilePath, Text, FilePath, Text)]
      examples = [("freeze", ".build/cabal.project.freeze", "constraints: dhall >=1.42 && <1.43\n", "cabal.project.freeze", "constraints: dhall >=1.42 && <1.43\n")
        ,("package-pin", "cabal.project", "packages: .\n", "cabal.project", "constraints: dhall ==1.42.3\n")
        ,("developer-home", "cabal.project.local", "with-compiler: ghc\n", "cabal.project.local", "with-compiler: /home/developer/ghc\n")
        ,("multiline-pin", "cabal.project", "constraints:\n  dhall >=1.42 && <1.43, -- == is a comment\n  io-sim >=1.10 && <1.11\n", "cabal.project", "constraints:\n  dhall >=1.42 && <1.43, -- == is a comment\n  io-sim ==1.10.1.0\n")
        ,("comment-only", "cabal.project", "-- constraints: dhall ==1.42.3\n", "cabal.project", "constraints: dhall ==1.42.3\n")]
  present <- doesPathExist fixture
  when present (fail "ResolutionSourceRootNotFresh")
  rows <- forM examples $ \(name, positivePath, positiveBytes, negativePath, negativeBytes) ->
    forM [("positive" :: Text, positivePath, positiveBytes), ("negative", negativePath, negativeBytes)] $ \(role, path, bytes) -> do
      createDirectoryIfMissing True (takeDirectory (fixture </> path))
      (do
        TextIO.writeFile (fixture </> path) bytes
        discovered <- sort <$> authoredPaths fixture
        observed <- inspectTrackedArtefacts fixture
        actual <- TextIO.readFile (fixture </> path)
        pure (name, role, path, actual, discovered, map renderResolveRefusal observed))
        `finally` removePathForcibly fixture
  removed <- not <$> doesPathExist fixture
  TextIO.writeFile (directory </> "resolution-sources.data") (Text.pack (show (concat rows, removed)))

sourceIdentity :: FilePath -> IO [(FilePath, Text)]
sourceIdentity root = do
  paths <- fixtureSourcePaths root
  mapM (\path -> (path,) <$> sha256File (root </> path)) paths

-- Fixture copying and the unchanged-source measurement do not consume the
-- product discovery result that the independent oracle is judging.
fixtureSourcePaths :: FilePath -> IO [FilePath]
fixtureSourcePaths root = sort . map (makeRelative root) <$> walk root
 where
  walk directory = do
    names <- filter (`notElem` [".build", ".git", "dist-newstyle", ".data", ".test_data"]) <$> listDirectory directory
    concat <$> forM names (\name -> do
      let path = directory </> name
      directoryPresent <- doesDirectoryExist path
      if directoryPresent then walk path else do
        filePresent <- doesFileExist path
        pure [path | filePresent])

filesBelow :: FilePath -> IO [FilePath]
filesBelow root = do
  present <- doesDirectoryExist root
  if not present then pure [] else do
    names <- sort <$> listDirectory root
    directories <- filterM (doesDirectoryExist . (root </>)) names
    nested <- concat <$> mapM (filesBelow . (root </>)) directories
    pure ([root </> name | name <- names, name `notElem` directories] <> nested)

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
