{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-5 suite: the lift calculus against its two authored tables.
--
-- The tables are the independent side. Both are written from
-- 'lift_and_compose_doctrine.md' section 7 and never from the modules they judge: the
-- pair table says which of the nine ordered layer pairs the relation admits, and the
-- observation table says which evidence licenses which move. Each is joined in both
-- directions, because a one-way join catches a relation that admits too little and says
-- nothing about one that admits too much.
--
-- Two claims are deliberately not checked in here. That there is no catch-all arm is a
-- property of the source rather than of any value it computes, so the gate scans for one;
-- and that a witness cannot be written down, and that two paths whose layers do not meet
-- cannot be composed, are claims about types, so they are committed compile-fail pairs.
--
-- Nothing below is partial. The corpus is built through 'observe', which may refuse, so it
-- is a 'Maybe' and the suite reports an unbuildable corpus as its own failure rather than
-- reaching for an exception a calculus is not allowed to throw.
module Main (main) where

import Amoebius.Calculus.Lift.Compose
  ( Path
  , PlanError (LayersDoNotMeet)
  , compose
  , here
  , pathLayers
  , pathSource
  , pathTarget
  , planFrom
  , step
  )
import Amoebius.Calculus.Lift.Layer
  ( Layer (..)
  , SLayer (..)
  , SomeLayer (..)
  , everyLayer
  , layerFromTag
  , layerOf
  , layerTag
  , sameLayer
  )
import Amoebius.Calculus.Lift.Transition
  ( Lift
  , SomeLift (..)
  , admits
  , enterContainer
  , enterFrame
  , liftDetail
  , liftSource
  , liftTarget
  , remain
  )
import Amoebius.Calculus.Lift.Witness
  ( Observation (..)
  , everyObservation
  , observationFromTag
  , observationTag
  , observe
  , witnessDetail
  )
import Data.List (nub, sort)
import Data.Maybe (isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Type.Equality ((:~:) (Refl))
import System.Exit (exitFailure)

main :: IO ()
main = checks

-- --------------------------------------------------------------------------
-- the authored tables
-- --------------------------------------------------------------------------

-- | One row of the pair table: an ordered layer pair and whether the relation admits it.
data PairRow = PairRow
  { pairSource :: Text
  , pairTarget :: Text
  , pairAdmitted :: Bool
  }
  deriving stock (Eq, Ord, Show)

-- | One row of the observation table: a transition, an observation, and whether that
-- evidence licenses that move.
data WitnessRow = WitnessRow
  { witnessSourceTag :: Text
  , witnessTargetTag :: Text
  , witnessObservation :: Text
  , witnessAdmitted :: Bool
  }
  deriving stock (Eq, Ord, Show)

readRows :: FilePath -> IO [[Text]]
readRows path = do
  contents <- readFile path
  pure [fields | line <- lines contents, fields <- usable (splitTabs line)]
  where
    usable fields = case fields of
      (first : _) | Text.isPrefixOf "#" first -> []
      [] -> []
      _ -> [fields]

readPairTable :: IO [PairRow]
readPairTable = fmap (concatMap build) (readRows "test/oracle/lift_calculus/transition_pairs.tsv")
  where
    build fields = case fields of
      [source, target, admitted, _why] -> [PairRow source target (admitted == "yes")]
      _ -> []

readWitnessTable :: IO [WitnessRow]
readWitnessTable =
  fmap (concatMap build) (readRows "test/oracle/lift_calculus/witness_observations.tsv")
  where
    build fields = case fields of
      [source, target, seen, admitted] -> [WitnessRow source target seen (admitted == "yes")]
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

-- | The transitions and paths every check below reads.
--
-- It is a 'Maybe', and that is the calculus doing its job rather than an inconvenience:
-- every lift here is built from a witness, every witness comes from 'observe', and
-- 'observe' refuses. There is no way to write this corpus that does not go through an
-- observation, which is the property the compile-fail pair states as a type.
data Corpus = Corpus
  { corpusFrame :: Lift 'OnHost 'InFrame
  , corpusContainer :: Lift 'InFrame 'InContainer
  , corpusHost :: Lift 'OnHost 'OnHost
  , corpusFrameDetail :: Text
  }

corpus :: Maybe Corpus
corpus = do
  frame <- observe SOnHost SInFrame (FrameRunning "lima-linux")
  engine <- observe SInFrame SInContainer (EngineResponding "containerd")
  host <- observe SOnHost SOnHost HostResponding
  pure
    Corpus
      { corpusFrame = enterFrame frame
      , corpusContainer = enterContainer engine
      , corpusHost = remain SOnHost host
      , corpusFrameDetail = witnessDetail frame
      }

hostPath :: Corpus -> Path 'OnHost 'OnHost
hostPath _built = here SOnHost

framePath :: Corpus -> Path 'OnHost 'InFrame
framePath built = step (corpusFrame built) (here SOnHost)

containerPath :: Corpus -> Path 'InFrame 'InContainer
containerPath built = step (corpusContainer built) (here SInFrame)

-- --------------------------------------------------------------------------
-- checks
-- --------------------------------------------------------------------------

checks :: IO ()
checks = do
  pairs <- readPairTable
  witnesses <- readWitnessTable
  case corpus of
    Nothing -> do
      putStrLn "  FAIL corpus-observable"
      putStrLn "lift-calculus-spec: FAIL corpus-observable"
      exitFailure
    Just built -> report pairs witnesses (results pairs witnesses built)

results :: [PairRow] -> [WitnessRow] -> Corpus -> [(String, Bool)]
results pairs witnesses built =
  [ ("layer-set-is-closed", layerSetIsClosed)
  , ("singleton-equality-is-decidable", singletonEqualityIsDecidable)
  , ("oracle-covers-every-pair", oracleCoversEveryPair pairs)
  , ("relation-matches-oracle", relationMatchesOracle pairs)
  , ("oracle-covers-every-observation", oracleCoversEveryObservation witnesses)
  , ("witness-requires-observation", witnessRequiresObservation witnesses)
  , ("witness-is-transition-specific", witnessIsTransitionSpecific)
  , ("witness-travels-into-its-lift", witnessTravelsIntoItsLift built)
  , ("composition-requires-meeting-layers", compositionRequiresMeetingLayers built)
  , ("composition-is-associative", compositionIsAssociative built)
  , ("identity-is-neutral", identityIsNeutral built)
  ]

report :: [PairRow] -> [WitnessRow] -> [(String, Bool)] -> IO ()
report pairs witnesses outcomes = do
  mapM_ (\(name, verdict) -> putStrLn ((if verdict then "  ok   " else "  FAIL ") <> name)) outcomes
  case [name | (name, verdict) <- outcomes, not verdict] of
    [] ->
      putStrLn
        ( "lift-calculus-spec: PASS ("
            <> show (length pairs)
            <> " pairs, "
            <> show (length witnesses)
            <> " observations, "
            <> show (length outcomes)
            <> " checks)"
        )
    failures -> do
      putStrLn ("lift-calculus-spec: FAIL " <> unwords failures)
      exitFailure

-- | Three layers, each with a singleton, each tag round-tripping. A member added to the
-- promoted set without a singleton fails to compile in the module; this is the value-level
-- half — that nothing enumerates fewer than the set has.
layerSetIsClosed :: Bool
layerSetIsClosed =
  length everyLayer == 3
    && sort tags == sort (nub tags)
    && all roundTrips layerValues
  where
    tags = fmap layerTag layerValues
    roundTrips layer = layerFromTag (layerTag layer) == Just layer

layerValues :: [Layer]
layerValues = [layerOf singleton | SomeLayer singleton <- everyLayer]

-- | Equality on the singletons is decided, and decided correctly: the type-level evidence
-- comes back exactly when the two layers are the same one. That is what lets a plan
-- assembled at run time be composed under the same equation a written one obeys.
singletonEqualityIsDecidable :: Bool
singletonEqualityIsDecidable =
  and
    [ decided left right == (layerOf left == layerOf right)
    | SomeLayer left <- everyLayer
    , SomeLayer right <- everyLayer
    ]
  where
    decided left right = case sameLayer left right of
      Just Refl -> True
      Nothing -> False

-- | The table names every ordered pair of the closed set exactly once. A pair it omits is
-- a relation arm nothing checks; a pair it repeats discharges nothing twice.
oracleCoversEveryPair :: [PairRow] -> Bool
oracleCoversEveryPair table =
  sort [(pairSource row, pairTarget row) | row <- table]
    == sort [(layerTag from, layerTag to) | from <- layerValues, to <- layerValues]

-- | The join, in both directions: the relation admits a pair exactly when the table does.
relationMatchesOracle :: [PairRow] -> Bool
relationMatchesOracle table = and (fmap agrees table)
  where
    agrees row = case (layerFromTag (pairSource row), layerFromTag (pairTarget row)) of
      (Just from, Just to) -> admits from to == pairAdmitted row
      _ -> False

-- | The observation table crosses every admitted transition with every observation. A
-- missing cell is evidence nobody asked about.
oracleCoversEveryObservation :: [WitnessRow] -> Bool
oracleCoversEveryObservation table =
  sort [(witnessSourceTag row, witnessTargetTag row, witnessObservation row) | row <- table]
    == sort
      [ (layerTag from, layerTag to, observationTag seen)
      | (from, to) <- admittedPairs
      , seen <- everyObservation
      ]

admittedPairs :: [(Layer, Layer)]
admittedPairs = [(from, to) | from <- layerValues, to <- layerValues, admits from to]

-- | The refusing half of section 7: a witness exists exactly where the table says
-- something was seen that reports the transition's precondition.
witnessRequiresObservation :: [WitnessRow] -> Bool
witnessRequiresObservation table = and (fmap agrees table)
  where
    agrees row =
      case
        ( layerFromTag (witnessSourceTag row)
        , layerFromTag (witnessTargetTag row)
        , observationFromTag (witnessObservation row)
        ) of
        (Just from, Just to, Just seen) -> observedAt from to seen == witnessAdmitted row
        _ -> False

-- | Whether a witness exists for one transition under one observation, reached through the
-- singletons so the answer is about the indexed type rather than about three loose values.
observedAt :: Layer -> Layer -> Observation -> Bool
observedAt from to seen = case (singletonFor from, singletonFor to) of
  (SomeLayer sFrom, SomeLayer sTo) -> isJust (observe sFrom sTo seen)

-- | The singleton for a layer. Written out over the closed set rather than searched for,
-- so there is no arm that answers when the search fails.
singletonFor :: Layer -> SomeLayer
singletonFor = \case
  OnHost -> SomeLayer SOnHost
  InFrame -> SomeLayer SInFrame
  InContainer -> SomeLayer SInContainer

-- | The evidence for one transition does not license another. A running frame admits the
-- frame entry and not the container entry; a responding engine admits the reverse.
witnessIsTransitionSpecific :: Bool
witnessIsTransitionSpecific =
  isJust (observe SOnHost SInFrame frameRunning)
    && not (isJust (observe SInFrame SInContainer frameRunning))
    && isJust (observe SInFrame SInContainer engineResponding)
    && not (isJust (observe SOnHost SInFrame engineResponding))
  where
    frameRunning = FrameRunning "lima-linux"
    engineResponding = EngineResponding "containerd"

-- | What the witness recorded travels into the transition it licensed, so the evidence
-- stays attached to the move rather than being consumed and forgotten.
witnessTravelsIntoItsLift :: Corpus -> Bool
witnessTravelsIntoItsLift built =
  liftDetail (corpusFrame built) == corpusFrameDetail built
    && Text.isPrefixOf "frame:" (corpusFrameDetail built)

-- | The type equation, stated over values: a plan walks only while each transition starts
-- where the last one ended.
compositionRequiresMeetingLayers :: Corpus -> Bool
compositionRequiresMeetingLayers built =
  planFrom OnHost [frameStep, containerStep] == Right InContainer
    && planFrom OnHost [containerStep] == Left (LayersDoNotMeet OnHost InFrame)
    && planFrom OnHost [frameStep, frameStep] == Left (LayersDoNotMeet InFrame OnHost)
    && planFrom OnHost [hostStep, frameStep] == Right InFrame
    && all admitted [frameStep, containerStep, hostStep]
  where
    frameStep = SomeLift SOnHost SInFrame (corpusFrame built)
    containerStep = SomeLift SInFrame SInContainer (corpusContainer built)
    hostStep = SomeLift SOnHost SOnHost (corpusHost built)
    admitted (SomeLift _from _to transition) =
      admits (liftSource transition) (liftTarget transition)

-- | Composition is associative, which is what makes a path a path rather than a
-- particular bracketing of one.
compositionIsAssociative :: Corpus -> Bool
compositionIsAssociative built =
  pathLayers (compose (compose (containerPath built) (framePath built)) (hostPath built))
    == pathLayers (compose (containerPath built) (compose (framePath built) (hostPath built)))

-- | The identity at a layer composes away on both sides.
identityIsNeutral :: Corpus -> Bool
identityIsNeutral built =
  pathLayers (compose (here SInFrame) (framePath built)) == pathLayers (framePath built)
    && pathLayers (compose (framePath built) (here SOnHost)) == pathLayers (framePath built)
    && pathSource (framePath built) == OnHost
    && pathTarget (framePath built) == InFrame
