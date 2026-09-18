{-# LANGUAGE OverloadedStrings #-}

-- | The toolchain suite: a byte producer, never a verdict.
--
-- It verifies the GenesisTrust pins, performs two contained acquisitions beneath
-- the suite directory, elaborates their plans, exercises every probe, evaluates
-- each named negative, and writes one tab-separated file for the separately
-- authored oracle under @test/oracle/toolchain/Main.hs@ to judge from literals.
-- Every extracted tree is removed before the suite exits; the receipts stay.
module Main (main) where

import Amoebius.Toolchain.Acquire
import Amoebius.Toolchain.Pins
import Amoebius.Toolchain.Probe
import Amoebius.Toolchain.Provenance
import Amoebius.Toolchain.Report
import Amoebius.Toolchain.Resolve
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectoryIfMissing, createFileLink, findExecutable, getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.Environment (getArgs)
import System.FilePath ((</>))

main :: IO ()
main = do
  arguments <- getArgs
  let suiteDir = case arguments of
        [path] -> path
        _ -> ".build/runs/toolchain-suite"
  createDirectoryIfMissing True suiteDir
  absolute <- makeAbsolute suiteDir
  root <- getCurrentDirectory
  located <- locateInputs absolute
  rows <- case located of
    Nothing -> pure [("inputs", "absent"), ("inputs.expected", Text.pack inputsDirectory)]
    Just inputs -> suiteRows root inputs absolute
  TextIO.writeFile (absolute </> "toolchain.tsv") (Text.unlines [key <> "\t" <> value | (key, value) <- rows])
  putStrLn ("toolchain projection written: " <> (absolute </> "toolchain.tsv"))

suiteRows :: FilePath -> FilePath -> FilePath -> IO [(Text, Text)]
suiteRows root inputs suiteDir = do
  pins <- verifyPins inputs
  (signatures, _) <- verifySignatures inputs
  let pinRows = case pins of
        Right verified ->
          ("pins.verdict", "ok")
            : [("pin." <> Text.pack (pinName pin), "ok bytes=" <> showText (pinBytes pin) <> " sha256=" <> digest) | (pin, digest) <- verifiedObserved verified]
              <> [("manifest." <> renderPinRole role, "agrees claimed=" <> claimed) | (role, claimed) <- verifiedClaimed verified]
        Left refusals -> [("pins.verdict", Text.intercalate "; " (map renderRefusal refusals))]
      signatureRows = [("signature." <> showText index, renderSignature result) | (index, result) <- zip [1 :: Int ..] signatures]
  acquisitionRows <- case pins of
    Left _ -> pure [("acquisition.verdict", "pins refused")]
    Right verified -> acquisitionSection root verified suiteDir
  decodes <- decodeProbe (suiteDir </> "probe" </> "decode")
  bridge <- bridgeProbe (suiteDir </> "probe" </> "purs")
  authored <- authoredPaths root
  forkProblems <- verifyFork root
  let probeRows =
        [("probe.decode." <> name, renderDecodeOutcome outcome) | (name, outcome) <- decodes]
          <> [ ("probe.sim.clean", simProbe cleanSchedule)
             , ("probe.sim.perturbed", simProbe perturbedSchedule)
             , ("probe.codegen.link-token", linkToken)
             , ("probe.bridge.files", Text.intercalate "," (map Text.pack bridge))
             ]
      planRows =
        [ ("plan.steps", either (Text.intercalate "; " . map renderPlanRefusal) (Text.intercalate "; " . map renderStep) (planEnsure platform (Inventory []) probeCatalogue floorTools))
        , ("plan.present", either (Text.intercalate "; " . map renderPlanRefusal) (Text.intercalate "; " . map renderStep) (planEnsure platform (Inventory [("ghc", [9, 12, 4]), ("cabal-install", [3, 16, 1, 0])]) probeCatalogue (take 2 floorTools)))
        ]
      layoutRows =
        [ ("layout.resolve-refusals", noneOr (map renderResolveRefusal (refuseTrackedArtefacts authored)))
        , ("layout.provenance-refusals", noneOr (map renderProvenanceRefusal (refuseLayout authored)))
        , ("fork.missing", noneOr (map renderProvenanceRefusal forkProblems))
        , ("fork.modules", showText (length forkModules))
        , ("identity.pins", showText (length genesisPins))
        , ("identity.platform", renderPlatform platform)
        ]
      pureNegatives =
        [ ("negative.AmbientNetworkRead", "deferred")
        , ("negative.TrackedResolutionOutput", refusalsText (map renderResolveRefusal (refuseTrackedArtefacts ["cabal.project.freeze"])))
        , ("negative.DeveloperHomePath", refusalsText (map renderResolveRefusal (refuseTrackedArtefacts ["/home/developer/amoebius/probe.cabal"])))
        , ("negative.TrackedProbeInput", refusalsText (map renderResolveRefusal (refuseTrackedArtefacts ["test/fixture/probe.dhall"])))
        , ("negative.MutableIdentity", either renderProvenanceRefusal renderReference (admitReference (GitBranch "https://github.com/cr-org/supernova" "main")))
        , ("negative.AbsentIdentity", either renderProvenanceRefusal renderReference (admitReference (HackageRelease "" "")))
        , ("negative.ProvenanceDeveloperHome", either renderProvenanceRefusal renderReference (admitReference (LocalPath "/home/developer/supernova")))
        , ("negative.TopLevelVendor", refusalsText (map renderProvenanceRefusal (refuseLayout ["vendor/supernova/src/Pulsar.hs"])))
        , ("negative.PatchProgram", refusalsText (map renderProvenanceRefusal (refuseLayout ["patches/supernova.patch"])))
        , ("negative.TrackedForeignPackage", refusalsText (map renderProvenanceRefusal (refuseLayout ["vendor/supernova/supernova.cabal"])))
        , ("negative.AbsentTool", either (refusalsText . map renderPlanRefusal) (refusalsText . map renderStep) (planEnsure platform (Inventory []) probeCatalogue [Tool "absent-tool" [1] [2]]))
        , ("negative.OutOfRangeVersion", either (refusalsText . map renderPlanRefusal) (refusalsText . map renderStep) (planEnsure platform (Inventory [("ghc", [9, 10, 1])]) probeCatalogue (take 1 floorTools)))
        , ("negative.NoPlatformAsset", either (refusalsText . map renderPlanRefusal) (refusalsText . map renderStep) (planEnsure (Platform "windows" "x86_64") (Inventory []) probeCatalogue (take 1 floorTools)))
        ]
  networkRefusal <- verifyPins "https://downloads.haskell.org/~ghc/9.12.4/.build/bootstrap-inputs"
  missingPin <- verifyPinsWith inputs [(CompilerManifest, suiteDir </> "negatives" </> "absent-manifest")]
  corrupted <- corruptedManifest inputs (suiteDir </> "negatives")
  signatureNegative <- corruptedSignature inputs (suiteDir </> "negatives" </> "inputs")
  let inputNegatives =
        [ ("negative.AmbientNetworkRead", either (refusalsText . map renderRefusal) (const "accepted") networkRefusal)
        , ("negative.MissingPin", either (refusalsText . map renderRefusal) (const "accepted") missingPin)
        , ("negative.DigestMismatch", either (refusalsText . map renderRefusal) (const "accepted") corrupted)
        , ("negative.ManifestDisagrees", either (refusalsText . map renderRefusal) (const "accepted") corrupted)
        , ("negative.SignatureMismatch", refusalsText (map renderSignature signatureNegative))
        ]
  removePathForcibly (suiteDir </> "negatives" </> "inputs")
  reportRowsObserved <- reportSection inputs suiteDir
  pure (pinRows <> signatureRows <> acquisitionRows <> probeRows <> planRows <> layoutRows <> [row | row <- pureNegatives, fst row /= "negative.AmbientNetworkRead"] <> inputNegatives <> reportRowsObserved)

-- | The shipped report's rows over the real pins and over a manifest whose
-- archive digest is rewritten, plus its argument refusal.
reportSection :: FilePath -> FilePath -> IO [(Text, Text)]
reportSection inputs suiteDir = do
  let base = ReportOptions {optionInputs = Just inputs, optionCompilerManifest = Nothing, optionPackageToolManifest = Nothing, optionOutput = Nothing, optionProbeRoot = Just (suiteDir </> "report-probe"), optionAcquireRoot = Nothing}
  clean <- reportRows base
  createDirectoryIfMissing True (suiteDir </> "negatives")
  original <- TextIO.readFile (inputs </> "ghc-SHA256SUMS")
  let rewritten = suiteDir </> "negatives" </> "rewritten-compiler-manifest"
  TextIO.writeFile rewritten (Text.replace "4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa" (Text.replicate 64 "0") original)
  refused <- reportRows base {optionCompilerManifest = Just rewritten}
  let pick rows key = maybe "<absent>" id (lookup key rows)
      carried = ["pins.verdict", "identity.compiler", "identity.package-tool", "identity.platform", "identity.pins", "probe.decode.positive", "probe.decode.mistyped", "probe.sim.clean", "probe.sim.perturbed", "probe.sim.schedule.clean", "probe.codegen.link-token", "probe.bridge.files", "plan.steps", "provenance.upstream", "provenance.fork-modules", "provenance.requirements"]
  pure
    ( [("report." <> key, pick clean key) | key <- carried]
        <> [("report.signature." <> showText index, Text.take 60 (pick clean ("signature." <> showText index))) | index <- [1 :: Int, 2, 3]]
        <> [ ("report.rows", showText (length clean))
           , ("report.keys", Text.intercalate "," (map fst clean))
           , ("pins.rendered", Text.intercalate "; " (map renderPin genesisPins))
           , ("probe.codegen.schema-sha256", sha256Bytes (TextEncoding.encodeUtf8 probeProto))
           , ("positive.GitCommit", either renderProvenanceRefusal renderReference (admitReference (GitCommit "https://github.com/cr-org/supernova" "0123456789abcdef0123456789abcdef01234567")))
           , ("negative.ShortCommit", either renderProvenanceRefusal renderReference (admitReference (GitCommit "https://github.com/cr-org/supernova" "0123456789abcdef0123456789abcdef0123456")))
           , ("report.refused.verdict", pick refused "pins.verdict")
           , ("report.refused.manifest", Text.intercalate "; " [value | (key, value) <- refused, "pins.refusal." `Text.isPrefixOf` key, "ManifestDisagrees" `Text.isPrefixOf` value])
           , ("negative.ReportUnknownArgument", either id (const "accepted") (parseReportOptions ["--acquire", "x", "--bogus"]))
           , ("report.options", Text.pack (show (either (const Nothing) (Just . optionAcquireRoot) (parseReportOptions ["--acquire", "root", "--output", "out"]))))
           ]
    )

-- | Two contained acquisitions, their plans, the codegen probe over the first,
-- the upstream provenance acquisition, and the acquisition-bound negatives.
acquisitionSection :: FilePath -> VerifiedPins -> FilePath -> IO [(Text, Text)]
acquisitionSection _ verified suiteDir = do
  let rootA = suiteDir </> "acquire" </> "a"
      rootB = suiteDir </> "acquire" </> "b"
  acquired <- acquireTwice verified rootA rootB
  case acquired of
    Left refusals -> pure [("acquisition.verdict", Text.intercalate "; " (map renderRefusal refusals))]
    Right (a, b) -> do
      planA <- elaborate a (rootA </> "resolve") probeRequirements
      planB <- elaborate b (rootB </> "resolve") probeRequirements
      missing <- elaborate a (suiteDir </> "negatives" </> "resolve") [Requirement "amoebius-absent-probe" "1" "2"]
      tool <- installTool a (suiteDir </> "tools") "proto-lens-protoc" "proto-lens-protoc"
      protoc <- findExecutable "protoc"
      codegen <- case (tool, protoc) of
        (Right (plugin, _), Just protocPath) -> either (Left . renderProbeRefusal) (Right . fst) <$> codegenProbe protocPath plugin (suiteDir </> "probe" </> "proto")
        (Left refusal, _) -> pure (Left (renderResolveRefusal refusal))
        (_, Nothing) -> pure (Left "CodegenToolAbsent: protoc")
      upstream <- acquireUpstream a (suiteDir </> "vendor") forkUpstream
      mismatch <- acquireUpstream a (suiteDir </> "negatives" </> "vendor") forkUpstream {upstreamTreeDigest = Text.replicate 64 "0"}
      again <- acquire verified rootA
      _ <- writeAcquisitionReceipt a
      _ <- writeAcquisitionReceipt b
      removeAcquisition a
      removeAcquisition b
      removePathForcibly (suiteDir </> "tools")
      pure
        ( [("acquisition.verdict", "agree")]
            <> [("acquisition.a." <> key, value) | (key, value) <- renderAcquisition a]
            <> [("acquisition.b." <> key, value) | (key, value) <- renderAcquisition b]
            <> [ ("plan.a.digest", either renderResolveRefusal (planDigest . fst) planA)
               , ("plan.b.digest", either renderResolveRefusal (planDigest . fst) planB)
               , ("plan.a.packages", either renderResolveRefusal (Text.intercalate "," . planPackages . fst) planA)
               , ("plan.a.units", either renderResolveRefusal (showText . length . planUnits . fst) planA)
               , ("plan.agree", Text.pack (show (either (const Nothing) (Just . planDigest . fst) planA /= Nothing && either (const Nothing) (Just . planDigest . fst) planA == either (const Nothing) (Just . planDigest . fst) planB)))
               , ("probe.codegen.files", either id (Text.intercalate "," . map Text.pack) codegen)
               , ("upstream.verdict", either renderProvenanceRefusal (const "acquired") upstream)
               ]
            <> either (const []) renderAcquiredUpstream upstream
            <> [ ("negative.MissingDependency", either renderResolveRefusal (const "accepted") missing)
               , ("negative.UpstreamDigestMismatch", either renderProvenanceRefusal (const "accepted") mismatch)
               , ("negative.RootNotAbsent", either (refusalsText . map renderRefusal) (const "accepted") again)
               , ("negative.DisagreeingAcquisition", refusalsText (map renderRefusal (agreement a b {acquisitionCompilerDigest = Text.replicate 64 "0"})))
               ]
        )

-- | A copy of the package-tool manifest with one digit of the archive's digest
-- changed, substituted for the pinned manifest.
corruptedManifest :: FilePath -> FilePath -> IO (Either [AcquisitionRefusal] VerifiedPins)
corruptedManifest inputs negatives = do
  createDirectoryIfMissing True negatives
  case pinFor PackageToolManifest of
    Nothing -> pure (Left [PinMissing "package-tool-manifest"])
    Just pin -> do
      contents <- TextIO.readFile (inputs </> pinName pin)
      let path = negatives </> "corrupted-manifest"
          flipped = Text.map (\c -> if c == '9' then '8' else c) contents
      TextIO.writeFile path flipped
      verifyPinsWith inputs [(PackageToolManifest, path)]

-- | An inputs directory whose package-tool manifest signature is corrupted; the
-- other signed files are linked, not copied.
corruptedSignature :: FilePath -> FilePath -> IO [SignatureResult]
corruptedSignature inputs negatives = do
  removePathForcibly negatives
  createDirectoryIfMissing True negatives
  mapM_ (\name -> createFileLink (inputs </> name) (negatives </> name)) [pinName pin | pin <- genesisPins, pinName pin /= "cabal-SHA256SUMS.sig"]
  copyFile (inputs </> keyringFile) (negatives </> keyringFile)
  TextIO.writeFile (negatives </> "cabal-SHA256SUMS.sig") "not a signature\n"
  fst <$> verifySignatures negatives

showText :: Show value => value -> Text
showText = Text.pack . show

noneOr :: [Text] -> Text
noneOr items = if null items then "none" else Text.intercalate "; " items

refusalsText :: [Text] -> Text
refusalsText items = if null items then "accepted" else Text.intercalate "; " items
