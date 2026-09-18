{-# LANGUAGE OverloadedStrings #-}

-- | Stage 5 of the runner (gate_runner_doctrine.md section 3; AGENTS.md "Kernel
-- Budget"): the kernel line count against the smaller of fourteen thousand and
-- the last accepted count, no conditional compilation, no per-phase run module,
-- no phase-number literal, one phase table, and one definition per vocabulary
-- type. The row is computed from the tree, never from a candidate's claim.
module Amoebius.Validation.Runner.Hygiene
  ( HygieneReport (..)
  , docCheckRoot
  , hygieneGreen
  , hygieneProblems
  , hygieneRow
  , kernelBudget
  , kernelRoots
  , renderHygiene
  , vocabularyTypes
  ) where

import Control.Monad (filterM, forM)
import Data.Char (isDigit)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (makeRelative, splitDirectories, takeBaseName, (</>))

kernelBudget :: Int
kernelBudget = 14000

-- | The roots the kernel budget covers: the runner and custody core, and the
-- gate-specification library.
kernelRoots :: [FilePath]
kernelRoots = ["src/validation-kernel", "src/gate-spec"]

docCheckRoot :: FilePath
docCheckRoot = "src/doc-check"

-- | The vocabulary axes that must have exactly one definition inside the validator
-- roots; duplicates elsewhere under src/ are observed on the row and owed to the
-- phase that owns the vocabulary library (DL-0012).
vocabularyTypes :: [Text]
vocabularyTypes = ["Substrate", "Lane", "Architecture", "ComputeEngine", "EngineRuntime", "ExtensionId", "ResourceVector", "Register"]

data HygieneReport = HygieneReport
  { hygieneKernelLines :: Int
  , hygieneKernelCap :: Int
  , hygieneDocCheckLines :: Int
  , hygieneDocCheckCap :: Int
  , hygieneConditionalCompilation :: [(FilePath, Int)]
  , hygieneRunModules :: [FilePath]
  , hygienePhaseLiterals :: [(FilePath, Int, Text)]
  , hygienePhaseTables :: [FilePath]
  , hygieneDuplicateVocabulary :: [(Text, [FilePath])]
  , hygieneProductDuplicateVocabulary :: [(Text, [FilePath])]
  }
  deriving (Eq, Show)

-- | Compute the row for a tree. The cap is the smaller of the budget and the last
-- accepted count when one exists.
hygieneRow :: FilePath -> Maybe Int -> Int -> IO HygieneReport
hygieneRow root lastAccepted docCheckCap = do
  kernelFiles <- concat <$> mapM (haskellFilesUnder root) kernelRoots
  docFiles <- haskellFilesUnder root docCheckRoot
  productFiles <- haskellFilesUnder root "src"
  kernelSources <- forM kernelFiles $ \file -> (,) file <$> TextIO.readFile (root </> file)
  docSources <- forM docFiles $ \file -> (,) file <$> TextIO.readFile (root </> file)
  productSources <- forM productFiles $ \file -> (,) file <$> TextIO.readFile (root </> file)
  let kernelLines = sum [length (Text.lines source) | (_, source) <- kernelSources]
      docLines = sum [length (Text.lines source) | (_, source) <- docSources]
      cpp = [(file, number) | (file, source) <- kernelSources, (number, line) <- zip [1 ..] (Text.lines source), "#" `Text.isPrefixOf` line]
      runModules = [file | (file, _) <- kernelSources, isRunModule file]
      literals =
        [ (file, number, Text.strip line)
        | (file, source) <- kernelSources
        , (number, line) <- zip [1 ..] (Text.lines source)
        , phaseLiteral line
        ]
      tables = [file | (file, source) <- kernelSources, any phaseTableDefinition (Text.lines source)]
      definitionsIn sources =
        Map.fromListWith
          (<>)
          [ (name, [file])
          | (file, source) <- sources
          , line <- Text.lines source
          , Just name <- [definedType line]
          , name `elem` vocabularyTypes
          ]
      duplicatesIn sources = [(name, sort files) | (name, files) <- Map.toList (definitionsIn sources), length files > 1]
      duplicates = duplicatesIn kernelSources
      productDuplicates = duplicatesIn productSources
  pure
    HygieneReport
      { hygieneKernelLines = kernelLines
      , hygieneKernelCap = maybe kernelBudget (min kernelBudget) lastAccepted
      , hygieneDocCheckLines = docLines
      , hygieneDocCheckCap = docCheckCap
      , hygieneConditionalCompilation = cpp
      , hygieneRunModules = runModules
      , hygienePhaseLiterals = literals
      , hygienePhaseTables = tables
      , hygieneDuplicateVocabulary = duplicates
      , hygieneProductDuplicateVocabulary = productDuplicates
      }

-- | A per-phase run module: a path segment ending in @Run@ (@PhaseZeroRun@,
-- @ArtifactCalculusRun/Internal.hs@). The generic @Runner@ is not one.
isRunModule :: FilePath -> Bool
isRunModule file = any segmentIsRun (splitDirectories file)
 where
  segmentIsRun segment =
    let base = takeBaseName segment
     in "Run" `isSuffixOf` base && base /= "Run"

-- | A phase ordinal spelled into kernel source: @phase-NN@, @PhaseNN@, @phase NN@.
phaseLiteral :: Text -> Bool
phaseLiteral line =
  any (\needle -> any (digitAfter needle) (Text.breakOnAll needle line)) ["phase-", "Phase-", "phase_", "Phase ", "phase "]
 where
  digitAfter needle (_, rest) =
    let after = Text.drop (Text.length needle) rest
     in not (Text.null after) && isDigit (Text.head after) && not ("--" `Text.isPrefixOf` Text.stripStart line)

phaseTableDefinition :: Text -> Bool
phaseTableDefinition line =
  any (`Text.isPrefixOf` line) ["canonicalPhaseIdentities ::", "phaseMetadata ::", "canonicalPhaseRegistry ::", "canonicalPhasePaths ::"]

definedType :: Text -> Maybe Text
definedType line =
  case Text.words line of
    ("data" : name : _) -> Just (Text.takeWhile (/= '(') name)
    ("newtype" : name : _) -> Just name
    _ -> Nothing

hygieneProblems :: HygieneReport -> [Text]
hygieneProblems report =
  [ "KernelOverBudget: " <> showText (hygieneKernelLines report) <> " lines against a cap of " <> showText (hygieneKernelCap report)
  | hygieneKernelLines report > hygieneKernelCap report
  ]
    <> [ "DocCheckOverBudget: " <> showText (hygieneDocCheckLines report) <> " lines against a cap of " <> showText (hygieneDocCheckCap report)
       | hygieneDocCheckLines report > hygieneDocCheckCap report
       ]
    <> ["ConditionalCompilation: " <> showText (length (hygieneConditionalCompilation report)) <> " lines" | not (null (hygieneConditionalCompilation report))]
    <> ["RunModules: " <> Text.intercalate "," (map Text.pack (take 5 (hygieneRunModules report))) | not (null (hygieneRunModules report))]
    <> ["PhaseLiterals: " <> showText (length (hygienePhaseLiterals report)) | not (null (hygienePhaseLiterals report))]
    <> ["PhaseTables: " <> Text.intercalate "," (map Text.pack (hygienePhaseTables report)) | length (hygienePhaseTables report) > 1]
    <> ["DuplicateVocabulary: " <> Text.intercalate "," (map fst (hygieneDuplicateVocabulary report)) | not (null (hygieneDuplicateVocabulary report))]

hygieneGreen :: HygieneReport -> Bool
hygieneGreen = null . hygieneProblems

renderHygiene :: HygieneReport -> [(Text, Text)]
renderHygiene report =
  [ ("hygiene.kernel-lines", showText (hygieneKernelLines report))
  , ("hygiene.kernel-cap", showText (hygieneKernelCap report))
  , ("hygiene.doc-check-lines", showText (hygieneDocCheckLines report))
  , ("hygiene.doc-check-cap", showText (hygieneDocCheckCap report))
  , ("hygiene.conditional-compilation-lines", showText (length (hygieneConditionalCompilation report)))
  , ("hygiene.run-modules", showText (length (hygieneRunModules report)))
  , ("hygiene.phase-literals", showText (length (hygienePhaseLiterals report)))
  , ("hygiene.phase-tables", showText (length (hygienePhaseTables report)))
  , ("hygiene.duplicate-vocabulary", showText (length (hygieneDuplicateVocabulary report)))
  , ("hygiene.product-duplicate-vocabulary", Text.intercalate "," (map fst (hygieneProductDuplicateVocabulary report)))
  , ("hygiene.verdict", if hygieneGreen report then "green" else Text.intercalate "; " (hygieneProblems report))
  ]

haskellFilesUnder :: FilePath -> FilePath -> IO [FilePath]
haskellFilesUnder root relative = do
  exists <- doesDirectoryExist (root </> relative)
  if not exists then pure [] else map (makeRelative root) <$> walk (root </> relative)
 where
  walk directory = do
    names <- listDirectory directory
    directories <- filterM (doesDirectoryExist . (directory </>)) names
    nested <- concat <$> mapM (walk . (directory </>)) directories
    pure ([directory </> name | name <- names, ".hs" `isSuffixOf` name, name `notElem` directories] <> nested)

showText :: Int -> Text
showText = Text.pack . show

_unusedPrefix :: String -> String -> Bool
_unusedPrefix = isPrefixOf
