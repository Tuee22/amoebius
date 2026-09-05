{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-4 suite: the budget calculus against its independently authored
-- Haskell capacity relation.
--
-- The table is the independent side. It is written from
-- 'jit_budget_doctrine.md' sections 2, 3 and 4 and never from 'admit', so every row is a
-- demand vector the implementation has not seen, carrying both the verdict and the
-- /reason/. Checking the reason rather than only the verdict is what makes a refusal
-- attributable: an admission that refused everything would agree with two thirds of a
-- verdict-only table.
--
-- One claim is deliberately not checked in here. \"A refusal leaves the store byte
-- identical\" is settled between two readings of the same run rather than by an assertion
-- that agrees with itself, so this binary prints the store's image on either side of a
-- refusal under @--store-identity@ and the gate compares them. That is also what keeps
-- the seeded partial-write mutant attributable: it leaves every check below green and
-- moves only the printed image.
module Main (main) where

import Amoebius.Calculus.Artifact.Address (addressHex, addressOf)
import Amoebius.Calculus.Artifact.Recipe
  ( Declaration (declarationBytes)
  , Recipe (..)
  , RecipeId (..)
  , Rendered (Rendered)
  , render
  , renderedBytes
  )
import Amoebius.Calculus.Artifact.Target (ArtifactKind (ObjectManifest), Target (ObjectManifestTarget))
import Amoebius.Calculus.Budget.Admission
  ( Budget
  , Demand (..)
  , Refusal (..)
  , admissionRefusalTags
  , admit
  , admitFirst
  , budgetHeldBytes
  , budgetHeldSlots
  , holding
  , openBudget
  , refusalTag
  , refusalTagText
  , release
  , reservationBytes
  , settle
  )
import Amoebius.Calculus.Budget.Grant
  ( Allowance
  , Bytes (..)
  , Grant
  , IssueRefusal (PoolBytesExhausted)
  , Location (..)
  , Purpose (..)
  , Slots (..)
  , allowance
  , everyPurpose
  , issue
  , pool
  , poolFreeBytes
  , purposeTag
  )
import Amoebius.Calculus.Budget.Retention
  ( Reaper (EvictionPolicy, GenerationBound)
  , retain
  , retentionReaper
  )
import Amoebius.Calculus.Budget.Store
  ( Placement
  , Store
  , emptyStore
  , materializeUnder
  , placement
  , storeCommitted
  , storeImageHex
  , storeStaging
  )
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Word (Word32, Word64)
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--store-identity"] -> storeIdentityReport
    ["--grants"] -> grantAccounting
    _ -> checks

-- --------------------------------------------------------------------------
-- the authored table
-- --------------------------------------------------------------------------

-- | One row of the capacity table: a grant shape, an in-flight state, a demand, and the
-- verdict the doctrine gives it.
data Row = Row
  { rowCase :: Text
  , rowCeiling :: Word64
  , rowConcurrency :: Word32
  , rowPerItem :: Word64
  , rowHeldBytes :: Word64
  , rowHeldSlots :: Word32
  , rowLocation :: Text
  , rowPurpose :: Text
  , rowDemand :: Word64
  , rowVerdict :: Text
  , rowReason :: Text
  }
  deriving stock (Eq, Show)

independentAdmissionOracle :: [Row]
independentAdmissionOracle =
  [ row "fits-empty" 40 4 15 0 0 "cache-a" "build-cache" 10 "admitted" "-"
  , row "fits-to-the-ceiling" 40 4 15 30 2 "cache-a" "build-cache" 10 "admitted" "-"
  , row "fits-on-the-last-slot" 40 4 15 10 3 "cache-a" "build-cache" 10 "admitted" "-"
  , row "fits-at-the-per-item-bound" 40 4 15 0 0 "cache-a" "build-cache" 15 "admitted" "-"
  , row "fits-nothing-asked" 40 4 15 0 0 "cache-a" "build-cache" 0 "admitted" "-"
  , row "narrow-grant-fits" 1 1 1 0 0 "cache-a" "build-cache" 1 "admitted" "-"
  , row "ceiling-one-over" 40 4 15 31 1 "cache-a" "build-cache" 10 "refused" "ceiling-exceeded"
  , row "ceiling-already-full" 40 4 15 40 1 "cache-a" "build-cache" 1 "refused" "ceiling-exceeded"
  , row "ceiling-sum-overruns" 40 4 15 28 1 "cache-a" "build-cache" 15 "refused" "ceiling-exceeded"
  , row "narrow-grant-ceiling" 1 1 1 1 0 "cache-a" "build-cache" 1 "refused" "ceiling-exceeded"
  , row "concurrency-with-room-to-spare" 40 2 15 20 2 "cache-a" "build-cache" 10 "refused" "concurrency-exhausted"
  , row "concurrency-single-slot" 40 1 15 5 1 "cache-a" "build-cache" 5 "refused" "concurrency-exhausted"
  , row "concurrency-none-granted" 40 0 15 0 0 "cache-a" "build-cache" 1 "refused" "concurrency-exhausted"
  , row "narrow-grant-concurrency" 1 1 1 0 1 "cache-a" "build-cache" 0 "refused" "concurrency-exhausted"
  , row "per-item-one-over" 40 4 15 0 0 "cache-a" "build-cache" 16 "refused" "per-item-bound-exceeded"
  , row "per-item-before-ceiling" 40 4 15 30 1 "cache-a" "build-cache" 16 "refused" "per-item-bound-exceeded"
  , row "per-item-clamped" 40 4 60 0 0 "cache-a" "build-cache" 41 "refused" "per-item-bound-exceeded"
  , row "wrong-location-empty" 40 4 15 0 0 "cache-b" "build-cache" 1 "refused" "wrong-location"
  , row "wrong-location-would-fit" 40 4 15 0 0 "scratch" "build-cache" 10 "refused" "wrong-location"
  , row "wrong-location-before-size" 40 4 15 0 0 "cache-b" "build-cache" 99 "refused" "wrong-location"
  , row "wrong-purpose-checkpoint" 40 4 15 0 0 "cache-a" "model-checkpoint" 1 "refused" "wrong-purpose"
  , row "wrong-purpose-artifact-store" 40 4 15 0 0 "cache-a" "artifact-store" 10 "refused" "wrong-purpose"
  , row "wrong-purpose-working-directory" 40 4 15 0 0 "cache-a" "working-directory" 10 "refused" "wrong-purpose"
  , row "wrong-purpose-before-size" 40 4 15 30 1 "cache-a" "model-checkpoint" 99 "refused" "wrong-purpose"
  ]
 where
  row name ceilingBytes slots perItem held heldSlots location purpose demand verdict reason =
    Row name ceilingBytes slots perItem held heldSlots location purpose demand verdict reason

-- --------------------------------------------------------------------------
-- the fixed grant every row is issued against
-- --------------------------------------------------------------------------

cacheLocation :: Location
cacheLocation = Location "cache-a"

-- | The grant a row is issued against.
--
-- The pool is exactly the row's own ceiling and concurrency, so no row is refused at
-- issue: this table is about admission, and a row that never got a grant would report a
-- scarcity failure as an admission one. Scarcity has its own check.
grantFor :: Row -> Maybe Grant
grantFor row =
  case issue
    (pool cacheLocation (Bytes (rowCeiling row)) (Slots (rowConcurrency row)))
    BuildCache
    (allowanceFor row) of
    Right (grant, _) -> Just grant
    Left _ -> Nothing

allowanceFor :: Row -> Allowance
allowanceFor row =
  allowance (Bytes (rowCeiling row)) (Slots (rowConcurrency row)) (Bytes (rowPerItem row))

budgetFor :: Row -> Maybe Budget
budgetFor row =
  fmap (\grant -> holding grant (Bytes (rowHeldBytes row)) (Slots (rowHeldSlots row))) (grantFor row)

demandFor :: Row -> Maybe Demand
demandFor row =
  fmap
    (\purpose -> Demand (Location (rowLocation row)) purpose (Bytes (rowDemand row)))
    (purposeFrom (rowPurpose row))

purposeFrom :: Text -> Maybe Purpose
purposeFrom wanted = case [p | p <- everyPurpose, purposeTag p == wanted] of
  (found : _) -> Just found
  [] -> Nothing

-- | The verdict and reason the implementation gives one row.
observed :: Row -> (Text, Text)
observed row = case (budgetFor row, demandFor row) of
  (Just budget, Just demand) -> case admit budget demand of
    Right _ -> ("admitted", "-")
    Left refusal -> ("refused", refusalTagText (refusalTag refusal))
  _ -> ("unreachable", "-")

-- --------------------------------------------------------------------------
-- checks
-- --------------------------------------------------------------------------

checks :: IO ()
checks = do
  let table = independentAdmissionOracle
      results =
        [ ("oracle-names-every-refusal", oracleNamesEveryRefusal table)
        , ("admission-matches-oracle", admissionMatchesOracle table)
        , ("pool-is-scarce", poolIsScarce)
        , ("grant-is-specific", grantIsSpecific)
        , ("admit-first-takes-first-fit", admitFirstTakesFirstFit)
        , ("admit-writes-nothing", admitWritesNothing)
        , ("release-and-settle-return-the-slot", releaseAndSettleReturnTheSlot)
        , ("materialize-commits-through-staging", materializeCommitsThroughStaging)
        , ("retention-names-its-reaper", retentionNamesItsReaper)
        , ("retention-refuses-past-ceiling", retentionRefusesPastCeiling)
        ]
      failures = [name | (name, verdict) <- results, not verdict]
  mapM_ (\(name, verdict) -> putStrLn ((if verdict then "  ok   " else "  FAIL ") <> name)) results
  if null failures
    then
      putStrLn
        ( "budget-calculus-spec: PASS ("
            <> show (length table)
            <> " rows, "
            <> show (length admissionRefusalTags)
            <> " refusal reasons, "
            <> show (length results)
            <> " checks)"
        )
    else do
      putStrLn ("budget-calculus-spec: FAIL " <> unwords failures)
      exitFailure

-- | The table is load-bearing only if it names every reason admission can give and no
-- other. A reason it omits is an arm nothing checks; a reason it invents is a claim
-- nothing discharges. `declaration-exceeded` is deliberately absent: that refusal belongs
-- to the store, not to admission, and the table would be wrong to expect it here.
oracleNamesEveryRefusal :: [Row] -> Bool
oracleNamesEveryRefusal table =
  sortUnique [rowReason row | row <- table, rowVerdict row == "refused"]
    == sortUnique (fmap refusalTagText admissionRefusalTags)
    && sortUnique [rowVerdict row | row <- table] == ["admitted", "refused"]

admissionMatchesOracle :: [Row] -> Bool
admissionMatchesOracle table =
  and [observed row == (rowVerdict row, rowReason row) | row <- table]

-- | A pool subtracts. Two grants cannot both hold the last unit, and the pool that could
-- not satisfy the second refuses rather than defaulting it to something unbounded.
poolIsScarce :: Bool
poolIsScarce = case issue (pool cacheLocation (Bytes 10) (Slots 2)) BuildCache half of
  Left _ -> False
  Right (_, afterFirst) -> case issue afterFirst BuildCache half of
    Left _ -> False
    Right (_, afterSecond) ->
      poolFreeBytes afterSecond == Bytes 0
        && case issue afterSecond BuildCache half of
          Left (PoolBytesExhausted asked free) -> asked == Bytes 5 && free == Bytes 0
          _ -> False
  where
    half = allowance (Bytes 5) (Slots 1) (Bytes 5)

-- | A grant is specific: neither the location nor the purpose can be swapped for another.
grantIsSpecific :: Bool
grantIsSpecific = case grantFor specimen of
  Nothing -> False
  Just grant ->
    let budget = openBudget grant
        elsewhere = Demand (Location "cache-b") BuildCache (Bytes 1)
        elsePurpose = Demand cacheLocation ModelCheckpoint (Bytes 1)
     in refuses (admit budget elsewhere) && refuses (admit budget elsePurpose)
  where
    refuses = \case
      Left _ -> True
      Right _ -> False

-- | `admitFirst` takes the first candidate that fits, and refuses with the last
-- candidate's reason when none do — the smaller variant is the one whose refusal tells the
-- caller something it can act on.
admitFirstTakesFirstFit :: Bool
admitFirstTakesFirstFit = case grantFor specimen of
  Nothing -> False
  Just grant ->
    let budget = holding grant (Bytes 30) (Slots 0)
        candidates = [want 15, want 12, want 8]
        allTooLarge = [want 15, want 14, want 13]
     in case admitFirst budget candidates of
          Right (reservation, _) -> reservationBytes reservation == Bytes 8 && lastReasonHolds budget allTooLarge
          Left _ -> False
  where
    want size = Demand cacheLocation BuildCache (Bytes size)
    lastReasonHolds budget candidates = case admitFirst budget candidates of
      Left (CeilingExceeded _ asked) -> asked == Bytes 43
      _ -> False

-- | A refused demand writes nothing: the budget it was decided against is the budget the
-- caller still holds, so a refusal costs nothing and leaves nothing behind.
admitWritesNothing :: Bool
admitWritesNothing = case grantFor specimen of
  Nothing -> False
  Just grant ->
    let budget = holding grant (Bytes 39) (Slots 1)
     in case admit budget (Demand cacheLocation BuildCache (Bytes 5)) of
          Left _ ->
            budgetHeldBytes budget == Bytes 39 && budgetHeldSlots budget == Slots 1
          Right _ -> False

-- | Both halves come back. A failed materialization returns the slot and the worst case;
-- a completed one returns them and holds the artifact's actual size in their place.
releaseAndSettleReturnTheSlot :: Bool
releaseAndSettleReturnTheSlot = case grantFor specimen of
  Nothing -> False
  Just grant -> case admit (openBudget grant) (Demand cacheLocation BuildCache (Bytes 12)) of
    Left _ -> False
    Right (reservation, taken) ->
      budgetHeldBytes taken == Bytes 12
        && budgetHeldSlots taken == Slots 1
        && release reservation taken == openBudget grant
        && budgetHeldBytes (settle reservation (Bytes 9) taken) == Bytes 9
        && budgetHeldSlots (settle reservation (Bytes 9) taken) == Slots 0

-- | A completed materialization commits at its address and leaves staging empty: the
-- staging location is where the bytes were, never where they are.
materializeCommitsThroughStaging :: Bool
materializeCommitsThroughStaging = case grantFor specimen of
  Nothing -> False
  Just grant -> case admit (openBudget grant) (Demand cacheLocation BuildCache (Bytes 12)) of
    Left _ -> False
    Right (reservation, _) ->
      case materializeUnder reservation (placed (Declared "aaaaaaaaaaaa")) emptyStore of
        (Left _, _) -> False
        (Right _, store) ->
          Map.size (storeCommitted store) == 1 && Map.null (storeStaging store)

-- | Every retention grant carries the reaper it was retained under. There is no arm that
-- declines to name one, so this check is about the value travelling intact rather than
-- about the field existing — the compile-fail twin is what holds the field.
retentionNamesItsReaper :: Bool
retentionNamesItsReaper = case grantFor specimen of
  Nothing -> False
  Just grant ->
    [ fmap retentionReaper (retain grant (Bytes 4) (EvictionPolicy "least-recently-used"))
    , fmap retentionReaper (retain grant (Bytes 4) (GenerationBound 3))
    ]
      == [Right (EvictionPolicy "least-recently-used"), Right (GenerationBound 3)]

-- | Retention is bounded by the same allowance admission is. Space held indefinitely is
-- still space.
retentionRefusesPastCeiling :: Bool
retentionRefusesPastCeiling = case grantFor specimen of
  Nothing -> False
  Just grant -> case retain grant (Bytes 99) (GenerationBound 1) of
    Left (PerItemBoundExceeded bound asked) -> bound == Bytes 15 && asked == Bytes 99
    _ -> False

-- | The grant shape the non-table checks use: section 3's worked proportions, so the
-- numbers a reader sees here are the numbers the doctrine argues over.
specimen :: Row
specimen =
  Row
    { rowCase = "specimen"
    , rowCeiling = 40
    , rowConcurrency = 4
    , rowPerItem = 15
    , rowHeldBytes = 0
    , rowHeldSlots = 0
    , rowLocation = "cache-a"
    , rowPurpose = "build-cache"
    , rowDemand = 0
    , rowVerdict = "admitted"
    , rowReason = "-"
    }

-- --------------------------------------------------------------------------
-- the store-identity report
-- --------------------------------------------------------------------------

-- | A declaration is whatever the recipe consumes. This one is a string, because the
-- store claim is about /whether/ bytes moved rather than about what they say.
newtype Declared = Declared Text

instance Declaration Declared where
  declarationBytes (Declared value) = Encoding.encodeUtf8 value

cacheRecipe :: Recipe 'ObjectManifest Declared
cacheRecipe =
  Recipe
    { recipeTarget = ObjectManifestTarget
    , recipeIdentity = RecipeId {recipeName = "budget-store-recipe", recipeRevision = 1}
    , recipeRender = \(Declared value) -> Rendered (Encoding.encodeUtf8 value)
    }

-- | The seam between the two calculi, and the only place they meet.
--
-- The budget calculus does not depend on the artifact calculus — a grant authorises bytes,
-- and how those bytes got their name is the other calculus's question. Here, where a
-- Phase-4 grant authorises a Phase-3 materialization, the address and the rendering are
-- taken from the recipe and handed to the store as one placement. That is the dependency
-- this phase declares on Phase 3, exercised where it can actually be exercised.
placed :: Declared -> Placement
placed declared =
  placement (addressHex (addressOf cacheRecipe declared rendered)) (renderedBytes rendered)
  where
    rendered = render cacheRecipe declared

-- | Drive a grant to its ceiling, then refuse twice and print the store on either side.
--
-- The first refusal is at admission and the second is mid-write. They are different
-- claims and the report carries both, because only the second one can go wrong: 'admit'
-- has no store in its type, so an admission refusal cannot touch one, while
-- 'materializeUnder' does and the staging rule is what keeps its refusal from leaving an
-- artifact at an address.
storeIdentityReport :: IO ()
storeIdentityReport = case grantFor specimen of
  Nothing -> putStrLn "store-identity\tno-grant" >> exitFailure
  Just grant -> do
    let (filledStore, filledBudget) = filledRegion grant
        atCeiling = storeImageHex filledStore
        ceilingRefused = case admit filledBudget (Demand cacheLocation BuildCache (Bytes 12)) of
          Left _ -> filledStore
          Right _ -> emptyStore
        declarationRefused = case admit filledBudget (Demand cacheLocation BuildCache (Bytes 2)) of
          Left _ -> filledStore
          Right (reservation, _) ->
            snd (materializeUnder reservation (placed (Declared "dddddddddddd")) filledStore)
    putStrLn (row "ceiling-refusal-before" atCeiling)
    putStrLn (row "ceiling-refusal-after" (storeImageHex ceilingRefused))
    putStrLn (row "declaration-refusal-before" atCeiling)
    putStrLn (row "declaration-refusal-after" (storeImageHex declarationRefused))
    putStrLn (row "committed-after-refusal" (Text.pack (show (Map.size (storeCommitted declarationRefused)))))
  where
    row label value = Text.unpack (label <> "\t" <> value)

-- | Three twelve-byte artifacts materialized under one grant, which leaves the ceiling
-- with four bytes of room and no slot outstanding.
filledRegion :: Grant -> (Store, Budget)
filledRegion grant =
  foldl fill (emptyStore, openBudget grant) ["aaaaaaaaaaaa", "bbbbbbbbbbbb", "cccccccccccc"]
  where
    fill (store, budget) body =
      case admit budget (Demand cacheLocation BuildCache (Bytes 12)) of
        Left _ -> (store, budget)
        Right (reservation, taken) ->
          case materializeUnder reservation (placed (Declared body)) store of
            (Left _, next) -> (next, release reservation taken)
            (Right _, next) ->
              (next, settle reservation (Bytes (fromIntegral (ByteString.length (Encoding.encodeUtf8 body)))) taken)

-- --------------------------------------------------------------------------
-- the grant accounting
-- --------------------------------------------------------------------------

-- | The per-region accounting `repository_layout_doctrine.md` section 3.1 reserves
-- `.build/grants/**` for: a ceiling, the concurrency it is shared across, and the
-- reservations outstanding against it.
--
-- The four rows are the four states the store-identity scenario passes through, which is
-- deliberate: the accounting is a reading of the same run rather than a second scenario
-- written to look tidy. An outstanding reservation is a held slot — each admission takes
-- exactly one — so the column is named for what it counts rather than for how it is
-- stored.
grantAccounting :: IO ()
grantAccounting = case grantFor specimen of
  Nothing -> putStrLn "grants\tno-grant" >> exitFailure
  Just grant -> do
    putStrLn "region\tceiling\tconcurrency\theld_bytes\toutstanding"
    let opened = openBudget grant
        inFlight = case admit opened (Demand cacheLocation BuildCache (Bytes 12)) of
          Left _ -> opened
          Right (_, taken) -> taken
        (_, atCeiling) = filledRegion grant
    mapM_
      (putStrLn . accountingRow)
      [ ("opened", opened)
      , ("one-in-flight", inFlight)
      , ("at-ceiling", atCeiling)
      , ("after-refusal", atCeiling)
      ]

accountingRow :: (Text, Budget) -> String
accountingRow (stage, budget) =
  Text.unpack
    ( Text.intercalate
        "\t"
        [ "cache-a/build-cache/" <> stage
        , decimal (rowCeiling specimen)
        , decimal (fromIntegral (rowConcurrency specimen))
        , heldBytesText budget
        , heldSlotsText budget
        ]
    )

heldBytesText :: Budget -> Text
heldBytesText budget = case budgetHeldBytes budget of
  Bytes value -> decimal value

heldSlotsText :: Budget -> Text
heldSlotsText budget = case budgetHeldSlots budget of
  Slots value -> decimal (fromIntegral value)

-- | Decimal rendering written out rather than taken from 'show', because the accounting
-- is read back by the gate and 'show' is a class method a later instance could redefine.
decimal :: Word64 -> Text
decimal value
  | value < 10 = digit value
  | otherwise = decimal (value `div` 10) <> digit (value `mod` 10)
  where
    digit n = Text.pack (take 1 (drop (fromIntegral n) "0123456789"))

-- | Sorted, without duplicates, written out rather than imported: the two sets this
-- compares are tiny, and an insertion sort with an equality case is easier to read as an
-- oracle join than a sort composed with a nub.
sortUnique :: Ord a => [a] -> [a]
sortUnique = foldr insert []
  where
    insert value [] = [value]
    insert value rest@(first : remaining)
      | value == first = rest
      | value < first = value : rest
      | otherwise = first : insert value remaining
