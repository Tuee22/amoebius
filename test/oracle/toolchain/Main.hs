{-# LANGUAGE OverloadedStrings #-}

-- | The toolchain-area oracle executable.
--
-- It depends on no @amoebius@ library. It reads the projection the toolchain
-- suite wrote and prints a ledger derived from the literals below: one row per
-- expectation, @green@ or @red@ with the observed value. The seven pins, the
-- compiler and package-tool identities, the probe outcomes, the planner's step
-- list, the upstream identity, and every refusal tag are restated here, never
-- regenerated from the subject.
module Main (main) where

import Control.Monad (unless)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  input <- case arguments of
    [path] -> do
      directory <- doesDirectoryExist path
      pure (if directory then path <> "/toolchain.tsv" else path)
    _ -> pure ".build/runs/toolchain-suite/toolchain.tsv"
  contents <- TextIO.readFile input
  let rows = Map.fromList [(key, Text.intercalate "\t" rest) | line <- Text.lines contents, (key : rest) <- [Text.splitOn "\t" line]]
      ledger = judge rows
  mapM_ (TextIO.putStrLn . renderRow) ledger
  unless (all rowGreen ledger) exitFailure

data LedgerRow = LedgerRow
  { rowName :: Text
  , rowGreen :: Bool
  , rowObserved :: Text
  }

renderRow :: LedgerRow -> Text
renderRow row = Text.intercalate "\t" [rowName row, if rowGreen row then "green" else "red", rowObserved row]

-- | The seven pins: name, byte count, SHA-256.
expectedPins :: [(Text, Text, Text)]
expectedPins =
  [ ("ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz", "302637420", "4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa")
  , ("ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig", "438", "a5c8828b3c1c53cfc8d5e4459de0790efa5a8dea96cc16dd564382f005280cc5")
  , ("ghc-SHA256SUMS", "6585", "67869bc776c7f0ffe76226a689c234b367b2194aececbb53da2275892040053b")
  , ("ghc-SHA256SUMS.sig", "438", "9db94ced16b87713e89a41c408bf5efcb29462971c2494fbfec7e05a33de6bad")
  , ("cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz", "5288744", "9d68bd17d4aa87e93eea3f667d3edf41ab1cb2b5194bf1745da9dee678426c17")
  , ("cabal-SHA256SUMS", "2799", "19ef5e11a70d6d06ae23a2b4cae6b52bcf19575be7343fc9dfcce4104bce8bb3")
  , ("cabal-SHA256SUMS.sig", "95", "59fa7dbebd873bd1714f440111fe1607148d25afd23450e4c5ee9afdc38c4eb3")
  ]

-- | The role of each pin, in the order of 'expectedPins'.
pinRoles :: [Text]
pinRoles = ["compiler-archive", "compiler-archive-signature", "compiler-manifest", "compiler-manifest-signature", "package-tool-archive", "package-tool-manifest", "package-tool-manifest-signature"]

compilerSha256 :: Text
compilerSha256 = "29b0a853efd81eeed37f5d5ffe8add38f3bd0daa87a8838deaf088ec458e99fc"

packageToolSha256 :: Text
packageToolSha256 = "27a896cd2389c336d8c492dbb4d49dd22148a278150f9e4619a84c0ea6a307fb"

upstreamTreeSha256 :: Text
upstreamTreeSha256 = "2e2f01be19b08128cd8549befcc1da3fea172b1f5b3471845d05ef8dc06dda33"

expectedSteps :: Text
expectedSteps = "ensure ghc 9.12.4 pinned via compiler-archive; ensure cabal-install 3.16.1.0 pinned via package-tool-archive; ensure proto-lens-protoc 0.9.0.1 managed via cabal-install; ensure protoc 3.21.12 managed via package-manager"

expectedPackages :: [Text]
expectedPackages = ["dhall", "io-classes", "io-sim", "proto-lens", "proto-lens-runtime", "purescript-bridge", "tar", "zlib"]

-- | Every negative and the tag its refusal must carry at its locus.
expectedNegatives :: [(Text, Text)]
expectedNegatives =
  [ ("AmbientNetworkRead", "AmbientNetworkRefused: ")
  , ("MissingPin", "PinMissing: ghc-SHA256SUMS")
  , ("DigestMismatch", "PinDigestMismatch: cabal-SHA256SUMS")
  , ("ManifestDisagrees", "ManifestDisagrees: cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz")
  , ("SignatureMismatch", "SignatureRejected: cabal-SHA256SUMS")
  , ("RootNotAbsent", "RootNotAbsent: ")
  , ("DisagreeingAcquisition", "AcquisitionsDisagree: compiler.sha256")
  , ("MissingDependency", "MissingDependency: amoebius-absent-probe")
  , ("TrackedResolutionOutput", "TrackedResolutionOutput: cabal.project.freeze")
  , ("DeveloperHomePath", "DeveloperHomePath: /home/developer/amoebius/probe.cabal")
  , ("TrackedProbeInput", "TrackedProbeInput: test/fixture/probe.dhall")
  , ("MutableIdentity", "MutableIdentity: git:https://github.com/cr-org/supernova#main")
  , ("AbsentIdentity", "AbsentIdentity: hackage:-")
  , ("ProvenanceDeveloperHome", "DeveloperHomePath: /home/developer/supernova")
  , ("UpstreamDigestMismatch", "DigestMismatch: expected=0000000000000000000000000000000000000000000000000000000000000000")
  , ("TopLevelVendor", "TopLevelVendor: vendor/supernova/src/Pulsar.hs")
  , ("PatchProgram", "PatchProgram: patches/supernova.patch")
  , ("TrackedForeignPackage", "TrackedForeignPackage: vendor/supernova/supernova.cabal")
  , ("AbsentTool", "AbsentTool: absent-tool")
  , ("OutOfRangeVersion", "OutOfRangeVersion: ghc 9.10.1")
  , ("NoPlatformAsset", "NoPlatformAsset: ghc windows-x86_64")
  ]

judge :: Map Text Text -> [LedgerRow]
judge rows =
  [ expect "pins.verdict" "ok"
  , expect "identity.pins" "7"
  , expect "identity.platform" "linux-x86_64"
  ]
    <> [expect ("pin." <> name) ("ok bytes=" <> bytes <> " sha256=" <> digest) | (name, bytes, digest) <- expectedPins]
    <> [ expect "manifest.compiler-archive" "agrees claimed=4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa"
       , expect "manifest.package-tool-archive" "agrees claimed=9d68bd17d4aa87e93eea3f667d3edf41ab1cb2b5194bf1745da9dee678426c17"
       , prefix "signature.1" "good ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz "
       , prefix "signature.2" "good ghc-SHA256SUMS "
       , prefix "signature.3" "good cabal-SHA256SUMS "
       , expect "acquisition.verdict" "agree"
       ]
    <> concat
      [ [ expect ("acquisition." <> arm <> ".compiler.sha256") compilerSha256
        , expect ("acquisition." <> arm <> ".package-tool.sha256") packageToolSha256
        , expect ("acquisition." <> arm <> ".compiler.version") "9.12.4"
        , expect ("acquisition." <> arm <> ".package-tool.version") "3.16.1.0"
        , expect ("acquisition." <> arm <> ".compiler.target") "x86_64-unknown-linux"
        ]
      | arm <- ["a", "b"]
      ]
    <> [ hex64 "plan.a.digest"
       , hex64 "plan.b.digest"
       , equalRows "plan.digests-agree" "plan.a.digest" "plan.b.digest"
       , expect "plan.agree" "True"
       , contains "plan.a.packages" expectedPackages
       , expect "probe.decode.positive" "decoded amoebius/3/True"
       , expect "probe.decode.mistyped" "refused type-error"
       , expect "probe.sim.clean" "b:2"
       , expect "probe.sim.perturbed" "a:1"
       , expect "probe.codegen.link-token" "0a08616d6f65626975731003"
       , expect "probe.codegen.files" "Proto/Probe.hs,Proto/Probe_Fields.hs"
       , expect "probe.bridge.files" "Amoebius/Toolchain/Probe.purs"
       , expect "plan.steps" expectedSteps
       , expect "plan.present" "present ghc 9.12.4; present cabal-install 3.16.1.0"
       , expect "upstream.verdict" "acquired"
       , expect "upstream.identity" "supernova-0.0.3"
       , expect "upstream.tree-sha256" upstreamTreeSha256
       , expect "upstream.files" "22"
       , expect "fork.missing" "none"
       , expect "fork.modules" "17"
       , expect "layout.resolve-refusals" "none"
       , expect "layout.provenance-refusals" "none"
       ]
    <> [prefixWithin ("negative." <> name) tag | (name, tag) <- expectedNegatives]
    <> [ expect "report.pins.verdict" "ok"
       , expect "report.identity.compiler" ("ghc 9.12.4 " <> compilerSha256)
       , expect "report.identity.package-tool" ("cabal-install 3.16.1.0 " <> packageToolSha256)
       , expect "report.identity.platform" "linux-x86_64"
       , expect "report.identity.pins" "7"
       , expect "report.probe.decode.positive" "decoded amoebius/3/True"
       , expect "report.probe.decode.mistyped" "refused type-error"
       , expect "report.probe.sim.clean" "b:2"
       , expect "report.probe.sim.perturbed" "a:1"
       , expect "report.probe.sim.schedule.clean" "a@10=1,b@20=2"
       , expect "report.probe.codegen.link-token" "0a08616d6f65626975731003"
       , expect "report.probe.bridge.files" "Amoebius/Toolchain/Probe.purs"
       , expect "report.plan.steps" expectedSteps
       , expect "report.provenance.upstream" ("supernova-0.0.3 " <> upstreamTreeSha256)
       , expect "report.provenance.fork-modules" "17"
       , expect "report.provenance.requirements" "dhall >=1.42 && <1.43; io-sim >=1.10 && <1.11; io-classes >=1.10 && <1.11; proto-lens >=0.7 && <0.8; proto-lens-runtime >=0.7 && <0.8; purescript-bridge >=0.15 && <0.16; tar >=0.6 && <0.8; zlib >=0.7 && <0.8"
       , expect "report.rows" "32"
       , expect "report.refused.verdict" "refused"
       , expect "report.refused.manifest" "ManifestDisagrees: ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz claimed=0000000000000000000000000000000000000000000000000000000000000000 observed=4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa"
       , expect "negative.ReportUnknownArgument" "toolchain-report: unknown argument --bogus"
       , expect "report.options" "Just (Just \"root\")"
       , expect "report.keys" "pins.verdict,pin.ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz,pin.ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig,pin.ghc-SHA256SUMS,pin.ghc-SHA256SUMS.sig,pin.cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz,pin.cabal-SHA256SUMS,pin.cabal-SHA256SUMS.sig,manifest.compiler-archive,manifest.package-tool-archive,identity.compiler,identity.package-tool,identity.platform,identity.pins,signature.1,signature.2,signature.3,signature.child.1,signature.child.2,signature.child.3,probe.decode.positive,probe.decode.mistyped,probe.sim.clean,probe.sim.perturbed,probe.sim.schedule.clean,probe.sim.schedule.perturbed,probe.codegen.link-token,probe.bridge.files,plan.steps,provenance.upstream,provenance.fork-modules,provenance.requirements"
       , prefix "report.signature.1" "good ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz Good"
       , prefix "report.signature.2" "good ghc-SHA256SUMS Good signature"
       , prefix "report.signature.3" "good cabal-SHA256SUMS Good signature"
       , expect "pins.rendered" (Text.intercalate "; " [role <> " " <> name <> " " <> bytes <> " " <> digest | ((name, bytes, digest), role) <- zip expectedPins pinRoles])
       , expect "probe.codegen.schema-sha256" "56c70c7e2ec078925245048b18ecaaafb41c4da01524095c6b9d54b1fd68b4bd"
       , expect "positive.GitCommit" "git:https://github.com/cr-org/supernova@0123456789abcdef0123456789abcdef01234567"
       , expect "negative.ShortCommit" "MutableIdentity: git:https://github.com/cr-org/supernova@0123456789abcdef0123456789abcdef0123456"
       ]
 where
  observed key = Map.findWithDefault "<absent>" key rows
  expect key value = LedgerRow key (observed key == value) (observed key)
  prefix key value = LedgerRow key (value `Text.isPrefixOf` observed key) (observed key)
  prefixWithin key value = LedgerRow key (value `Text.isInfixOf` observed key) (observed key)
  hex64 key = LedgerRow key (Text.length (observed key) == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) (observed key)) (observed key)
  equalRows name first second = LedgerRow name (observed first == observed second && observed first /= "<absent>") (observed first <> " vs " <> observed second)
  contains key members = LedgerRow key (all (`elem` Text.splitOn "," (observed key)) members) (observed key)
