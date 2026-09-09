{-# LANGUAGE CPP #-}
{-# LANGUAGE CApiFFI #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Inspect prerequisites without creating an accepted seed or custody token.
--
-- The initial supervisor design uses real/effective UID zero and a distinct
-- non-reserved candidate UID. Every authority-bearing ancestor must be owned
-- by UID zero and deny group/other writes. Directories are opened with
-- no-follow and close-on-exec. Leaf metadata uses descriptor-relative fstatat
-- without following symlinks or opening payload endpoints. This function never
-- reads private key bytes or changes permissions.
--
-- These observations cannot establish irreversible credential separation,
-- capability/ACL policy, inherited-descriptor cleanup, candidate denial, oracle
-- provenance, or issuer qualification. Even a matching layout retains an
-- explicit unqualified finding. No observation or supplied request is accepted
-- as a gate input; the real supervisor and seven-case corpus remain required.
module Amoebius.Validation.SeedCustodyPrerequisites.Internal
  ( SeedCustodyRequest (..)
  , seedCustodyPrerequisitesDiagnostic
  , ProtectedFile (..)
  , seedCustodyFileMetadataDiagnostic
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..), Finding, Observation, finding, observation )
import Data.Char (isControl)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word32)
import System.Info qualified as SystemInfo

#if !defined(mingw32_HOST_OS)
import Control.Exception (IOException, bracket, displayException, try)
import Data.Bits ((.&.))
import Foreign.C.Error (throwErrnoIfMinus1Retry_)
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt (..))
import Foreign.ForeignPtr (withForeignPtr)
import Foreign.Ptr (Ptr, castPtr)
import System.FilePath ((</>))
import System.Posix.Files
  ( FileStatus (..), deviceID, fileID, fileMode, fileOwner, fileSize, getFdStatus
  , isDirectory, isRegularFile, linkCount )
import System.Posix.IO
  ( OpenFileFlags (cloexec, directory, nofollow, nonBlock)
  , OpenMode (ReadOnly), closeFd, defaultFileFlags, openFd, openFdAt )
import System.Posix.Types (Fd (..))
import System.Posix.User (getEffectiveUserID, getRealUserID)

foreign import capi unsafe "sys/stat.h fstatat"
  cFstatAt :: CInt -> CString -> Ptr () -> CInt -> IO CInt
foreign import capi unsafe "fcntl.h value AT_SYMLINK_NOFOLLOW"
  atSymlinkNoFollow :: CInt
#endif

data SeedCustodyRequest = SeedCustodyRequest
  { seedCustodyRepositoryRoot :: FilePath
  , seedCustodyCandidateUid :: Word32
  }
  deriving (Eq, Show)

seedCustodyPrerequisitesDiagnostic :: SeedCustodyRequest -> IO CheckResult
seedCustodyPrerequisitesDiagnostic request =
  case absoluteComponents (seedCustodyRepositoryRoot request) of
    Nothing -> pure (result request [] [rootFinding])
    Just components
      | candidate == 0 || candidate == maxBound ->
          pure (result request [] [candidateFinding])
      | otherwise -> inspectRequest request components
  where
    candidate = seedCustodyCandidateUid request

absoluteComponents :: FilePath -> Maybe [FilePath]
absoluteComponents path
  | length (take 4097 path) > 4096 = Nothing
  | ByteString.length (TextEncoding.encodeUtf8 (Text.pack path)) > 4096 = Nothing
  | any isControl path = Nothing
  | path == "/" = Just []
  | otherwise = case Text.splitOn "/" (Text.pack path) of
      "" : components
        | not (null components) && length components <= 64 && all valid components ->
            Just (map Text.unpack components)
      _ -> Nothing
  where
    valid part = not (Text.null part) && part /= "." && part /= ".."

result :: SeedCustodyRequest -> [Observation] -> [Finding] -> CheckResult
result request observations problems =
  CheckResult
    { checkName = "seed-custody-prerequisites"
    , checkObservations =
        [ observation "seed-custody.status" "NOT QUALIFIED"
        , observation "seed-custody.platform" (Text.pack SystemInfo.os)
        , observation "seed-custody.candidate-uid" (Text.pack (show (seedCustodyCandidateUid request)))
        ] <> observations
    , checkFindings = problems <> [unqualifiedFinding]
    }

rootFinding, candidateFinding, unqualifiedFinding, platformFinding :: Finding
rootFinding = custodyFinding "SEED-CUSTODY-ROOT"
  "The protected repository root must be an absolute normalized path of at most 4096 UTF-8 bytes and 64 components, without control characters, dot, or parent components."
candidateFinding = custodyFinding "SEED-CUSTODY-CANDIDATE"
  "The candidate UID must be nonzero, non-reserved, and different from the supervisor real and effective UIDs."
unqualifiedFinding = custodyFinding "SEED-CUSTODY-NOT-QUALIFIED"
  "Path and identity prerequisites do not qualify OS custody; candidate credential, inherited-authority, and denial probes remain required."
platformFinding = custodyFinding "SEED-CUSTODY-PLATFORM"
  "The planned seed custody supervisor requires the pinned Linux platform; no supervisor is qualified yet."

custodyFinding :: Text -> Text -> Finding
custodyFinding code = finding code "<seed-custody>"

inspectRequest :: SeedCustodyRequest -> [FilePath] -> IO CheckResult
#if defined(mingw32_HOST_OS)
inspectRequest request _ = pure (result request [] [platformFinding])
#else
inspectRequest request components = do
  realUid <- getRealUserID
  effectiveUid <- getEffectiveUserID
  if fromIntegral realUid == candidate || fromIntegral effectiveUid == candidate
    then pure (result request [] [candidateFinding])
    else do
      inspected <- inspectLayout components
      let identityObservations =
            [ observation "seed-custody.supervisor-real-uid" (Text.pack (show realUid))
            , observation "seed-custody.supervisor-effective-uid" (Text.pack (show effectiveUid))
            ]
          floors =
            [platformFinding | SystemInfo.os /= "linux"]
              <> [ custodyFinding "SEED-CUSTODY-SUPERVISOR"
                     "The initial seed supervisor requires real and effective UID zero before candidate privilege separation."
                 | realUid /= 0 || effectiveUid /= 0 ]
      pure $ case inspected of
        Left problem -> result request identityObservations (floors <> [problem])
        Right observed -> result request (identityObservations <> observed) floors
  where
    candidate = seedCustodyCandidateUid request
#endif

-- | A non-admitting diagnostic used to exercise file-kind inspection on native
-- scratch fixtures. It checks one leaf, not ancestor permissions, credentials,
-- accepted input bytes, or custody. No descriptor or authority token escapes.
seedCustodyFileMetadataDiagnostic :: FilePath -> ProtectedFile -> IO CheckResult
seedCustodyFileMetadataDiagnostic path role = do
  inspected <- case absoluteComponents path of
    Nothing -> pure (Left rootFinding)
    Just [] -> pure (Left rootFinding)
#if defined(mingw32_HOST_OS)
    Just _ -> pure (Left platformFinding)
#else
    Just components -> inspectAt path $
      withParent (init components) $ \parent -> do
        status <- fileStatusAtNoFollow parent (last components)
        pure $ case fileProblem path role status of
          Just problem -> Left problem
          Nothing -> Right [pathObservation path status]
#endif
  pure CheckResult
    { checkName = "seed-custody-file-metadata"
    , checkObservations =
        [ observation "seed-custody.status" "NOT QUALIFIED"
        , observation "seed-custody.scope" "leaf-metadata-only; ancestors-and-credentials-unverified"
        ] <> either (const []) id inspected
    , checkFindings = either (: []) (const []) inspected <> [unqualifiedFinding]
    }
#if !defined(mingw32_HOST_OS)
  where
    withParent components action =
      bracket (openFd "/" ReadOnly directoryFlags) closeFd $ \root ->
        walk root components action
    walk parent [] action = action parent
    walk parent (part : rest) action =
      bracket (openFdAt (Just parent) part ReadOnly directoryFlags) closeFd $ \child ->
        walk child rest action
#endif

data ProtectedFile = AcceptedSeed | VerifierExecutable | OracleExecutable | IssuerPrivateKey | IssuerPublicKey
  deriving (Eq, Show)

#if !defined(mingw32_HOST_OS)

-- Each open is relative to its held, inspected parent, starting at '/'.
-- No canonicalizePath/reopen pair can follow a substituted symlink.
inspectLayout :: [FilePath] -> IO (Either Finding [Observation])
inspectLayout components =
  inspectAt "/" $
    bracket (openFd "/" ReadOnly directoryFlags) closeFd $ \rootFd ->
      descend rootFd "/" (components <> [".build", "validation-seed"])

descend :: Fd -> FilePath -> [FilePath] -> IO (Either Finding [Observation])
descend descriptor path remaining = do
  before <- getFdStatus descriptor
  case directoryProblem path before of
    Just problem -> pure (Left problem)
    Nothing -> do
      inspected <- case remaining of
        [] -> inspectFiles descriptor path protectedFiles
        child : rest -> inspectAt (path </> child) $
          bracket (openFdAt (Just descriptor) child ReadOnly directoryFlags) closeFd $ \childFd ->
            descend childFd (path </> child) rest
      after <- getFdStatus descriptor
      pure $ if not (sameStatus before after)
        then Left (finding "SEED-CUSTODY-CHANGED" path "An authority directory changed during inspection.")
        else fmap (pathObservation path before :) inspected

protectedFiles :: [(FilePath, ProtectedFile)]
protectedFiles =
  [ ("accepted-seed", AcceptedSeed)
  , ("verifier", VerifierExecutable)
  , ("oracle", OracleExecutable)
  , ("issuer.key", IssuerPrivateKey)
  , ("issuer.pub", IssuerPublicKey)
  ]

inspectFiles :: Fd -> FilePath -> [(FilePath, ProtectedFile)] -> IO (Either Finding [Observation])
inspectFiles _ _ [] = pure (Right [])
inspectFiles parent path ((leaf, role) : rest) = do
  checked <- inspectAt (path </> leaf) $ do
    status <- fileStatusAtNoFollow parent leaf
    pure $ case fileProblem (path </> leaf) role status of
      Just problem -> Left problem
      Nothing -> Right (pathObservation (path </> leaf) status)
  case checked of
    Left problem -> pure (Left problem)
    Right observed -> fmap (fmap (observed :)) (inspectFiles parent path rest)

-- Metadata only: never open a device, FIFO, socket, or private-key payload.
-- getFdStatus supplies a fresh ABI-correct stat buffer from the unix library;
-- fstatat overwrites that private buffer without assuming a struct-stat size.
-- The FileStatus constructor is an internal compatibility dependency of unix
-- 2.8.x. No earlier parent observation aliases this newly allocated buffer.
fileStatusAtNoFollow :: Fd -> FilePath -> IO FileStatus
fileStatusAtNoFollow parent@(Fd descriptor) leaf = do
  status@(FileStatus buffer) <- getFdStatus parent
  withForeignPtr buffer $ \pointer ->
    withCString leaf $ \name ->
      throwErrnoIfMinus1Retry_ "seed-custody-fstatat" $
        cFstatAt descriptor name (castPtr pointer) atSymlinkNoFollow
  pure status

directoryProblem :: FilePath -> FileStatus -> Maybe Finding
directoryProblem path status
  | not (isDirectory status) = Just (finding "SEED-CUSTODY-KIND" path "An authority ancestor is not a directory.")
  | fileOwner status /= 0 = Just (finding "SEED-CUSTODY-OWNER" path "Every authority-bearing ancestor must be owned by UID zero.")
  | fileMode status .&. 0o022 /= 0 = Just (finding "SEED-CUSTODY-WRITABLE" path "An authority ancestor permits group or other writes.")
  | otherwise = Nothing

fileProblem :: FilePath -> ProtectedFile -> FileStatus -> Maybe Finding
fileProblem path role status
  | not (isRegularFile status) = problem "SEED-CUSTODY-KIND" "An authority input is not a regular file."
  | fileOwner status /= 0 = problem "SEED-CUSTODY-OWNER" "Every authority input must be owned by UID zero."
  | linkCount status /= 1 = problem "SEED-CUSTODY-LINKS" "An authority input must have exactly one link."
  | fileMode status .&. 0o7022 /= 0 = problem "SEED-CUSTODY-MODE" "An authority input has special mode bits or permits group or other writes."
  | fileSize status <= 0 = problem "SEED-CUSTODY-SIZE" "An authority input is empty."
  | otherwise = case role of
      IssuerPrivateKey
        | fileMode status .&. 0o777 /= 0o600 -> problem "SEED-CUSTODY-PRIVATE-MODE" "Private issuer state must have mode 0600."
        | fileSize status /= 32 -> problem "SEED-CUSTODY-KEY-SIZE" "The Ed25519 private seed must contain exactly 32 bytes."
      IssuerPublicKey
        | fileSize status /= 32 -> problem "SEED-CUSTODY-KEY-SIZE" "The Ed25519 public key must contain exactly 32 bytes."
      VerifierExecutable -> executableProblem
      OracleExecutable -> executableProblem
      _ -> Nothing
  where
    problem code detail = Just (finding code path detail)
    executableProblem
      | fileMode status .&. 0o100 == 0 = problem "SEED-CUSTODY-EXECUTABLE" "An authority executable lacks owner execute permission."
      | otherwise = Nothing

sameStatus :: FileStatus -> FileStatus -> Bool
-- This is held-object metadata equality, not namespace or content freshness.
sameStatus left right =
  deviceID left == deviceID right && fileID left == fileID right
    && fileOwner left == fileOwner right && fileMode left == fileMode right

pathObservation :: FilePath -> FileStatus -> Observation
pathObservation path status = observation "seed-custody.path-metadata"
  (Text.pack (show (path, deviceID status, fileID status, fileOwner status, fileMode status)))

inspectAt :: FilePath -> IO (Either Finding value) -> IO (Either Finding value)
inspectAt path action = do
  attempted <- try action
  pure $ case attempted of
    Left (problem :: IOException) -> Left (finding "SEED-CUSTODY-INSPECTION" path
      ("Read-only inspection failed; this is not a candidate-denial observation: "
        <> Text.take 512 (Text.map clean (Text.pack (displayException problem)))))
    Right inspected -> inspected
  where
    clean character | isControl character = ' '
                    | otherwise = character

directoryFlags :: OpenFileFlags
directoryFlags = defaultFileFlags {cloexec = True, directory = True, nofollow = True, nonBlock = True}
#endif
