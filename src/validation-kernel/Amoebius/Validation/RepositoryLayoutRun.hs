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
-- assigned to this capability and the contract rows it leaves unbound. Both
-- families are decidable from an acquired snapshot, and both are open, so this
-- runner reports real debt rather than an absence of evidence.
module Amoebius.Validation.RepositoryLayoutRun
  ( repositoryLayoutRunCheck
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types (CheckResult (..), finding, observation)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

repositoryLayoutRunCheck :: AcquiredSourceSnapshot -> CheckResult
repositoryLayoutRunCheck acquired =
  CheckResult
    { checkName = "repository-layout-conformance"
    , checkObservations =
        [ observation "repository-layout.retired-ignore-root-count" (countText retiredIgnoreHits)
        , observation "repository-layout.phase-ordinal-source-count" (countText ordinalHits)
        ]
    , checkFindings = ignoreFindings <> ordinalFindings <> unresolvedFindings
    }
 where
  entries = snapshotEntries (acquiredSourceSnapshot acquired)
  pathOf = indexPath . trackedIndex
  textOf entry = either (const "") id (TextEncoding.decodeUtf8' (trackedBytes entry))

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
    , hasSuffix ".hs" (pathOf entry)
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

  unresolvedFindings =
    [ finding
        "REPOSITORY-LAYOUT-SUBJECT-UNRESOLVED"
        "DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md"
        "no production module and entry point are bound as this capability's Subject"
    , finding
        "REPOSITORY-LAYOUT-ORACLE-UNRESOLVED"
        "DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md"
        "no separately authored oracle, independence boundary, or provenance is bound"
    ]

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

countText :: [value] -> Text
countText = Text.pack . show . length

hasSuffix :: String -> FilePath -> Bool
hasSuffix suffix = Text.isSuffixOf (Text.pack suffix) . Text.pack
