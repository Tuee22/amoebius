{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The workflow itself: five arms over one vocabulary, indexed by what it still owes.
--
-- 'workflow_calculus_doctrine.md' section 3 is the whole of this module's design. Provision
-- returns a handle and a teardown obligation together; the obligation is discharged by
-- tearing the resource down or by transferring it to something longer-lived under a stated
-- condition; and ending while still holding one is rejected at compile time.
--
-- The outstanding set is the workflow's type index. 'provision' adds a name to it,
-- 'teardown' and 'transfer' remove one, and 'runWorkflow' accepts only
-- @Workflow '[] '[]@ — a workflow that began owing nothing and ends owing nothing. There
-- is no combinator that shrinks the set any other way, which is what \"no discard rule\"
-- means here: dropping an obligation is not refused at run time, it is unspellable.
--
-- Composition is typed by what each arm consumes. 'andThen' threads the outstanding set
-- through, so a sequence's obligations are the second arm's applied to the first's;
-- 'inParallel' requires the two branches to owe nothing in common, which is section 2's
-- \"over disjoint resources\" as a constraint rather than as a convention.
module Amoebius.Calculus.Workflow.Run
  ( Workflow
  , Handle
  , handleResource
  , pureWorkflow
  , andThen
  , inParallel
  , provision
  , build
  , deploy
  , observe
  , teardown
  , transfer
  , runWorkflow
  ) where

import Amoebius.Calculus.Workflow.Arm
  ( Arm (Build, Deploy, Observe, Provision, Teardown)
  , Condition
  , Discharge (ToreDown, TransferredTo)
  , Evidence (Evidence)
  , Resource (Resource)
  )
#ifdef WORKFLOW_CALCULUS_TRANSFER_CONDITION_OPTIONAL_MUTANT
import Amoebius.Calculus.Workflow.Arm qualified as WorkflowArm
#endif
import Amoebius.Calculus.Workflow.Ledger
  ( Ledger
  , emptyLedger
  , recordArm
  , recordProvision
  , recordRelease
  )
import Amoebius.Calculus.Workflow.Obligation (Append, Disjoint, Remove)
import Data.Proxy (Proxy)
import Data.Text qualified as Text
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)

-- | A handle to a provisioned resource. The constructor is not exported: a handle exists
-- because 'provision' produced one, and the obligation that came with it is in the
-- workflow's type rather than in the handle.
newtype Handle = Handle {handleResource :: Resource}
  deriving stock (Eq, Ord, Show)

-- | A workflow, indexed by the obligations it holds before and after.
--
-- The representation is a state fold over the ledger, because the whole calculus is stated
-- over values: an arm is something that happened, and a workflow is the record of what
-- happened together with the value it computed. The indices are phantom and carry the
-- obligation discipline; the ledger carries what an oracle replays.
newtype Workflow (before :: [Symbol]) (after :: [Symbol]) a
  = Workflow (Ledger -> (a, Ledger))

-- | A workflow that does nothing and owes nothing new.
pureWorkflow :: a -> Workflow rs rs a
pureWorkflow value = Workflow (\ledger -> (value, ledger))

-- | Sequential composition. The second workflow consumes the first's value, and the
-- outstanding set threads through: a sequence owes what the second arm leaves owing.
andThen :: Workflow as bs x -> (x -> Workflow bs cs y) -> Workflow as cs y
andThen (Workflow first) next =
  Workflow
    ( \ledger -> case first ledger of
        (value, afterFirst) -> case next value of
          Workflow second -> second afterFirst
    )

-- | Parallel composition over disjoint resources.
--
-- Each branch starts owing nothing and ends owing its own set; the composition owes both,
-- on top of whatever was already outstanding. 'Disjoint' is what stops two branches from
-- provisioning the same resource — which would leave the ledger balanced while the thing
-- was created twice.
--
-- The branches are interleaved by running them in order, which is the honest reading of
-- \"may interleave\" for a pure calculus: nothing here executes, so what parallel
-- composition asserts is that the two orders are equally admissible, not that anything ran
-- at once.
inParallel
  :: Disjoint bs cs
  => Workflow '[] bs x
  -> Workflow '[] cs y
  -> Workflow rs (Append bs (Append cs rs)) (x, y)
inParallel (Workflow left) (Workflow right) =
#ifdef WORKFLOW_CALCULUS_PARALLEL_REVERSES_BRANCHES_MUTANT
  Workflow
    ( \ledger -> case right ledger of
        (rightValue, afterRight) -> case left afterRight of
          (leftValue, afterLeft) -> ((leftValue, rightValue), afterLeft)
    )
#else
  Workflow
    ( \ledger -> case left ledger of
        (leftValue, afterLeft) -> case right afterLeft of
          (rightValue, afterRight) -> ((leftValue, rightValue), afterRight)
    )
#endif

-- | Bring a declared resource into existence, yielding a handle that witnesses it and an
-- obligation that is now in the type.
provision :: KnownSymbol r => Proxy r -> Workflow rs (r ': rs) Handle
provision name =
  Workflow
    ( \ledger ->
        ( Handle resource
        , recordProvision resource (recordArm Provision ledger)
        )
    )
  where
    resource = resourceOf name

-- | Materialize the artifacts the change needs. It owes nothing: what a build spends is a
-- grant, which is the budget calculus's, and what it produces is an artifact, which is the
-- artifact calculus's.
build :: Workflow rs rs ()
build = Workflow (\ledger -> ((), recordArm Build ledger))

-- | Move a system from one declared state to another.
deploy :: Workflow rs rs ()
deploy = Workflow (\ledger -> ((), recordArm Deploy ledger))

-- | Read the system's actual state, producing evidence rather than a log line.
observe :: Workflow rs rs Evidence
observe = Workflow (\ledger -> (Evidence "observed", recordArm Observe ledger))

-- | Discharge an obligation by returning the resource.
teardown :: KnownSymbol r => Proxy r -> Workflow rs (Remove r rs) ()
teardown name = Workflow (\ledger -> ((), released (recordArm Teardown ledger)))
  where
    resource = resourceOf name
#if defined(WORKFLOW_CALCULUS_OBLIGATION_DROPPED_MUTANT)
    -- The seeded drop. The arm still ran and still appears in the trace; only the record
    -- that the obligation left the outstanding set is missing, which is exactly the shape
    -- of the cleanup script that quietly diverges from what the other arms created. The
    -- provisioned and released sets stop being equal, and nothing else moves.
    released = id
#elif defined(WORKFLOW_CALCULUS_OBLIGATION_DISCHARGED_TWICE_MUTANT)
    -- The seeded double discharge. The two sets stay equal, so the balance question sees
    -- nothing at all; only the multiplicity question does, which is why the ledger asks
    -- both rather than one.
    released ledger = recordRelease resource ToreDown (recordRelease resource ToreDown ledger)
#else
    released = recordRelease resource ToreDown
#endif

-- | Discharge an obligation by transferring it to a longer-lived declaration, under a
-- stated condition.
--
-- The condition is an argument and not a field with a default, so a caller that forgets it
-- does not get a transfer with a hole in it — it gets a function, and the committed
-- compile-fail twin is exactly that program.
#ifdef WORKFLOW_CALCULUS_TRANSFER_CONDITION_OPTIONAL_MUTANT
transfer :: KnownSymbol r => Proxy r -> Workflow rs (Remove r rs) ()
transfer name =
  Workflow
    ( \ledger ->
        ((), recordRelease (resourceOf name) (TransferredTo (WorkflowArm.Condition "unstated")) (recordArm Teardown ledger))
    )
#else
transfer :: KnownSymbol r => Proxy r -> Condition -> Workflow rs (Remove r rs) ()
transfer name condition =
  Workflow
    ( \ledger ->
        ((), recordRelease (resourceOf name) (dischargeFor condition) (recordArm Teardown ledger))
    )
  where
#ifdef WORKFLOW_CALCULUS_TRANSFER_WITHOUT_A_CONDITION_MUTANT
    -- The seeded loss. The obligation still leaves the outstanding set and the ledger
    -- still balances, so neither of the ledger's two questions notices; what is gone is
    -- the record of /why/ it left, and a transfer whose condition nobody stated is the
    -- orphan this calculus exists to foreclose arriving through the one door left open.
    dischargeFor _stated = ToreDown
#else
    dischargeFor = TransferredTo
#endif
#endif

-- | Run a workflow that begins owing nothing and ends owing nothing.
--
-- The two @'[]@s are the whole of section 3's compile-time claim. A workflow still holding
-- an obligation has a different type, so it is not that this function refuses it — it is
-- that the application does not typecheck.
#ifdef WORKFLOW_CALCULUS_RUN_ACCEPTS_OUTSTANDING_MUTANT
runWorkflow :: Workflow '[] after a -> (a, Ledger)
#else
runWorkflow :: Workflow '[] '[] a -> (a, Ledger)
#endif
runWorkflow (Workflow fold) = fold emptyLedger

resourceOf :: KnownSymbol r => Proxy r -> Resource
resourceOf = Resource . Text.pack . symbolVal
