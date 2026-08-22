{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , checkPassed
  , finding
  , mergeChecks
  , observation
  , renderFinding
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

data Finding = Finding
  { findingCode :: Text
  , findingSubject :: FilePath
  , findingDetail :: Text
  }
  deriving (Eq, Ord, Show)

data Observation = Observation
  { observationKey :: Text
  , observationValue :: Text
  }
  deriving (Eq, Ord, Show)

data CheckResult = CheckResult
  { checkName :: Text
  , checkObservations :: [Observation]
  , checkFindings :: [Finding]
  }
  deriving (Eq, Show)

checkPassed :: CheckResult -> Bool
checkPassed = null . checkFindings

finding :: Text -> FilePath -> Text -> Finding
finding = Finding

observation :: Text -> Text -> Observation
observation = Observation

mergeChecks :: Text -> [CheckResult] -> CheckResult
mergeChecks name checks =
  CheckResult
    { checkName = name
    , checkObservations = concatMap checkObservations checks
    , checkFindings = concatMap checkFindings checks
    }

renderFinding :: Finding -> Text
renderFinding item =
  findingCode item
    <> "\t"
    <> Text.pack (findingSubject item)
    <> "\t"
    <> findingDetail item
