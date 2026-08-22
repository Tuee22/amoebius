{-# LANGUAGE OverloadedStrings #-}

module ConformanceGateMutants
  ( omitLawFromSuite
  , ignoreObservedSuite
  , admitWithoutVerdict
  ) where

import Amoebius.Extension.Conformance.Gate
  ( ConformanceVerdict
  , GatePlan
  , GateRunError
  , GeneratedFile (..)
  , ObservedCase
  , generatedFiles
  , runGeneratedGate
  )
import Amoebius.Extension.Declaration
  ( ExtensionDeclaration
  , declarationDigest
  )
import Data.ByteString.Char8 qualified as ByteString
import Data.List (isInfixOf)
import Data.Text (Text)

omitLawFromSuite :: String -> [GeneratedFile] -> [GeneratedFile]
omitLawFromSuite law = fmap mutate
 where
  mutate file
    | generatedPath file == "property-suite.tsv" =
        file {generatedBytes = ByteString.unlines (filter (not . containsLaw) (ByteString.lines (generatedBytes file)))}
    | otherwise = file
  containsLaw line = ("\t" <> law <> "\t") `isInfixOf` ByteString.unpack line

-- Seeded defect: pretend the canonical bytes ran, ignoring the observed suite bytes.
ignoreObservedSuite
  :: GatePlan scope
  -> [GeneratedFile]
  -> [ObservedCase]
  -> Either GateRunError (ConformanceVerdict scope)
ignoreObservedSuite plan _observedFiles = runGeneratedGate plan (generatedFiles plan)

-- Seeded defect: an ordinary digest is appended without a verdict-bearing API.
admitWithoutVerdict :: ExtensionDeclaration scope -> [Text] -> [Text]
admitWithoutVerdict declaration members = declarationDigest declaration : members
