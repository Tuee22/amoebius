{-# LANGUAGE OverloadedStrings #-}

module CompositionFixtures
  ( FixtureSet (..)
  , fixtureSet
  , emptyLawObservations
  , infernixLawObservations
  , jitmlLawObservations
  , mergeLawObservations
  , shareArtifactContent
  , addressObservations
  ) where

import Amoebius.Extension.Declaration
  ( DeclarationError
  , ExtensionDeclaration
  )
import Amoebius.Extension.Laws.Compositional
  ( ArtifactAddressObservation (ArtifactAddressObservation)
  , contentAddress
  )
import Amoebius.Extension.Laws.PerExtension
  ( ArtifactObservation (ArtifactObservation)
  , BudgetObservation (BudgetObservation)
  , ClaimObservation (ClaimObservation)
  , ExhaustionObservation (RefusedBeforeMaterialization)
  , FixtureObservation (FixturePassedAtPinnedReason)
  , FlowObservation (FlowObservation)
  , FlowScope (RequestFlow)
  , LawObservations (..)
  , OperationObservation (OperationObservation)
  , OperationOutcome (OperationReturned)
  , RetentionObservation (RetainedWithReaper)
  )
import Amoebius.Scope.Index (RequestScope)
import Data.ByteString (ByteString)
import Data.Text (Text)

import LawFixtures
  ( infernixDeclaration
  , jitmlDeclaration
  )

data FixtureSet scope = FixtureSet
  { infernixExtension :: ExtensionDeclaration scope
  , jitmlExtension :: ExtensionDeclaration scope
  }

fixtureSet :: RequestScope scope -> Either DeclarationError (FixtureSet scope)
fixtureSet scope = FixtureSet <$> infernixDeclaration scope <*> jitmlDeclaration scope

emptyLawObservations :: LawObservations
emptyLawObservations = LawObservations [] [] [] [] []

infernixLawObservations :: LawObservations
infernixLawObservations =
  LawObservations
    [OperationObservation "inference-workflow" "compose" (OperationReturned "infernix:compose")]
    [artifact "infernix-image" "infernix:artifact:compose"]
    [ BudgetObservation
        "infernix-image"
        "inference-budget"
        RefusedBeforeMaterialization
        (RetainedWithReaper "infernix-reaper")
    ]
    [FlowObservation "inference-workflow" RequestFlow RequestFlow]
    [ ClaimObservation
        "inference-evidence"
        (FixturePassedAtPinnedReason "test/oracle/extension_laws/law_verdicts.tsv")
    ]

jitmlLawObservations :: LawObservations
jitmlLawObservations =
  LawObservations
    [OperationObservation "training-workflow" "compose" (OperationReturned "jitml:compose")]
    [artifact "jitml-model" "jitml:artifact:compose"]
    [ BudgetObservation
        "jitml-model"
        "training-budget"
        RefusedBeforeMaterialization
        (RetainedWithReaper "jitml-reaper")
    ]
    [FlowObservation "training-workflow" RequestFlow RequestFlow]
    [ ClaimObservation
        "training-evidence"
        (FixturePassedAtPinnedReason "test/oracle/extension_laws/law_verdicts.tsv")
    ]

artifact :: Text -> ByteString -> ArtifactObservation
artifact name bytes = ArtifactObservation name bytes bytes

mergeLawObservations :: LawObservations -> LawObservations -> LawObservations
mergeLawObservations left right =
  LawObservations
    (observedOperations left <> observedOperations right)
    (observedArtifacts left <> observedArtifacts right)
    (observedBudgets left <> observedBudgets right)
    (observedFlows left <> observedFlows right)
    (observedClaims left <> observedClaims right)

shareArtifactContent :: LawObservations -> LawObservations
shareArtifactContent observations = observations
  { observedArtifacts =
      [ ArtifactObservation name sharedBytes sharedBytes
      | ArtifactObservation name _first _second <- observedArtifacts observations
      ]
  }
 where
  sharedBytes = "shared-composite-content"

addressObservations :: LawObservations -> [ArtifactAddressObservation]
addressObservations observations =
  [ ArtifactAddressObservation name (contentAddress bytes) bytes
  | ArtifactObservation name bytes _second <- observedArtifacts observations
  ]
