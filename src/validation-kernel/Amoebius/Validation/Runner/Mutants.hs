{-# LANGUAGE OverloadedStrings #-}
-- | Generate mutations in captured source copies from a fixed catalogue and
module Amoebius.Validation.Runner.Mutants
  ( KillTable (..), Locus (..), MutantOutcome (..), Operator (..), SubjectChangeWitness (..), allOperators, applyLocus
  , enumerateLoci, isAttributed, truncateListLocus, killTable, renderKillTable, renderOperator, sampleLoci ) where
import Amoebius.Validation.Runner.Observer (sha256Hex)
import Amoebius.Validation.Runner.Hygiene (readSourceText)
import Data.Bits (xor, shiftL, shiftR)
import Data.Char (isAlphaNum, isDigit)
import Data.List (sortOn)
import Data.Maybe (listToMaybe)
import Data.Ratio ((%))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Word (Word64)
data Operator = ConstantFlip | BoundaryShift | BranchSwap | FieldDrop | ListTruncation
  deriving (Bounded, Enum, Eq, Ord, Show)
allOperators :: [Operator]
allOperators = [minBound .. maxBound]
-- module that owns none keeps the rule that any red row kills.
isAttributed :: [(Text, Text)] -> Text -> [Text] -> Bool
isAttributed owned moduleName reds = null mine || any (\row -> any (`Text.isPrefixOf` row) mine) reds
 where
  mine = [prefix | (owner, prefix) <- owned, owner == moduleName]
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
  { locusModule :: Text, locusFile :: FilePath, locusLine :: Int
  , locusOperator :: Operator, locusBefore :: Text, locusAfter :: Text } deriving (Eq, Ord, Show)
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
  eligible line = let trimmed = Text.stripStart line
    in not (Text.null trimmed || any (`Text.isPrefixOf` trimmed) ["--", "{-", "import ", "module ", "#"])
rewrite :: Operator -> Text -> Maybe Text
rewrite operator line = case operator of
  ConstantFlip -> constantFlip line
  BoundaryShift -> firstReplacement [(" < ", " <= "), (" <= ", " < "), (" > ", " >= "), (" >= ", " > ")] line
  BranchSwap -> firstReplacement [(" == ", " /= "), (" /= ", " == "), ("if not (", "if ("), (" not $ ", " ")] line
  FieldDrop -> fieldDrop line
  ListTruncation -> listTruncation line
firstReplacement :: [(Text, Text)] -> Text -> Maybe Text
firstReplacement replacements line = listToMaybe
  [before <> replacement <> Text.drop (Text.length needle) after
  | (needle, replacement) <- replacements, let (before, after) = Text.breakOn needle line, not (Text.null after)]
-- | Flip a Boolean or integer first, otherwise the first lexed string constant.
constantFlip :: Text -> Maybe Text
constantFlip line
  | Just rewritten <- firstReplacement [(" True", " False"), (" False", " True")] line = Just rewritten
  | otherwise = go "" line
 where
  go done rest
    | Text.null rest = stringConstant "" line
    | isDigit (Text.head rest) && boundaryBefore done =
        let (digits, after) = Text.span isDigit rest
         in if Text.null after || not (isAlphaNum (Text.head after) || Text.head after == '.')
              then case reads (Text.unpack digits) :: [(Integer, String)] of
                [(value, "")] -> Just (done <> Text.pack (show (value + 1)) <> after)
                _ -> Nothing
              else go (done <> digits) after
    | otherwise = go (Text.snoc done (Text.head rest)) (Text.tail rest)
  boundaryBefore done = Text.null done || not (isAlphaNum (Text.last done) || Text.last done `elem` ("_'." :: String))
  -- A comment or malformed token ends this bounded single-line operator.
  stringConstant before remaining
    | Text.take 2 (Text.stripStart remaining) `elem` ["--", "{-"] = Nothing
    | [(token, after)] <- lex (Text.unpack remaining), not (null token) =
        let consumed = Text.length remaining - length after
            prefix = before <> Text.take (consumed - length token) remaining
         in case reads token :: [(String, String)] of
              [(value, "")] | take 1 token == "\"" -> Just (prefix <> Text.pack (show (value <> "!")) <> Text.pack after)
              _ -> stringConstant (before <> Text.take consumed remaining) (Text.pack after)
    | otherwise = Nothing
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
-- | Remove the last element of a simple one-line term list, including its singleton.
listTruncation :: Text -> Maybe Text
listTruncation line = case Text.breakOnEnd "]" line of
  (closed, after) | not (Text.null closed), (prefix, body) <- Text.breakOnEnd "[" (Text.dropEnd 1 closed),
    not (Text.null prefix || Text.null (Text.strip body)), not (Text.any (`elem` ("[]\"" :: String)) body),
    not ("::" `Text.isInfixOf` prefix || ".." `Text.isInfixOf` body) ->
      Just (prefix <> Text.intercalate ", " (init (Text.splitOn ", " body)) <> "]" <> after)
  _ -> Nothing
truncateListLocus :: Locus -> Locus
truncateListLocus locus = case enumerateLoci (locusModule locus) (locusFile locus) ListTruncation (locusAfter locus) of
  next : _ -> truncateListLocus locus {locusAfter = locusAfter next}
  [] -> locus
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
seedValue :: Text -> Word64
seedValue seed = max 1 (Text.foldl' (\acc c -> acc * 31 + fromIntegral (fromEnum c)) 7 seed)
xorshift :: Word64 -> Word64
xorshift state0 =
  let state1 = state0 `xor` (state0 `shiftL` 13)
      state2 = state1 `xor` (state1 `shiftR` 7)
      state3 = state2 `xor` (state2 `shiftL` 17)
   in if state3 == 0 then 88172645463325252 else state3
-- | The proof that a mutant changed the subject: file, line, and the digests of
-- the source before and after the rewrite.
data SubjectChangeWitness = SubjectChangeWitness
  { witnessFile :: FilePath, witnessLine :: Int, witnessOperator :: Operator
  , witnessBeforeDigest :: Text, witnessAfterDigest :: Text, witnessDiff :: Text } deriving (Eq, Ord, Show)
-- | Rewrite one line of the file at the locus inside a copied tree, returning the
-- witness. Left when the file no longer carries the expected line.
applyLocus :: FilePath -> Locus -> IO (Either Text SubjectChangeWitness)
applyLocus copyRoot locus = do
  let path = copyRoot <> "/" <> locusFile locus
  original <- readSourceText path
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
              { witnessFile = locusFile locus, witnessLine = locusLine locus, witnessOperator = locusOperator locus
              , witnessBeforeDigest = sha256Hex original, witnessAfterDigest = sha256Hex rewritten
              , witnessDiff = "-" <> locusBefore locus <> "\n+" <> locusAfter locus }
        )
data MutantOutcome = Killed Text | Survived | Stillborn Text | Unapplied Text
  deriving (Eq, Ord, Show)
data KillTable = KillTable
  { killRows :: [(Locus, Maybe SubjectChangeWitness, MutantOutcome)]
  , killedCount :: Int, viableCount :: Int, stillbornCount :: Int, killRatioObserved :: Rational } deriving (Eq, Show)
killTable :: [(Locus, Maybe SubjectChangeWitness, MutantOutcome)] -> KillTable
killTable rows = KillTable
    { killRows = rows, killedCount = killed, viableCount = viable
    , stillbornCount = length [() | (_, _, Stillborn _) <- rows]
    , killRatioObserved = if viable == 0 then 0 else fromIntegral killed % fromIntegral viable
    }
 where
  killed = length [() | (_, _, Killed _) <- rows]
  viable = killed + length [() | (_, _, Survived) <- rows]
renderKillTable :: KillTable -> [Text]
renderKillTable table =
  [ Text.intercalate "\t"
      [ locusModule locus
      , Text.pack (locusFile locus) <> ":" <> Text.pack (show (locusLine locus))
      , renderOperator (locusOperator locus)
      , maybe "no-witness" (\w -> Text.take 12 (witnessBeforeDigest w) <> "->" <> Text.take 12 (witnessAfterDigest w)) witness
      , renderOutcome outcome ]
  | (locus, witness, outcome) <- killRows table ]
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
