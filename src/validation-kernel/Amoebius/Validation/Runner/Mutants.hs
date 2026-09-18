{-# LANGUAGE OverloadedStrings #-}

-- | Stage 3 of the runner (gate_runner_doctrine.md section 3; gate integrity
-- section M.3): the fixed operator catalogue, deterministic sampling of loci in
-- the specification's stage modules, application to a copy of the tracked tree,
-- and the kill table. Mutants are generated, never authored, and every applied
-- mutant records a 'SubjectChangeWitness'.
module Amoebius.Validation.Runner.Mutants
  ( KillTable (..)
  , Locus (..)
  , MutantOutcome (..)
  , Operator (..)
  , SubjectChangeWitness (..)
  , allOperators
  , applyLocus
  , enumerateLoci
  , killTable
  , renderKillTable
  , renderOperator
  , sampleLoci
  ) where

import Amoebius.Validation.Runner.Observer (sha256Hex)
import Data.Char (isAlphaNum, isDigit)
import Data.List (sortOn)
import Data.Ratio ((%))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO

data Operator
  = ConstantFlip
  | BoundaryShift
  | BranchSwap
  | FieldDrop
  | ListTruncation
  deriving (Bounded, Enum, Eq, Ord, Show)

allOperators :: [Operator]
allOperators = [minBound .. maxBound]

renderOperator :: Operator -> Text
renderOperator operator = case operator of
  ConstantFlip -> "constant-flip"
  BoundaryShift -> "boundary-shift"
  BranchSwap -> "branch-swap"
  FieldDrop -> "field-drop"
  ListTruncation -> "list-truncation"

-- | One production locus: the module, its file, the line, the operator, and the
-- exact before/after line text.
data Locus = Locus
  { locusModule :: Text
  , locusFile :: FilePath
  , locusLine :: Int
  , locusOperator :: Operator
  , locusBefore :: Text
  , locusAfter :: Text
  }
  deriving (Eq, Ord, Show)

-- | Every locus an operator can rewrite in a source text, in line order.
-- Comment and pragma lines are skipped; a line yields at most one locus per
-- operator so the sample stays spread across the module.
enumerateLoci :: Text -> FilePath -> Operator -> Text -> [Locus]
enumerateLoci moduleName file operator source =
  [ Locus moduleName file number operator line rewritten
  | (number, line) <- zip [1 ..] (Text.lines source)
  , eligible line
  , Just rewritten <- [rewrite operator line]
  , rewritten /= line
  ]
 where
  eligible line =
    let trimmed = Text.stripStart line
     in not (Text.null trimmed)
          && not ("--" `Text.isPrefixOf` trimmed)
          && not ("{-" `Text.isPrefixOf` trimmed)
          && not ("import " `Text.isPrefixOf` trimmed)
          && not ("module " `Text.isPrefixOf` trimmed)
          && not ("#" `Text.isPrefixOf` trimmed)

rewrite :: Operator -> Text -> Maybe Text
rewrite operator line = case operator of
  ConstantFlip -> constantFlip line
  BoundaryShift -> firstReplacement [(" < ", " <= "), (" <= ", " < "), (" > ", " >= "), (" >= ", " > ")] line
  BranchSwap -> firstReplacement [(" == ", " /= "), (" /= ", " == "), ("if not (", "if ("), (" not $ ", " ")] line
  FieldDrop -> fieldDrop line
  ListTruncation -> listTruncation line

firstReplacement :: [(Text, Text)] -> Text -> Maybe Text
firstReplacement [] _ = Nothing
firstReplacement ((needle, replacement) : rest) line =
  case Text.breakOn needle line of
    (before, after)
      | Text.null after -> firstReplacement rest line
      | otherwise -> Just (before <> replacement <> Text.drop (Text.length needle) after)

-- | Flip the first standalone integer literal or Boolean constant on the line.
constantFlip :: Text -> Maybe Text
constantFlip line
  | Just rewritten <- firstReplacement [(" True", " False"), (" False", " True")] line = Just rewritten
  | otherwise = go "" line
 where
  go done rest
    | Text.null rest = Nothing
    | isDigit (Text.head rest) && boundaryBefore done =
        let (digits, after) = Text.span isDigit rest
         in if Text.null after || not (isAlphaNum (Text.head after) || Text.head after == '.')
              then case reads (Text.unpack digits) :: [(Integer, String)] of
                [(value, "")] -> Just (done <> Text.pack (show (value + 1)) <> after)
                _ -> Nothing
              else go (done <> digits) after
    | otherwise = go (Text.snoc done (Text.head rest)) (Text.tail rest)
  boundaryBefore done = Text.null done || not (isAlphaNum (Text.last done) || Text.last done `elem` ("_'." :: String))

-- | Drop a record field assignment written as its own @, field = value@ line.
fieldDrop :: Text -> Maybe Text
fieldDrop line =
  let trimmed = Text.stripStart line
   in if ", " `Text.isPrefixOf` trimmed && " = " `Text.isInfixOf` trimmed && fieldName (Text.drop 2 trimmed)
        then Just ""
        else Nothing
 where
  fieldName rest =
    let name = Text.takeWhile (\c -> isAlphaNum c || c == '_' || c == '\'') rest
     in not (Text.null name) && Text.head name `elem` ['a' .. 'z']

-- | Remove the last element of a one-line list literal with at least two elements.
listTruncation :: Text -> Maybe Text
listTruncation line = case Text.breakOnEnd "]" line of
  (withBracket, after)
    | Text.null withBracket -> Nothing
    | otherwise ->
        let body = Text.dropEnd 1 withBracket
            (beforeComma, lastElement) = Text.breakOnEnd ", " body
         in if Text.null beforeComma || Text.null (Text.strip lastElement) || "[" `Text.isInfixOf` lastElement || "\"" `Text.isInfixOf` lastElement
              then Nothing
              else Just (Text.dropEnd 2 beforeComma <> "]" <> after)

-- | Deterministic sampling: a xorshift stream seeded from the specification digest
-- and the module name selects at most @count@ loci, spread over the operators.
sampleLoci :: Text -> Int -> [Locus] -> [Locus]
sampleLoci seed count loci = sortOn (\locus -> (locusLine locus, locusOperator locus)) (go (seedValue seed) count loci)
 where
  go _ 0 _ = []
  go _ _ [] = []
  go state remaining pool =
    let next = xorshift state
        index = fromIntegral (next `mod` fromIntegral (length pool))
        (before, chosen : after) = splitAt index pool
     in chosen : go next (remaining - 1) (before <> after)

seedValue :: Text -> Word
seedValue seed = max 1 (fromIntegral (Text.foldl' (\acc c -> acc * 31 + fromEnum c) (7 :: Int) seed))

xorshift :: Word -> Word
xorshift state0 =
  let state1 = state0 `xorW` (state0 * 8192)
      state2 = state1 `xorW` (state1 `div` 128)
      state3 = state2 `xorW` (state2 * 131072)
   in if state3 == 0 then 88172645463325252 else state3
 where
  xorW a b = fromIntegral ((fromIntegral a :: Integer) `xorInteger` fromIntegral b)
  xorInteger a b = a + b - 2 * andInteger a b
  andInteger a b
    | a == 0 || b == 0 = 0
    | otherwise = (a `mod` 2) * (b `mod` 2) + 2 * andInteger (a `div` 2) (b `div` 2)

-- | The proof that a mutant changed the subject: file, line, and the digests of
-- the source before and after the rewrite.
data SubjectChangeWitness = SubjectChangeWitness
  { witnessFile :: FilePath
  , witnessLine :: Int
  , witnessOperator :: Operator
  , witnessBeforeDigest :: Text
  , witnessAfterDigest :: Text
  , witnessDiff :: Text
  }
  deriving (Eq, Ord, Show)

-- | Rewrite one line of the file at the locus inside a copied tree, returning the
-- witness. Left when the file no longer carries the expected line.
applyLocus :: FilePath -> Locus -> IO (Either Text SubjectChangeWitness)
applyLocus copyRoot locus = do
  let path = copyRoot <> "/" <> locusFile locus
  original <- TextIO.readFile path
  let lines' = Text.lines original
      index = locusLine locus - 1
  if index < 0 || index >= length lines' || lines' !! index /= locusBefore locus
    then pure (Left ("locus line mismatch at " <> Text.pack path <> ":" <> Text.pack (show (locusLine locus))))
    else do
      let rewritten = Text.unlines (take index lines' <> [locusAfter locus] <> drop (index + 1) lines')
      TextIO.writeFile path rewritten
      pure
        ( Right
            SubjectChangeWitness
              { witnessFile = locusFile locus
              , witnessLine = locusLine locus
              , witnessOperator = locusOperator locus
              , witnessBeforeDigest = sha256Hex original
              , witnessAfterDigest = sha256Hex rewritten
              , witnessDiff = "-" <> locusBefore locus <> "\n+" <> locusAfter locus
              }
        )

data MutantOutcome
  = Killed Text
  | Survived
  | Stillborn Text
  | Unapplied Text
  deriving (Eq, Ord, Show)

data KillTable = KillTable
  { killRows :: [(Locus, Maybe SubjectChangeWitness, MutantOutcome)]
  , killedCount :: Int
  , viableCount :: Int
  , stillbornCount :: Int
  , killRatioObserved :: Rational
  }
  deriving (Eq, Show)

killTable :: [(Locus, Maybe SubjectChangeWitness, MutantOutcome)] -> KillTable
killTable rows =
  KillTable
    { killRows = rows
    , killedCount = killed
    , viableCount = viable
    , stillbornCount = length [() | (_, _, Stillborn _) <- rows]
    , killRatioObserved = if viable == 0 then 0 else fromIntegral killed % fromIntegral viable
    }
 where
  killed = length [() | (_, _, Killed _) <- rows]
  viable = killed + length [() | (_, _, Survived) <- rows]

renderKillTable :: KillTable -> [Text]
renderKillTable table =
  [ Text.intercalate
      "\t"
      [ locusModule locus
      , Text.pack (locusFile locus) <> ":" <> Text.pack (show (locusLine locus))
      , renderOperator (locusOperator locus)
      , maybe "no-witness" (\w -> Text.take 12 (witnessBeforeDigest w) <> "->" <> Text.take 12 (witnessAfterDigest w)) witness
      , renderOutcome outcome
      ]
  | (locus, witness, outcome) <- killRows table
  ]
    <> [ "summary\tkilled=" <> showText (killedCount table) <> "\tviable=" <> showText (viableCount table) <> "\tstillborn=" <> showText (stillbornCount table)
       ]
 where
  renderOutcome outcome = case outcome of
    Killed stage -> "killed@" <> stage
    Survived -> "survived"
    Stillborn detail -> "stillborn:" <> Text.take 80 detail
    Unapplied detail -> "unapplied:" <> Text.take 80 detail
  showText :: Int -> Text
  showText = Text.pack . show
