{-# LANGUAGE OverloadedStrings #-}

-- The extended oracle is selected by the compiled gate contract. No marker
-- emitted by a producer may activate or skip any of its required sections.
-- A case with an unimplemented observation remains red through the exact
-- required-row join below; existing components cannot close a larger claim.
module ExtensionsOracle (extensionRows) where

import Control.Exception (IOException, try)
import Data.Text qualified as Text
import DslConformance (conformanceRows)
import DslExtensionAst (extensionAstRows)
import DslExtensionCodec (extensionCodecRows)
import DslExtensionLower (extensionLowerRows, mixedRuntimeRows)
import DslExtensionRuntime (runtimeRows, binaryRuntimeRows)
import DslExtensionRegistry (extensionRegistryRows)
import DslExtensionTransport (transportRows)
import DslExtensionTypes (conformanceTypeRows, closedApiRows)
import DslExtensionsExpected (AstExpected (..), astExpectations, astPairs)
import DslOracle (coreRowsWithBinary)
import DslParse
import DslSibling (sourceSiblingRows)
import System.Directory (listDirectory, doesDirectoryExist)
import System.FilePath ((</>))

extensionRows :: Maybe FilePath -> FilePath -> FilePath -> IO [Row]
extensionRows compiler buildDirectory suite = do
  -- This entry point never applies the predecessor's ObjectStore-only binary
  -- expectations to an inference input. The extension cases require their
  -- own runtime and source-sibling observations, even in their absence.
  core <- coreRowsWithBinary False binaryRows compiler buildDirectory suite
  ast <- extensionAstRows (suite </> "extensions/ast")
  codec <- triples "extensions.spec." <$> extensionCodecRows (suite </> "extensions/codec")
  registry <- map registryRow <$> extensionRegistryRows "." (suite </> "extensions/registry")
  lower <- extensionLowerRows (suite </> "extensions/lower")
  models <- rename "extensions.conformance." "workflow.conformance." <$> conformanceRows (suite </> "extensions/conformance")
  native <- rename "extensions.native-types." "scope.native-types." <$> conformanceTypeRows compiler buildDirectory suite
  closed <- closedApiRows compiler buildDirectory suite
  transport <- triples "astcheck." <$> transportRows (suite </> "extensions/transport")
  runtime <- runtimeRows suite
  mixed <- mixedRuntimeRows (suite </> "extensions/runtime/mixed/compiled")
  marker <- readText (suite </> "extensions.marker")
  failed <- try (listDirectory (suite </> "sections")) :: IO (Either IOException [FilePath])
  let details = core <> ast <> codec <> registry <> lower <> models <> native <> closed <> transport <> runtime <> mixed <>
        [check "extensions.complete-sections" (marker == Just "extensions\n" && either (const False) null failed) (Text.pack (show failed))]
  pure (details <> requiredCases details)
 where
  triples prefix = map (\(name, passed, detail) -> Row (prefix <> name) passed detail)
  registryRow (name, passed, detail) = Row
    ((if name `elem` ["registry.dependency-order", "registry.merge-controls"] then "extensions.graph."
      else if "registry.source-" `Text.isPrefixOf` name then "astcheck." else "extensions.spec.") <> name) passed detail
  rename before after = map (\(Row name passed detail) -> Row (maybe name (after <>) (Text.stripPrefix before name)) passed detail)
  binaryRows directory = doesDirectoryExist (directory </> "binary") >>= \present -> if present
    then (<>) <$> sourceSiblingRows directory <*> binaryRuntimeRows directory else pure []

requiredCases :: [Row] -> [Row]
requiredCases observations = [caseRow name required | (name, required) <- cases]
 where
  caseRow name required = check ("case:" <> name)
    (all (\wanted -> [passed | Row actual passed _ <- observations, actual == wanted] == [True]) required)
    ("missing, duplicate or red required boundary: " <> Text.intercalate "," required)
  cases =
    [("infernix-linked", ["runtime.cpu-amd64.complete-manifest", "scope.cpu-amd64.every-object", "workflow.cpu-amd64.consumed"]),
     ("cuda-on-cuda-sibling", ["runtime.cuda-amd64.complete-manifest", "scope.cuda-amd64.every-object", "workflow.cuda-amd64.consumed"]),
     ("attested-scope", ["scope.cpu-arm64.every-object", "scope.native-types.complete-inventory", "scope.closed-api.complete-inventory"]),
     ("UnboundCapability", ["binary.extensions.source-sibling.unbound-exact-app-need"]),
     ("LaneUnavailable", ["extensions.lower.complete-controls"]),
     ("UnattestedScope", ["scope.render.missing-authority-refused"]),
     ("AstEvasion", "astcheck.complete-discovery" :
        ["astcheck." <> nameOf expected | expected <- astExpectations] <>
        ["astcheck.pair." <> name | (name, _) <- astPairs])]
  nameOf expected = case expected of
    Admitted value -> value
    Refused value _ _ _ _ -> value
