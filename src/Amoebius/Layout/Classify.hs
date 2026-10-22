{-# LANGUAGE OverloadedStrings #-}

-- | Closed classification of repository paths. The input is an independently
-- acquired path inventory; neither a plan document nor a claimed path count is
-- consulted here.
module Amoebius.Layout.Classify
  ( PathClass (..)
  , LayoutFinding (..)
  , classifyPath
  , classifyPaths
  , testSourcePaths
  , testSourceFindings
  , testSourceExamples
  , toolSourceExamples
  , pulumiSourceExamples
  , RuntimeIdentityInput (..)
  , runtimeIdentityExamples
  , runtimeIdentityControls
  , checkRuntimeComponent
  , IgnoreContextEdit (..)
  , ignoreContextExamples
  , ignoreContextControls
  , checkIgnorePolicy
  , checkRuntimeText
  , renderFinding
  , renderPathClass
  ) where

import Data.List (group, sort)
import Data.Char (isSymbol)
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath (takeExtension)
import System.FilePath.Posix qualified as Posix

data PathClass
  = HaskellSource
  | BootstrapSource
  | GovernanceDocument
  | BuildMetadata
  | RepositoryMetadata
  | HistoricalEvidence
  deriving (Eq, Ord, Show)

data LayoutFinding = LayoutFinding
  { findingCode :: Text
  , findingPath :: FilePath
  }
  deriving (Eq, Ord, Show)

renderPathClass :: PathClass -> Text
renderPathClass pathClass = case pathClass of
  HaskellSource -> "haskell-source"
  BootstrapSource -> "bootstrap-source"
  GovernanceDocument -> "governance-document"
  BuildMetadata -> "build-metadata"
  RepositoryMetadata -> "repository-metadata"
  HistoricalEvidence -> "historical-evidence"

renderFinding :: LayoutFinding -> Text
renderFinding finding =
  findingCode finding <> "\t" <> Text.pack (findingPath finding)

-- | The sole admitted metadata set is the two package descriptions, the two
-- ignore policies, one probe package description, and the licence text.
-- Markdown and the bounded bootstrap are different classes.
metadataPaths :: [(FilePath, PathClass)]
metadataPaths =
  [ ("amoebius.cabal", BuildMetadata)
  , ("cabal.project", BuildMetadata)
  , ("probe/probe.cabal", BuildMetadata)
  , (".gitignore", RepositoryMetadata)
  , (".dockerignore", RepositoryMetadata)
  , ("LICENSE", RepositoryMetadata)
  ]

classifyPath :: FilePath -> Either LayoutFinding PathClass
classifyPath path
  | null path || take 1 path == "/" || any (`elem` ["", ".", ".."]) (splitPath path) = reject "NonCanonicalPath"
  | Just pathClass <- lookup path metadataPaths = Right pathClass
  | path == "pb/__main__.py" = Right BootstrapSource
  | "pb/" `prefix` path = reject "BootstrapExtraSource"
  | "validation-records/" `prefix` path =
      if historicalEvidenceShape path then Right HistoricalEvidence else reject "UnexpectedValidationRecord"
  | path `elem` ["AGENTS.md", "CLAUDE.md", "README.md"] = Right GovernanceDocument
  | "DEVELOPMENT_PLAN/" `prefix` path || "documents/" `prefix` path =
      if takeExtension path == ".md" then Right GovernanceDocument else reject "NonMarkdownGovernanceInput"
  | "test/" `prefix` path =
      if takeExtension path == ".hs" then Right HaskellSource else reject "NonHaskellTestInput"
  | "src/" `prefix` path || "app/" `prefix` path || "probe/" `prefix` path =
      if takeExtension path /= ".hs" then reject "NonHaskellSource" else
        if ordinalName path then reject "OrdinalRuntimeIdentity" else Right HaskellSource
  | "tools/" `prefix` path = reject "TrackedToolRoot"
  | "pulumi/" `prefix` path = reject "TrackedPulumiProgram"
  | any (`prefix` path) ["dhall/", "proto/", "ui/"] = reject "ForeignSourceOwed"
  | takeExtension path == ".dhall" = reject "TrackedDhall"
  | takeExtension path == ".proto" = reject "TrackedProto"
  | takeExtension path == ".py" = reject "TrackedPythonOutsidePb"
  | otherwise = reject "UnclassifiedTrackedPath"
 where
  reject code = Left (LayoutFinding code path)

-- | Exactly one result for each distinct path, and a separate failure for an
-- absent metadata member or a repeated path. This prevents a short or repeated
-- manifest from satisfying the six-file count.
classifyPaths :: [FilePath] -> ([(FilePath, PathClass)], [LayoutFinding])
classifyPaths paths =
  ([(path, pathClass) | path <- sorted, Right pathClass <- [classifyPath path]]
  , [finding | path <- sorted, not ("test/" `prefix` path), Left finding <- [classifyPath path]]
      <> testSourceFindings paths
      <> [LayoutFinding "DuplicateTrackedPath" path | (path : _ : _) <- group sorted, not ("test/" `prefix` path)]
      <> [LayoutFinding "MissingMetadata" path | (path, _) <- metadataPaths, path `notElem` paths]
  )
 where
  sorted = sort paths

-- | The complete authored test inventory, independent of extension or role.
testSourcePaths :: [FilePath] -> [FilePath]
testSourcePaths = filter ("test/" `prefix`)

testSourceFindings :: [FilePath] -> [LayoutFinding]
testSourceFindings paths =
  [finding | path <- selected, Left finding <- [classifyPath path]]
    <> [LayoutFinding "DuplicateTrackedPath" path | (path : _ : _) <- group selected]
    <> [LayoutFinding "TestSourceInventoryEmpty" "test" | null selected]
 where selected = sort (testSourcePaths paths)

-- | Input examples only; foreign forms are emitted in owned scratch by callers.
-- The shipped report projects their identities; independent oracles own verdicts.
testSourceExamples :: [(Text, Text, FilePath, Text)]
testSourceExamples =
  [("tracked-test-script", "python", "test/source-control/check.py", "print(True)\n")
  ,("tracked-test-script", "shell", "test/source-control/check.sh", "exit 0\n")
  ,("tracked-test-script", "extensionless", "test/source-control/check", "#!/bin/sh\nexit 0\n")
  ,("tracked-test-table", "json", "test/source-control/cases.json", "{\"expected\":true}\n")
  ,("tracked-test-table", "yaml", "test/source-control/cases.yaml", "expected: true\n")
  ,("tracked-test-table", "tsv", "test/source-control/cases.tsv", "case\texpected\ninput\tTrue\n")
  ,("tracked-expected-output", "golden", "test/golden/output.expected", "accepted\n")
  ,("tracked-expected-output", "output", "test/source-control/output.out", "accepted\n")
  ,("tracked-expected-output", "markdown", "test/source-control/output.md", "expected: accepted\n")
  ,("tracked-patch", "patch", "test/source-control/change.patch", "--- a/Input.hs\n+++ b/Input.hs\n@@ -1 +1 @@\n-old\n+new\n")
  ,("tracked-patch", "diff", "test/source-control/change.diff", "--- a/Input.hs\n+++ b/Input.hs\n@@ -1 +1 @@\n-old\n+new\n")
  ,("tracked-mutant-body", "python", "test/variants/altered.py", "accepted = False\n")
  ,("tracked-mutant-body", "disabled-haskell", "test/variants/altered.hs.disabled", "module Altered where\naccepted = False\n")
  ,("tracked-mutant-body", "extensionless", "test/variants/altered", "accepted = False\n")]

-- | Tool migrations exercise both the retired root and arbitrary renamed roots.
-- Verdicts belong to callers' independent oracles, never to these input values.
toolSourceExamples :: [(Text, Text, FilePath, Text)]
toolSourceExamples =
  [("tracked-python-gate", "tool-root", "tools/layout_gate.py", "print(True)\n")
  ,("tracked-python-gate", "renamed-python", "automation/layout_gate.py", "print(True)\n")
  ,("renamed-tool-root", "haskell", "automation/LayoutGate.hs", "module LayoutGate where\naccepted = True\n")
  ,("renamed-tool-root", "extensionless", "automation/layout-gate", "#!/bin/sh\nexit 0\n")
  ,("renamed-tool-root", "state-name-file", "dist-newstyle", "#!/bin/sh\nexit 0\n")]

-- | Foreign infrastructure inputs are refused even when their root is renamed.
pulumiSourceExamples :: [(Text, Text, FilePath, Text)]
pulumiSourceExamples =
  [("tracked-pulumi-yaml", "original-root", "pulumi/Pulumi.yaml", "resources: {}\n")
  ,("renamed-pulumi-program", "yaml", "infrastructure/Pulumi.yaml", "resources: {}\n")
  ,("renamed-pulumi-program", "typescript", "infrastructure/index.ts", "export const accepted = true;\n")
  ,("renamed-pulumi-program", "python", "infrastructure/__main__.py", "accepted = True\n")]

-- | Counterexample inputs are assembled from an ordinal value; they are not
-- names used by the product itself. Independent oracles own their verdicts.
data RuntimeIdentityInput = RuntimeIdentitySource FilePath Text | RuntimeIdentityPackage FilePath Text
  deriving (Eq, Show)

runtimeIdentityExamples :: [(Text, Text, RuntimeIdentityInput)]
runtimeIdentityExamples =
  [("stale-ordinal", variant, RuntimeIdentitySource "src/Amoebius/IdentityInput.hs"
      ("module IdentityInput where\ndiagnosticName = " <> Text.pack (show label) <> "\n"))
    | (variant, label) <- [("plain", tag "phase"), ("mixed-case", tag "pHaSe"), ("hyphen", tag "phase-"), ("underscore", tag "phase_"), ("quoted-comment-marker", "{- " <> tag "phase" <> " -}")]]
  <> [("copied-ordinal", variant, RuntimeIdentitySource path "module IdentityInput where\nidentity = \"runtime\"\n")
     | (variant, path) <- [("plain", "src/Amoebius/" <> Text.unpack (tag "Phase") <> "Copy.hs"),
         ("hyphen", "src/Amoebius/" <> Text.unpack (tag "phase-") <> "/Copy.hs"),
         ("underscore", "app/" <> Text.unpack (tag "phase_") <> "/Main.hs")]]
  <> [("phase-named-runtime", variant, RuntimeIdentityPackage "amoebius.cabal" (header <> stanza))
     | (variant, stanza) <-
       [("executable", "executable " <> tag "phase" <> "-runtime\n  main-is: Main.hs\n  hs-source-dirs: app/amoebius\n  default-language: Haskell2010\n")
       ,("library", "library " <> tag "phase" <> "-library\n  exposed-modules: Example\n  hs-source-dirs: src\n  default-language: Haskell2010\n")
       ,("empty-library", "library " <> tag "phase" <> "-empty\n  hs-source-dirs: src\n  buildable: False\n")
       ,("foreign-library", "foreign-library " <> tag "phase" <> "-foreign\n  type: native-shared\n  hs-source-dirs: src\n  buildable: False\n")
       ,("benchmark", "benchmark " <> tag "phase" <> "-benchmark\n  type: exitcode-stdio-1.0\n  main-is: Main.hs\n  hs-source-dirs: app/amoebius\n  default-language: Haskell2010\n")
       ,("conditional", "executable " <> tag "phase" <> "-conditional\n  main-is: Main.hs\n  default-language: Haskell2010\n  if os(windows)\n    hs-source-dirs: test/oracle\n  else\n    hs-source-dirs: app/amoebius\n")]]
  <> [("phase-named-runtime", "disguised-validation-root", RuntimeIdentityPackage "amoebius.cabal"
      (header <> "library " <> tag "phase" <> "-disguised\n  hs-source-dirs: test/../src\n  buildable: False\n"))]
 where
  tag prefixText = prefixText <> Text.pack (show (42 :: Int))
  header = "cabal-version: 3.0\nname: runtime-input\nversion: 0.1.0.0\n"

runtimeIdentityControls :: [(Text, RuntimeIdentityInput)]
runtimeIdentityControls =
  [("validation-source", RuntimeIdentitySource ("test/oracle/" <> Text.unpack label <> "Contract.hs")
      ("module Contract where\nvalidatedName = " <> Text.pack (show label) <> "\n"))
  ,("validation-component", RuntimeIdentityPackage "amoebius.cabal"
      (header <> "test-suite " <> Text.toLower label <> "-contract\n  type: exitcode-stdio-1.0\n  main-is: Main.hs\n  hs-source-dirs: test/oracle\n  default-language: Haskell2010\n"))
  ,("malformed-package", RuntimeIdentityPackage "amoebius.cabal" "this is not a package description\n")]
  <> [("block-comments", RuntimeIdentitySource "src/Amoebius/IdentityComments.hs"
      ("module IdentityComments where\nquote = '\\''\n{- Outer " <> label <> "\n {- nested " <> Text.toLower label <> " -}\n-}\nidentity = \"runtime\" -- " <> label <> "\n"))]
 where
  label = "Phase" <> Text.pack (show (42 :: Int))
  header = "cabal-version: 3.0\nname: runtime-input\nversion: 0.1.0.0\n"

-- | A component is validation-only only when every declared source root is
-- validation-owned; disabled and empty runtime components have no exemption.
checkRuntimeComponent :: FilePath -> Text -> [FilePath] -> [LayoutFinding]
checkRuntimeComponent packagePath name directories =
  [LayoutFinding "OrdinalRuntimeIdentity" (packagePath <> ":" <> Text.unpack name)
    | ordinalToken name, not (not (null directories) && all validationSourcePath directories)]

validationSourcePath :: FilePath -> Bool
validationSourcePath input = not (Posix.isAbsolute candidate) && ".." `notElem` Posix.splitDirectories candidate
  && any (\root -> candidate == root || (root <> "/") `prefix` candidate)
  ["test", "src/gate-spec", "src/validation-kernel", "src/doc-check", "src/plan-decisions", "src/tool-and-mutant-generation", "app/amoebius-validate"]
 where candidate = Posix.normalise input

-- | Input edits only. The original policy bytes are acquired by the caller.
data IgnoreContextEdit = OmitIgnorePattern FilePath Text | AppendIgnoreLines FilePath Text
  deriving (Eq, Show)

ignoreContextExamples :: [(Text, Text, FilePath, Text)]
ignoreContextExamples =
  [("retired-generated-root", Text.pack path <> ":" <> root, path, root <> "\n")
    | path <- [".gitignore", ".dockerignore"], root <- ["ui/", "dhall/", "proto/", "pulumi/", "tools/", "test/golden/"]]
  <> [("undeclared-state-root", Text.pack path <> ":" <> patternText, path, patternText <> "\n")
      | (path,patterns) <- [(".gitignore", ["/src/.generated/", "/scratch/"]), (".dockerignore", ["src/.generated", "scratch"])], patternText <- patterns]

ignoreContextControls :: [(Text, IgnoreContextEdit)]
ignoreContextControls =
  [("missing-state:" <> Text.pack path, OmitIgnorePattern path patternText)
    | (path,patternText) <- [(".gitignore", "/.build/"), (".dockerignore", ".build")]]
  <> [("missing-spill:" <> Text.pack path, OmitIgnorePattern path patternText)
      | (path,patternText) <- [(".gitignore", "*.o"), (".dockerignore", "**/*.o")]]
  <> [("hidden-archive", AppendIgnoreLines ".gitignore" "validation-records/\n")]
  <> [("comments:" <> Text.pack path, AppendIgnoreLines path "\n# tools/ is a comment\n\n") | path <- [".gitignore", ".dockerignore"]]

-- | Policy files may catch tool spill, but cannot hide a retired authored
-- root or omit a contained-state root. The container context also excludes
-- the historical archive; the worktree ignore must leave it visible.
checkIgnorePolicy :: FilePath -> Text -> [LayoutFinding]
checkIgnorePolicy path contents =
  [LayoutFinding "MissingIgnoreRoot" (path <> ":" <> Text.unpack required) | required <- requiredPatterns, required `notElem` patterns]
    <> [LayoutFinding "RetiredIgnoreRoot" (path <> ":" <> Text.unpack patternText) | patternText <- patterns, retired patternText]
    <> [LayoutFinding "IgnoredValidationArchive" path | path == ".gitignore", any ("validation-records" `Text.isInfixOf`) patterns]
    <> [LayoutFinding "UnexpectedIgnorePattern" (path <> ":" <> Text.unpack patternText)
       | patternText <- patterns, patternText `notElem` allowedPatterns, not (retired patternText),
         not (path == ".gitignore" && "validation-records" `Text.isInfixOf` patternText)]
    <> [LayoutFinding "MissingIgnorePattern" (path <> ":" <> Text.unpack patternText)
       | patternText <- allowedPatterns, patternText `notElem` patterns]
 where
  patterns = [Text.strip line | line <- Text.lines contents, let stripped = Text.strip line, not (Text.null stripped), not ("#" `Text.isPrefixOf` stripped)]
  requiredPatterns
    | path == ".gitignore" = ["/.build/", "/.data/", "/.test_data/"]
    | path == ".dockerignore" = [".git", ".build", ".data", ".test_data", "validation-records"]
    | otherwise = []
  retired patternText =
    let normalized = Text.dropWhile (== '/') patternText
     in any (`Text.isPrefixOf` normalized) ["ui/", "dhall/", "proto/", "pulumi/", "tools/", "test/golden/"]
  allowedPatterns
    | path == ".gitignore" = Text.words
        "/.build/ /.data/ /.test_data/ *.lock *.freeze package-lock.json npm-shrinkwrap.json pnpm-lock.yaml go.sum dist-newstyle/ .cabal-sandbox/ .ghc.environment.* *.o *.hi *.dyn_o *.dyn_hi *.hie *.tla *.cfg node_modules/ __pycache__/ *.py[cod] .venv/ cabal.project.local .DS_Store .pytest_cache/ .coverage .coverage.* htmlcov/ playwright-report/ test-results/ *.log *.pid *.sock /test-secrets.dhall"
    | path == ".dockerignore" = Text.words
        ".git .git/** .build .build/** .data .data/** .test_data .test_data/** validation-records validation-records/** **/*.lock **/*.freeze **/package-lock.json **/npm-shrinkwrap.json **/pnpm-lock.yaml **/go.sum **/dist-newstyle **/dist-newstyle/** **/.cabal-sandbox **/.cabal-sandbox/** **/.ghc.environment.* **/node_modules **/node_modules/** **/*.o **/*.hi **/*.dyn_o **/*.dyn_hi **/*.hie **/*.tla **/*.cfg **/__pycache__ **/__pycache__/** **/*.pyc **/*.pyo **/*.pyd **/.venv **/.venv/** **/cabal.project.local **/.DS_Store **/.pytest_cache **/.pytest_cache/** **/.coverage **/.coverage.* **/htmlcov **/htmlcov/** **/playwright-report **/playwright-report/** **/test-results **/test-results/** **/*.log **/*.pid **/*.sock test-secrets.dhall"
    | otherwise = []

-- | Ordinal-bearing validation contracts are permitted in validator-only
-- roots. Shipped product source must name runtime identities by capability.
checkRuntimeText :: FilePath -> Text -> [LayoutFinding]
checkRuntimeText path contents
  | not (productSource path) = []
  | otherwise = [LayoutFinding "OrdinalRuntimeIdentity" (path <> ":" <> show lineNumber)
                | (lineNumber, line) <- zip [1 :: Int ..] (runtimeSourceLines contents)
                , let sourceLine = Text.stripStart line
                , not ("--" `Text.isPrefixOf` sourceLine)
                , ordinalToken sourceLine]
 where
  productSource candidate =
    ("src/" `prefix` candidate || "app/" `prefix` candidate)
      && takeExtension candidate == ".hs"
      && not (validationSourcePath candidate)

-- Preserve source line numbers and literal contents while excluding nested
-- block and line comments. Quoted comment-looking text remains observable.
runtimeSourceLines :: Text -> [Text]
runtimeSourceLines = Text.lines . Text.pack . scan 0 False . Text.unpack
 where
  scan :: Int -> Bool -> String -> String
  scan _ _ [] = []
  scan depth quoted input
    | depth > 0 = case input of
        '{' : '-' : rest -> ' ' : ' ' : scan (depth + 1) False rest
        '-' : '}' : rest -> ' ' : ' ' : scan (depth - 1) False rest
        '\n' : rest -> '\n' : scan depth False rest
        _ : rest -> ' ' : scan depth False rest
    | quoted = case input of
        '\\' : next : rest -> '\\' : next : scan 0 True rest
        '"' : rest -> '"' : scan 0 False rest
        first : rest -> first : scan 0 True rest
    | otherwise = case input of
        '"' : rest -> '"' : scan 0 True rest
        '\'' : '\\' : next : rest -> '\'' : '\\' : next : character rest
        '\'' : value : '\'' : rest -> '\'' : value : '\'' : scan 0 False rest
        '{' : '-' : rest -> ' ' : ' ' : scan 1 False rest
        '-' : '-' : rest | commentAfterDashes rest -> map (const ' ') (takeWhile (/= '\n') rest) <> scan 0 False (dropWhile (/= '\n') rest)
        first : rest -> first : scan 0 False rest
  character [] = []
  character ('\\' : next : rest) = '\\' : next : character rest
  character ('\'' : rest) = '\'' : scan 0 False rest
  character (first : rest) = first : character rest
  commentAfterDashes rest = case dropWhile (== '-') rest of
    [] -> True
    next : _ -> not (next `elem` ("!#$%&*+./<=>?@\\^|~:" :: String) || isSymbol next)

ordinalToken :: Text -> Bool
ordinalToken source = any hasOrdinal ["phase", "phase-", "phase_", "phase "]
 where
  hasOrdinal needle = any (startsWithDigit . Text.drop (Text.length needle) . snd) (Text.breakOnAll needle (Text.toCaseFold source))
  startsWithDigit value = maybe False (asciiDigit . fst) (Text.uncons value)

prefix :: String -> String -> Bool
prefix start value = take (length start) value == start

splitPath :: FilePath -> [String]
splitPath path = case break (== '/') path of
  (part, []) -> [part]
  (part, _ : rest) -> part : splitPath rest

-- | Only source basename components are runtime identities. Plan documents and
-- evidence paths intentionally retain phase ordinals.
ordinalName :: FilePath -> Bool
ordinalName = ordinalToken . Text.pack

-- | The product checks the archive's closed filename shape. The verifier's
-- separate custody reader checks the phase table, file set, bytes, and receipt
-- binding before any historical record can supply evidence.
historicalEvidenceShape :: FilePath -> Bool
historicalEvidenceShape path = case splitPath path of
  ["validation-records", generation, "receipts", phase, file] ->
    generationHex generation && phaseTriple phase && file `elem` receiptFiles
  ["validation-records", generation, "voids", file] ->
    generationHex generation && voidTriple file
  _ -> False
 where
  generationHex segment = case splitAt 11 segment of
    ("generation-", digits) -> lowerHex 16 digits
    _ -> False
  phaseTriple segment = case splitDash segment of
    ["phase", ordinal, digest, bundle] -> ordinalShape ordinal && lowerHex 64 digest && lowerHex 64 bundle
    _ -> False
  voidTriple segment = case splitDash segment of
    ["phase", ordinal, target, digestWithExtension] ->
      ordinalShape ordinal && lowerHex 64 target &&
        case splitAt 64 digestWithExtension of
          (digest, ".tsv") -> lowerHex 64 digest
          _ -> False
    _ -> False
  ordinalShape ordinal = length ordinal == 2 && all asciiDigit ordinal
  lowerHex wanted value = length value == wanted && all (\character -> asciiDigit character || character >= 'a' && character <= 'f') value
  receiptFiles = ["receipt.tsv", "receipt.tsv.sha256", "candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]

splitDash :: String -> [String]
splitDash value = case break (== '-') value of
  (part, []) -> [part]
  (part, _ : rest) -> part : splitDash rest

asciiDigit :: Char -> Bool
asciiDigit character = character >= '0' && character <= '9'
