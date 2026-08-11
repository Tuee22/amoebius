module Amoebius.Formal.Model
  ( Name
  , Value (..)
  , Expr (..)
  , Comparison (..)
  , Quantifier (..)
  , Parameter (..)
  , Action (..)
  , NamedExpr (..)
  , FairnessKind (..)
  , Fairness (..)
  , Temporal (..)
  , Property (..)
  , Model (..)
  , Event (..)
  , State
  , modelProblems
  ) where

import Data.Map.Strict (Map)
import Data.List (group, sort)

type Name = String

data Value
  = BoolValue Bool
  | IntValue Integer
  | AtomValue String
  | SetValue [Value]
  | FunctionValue [(Value, Value)]
  deriving stock (Eq, Ord, Show)

data Comparison = LessThan | LessThanOrEqual | GreaterThan | GreaterThanOrEqual
  deriving stock (Eq, Ord, Show)

data Quantifier = ForAll | Exists
  deriving stock (Eq, Ord, Show)

-- | The deliberately closed, first-order expression fragment. 'Ref' resolves
-- lexical binders first, then action parameters, state variables, and constants.
data Expr
  = Literal Value
  | Ref Name
  | Not Expr
  | And [Expr]
  | Or [Expr]
  | Implies Expr Expr
  | Equal Expr Expr
  | NotEqual Expr Expr
  | ArithmeticComparison Comparison Expr Expr
  | Add Expr Expr
  | Subtract Expr Expr
  | FiniteSet [Expr]
  | SetUnion Expr Expr
  | SetDifference Expr Expr
  | Cardinality Expr
  | FiniteSetMembership Expr Expr
  | FiniteQuantifier Quantifier Name Expr Expr
  | FunctionLiteral Name Expr Expr
  | FunctionUpdate Expr Expr Expr
  | FunctionApplication Expr Expr
  | IfThenElse Expr Expr Expr
  deriving stock (Eq, Ord, Show)

data Parameter = Parameter
  { parameterName :: Name
  , parameterDomain :: Expr
  }
  deriving stock (Eq, Ord, Show)

data Action = Action
  { actionName :: Name
  , actionParameters :: [Parameter]
  , actionGuard :: Expr
  , actionEffects :: [(Name, Expr)]
  }
  deriving stock (Eq, Ord, Show)

data NamedExpr = NamedExpr
  { namedExprName :: Name
  , namedExprBody :: Expr
  }
  deriving stock (Eq, Ord, Show)

data FairnessKind = WeakFair | StrongFair
  deriving stock (Eq, Ord, Show)

data Fairness = Fairness
  { fairnessKind :: FairnessKind
  , fairnessAction :: Name
  }
  deriving stock (Eq, Ord, Show)

data Temporal
  = Always Expr
  | Eventually Expr
  | LeadsTo Expr Expr
  deriving stock (Eq, Ord, Show)

data Property = Property
  { propertyName :: Name
  , propertyTemporal :: Temporal
  }
  deriving stock (Eq, Ord, Show)

data Model = Model
  { modelName :: Name
  , modelConstants :: [(Name, Value)]
  , modelVariables :: [Name]
  , modelInit :: [(Name, Expr)]
  , modelActions :: [Action]
  , modelInvariants :: [NamedExpr]
  -- | TLC state constraint. States failing it are not part of the distinct set.
  , modelConstraint :: Maybe NamedExpr
  -- | Optional expansion bound. A failing state is counted and checked, but is
  -- not expanded. This makes the plan's boundary convention explicit instead
  -- of conflating it with TLC's exclusionary CONSTRAINT semantics.
  , modelExpansionLimit :: Maybe Expr
  , modelFairness :: [Fairness]
  , modelProperties :: [Property]
  , modelCheckDeadlock :: Bool
  }
  deriving stock (Eq, Ord, Show)

data Event = Event
  { eventAction :: Name
  , eventArguments :: [Value]
  }
  deriving stock (Eq, Ord, Show)

type State = Map Name Value

-- | Structural well-formedness errors that can be decided without evaluating
-- the model. Expression sort errors remain explicit 'Left' values in evalExpr.
modelProblems :: Model -> [String]
modelProblems model = concat
  [ duplicates "constant" (map fst (modelConstants model))
  , duplicates "variable" (modelVariables model)
  , duplicates "initial assignment" (map fst (modelInit model))
  , ["initial assignments do not exactly cover model variables"
    | sort (map fst (modelInit model)) /= sort (modelVariables model)]
  , duplicates "action" (map actionName (modelActions model))
  , duplicates "invariant" (map namedExprName (modelInvariants model))
  , duplicates "property" (map propertyName (modelProperties model))
  , concatMap actionProblems (modelActions model)
  , ["fairness references unknown action " <> fairnessAction fairness
    | fairness <- modelFairness model
    , fairnessAction fairness `notElem` map actionName (modelActions model)]
  ]
  where
    actionProblems action =
      duplicates ("parameter in action " <> actionName action) (map parameterName (actionParameters action))
        <> duplicates ("effect in action " <> actionName action) (map fst (actionEffects action))
        <> ["action " <> actionName action <> " effects unknown variable " <> name
           | (name, _) <- actionEffects action, name `notElem` modelVariables model]
    duplicates kind names =
      ["duplicate " <> kind <> " " <> name | name : _ : _ <- group (sort names)]
