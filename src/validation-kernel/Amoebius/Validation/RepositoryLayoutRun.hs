{-# LANGUAGE OverloadedStrings #-}

-- | The @repository_layout_conformance@ capability's phase runner.
--
-- The capability's claim is that the target repository layout holds: behavioural
-- source is @.hs@ outside @pb\/**@, consumers resolve at canonical Haskell
-- module and package paths, no newly tracked non-@.hs@ behavioural source
-- appears, and every existing one joins a legacy binding.
--
-- The tracked-source boundary itself is decided by the source-closure subject
-- and is not re-decided here. What this runner owns are the two legacy families
-- assigned to this capability. Both families are decidable from an acquired
-- snapshot. Phase-labelled validation contracts and evidence are deliberately
-- outside the runtime-identity subject: a phase gate must be able to name the
-- phase whose evidence it records without becoming a product identity.
module Amoebius.Validation.RepositoryLayoutRun
  ( repositoryLayoutRunCheck
  , repositoryLayoutQualificationDiagnostic
  , repositoryLayoutRawDiagnostic
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types (CheckResult (..), finding, findingCode, observation)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteString8
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

repositoryLayoutRunCheck :: AcquiredSourceSnapshot -> CheckResult
repositoryLayoutRunCheck acquired = repositoryLayoutCheck entries
 where
  entries =
    [ (indexPath (trackedIndex entry), trackedBytes entry)
    | entry <- snapshotEntries (acquiredSourceSnapshot acquired)
    ]

-- | Refusal-free pure seam for independently authored small corpora. It has no
-- acquired-source constructor and therefore cannot itself become gate evidence.
repositoryLayoutRawDiagnostic :: [(FilePath, ByteString)] -> CheckResult
repositoryLayoutRawDiagnostic = repositoryLayoutCheck

repositoryLayoutCheck :: [(FilePath, ByteString)] -> CheckResult
repositoryLayoutCheck entries =
  CheckResult
    { checkName = "repository-layout-conformance"
    , checkObservations =
        [ observation "repository-layout.retired-ignore-root-count" (countText retiredIgnoreHits)
        , observation "repository-layout.phase-ordinal-source-count" (countText ordinalHits)
        ]
    , checkFindings = ignoreFindings <> ordinalFindings
    }
 where
  pathOf = fst
  textOf entry = either (const "") id (TextEncoding.decodeUtf8' (snd entry))

  -- LTD-META-001. Generated material has no admitted home outside .build/**,
  -- .data/** and the marker-owned .test_data/** root, so an ignore file naming
  -- a retired source-adjacent root still describes a layout the doctrine has
  -- withdrawn.
  retiredIgnoreHits =
    [ (pathOf entry, root)
    | entry <- entries
    , pathOf entry `elem` ignoreContractPaths
    , root <- retiredGeneratedRoots
    , any (Text.isInfixOf root) (Text.lines (textOf entry))
    ]

  -- LTD-NAME-001. A runtime identity names a capability; plan position belongs
  -- to the contract path alone, so an ordinal spelled into Haskell drifts the
  -- moment the plan is rebalanced.
  ordinalHits =
    [ (pathOf entry, literal)
    | entry <- entries
    , runtimeIdentitySourcePath (pathOf entry)
    , literal <- phaseOrdinalLiterals (textOf entry)
    ]

  ignoreFindings =
    [ finding
        "REPOSITORY-LAYOUT-RETIRED-IGNORE-ROOT"
        path
        ("LTD-META-001: the ignore contract still names the retired generated root " <> root)
    | (path, root) <- retiredIgnoreHits
    ]

  ordinalFindings =
    [ finding
        "REPOSITORY-LAYOUT-PHASE-ORDINAL-IN-SOURCE"
        path
        ("LTD-NAME-001: a runtime identity spells a plan ordinal: " <> literal)
    | (path, literal) <- ordinalHits
    ]

-- | Fixed clean and minimally different subjects used to qualify the layout
-- checker. The gate compares this production projection with an independently
-- authored oracle expectation.
repositoryLayoutQualificationDiagnostic :: [(Text, [Text])]
repositoryLayoutQualificationDiagnostic =
  [ (label, map findingCode (checkFindings (repositoryLayoutRawDiagnostic corpus)))
  | (label, corpus) <- qualificationCorpora
  ]
 where
  qualificationCorpora =
    [ ("clean", clean)
    , ("retired-ignore-root", replaceIgnore ".build/\ngen/\n")
    , ("runtime-phase-ordinal", clean <> [("src/Amoebius/Gate.hs", bytes "name = \"phase-07\"\n")])
    , ("validation-phase-label", clean <> [("src/validation-kernel/Amoebius/Validation/Gate.hs", bytes "name = \"phase-07\"\n")])
    ]
  clean =
    [ (".gitignore", bytes ".build/\n.data/\n.test_data/\n")
    , (".dockerignore", bytes ".build/\n.data/\n")
    , ("src/Amoebius/Kernel.hs", bytes "capability = \"documentation_suite\"\n")
    ]
  replaceIgnore contents = (".gitignore", bytes contents) : drop 1 clean
  bytes = ByteString8.pack

-- | The two files that carry the ignore contract.
ignoreContractPaths :: [FilePath]
ignoreContractPaths = [".gitignore", ".dockerignore"]

-- | Generated roots the layout doctrine has withdrawn. Authored here from the
-- doctrine, never read back from either ignore file.
retiredGeneratedRoots :: [Text]
retiredGeneratedRoots =
  [ "gen/"
  , "DEVELOPMENT_PLAN/evidence"
  , "test/enumeration"
  ]

-- | Quoted phase ordinals appearing in Haskell text.
--
-- The pattern is deliberately narrow: a string literal opening on @phase-@ or
-- @phase_@ immediately followed by a digit. A constructed identity such as
-- @"phase-" <> render ordinal@ is not a spelled ordinal and is not reported.
phaseOrdinalLiterals :: Text -> [Text]
phaseOrdinalLiterals contents =
  [ Text.drop 1 prefix <> Text.takeWhile (/= '"') candidate
  | prefix <- ["\"phase-", "\"phase_"]
  , -- 'Text.splitOn' already removes the separator, so every element after the
    -- first begins immediately at the character following it.
    candidate <- drop 1 (Text.splitOn prefix contents)
  , maybe False isDigitChar (fst <$> Text.uncons candidate)
  ]
 where
  isDigitChar character = character >= '0' && character <= '9'

-- | Product/runtime modules are the only possible runtime-identity owners.
-- The source-bound validation kernel names phase contracts and evidence, and
-- tests name the exact phase whose negative they exercise; neither namespace
-- is admitted as a product identity.
runtimeIdentitySourcePath :: FilePath -> Bool
runtimeIdentitySourcePath path =
  hasPrefix "src/Amoebius/" path && hasSuffix ".hs" path

countText :: [value] -> Text
countText = Text.pack . show . length

hasSuffix :: String -> FilePath -> Bool
hasSuffix suffix = Text.isSuffixOf (Text.pack suffix) . Text.pack

hasPrefix :: String -> FilePath -> Bool
hasPrefix prefix = Text.isPrefixOf (Text.pack prefix) . Text.pack
