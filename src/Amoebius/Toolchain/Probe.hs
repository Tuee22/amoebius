{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The retained probe set (phase_01, Sprints 1.2, 1.3, 1.4 and 1.8): the
-- in-process Dhall decoder, the deterministic simulator, the protobuf codegen
-- link, and the browser-contract generator. Each probe is a Haskell value the
-- report exercises; its cases are rendered beneath @.build/**@ after a run
-- starts and its outcomes are literals the oracle restates.
module Amoebius.Toolchain.Probe
  ( DecodeOutcome (..)
  , ProbeConfig (..)
  , ProbeContract (..)
  , ProbeRefusal (..)
  , Schedule (..)
  , Writer (..)
  , bridgeProbe
  , cleanSchedule
  , codegenProbe
  , decodeCase
  , decodeProbe
  , linkToken
  , mistypedCase
  , perturbedSchedule
  , positiveCase
  , probeProto
  , renderDecodeOutcome
  , renderProbeRefusal
  , renderSchedule
  , simProbe
  ) where

import Amoebius.Toolchain.Acquire (ChildRecord (..), spawnChild)
import Control.Exception (SomeException, finally, fromException, try)
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import System.IO (IOMode (WriteMode), hClose, hFlush, openFile, stdout)
import Control.Monad (filterM)
import Control.Monad.Class.MonadFork (MonadFork (..))
import Control.Concurrent.Class.MonadSTM.TVar (newTVarIO, readTVarIO, writeTVar)
import Control.Monad.Class.MonadSTM (MonadSTM (..))
import Control.Monad.Class.MonadTimer (MonadDelay (..))
import Control.Monad.IOSim (IOSim, runSimOrThrow)
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.ProtoLens.Encoding.Bytes (putBytes, putVarInt, runBuilder)
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Void (Void)
import Dhall (FromDhall, auto, inputFile)
import Dhall.Src (Src)
import Dhall.TypeCheck (TypeError)
import GHC.Generics (Generic)
import Language.PureScript.Bridge (buildBridge, defaultBridge, writePSTypes)
import Language.PureScript.Bridge.SumType (mkSumType)
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, listDirectory)
import System.FilePath (makeRelative, (</>))

data ProbeRefusal
  = CodegenToolAbsent Text
  | CodegenFailed Text
  deriving (Eq, Show)

renderProbeRefusal :: ProbeRefusal -> Text
renderProbeRefusal refusal = case refusal of
  CodegenToolAbsent tool -> "CodegenToolAbsent: " <> tool
  CodegenFailed detail -> "CodegenFailed: " <> detail

-- * The in-process decoder

-- | The typed value the positive case must decode to.
data ProbeConfig = ProbeConfig
  { probeName :: Text
  , probeReplicas :: Natural
  , probeEnabled :: Bool
  }
  deriving (Eq, Generic, Show, FromDhall)

positiveCase :: Text
positiveCase = "{ probeName = \"amoebius\", probeReplicas = 3, probeEnabled = True }\n"

-- | The twin with one field mistyped: a text where a natural is expected.
mistypedCase :: Text
mistypedCase = "{ probeName = \"amoebius\", probeReplicas = \"3\", probeEnabled = True }\n"

data DecodeOutcome
  = Decoded Text
  | DecodeRefused Text
  deriving (Eq, Show)

renderDecodeOutcome :: DecodeOutcome -> Text
renderDecodeOutcome outcome = case outcome of
  Decoded value -> "decoded " <> value
  DecodeRefused tag -> "refused " <> tag

-- | Render one case beneath the directory and decode it in-process.
decodeCase :: FilePath -> Text -> Text -> IO DecodeOutcome
decodeCase directory name source = do
  createDirectoryIfMissing True directory
  let path = directory </> (Text.unpack name <> ".dhall")
  TextIO.writeFile path source
  attempt <- try (inputFile auto path) :: IO (Either SomeException ProbeConfig)
  pure $ case attempt of
    Right value -> Decoded (probeName value <> "/" <> Text.pack (show (probeReplicas value)) <> "/" <> Text.pack (show (probeEnabled value)))
    Left problem -> DecodeRefused (classify problem)
 where
  classify problem = case fromException problem :: Maybe (TypeError Src Void) of
    Just _ -> "type-error"
    Nothing -> "unexpected:" <> Text.take 60 (Text.pack (takeWhile (/= '\n') (show problem)))

decodeProbe :: FilePath -> IO [(Text, DecodeOutcome)]
decodeProbe directory = do
  positive <- decodeCase directory "positive" positiveCase
  mistyped <- decodeCase directory "mistyped" mistypedCase
  pure [("positive", positive), ("mistyped", mistyped)]

-- * The deterministic simulator

-- | One writer: its name, the simulated delay before it writes, and its value.
data Writer = Writer
  { writerName :: Text
  , writerDelay :: Int
  , writerValue :: Int
  }
  deriving (Eq, Show)

newtype Schedule = Schedule {scheduleWriters :: [Writer]}
  deriving (Eq, Show)

renderSchedule :: Schedule -> Text
renderSchedule (Schedule writers) = Text.intercalate "," [writerName w <> "@" <> Text.pack (show (writerDelay w)) <> "=" <> Text.pack (show (writerValue w)) | w <- writers]

-- | Two writers race for one cell; the later delay wins.
cleanSchedule :: Schedule
cleanSchedule = Schedule [Writer "a" 10 1, Writer "b" 20 2]

-- | The same writers with the first delay moved past the second.
perturbedSchedule :: Schedule
perturbedSchedule = Schedule [Writer "a" 30 1, Writer "b" 20 2]

-- | The terminal state of the cell under the schedule, run deterministically.
simProbe :: Schedule -> Text
simProbe (Schedule writers) = runSimOrThrow (simulation writers)

simulation :: [Writer] -> IOSim s Text
simulation writers = do
  cell <- newTVarIO "none"
  mapM_ (\writer -> forkIO (threadDelay (writerDelay writer) >> atomically (writeTVar cell (writerName writer <> ":" <> Text.pack (show (writerValue writer)))))) writers
  threadDelay (maximum (0 : map writerDelay writers) + 1)
  readTVarIO cell

-- * The protobuf codegen link

-- | The schema the codegen probe renders; a Haskell value, never a tracked file.
probeProto :: Text
probeProto =
  Text.unlines
    [ "syntax = \"proto3\";"
    , "package amoebius.probe;"
    , "message ProbeMessage {"
    , "  string name = 1;"
    , "  uint32 replicas = 2;"
    , "}"
    ]

-- | The wire bytes of @ProbeMessage{name=\"amoebius\", replicas=3}@ produced by
-- the runtime library linked into this binary, as lowercase hex.
linkToken :: Text
linkToken = Text.pack (concatMap byteHex (ByteString.unpack encoded))
 where
  encoded = runBuilder (putVarInt 10 <> putVarInt 8 <> putBytes "amoebius" <> putVarInt 16 <> putVarInt 3)
  byteHex value = [digit (fromIntegral value `div` 16), digit (fromIntegral value `mod` 16)]
  digit n = "0123456789abcdef" !! (n :: Int)

-- | Render the schema and run the codegen tool over it beneath the directory,
-- returning the generated module files relative to the output root.
codegenProbe :: FilePath -> FilePath -> FilePath -> IO (Either ProbeRefusal ([FilePath], ChildRecord))
codegenProbe protoc plugin directory = do
  let output = directory </> "generated"
  createDirectoryIfMissing True output
  TextIO.writeFile (directory </> "probe.proto") probeProto
  (child, _, err) <- spawnChild directory protoc ["--plugin=protoc-gen-haskell=" <> plugin, "--haskell_out=" <> output, "-I", directory, "probe.proto"]
  if childExit child == 127
    then pure (Left (CodegenToolAbsent (Text.pack protoc)))
    else
      if childExit child /= 0
        then pure (Left (CodegenFailed (Text.strip (Text.pack (take 200 err)))))
        else do
          files <- filesBeneath output
          pure (Right (sort (map (makeRelative output) files), child))

-- * The browser-contract generator

-- | The contract the bridge renders to PureScript.
data ProbeContract = ProbeContract
  { contractName :: Text
  , contractReplicas :: Int
  }
  deriving (Eq, Generic, Show)

-- | Render the contract beneath the directory and return the generated files.
bridgeProbe :: FilePath -> IO [FilePath]
bridgeProbe directory = do
  createDirectoryIfMissing True directory
  silently (writePSTypes directory (buildBridge defaultBridge) [mkSumType (Proxy :: Proxy ProbeContract)])
  files <- filesBeneath directory
  pure (sort (map (makeRelative directory) files))

-- | Run an action with standard output routed to the null device: the bridge
-- library narrates on stdout, and a report's stdout is rows only.
silently :: IO a -> IO a
silently action = do
  saved <- hDuplicate stdout
  hFlush stdout
  sink <- openFile "/dev/null" WriteMode
  hDuplicateTo sink stdout
  result <- action `finally` (hFlush stdout >> hDuplicateTo saved stdout >> hClose sink >> hClose saved)
  pure result

filesBeneath :: FilePath -> IO [FilePath]
filesBeneath directory = do
  names <- listDirectory directory
  directories <- filterM (doesDirectoryExist . (directory </>)) names
  nested <- concat <$> mapM (filesBeneath . (directory </>)) directories
  pure ([directory </> name | name <- names, name `notElem` directories] <> nested)
