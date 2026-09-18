{-# LANGUAGE OverloadedStrings #-}

-- | The generation-2 certification store (gate_runner_doctrine.md section 6). A
-- generation is the content address of the verifier; its directory holds the
-- signed seed record, the signed receipts, and nothing the agent identity can
-- write. Signing needs the issuer key, which only the human's root account can
-- read, and refuses whenever an agent environment marker is present (DL-0010).
module Amoebius.Validation.Custody.Store
  ( GenerationId
  , Receipt (..)
  , SeedRecord (..)
  , Store (..)
  , agentMarkers
  , agentMarkersPresent
  , defaultStore
  , generationDirectory
  , governanceDigest
  , issuerRefusal
  , latestGeneration
  , listGenerations
  , markersIn
  , parseReceipt
  , parseSeed
  , readReceipts
  , readSeed
  , readSigned
  , renderReceipt
  , renderSeed
  , verifierDigest
  , writeReceipt
  , writeSeed
  , writeSigned
  ) where

import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Validation.Runner.Observer (sha256Hex)
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM)
import Crypto.Error (CryptoFailable (..))
import Crypto.Hash.SHA256 qualified as SHA256
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (sort)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getExecutablePath, lookupEnv)
import System.FilePath (takeExtension, (</>))
import System.Posix.User (getEffectiveUserID)

type GenerationId = Text

newtype Store = Store {storeRoot :: FilePath}
  deriving (Eq, Show)

defaultStore :: Store
defaultStore = Store "/var/lib/amoebius-certification"

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

data SeedRecord = SeedRecord
  { seedGeneration :: GenerationId
  , seedDecision :: Text
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
    [ ("record", "amoebius-certification-seed.v2")
    , ("generation", seedGeneration seed)
    , ("decision", seedDecision seed)
    , ("verifier-digest", seedVerifierDigest seed)
    , ("governance-digest", seedGovernanceDigest seed)
    , ("status-postimage", seedStatusPostimage seed)
    , ("tree-commit", seedTreeCommit seed)
    , ("issued-at", seedIssuedAt seed)
    ]

parseSeed :: Text -> Either Text SeedRecord
parseSeed contents = do
  let fields = parseFields contents
      field key = maybe (Left ("seed record lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-certification-seed.v2" then Left ("unknown seed record: " <> record) else Right ()
  SeedRecord <$> field "generation" <*> field "decision" <*> field "verifier-digest" <*> field "governance-digest" <*> field "status-postimage" <*> field "tree-commit" <*> field "issued-at"

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
    <*> field "verifier-digest"
    <*> field "governance-digest"
    <*> field "status-postimage"
    <*> field "tree-commit"
    <*> pure [value | ("witness", value) <- fields]
    <*> pure ((,) <$> lookup "reset-validator-gap" fields <*> lookup "reset-product-gap" fields)
    <*> pure (lookup "operator-demonstration" fields)
    <*> field "issued-at"

-- * Signing

issuerKeyPath, issuerPublicPath :: Store -> FilePath
issuerKeyPath store = storeRoot store </> "issuer.key"
issuerPublicPath store = storeRoot store </> "issuer.pub"

-- | Sign a payload with the issuer key and write payload and signature.
writeSigned :: Store -> FilePath -> Text -> IO (Either Text ())
writeSigned store path payload = do
  keyBytes <- try (ByteString.readFile (issuerKeyPath store)) :: IO (Either IOException ByteString)
  case keyBytes of
    Left problem -> pure (Left ("issuer key unreadable: " <> Text.pack (show problem)))
    Right seedBytes -> case Ed25519.secretKey seedBytes of
      CryptoFailed _ -> pure (Left "issuer key is not a valid Ed25519 seed")
      CryptoPassed secret -> do
        let public = Ed25519.toPublic secret
            bytes = TextEncoding.encodeUtf8 payload
            signature = convert (Ed25519.sign secret public bytes) :: ByteString
        ByteString.writeFile path bytes
        ByteString.writeFile (path <> ".sig") signature
        ByteString.writeFile (issuerPublicPath store) (convert public)
        pure (Right ())

-- | Read a payload and verify its signature against the issuer public key.
readSigned :: Store -> FilePath -> IO (Either Text Text)
readSigned store path = do
  attempt <- try ((,,) <$> ByteString.readFile path <*> ByteString.readFile (path <> ".sig") <*> ByteString.readFile (issuerPublicPath store)) :: IO (Either IOException (ByteString, ByteString, ByteString))
  pure $ case attempt of
    Left problem -> Left ("signed record unreadable: " <> Text.pack (show problem))
    Right (payload, signatureBytes, publicBytes) -> case (Ed25519.publicKey publicBytes, Ed25519.signature signatureBytes) of
      (CryptoPassed public, CryptoPassed signature)
        | Ed25519.verify public payload signature -> Right (TextEncoding.decodeUtf8 payload)
        | otherwise -> Left ("signature does not verify: " <> Text.pack path)
      _ -> Left ("malformed public key or signature for " <> Text.pack path)

writeSeed :: Store -> SeedRecord -> IO (Either Text ())
writeSeed store seed = do
  let directory = generationDirectory store (seedGeneration seed)
  createDirectoryIfMissing True (directory </> "receipts")
  writeSigned store (directory </> "seed.tsv") (renderSeed seed)

readSeed :: Store -> GenerationId -> IO (Either Text SeedRecord)
readSeed store generation = do
  signed <- readSigned store (generationDirectory store generation </> "seed.tsv")
  pure (signed >>= parseSeed)

-- | A pass receipt is @phase-NN.tsv@; a reset receipt is @reset-phase-NN-<issued>.tsv@
-- so a later pass never overwrites the reset that preceded it.
writeReceipt :: Store -> Receipt -> IO (Either Text ())
writeReceipt store receipt =
  writeSigned store (generationDirectory store (receiptGeneration receipt) </> "receipts" </> name) (renderReceipt receipt)
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
        signed <- readSigned store (directory </> name)
        pure (either (const Nothing) (either (const Nothing) Just . parseReceipt) signed)
      pure (mapMaybe id parsed)

-- | Generations present in the store, by directory name.
listGenerations :: Store -> IO [FilePath]
listGenerations store = do
  exists <- doesDirectoryExist (storeRoot store)
  if not exists
    then pure []
    else do
      names <- listDirectory (storeRoot store)
      sort <$> filterM (\name -> doesFileExist (storeRoot store </> name </> "seed.tsv")) [name | name <- names, "generation-" `Text.isPrefixOf` Text.pack name]

-- | The generation whose seed names the running verifier, if any.
latestGeneration :: Store -> Text -> IO (Maybe SeedRecord)
latestGeneration store verifier = do
  names <- listGenerations store
  seeds <- forM names $ \name -> do
    signed <- readSigned store (storeRoot store </> name </> "seed.tsv")
    pure (either (const Nothing) (either (const Nothing) Just . parseSeed) signed)
  pure (case [seed | Just seed <- seeds, seedVerifierDigest seed == verifier] of
    (seed : _) -> Just seed
    [] -> Nothing)

-- * The issuer context

agentMarkers :: [String]
agentMarkers = ["CLAUDECODE", "CLAUDE_CODE_SESSION_ID", "CLAUDE_CODE_CHILD_SESSION", "CLAUDE_PID", "AI_AGENT"]

agentMarkersPresent :: IO [Text]
agentMarkersPresent = do
  values <- mapM lookupEnv agentMarkers
  pure (markersIn [(name, value) | (name, Just value) <- zip agentMarkers values])

-- | The markers present in an environment; pure so a suite can state it.
markersIn :: [(String, String)] -> [Text]
markersIn environment = [Text.pack name | name <- agentMarkers, name `elem` map fst environment]

-- | Why this process may not issue: not root, or an agent session.
issuerRefusal :: IO (Maybe Text)
issuerRefusal = do
  markers <- agentMarkersPresent
  uid <- getEffectiveUserID
  pure $ case (markers, uid) of
    (present@(_ : _), _) -> Just ("ISSUER-AGENT-SESSION: " <> Text.intercalate "," present)
    ([], 0) -> Nothing
    ([], _) -> Just "ISSUER-NOT-ROOT"

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]

_unusedTextIO :: FilePath -> IO Text
_unusedTextIO = TextIO.readFile
