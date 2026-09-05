{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Mechanical observations and predicates for the seven compositional laws.
--
-- A 'CompositeDeclaration' is a separate value from Phase 20's exactly-five-component
-- 'ExtensionDeclaration'.  It retains the declarations at one request-scope index,
-- normalizes their order, unions their L-law vocabularies, and folds their real resource
-- vectors.  The finite gate supplies behavior and address observations; this module does
-- not mint a conformance verdict.
module Amoebius.Extension.Laws.Compositional
  ( CompositionLaw (..)
  , everyCompositionLaw
  , compositionLawTag
  , CompositeDeclaration
  , emptyComposite
  , singletonComposite
  , composeComposites
  , compositePartNames
  , compositePartDigests
  , compositeResource
  , compositeVocabulary
  , ArtifactAddressObservation (..)
  , PartObservation (..)
  , CompositionObservations (..)
  , CompositionFailure (..)
  , CompositionVerdict (..)
  , evaluateCompositionLaws
  , compositionLawPassed
  , contentAddress
  ) where

import Amoebius.Capacity.Types
  ( ResourceVector
  , addResources
  , zeroResources
  )
import Amoebius.Extension.Declaration
  ( ExtensionDeclaration
  , declarationDigest
  , declarationResource
  , extensionName
  )
import Amoebius.Extension.Laws.PerExtension
  ( FlowObservation (..)
  , Law
  , LawObservations (..)
  , LawVocabulary
  , declarationVocabulary
  , emptyVocabulary
  , evaluateLaws
  , evaluateVocabularyLaws
  , lawPassed
  , restrictObservations
  , unionVocabulary
  , vocabularyArtifactNames
  )
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (sort, sortOn)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)

data CompositionLaw = C1 | C2 | C3 | C4 | C5 | C6 | C7
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyCompositionLaw :: [CompositionLaw]
everyCompositionLaw = [minBound .. maxBound]

compositionLawTag :: CompositionLaw -> Text
compositionLawTag law = case law of
  C1 -> "C1"
  C2 -> "C2"
  C3 -> "C3"
  C4 -> "C4"
  C5 -> "C5"
  C6 -> "C6"
  C7 -> "C7"

-- | A normalized multiset of complete declarations at one request-scope index.  The
-- constructor remains private, preserving the Phase-20 introduction rule for every
-- member.  Repeated declarations are retained because budget additivity is over linked
-- inputs, not a name-keyed overwrite.
newtype CompositeDeclaration scope = CompositeDeclaration [ExtensionDeclaration scope]

instance Eq (CompositeDeclaration scope) where
  left == right = compositeKeys left == compositeKeys right

instance Show (CompositeDeclaration scope) where
  show = show . compositeKeys

emptyComposite :: CompositeDeclaration scope
emptyComposite = CompositeDeclaration []

singletonComposite :: ExtensionDeclaration scope -> CompositeDeclaration scope
singletonComposite declaration = CompositeDeclaration [declaration]

composeComposites
  :: CompositeDeclaration scope
  -> CompositeDeclaration scope
  -> CompositeDeclaration scope
composeComposites (CompositeDeclaration left) (CompositeDeclaration right) =
  CompositeDeclaration (sortOn declarationKey (left <> right))

compositePartNames :: CompositeDeclaration scope -> [Text]
compositePartNames (CompositeDeclaration declarations) = fmap extensionName declarations

compositePartDigests :: CompositeDeclaration scope -> [Text]
compositePartDigests (CompositeDeclaration declarations) = fmap declarationDigest declarations

compositeResource :: CompositeDeclaration scope -> ResourceVector
compositeResource (CompositeDeclaration declarations) =
  foldl' addResources zeroResources (fmap declarationResource declarations)

compositeVocabulary :: CompositeDeclaration scope -> LawVocabulary
compositeVocabulary (CompositeDeclaration declarations) =
  foldl' unionVocabulary emptyVocabulary (fmap declarationVocabulary declarations)

compositeKeys :: CompositeDeclaration scope -> [(Text, Text)]
compositeKeys (CompositeDeclaration declarations) = fmap declarationKey declarations

declarationKey :: ExtensionDeclaration scope -> (Text, Text)
declarationKey declaration = (extensionName declaration, declarationDigest declaration)

data ArtifactAddressObservation = ArtifactAddressObservation
  { addressedArtifact :: Text
  , observedAddress :: Text
  , addressedBytes :: ByteString
  }
  deriving stock (Eq, Ord, Show)

data PartObservation = PartObservation
  { observedPartDigest :: Text
  , isolatedObservations :: LawObservations
  }
  deriving stock (Eq, Show)

-- | Values produced by executing the operator and the parts.  Algebraic results are
-- explicit so a mutant can replace one execution without replacing the expectation.
data CompositionObservations scope = CompositionObservations
  { compositeLawObservations :: LawObservations
  , partObservations :: [PartObservation]
  , observedLeftIdentity :: CompositeDeclaration scope
  , observedRightIdentity :: CompositeDeclaration scope
  , observedAssociationLeft :: CompositeDeclaration scope
  , observedAssociationRight :: CompositeDeclaration scope
  , observedCompositeResource :: ResourceVector
  , observedArtifactAddresses :: [ArtifactAddressObservation]
  }
  deriving stock (Show)

data CompositionFailure
  = OperandObservationCoverageMismatch [Text] [Text]
  | OperandLawFailed Text Law
  | CompositeLawFailed Law
  | LeftIdentityMismatch
  | RightIdentityMismatch
  | AssociativityMismatch
  | PartBehaviorChanged Text
  | BudgetWasNotAdditive ResourceVector ResourceVector
  | ScopeConjunctionViolation Text
  | AddressCoverageMismatch [Text] [Text]
  | AddressCollision Text Text Text
  | AddressNotContentDerived Text Text Text
  deriving stock (Eq, Ord, Show)

data CompositionVerdict
  = CompositionLawPassed
  | CompositionLawFailed [CompositionFailure]
  deriving stock (Eq, Ord, Show)

evaluateCompositionLaws
  :: CompositeDeclaration scope
  -> CompositeDeclaration scope
  -> CompositeDeclaration scope
  -> CompositionObservations scope
  -> [(CompositionLaw, CompositionVerdict)]
evaluateCompositionLaws left right _third observations =
  [ (C1, verdict c1Failures)
  , (C2, verdict c2Failures)
  , (C3, verdict c3Failures)
  , (C4, verdict c4Failures)
  , (C5, verdict c5Failures)
  , (C6, verdict c6Failures)
  , (C7, verdict c7Failures)
  ]
 where
  pair = composeComposites left right
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_CLOSURE_MUTANT
  c1Failures = []
#else
  c1Failures = closureFailures pair observations
#endif
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_IDENTITY_MUTANT
  c2Failures = []
#else
  c2Failures = identityFailures pair observations
#endif
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_ASSOCIATIVITY_MUTANT
  c3Failures = []
#else
  c3Failures = associativityFailures observations
#endif
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_NON_INTERFERENCE_MUTANT
  c4Failures = []
#else
  c4Failures = nonInterferenceFailures pair observations
#endif
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_BUDGET_ADDITIVITY_MUTANT
  c5Failures = []
#else
  c5Failures = budgetFailures left right observations
#endif
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_SCOPE_CONJUNCTION_MUTANT
  c6Failures = []
#else
  c6Failures = scopeFailures observations
#endif
#ifdef EXTENSION_LAWS_COMPOSITIONAL_IGNORE_NAME_DISJOINTNESS_MUTANT
  c7Failures = []
#else
  c7Failures = addressFailures pair observations
#endif

compositionLawPassed :: CompositionVerdict -> Bool
compositionLawPassed lawVerdict = case lawVerdict of
  CompositionLawPassed -> True
  CompositionLawFailed _ -> False

verdict :: [CompositionFailure] -> CompositionVerdict
verdict failures = case failures of
  [] -> CompositionLawPassed
  _ -> CompositionLawFailed failures

closureFailures
  :: CompositeDeclaration scope
  -> CompositionObservations scope
  -> [CompositionFailure]
closureFailures composite observations =
  operandCoverage <> operandFailures <> compositeFailures
 where
  declarations = case composite of CompositeDeclaration values -> values
  expected = sort (fmap declarationDigest declarations)
  observed = sort (fmap observedPartDigest (partObservations observations))
  operandCoverage =
    [OperandObservationCoverageMismatch expected observed | expected /= observed]
  indexed = Map.fromListWith (<>)
    [ (observedPartDigest row, [isolatedObservations row])
    | row <- partObservations observations
    ]
  operandFailures =
    [ OperandLawFailed (declarationDigest declaration) law
    | declaration <- declarations
    , [part] <- [Map.findWithDefault [] (declarationDigest declaration) indexed]
    , (law, result) <- evaluateLaws declaration part
    , not (lawPassed result)
    ]
  compositeFailures =
    [ CompositeLawFailed law
    | (law, result) <- evaluateVocabularyLaws (compositeVocabulary composite) (compositeLawObservations observations)
    , not (lawPassed result)
    ]

identityFailures
  :: CompositeDeclaration scope
  -> CompositionObservations scope
  -> [CompositionFailure]
identityFailures composite observations =
  [LeftIdentityMismatch | observedLeftIdentity observations /= composite]
    <> [RightIdentityMismatch | observedRightIdentity observations /= composite]

associativityFailures :: CompositionObservations scope -> [CompositionFailure]
associativityFailures observations =
  [AssociativityMismatch | observedAssociationLeft observations /= observedAssociationRight observations]

nonInterferenceFailures
  :: CompositeDeclaration scope
  -> CompositionObservations scope
  -> [CompositionFailure]
nonInterferenceFailures composite observations = coverage <> changed
 where
  declarations = case composite of CompositeDeclaration values -> values
  expected = sort (fmap declarationDigest declarations)
  observed = sort (fmap observedPartDigest (partObservations observations))
  coverage = [OperandObservationCoverageMismatch expected observed | expected /= observed]
  indexed = Map.fromListWith (<>)
    [ (observedPartDigest row, [isolatedObservations row])
    | row <- partObservations observations
    ]
  changed =
    [ PartBehaviorChanged (declarationDigest declaration)
    | declaration <- declarations
    , [isolated] <- [Map.findWithDefault [] (declarationDigest declaration) indexed]
    , not
        ( behaviorEquivalent
            (restrictObservations (declarationVocabulary declaration) (compositeLawObservations observations))
            isolated
        )
    ]

behaviorEquivalent :: LawObservations -> LawObservations -> Bool
behaviorEquivalent left right =
  observedOperations left == observedOperations right
    && observedArtifacts left == observedArtifacts right
    && observedBudgets left == observedBudgets right
    && observedFlows left == observedFlows right

budgetFailures
  :: CompositeDeclaration scope
  -> CompositeDeclaration scope
  -> CompositionObservations scope
  -> [CompositionFailure]
budgetFailures left right observations =
  [ BudgetWasNotAdditive expected actual
  | actual /= expected
  ]
 where
  expected = addResources (compositeResource left) (compositeResource right)
  actual = observedCompositeResource observations

scopeFailures :: CompositionObservations scope -> [CompositionFailure]
scopeFailures observations =
  [ ScopeConjunctionViolation (flowOperation flow)
  | flow <- observedFlows (compositeLawObservations observations)
  , flowSink flow > flowSource flow
  ]

addressFailures
  :: CompositeDeclaration scope
  -> CompositionObservations scope
  -> [CompositionFailure]
addressFailures composite observations = coverage <> collisions <> nonDerived
 where
  rows = observedArtifactAddresses observations
  expected = vocabularyArtifactNames (compositeVocabulary composite)
  observed = Set.toAscList (Set.fromList (fmap addressedArtifact rows))
  coverage = [AddressCoverageMismatch expected observed | expected /= observed]
  collisions =
    [ AddressCollision (observedAddress left) (addressedArtifact left) (addressedArtifact right)
    | (position, left) <- zip [0 :: Int ..] rows
    , right <- drop (position + 1) rows
    , observedAddress left == observedAddress right
    , addressedBytes left /= addressedBytes right
    ]
  nonDerived =
    [ AddressNotContentDerived (addressedArtifact row) (contentAddress (addressedBytes row)) (observedAddress row)
    | row <- rows
    , observedAddress row /= contentAddress (addressedBytes row)
    ]

contentAddress :: ByteString -> Text
contentAddress bytes = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
