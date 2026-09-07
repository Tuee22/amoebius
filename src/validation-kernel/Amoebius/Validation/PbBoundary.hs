{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The post-exec observation continuation for the bounded @pb@ handoff.
--
-- Ordinary invocations return 'Nothing'.  The Phase-50 supervisor supplies a
-- fresh, run-owned protocol directory and starts Python before publishing the
-- challenge.  After @pb@ replaces Python with the source-built executable,
-- this continuation records its own process identity and waits for the
-- external supervisor to acknowledge the live OS observation.
module Amoebius.Validation.PbBoundary
  ( runPbHandoffContinuation
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (encode, object, (.=))
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.Text qualified as Text
import System.Directory
  ( canonicalizePath
  , doesFileExist
  , renameFile
  )
import System.Environment (lookupEnv)
import System.Exit (ExitCode (ExitFailure))
import System.FilePath ((</>))
import System.IO (hClose, openBinaryTempFile)
#if !defined(mingw32_HOST_OS)
import System.Posix.Process (getProcessID)
#endif

-- | Participate in the private Phase-50 observation protocol when selected.
-- The caller must run this before interpreting any public command.
runPbHandoffContinuation :: [String] -> IO (Maybe ExitCode)
runPbHandoffContinuation arguments = do
  selected <- lookupEnv "AMOEBIUS_PB_HANDOFF_PROTOCOL"
  case selected of
    Nothing -> pure Nothing
    Just protocolRoot -> do
      result <- observeHandoff protocolRoot arguments
      pure (Just result)

observeHandoff :: FilePath -> [String] -> IO ExitCode
observeHandoff protocolRoot arguments = do
  challenge <- awaitFile (protocolRoot </> "challenge") 600
  case challenge of
    Nothing -> pure (ExitFailure 74)
    Just canary -> do
      executableResult <- try (canonicalizePath "/proc/self/exe") :: IO (Either IOException FilePath)
#if !defined(mingw32_HOST_OS)
      processIdentifier <- show <$> getProcessID
#else
      let processIdentifier = "unsupported"
#endif
      case executableResult of
        Left _ -> pure (ExitFailure 75)
        Right executable -> do
          let acknowledgement = hexSha256 canary
              payload =
                encode
                  ( object
                      [ "schema" .= ("amoebius-pb-handoff-observation-v1" :: Text.Text)
                      , "pid" .= processIdentifier
                      , "executable" .= executable
                      , "argv" .= arguments
                      , "challengeSha256" .= acknowledgement
                      ]
                  )
          writeAtomic protocolRoot "observation" payload
          accepted <- awaitAcknowledgement (protocolRoot </> "acknowledgement") acknowledgement 600
          pure (if accepted then ExitFailure 73 else ExitFailure 76)

awaitFile :: FilePath -> Int -> IO (Maybe ByteString.ByteString)
awaitFile path attempts
  | attempts <= 0 = pure Nothing
  | otherwise = do
      present <- doesFileExist path
      if present
        then do
          value <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
          case value of
            Right bytes | ByteString.length bytes == 32 -> pure (Just bytes)
            _ -> retry
        else retry
 where
  retry = threadDelay 50000 >> awaitFile path (attempts - 1)

awaitAcknowledgement :: FilePath -> Text.Text -> Int -> IO Bool
awaitAcknowledgement path expected attempts
  | attempts <= 0 = pure False
  | otherwise = do
      present <- doesFileExist path
      if present
        then do
          value <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
          pure (value == Right (encodeUtf8 expected))
        else threadDelay 50000 >> awaitAcknowledgement path expected (attempts - 1)

writeAtomic :: FilePath -> String -> LazyByteString.ByteString -> IO ()
writeAtomic directory name payload = do
  (temporary, handle) <- openBinaryTempFile directory (name <> ".tmp-")
  LazyByteString.hPut handle payload
  hClose handle
  renameFile temporary (directory </> name)

hexSha256 :: ByteString.ByteString -> Text.Text
hexSha256 = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
 where
  byteHex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

encodeUtf8 :: Text.Text -> ByteString.ByteString
encodeUtf8 = ByteString.pack . map (fromIntegral . fromEnum) . Text.unpack
