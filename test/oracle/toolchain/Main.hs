{-# LANGUAGE OverloadedStrings #-}
-- | Independent version and probe expectations. No product dependency.
module Main (main) where
import Control.Monad (unless)
import Control.Exception (IOException, try)
import Data.Map.Strict qualified as Map
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import VersionExpectations (versionCases)
import Admission (admissionChecks)
import ProbeSource (probeSourceChecks)
import VendorSource (vendorSourceChecks)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--native-tool-versions", directory] -> admissionChecks directory >>= emit
    ["--probe-source", directory] -> probeSourceChecks directory >>= emit
    ["--vendor-source", directory] -> vendorSourceChecks directory >>= emit
    [input] -> toolchainChecks input
    _ -> exitFailure

emit :: [(Text, Bool, Text)] -> IO ()
emit rows = do
  mapM_ (\(name, green, observed) -> TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", observed])) rows
  unless (all (\(_, green, _) -> green) rows) exitFailure

toolchainChecks :: FilePath -> IO ()
toolchainChecks input = do
  directory <- doesDirectoryExist input
  observed <- try (TextIO.readFile (if directory then input <> "/toolchain.tsv" else input)) :: IO (Either IOException Text)
  contents <- case observed of
    Left _ -> TextIO.putStrLn "observation.toolchain\tred\trequired toolchain.tsv is unreadable" >> exitFailure
    Right bytes -> pure bytes
  let rows = Map.fromList [(key, Text.intercalate "\t" rest) | line <- Text.lines contents, key : rest <- [Text.splitOn "\t" line]]
      value key = Map.findWithDefault "<absent>" key rows
      exact key expected = (key, value key == expected, value key)
      prefix key expected = (key, expected `Text.isPrefixOf` value key, value key)
      ledger = [exact ("version.case." <> Text.pack (show index)) (Text.intercalate "|" [tool, raw, verdict]) | (index, (tool, raw, verdict)) <- zip [1 :: Int ..] versionCases]
        <> [("version.discovery", length [key | key <- Map.keys rows, "version.case." `Text.isPrefixOf` key] == length versionCases, "version case inventory")]
        <> [exact "versions.verdict" "accepted", exact "second.verdict" "none", exact "report.versions.verdict" "accepted", exact "report.request.positive" "accepted", exact "report.request.negative" "ToolVersionMismatch: ghc", exact "negative.ReportUnknownArgument" "toolchain-report: unknown argument --bogus",
           exact "report.probe.decode.positive" "decoded amoebius/3/True", exact "report.probe.decode.mistyped" "refused type-error", exact "report.probe.sim.clean" "b:2", exact "report.probe.sim.perturbed" "a:1", exact "report.probe.codegen.link-token" "0a08616d6f65626975731003", exact "report.probe.bridge.files" "Amoebius/Toolchain/Probe.purs", exact "report.provenance.fork-modules" "17", exact "probe.decode.positive" "decoded amoebius/3/True", prefix "probe.decode.mistyped" "refused type-error", exact "probe.sim.clean" "b:2", exact "probe.sim.perturbed" "a:1", exact "fork.modules" "17", exact "fork.problems" "none", exact "layout.problems" "none", exact "upstream.verdict" "acquired", exact "probe.codegen.files" "Proto/Probe.hs,Proto/Probe_Fields.hs"
           , ("plan.packages", all (`elem` Text.splitOn "," (value "plan.packages")) ["dhall", "io-classes", "io-sim", "proto-lens", "proto-lens-runtime", "purescript-bridge", "tar", "zlib"], value "plan.packages")
           , exact "report.provenance.upstream" "supernova-0.0.3 2e2f01be19b08128cd8549befcc1da3fea172b1f5b3471845d05ef8dc06dda33"]
        <> [prefix ("negative." <> key) expected | (key, expected) <- [("MissingTool", "ToolMissing"), ("MalformedVersion", "ToolVersionMalformed"), ("UnsupportedVersion", "ToolVersionMismatch"), ("UnsupportedGhcupVersion", "ToolVersionMismatch"), ("FailedVersionCommand", "ToolCommandFailed"), ("TrackedResolutionOutput", "TrackedResolutionOutput"), ("TrackedProbeInput", "TrackedProbeInput"), ("MutableIdentity", "MutableIdentity"), ("TopLevelVendor", "TopLevelVendor"), ("AbsentTool", "AbsentTool"), ("OutOfRangeVersion", "OutOfRangeVersion"), ("NoPlatformAsset", "NoPlatformAsset"), ("UpstreamDigestMismatch", "DigestMismatch")]]
        <> [exact "negative.MissingDependency" "MissingDependency: amoebius-absent-probe", exact "report.probe.source.findings" "", exact "report.provenance.layout" ""]
        <> [("report.probe.discovery", sort [key | line <- Text.lines contents, key : _ <- [Text.splitOn "\t" line], "report.probe." `Text.isPrefixOf` key]
             == sort ["report.probe." <> key | key <- ["decode.positive", "decode.mistyped", "sim.clean", "sim.perturbed", "codegen.link-token", "bridge.files", "source.findings"]], "exact shipped-report probe inventory")]
        <> [exact "report.plan.steps" "ensure ghc 9.12.4 versioned via ghcup; ensure cabal-install 3.16.1.0 managed via ghcup; ensure proto-lens-protoc 0.9.0.1 managed via cabal-install; ensure protoc 3.21.12 managed via package-manager"]
        <> [exact "plan.steps" "ensure ghc 9.12.4 versioned via ghcup; ensure cabal-install 3.16.1.0 managed via ghcup; ensure proto-lens-protoc 0.9.0.1 managed via cabal-install; ensure protoc 3.21.12 managed via package-manager"]
        <> [exact "child.absent.exit" "127", exact "child.absent.stdout" "", prefix "child.absent.stderr" "executable not found:", exact "child.failed-cwd.exit" "127", exact "child.failed-cwd.stdout" "", ("child.failed-cwd.stderr", not (Text.null (value "child.failed-cwd.stderr")), "spawn error observed")]
        <> [exact "second.mismatch.ghcup" "AcquisitionsDisagree: ghcup.version 0.1.50.2 /= 0.2.6.2", exact "second.mismatch.compiler" "AcquisitionsDisagree: compiler.version 9.12.4 /= 9.10.1", exact "second.cabal-version" "none", exact "versions.cabal-report-unavailable" "accepted"]
        <> [exact "report.cli.unknown.exit" "2", prefix "report.cli.unknown.stderr" "toolchain-report: unknown argument --bogus", exact "report.cli.emit.exit" "0", exact "report.cli.run.exit" "0", exact "report.cli.run.stdout" ""]
  binary <- if directory then binaryRows input else pure []
  cli <- if directory then cliRows input else pure []
  admission <- if directory then admissionChecks input else pure []
  source <- if directory then probeSourceChecks input else pure []
  vendor <- if directory then vendorSourceChecks input else pure []
  let complete = ledger <> binary <> cli <> admission <> source <> vendor
  emit complete

cliRows :: FilePath -> IO [(Text, Bool, Text)]
cliRows directory = do
  let request = directory <> "/cli/request/deep/request.tsv"
      report = directory <> "/cli/output/deep/report.tsv"
  requestPresent <- doesFileExist request
  reportPresent <- doesFileExist report
  if not (requestPresent && reportPresent) then pure [("report.cli.files", False, "request or report missing")] else do
    requestBytes <- TextIO.readFile request
    reportBytes <- TextIO.readFile report
    let values = Map.fromList [(key, value) | line <- Text.lines reportBytes, [key, value] <- [Text.splitOn "\t" line]]
        check name condition = (name, condition, if condition then "ok" else "report contract differs")
    pure [check "report.cli.request" (requestBytes == "label\t0b5e17e11a0c0ffee0de1e9a7e5ba5ed\nghc.requested-version\t9.12.4\n")
         , check "report.cli.label" (Map.lookup "request.label" values == Just "cli-fixture")
         , check "report.cli.refusal" (Map.lookup "request.verdict" values == Just "ToolVersionMismatch: ghc")
         , check "report.cli.acquisition" (Map.lookup "acquisition.verdict" values == Just "agree")
         , check "report.cli.native" (Map.lookup "versions.verdict" values == Just "accepted" && Map.lookup "compiler.version" values == Just "9.12.4")]

-- | Judge the runner's rewritten request independently, including its semantic
-- refusal. Echoing a nonce alone cannot satisfy this binary challenge.
binaryRows :: FilePath -> IO [(Text, Bool, Text)]
binaryRows directory = do
  let root = directory <> "/binary"
  present <- doesDirectoryExist root
  if not present then pure [] else do
    let input = root <> "/input/toolchain-request.tsv"
        output = root <> "/toolchain-report.tsv"
    hasInput <- doesFileExist input
    hasOutput <- doesFileExist output
    if not (hasInput && hasOutput) then pure [("binary.outputs-present", False, "input or report absent")] else do
      request <- rowsOf <$> TextIO.readFile input
      report <- rowsOf <$> TextIO.readFile output
      let values key rows = [value | (name, value) <- rows, name == key]
          label = values "label" request
          validNonce value = Text.length value == 32 && Text.all (\c -> c `elem` ['0'..'9'] || c `elem` ['a'..'f']) value
          exact name condition = (name, condition, if condition then "ok" else "input/report contract differs")
      pure [exact "binary.input-contract" (length request == 2 && values "ghc.requested-version" request == ["9.10.1"] && length label == 1 && all validNonce label)
           , exact "binary.nonce-recovered" (values "request.label" report == label && not (null label))
           , exact "binary.version-request-refused" (values "request.verdict" report == ["ToolVersionMismatch: ghc"])
           , exact "binary.native-versions-admitted" (values "versions.verdict" report == ["accepted"] && values "compiler.version" report == ["9.12.4"])]
 where
  rowsOf text = [(key, value) | line <- Text.lines text, [key, value] <- [Text.splitOn "\t" line]]
