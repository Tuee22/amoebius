module Amoebius.Formal.GatewayMigration
  ( gatewayMigrationModel
  , gatewayActionNames
  , maxDataLoss
  , minTtl
  , maxTtl
  , maxFreshness
  , maxOffset
  ) where

import Amoebius.Formal.Model

maxDataLoss, minTtl, maxTtl, maxFreshness, maxOffset :: Integer
maxDataLoss = 1
minTtl = 1
maxTtl = 60
maxFreshness = 1
maxOffset = 2

bool :: Bool -> Expr
bool = Literal . BoolValue

int :: Integer -> Expr
int = Literal . IntValue

atom :: String -> Expr
atom = Literal . AtomValue

is :: Name -> String -> Expr
is name value = Equal (Ref name) (atom value)

allOf :: [Expr] -> Expr
allOf = And

anyOf :: [Expr] -> Expr
anyOf = Or

assign :: Name -> Expr -> (Name, Expr)
assign = (,)

action :: Name -> Expr -> [(Name, Expr)] -> Action
action name guard effects = Action name [] guard effects

clientWrite :: Action
clientWrite = action "ClientWrite"
  (allOf
    [ is "phase" "Choose"
    , Ref "sourceUp"
    , Ref "sourceOwns"
    , Not (Ref "quiesced")
    , ArithmeticComparison LessThan (Ref "committed") (Ref "MaxOffset")
    ])
  [ assign "committed" (Add (Ref "committed") (int 1))
  , assign "sourceLog" (Add (Ref "sourceLog") (int 1))
  ]

replicationTick :: Action
replicationTick = action "ReplicationTick"
  (allOf
    [ is "phase" "Choose"
    , Ref "targetUp"
    , ArithmeticComparison LessThan (Ref "targetLog") (Ref "sourceLog")
    ])
  [assign "targetLog" (Add (Ref "targetLog") (int 1))]

activeCrash :: Action
activeCrash = action "ActiveCrash"
  (allOf
    [ is "phase" "Choose"
    , Ref "sourceOwns"
    , Ref "sourceUp"
    , ArithmeticComparison GreaterThan (Ref "committed") (int 0)
    ])
  [ assign "branch" (atom "failover")
  , assign "phase" (atom "FColdSeed")
  , assign "sourceOwns" (bool False)
  , assign "sourceUp" (bool False)
  ]

coldSeed :: Action
coldSeed = action "ColdSeed"
  (allOf [is "branch" "failover", is "phase" "FColdSeed", Ref "targetUp"])
  [ assign "targetLog" (Ref "sourceLog")
  , assign "coldSeeded" (bool True)
  , assign "freshnessWitness" (bool True)
  , assign "phase" (atom "FPromote")
  ]

startPlanned :: Action
startPlanned = action "StartPlanned"
  (allOf
    [ is "phase" "Choose"
    , ArithmeticComparison GreaterThan (Ref "committed") (int 0)
    , Equal (Ref "targetLog") (Ref "committed")
    , FiniteQuantifier ForAll "cluster" (Ref "Clusters")
        (anyOf [NotEqual (Ref "cluster") (atom "target"), Ref "targetUp"])
    ])
  [assign "branch" (atom "planned"), assign "phase" (atom "PReplica")]

standUpReplica :: Action
standUpReplica = action "StandUpReplica"
  (allOf [is "branch" "planned", is "phase" "PReplica", Ref "targetUp"])
  [assign "phase" (atom "PQuiesce")]

quiesce :: Action
quiesce = action "Quiesce"
  (allOf [is "branch" "planned", is "phase" "PQuiesce"])
  [assign "quiesced" (bool True), assign "phase" (atom "PVerify")]

standbyCrash :: Action
standbyCrash = action "StandbyCrash"
  (allOf
    [ is "branch" "planned"
    , anyOf [is "phase" "PVerify", is "phase" "PPromote"]
    , Ref "targetUp"
    ])
  [assign "targetUp" (bool False)]

verifyCaughtUp :: Action
verifyCaughtUp = action "VerifyCaughtUp"
  (allOf
    [ is "branch" "planned"
    , is "phase" "PVerify"
    , Ref "targetUp"
    , Equal (Ref "targetLog") (Ref "committed")
    ])
  [ assign "caughtUp" (bool True)
  , assign "freshnessWitness" (bool True)
  , assign "phase" (atom "PPromote")
  ]

promotePlanned :: Action
promotePlanned = action "PromotePlanned"
  (allOf
    [ is "branch" "planned"
    , is "phase" "PPromote"
    , Ref "caughtUp"
    , Ref "freshnessWitness"
    , FiniteQuantifier ForAll "cluster" (Ref "Clusters")
        (anyOf [NotEqual (Ref "cluster") (atom "target"), Ref "targetUp"])
    ])
  [ assign "sourceOwns" (bool False)
  , assign "targetOwns" (bool True)
  , assign "divergence" (int 0)
  , assign "phase" (atom "PRepoint")
  ]

repointPlannedDns :: Action
repointPlannedDns = action "RepointPlannedDns"
  (allOf [is "branch" "planned", is "phase" "PRepoint", Ref "targetOwns"])
  [assign "dns" (atom "target"), assign "phase" (atom "PUnfreeze")]

unfreeze :: Action
unfreeze = action "Unfreeze"
  (allOf [is "branch" "planned", is "phase" "PUnfreeze"])
  [assign "quiesced" (bool False), assign "phase" (atom "PDrain")]

drainMonitor :: Action
drainMonitor = action "DrainMonitor"
  (allOf [is "branch" "planned", is "phase" "PDrain", Ref "targetUp"])
  [assign "drainComplete" (bool True), assign "phase" (atom "PDecommission")]

decommissionSource :: Action
decommissionSource = action "DecommissionSource"
  (allOf [is "branch" "planned", is "phase" "PDecommission", Ref "drainComplete"])
  [assign "sourceUp" (bool False), assign "phase" (atom "Done")]

standDown :: Action
standDown = action "StandDown"
  (allOf
    [ is "branch" "planned"
    , anyOf [is "phase" "PVerify", is "phase" "PPromote"]
    ])
  [ assign "branch" (atom "none")
  , assign "phase" (atom "StandDown")
  , assign "quiesced" (bool False)
  ]

promoteSurvivor :: Action
promoteSurvivor = action "PromoteSurvivor"
  (allOf
    [ is "branch" "failover"
    , is "phase" "FPromote"
    , Ref "targetUp"
    , Ref "freshnessWitness"
    ])
  [ assign "targetOwns" (bool True)
  , assign "divergence" (Subtract (Ref "committed") (Ref "targetLog"))
  , assign "phase" (atom "FRepoint")
  ]

repointFailoverDns :: Action
repointFailoverDns = action "RepointFailoverDns"
  (allOf [is "branch" "failover", is "phase" "FRepoint", Ref "targetOwns"])
  [assign "dns" (atom "target"), assign "phase" (atom "FRebind")]

boundedRebind :: Action
boundedRebind = action "BoundedRebind"
  (allOf [is "branch" "failover", is "phase" "FRebind", is "dns" "target"])
  [ assign "rebound" (bool True)
  , assign "rebindable" (bool True)
  , assign "phase" (atom "FHeal")
  ]

heal :: Action
heal = action "Heal"
  (allOf [is "branch" "failover", is "phase" "FHeal", Ref "rebound"])
  [assign "sourceUp" (bool True), assign "healed" (bool True), assign "phase" (atom "FMerge")]

mergeConverge :: Action
mergeConverge = action "MergeConverge"
  (allOf [is "branch" "failover", is "phase" "FMerge", Ref "healed"])
  [ assign "sourceOwns" (bool False)
  , assign "targetOwns" (bool True)
  , assign "divergence" (int 0)
  , assign "phase" (atom "Done")
  ]

gatewayActions :: [Action]
gatewayActions =
  [ clientWrite, replicationTick, activeCrash, coldSeed
  , startPlanned, standUpReplica, quiesce, standbyCrash, verifyCaughtUp, promotePlanned
  , repointPlannedDns, unfreeze, drainMonitor, decommissionSource, standDown
  , promoteSurvivor, repointFailoverDns, boundedRebind, heal, mergeConverge
  ]

gatewayActionNames :: [Name]
gatewayActionNames = map actionName gatewayActions

ownerCount :: Expr
ownerCount = Add
  (IfThenElse (Ref "sourceOwns") (int 1) (int 0))
  (IfThenElse (Ref "targetOwns") (int 1) (int 0))

uniqueGatewayOwner :: Expr
uniqueGatewayOwner = ArithmeticComparison LessThanOrEqual ownerCount (int 1)

sessionAlwaysRebindable :: Expr
sessionAlwaysRebindable = Implies (Ref "liveSession") (anyOf [Ref "sourceUp", Ref "targetUp"])

plannedIsLossless :: Expr
plannedIsLossless = Implies
  (allOf [is "branch" "planned", Ref "targetOwns"])
  (ArithmeticComparison GreaterThanOrEqual (Ref "targetLog") (Ref "committed"))

noWriteAfterStaleFailover :: Expr
noWriteAfterStaleFailover = Implies
  (allOf [is "branch" "failover", Ref "targetOwns"])
  (ArithmeticComparison LessThanOrEqual (Ref "divergence") (Ref "MaxDataLoss"))

noTakeWithoutProvenFreshness :: Expr
noTakeWithoutProvenFreshness = Implies
  (Ref "targetOwns")
  (allOf [Ref "freshnessWitness", Ref "targetUp"])

phaseValues :: [String]
phaseValues =
  [ "Choose", "PReplica", "PQuiesce", "PVerify", "PPromote", "PRepoint"
  , "PUnfreeze", "PDrain", "PDecommission", "FColdSeed", "FPromote"
  , "FRepoint", "FRebind", "FHeal", "FMerge", "Done", "StandDown"
  ]

stateBound :: Expr
stateBound = And
  [ FiniteSetMembership (Ref "branch") (FiniteSet (map atom ["none", "planned", "failover"]))
  , FiniteSetMembership (Ref "phase") (FiniteSet (map atom phaseValues))
  , FiniteSetMembership (Ref "dns") (FiniteSet (map atom ["source", "target"]))
  , FiniteSetMembership (Ref "committed") offsets
  , FiniteSetMembership (Ref "sourceLog") offsets
  , FiniteSetMembership (Ref "targetLog") offsets
  , FiniteSetMembership (Ref "divergence") offsets
  , FiniteQuantifier ForAll "flag" (FiniteSet (map Ref booleanVariables))
      (FiniteSetMembership (Ref "flag") (FiniteSet [bool False, bool True]))
  ]
  where
    offsets = FiniteSet [int value | value <- [0 .. maxOffset]]

booleanVariables :: [Name]
booleanVariables =
  [ "sourceOwns", "targetOwns", "sourceUp", "targetUp", "liveSession", "rebindable"
  , "quiesced", "caughtUp", "freshnessWitness", "coldSeeded", "rebound"
  , "drainComplete", "healed"
  ]

terminalPlanned :: Expr
terminalPlanned = anyOf [is "phase" "Done", is "phase" "StandDown", is "branch" "none"]

gatewayMigrationModel :: Model
gatewayMigrationModel = Model
  { modelName = "GatewayMigration"
  , modelConstants =
      [ ("Clusters", SetValue [AtomValue "source", AtomValue "target"])
      , ("MaxOffset", IntValue maxOffset)
      , ("MaxDataLoss", IntValue maxDataLoss)
      , ("MinTTL", IntValue minTtl)
      , ("MaxTTL", IntValue maxTtl)
      , ("MaxFreshness", IntValue maxFreshness)
      ]
  , modelVariables =
      [ "branch", "phase", "sourceOwns", "targetOwns", "sourceUp", "targetUp"
      , "dns", "committed", "sourceLog", "targetLog", "liveSession", "rebindable"
      , "quiesced", "caughtUp", "freshnessWitness", "coldSeeded", "rebound"
      , "drainComplete", "healed", "divergence"
      ]
  , modelInit =
      [ assign "branch" (atom "none"), assign "phase" (atom "Choose")
      , assign "sourceOwns" (bool True), assign "targetOwns" (bool False)
      , assign "sourceUp" (bool True), assign "targetUp" (bool True)
      , assign "dns" (atom "source"), assign "committed" (int 0)
      , assign "sourceLog" (int 0), assign "targetLog" (int 0)
      , assign "liveSession" (bool True), assign "rebindable" (bool True)
      , assign "quiesced" (bool False), assign "caughtUp" (bool False)
      , assign "freshnessWitness" (bool False), assign "coldSeeded" (bool False)
      , assign "rebound" (bool False), assign "drainComplete" (bool False)
      , assign "healed" (bool False), assign "divergence" (int 0)
      ]
  , modelActions = gatewayActions
  , modelInvariants =
      [ NamedExpr "UniqueGatewayOwner" uniqueGatewayOwner
      , NamedExpr "SessionAlwaysRebindable" sessionAlwaysRebindable
      , NamedExpr "PlannedIsLossless" plannedIsLossless
      , NamedExpr "NoWriteAfterStaleFailover" noWriteAfterStaleFailover
      , NamedExpr "NoTakeWithoutProvenFreshness" noTakeWithoutProvenFreshness
      ]
  , modelConstraint = Just (NamedExpr "StateBound" stateBound)
  , modelExpansionLimit = Nothing
  , modelFairness = [Fairness WeakFair name | name <- gatewayActionNames]
  , modelProperties =
      [ Property "MergeConverges" (LeadsTo (is "branch" "failover") (Equal ownerCount (int 1)))
      , Property "SessionEventuallyRebinds" (LeadsTo (is "branch" "failover") (Ref "rebound"))
      , Property "PlannedMigrationTerminates" (LeadsTo (is "branch" "planned") terminalPlanned)
      ]
  , modelCheckDeadlock = False
  }
