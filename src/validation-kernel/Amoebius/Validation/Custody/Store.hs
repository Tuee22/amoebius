{-# LANGUAGE OverloadedStrings #-}

-- | The generation-2 certification store (gate_runner_doctrine.md section 6;
-- DL-0013). A generation is the content address of the verifier; its directory
-- beneath the ignored @.build/certification@ tree holds the generation record and
-- the receipts. A record carries no signature: its authority is that any later run
-- re-derives its reproducible digest. The @.sha256@ sidecar beside every record
-- detects corruption, nothing more.
module Amoebius.Validation.Custody.Store
  ( GenerationId
  , Receipt (..)
  , SeedRecord (..)
  , Store (..)
  , defaultStore
  , generationDirectory
  , governanceDigest
  , latestGeneration
  , listGenerations
  , parseReceipt
  , parseSeed
  , readReceipts
  , readRecord
  , readSeed
  , renderReceipt
  , renderSeed
  , verifierDigest
  , writeReceipt
  , writeRecord
  , writeSeed
  ) where

import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Validation.Runner.Observer (sha256Hex)
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (sort)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getExecutablePath)
import System.FilePath (takeExtension, (</>))

type GenerationId = Text

newtype Store = Store {storeRoot :: FilePath}
  deriving (Eq, Show)

defaultStore :: Store
defaultStore = Store ".build/certification"

generationDirectory :: Store -> GenerationId -> FilePath
generationDirectory store generation = storeRoot store </> ("generation-" <> Text.unpack (Text.take 16 generation))

-- | The verifier's content address: the SHA-256 of the running executable.
verifierDigest :: IO Text
verifierDigest = do
  path <- getExecutablePath
  bytes <- ByteString.readFile path
  pure (hex (SHA256.hash bytes))

-- | The governance digest: the frozen baseline rows in order.
governanceDigest :: Text
governanceDigest =
  sha256Hex
    ( Text.unlines
        [ Text.pack (Decisions.frozenPath row) <> "\t" <> Decisions.frozenDigest row <> "\t" <> Decisions.renderDecisionId (Decisions.frozenDecision row)
        | row <- Decisions.frozenBaseline
        ]
    )

-- | The generation record: written by the first accept, replay, reset, or demo
-- under a verifier.
data SeedRecord = SeedRecord
  { seedGeneration :: GenerationId
  , seedEnteredBy :: Text
  , seedVerifierDigest :: Text
  , seedGovernanceDigest :: Text
  , seedStatusPostimage :: Text
  , seedTreeCommit :: Text
  , seedIssuedAt :: Text
  }
  deriving (Eq, Show)

data Receipt = Receipt
  { receiptPhase :: Int
  , receiptCapability :: Text
  , receiptGeneration :: GenerationId
  , receiptSpecDigest :: Text
  , receiptSpecRendered :: Text
  , receiptCandidateDigest :: Text
  , receiptKillTableDigest :: Text
  , receiptClosureDigest :: Text
  , receiptReproducible :: Text
  , receiptVerifierDigest :: Text
  , receiptGovernanceDigest :: Text
  , receiptStatusPostimage :: Text
  , receiptTreeCommit :: Text
  , receiptWitnesses :: [Text]
  , receiptResetCause :: Maybe (Text, Text)
  , receiptDemonstration :: Maybe Text
  , receiptIssuedAt :: Text
  }
  deriving (Eq, Show)

renderFields :: [(Text, Text)] -> Text
renderFields fields = Text.unlines [key <> "\t" <> Text.replace "\n" "\\n" value | (key, value) <- fields]

parseFields :: Text -> [(Text, Text)]
parseFields contents = [(key, Text.replace "\\n" "\n" (Text.intercalate "\t" rest)) | line <- Text.lines contents, (key : rest) <- [Text.splitOn "\t" line]]

renderSeed :: SeedRecord -> Text
renderSeed seed =
  renderFields
    [ ("record", "amoebius-certification-generation.v2")
    , ("generation", seedGeneration seed)
    , ("entered-by", seedEnteredBy seed)
    , ("verifier-digest", seedVerifierDigest seed)
    , ("governance-digest", seedGovernanceDigest seed)
    , ("status-postimage", seedStatusPostimage seed)
    , ("tree-commit", seedTreeCommit seed)
    , ("issued-at", seedIssuedAt seed)
    ]

parseSeed :: Text -> Either Text SeedRecord
parseSeed contents = do
  let fields = parseFields contents
      field key = maybe (Left ("generation record lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-certification-generation.v2" then Left ("unknown generation record: " <> record) else Right ()
  SeedRecord <$> field "generation" <*> field "entered-by" <*> field "verifier-digest" <*> field "governance-digest" <*> field "status-postimage" <*> field "tree-commit" <*> field "issued-at"

renderReceipt :: Receipt -> Text
renderReceipt receipt =
  renderFields
    ( [ ("record", "amoebius-phase-receipt.v2")
      , ("phase", Text.pack (show (receiptPhase receipt)))
      , ("capability", receiptCapability receipt)
      , ("generation", receiptGeneration receipt)
      , ("spec-digest", receiptSpecDigest receipt)
      , ("spec", receiptSpecRendered receipt)
      , ("candidate-digest", receiptCandidateDigest receipt)
      , ("kill-table-digest", receiptKillTableDigest receipt)
      , ("closure-digest", receiptClosureDigest receipt)
      , ("reproducible-digest", receiptReproducible receipt)
      , ("verifier-digest", receiptVerifierDigest receipt)
      , ("governance-digest", receiptGovernanceDigest receipt)
      , ("status-postimage", receiptStatusPostimage receipt)
      , ("tree-commit", receiptTreeCommit receipt)
      , ("issued-at", receiptIssuedAt receipt)
      ]
        <> [("witness", witness) | witness <- receiptWitnesses receipt]
        <> maybe [] (\(gap, product) -> [("reset-validator-gap", gap), ("reset-product-gap", product)]) (receiptResetCause receipt)
        <> maybe [] (\demo -> [("operator-demonstration", demo)]) (receiptDemonstration receipt)
    )

parseReceipt :: Text -> Either Text Receipt
parseReceipt contents = do
  let fields = parseFields contents
      field key = maybe (Left ("receipt lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-phase-receipt.v2" then Left ("unknown receipt record: " <> record) else Right ()
  phaseText <- field "phase"
  phase <- case reads (Text.unpack phaseText) of
    [(value, "")] -> Right value
    _ -> Left "receipt phase is not an ordinal"
  Receipt phase
    <$> field "capability"
    <*> field "generation"
    <*> field "spec-digest"
    <*> field "spec"
    <*> field "candidate-digest"
    <*> field "kill-table-digest"
    <*> field "closure-digest"
    <*> field "reproducible-digest"
    <*> field "verifier-digest"
    <*> field "governance-digest"
    <*> field "status-postimage"
    <*> field "tree-commit"
    <*> pure [value | ("witness", value) <- fields]
    <*> pure ((,) <$> lookup "reset-validator-gap" fields <*> lookup "reset-product-gap" fields)
    <*> pure (lookup "operator-demonstration" fields)
    <*> field "issued-at"

-- * Records

-- | Write a record and its digest sidecar.
writeRecord :: FilePath -> Text -> IO (Either Text ())
writeRecord path payload = do
  attempt <- try (do
    let bytes = TextEncoding.encodeUtf8 payload
    ByteString.writeFile path bytes
    ByteString.writeFile (path <> ".sha256") (TextEncoding.encodeUtf8 (hex (SHA256.hash bytes)))) :: IO (Either IOException ())
  pure (either (\problem -> Left ("record not written: " <> Text.pack (show problem))) Right attempt)

-- | Read a record and refuse it when its sidecar digest does not match.
readRecord :: FilePath -> IO (Either Text Text)
readRecord path = do
  attempt <- try ((,) <$> ByteString.readFile path <*> ByteString.readFile (path <> ".sha256")) :: IO (Either IOException (ByteString, ByteString))
  pure $ case attempt of
    Left problem -> Left ("record unreadable: " <> Text.pack (show problem))
    Right (payload, sidecar)
      | TextEncoding.decodeUtf8 sidecar == hex (SHA256.hash payload) -> Right (TextEncoding.decodeUtf8 payload)
      | otherwise -> Left ("record digest does not match its sidecar: " <> Text.pack path)

writeSeed :: Store -> SeedRecord -> IO (Either Text ())
writeSeed store seed = do
  let directory = generationDirectory store (seedGeneration seed)
  createDirectoryIfMissing True (directory </> "receipts")
  writeRecord (directory </> "generation.tsv") (renderSeed seed)

readSeed :: Store -> GenerationId -> IO (Either Text SeedRecord)
readSeed store generation = do
  record <- readRecord (generationDirectory store generation </> "generation.tsv")
  pure (record >>= parseSeed)

-- | A pass receipt is @phase-NN.tsv@; a reset receipt is @reset-phase-NN-<issued>.tsv@
-- so a later pass never overwrites the reset that preceded it.
writeReceipt :: Store -> Receipt -> IO (Either Text ())
writeReceipt store receipt = do
  let directory = generationDirectory store (receiptGeneration receipt) </> "receipts"
  createDirectoryIfMissing True directory
  writeRecord (directory </> name) (renderReceipt receipt)
 where
  pad n = let s = show n in if length s < 2 then '0' : s else s
  stamp = Text.unpack (Text.filter (\c -> c /= ' ' && c /= ':') (receiptIssuedAt receipt))
  name = case receiptResetCause receipt of
    Nothing -> "phase-" <> pad (receiptPhase receipt) <> ".tsv"
    Just _ -> "reset-phase-" <> pad (receiptPhase receipt) <> "-" <> stamp <> ".tsv"

readReceipts :: Store -> GenerationId -> IO [Receipt]
readReceipts store generation = do
  let directory = generationDirectory store generation </> "receipts"
  exists <- doesDirectoryExist directory
  if not exists
    then pure []
    else do
      names <- sort . filter ((== ".tsv") . takeExtension) <$> listDirectory directory
      parsed <- forM names $ \name -> do
        record <- readRecord (directory </> name)
        pure (either (const Nothing) (either (const Nothing) Just . parseReceipt) record)
      pure (mapMaybe id parsed)

-- | Generations present in the store, by directory name.
listGenerations :: Store -> IO [FilePath]
listGenerations store = do
  exists <- doesDirectoryExist (storeRoot store)
  if not exists
    then pure []
    else do
      names <- listDirectory (storeRoot store)
      sort <$> filterM (\name -> doesFileExist (storeRoot store </> name </> "generation.tsv")) [name | name <- names, "generation-" `Text.isPrefixOf` Text.pack name]

-- | The generation whose record names the running verifier, if any.
latestGeneration :: Store -> Text -> IO (Maybe SeedRecord)
latestGeneration store verifier = do
  names <- listGenerations store
  seeds <- forM names $ \name -> do
    record <- readRecord (storeRoot store </> name </> "generation.tsv")
    pure (either (const Nothing) (either (const Nothing) Just . parseSeed) record)
  pure (case [seed | Just seed <- seeds, seedVerifierDigest seed == verifier] of
    (seed : _) -> Just seed
    [] -> Nothing)

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]
