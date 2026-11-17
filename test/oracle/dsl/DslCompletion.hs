{-# LANGUAGE OverloadedStrings #-}

-- | Completion protocol for the independent typed-spine oracle. Its closed
-- inventory is declared separately from the execution of the checks.
module DslCompletion (completionMain) where

import Control.Exception (IOException, evaluate, throwIO, try)
import Control.Monad (unless)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as Text
import DslInventory (spineInventory)
import DslOracle (coreRowsWithCabal)
import DslParse (renderRow, rowGreen, rowNamed, sha256Hex)
import DslWireDescriptor (preparationRows)
import Data.ByteString qualified as ByteString
import System.Directory (doesDirectoryExist, makeAbsolute)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath ((</>))
import System.IO (hFlush, hSetEncoding, hSetNewlineMode, noNewlineTranslation, stderr, stdout, utf8)
import System.IO.Error (isDoesNotExistError)

completionMain :: [String] -> IO ()
completionMain arguments = do
  hSetEncoding stderr utf8
  hSetNewlineMode stderr noNewlineTranslation
  (challenge, rest) <- case arguments of
    "--oracle-invocation" : value : remaining
      | length value == 64 && all lowerHex value && "--oracle-invocation" `notElem` remaining -> pure (Text.pack value, remaining)
    _ -> refuse "InvocationMalformed"
  case rest of
    ["--oracle-inventory", "wire.prepare.v1"] ->
      emit challenge "wire.prepared-schema\tgreen\tdeclared\nwire.plugin-request\tgreen\tdeclared\n" 2 "all-green" "-"
    ["--oracle-profile", "wire.prepare.v1", supplied] -> do
      directory <- (</> "current") <$> makeAbsolute supplied
      requiredReadBytes challenge (directory </> "PulsarApi.proto")
      requiredReadBytes challenge (directory </> "plugin.request")
      rows <- preparationRows directory
      unless (map rowNamed rows == ["wire.prepared-schema", "wire.plugin-request"]) (refuse "PreparationInventoryMismatch")
      let prefix = Text.unlines (map (Text.pack . renderRow) rows)
          green = all rowGreen rows
      emit challenge prefix (length rows) (if green then "all-green" else "some-red") "-"
      exitWith (if green then ExitSuccess else ExitFailure 1)
    ["--oracle-inventory", profile] -> do
      withBinary <- profileValue profile
      let names = spineInventory withBinary
      emit challenge (Text.unlines [name <> "\tgreen\tdeclared" | name <- names]) (length names) "all-green" "-"
    "--oracle-profile" : profile : options -> do
      withBinary <- profileValue profile
      (cabal, compiler, buildDirectory, supplied) <- case options of
        [directory] -> pure (Nothing, Nothing, ".build/dist-native", directory)
        ["--builddir", directory, suite] -> pure (Nothing, Nothing, directory, suite)
        ["--builddir", directory, "--ghc", ghc, suite] -> pure (Nothing, Just ghc, directory, suite)
        ["--builddir", directory, "--cabal", tool, suite] -> pure (Just tool, Nothing, directory, suite)
        ["--builddir", directory, "--cabal", tool, "--ghc", ghc, suite] -> pure (Just tool, Just ghc, directory, suite)
        _ -> refuse "InvocationArguments"
      directory <- makeAbsolute supplied
      present <- doesDirectoryExist directory
      unless present (refuse "InvocationDirectoryRequired")
      requiredRead challenge (directory </> "complete.marker")
      rows <- coreRowsWithCabal cabal compiler buildDirectory directory
      let prefix = Text.unlines (map (Text.pack . renderRow) rows)
          green = not (null rows) && all rowGreen rows
          hasBinary = any ((== "case:shipped-binary") . Text.takeWhile (/= '\t') . Text.pack . renderRow) rows
      unless (hasBinary == withBinary) (refuse "BinaryProfileMismatch")
      emit challenge prefix (length rows) (if green then "all-green" else "some-red") "-"
      exitWith (if green then ExitSuccess else ExitFailure 1)
    _ -> refuse "InvocationArguments"
 where
  lowerHex character = ('0' <= character && character <= '9') || ('a' <= character && character <= 'f')
  profileValue value = case value of
    "spine.full.v1" -> pure False
    "spine.gate.v1" -> pure True
    _ -> refuse "InventoryProfileUnknown"

refuse :: String -> IO a
refuse reason = Text.hPutStrLn stderr ("oracle-dsl: " <> Text.pack reason) >> exitWith (ExitFailure 2)

requiredRead :: Text.Text -> FilePath -> IO ()
requiredRead challenge path = do
  result <- try (Text.readFile path >>= \body -> evaluate (Text.length body)) :: IO (Either IOException Int)
  case result of
    Right _ -> pure ()
    Left problem | isDoesNotExistError problem -> do
      Text.hPutStrLn stderr (Text.pack (show problem))
      hFlush stderr
      emit challenge "" 0 "required-input-missing" (Text.pack (show (Text.pack path)))
      exitWith (ExitFailure 1)
    Left problem -> throwIO problem

requiredReadBytes :: Text.Text -> FilePath -> IO ()
requiredReadBytes challenge path = do
  result <- try (ByteString.readFile path >>= \body -> evaluate (ByteString.length body)) :: IO (Either IOException Int)
  case result of
    Right _ -> pure ()
    Left problem | isDoesNotExistError problem -> do
      Text.hPutStrLn stderr (Text.pack (show problem))
      hFlush stderr
      emit challenge "" 0 "required-input-missing" (Text.pack (show (Text.pack path)))
      exitWith (ExitFailure 1)
    Left problem -> throwIO problem

emit :: Text.Text -> Text.Text -> Int -> Text.Text -> Text.Text -> IO ()
emit challenge prefix count purpose locus = do
  let footer = Text.intercalate "\t" ["oracle.protocol.complete.v1", "green", "retained-text-utf8.v1", challenge, Text.pack (show count), sha256Hex (Encoding.encodeUtf8 prefix), purpose, locus] <> "\n"
  _ <- evaluate (Text.length prefix + Text.length footer)
  hSetEncoding stdout utf8
  hSetNewlineMode stdout noNewlineTranslation
  Text.hPutStr stdout prefix
  hFlush stdout
  Text.hPutStr stdout footer
  hFlush stdout
