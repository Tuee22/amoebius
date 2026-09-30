{-# LANGUAGE OverloadedStrings #-}
-- | Transient certification state and immutable, tracked receipt bundles.
module Amoebius.Validation.Custody.Store
  ( GenerationId, Receipt (..), SeedRecord (..), Store (..)
  , archivedBundlePath, auditArchivedInventory, defaultStore, generationDirectory, governanceDigest
  , latestGeneration, listGenerations, parseReceipt, parseSeed
  , readArchivedBundles, readArchivedReceipts, readCurrentArchivedBundles, readReceipts, readRecord, readSeed
  , renderReceipt, renderSeed, verifierDigest
  , writeArchivedReceipt, writeReceipt, writeRecord, writeReplayVoid, writeSeed ) where
import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Plan.ValidationRecordPath (isValidationRecordPath, validationRecordRoot)
import Amoebius.Validation.Runner.Observer (observe, runExit, runStdout, sha256Hex)
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (nub, sort)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory (createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, doesPathExist, getFileSize, listDirectory, makeAbsolute, pathIsSymbolicLink, removePathForcibly, renameDirectory, renameFile)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..))
import System.FilePath (makeRelative, takeDirectory, takeExtension, takeFileName, (</>))
import System.IO.Error (isDoesNotExistError)
type GenerationId = Text
newtype Store = Store {storeRoot :: FilePath} deriving (Eq, Show)
defaultStore :: Store
defaultStore = Store ".build/certification"
generationDirectory :: Store -> GenerationId -> FilePath
generationDirectory store generation = storeRoot store </> ("generation-" <> Text.unpack (Text.take 16 generation))
verifierDigest :: IO Text
verifierDigest = hex . SHA256.hash <$> (getExecutablePath >>= ByteString.readFile)
governanceDigest :: Text
governanceDigest = sha256Hex (Text.unlines [Text.pack (Decisions.frozenPath row) <> "\t" <> Decisions.frozenDigest row <> "\t" <> Decisions.renderDecisionId (Decisions.frozenDecision row) | row <- Decisions.frozenBaseline])
data SeedRecord = SeedRecord
  { seedGeneration :: GenerationId, seedEnteredBy :: Text, seedVerifierDigest :: Text, seedGovernanceDigest :: Text
  , seedStatusPostimage :: Text, seedTreeCommit :: Text, seedIssuedAt :: Text } deriving (Eq, Show)
data Receipt = Receipt
  { receiptPhase :: Int, receiptCapability :: Text, receiptGeneration :: GenerationId, receiptSpecDigest :: Text
  , receiptSpecRendered :: Text, receiptCandidateDigest :: Text, receiptKillTableDigest :: Text, receiptClosureDigest :: Text
  , receiptReproducible :: Text, receiptVerifierDigest :: Text, receiptGovernanceDigest :: Text, receiptStatusPostimage :: Text
  , receiptTreeCommit :: Text, receiptWitnesses :: [Text], receiptResetCause :: Maybe (Text, Text), receiptDemonstration :: Maybe Text
  , receiptIssuedAt :: Text } deriving (Eq, Show)
renderFields :: [(Text, Text)] -> Text
renderFields fields = Text.unlines [key <> "\t" <> Text.concatMap escape value | (key, value) <- fields]
 where
  escape '\\' = "\\\\"
  escape '\n' = "\\n"
  escape '\t' = "\\t"
  escape c = Text.singleton c
parseFields :: Text -> [(Text, Text)]
parseFields contents = [(key, Text.pack (unescape (Text.unpack (Text.intercalate "\t" rest)))) | line <- Text.lines contents, (key : rest) <- [Text.splitOn "\t" line]]
 where
  unescape ('\\' : 'n' : xs) = '\n' : unescape xs
  unescape ('\\' : 't' : xs) = '\t' : unescape xs
  unescape ('\\' : '\\' : xs) = '\\' : unescape xs
  unescape (x : xs) = x : unescape xs
  unescape [] = []
renderSeed :: SeedRecord -> Text
renderSeed seed = renderFields
  [ ("record", "amoebius-certification-generation.v2"), ("generation", seedGeneration seed), ("entered-by", seedEnteredBy seed), ("verifier-digest", seedVerifierDigest seed)
  , ("governance-digest", seedGovernanceDigest seed), ("status-postimage", seedStatusPostimage seed), ("tree-commit", seedTreeCommit seed), ("issued-at", seedIssuedAt seed) ]
parseSeed :: Text -> Either Text SeedRecord
parseSeed contents = do
  let fields = parseFields contents
      field key = maybe (Left ("generation record lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-certification-generation.v2" then Left ("unknown generation record: " <> record) else Right ()
  SeedRecord <$> field "generation" <*> field "entered-by" <*> field "verifier-digest" <*> field "governance-digest" <*> field "status-postimage" <*> field "tree-commit" <*> field "issued-at"
renderReceipt :: Receipt -> Text
renderReceipt receipt = renderFields
  ( [ ("record", "amoebius-phase-receipt.v2"), ("phase", Text.pack (show (receiptPhase receipt))), ("capability", receiptCapability receipt), ("generation", receiptGeneration receipt)
    , ("spec-digest", receiptSpecDigest receipt), ("spec", receiptSpecRendered receipt), ("candidate-digest", receiptCandidateDigest receipt), ("kill-table-digest", receiptKillTableDigest receipt)
    , ("closure-digest", receiptClosureDigest receipt), ("reproducible-digest", receiptReproducible receipt), ("verifier-digest", receiptVerifierDigest receipt), ("governance-digest", receiptGovernanceDigest receipt)
    , ("status-postimage", receiptStatusPostimage receipt), ("tree-commit", receiptTreeCommit receipt), ("issued-at", receiptIssuedAt receipt) ]
      <> [("witness", witness) | witness <- receiptWitnesses receipt]
      <> maybe [] (\(gap, product) -> [("reset-validator-gap", gap), ("reset-product-gap", product)]) (receiptResetCause receipt)
      <> maybe [] (\demo -> [("operator-demonstration", demo)]) (receiptDemonstration receipt) )
parseReceipt :: Text -> Either Text Receipt
parseReceipt contents = do
  let fields = parseFields contents
      field key = maybe (Left ("receipt lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-phase-receipt.v2" then Left ("unknown receipt record: " <> record) else Right ()
  phaseText <- field "phase"
  phase <- case reads (Text.unpack phaseText) of [(value, "")] -> Right value; _ -> Left "receipt phase is not an ordinal"
  Receipt phase <$> field "capability" <*> field "generation" <*> field "spec-digest" <*> field "spec"
    <*> field "candidate-digest" <*> field "kill-table-digest" <*> field "closure-digest"
    <*> field "reproducible-digest" <*> field "verifier-digest" <*> field "governance-digest"
    <*> field "status-postimage" <*> field "tree-commit"
    <*> pure [value | ("witness", value) <- fields]
    <*> pure ((,) <$> lookup "reset-validator-gap" fields <*> lookup "reset-product-gap" fields)
    <*> pure (lookup "operator-demonstration" fields) <*> field "issued-at"
writeRecord :: FilePath -> Text -> IO (Either Text ())
writeRecord path payload = do
  attempt <- try (do
    let bytes = TextEncoding.encodeUtf8 payload
    ByteString.writeFile path bytes
    ByteString.writeFile (path <> ".sha256") (TextEncoding.encodeUtf8 (hex (SHA256.hash bytes)))) :: IO (Either IOException ())
  pure (either (\problem -> Left ("record not written: " <> Text.pack (show problem))) Right attempt)
readRecord :: FilePath -> IO (Either Text Text)
readRecord path = do
  attempt <- try ((,) <$> ByteString.readFile path <*> ByteString.readFile (path <> ".sha256")) :: IO (Either IOException (ByteString, ByteString))
  pure $ case attempt of
    Left problem -> Left ("record unreadable: " <> Text.pack (show problem))
    Right (payload, sidecar) -> case (TextEncoding.decodeUtf8' payload, TextEncoding.decodeUtf8' sidecar) of
      (Right value, Right digest) | digest == hex (SHA256.hash payload) -> Right value
      _ -> Left ("record digest or UTF-8 is invalid: " <> Text.pack path)
writeSeed :: Store -> SeedRecord -> IO (Either Text ())
writeSeed store seed = do
  let directory = generationDirectory store (seedGeneration seed)
  createDirectoryIfMissing True (directory </> "receipts") >> writeRecord (directory </> "generation.tsv") (renderSeed seed)
readSeed :: Store -> GenerationId -> IO (Either Text SeedRecord)
readSeed store generation = fmap (>>= parseSeed) (readRecord (generationDirectory store generation </> "generation.tsv"))
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
  if not exists then pure [] else do
    names <- sort . filter ((== ".tsv") . takeExtension) <$> listDirectory directory
    parsed <- forM names $ \name -> fmap (either (const Nothing) (either (const Nothing) Just . parseReceipt)) (readRecord (directory </> name))
    pure (mapMaybe id parsed)
listGenerations :: Store -> IO [FilePath]
listGenerations store = do
  exists <- doesDirectoryExist (storeRoot store)
  if not exists then pure [] else do
    names <- listDirectory (storeRoot store)
    sort <$> filterM (\name -> doesFileExist (storeRoot store </> name </> "generation.tsv")) [name | name <- names, "generation-" `Text.isPrefixOf` Text.pack name]
latestGeneration :: Store -> Text -> IO (Maybe SeedRecord)
latestGeneration store verifier = do
  names <- listGenerations store
  seeds <- forM names $ \name -> fmap (either (const Nothing) (either (const Nothing) Just . parseSeed)) (readRecord (storeRoot store </> name </> "generation.tsv"))
  pure (case [seed | Just seed <- seeds, seedVerifierDigest seed == verifier] of (seed : _) -> Just seed; [] -> Nothing)
-- The five bounded evidence values are Haskell renderings, never executable inputs.
archiveEvidenceNames :: [FilePath]
archiveEvidenceNames = ["candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]
digestShape :: Text -> Bool
digestShape value = Text.length value == 64 && Text.all (\c -> c >= '0' && c <= '9' || c >= 'a' && c <= 'f') value
candidateMatches :: Receipt -> Text -> Bool
candidateMatches receipt candidate = take 2 (Text.lines candidate) ==
  [ "candidate\tphase=" <> Text.pack (show (receiptPhase receipt)) <> "\tcapability=" <> receiptCapability receipt
  , "spec-digest\t" <> receiptSpecDigest receipt ]
bundleDigest :: Receipt -> [(FilePath, Text)] -> Text
bundleDigest receipt evidence = sha256Hex (Text.unlines (("receipt.tsv\t" <> sha256Hex (renderReceipt receipt)) : [Text.pack name <> "\t" <> sha256Hex body | (name, body) <- sort evidence]))
archiveName :: Receipt -> [(FilePath, Text)] -> FilePath
archiveName receipt evidence = "phase-" <> pad (receiptPhase receipt) <> "-" <> Text.unpack (receiptReproducible receipt) <> "-" <> Text.unpack (bundleDigest receipt evidence)
 where
  pad n = let s = show n in if length s < 2 then '0' : s else s
archivedBundlePath :: FilePath -> Receipt -> [(FilePath, Text)] -> FilePath
archivedBundlePath root receipt evidence = generationDirectory (Store root) (receiptGeneration receipt) </> "receipts" </> archiveName receipt evidence
readEvidence :: FilePath -> IO (Either Text Text)
readEvidence path = do
  attempt <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
  pure $ case attempt of
    Left problem -> Left ("archive evidence unreadable: " <> Text.pack (show problem))
    Right bytes -> either (const (Left ("archive evidence is not UTF-8: " <> Text.pack path))) Right (TextEncoding.decodeUtf8' bytes)
hasSymlink :: [FilePath] -> IO Bool
hasSymlink paths = or <$> mapM check paths
 where
  check path = do
    result <- try (pathIsSymbolicLink path) :: IO (Either IOException Bool)
    pure (either (not . isDoesNotExistError) id result)
-- | Publish a complete acceptance bundle with a single directory rename.
-- A conflicting content address, including a partially written one, is refused.
writeArchivedReceipt :: FilePath -> Receipt -> [(FilePath, Text)] -> IO (Either Text FilePath)
writeArchivedReceipt root receipt evidence
  | not (digestShape (receiptGeneration receipt) && digestShape (receiptReproducible receipt) && receiptGeneration receipt == receiptVerifierDigest receipt && receiptPhase receipt >= 0) = pure (Left "archive receipt identity is invalid")
  | not (digestShape (receiptStatusPostimage receipt)) = pure (Left "archive status postimage is not a SHA-256 digest")
  | sort (map fst evidence) /= sort archiveEvidenceNames = pure (Left "archive evidence names are incomplete or repeated")
  | any ((> 16 * 1024 * 1024) . ByteString.length . TextEncoding.encodeUtf8) (renderReceipt receipt : map snd evidence) = pure (Left "archive record exceeds the 16 MiB per-record limit")
  | sha256Hex (value "candidate.tsv") /= receiptCandidateDigest receipt || sha256Hex (value "kill-table.tsv") /= receiptKillTableDigest receipt = pure (Left "archive evidence digest does not match receipt")
  | not (candidateMatches receipt (value "candidate.tsv")) = pure (Left "archive candidate identity does not match receipt")
  | not (all (isValidationRecordPath . (archivedBundlePath validationRecordRoot receipt evidence </>)) ("receipt.tsv.sha256" : "receipt.tsv" : archiveEvidenceNames)) = pure (Left "archive path does not have the admitted phase and digest shape")
  | otherwise = do
      let target = archivedBundlePath root receipt evidence
          staging = target <> ".pending"
          generationPath = generationDirectory (Store root) (receiptGeneration receipt)
          receiptsPath = generationPath </> "receipts"
      linked <- hasSymlink [root, generationPath, receiptsPath, target, staging]
      exists <- doesPathExist target
      pending <- doesPathExist staging
      earlier <- readArchivedBundles root (receiptGeneration receipt)
      let stale = either (const True) (any (\(old, _) -> receiptPhase old == receiptPhase receipt && receiptIssuedAt old >= receiptIssuedAt receipt)) earlier
      if linked then pure (Left "archive path contains a symbolic link")
      else if pending then pure (Left "archive has an unfinished pending bundle")
      else if not exists && stale then pure (Left "archive receipt issued-at is not newer than the existing phase bundle")
      else if exists then do
          prior <- readBundle target (receiptGeneration receipt)
          pure $ case prior of
            Right (old, rows) | old == receipt && sort rows == sort evidence -> Right target
            _ -> Left ("archive content address already exists with different or invalid evidence: " <> Text.pack target)
      else do
          prepared <- try (createDirectoryIfMissing True receiptsPath >> createDirectory staging) :: IO (Either IOException ())
          case prepared of
            Left problem -> pure (Left ("archive staging unavailable: " <> Text.pack (show problem)))
            Right () -> do
              receiptWritten <- writeRecord (staging </> "receipt.tsv") (renderReceipt receipt)
              evidenceWritten <- try (mapM_ (\(name, payload) -> ByteString.writeFile (staging </> name) (TextEncoding.encodeUtf8 payload)) evidence) :: IO (Either IOException ())
              checked <- case (receiptWritten, evidenceWritten) of
                (Right (), Right ()) -> do
                  savedReceipt <- readRecord (staging </> "receipt.tsv")
                  savedEvidence <- mapM (\(name, payload) -> fmap (fmap (== payload)) (readEvidence (staging </> name))) evidence
                  pure $ if savedReceipt == Right (renderReceipt receipt) && sequence savedEvidence == Right (replicate (length evidence) True) then Right () else Left "archive staging verification failed"
                (Left problem, _) -> pure (Left problem)
                (_, Left problem) -> pure (Left ("archive evidence not written: " <> Text.pack (show problem)))
              published <- case checked of
                Left problem -> pure (Left problem)
                Right () -> do
                  moved <- try (renameDirectory staging target) :: IO (Either IOException ())
                  pure (either (Left . Text.pack . show) (const (Right target)) moved)
              case published of
                Right path -> pure (Right path)
                Left problem -> do
                  _ <- try (removePathForcibly staging) :: IO (Either IOException ())
                  pure (Left problem)
 where
  value name = maybe "" id (lookup name evidence)
-- | Every record, sidecar, path key, and evidence digest must be valid.
readBundle :: FilePath -> GenerationId -> IO (Either Text (Receipt, [(FilePath, Text)]))
readBundle path generation = do
  pathLinked <- hasSymlink [path]
  listed <- if pathLinked then pure (Left "archive bundle is a symbolic link") else do
    attempt <- try (listDirectory path) :: IO (Either IOException [FilePath])
    pure (either (Left . ("archive bundle unreadable: " <>) . Text.pack . show) Right attempt)
  case listed of
    Left problem -> pure (Left problem)
    Right names
      | sort names /= sort ("receipt.tsv" : "receipt.tsv.sha256" : archiveEvidenceNames) -> pure (Left ("archive bundle has missing or extra records: " <> Text.pack path))
      | otherwise -> do
          linked <- hasSymlink (path : [path </> name | name <- names])
          if linked then pure (Left "archive bundle contains a symbolic link") else do
            sizes <- try (mapM (getFileSize . (path </>)) names) :: IO (Either IOException [Integer])
            if either (const True) (any (> 16 * 1024 * 1024)) sizes then pure (Left "archive record is unreadable or exceeds 16 MiB") else do
              receiptValue <- readRecord (path </> "receipt.tsv")
              values <- mapM (\name -> fmap (fmap ((,) name)) (readEvidence (path </> name))) archiveEvidenceNames
              pure $ do
                raw <- receiptValue
                evidence <- sequence values
                receipt <- parseReceipt raw
                if renderReceipt receipt /= raw || receiptGeneration receipt /= generation || receiptVerifierDigest receipt /= generation || not (digestShape generation && digestShape (receiptReproducible receipt) && digestShape (receiptStatusPostimage receipt)) || archiveName receipt evidence /= takeFileName path || not (isValidationRecordPath (archivedBundlePath validationRecordRoot receipt evidence </> "receipt.tsv"))
                  then Left ("archive receipt identity or canonical form is invalid: " <> Text.pack path)
                  else if sha256Hex (value "candidate.tsv" evidence) /= receiptCandidateDigest receipt || sha256Hex (value "kill-table.tsv" evidence) /= receiptKillTableDigest receipt || not (candidateMatches receipt (value "candidate.tsv" evidence))
                    then Left ("archive evidence digest does not match receipt: " <> Text.pack path)
                    else Right (receipt, evidence)
 where
  value name rows = maybe "" id (lookup name rows)
-- | Missing generation means no evidence; malformed present evidence is fatal.
readArchivedBundles :: FilePath -> GenerationId -> IO (Either Text [(Receipt, FilePath)])
readArchivedBundles root generation
  | not (digestShape generation) = pure (Left "archive generation identity is invalid")
  | otherwise = do
      let parent = generationDirectory (Store root) generation
          directory = parent </> "receipts"
      linked <- hasSymlink [root, parent, directory]
      exists <- doesDirectoryExist directory
      if linked then pure (Left "archive path contains a symbolic link")
      else if not exists then do
          generationExists <- doesDirectoryExist parent
          pure (if generationExists then Left "archive generation has no receipts directory" else Right [])
      else do
          listed <- try (listDirectory directory) :: IO (Either IOException [FilePath])
          case listed of
            Left problem -> pure (Left ("archive receipts unreadable: " <> Text.pack (show problem)))
            Right names -> fmap sequence (mapM (\name -> fmap (fmap (\(receipt, _) -> (receipt, directory </> name))) (readBundle (directory </> name) generation)) (sort names))
readArchivedReceipts :: FilePath -> GenerationId -> IO (Either Text [Receipt])
readArchivedReceipts root generation = fmap (fmap (map fst)) (readArchivedBundles root generation)
-- Select the latest unique bundle per phase before applying voids, so a red
-- replay cannot fall back to an older bundle with the same receipt digest.
readCurrentArchivedBundles :: FilePath -> GenerationId -> IO (Either Text [(Receipt, FilePath)])
readCurrentArchivedBundles root generation = do
  archived <- readArchivedBundles root generation
  voids <- readReplayVoids root generation
  pure $ do
    rows <- archived
    targets <- voids
    let newest = [(receipt, path) | (receipt, path) <- rows, not (any (\(other, _) -> receiptPhase other == receiptPhase receipt && receiptIssuedAt other > receiptIssuedAt receipt) rows)]
    if any (\(receipt, _) -> length [() | (other, _) <- newest, receiptPhase other == receiptPhase receipt] > 1) newest
      then Left "archive has tied latest bundles for a phase"
      else Right [(receipt, path) | (receipt, path) <- newest, path `notElem` targets]
-- A red replay leaves an immutable content-addressed revocation of the exact
-- bundle it invalidated. Green replay publishes a different bundle.
writeReplayVoid :: FilePath -> Receipt -> FilePath -> Text -> Text -> Text -> IO (Either Text FilePath)
writeReplayVoid root receipt bundle reason failure issued = do
  let generation = receiptGeneration receipt
      target = validationRecordRoot </> makeRelative root bundle
      bundleKey = last (Text.splitOn "-" (Text.pack (takeFileName bundle)))
      body = Text.unlines ["record\tamoebius-replay-void.v1", "target\t" <> Text.pack target
        , "phase\t" <> Text.pack (show (receiptPhase receipt)), "reproducible-digest\t" <> receiptReproducible receipt
        , "verifier-digest\t" <> generation, "governance-digest\t" <> receiptGovernanceDigest receipt
        , "failure-digest\t" <> failure, "reason\t" <> reason, "issued-at\t" <> issued]
      directory = generationDirectory (Store root) generation </> "voids"
      name = "phase-" <> pad (receiptPhase receipt) <> "-" <> Text.unpack bundleKey <> "-" <> Text.unpack (sha256Hex body) <> ".tsv"
      path = directory </> name
      pending = path <> ".pending"
  valid <- readBundle bundle generation
  linked <- hasSymlink [root, directory, path, pending]
  exists <- doesPathExist path
  if either (const True) ((/= receipt) . fst) valid || not (digestShape failure) || reason `notElem` ["gate-red", "runner-refusal"]
    then pure (Left "void target or failure identity is invalid")
  else if linked then pure (Left "void path contains a symbolic link")
  else if exists then do checked <- readReplayVoid root path; pure (if checked == Right bundle then Right path else Left "void content address conflicts")
  else do
    result <- try (createDirectoryIfMissing True directory >> ByteString.writeFile pending (TextEncoding.encodeUtf8 body) >> renameFile pending path) :: IO (Either IOException ())
    pure (either (Left . ("void record not written: " <>) . Text.pack . show) (const (Right path)) result)
 where pad n = let value = show n in if length value < 2 then '0' : value else value
readReplayVoid :: FilePath -> FilePath -> IO (Either Text FilePath)
readReplayVoid root path = do
  linked <- hasSymlink [path]
  sized <- try (getFileSize path) :: IO (Either IOException Integer)
  if linked || either (const True) (> 16 * 1024 * 1024) sized then pure (Left "void record is linked, unreadable, or oversized") else do
    raw <- readEvidence path
    case raw of
      Left problem -> pure (Left problem)
      Right body -> case traverse pair (Text.lines body) of
        Just fields | map fst fields == ["record", "target", "phase", "reproducible-digest", "verifier-digest", "governance-digest", "failure-digest", "reason", "issued-at"] -> do
          let field key = maybe "" id (lookup key fields)
              generation = field "verifier-digest"
              target = Text.unpack (field "target")
              bundle = root </> makeRelative validationRecordRoot target
              bundleKey = last (Text.splitOn "-" (Text.pack (takeFileName bundle)))
              name = "phase-" <> pad (field "phase") <> "-" <> bundleKey <> "-" <> sha256Hex body <> ".tsv"
          found <- if isValidationRecordPath (target </> "receipt.tsv") then readBundle bundle generation else pure (Left "void target path is invalid")
          pure $ case found of
            Right (receipt, _) | field "record" == "amoebius-replay-void.v1" && field "target" == Text.pack (validationRecordRoot </> makeRelative root bundle)
              && digestShape generation && takeFileName (takeDirectory (takeDirectory path)) == "generation-" <> Text.unpack (Text.take 16 generation)
              && field "phase" == Text.pack (show (receiptPhase receipt)) && field "reproducible-digest" == receiptReproducible receipt
              && field "verifier-digest" == generation && field "governance-digest" == receiptGovernanceDigest receipt
              && digestShape (field "failure-digest") && field "reason" `elem` ["gate-red", "runner-refusal"]
              && Text.pack (takeFileName path) == name && body == Text.unlines [key <> "\t" <> value | (key, value) <- fields] -> Right bundle
            _ -> Left ("void record identity or target is invalid: " <> Text.pack path)
        _ -> pure (Left "void record fields are not canonical")
 where
  pair line = case Text.splitOn "\t" line of [key, value] -> Just (key, value); _ -> Nothing
  pad value = if Text.length value < 2 then "0" <> value else value
readReplayVoids :: FilePath -> GenerationId -> IO (Either Text [FilePath])
readReplayVoids root generation = do
  let directory = generationDirectory (Store root) generation </> "voids"
  linked <- hasSymlink [directory]
  exists <- doesDirectoryExist directory
  if linked then pure (Left "void directory is a symbolic link") else if not exists then pure (Right []) else do
    names <- try (listDirectory directory) :: IO (Either IOException [FilePath])
    case names of
      Left problem -> pure (Left ("void directory unreadable: " <> Text.pack (show problem)))
      Right files -> fmap sequence (mapM (readReplayVoid root . (directory </>)) files)
-- | Audit all generations and refuse edits to committed evidence.
auditArchivedInventory :: FilePath -> IO (Either Text Text)
auditArchivedInventory repository = do
  absolute <- makeAbsolute repository
  changed <- observe repository "git" ["-c", "safe.directory=" <> absolute, "diff", "--no-renames", "--name-only", "--diff-filter=MDRT", "HEAD", "--", validationRecordRoot]
  if runExit changed /= ExitSuccess then pure (Left "archive Git inventory unavailable") else
    if not (Text.null (Text.strip (runStdout changed))) then pure (Left "committed archive was modified or deleted") else do
      let root = repository </> validationRecordRoot
      linked <- hasSymlink [root]
      exists <- doesPathExist root
      if linked then pure (Left "archive root is a symbolic link")
      else if not exists then pure (Right (sha256Hex ""))
      else do
        paths <- walk root root
        case paths of
          Left problem -> pure (Left problem)
          Right files -> case filter (not . isValidationRecordPath) (map (makeRelative repository) files) of
            (bad : _) -> pure (Left ("archive path is not admitted: " <> Text.pack bad))
            [] -> do
              bundles <- fmap sequence (mapM checkBundle (nub (sort [takeDirectory file | file <- files, takeFileName (takeDirectory (takeDirectory file)) == "receipts"])))
              case bundles of
                Left problem -> pure (Left problem)
                Right _ -> do
                  voids <- fmap sequence (mapM (readReplayVoid root) [file | file <- files, takeFileName (takeDirectory file) == "voids"])
                  case voids of
                    Left problem -> pure (Left problem)
                    Right _ -> do
                      bytes <- try (mapM ByteString.readFile (sort files)) :: IO (Either IOException [ByteString])
                      pure (either (Left . Text.pack . show) (Right . sha256Hex . Text.unlines . zipWith (\path body -> Text.pack (makeRelative repository path) <> "\t" <> hex (SHA256.hash body)) (sort files)) bytes)
 where
  walk root path = do
    linked <- hasSymlink [path]
    if linked then pure (Left ("archive path is a symbolic link: " <> Text.pack path)) else do
      directory <- doesDirectoryExist path
      if directory then do
        listed <- try (listDirectory path) :: IO (Either IOException [FilePath])
        case listed of
          Left problem -> pure (Left (Text.pack (show problem)))
          Right [] | path /= root -> pure (Left ("archive has an empty directory: " <> Text.pack path))
          Right names -> fmap (fmap concat . sequence) (mapM (walk root . (path </>)) names)
      else fmap (\file -> if file then Right [path] else Left ("archive entry is unreadable: " <> Text.pack path)) (doesFileExist path)
  checkBundle path = do
    record <- readRecord (path </> "receipt.tsv")
    case record >>= parseReceipt of
      Left problem -> pure (Left problem)
      Right receipt
        | takeFileName (takeDirectory (takeDirectory path)) /= "generation-" <> Text.unpack (Text.take 16 (receiptGeneration receipt)) -> pure (Left "archive generation directory and receipt disagree")
        | otherwise -> fmap (fmap (const ())) (readBundle path (receiptGeneration receipt))
hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]
