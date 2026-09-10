{-# LANGUAGE OverloadedStrings #-}

module SeedCustodySupervisorOracle (main) where

import Amoebius.Validation.SeedCustodySupervisor.Internal
  ( SeedCustodyIssueRequest (..)
  , foldQualifiedSeedCustody
  , qualifyAndIssueSeedCustody
  , issueQualifiedPhasePassReceipt
  , runSeedCustodyProbeContinuation
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Observation (..)
  , checkPassed
  )
import Control.Exception (bracket)
import Control.Monad (unless)
import Crypto.Error (CryptoFailable (..))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (digitToInt)
import Data.Text qualified as Text
import Data.Word (Word8)
import System.Directory
  ( copyFile
  , createDirectory
  , createDirectoryIfMissing
  , removePathForcibly
  )
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory)
import System.Environment (getArgs, getExecutablePath)
import System.Exit (exitWith)
import System.Posix.Files (setFileMode)
import System.Posix.Process (getProcessID)
import System.Posix.User (getEffectiveUserID)

main :: IO ()
main = do
  arguments <- getArgs
  continuation <- runSeedCustodyProbeContinuation arguments
  case continuation of
    Just outcome -> exitWith outcome
    Nothing -> do
      effectiveUid <- getEffectiveUserID
      unless (effectiveUid == 0) $ fail "SeedCustodySupervisorOracle must run under the UID-zero test supervisor"
      process <- getProcessID
      let fixedParent = "/var/lib" </> ("amoebius-seed-custody-test-" <> show process)
      bracket
        (createFixture fixedParent)
        (const (removePathForcibly fixedParent))
        runFixture

createFixture :: FilePath -> IO FilePath
createFixture parent = do
  createDirectory parent
  setFileMode parent 0o755
  repository <- createTempDirectory parent "repository-"
  setFileMode repository 0o755
  let seed = repository </> ".build" </> "validation-seed"
  createDirectoryIfMissing True seed
  setFileMode (repository </> ".build") 0o755
  setFileMode seed 0o755
  executable <- getExecutablePath
  copyFile executable (seed </> "verifier")
  setFileMode (seed </> "verifier") 0o755
  writeProtected (seed </> "oracle") 0o755 "independent-oracle-binary"
  verifierBytes <- ByteString.readFile (seed </> "verifier")
  oracleBytes <- ByteString.readFile (seed </> "oracle")
  writeProtected
    (seed </> "accepted-seed")
    0o444
    ( ByteString.concat
        [ "amoebius.accepted-seed.v1\0"
        , SHA256.hash "amoebius-certification-generation-1"
        , ByteString.replicate 32 0x73
        , SHA256.hash verifierBytes
        , SHA256.hash oracleBytes
        , word32be 65534
        , word32be 65534
        ]
    )
  writeProtected (seed </> "issuer.key") 0o600 secretSeed
  writeProtected (seed </> "issuer.pub") 0o644 publicKey
  pure repository

runFixture :: FilePath -> IO ()
runFixture repository = do
  result <-
    qualifyAndIssueSeedCustody
      SeedCustodyIssueRequest
        { seedIssueRepositoryRoot = repository
        , seedIssueCandidateUid = 65534
        , seedIssueCandidateGid = 65534
        , seedIssueSourceIdentity = ByteString.replicate 32 0x73
        }
  case result of
    Left problems -> fail ("SeedCustodySupervisorOracle refused the qualified fixture: " <> show problems)
    Right qualified -> do
      phaseReceipt <-
        issueQualifiedPhasePassReceipt qualified 0
          (hexBytes 0x73) (hexBytes 0x74) (hexBytes 0x75) (hexBytes 0x76)
          (hexBytes 0x77) (hexBytes 0x78) (hexBytes 0x79) (hexBytes 0x7a)
      case phaseReceipt of
        Left problems -> fail ("SeedCustodySupervisorOracle could not issue a qualified phase receipt: " <> show problems)
        Right bytes -> unless (ByteString.length bytes > 400) $ fail "SeedCustodySupervisorOracle emitted a truncated phase receipt"
      foldQualifiedSeedCustody checkQualified qualified

checkQualified
  :: ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> CheckResult
  -> IO ()
checkQualified generation accepted source session transcript public receipt result = do
  mapM_ (expectWidth 32)
    [ ("generation", generation)
    , ("accepted seed", accepted)
    , ("source", source)
    , ("session", session)
    , ("transcript", transcript)
    , ("public key", public)
    ]
  expectWidth 251 ("receipt", receipt)
  unless (source == ByteString.replicate 32 0x73) $
    fail "SeedCustodySupervisorOracle lost the acquired source binding"
  unless (public == publicKey) $
    fail "SeedCustodySupervisorOracle admitted a substituted issuer public key"
  unless (checkPassed result && null (checkFindings result)) $
    fail ("SeedCustodySupervisorOracle expected one green integrated result: " <> show result)
  unless
    (lookup "seed-custody.oracle-cases" [(Text.unpack key, Text.unpack value) | observation <- checkObservations result, let key = observationKey observation, let value = observationValue observation] == Just "7") $
    fail "SeedCustodySupervisorOracle did not retain the exact seven-case oracle count"

expectWidth :: Int -> (String, ByteString) -> IO ()
expectWidth expected (label, bytes) =
  unless (ByteString.length bytes == expected) $
    fail ("SeedCustodySupervisorOracle wrong " <> label <> " width")

writeProtected :: FilePath -> Int -> ByteString -> IO ()
writeProtected path mode bytes = do
  ByteString.writeFile path bytes
  setFileMode path (fromIntegral mode)

secretSeed :: ByteString
secretSeed = decodeHex "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"

publicKey :: ByteString
publicKey = case Ed25519.secretKey secretSeed of
  CryptoFailed problem -> error (show problem)
  CryptoPassed secret -> convert (Ed25519.toPublic secret)

decodeHex :: String -> ByteString
decodeHex [] = ByteString.empty
decodeHex (high : low : rest) =
  ByteString.cons (fromIntegral (digitToInt high * 16 + digitToInt low)) (decodeHex rest)
decodeHex _ = error "odd hexadecimal fixture"

hexBytes :: Word8 -> Text.Text
hexBytes byte = Text.pack (concat (replicate 32 [digits !! high, digits !! low]))
 where
  digits = "0123456789abcdef"
  value = fromIntegral byte
  high = value `div` 16
  low = value `mod` 16

word32be :: Int -> ByteString
word32be value =
  ByteString.pack
    [ fromIntegral (value `div` 16777216)
    , fromIntegral (value `div` 65536)
    , fromIntegral (value `div` 256)
    , fromIntegral value
    ]
