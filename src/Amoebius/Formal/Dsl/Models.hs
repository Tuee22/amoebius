module Amoebius.Formal.Dsl.Models
  ( dslModels
  , dslSafetyMutants
  , dslFairnessModels
  ) where

import Amoebius.Formal.Model

bool :: Bool -> Expr
bool = Literal . BoolValue

int :: Integer -> Expr
int = Literal . IntValue

atom :: String -> Expr
atom = Literal . AtomValue

named :: Name -> Expr -> NamedExpr
named = NamedExpr

action :: Name -> Expr -> [(Name, Expr)] -> Action
action name guard effects = Action name [] guard effects

exactProjection :: Expr
exactProjection = And
  [ Equal (Ref "decoderPositives") (int 5)
  , Equal (Ref "decoderNegatives") (int 4)
  , Equal (Ref "capacityCases") (int 6561)
  , Equal (Ref "renderObjects") (int 19)
  , Equal (Ref "chainSteps") (int 19)
  , Equal (Ref "calculusComponents") (int 5)
  ]

projectionModel :: Model
projectionModel = Model
  { modelName = "DslProjection"
  , modelConstants = []
  , modelVariables =
      [ "decoderPositives", "decoderNegatives", "capacityCases"
      , "renderObjects", "chainSteps", "calculusComponents"
      ]
  , modelInit =
      [ ("decoderPositives", int 5)
      , ("decoderNegatives", int 4)
      , ("capacityCases", int 6561)
      , ("renderObjects", int 19)
      , ("chainSteps", int 19)
      , ("calculusComponents", int 5)
      ]
  , modelActions = [action "ObserveProjection" (bool True) []]
  , modelInvariants = [named "DslProjectionExact" exactProjection]
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = []
  , modelProperties = []
  , modelCheckDeadlock = False
  }

tokenState :: String -> Expr
tokenState value = Equal (Ref "tokenState") (atom value)

tokenInvariant :: Expr
tokenInvariant = And
  [ ArithmeticComparison LessThanOrEqual (Ref "writes") (int 1)
  , Implies (tokenState "used") (Equal (Ref "writes") (int 1))
  , Implies (Not (tokenState "used")) (Equal (Ref "writes") (int 0))
  ]

tokenModel :: Model
tokenModel = Model
  { modelName = "SnapshotToken"
  , modelConstants = []
  , modelVariables = ["tokenState", "writes"]
  , modelInit = [("tokenState", atom "unissued"), ("writes", int 0)]
  , modelActions =
      [ action "Mint" (tokenState "unissued") [("tokenState", atom "ready")]
      , action "Consume" (tokenState "ready")
          [("tokenState", atom "used"), ("writes", Add (Ref "writes") (int 1))]
      ]
  , modelInvariants = [named "NoTokenReuse" tokenInvariant]
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = [Fairness WeakFair "Consume"]
  , modelProperties =
      [Property "IssuedTokenEventuallyConsumed" (LeadsTo (tokenState "ready") (tokenState "used"))]
  , modelCheckDeadlock = False
  }

reservationPhase :: String -> Expr
reservationPhase value = Equal (Ref "phase") (atom value)

reservationInvariant :: Expr
reservationInvariant = And
  [ ArithmeticComparison LessThanOrEqual (Ref "debit") (int 1)
  , Implies (reservationPhase "absent") (Equal (Ref "debit") (int 0))
  , Implies (Not (reservationPhase "absent")) (Equal (Ref "debit") (int 1))
  ]

reservationModel :: Model
reservationModel = Model
  { modelName = "ReservationProtocol"
  , modelConstants = []
  , modelVariables = ["phase", "debit"]
  , modelInit = [("phase", atom "absent"), ("debit", int 0)]
  , modelActions =
      [ action "Reserve" (reservationPhase "absent")
          [("phase", atom "reserved"), ("debit", int 1)]
      , action "PrepareBinding" (reservationPhase "reserved") [("phase", atom "binding")]
      , action "ConfirmBound" (reservationPhase "binding") [("phase", atom "bound")]
      ]
  , modelInvariants = [named "OneDebitPerReservation" reservationInvariant]
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = [Fairness WeakFair "PrepareBinding", Fairness WeakFair "ConfirmBound"]
  , modelProperties =
      [ Property "ReservationEventuallyBound"
          (LeadsTo (Or [reservationPhase "reserved", reservationPhase "binding"])
                   (reservationPhase "bound"))
      ]
  , modelCheckDeadlock = False
  }

holdersEmpty :: Expr
holdersEmpty = Equal (Cardinality (Ref "holders")) (int 0)

oneHolder :: Expr
oneHolder = Equal (Cardinality (Ref "holders")) (int 1)

leaseModel :: Model
leaseModel = Model
  { modelName = "LeaseAuthority"
  , modelConstants = [("Actors", SetValue [AtomValue "a", AtomValue "b"])]
  , modelVariables = ["holders"]
  , modelInit = [("holders", FiniteSet [])]
  , modelActions =
      [ Action "Acquire" [Parameter "actor" (Ref "Actors")] holdersEmpty
          [("holders", SetUnion (Ref "holders") (FiniteSet [Ref "actor"]))]
      , Action "Release" [Parameter "actor" (Ref "Actors")]
          (FiniteSetMembership (Ref "actor") (Ref "holders"))
          [("holders", SetDifference (Ref "holders") (FiniteSet [Ref "actor"]))]
      ]
  , modelInvariants =
      [named "AtMostOneLeaseHolder" (ArithmeticComparison LessThanOrEqual (Cardinality (Ref "holders")) (int 1))]
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = [Fairness WeakFair "Acquire"]
  , modelProperties = [Property "EmptyEventuallyHeld" (LeadsTo holdersEmpty oneHolder)]
  , modelCheckDeadlock = False
  }

observation :: String -> Expr
observation value = Equal (Ref "observation") (atom value)

replacement :: String -> Expr
replacement value = Equal (Ref "replacement") (atom value)

reconcileInvariants :: [NamedExpr]
reconcileInvariants =
  [ named "OneLeaseHolderActs" (Equal (Ref "holderCount") (int 1))
  , named "RefuseOnUnreachable" (Implies (observation "unreachable") (Not (Ref "oldDeleted")))
  , named "DeleteAfterBoundReady" (Implies (Ref "oldDeleted") (replacement "boundready"))
  , named "ConvergedIsStable" (Implies (Ref "converged") (Equal (Ref "revision") (int 0)))
  ]

reconcileActions :: [Action]
reconcileActions =
  [ action "ObserveAbsent" (observation "unreachable") [("observation", atom "absent")]
  , action "ObservePresent" (observation "unreachable") [("observation", atom "present")]
  , action "BindReplacement" (And [observation "present", replacement "unbound"])
      [("replacement", atom "boundready")]
  , action "DeleteOld" (And [observation "present", replacement "boundready", Not (Ref "oldDeleted")])
      [("oldDeleted", bool True), ("converged", bool True)]
  , action "MarkAbsentConverged" (And [observation "absent", Not (Ref "converged")])
      [("converged", bool True)]
  ]

reconcileModel :: Model
reconcileModel = Model
  { modelName = "ReconcileProtocol"
  , modelConstants = []
  , modelVariables =
      ["observation", "replacement", "oldDeleted", "holderCount", "revision", "converged"]
  , modelInit =
      [ ("observation", atom "unreachable")
      , ("replacement", atom "unbound")
      , ("oldDeleted", bool False)
      , ("holderCount", int 1)
      , ("revision", int 0)
      , ("converged", bool False)
      ]
  , modelActions = reconcileActions
  , modelInvariants = reconcileInvariants
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = [Fairness WeakFair name | name <- map actionName reconcileActions]
  , modelProperties =
      [Property "PendingEventuallyConverged" (LeadsTo (Not (Ref "converged")) (Ref "converged"))]
  , modelCheckDeadlock = False
  }

dslModels :: [Model]
dslModels = [projectionModel, tokenModel, reservationModel, leaseModel, reconcileModel]

dslFairnessModels :: [Model]
dslFairnessModels = [tokenModel, reservationModel, leaseModel, reconcileModel]

dslSafetyMutants :: [(String, Name, Model)]
dslSafetyMutants =
  [ ("projection-count-drift", "DslProjectionExact",
      projectionModel {modelInit = replaceInitial "capacityCases" (int 0) (modelInit projectionModel)})
  , ("token-reuse", "NoTokenReuse", mapAction "Consume" reuseToken tokenModel)
  , ("reservation-double-debit", "OneDebitPerReservation", mapAction "Reserve" doubleDebit reservationModel)
  , ("lease-second-holder", "AtMostOneLeaseHolder", mapAction "Acquire" (\value -> value {actionGuard = bool True}) leaseModel)
  , ("reconcile-second-holder", "OneLeaseHolderActs", addAction secondHolder reconcileModel)
  , ("reconcile-delete-unreachable", "RefuseOnUnreachable", addAction deleteUnreachable reconcileModel)
  , ("reconcile-delete-before-ready", "DeleteAfterBoundReady", addAction deleteBeforeReady reconcileModel)
  , ("reconcile-post-convergence-write", "ConvergedIsStable", addAction postConvergenceWrite reconcileModel)
  ]
 where
  reuseToken value = value
    { actionGuard = And
        [ NotEqual (Ref "tokenState") (atom "unissued")
        , ArithmeticComparison LessThan (Ref "writes") (int 2)
        ]
    }
  doubleDebit value = value
    { actionGuard = And
        [ Not (reservationPhase "bound")
        , ArithmeticComparison LessThan (Ref "debit") (int 2)
        ]
    , actionEffects = [("phase", atom "reserved"), ("debit", Add (Ref "debit") (int 1))]
    }
  secondHolder = action "MutantSecondHolder" (Equal (Ref "holderCount") (int 1)) [("holderCount", int 2)]
  deleteUnreachable = action "MutantDeleteUnreachable" (observation "unreachable")
    [("replacement", atom "boundready"), ("oldDeleted", bool True)]
  deleteBeforeReady = action "MutantDeleteBeforeReady" (And [observation "present", replacement "unbound"])
    [("oldDeleted", bool True)]
  postConvergenceWrite = action "MutantPostConvergenceWrite" (Ref "converged") [("revision", int 1)]

mapAction :: Name -> (Action -> Action) -> Model -> Model
mapAction target mutate model = model
  {modelActions = [if actionName value == target then mutate value else value | value <- modelActions model]}

addAction :: Action -> Model -> Model
addAction value model = model {modelActions = modelActions model <> [value]}

replaceInitial :: Name -> Expr -> [(Name, Expr)] -> [(Name, Expr)]
replaceInitial target replacementValue =
  map (\(name, value) -> if name == target then (name, replacementValue) else (name, value))
