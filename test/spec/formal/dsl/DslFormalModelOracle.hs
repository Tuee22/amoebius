module DslFormalModelOracle
  ( ModelContract (..)
  , expectedCalculusFacts
  , expectedCapacityCaseCount
  , expectedCapacityDomain
  , expectedModelContracts
  , expectedMutationCatalogue
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

-- Separately authored Phase-18 expectations.  These values are deliberately
-- independent of both the production model constructors and rendered TLA/CFG.
data ModelContract = ModelContract
  { contractName :: String
  , contractStates :: Int
  , contractInvariants :: [String]
  , contractProperties :: [String]
  , contractActions :: [String]
  }
  deriving stock (Eq, Show)

expectedCapacityDomain :: String
expectedCapacityDomain = "0..2x4-demand/capacity"

expectedCapacityCaseCount :: Int
expectedCapacityCaseCount = 6561

expectedCalculusFacts :: Map String String
expectedCalculusFacts = Map.fromList
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-count", "5")
  , ("cpu", "15")
  , ("memory", "150")
  , ("ephemeral", "1500")
  , ("pods", "15")
  , ("formal-distinct-state-count", "1")
  , ("formal-safety", "green")
  ]

expectedModelContracts :: [ModelContract]
expectedModelContracts =
  [ ModelContract "DslProjection" 1 ["DslProjectionExact"] [] ["ObserveProjection"]
  , ModelContract "SnapshotToken" 3 ["NoTokenReuse"] ["IssuedTokenEventuallyConsumed"] ["Mint", "Consume"]
  , ModelContract "ReservationProtocol" 4 ["OneDebitPerReservation"] ["ReservationEventuallyBound"] ["Reserve", "PrepareBinding", "ConfirmBound"]
  , ModelContract "LeaseAuthority" 3 ["AtMostOneLeaseHolder"] ["EmptyEventuallyHeld"] ["Acquire", "Release"]
  , ModelContract "ReconcileProtocol" 6
      ["OneLeaseHolderActs", "RefuseOnUnreachable", "DeleteAfterBoundReady", "ConvergedIsStable"]
      ["PendingEventuallyConverged"]
      ["ObserveAbsent", "ObservePresent", "BindReplacement", "DeleteOld", "MarkAbsentConverged"]
  , ModelContract "CalculusComposition" 1
      ["CompositionProjectionExact", "CompositionIndicesNonNegative"] [] []
  ]

expectedMutationCatalogue :: [(String, String)]
expectedMutationCatalogue =
  [ ("projection-count-drift", "DslProjectionExact")
  , ("token-reuse", "NoTokenReuse")
  , ("reservation-double-debit", "OneDebitPerReservation")
  , ("lease-second-holder", "AtMostOneLeaseHolder")
  , ("reconcile-second-holder", "OneLeaseHolderActs")
  , ("reconcile-delete-unreachable", "RefuseOnUnreachable")
  , ("reconcile-delete-before-ready", "DeleteAfterBoundReady")
  , ("reconcile-post-convergence-write", "ConvergedIsStable")
  ]
