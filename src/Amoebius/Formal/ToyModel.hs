{-# LANGUAGE CPP #-}

module Amoebius.Formal.ToyModel
  ( toyModel
  , toyProcesses
  ) where

import Amoebius.Formal.Model

toyProcesses :: Expr
toyProcesses = Ref "Proc"

atom :: String -> Expr
atom = Literal . AtomValue

integer :: Integer -> Expr
integer = Literal . IntValue

pcAt :: Expr -> Expr
pcAt = FunctionApplication (Ref "pc")

mirrorAt :: Expr -> Expr
mirrorAt = FunctionApplication (Ref "mirror")

statusSet :: Expr
statusSet = FiniteSet (map atom ["idle", "want", "critical"])

anyCritical :: Expr
anyCritical = FiniteQuantifier Exists "p" toyProcesses (Equal (pcAt (Ref "p")) (atom "critical"))

noCritical :: Expr
noCritical = FiniteQuantifier ForAll "p" toyProcesses (NotEqual (pcAt (Ref "p")) (atom "critical"))

mutualExclusion :: Expr
mutualExclusion = And
#ifdef FORMAL_MODEL_WEAKENS_INVARIANT_MUTANT
  [ Equal (Ref "pc") (Ref "mirror")
#else
  [ FiniteQuantifier ForAll "p" toyProcesses
      (FiniteQuantifier ForAll "q" toyProcesses
        (Or
          [ Equal (Ref "p") (Ref "q")
          , Or
              [ NotEqual (pcAt (Ref "p")) (atom "critical")
              , NotEqual (pcAt (Ref "q")) (atom "critical")
              ]
          ]))
  , Equal (Ref "pc") (Ref "mirror")
#endif
  , ArithmeticComparison LessThanOrEqual (integer 0) (Ref "criticalCount")
  , ArithmeticComparison LessThanOrEqual (Ref "criticalCount") (integer 1)
  , Or
      [ And [Equal (Ref "criticalCount") (integer 0), noCritical]
      , And [Equal (Ref "criticalCount") (integer 1), anyCritical]
      ]
  ]

stateBound :: Expr
stateBound = And
  [ Literal (BoolValue True)
  , FiniteQuantifier ForAll "p" toyProcesses (FiniteSetMembership (pcAt (Ref "p")) statusSet)
  , FiniteQuantifier ForAll "p" toyProcesses (FiniteSetMembership (mirrorAt (Ref "p")) statusSet)
  ]

processParameter :: Parameter
processParameter = Parameter "p" toyProcesses

updateAt :: Name -> Expr -> Expr -> Expr
updateAt name key value = FunctionUpdate (Ref name) key value

requestAction :: Action
requestAction = Action
  { actionName = "Request"
  , actionParameters = [processParameter]
  , actionGuard = Equal (pcAt (Ref "p")) (atom "idle")
  , actionEffects =
      [ ("pc", updateAt "pc" (Ref "p") (atom "want"))
      , ("mirror", updateAt "mirror" (Ref "p") (atom "want"))
      ]
  }

enterAction :: Action
enterAction = Action
  { actionName = "Enter"
  , actionParameters = [processParameter]
  , actionGuard = And
      [ Equal (pcAt (Ref "p")) (atom "want")
      , FiniteQuantifier ForAll "q" toyProcesses
          (Or
            [ Equal (Ref "q") (Ref "p")
            , NotEqual (pcAt (Ref "q")) (atom "critical")
            ])
      ]
  , actionEffects =
      [ ("pc", updateAt "pc" (Ref "p") (atom "critical"))
      , ("mirror", updateAt "mirror" (Ref "p") (atom "critical"))
      , ("criticalCount", integer 1)
      ]
  }

exitAction :: Action
exitAction = Action
  { actionName = "Exit"
  , actionParameters = [processParameter]
  , actionGuard = Equal (pcAt (Ref "p")) (atom "critical")
  , actionEffects =
      [ ("pc", updateAt "pc" (Ref "p") (atom "idle"))
      , ("mirror", updateAt "mirror" (Ref "p") (atom "idle"))
      , ("criticalCount", integer 0)
      ]
  }

toyModel :: Model
toyModel = Model
  { modelName = "ToyModel"
  , modelConstants = [("Proc", SetValue [AtomValue "p0", AtomValue "p1"])]
  , modelVariables = ["pc", "mirror", "criticalCount"]
  , modelInit =
      [ ("pc", FunctionLiteral "p" toyProcesses (atom "idle"))
      , ("mirror", FunctionLiteral "p" toyProcesses (atom "idle"))
      , ("criticalCount", integer 0)
      ]
  , modelActions = [requestAction, enterAction, exitAction]
  , modelInvariants = [NamedExpr "MutualExclusion" mutualExclusion]
  , modelConstraint = Just (NamedExpr "StateBound" stateBound)
  , modelExpansionLimit = Nothing
  , modelFairness =
      [ Fairness WeakFair "Request"
      , Fairness StrongFair "Enter"
      , Fairness WeakFair "Exit"
      ]
  , modelProperties =
      [ Property "EveryRequestEventuallyExits" (LeadsTo anyCritical noCritical)
      , Property "AlwaysMutualExclusion" (Always (Ref "MutualExclusion"))
      , Property "SomeProcessEventuallyCritical" (Eventually anyCritical)
      ]
  , modelCheckDeadlock = False
  }
