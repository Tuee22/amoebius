{-# LANGUAGE OverloadedStrings #-}

-- | Closed classification of repository paths. The input is an independently
-- acquired path inventory; neither a plan document nor a claimed path count is
-- consulted here.
module Amoebius.Layout.Classify
  ( PathClass (..)
  , LayoutFinding (..)
  , classifyPath
  , classifyPaths
  , checkIgnorePolicy
  , checkRuntimeText
  , renderFinding
  , renderPathClass
  ) where

import Data.List (group, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath (takeExtension)

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
  , [finding | path <- sorted, Left finding <- [classifyPath path]]
      <> [LayoutFinding "DuplicateTrackedPath" path | (path : _ : _) <- group sorted]
      <> [LayoutFinding "MissingMetadata" path | (path, _) <- metadataPaths, path `notElem` paths]
  )
 where
  sorted = sort paths

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
                | (lineNumber, line) <- zip [1 :: Int ..] (Text.lines contents)
                , let sourceLine = Text.stripStart line
                , not ("--" `Text.isPrefixOf` sourceLine)
                , ordinalToken sourceLine]
 where
  productSource candidate =
    ("src/" `prefix` candidate || "app/" `prefix` candidate)
      && takeExtension candidate == ".hs"
      && not (any (`prefix` candidate)
          ["src/gate-spec/", "src/validation-kernel/", "src/doc-check/", "src/plan-decisions/", "src/tool-and-mutant-generation/"])

ordinalToken :: Text -> Bool
ordinalToken source = any hasOrdinal ["Phase", "phase", "phase-", "phase_", "phase "]
 where
  hasOrdinal needle = any (startsWithDigit . Text.drop (Text.length needle) . snd) (Text.breakOnAll needle source)
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
ordinalName path = any hasOrdinal (splitPath path)
 where
  hasOrdinal component = any (isOrdinalAt component) [0 .. length component - 1]
  isOrdinalAt component index =
    let suffix = drop index component
        after = case suffix of
          'P' : 'h' : 'a' : 's' : 'e' : rest -> rest
          'p' : 'h' : 'a' : 's' : 'e' : rest -> rest
          _ -> ""
     in case after of
          first : _ -> asciiDigit first
          _ -> False

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
