{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the @repository_layout_conformance@ runner.
--
-- Expectations are authored from the capability's two owned legacy families,
-- never restated from a run. Each negative
-- differs from 'cleanSnapshot' in exactly one dimension and must add exactly
-- one refusal code.
module RepositoryLayoutRunOracle
  ( runRepositoryLayoutRunOracle
  ) where

import Amoebius.Validation.RepositoryLayoutRun
  ( repositoryLayoutQualificationDiagnostic
  , repositoryLayoutRunCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( IndexEntry (..)
  , IndexMode (RegularFile)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , sourceClosureInternalTestAcquire
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Monad (unless)
import Data.ByteString.Char8 qualified as ByteString8
import Data.Text (Text)
import Data.Text qualified as Text

runRepositoryLayoutRunOracle :: IO ()
runRepositoryLayoutRunOracle = do
  unless (null problems) (fail (unlines ("RepositoryLayoutRunOracle:" : map ("  " <>) problems)))
  putStrLn
    ( "RepositoryLayoutRunOracle: the capability decides its ignore-contract and runtime-identity legacy "
        <> "families and names every contract row it leaves unbound. An inventory and refusal check, not a "
        <> "gate result."
    )
 where
  problems =
    [ "the production qualification projection differs from the independent four-case expectation: "
        <> show repositoryLayoutQualificationDiagnostic
    | repositoryLayoutQualificationDiagnostic /= expectedQualification
    ]
      <> exactly "a snapshot with no open layout debt" cleanSnapshot []
      <> exactly
        "an ignore contract naming a retired generated root"
        (entryWith ".gitignore" ".build/\ngen/\n" : drop 1 cleanSnapshot)
        ["REPOSITORY-LAYOUT-RETIRED-IGNORE-ROOT"]
      <> exactly
        "a runtime identity spelling a plan ordinal"
        (cleanSnapshot <> [entryWith "src/Amoebius/Gate.hs" "name = \"phase-07\"\n"])
        ["REPOSITORY-LAYOUT-PHASE-ORDINAL-IN-SOURCE"]
      <> exactly
        "phase-labelled validation evidence outside the runtime identity namespace"
        (cleanSnapshot <> [entryWith "src/validation-kernel/Amoebius/Validation/Gate.hs" "name = \"phase-07\"\n"])
        []
      <> [ "a constructed identity must not be reported as a spelled ordinal, observed "
             <> show (observed constructedIdentitySnapshot)
         | observed constructedIdentitySnapshot /= []
         ]

  expectedQualification =
    [ ("clean", [])
    , ("retired-ignore-root", ["REPOSITORY-LAYOUT-RETIRED-IGNORE-ROOT"])
    , ("runtime-phase-ordinal", ["REPOSITORY-LAYOUT-PHASE-ORDINAL-IN-SOURCE"])
    , ("validation-phase-label", [])
    ]

  exactly label entries expected =
    [ label <> " must produce exactly " <> show expected <> ", observed " <> show (observed entries)
    | observed entries /= expected
    ]

  observed entries =
    map (Text.unpack . findingCode)
      ( checkFindings
          ( repositoryLayoutRunCheck
              (sourceClosureInternalTestAcquire (SourceSnapshot "/fixture" snapshotIdentityValue entries))
          )
      )

-- | An ignore contract naming only admitted contained roots, and Haskell whose
-- identities name capabilities.
cleanSnapshot :: [TrackedEntry]
cleanSnapshot =
  [ entryWith ".gitignore" ".build/\n.data/\n.test_data/\n"
  , entryWith ".dockerignore" ".build/\n.data/\n"
  , entryWith "src/Amoebius/Kernel.hs" "capability = \"documentation_suite\"\n"
  ]

-- | The near miss: an ordinal reached by construction rather than spelled into
-- a literal is not a drifting identity and must not be reported.
constructedIdentitySnapshot :: [TrackedEntry]
constructedIdentitySnapshot =
  cleanSnapshot
    <> [entryWith "src/Amoebius/Render.hs" "label ordinal = \"phase-\" <> render ordinal\n"]

entryWith :: FilePath -> String -> TrackedEntry
entryWith path contents =
  TrackedEntry
    { trackedIndex = IndexEntry path RegularFile objectIdentityValue
    , trackedBytes = ByteString8.pack contents
    }

snapshotIdentityValue, objectIdentityValue :: Text
snapshotIdentityValue = Text.replicate 64 "0"
objectIdentityValue = Text.replicate 64 "1"
