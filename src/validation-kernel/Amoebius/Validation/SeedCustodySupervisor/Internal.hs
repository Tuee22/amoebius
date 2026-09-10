{-# LANGUAGE OverloadedStrings #-}

-- | OS-backed qualification and issuance for the finite Phase-0 seed.
--
-- This module is intentionally package-hidden.  A successful value requires
-- a UID-zero supervisor, a distinct candidate UID, the descriptor-relative
-- protected-layout check, all seven independently judged custody cases, and
-- an Ed25519 acknowledgement bound to the current generation, accepted seed,
-- source, fresh session, and custody transcript.
module Amoebius.Validation.SeedCustodySupervisor.Internal
  ( QualifiedSeedCustody
  , ProtectedCandidateAdmission
  , SeedCustodyIssueRequest (..)
  , foldQualifiedSeedCustody
  , foldProtectedCandidateAdmission
  , initializeSeedAuthority
  , certificationMirrorRoot
  , qualifyAndIssueSeedCustody
  , issueQualifiedPhasePassReceipt
  , verifyProtectedCandidate
  , runSeedCustodyProbeContinuation
  ) where

import Amoebius.Validation.SeedCustodyOracle.Internal
  ( checkSeedCustodyTranscript )
import Amoebius.Validation.SeedCustodyPrerequisites.Internal
  ( SeedCustodyRequest (..)
  , seedCustodyPrerequisitesDiagnostic
  )
import Amoebius.Validation.SeedReceipt.Internal
  ( SeedReceiptExpectation (..)
  , verifySeedReceiptCryptography
  )
import Amoebius.Validation.PhasePassReceipt.Internal
  ( issuePhasePassReceipt )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , GitExecutable
  , SnapshotProblem
  , acquiredSourceSnapshot
  , loadGitSnapshot
  , mkGitExecutable
  , renderSnapshotProblem
  )
import Amoebius.Validation.SourceSnapshot.Internal
  ( IndexEntry (..)
  , IndexMode (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , checkPassed
  , finding
  , findingCode
  , observation
  , observationKey
  )
import Control.Exception (IOException, try)
import Control.Monad (unless)
import Crypto.Error (CryptoFailable (..))
import Crypto.Hash.SHA256 qualified as SHA256
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Crypto.Random (getRandomBytes)
import Data.Aeson (Value (..), decodeStrict')
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Foldable (toList)
import Data.List (isPrefixOf)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word32)
import System.Directory
  ( canonicalizePath
  , copyFile
  , createDirectory
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , doesPathExist
  , findExecutable
  , getDirectoryContents
  , listDirectory
  , makeAbsolute
  , pathIsSymbolicLink
  , removePathForcibly
  , getSymbolicLinkTarget
  )
import System.Environment
  ( getEnvironment
  , getExecutablePath
  )
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO.Error (isPermissionError)
import System.Posix.Files
  ( createSymbolicLink
  , fileMode
  , getFileStatus
  , rename
  , setFileMode
  )
import System.Posix.IO
  ( OpenMode (ReadOnly, WriteOnly)
  , closeFd
  , defaultFileFlags
  , openFd
  )
import System.Posix.User
  ( getEffectiveUserID
  , getRealUserID
  )
import System.Process
  ( CreateProcess (..)
  , createProcess
  , proc
  , waitForProcess
  )
import Text.Read (readMaybe)

certificationMirrorRoot :: FilePath
certificationMirrorRoot = "/var/lib/amoebius-certification/generation-1/repository"

-- | Create the initial finite accepted seed in a root-owned mirror.  Existing
-- authority state is never replaced.  The source snapshot is acquired before
-- and after copying, and the protected mirror must independently acquire the
-- same identity before any key or accepted-seed bytes are retained.
initializeSeedAuthority
  :: FilePath
  -> Word32
  -> Word32
  -> IO CheckResult
initializeSeedAuthority requestedRoot candidateUid candidateGid = do
  realUid <- getRealUserID
  effectiveUid <- getEffectiveUserID
  if realUid /= 0 || effectiveUid /= 0
    then pure (initializationFailure "SEED-AUTHORITY-SUPERVISOR" "Initial seed installation requires real and effective UID zero.")
    else do
      existing <- doesPathExist certificationMirrorRoot
      if existing
        then pure (initializationFailure "SEED-AUTHORITY-EXISTS" "The generation-1 certification mirror already exists and will not be replaced.")
        else initializeAbsent requestedRoot candidateUid candidateGid

initializeAbsent :: FilePath -> Word32 -> Word32 -> IO CheckResult
initializeAbsent requestedRoot candidateUid candidateGid = do
  absoluteRoot <- makeAbsolute requestedRoot >>= canonicalizePath
  gitPath <- findExecutable "git" >>= traverse canonicalizePath
  executable <- getExecutablePath >>= canonicalizePath
  case gitPath >>= either (const Nothing) Just . mkGitExecutable of
    Nothing -> pure (initializationFailure "SEED-AUTHORITY-GIT" "An absolute Git executable is required to acquire the initial source snapshot.")
    Just git -> do
      opening <- loadGitSnapshot git absoluteRoot
      case opening of
        Left problems -> pure (snapshotInitializationFailure "opening" problems)
        Right acquired -> do
          attempted <- try (installMirror git executable absoluteRoot candidateUid candidateGid acquired) :: IO (Either IOException CheckResult)
          case attempted of
            Left problem -> do
              cleanupInstalledMirror
              pure (initializationFailure "SEED-AUTHORITY-INSTALL" (Text.pack (show problem)))
            Right result
              | checkPassed result -> pure result
              | otherwise -> cleanupInstalledMirror >> pure result

installMirror
  :: GitExecutable
  -> FilePath
  -> FilePath
  -> Word32
  -> Word32
  -> AcquiredSourceSnapshot
  -> IO CheckResult
installMirror git executable originalRoot candidateUid candidateGid opening = do
  createDirectoryIfMissing True (takeDirectory certificationMirrorRoot)
  setFileMode "/var/lib/amoebius-certification" 0o755
  setFileMode "/var/lib/amoebius-certification/generation-1" 0o755
  createDirectory certificationMirrorRoot
  setFileMode certificationMirrorRoot 0o755
  copyGitAdministration (originalRoot </> ".git") (certificationMirrorRoot </> ".git")
  mapM_ (writeTrackedEntry certificationMirrorRoot) (snapshotEntries source)
  createDirectoryIfMissing True (certificationMirrorRoot </> ".build" </> "bootstrap-inputs")
  setFileMode (certificationMirrorRoot </> ".build") 0o755
  setFileMode (certificationMirrorRoot </> ".build" </> "bootstrap-inputs") 0o755
  copyBootstrapInputs originalRoot
  closing <- loadGitSnapshot git originalRoot
  mirrored <- loadGitSnapshot git certificationMirrorRoot
  case (closing, mirrored) of
    (Right closingAcquired, Right mirroredAcquired)
      | snapshotIdentity (acquiredSourceSnapshot closingAcquired) == sourceIdentity
      , snapshotIdentity (acquiredSourceSnapshot mirroredAcquired) == sourceIdentity -> do
          installSeedFiles executable candidateUid candidateGid sourceIdentity
          qualified <-
            qualifyAndIssueSeedCustody
              SeedCustodyIssueRequest
                { seedIssueRepositoryRoot = certificationMirrorRoot
                , seedIssueCandidateUid = candidateUid
                , seedIssueCandidateGid = candidateGid
                , seedIssueSourceIdentity = decodeSha256 sourceIdentity
                }
          case qualified of
            Left problems -> pure (CheckResult "seed-authority-initialization" [] problems)
            Right custody ->
              foldQualifiedSeedCustody
                (finishInitialization sourceIdentity candidateUid candidateGid)
                custody
    (Left problems, _) -> pure (snapshotInitializationFailure "closing" problems)
    (_, Left problems) -> pure (snapshotInitializationFailure "protected-mirror" problems)
    _ -> pure (initializationFailure "SEED-AUTHORITY-SOURCE-CHANGED" "The opening, closing, and protected-mirror source identities do not agree.")
 where
  source = acquiredSourceSnapshot opening
  sourceIdentity = snapshotIdentity source

finishInitialization
  :: Text
  -> Word32
  -> Word32
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> CheckResult
  -> IO CheckResult
finishInitialization sourceIdentity candidateUid candidateGid generation accepted _source session transcript public receipt custodyCheck = do
  let directory = certificationMirrorRoot </> ".build" </> "validation-seed"
  ByteString.writeFile (directory </> "initial-custody.receipt") receipt
  setFileMode (directory </> "initial-custody.receipt") 0o444
  pure
    CheckResult
      { checkName = "seed-authority-initialization"
      , checkObservations =
          checkObservations custodyCheck
            <> [ observation "seed-authority.repository" (Text.pack certificationMirrorRoot)
               , observation "seed-authority.source.sha256" sourceIdentity
               , observation "seed-authority.generation.sha256" (hex generation)
               , observation "seed-authority.accepted-seed.sha256" (hex accepted)
               , observation "seed-authority.session.sha256" (hex session)
               , observation "seed-authority.transcript.sha256" (hex transcript)
               , observation "seed-authority.public-key.sha256" (hex (SHA256.hash public))
               , observation "seed-authority.candidate-uid" (Text.pack (show candidateUid))
               , observation "seed-authority.candidate-gid" (Text.pack (show candidateGid))
               ]
      , checkFindings = checkFindings custodyCheck
      }

installSeedFiles :: FilePath -> Word32 -> Word32 -> Text -> IO ()
installSeedFiles executable candidateUid candidateGid sourceIdentity = do
  let directory = certificationMirrorRoot </> ".build" </> "validation-seed"
      verifier = directory </> "verifier"
      oracle = directory </> "oracle"
  createDirectory directory
  setFileMode directory 0o755
  copyFile executable verifier
  copyFile executable oracle
  setFileMode verifier 0o755
  setFileMode oracle 0o755
  privateSeed <- getRandomBytes identifierBytes
  secret <- case Ed25519.secretKey privateSeed of
    CryptoFailed problem -> fail (show problem)
    CryptoPassed value -> pure value
  let public = convert (Ed25519.toPublic secret)
  -- The binding is constructed after both executable copies are durable.
  verifierBytes <- ByteString.readFile verifier
  oracleBytes <- ByteString.readFile oracle
  let binding =
        ByteString.concat
          [ "amoebius.accepted-seed.v1\0"
          , SHA256.hash generationLabel
          , decodeSha256 sourceIdentity
          , SHA256.hash verifierBytes
          , SHA256.hash oracleBytes
          , word32be candidateUid
          , word32be candidateGid
          ]
  ByteString.writeFile (directory </> "issuer.key") privateSeed
  ByteString.writeFile (directory </> "issuer.pub") public
  ByteString.writeFile (directory </> "accepted-seed") binding
  setFileMode (directory </> "issuer.key") 0o600
  setFileMode (directory </> "issuer.pub") 0o444
  setFileMode (directory </> "accepted-seed") 0o444

copyBootstrapInputs :: FilePath -> IO ()
copyBootstrapInputs originalRoot =
  mapM_ copyOne bootstrapInputLeaves
 where
  copyOne leaf = do
    let source = originalRoot </> ".build" </> "bootstrap-inputs" </> leaf
        destination = certificationMirrorRoot </> ".build" </> "bootstrap-inputs" </> leaf
    copyFile source destination
    setFileMode destination 0o444

bootstrapInputLeaves :: [FilePath]
bootstrapInputLeaves =
  [ "ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz"
  , "ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig"
  , "ghc-SHA256SUMS"
  , "ghc-SHA256SUMS.sig"
  , "cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz"
  , "cabal-SHA256SUMS"
  , "cabal-SHA256SUMS.sig"
  ]

writeTrackedEntry :: FilePath -> TrackedEntry -> IO ()
writeTrackedEntry root entry = do
  let indexed = trackedIndex entry
      destination = root </> indexPath indexed
  createDirectoryIfMissing True (takeDirectory destination)
  case indexMode indexed of
    SymbolicLink -> createSymbolicLink (Text.unpack (TextEncoding.decodeUtf8 (trackedBytes entry))) destination
    RegularFile -> ByteString.writeFile destination (trackedBytes entry) >> setFileMode destination 0o644
    ExecutableFile -> ByteString.writeFile destination (trackedBytes entry) >> setFileMode destination 0o755

copyGitAdministration :: FilePath -> FilePath -> IO ()
copyGitAdministration source destination = do
  symbolic <- pathIsSymbolicLink source
  if symbolic
    then fail "seed-authority-git-symlink-refused"
    else do
      directory <- doesDirectoryExist source
      file <- doesFileExist source
      case (directory, file) of
        (True, _) -> do
          createDirectory destination
          setFileMode destination 0o755
          leaves <- listDirectory source
          mapM_ (\leaf -> copyGitAdministration (source </> leaf) (destination </> leaf)) leaves
        (_, True) -> do
          copyFile source destination
          sourceStatus <- getFileStatus source
          setFileMode destination (fileMode sourceStatus)
        _ -> fail "seed-authority-git-entry-kind-refused"

cleanupInstalledMirror :: IO ()
cleanupInstalledMirror = do
  present <- doesPathExist "/var/lib/amoebius-certification/generation-1"
  if present
    then removePathForcibly "/var/lib/amoebius-certification/generation-1"
    else pure ()

snapshotInitializationFailure :: Text -> [SnapshotProblem] -> CheckResult
snapshotInitializationFailure stage problems =
  CheckResult
    { checkName = "seed-authority-initialization"
    , checkObservations = [observation "seed-authority.snapshot-stage" stage]
    , checkFindings =
        [ finding "SEED-AUTHORITY-SNAPSHOT" "<source-snapshot>" (renderSnapshotProblem problem)
        | problem <- problems
        ]
    }

initializationFailure :: Text -> Text -> CheckResult
initializationFailure code detail =
  CheckResult
    { checkName = "seed-authority-initialization"
    , checkObservations = []
    , checkFindings = [finding code "<seed-authority>" detail]
    }

decodeSha256 :: Text -> ByteString
decodeSha256 value
  | Text.length value == 64 = ByteString.pack (go (Text.unpack value))
  | otherwise = ByteString.empty
 where
  go (high : low : rest) = fromIntegral (digit high * 16 + digit low) : go rest
  go [] = []
  go _ = []
  digit character
    | character >= '0' && character <= '9' = fromEnum character - fromEnum '0'
    | character >= 'a' && character <= 'f' = 10 + fromEnum character - fromEnum 'a'
    | otherwise = 0

word32be :: Word32 -> ByteString
word32be value =
  ByteString.pack
    [ fromIntegral (value `div` 16777216)
    , fromIntegral (value `div` 65536)
    , fromIntegral (value `div` 256)
    , fromIntegral value
    ]

data SeedCustodyIssueRequest = SeedCustodyIssueRequest
  { seedIssueRepositoryRoot :: FilePath
  , seedIssueCandidateUid :: Word32
  , seedIssueCandidateGid :: Word32
  , seedIssueSourceIdentity :: ByteString
  }
  deriving (Eq, Show)

data QualifiedSeedCustody = QualifiedSeedCustody
  { qualifiedGeneration :: ByteString
  , qualifiedAcceptedSeed :: ByteString
  , qualifiedSource :: ByteString
  , qualifiedSession :: ByteString
  , qualifiedTranscript :: ByteString
  , qualifiedPublicKey :: ByteString
  , qualifiedReceipt :: ByteString
  , qualifiedCheck :: CheckResult
  }

data ProtectedCandidateAdmission = ProtectedCandidateAdmission
  { protectedCandidatePhase :: Int
  , protectedCandidateSource :: Text
  , protectedCandidateEvidence :: Text
  , protectedCandidateProjection :: Text
  , protectedCandidatePostimage :: Text
  , protectedCandidateCompatibility :: Text
  , protectedCandidatePredecessor :: Text
  , protectedCandidatePath :: FilePath
  }

foldProtectedCandidateAdmission
  :: (Int -> Text -> Text -> Text -> Text -> Text -> Text -> FilePath -> value)
  -> ProtectedCandidateAdmission
  -> value
foldProtectedCandidateAdmission consume admitted =
  consume
    (protectedCandidatePhase admitted)
    (protectedCandidateSource admitted)
    (protectedCandidateEvidence admitted)
    (protectedCandidateProjection admitted)
    (protectedCandidatePostimage admitted)
    (protectedCandidateCompatibility admitted)
    (protectedCandidatePredecessor admitted)
    (protectedCandidatePath admitted)

foldQualifiedSeedCustody
  :: (ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> CheckResult -> value)
  -> QualifiedSeedCustody
  -> value
foldQualifiedSeedCustody consume qualified =
  consume
    (qualifiedGeneration qualified)
    (qualifiedAcceptedSeed qualified)
    (qualifiedSource qualified)
    (qualifiedSession qualified)
    (qualifiedTranscript qualified)
    (qualifiedPublicKey qualified)
    (qualifiedReceipt qualified)
    (qualifiedCheck qualified)

verifyProtectedCandidate
  :: QualifiedSeedCustody
  -> Int
  -> FilePath
  -> IO (Either [Finding] ProtectedCandidateAdmission)
verifyProtectedCandidate custody phase path = do
  attempted <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
  verifierAttempt <- try (ByteString.readFile (certificationMirrorRoot </> ".build" </> "validation-seed" </> "verifier")) :: IO (Either IOException ByteString)
  pure $ case (attempted, verifierAttempt) of
    (Left problem, _) -> Left [candidateFinding "CERTIFICATION-CANDIDATE-READ" (Text.pack (show problem))]
    (_, Left problem) -> Left [candidateFinding "CERTIFICATION-VERIFIER-READ" (Text.pack (show problem))]
    (Right bytes, Right verifierBytes) -> verifyCandidateBytes custody phase path (hex (SHA256.hash verifierBytes)) bytes

verifyCandidateBytes
  :: QualifiedSeedCustody
  -> Int
  -> FilePath
  -> Text
  -> ByteString
  -> Either [Finding] ProtectedCandidateAdmission
verifyCandidateBytes custody phase path verifierDigest bytes =
  case decodeStrict' bytes of
    Nothing -> Left [candidateFinding "CERTIFICATION-CANDIDATE-JSON" "The protected candidate is not valid JSON."]
    Just value -> case candidateProblems value of
      problems@(_ : _) -> Left problems
      [] -> case (textField "projectionDigest" value, textField "projectionPostimageDigest" value, textField "compatibilityClosureDigest" value, objectField "predecessor" value >>= predecessorEvidenceDigest) of
        (Just projection, Just postimage, Just compatibility, Just predecessor) ->
          Right
            ProtectedCandidateAdmission
              { protectedCandidatePhase = phase
              , protectedCandidateSource = sourceText
              , protectedCandidateEvidence = evidenceDigest
              , protectedCandidateProjection = projection
              , protectedCandidatePostimage = postimage
              , protectedCandidateCompatibility = compatibility
              , protectedCandidatePredecessor = predecessor
              , protectedCandidatePath = path
              }
        _ -> Left [candidateFinding "CERTIFICATION-CANDIDATE-PROJECTION" "The protected candidate omits a projection, compatibility, or predecessor identity."]
 where
  evidenceDigest = hex (SHA256.hash bytes)
  sourceText = hex (qualifiedSource custody)
  candidateProblems value =
    [candidateFinding "CERTIFICATION-CANDIDATE-PATH" "The candidate filename does not equal the exact evidence digest." | takeFileName path /= Text.unpack evidenceDigest <> ".json"]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-SCHEMA" "The candidate schema is not the accepted v4 schema." | textField "schema" value /= Just "amoebius-validation-candidate-v4"]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-GENERATION" "The candidate does not name the custody-qualified certification generation." | textField "certificationGenerationDigest" value /= Just generationText]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-BASELINE" "The candidate does not name the custody-qualified accepted baseline." | textField "acceptedBaselineDigest" value /= Just acceptedText]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-COMPATIBILITY" "The candidate compatibility closure is absent or does not bind its accepted dependency, oracle, observer, harness, qualification, build, toolchain, and predecessor fields." | not (candidateCompatibilityMatches value)]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-PHASE" "The candidate phase does not equal the supervised phase." | textField "phase" value /= Just (formatOrdinal phase)]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-SOURCE" "Opening and closing candidate source identities do not equal the custody-bound source." | textField "sourceOpeningDigest" value /= Just sourceText || textField "sourceClosingDigest" value /= Just sourceText]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-PROJECTION" "The projection identities are missing or malformed." | any (maybe True (not . sha256Text)) [textField "projectionDigest" value, textField "projectionPostimageDigest" value]]
      <> commandProblems value
      <> rowProblems value
      <> [candidateFinding "CERTIFICATION-CANDIDATE-RESIDUE" "The candidate retains missing-evidence or forbidden-resource residue." | arrayLengthField "residue" value /= Just 0]
      <> [candidateFinding "CERTIFICATION-CANDIDATE-VERDICT" "The candidate did not retain the exact sealed-green pre-verification verdict." | textField "gateResult" value /= Just "candidate-green; sealed gate verification required"]
  commandProblems value = case objectField "command" value of
    Nothing -> [candidateFinding "CERTIFICATION-CANDIDATE-COMMAND" "The candidate command object is absent."]
    Just command ->
      [candidateFinding "CERTIFICATION-CANDIDATE-EXECUTABLE" "The candidate did not execute the protected accepted verifier." | textField "executablePath" command /= Just (Text.pack verifierPath) || textField "executableDigest" command /= Just verifierDigest]
        <> [candidateFinding "CERTIFICATION-CANDIDATE-ARGV" "The candidate argv is not the exact phase command." | textArrayField "argv" command /= Just ["validate", "phase", formatOrdinal phase]]
  rowProblems value = case arrayField "rows" value of
    Nothing -> [candidateFinding "CERTIFICATION-CANDIDATE-ROWS" "The candidate row array is absent."]
    Just rows ->
      [candidateFinding "CERTIFICATION-CANDIDATE-ROWS" "The candidate rows do not equal the exact ordered eighteen-row inventory." | map (textFieldFrom "name") rows /= map Just acceptedGateRows]
        <> [candidateFinding "CERTIFICATION-CANDIDATE-ROW-OUTCOME" "A required candidate row is not green." | any ((/= Just "green") . textFieldFrom "outcome") rows]
        <> [candidateFinding "CERTIFICATION-CANDIDATE-ROW-OBSERVATION" "A required candidate row has no raw observation." | any ((== Just 0) . arrayLengthFieldFrom "observations") rows || any ((== Nothing) . arrayLengthFieldFrom "observations") rows]
        <> [candidateFinding "CERTIFICATION-CANDIDATE-ROW-FINDING" "A green candidate row retains a finding." | any ((/= Just 0) . arrayLengthFieldFrom "findings") rows]
        <> [candidateFinding "CERTIFICATION-CANDIDATE-ROW-UNVERIFIED" "A green candidate row retains unverified residue." | any ((/= Just Null) . fieldFrom "unverified") rows]
  verifierPath = certificationMirrorRoot </> ".build" </> "validation-seed" </> "verifier"
  generationText = hex (qualifiedGeneration custody)
  acceptedText = hex (qualifiedAcceptedSeed custody)
  candidateCompatibilityMatches value = case (textField "compatibilityClosureDigest" value, candidateCompatibilityDigest value) of
    (Just actual, Just expected) -> actual == expected
    _ -> False
  candidateCompatibilityDigest value = do
    candidatePhase <- textField "phase" value
    opening <- textField "sourceOpeningDigest" value
    contract <- textField "contractDigest" value
    subject <- textField "subjectDigest" value
    oracle <- textField "oracleDigest" value
    harness <- textField "harnessDigest" value
    observer <- textField "observerDigest" value
    qualification <- textField "qualificationDigest" value
    predecessor <- objectField "predecessor" value >>= predecessorCompatibility
    command <- objectField "command" value
    executable <- textField "executableDigest" command
    toolchain <- textField "toolchainIdentity" value
    pure
      ( digestFields
          [ "amoebius-candidate-compatibility-v1"
          , generationText
          , acceptedText
          , candidatePhase
          , opening
          , contract
          , subject
          , oracle
          , harness
          , observer
          , qualification
          , predecessor
          , executable
          , toolchain
          ]
      )
  predecessorCompatibility predecessor = case textField "kind" predecessor of
    Just "genesis-trust" -> ("genesis:" <>) <$> textField "trustDigest" predecessor
    Just "immediate-predecessor" -> do
      predecessorPhase <- textField "phase" predecessor
      predecessorDigest <- textField "evidenceDigest" predecessor
      pure ("phase-" <> predecessorPhase <> ":" <> predecessorDigest)
    Just "unverified" -> ("unverified:" <>) <$> textField "detail" predecessor
    _ -> Nothing
  predecessorEvidenceDigest predecessor = case textField "kind" predecessor of
    Just "genesis-trust" -> textField "trustDigest" predecessor
    Just "immediate-predecessor" -> textField "evidenceDigest" predecessor
    _ -> Nothing

acceptedGateRows :: [Text]
acceptedGateRows =
  [ "Claim", "Subject", "Command", "Oracle", "Positive controls"
  , "Paired negatives", "Mutants", "Discovery", "Challenge", "Observer"
  , "Authority/bypass", "Freshness", "Qualification", "Cleanroom"
  , "Legacy closure", "Predecessor", "Residue", "Pass criterion"
  ]

fieldFrom :: Text -> Value -> Maybe Value
fieldFrom key (Object values) = KeyMap.lookup (AesonKey.fromText key) values
fieldFrom _ _ = Nothing

objectField :: Text -> Value -> Maybe Value
objectField key value = case fieldFrom key value of
  Just object@(Object _) -> Just object
  _ -> Nothing

textField :: Text -> Value -> Maybe Text
textField key = textFieldFrom key

textFieldFrom :: Text -> Value -> Maybe Text
textFieldFrom key value = case fieldFrom key value of
  Just (String text) -> Just text
  _ -> Nothing

arrayField :: Text -> Value -> Maybe [Value]
arrayField key value = case fieldFrom key value of
  Just (Array values) -> Just (toList values)
  _ -> Nothing

arrayLengthField :: Text -> Value -> Maybe Int
arrayLengthField key value = length <$> arrayField key value

arrayLengthFieldFrom :: Text -> Value -> Maybe Int
arrayLengthFieldFrom = arrayLengthField

textArrayField :: Text -> Value -> Maybe [Text]
textArrayField key value = traverse asText =<< arrayField key value
 where
  asText item = case item of
    String text -> Just text
    _ -> Nothing

candidateFinding :: Text -> Text -> Finding
candidateFinding code = finding code "<protected-candidate>"

sha256Text :: Text -> Bool
sha256Text value =
  Text.length value == 64
    && Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f') value

formatOrdinal :: Int -> Text
formatOrdinal value
  | value >= 0 && value < 10 = "0" <> Text.pack (show value)
  | otherwise = Text.pack (show value)

qualifyAndIssueSeedCustody
  :: SeedCustodyIssueRequest
  -> IO (Either [Finding] QualifiedSeedCustody)
qualifyAndIssueSeedCustody request
  | ByteString.length (seedIssueSourceIdentity request) /= identifierBytes =
      pure (Left [custodyFinding "SEED-CUSTODY-SOURCE" "The acquired source identity must contain exactly 32 bytes."])
  | seedIssueCandidateUid request == 0 || seedIssueCandidateGid request == 0 =
      pure (Left [custodyFinding "SEED-CUSTODY-CANDIDATE" "The candidate UID and GID must be nonzero."])
  | otherwise = do
      realUid <- getRealUserID
      effectiveUid <- getEffectiveUserID
      if realUid /= 0 || effectiveUid /= 0
        then pure (Left [custodyFinding "SEED-CUSTODY-SUPERVISOR" "Seed issuance requires real and effective UID zero."])
        else qualifyAsRoot request

qualifyAsRoot :: SeedCustodyIssueRequest -> IO (Either [Finding] QualifiedSeedCustody)
qualifyAsRoot request = do
  prerequisites <-
    seedCustodyPrerequisitesDiagnostic
      SeedCustodyRequest
        { seedCustodyRepositoryRoot = seedIssueRepositoryRoot request
        , seedCustodyCandidateUid = seedIssueCandidateUid request
        }
  let prerequisiteProblems =
        [ problem
        | problem <- checkFindings prerequisites
        , findingCode problem /= "SEED-CUSTODY-NOT-QUALIFIED"
        ]
  if not (null prerequisiteProblems)
    then pure (Left prerequisiteProblems)
    else do
      acquired <- acquireAuthorityInputs request
      case acquired of
        Left problems -> pure (Left problems)
        Right (acceptedSeedBytes, privateSeed, publicBytes) -> do
          custodyCases <- runCustodyCases acceptedSeedBytes privateSeed publicBytes request
          case custodyCases of
            Left problems -> pure (Left problems)
            Right transcriptBytes ->
              issueQualified prerequisites acceptedSeedBytes privateSeed publicBytes transcriptBytes request

acquireAuthorityInputs
  :: SeedCustodyIssueRequest
  -> IO (Either [Finding] (ByteString, ByteString, ByteString))
acquireAuthorityInputs request = do
  let directory = seedDirectory request
  accepted <- readAuthorityFile (directory </> "accepted-seed")
  privateSeed <- readAuthorityFile (directory </> "issuer.key")
  publicBytes <- readAuthorityFile (directory </> "issuer.pub")
  verifier <- readAuthorityFile (directory </> "verifier")
  oracle <- readAuthorityFile (directory </> "oracle")
  pure $ do
    acceptedBytes <- accepted
    privateBytes <- privateSeed
    publicKeyBytes <- publicBytes
    verifierBytes <- verifier
    oracleBytes <- oracle
    unless (ByteString.length privateBytes == identifierBytes) $
      Left [custodyFinding "SEED-CUSTODY-KEY-SIZE" "The protected Ed25519 private seed is not exactly 32 bytes."]
    unless (ByteString.length publicKeyBytes == identifierBytes) $
      Left [custodyFinding "SEED-CUSTODY-KEY-SIZE" "The protected Ed25519 public key is not exactly 32 bytes."]
    secret <- case Ed25519.secretKey privateBytes of
      CryptoFailed _ -> Left [custodyFinding "SEED-CUSTODY-PRIVATE-KEY" "The protected Ed25519 private seed is invalid."]
      CryptoPassed value -> Right value
    let derivedPublic = convert (Ed25519.toPublic secret)
    unless (derivedPublic == publicKeyBytes) $
      Left [custodyFinding "SEED-CUSTODY-KEY-PAIR" "The protected public key does not correspond to the protected private seed."]
    let baselineSource = ByteString.take identifierBytes (ByteString.drop acceptedSeedSourceOffset acceptedBytes)
        expectedAcceptedSeed =
          ByteString.concat
            [ acceptedSeedDomain
            , SHA256.hash generationLabel
            , baselineSource
            , SHA256.hash verifierBytes
            , SHA256.hash oracleBytes
            , word32be (seedIssueCandidateUid request)
            , word32be (seedIssueCandidateGid request)
            ]
    unless (acceptedBytes == expectedAcceptedSeed) $
      Left [custodyFinding "SEED-CUSTODY-ACCEPTED-SEED" "The protected accepted seed does not exactly bind this generation, source, verifier, oracle, and candidate credential pair."]
    pure (acceptedBytes, privateBytes, publicKeyBytes)

issueQualified
  :: CheckResult
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> SeedCustodyIssueRequest
  -> IO (Either [Finding] QualifiedSeedCustody)
issueQualified prerequisites acceptedSeedBytes privateSeed publicBytes transcriptBytes request = do
  session <- getRandomBytes identifierBytes
  let generation = SHA256.hash generationLabel
      acceptedSeed = SHA256.hash acceptedSeedBytes
      source = seedIssueSourceIdentity request
      transcript = SHA256.hash transcriptBytes
      expectation =
        SeedReceiptExpectation
          { expectedSeedReceiptPublicKey = publicBytes
          , expectedSeedReceiptGeneration = generation
          , expectedSeedReceiptAcceptedSeed = acceptedSeed
          , expectedSeedReceiptSource = source
          , expectedSeedReceiptSession = session
          , expectedSeedReceiptTranscriptDigest = transcript
          }
  case Ed25519.secretKey privateSeed of
    CryptoFailed _ -> pure (Left [custodyFinding "SEED-CUSTODY-PRIVATE-KEY" "The protected Ed25519 private seed is invalid."])
    CryptoPassed secret -> do
      let receipt = signReceipt secret (Ed25519.toPublic secret) generation acceptedSeed source session transcript
          oracleResult = checkSeedCustodyTranscript transcriptBytes
          receiptResult = verifySeedReceiptCryptography expectation receipt
      pure $ case (checkPassed oracleResult, receiptResult) of
        (False, _) -> Left (checkFindings oracleResult)
        (_, Left problem) -> Left [problem]
        (True, Right ()) ->
          Right
            QualifiedSeedCustody
              { qualifiedGeneration = generation
              , qualifiedAcceptedSeed = acceptedSeed
              , qualifiedSource = source
              , qualifiedSession = session
              , qualifiedTranscript = transcript
              , qualifiedPublicKey = publicBytes
              , qualifiedReceipt = receipt
              , qualifiedCheck =
                  CheckResult
                    { checkName = "seed-custody-qualification"
                    , checkObservations =
                        filter ((/= "seed-custody.status") . observationKey) (checkObservations prerequisites)
                          <> checkObservations oracleResult
                          <> [ observation "seed-custody.status" "QUALIFIED"
                             , observation "seed-custody.generation.sha256" (hex generation)
                             , observation "seed-custody.accepted-seed.sha256" (hex acceptedSeed)
                             , observation "seed-custody.source.sha256" (hex source)
                             , observation "seed-custody.session.sha256" (hex session)
                             , observation "seed-custody.transcript.sha256" (hex transcript)
                             , observation "seed-custody.receipt.sha256" (hex (SHA256.hash receipt))
                             ]
                    , checkFindings = []
                    }
              }

-- | Sign one numbered-phase pass only from a freshly qualified custody value.
-- The candidate supplies none of the signing material; every digest is first
-- checked for canonical width and the source preimage must equal the source
-- already bound into the qualification receipt.
issueQualifiedPhasePassReceipt
  :: QualifiedSeedCustody
  -> Int
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> IO (Either [Finding] ByteString)
issueQualifiedPhasePassReceipt custody phase sourcePreimage sourcePostimage candidate projection compatibility predecessor stdoutDigest stderrDigest = do
  privateResult <- readAuthorityFile (certificationMirrorRoot </> ".build" </> "validation-seed" </> "issuer.key")
  session <- getRandomBytes identifierBytes
  pure $ do
    privateSeed <- privateResult
    unless (all sha256Text [sourcePreimage, sourcePostimage, candidate, projection, compatibility, predecessor, stdoutDigest, stderrDigest]) $
      Left [custodyFinding "PHASE-RECEIPT-IDENTITY" "A phase-pass binding is not a canonical lowercase SHA-256."]
    let decoded = map decodeSha256 [sourcePreimage, sourcePostimage, candidate, projection, compatibility, predecessor, stdoutDigest, stderrDigest]
    unless (all ((== identifierBytes) . ByteString.length) decoded) $
      Left [custodyFinding "PHASE-RECEIPT-IDENTITY" "A phase-pass binding is not a canonical lowercase SHA-256."]
    case decoded of
      [sourceBefore, sourceAfter, candidateDigest, projectionDigestValue, compatibilityDigest, predecessorDigest, stdoutBytes, stderrBytes] -> do
        unless (sourceBefore == qualifiedSource custody) $
          Left [custodyFinding "PHASE-RECEIPT-SOURCE" "The phase-pass source preimage differs from the custody-qualified source."]
        case issuePhasePassReceipt privateSeed phase (qualifiedAcceptedSeed custody) sourceBefore sourceAfter candidateDigest projectionDigestValue compatibilityDigest predecessorDigest session stdoutBytes stderrBytes of
          Left problem -> Left [problem]
          Right receipt -> Right receipt
      _ -> Left [custodyFinding "PHASE-RECEIPT-INVENTORY" "The phase-pass identity inventory is incomplete."]

runCustodyCases
  :: ByteString
  -> ByteString
  -> ByteString
  -> SeedCustodyIssueRequest
  -> IO (Either [Finding] ByteString)
runCustodyCases acceptedSeedBytes privateSeed publicBytes request = do
  let generation = SHA256.hash generationLabel
      acceptedSeed = SHA256.hash acceptedSeedBytes
      source = seedIssueSourceIdentity request
      probeSession = ByteString.replicate identifierBytes 0x53
      probeTranscript = ByteString.replicate identifierBytes 0x54
      expectation =
        SeedReceiptExpectation publicBytes generation acceptedSeed source probeSession probeTranscript
  cryptographic <- case Ed25519.secretKey privateSeed of
    CryptoFailed _ -> pure (Left [custodyFinding "SEED-CUSTODY-PRIVATE-KEY" "The protected Ed25519 private seed is invalid."])
    CryptoPassed secret -> do
      let public = Ed25519.toPublic secret
          clean = signReceipt secret public generation acceptedSeed source probeSession probeTranscript
          oldGeneration = ByteString.replicate identifierBytes 0x4f
          old = signReceipt secret public oldGeneration acceptedSeed source probeSession probeTranscript
          forged = ByteString.take signedPayloadBytes clean <> ByteString.replicate signatureBytes 0
          cleanResult = verifySeedReceiptCryptography expectation clean
          oldResult = verifySeedReceiptCryptography expectation old
          forgedResult = verifySeedReceiptCryptography expectation forged
          matchingCopyResult = verifySeedReceiptCryptography expectation (ByteString.copy forged)
      pure $ do
        unless (cleanResult == Right ()) $
          Left [custodyFinding "SEED-CUSTODY-PROTECTED-ISSUER" "The protected issuer control did not authenticate."]
        unless (findingResultCode oldResult == Just "SEED-RECEIPT-GENERATION") $
          Left [custodyFinding "SEED-CUSTODY-OLD-GENERATION" "A genuinely signed old-generation receipt did not refuse at generation admission."]
        unless
          ( findingResultCode forgedResult == Just "SEED-RECEIPT-SIGNATURE"
              && findingResultCode matchingCopyResult == Just "SEED-RECEIPT-SIGNATURE"
          ) $
          Left [custodyFinding "SEED-CUSTODY-FORGED-RECEIPT" "A forged receipt or its exact matching copy did not refuse at signature authentication."]
        pure ()
  baseline <- runCandidateProbe request ProbeBaselineReplacement
  ancestor <- runCandidateProbe request ProbeAncestorReplacement
  privateRead <- runCandidateProbe request ProbePrivateRead
  inherited <- runCandidateProbe request ProbeInheritedAuthority
  pure $ do
    _ <- cryptographic
    _ <- collectProbeFindings [baseline, ancestor, privateRead, inherited]
    pure
      ( TextEncoding.encodeUtf8
          ( Text.unlines
              [ "protected-issuer-success\taccepted"
              , "old-generation-refusal\tSEED-RECEIPT-GENERATION"
              , "forged-receipt-matching-copy-refusal\tSEED-RECEIPT-SIGNATURE"
              , "candidate-baseline-replacement-denial\tpermission-denied"
              , "authority-ancestor-replacement-denial\tpermission-denied"
              , "private-issuer-read-denial\tpermission-denied"
              , "inherited-authority-impersonation-denial\tno-authority-inherited"
              ]
          )
      )

collectProbeFindings :: [Either Finding ()] -> Either [Finding] ()
collectProbeFindings results = case [problem | Left problem <- results] of
  [] -> Right ()
  problems -> Left problems

findingResultCode :: Either Finding () -> Maybe Text
findingResultCode result = case result of
  Left problem -> Just (findingCode problem)
  Right () -> Nothing

data CandidateProbe
  = ProbeBaselineReplacement
  | ProbeAncestorReplacement
  | ProbePrivateRead
  | ProbeInheritedAuthority

runCandidateProbe :: SeedCustodyIssueRequest -> CandidateProbe -> IO (Either Finding ())
runCandidateProbe request probe = do
  let executable = seedDirectory request </> "verifier"
      arguments =
        [ "__seed-custody-probe-v1"
        , renderProbe probe
        , seedIssueRepositoryRoot request
        , show (seedIssueCandidateUid request)
        , show (seedIssueCandidateGid request)
        ]
      process =
        (proc executable arguments)
          { env = Just [("PATH", "/usr/bin:/bin")]
          , close_fds = True
          , child_group = Just (fromIntegral (seedIssueCandidateGid request))
          , child_user = Just (fromIntegral (seedIssueCandidateUid request))
          }
  attempted <- try (createProcess process >>= \(_, _, _, handle) -> waitForProcess handle) :: IO (Either IOException ExitCode)
  pure $ case attempted of
    Right ExitSuccess -> Right ()
    _ -> Left (custodyFinding (probeCode probe) ("The candidate-side denial probe failed: " <> Text.pack (show attempted)))

-- | Handle only the non-authoritative candidate probe command.  The command
-- can report a denial outcome but cannot issue a receipt or construct custody.
runSeedCustodyProbeContinuation :: [String] -> IO (Maybe ExitCode)
runSeedCustodyProbeContinuation arguments = case arguments of
  ["__seed-custody-probe-v1", label, root, uidText, gidText]
    | Just probe <- parseProbe label
    , Just uid <- readMaybe uidText
    , Just gid <- readMaybe gidText -> do
        realUid <- getRealUserID
        effectiveUid <- getEffectiveUserID
        if realUid /= fromIntegral (uid :: Word32) || effectiveUid /= fromIntegral uid
          then pure (Just (ExitFailure 2))
          else do
            outcome <-
              candidateProbe
                SeedCustodyIssueRequest
                  { seedIssueRepositoryRoot = root
                  , seedIssueCandidateUid = uid
                  , seedIssueCandidateGid = gid
                  , seedIssueSourceIdentity = ByteString.replicate identifierBytes 0
                  }
                probe
            pure (Just (if outcome then ExitSuccess else ExitFailure 1))
  _ -> pure Nothing

candidateProbe :: SeedCustodyIssueRequest -> CandidateProbe -> IO Bool
candidateProbe request probe = case probe of
  ProbeBaselineReplacement -> permissionDenied $ do
    descriptor <- openFd (seedDirectory request </> "accepted-seed") WriteOnly defaultFileFlags
    closeFd descriptor
  ProbeAncestorReplacement ->
    permissionDenied (rename (seedIssueRepositoryRoot request) (seedIssueRepositoryRoot request <> ".candidate-replacement"))
  ProbePrivateRead -> permissionDenied $ do
    descriptor <- openFd (seedDirectory request </> "issuer.key") ReadOnly defaultFileFlags
    closeFd descriptor
  ProbeInheritedAuthority -> inheritedAuthorityAbsent (seedDirectory request </> "issuer.key")

permissionDenied :: IO () -> IO Bool
permissionDenied action = do
  attempted <- try action :: IO (Either IOException ())
  pure $ case attempted of
    Left problem -> isPermissionError problem
    Right () -> False

inheritedAuthorityAbsent :: FilePath -> IO Bool
inheritedAuthorityAbsent privatePath = do
  environment <- getEnvironment
  descriptors <- try (getDirectoryContents "/proc/self/fd") :: IO (Either IOException [FilePath])
  let authorityEnvironment = any (("AMOEBIUS_CERTIFICATION_" `isPrefixOf`) . fst) environment
  authorityDescriptor <- case descriptors of
    Left _ -> pure True
    Right leaves -> fmap or $ mapM (descriptorTargets privatePath) leaves
  pure (not authorityEnvironment && not authorityDescriptor)

descriptorTargets :: FilePath -> FilePath -> IO Bool
descriptorTargets privatePath leaf =
  case readMaybe leaf :: Maybe Int of
    Nothing -> pure False
    Just descriptor
      | descriptor < 3 -> pure False
      | otherwise -> do
          target <- try (getSymbolicLinkTarget ("/proc/self/fd" </> leaf)) :: IO (Either IOException FilePath)
          pure (either (const False) (== privatePath) target)

probeCode :: CandidateProbe -> Text
probeCode probe = case probe of
  ProbeBaselineReplacement -> "SEED-CUSTODY-BASELINE-REPLACEMENT"
  ProbeAncestorReplacement -> "SEED-CUSTODY-ANCESTOR-REPLACEMENT"
  ProbePrivateRead -> "SEED-CUSTODY-PRIVATE-READ"
  ProbeInheritedAuthority -> "SEED-CUSTODY-INHERITED-AUTHORITY"

renderProbe :: CandidateProbe -> String
renderProbe probe = case probe of
  ProbeBaselineReplacement -> "baseline-replacement"
  ProbeAncestorReplacement -> "ancestor-replacement"
  ProbePrivateRead -> "private-read"
  ProbeInheritedAuthority -> "inherited-authority"

parseProbe :: String -> Maybe CandidateProbe
parseProbe label = case label of
  "baseline-replacement" -> Just ProbeBaselineReplacement
  "ancestor-replacement" -> Just ProbeAncestorReplacement
  "private-read" -> Just ProbePrivateRead
  "inherited-authority" -> Just ProbeInheritedAuthority
  _ -> Nothing

signReceipt
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
signReceipt secret public generation acceptedSeed source session transcript =
  let payload =
        ByteString.concat
          [ "amoebius.seed-receipt.v1\0"
          , ByteString.pack [1, 0]
          , generation
          , acceptedSeed
          , source
          , session
          , transcript
          ]
   in payload <> convert (Ed25519.sign secret public payload)

readAuthorityFile :: FilePath -> IO (Either [Finding] ByteString)
readAuthorityFile path = do
  attempted <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
  pure $ case attempted of
    Left problem -> Left [finding "SEED-CUSTODY-AUTHORITY-READ" path (Text.pack (show problem))]
    Right bytes -> Right bytes

seedDirectory :: SeedCustodyIssueRequest -> FilePath
seedDirectory request = seedIssueRepositoryRoot request </> ".build" </> "validation-seed"

custodyFinding :: Text -> Text -> Finding
custodyFinding code = finding code "<seed-custody-supervisor>"

generationLabel, acceptedSeedDomain :: ByteString
generationLabel = TextEncoding.encodeUtf8 "amoebius-certification-generation-1"
acceptedSeedDomain = "amoebius.accepted-seed.v1\0"

acceptedSeedSourceOffset :: Int
acceptedSeedSourceOffset = ByteString.length acceptedSeedDomain + identifierBytes

identifierBytes :: Int
identifierBytes = 32

signedPayloadBytes, signatureBytes :: Int
signedPayloadBytes = 187
signatureBytes = 64

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex byte =
    let digits = "0123456789abcdef"
        value = fromIntegral byte
     in [digits !! (value `div` 16), digits !! (value `mod` 16)]

digestFields :: [Text] -> Text
digestFields fields = hex (SHA256.hash (ByteString.concat (map frame fields)))
 where
  frame field =
    let bytes = TextEncoding.encodeUtf8 field
     in TextEncoding.encodeUtf8 (Text.pack (show (ByteString.length bytes))) <> ":" <> bytes <> ";"
