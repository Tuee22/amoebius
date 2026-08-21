{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-6 suite: the workflow calculus against its authored obligation ledger.
--
-- The table is the independent side. It is written from
-- 'workflow_calculus_doctrine.md' section 3 and never from the ledger it judges: for each
-- of five workflows it names every resource provisioned and how that obligation left the
-- outstanding set. The suite runs each workflow and replays the table against what the run
-- actually recorded.
--
-- Three questions are asked of every ledger rather than one, because they fail separately.
-- Balance — as sets — catches an obligation that was dropped. Multiplicity catches one
-- discharged twice, which leaves the sets equal and is invisible to the first. And a
-- transferred obligation must carry the condition the workflow stated, which a transfer
-- recorded as a teardown loses while both sets stay untouched.
--
-- The claim the suite does not make is the one the type system already does: a workflow
-- that ends still holding an obligation is not a workflow this file could run, because
-- 'runWorkflow' accepts only an empty outstanding set. That is a committed compile-fail
-- pair, and so are the conditionless transfer and the teardown of something never held.
module Main (main) where

import Amoebius.Calculus.Workflow.Arm
  ( Arm (..)
  , Condition (Condition)
  , Discharge (TransferredTo)
  , Evidence (Evidence)
  , Resource (Resource)
  , armFromTag
  , armTag
  , everyArm
  )
import Amoebius.Calculus.Workflow.Ledger
  ( Ledger
  , balances
  , dischargedOnce
  , ledgerArms
  , ledgerProvisioned
  , ledgerReleased
  )
import Amoebius.Calculus.Workflow.Run
  ( Workflow
  , andThen
  , build
  , deploy
  , handleResource
  , inParallel
  , observe
  , provision
  , pureWorkflow
  , runWorkflow
  , teardown
  , transfer
  )
import Data.List (nub, sort)
import Data.Proxy (Proxy (Proxy))
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (exitFailure)

main :: IO ()
main = checks

-- --------------------------------------------------------------------------
-- the authored table
-- --------------------------------------------------------------------------

-- | One row: a workflow, a resource it provisioned, how the obligation left the
-- outstanding set, and — for a transfer — the condition the workflow stated.
data Row = Row
  { rowWorkflow :: Text
  , rowResource :: Text
  , rowDischarge :: Text
  , rowCondition :: Text
  }
  deriving stock (Eq, Ord, Show)

readTable :: IO [Row]
readTable = do
  contents <- readFile "test/oracle/workflow_calculus/obligation_ledger.tsv"
  pure [row | line <- lines contents, row <- parse (splitTabs line)]
  where
    parse fields = case fields of
      (first : _) | Text.isPrefixOf "#" first -> []
      [workflow, resource, discharge, condition] -> [Row workflow resource discharge condition]
      _ -> []

splitTabs :: String -> [Text]
splitTabs = fmap Text.pack . go
  where
    go text = case break (== '\t') text of
      (field, []) -> [field]
      (field, _ : rest) -> field : go rest

-- --------------------------------------------------------------------------
-- the corpus
-- --------------------------------------------------------------------------

-- | One resource, every arm: provision it, build, deploy, observe, and return it.
singleResource :: Workflow '[] '[] ()
singleResource =
  provision (Proxy @"db-volume") `andThen` \_handle ->
    build `andThen` \_ ->
      deploy `andThen` \_ ->
        observe `andThen` \_evidence ->
          teardown (Proxy @"db-volume")

-- | An obligation that outlives the workflow, transferred under a stated condition.
transferredLease :: Workflow '[] '[] ()
transferredLease =
  provision (Proxy @"cluster-lease") `andThen` \_handle ->
    deploy `andThen` \_ ->
      transfer (Proxy @"cluster-lease") leaseCondition

leaseCondition :: Condition
leaseCondition = Condition "until the retained deployment that took it is deleted"

-- | Two obligations held at once and discharged inside out, which is the ordinary shape:
-- a subnet cannot outlive the network it sits in.
nested :: Workflow '[] '[] ()
nested =
  provision (Proxy @"vpc") `andThen` \_ ->
    provision (Proxy @"subnet") `andThen` \_ ->
      teardown (Proxy @"subnet") `andThen` \_ ->
        teardown (Proxy @"vpc")

-- | Two branches over disjoint resources, whose obligations the workflow then discharges.
parallelBranches :: Workflow '[] '[] ()
parallelBranches =
  inParallel (provision (Proxy @"left-volume")) (provision (Proxy @"right-volume"))
    `andThen` \_ ->
      teardown (Proxy @"left-volume") `andThen` \_ ->
        teardown (Proxy @"right-volume")

-- | One of each discharge in the same workflow.
mixed :: Workflow '[] '[] ()
mixed =
  provision (Proxy @"bucket") `andThen` \_ ->
    provision (Proxy @"queue") `andThen` \_ ->
      teardown (Proxy @"bucket") `andThen` \_ ->
        transfer (Proxy @"queue") queueCondition

queueCondition :: Condition
queueCondition = Condition "when the owning tenant is deleted"

-- | The five workflows, each run to its ledger. The ids match the table's `workflow`
-- column, which is what makes the replay a join rather than a coincidence.
corpus :: [(Text, Ledger)]
corpus =
  [ ("single-resource", snd (runWorkflow singleResource))
  , ("transferred", snd (runWorkflow transferredLease))
  , ("nested", snd (runWorkflow nested))
  , ("parallel", snd (runWorkflow parallelBranches))
  , ("mixed", snd (runWorkflow mixed))
  ]

ledgerOf :: Text -> Maybe Ledger
ledgerOf wanted = case [ledger | (name, ledger) <- corpus, name == wanted] of
  (found : _) -> Just found
  [] -> Nothing

-- | A workflow that returns what its provision arm handed it, so the value threading of
-- 'andThen' is checked rather than assumed.
threaded :: Workflow '[] '[] Resource
threaded =
  provision (Proxy @"threaded-volume") `andThen` \handle ->
    teardown (Proxy @"threaded-volume") `andThen` \_ ->
      pureWorkflow (handleResource handle)

-- | A workflow that is only an observation.
observed :: Workflow '[] '[] Evidence
observed = observe

-- --------------------------------------------------------------------------
-- checks
-- --------------------------------------------------------------------------

checks :: IO ()
checks = do
  table <- readTable
  let outcomes =
        [ ("arm-set-is-closed", armSetIsClosed)
        , ("oracle-covers-every-workflow", oracleCoversEveryWorkflow table)
        , ("provisioned-and-released-sets-are-equal", setsAreEqual)
        , ("each-obligation-discharged-once", dischargedExactlyOnce)
        , ("transfer-records-its-condition", transferRecordsItsCondition table)
        , ("provisioned-set-matches-oracle", provisionedMatchesOracle table)
        , ("arms-are-recorded-in-order", armsAreRecordedInOrder)
        , ("parallel-branches-both-provision", parallelBranchesBothProvision)
        , ("sequence-threads-its-value", sequenceThreadsItsValue)
        , ("observe-produces-evidence", observeProducesEvidence)
        ]
      failures = [name | (name, verdict) <- outcomes, not verdict]
  mapM_ (\(name, verdict) -> putStrLn ((if verdict then "  ok   " else "  FAIL ") <> name)) outcomes
  if null failures
    then
      putStrLn
        ( "workflow-calculus-spec: PASS ("
            <> show (length table)
            <> " obligations, "
            <> show (length corpus)
            <> " workflows, "
            <> show (length outcomes)
            <> " checks)"
        )
    else do
      putStrLn ("workflow-calculus-spec: FAIL " <> unwords failures)
      exitFailure

-- | Five arms, tags unique, each tag round-tripping. A sixth arm is a change to the
-- module; this is the value-level half — that nothing enumerates fewer than the set has.
armSetIsClosed :: Bool
armSetIsClosed =
  length everyArm == 5
    && sort tags == sort (nub tags)
    && all (\arm -> armFromTag (armTag arm) == Just arm) everyArm
  where
    tags = fmap armTag everyArm

-- | The table names exactly the corpus's workflows, uses exactly the two discharges, and
-- states a condition for every transfer and for no teardown. A workflow it omits is a
-- ledger nothing replays; a discharge it invents is a claim nothing discharges.
oracleCoversEveryWorkflow :: [Row] -> Bool
oracleCoversEveryWorkflow table =
  sort (nub (fmap rowWorkflow table)) == sort (fmap fst corpus)
    && sort (nub (fmap rowDischarge table)) == ["tore-down", "transferred"]
    && all statesItsCondition table
  where
    statesItsCondition row = case rowDischarge row of
      "transferred" -> rowCondition row /= "-" && rowCondition row /= ""
      _ -> rowCondition row == "-"

-- | Every resource provisioned was released and every resource released was provisioned.
setsAreEqual :: Bool
setsAreEqual = all (balances . snd) corpus

-- | No resource left the outstanding set twice.
dischargedExactlyOnce :: Bool
dischargedExactlyOnce = all (dischargedOnce . snd) corpus

-- | A transferred obligation carries the condition the workflow stated, and the ledger
-- carries the same one the table does.
transferRecordsItsCondition :: [Row] -> Bool
transferRecordsItsCondition table =
  and [carries row | row <- table, rowDischarge row == "transferred"]
  where
    carries row = case ledgerOf (rowWorkflow row) of
      Nothing -> False
      Just ledger ->
        [discharge | (Resource name, discharge) <- ledgerReleased ledger, name == rowResource row]
          == [TransferredTo (Condition (rowCondition row))]

-- | What each workflow provisioned is what the table says it provisions.
provisionedMatchesOracle :: [Row] -> Bool
provisionedMatchesOracle table = all matches corpus
  where
    matches (name, ledger) =
      sort (nub [resource | Resource resource <- ledgerProvisioned ledger])
        == sort (nub [rowResource row | row <- table, rowWorkflow row == name])

-- | The arms appear in the order the workflow states them, so the ledger is a trace rather
-- than a summary.
armsAreRecordedInOrder :: Bool
armsAreRecordedInOrder =
  fmap ledgerArms (ledgerOf "single-resource")
    == Just [Provision, Build, Deploy, Observe, Teardown]

-- | Both parallel branches provisioned, in branch order.
parallelBranchesBothProvision :: Bool
parallelBranchesBothProvision =
  fmap ledgerProvisioned (ledgerOf "parallel")
    == Just [Resource "left-volume", Resource "right-volume"]

-- | The handle 'provision' returns reaches the end of the sequence, so 'andThen' threads
-- its value rather than discarding it.
sequenceThreadsItsValue :: Bool
sequenceThreadsItsValue = fst (runWorkflow threaded) == Resource "threaded-volume"

-- | The observe arm produces evidence, and the arm is recorded.
observeProducesEvidence :: Bool
observeProducesEvidence = case runWorkflow observed of
  (evidence, ledger) -> evidence == Evidence "observed" && ledgerArms ledger == [Observe]
