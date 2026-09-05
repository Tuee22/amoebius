{-# LANGUAGE OverloadedStrings #-}

module ExtensionLawsCompositionalOracle
  ( OracleCompositionCase (..)
  , OracleExpectedVerdict (..)
  , compositionCases
  , expectedVerdicts
  , mutantProperties
  , oracleContentAddress
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)
import Numeric.Natural (Natural)

data OracleCompositionCase = OracleCompositionCase
  { oracleCaseName :: Text
  , oracleCaseLeft :: Text
  , oracleCaseRight :: Text
  , oracleCaseThird :: Text
  , oracleCaseParts :: [Text]
  , oracleCaseResource :: (Natural, Natural, Natural, Natural)
  }
  deriving stock (Eq, Show)

data OracleExpectedVerdict = OracleExpectedVerdict
  { oracleExpectedSubject :: Text
  , oracleExpectedLaws :: [Text]
  }
  deriving stock (Eq, Show)

compositionCases :: [OracleCompositionCase]
compositionCases =
  [ OracleCompositionCase "empty-empty" "none" "none" "infernix" [] (0, 0, 0, 0)
  , OracleCompositionCase "left-identity" "none" "infernix" "jitml" ["infernix"] (4, 1792, 26, 3)
  , OracleCompositionCase "right-identity" "infernix" "none" "jitml" ["infernix"] (4, 1792, 26, 3)
  , OracleCompositionCase "left-identity-jitml" "none" "jitml" "infernix" ["jitml"] (7, 3584, 52, 3)
  , OracleCompositionCase "right-identity-jitml" "jitml" "none" "infernix" ["jitml"] (7, 3584, 52, 3)
  , OracleCompositionCase "infernix-jitml" "infernix" "jitml" "infernix" ["infernix", "jitml"] (11, 5376, 78, 6)
  , OracleCompositionCase "jitml-infernix" "jitml" "infernix" "jitml" ["infernix", "jitml"] (11, 5376, 78, 6)
  ]

expectedVerdicts :: [OracleExpectedVerdict]
expectedVerdicts =
  [ verdict "lawful-standard" [pass, pass, pass, pass, pass, pass, pass]
  , verdict "lawful-shared-content" [pass, pass, pass, pass, pass, pass, pass]
  , verdict "c1-claim-omitted" [failed "CompositeLawFailed", pass, pass, pass, pass, pass, pass]
  , verdict "c2-left-identity" [pass, failed "LeftIdentityMismatch", pass, pass, pass, pass, pass]
  , verdict "c3-regrouped" [pass, pass, failed "AssociativityMismatch", pass, pass, pass, pass]
  , verdict "c4-interference" [pass, pass, pass, failed "PartBehaviorChanged", pass, pass, pass]
  , verdict "c5-budget-max" [pass, pass, pass, pass, failed "BudgetWasNotAdditive", pass, pass]
  , verdict "c6-scope-widened" [failed "CompositeLawFailed", pass, pass, failed "PartBehaviorChanged", pass, failed "ScopeConjunctionViolation", pass]
  , verdict "c7-address-collision" [pass, pass, pass, pass, pass, pass, failed "AddressCollision"]
  ]
 where
  verdict = OracleExpectedVerdict
  pass = "PASS"
  failed locus = "FAIL:" <> locus

mutantProperties :: [(Text, Text, Text)]
mutantProperties =
  [ ("ignore-closure", "C1", "Closure")
  , ("ignore-identity", "C2", "Identity")
  , ("ignore-associativity", "C3", "Associativity")
  , ("ignore-non-interference", "C4", "NonInterference")
  , ("ignore-budget-additivity", "C5", "BudgetAdditivity")
  , ("ignore-scope-conjunction", "C6", "ScopeConjunction")
  , ("ignore-name-disjointness", "C7", "NameDisjointness")
  ]

oracleContentAddress :: ByteString -> Text
oracleContentAddress = Text.pack . concatMap hexByte . ByteString.unpack . SHA256.hash
 where
  hexByte byte = case showHex byte "" of
    [single] -> ['0', single]
    digits -> digits
