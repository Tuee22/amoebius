{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The mutant record, and the one registry the corpus lives in.
--
-- 'evidence_calculus_doctrine.md' section 4 is where this belongs: a fixture derived from
-- the thing it checks tests that a program agrees with itself, and amoebius's own gates are
-- workflows in the algebra they validate, so a fixture cannot always be authored by a path
-- outside the machinery. What is available is a /mutation argument/ — a corpus of
-- deliberately broken inputs, each of which the gate must reject for a named reason.
--
-- \"For a named reason\" is why a record has a locus. A mutant that merely turns a gate red
-- proves the gate reacts; one that turns a /named/ check red proves which claim was
-- holding the property, and a mutant pointed at the wrong locus is a corpus that agrees
-- with itself.
--
-- The registry is one registry. A mutation is reachable by a committed body, by a build
-- flag, or by the gate that materializes it, and which of those it is travels as a
-- **carrier field** rather than as a second file — because a second registry is how a
-- mutation stops being enumerated by anything, which is the defect the one registry was
-- built to end.
module Amoebius.Calculus.Evidence.Mutant
  ( Carrier (..)
  , carrierTag
  , carrierFor
  , MutantRecord
  , mutantCapability
  , mutantId
  , mutantOperator
  , mutantChange
  , mutantLocus
  , mutantCarrier
  , RecordError (..)
  , mutantRecord
  , Registry
  , registrySource
  , registryRecords
  , RegistryError (..)
  , registry
  ) where

import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text

-- | How a mutation is reached. Three arms and no fourth: a mutation nothing can reach is a
-- mutation nothing runs.
data Carrier
  = -- | A committed body, at the path it lives.
    CommittedBody Text
  | -- | An `amoebius.cabal` build flag.
    BuildFlag Text
  | -- | Materialized by the named gate from its own code, which is how a sweep over an
    -- authored inventory is carried.
    GateCarried Text
  deriving stock (Eq, Ord, Show)

carrierTag :: Carrier -> Text
carrierTag = \case
  CommittedBody _path -> "committed-body"
  BuildFlag _flag -> "build-flag"
  GateCarried _gate -> "gate-carried"

-- | The carrier a registry row's two fields describe, or nothing when both are absent —
-- which is a mutation nothing can reach and is refused rather than recorded.
carrierFor :: Text -> Text -> Maybe Carrier
carrierFor body flag
  | present body && Text.isPrefixOf "gate:" body = Just (GateCarried (Text.drop 5 body))
  | present body = Just (CommittedBody body)
  | present flag = Just (BuildFlag flag)
  | otherwise = Nothing
  where
    present value = not (Text.null (Text.strip value)) && Text.strip value /= "\x2014"

-- | One mutation: what it is, what it changes, and the check the gate must see redden.
--
-- 'mutantChange' is the capability's own detail vocabulary verbatim. The registry keeps
-- four fixed columns and lets each phase's fields travel intact beside them, because
-- flattening eight schemas into two would have made the file lie about five of them; so
-- what a mutation changes is described in that phase's words, and this field does not
-- re-spell it.
data MutantRecord = MutantRecord
  { mutantCapability :: Text
  , mutantId :: Text
  , mutantOperator :: Text
  , mutantChange :: Text
  , mutantLocus :: Text
  , mutantCarrier :: Carrier
  }
  deriving stock (Eq, Ord, Show)

-- | Why a row is not a record.
data RecordError
  = -- | Neither a committed body nor a build flag, so nothing can reach it.
    MutationIsUnreachable Text
  | -- | The row names no check the gate must see redden.
    MutationNamesNoLocus Text
  deriving stock (Eq, Show)

-- | Decode one registry row.
mutantRecord :: Text -> Text -> Text -> Text -> Text -> Text -> Text -> Either RecordError MutantRecord
mutantRecord capability identifier operator change locus body flag =
  case carrierFor body flag of
    Nothing -> Left (MutationIsUnreachable identifier)
    Just carrier
      | Text.null (Text.strip locus) -> Left (MutationNamesNoLocus identifier)
      | otherwise ->
          Right
            MutantRecord
              { mutantCapability = capability
              , mutantId = identifier
              , mutantOperator = operator
              , mutantChange = change
              , mutantLocus = reported locus
              , mutantCarrier = carrier
              }
  where
#ifdef EVIDENCE_CALCULUS_MUTANT_POINTS_AT_THE_WRONG_LOCUS_MUTANT
    -- The seeded misdirection. Every record reports the same locus, so the corpus still
    -- says a check must redden and no longer says which — which is a mutation argument
    -- that has stopped distinguishing the claim it was holding from any other.
    reported _stated = "the-gate"
#else
    reported = Text.strip
#endif

-- | The one registry: a source and the records read from it.
data Registry = Registry
  { registrySource :: Text
  , registryRecords :: [MutantRecord]
  }
  deriving stock (Eq, Show)

-- | Why a corpus is not one registry.
data RegistryError
  = -- | More than one file claims to be the registry.
    MoreThanOneRegistry [Text]
  | -- | No file does.
    NoRegistry
  | -- | Two records share a capability and an id, so one of them is unaddressable.
    DuplicateMutation Text
  deriving stock (Eq, Show)

-- | Build the registry from the sources offered.
--
-- Offering two is the defect this refuses. A second registry is not a redundancy, it is a
-- second answer to \"what is the corpus\", and the carrier field exists precisely so that a
-- mutation with an unusual carrier does not need one.
registry :: [(Text, [MutantRecord])] -> Either RegistryError Registry
registry offered = case offered of
  [] -> Left NoRegistry
  ((source, records) : rest)
    | admits rest -> duplicated (Registry {registrySource = source, registryRecords = records})
    | otherwise -> Left (MoreThanOneRegistry (fmap fst offered))
  where
#ifdef EVIDENCE_CALCULUS_SECOND_MUTANT_REGISTRY_MUTANT
    -- The seeded second file. A further source is accepted and its records are simply not
    -- read, which is worse than merging them: the corpus now has two answers and reports
    -- the first, so a mutation recorded in the second is enumerated by nothing.
    admits _rest = True
#else
    admits rest = null rest
#endif
    duplicated built = case identities built of
      keys | length keys == length (nub keys) -> Right built
      keys -> Left (DuplicateMutation (firstRepeat keys))
    identities built = [mutantCapability r <> "/" <> mutantId r | r <- registryRecords built]
    firstRepeat keys = case [key | (key, seen) <- zip keys (inits' keys), key `elem` seen] of
      (found : _) -> found
      [] -> ""
    inits' keys = scanl (\seen key -> seen <> [key]) [] keys
