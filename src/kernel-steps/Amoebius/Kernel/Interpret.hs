{-# LANGUAGE OverloadedStrings #-}

-- | The only executor of steps. A step is data; this module reads it and, for an apply
-- step, hands its payload to a @kubectl@ process. The one executor this phase admits is a
-- fake: a copy of the running program named @kubectl@, which records
-- what it received and writes nothing to a cluster.
module Amoebius.Kernel.Interpret
  ( Executor (..)
  , InterpretRefusal (..)
  , interpretRefusalTag
  , StepReceipt (..)
  , stepArguments
  , stepRun
  , runChainFromFrame
  , Planned (..)
  , dryRun
  , renderDryRun
  , sha256Hex
  , materializeFake
  , runFakeKubectl
  ) where

import Amoebius.Kernel.Step
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.Char (intToDigit)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist, doesPathExist, exeExtension, makeAbsolute, removeFile)
import System.Environment (getArgs, getEnvironment, getProgName, lookupEnv)
import System.Exit (ExitCode (ExitFailure, ExitSuccess), exitWith)
import System.FilePath ((</>))
import System.IO (Handle, hClose)
import System.Process (CreateProcess (cwd, env, std_err, std_in, std_out), ProcessHandle, StdStream (CreatePipe), createProcess, proc, waitForProcess)

-- | Where a step's payload goes. There is no constructor for a real cluster yet.
data Executor = FakeKubectl
  { fakeExecutable :: FilePath
  , fakeTranscript :: FilePath
  }
  deriving stock (Eq, Show)

data InterpretRefusal
  = UnsupportedStepKind StepKind
  | ExecutorFailed Text Int
  | ExecutorUnavailable Text
  deriving stock (Eq, Show)

-- | The stable tag of a refusal: the name of its constructor.
interpretRefusalTag :: InterpretRefusal -> Text
interpretRefusalTag refusal = case refusal of
  UnsupportedStepKind _ -> "UnsupportedStepKind"
  ExecutorFailed _ _ -> "ExecutorFailed"
  ExecutorUnavailable _ -> "ExecutorUnavailable"

data StepReceipt = StepReceipt
  { receiptLabel :: Text
  , receiptPayloadSha256 :: Text
  , receiptOutput :: Text
  }
  deriving stock (Eq, Show)

-- | The arguments the executor passes for a step. The dry run and the run read this one
-- function, so they cannot disagree.
stepArguments :: Step -> Either InterpretRefusal [String]
stepArguments step = case stepKind step of
  ApplyObjects -> Right ["apply", "--server-side=true", "-f", "-"]
  other -> Left (UnsupportedStepKind other)

-- | Run one step through the executor.
stepRun :: Executor -> Step -> IO (Either InterpretRefusal StepReceipt)
stepRun executor step = case stepArguments step of
  Left refusal -> pure (Left refusal)
  Right arguments -> do
    let payload = stepPayload step
    spawned <- spawn executor arguments payload
    pure $ case spawned of
      Left problem -> Left (ExecutorUnavailable problem)
      Right (ExitSuccess, output) -> Right (StepReceipt (stepLabel step) (sha256Hex payload) output)
      Right (ExitFailure code, _) -> Left (ExecutorFailed (stepLabel step) code)

-- | Run the steps at or after a frame, in order, stopping at the first failure.
runChainFromFrame :: Executor -> Frame -> [Step] -> IO (Either InterpretRefusal [StepReceipt])
runChainFromFrame executor start steps = go (stepsFrom start steps) []
 where
  go remaining done = case remaining of
    [] -> pure (Right (reverse done))
    step : rest -> do
      outcome <- stepRun executor step
      case outcome of
        Left refusal -> pure (Left refusal)
        Right receipt -> go rest (receipt : done)

-- | What the interpreter would do for a step, without doing it.
data Planned = Planned
  { plannedLabel :: Text
  , plannedArguments :: [String]
  , plannedPayloadSha256 :: Text
  }
  deriving stock (Eq, Show)

-- | The dry run: pure, it spawns nothing and reads no executor.
dryRun :: [Step] -> Either InterpretRefusal [Planned]
dryRun = traverse planned
 where
  planned step = do
    arguments <- stepArguments step
    pure (Planned (stepLabel step) arguments (sha256Hex (stepPayload step)))

-- | One tab-separated line per planned step: position, label, arguments, payload digest.
renderDryRun :: [Planned] -> Text
renderDryRun entries = Text.unlines [Text.intercalate "\t" [Text.pack (show position), plannedLabel entry, Text.pack (unwords (plannedArguments entry)), plannedPayloadSha256 entry] | (position, entry) <- zip [1 :: Int ..] entries]

sha256Hex :: ByteString -> Text
sha256Hex bytes = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))
 where
  hexByte byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

-- | The name of the variable that tells the fake where its transcript lives.
transcriptVariable :: String
transcriptVariable = "AMOEBIUS_FAKE_TRANSCRIPT"

-- | Copy the image to the native @directory/bin/kubectl@ name and return the executor that
-- spawns it. Every path is made absolute, so the spawn never depends on a search path.
materializeFake :: FilePath -> FilePath -> IO Executor
materializeFake image directory = do
  absolute <- makeAbsolute directory
  let bin = absolute </> "bin"
      link = bin </> ("kubectl" <> exeExtension)
  createDirectoryIfMissing True bin
  present <- doesPathExist link
  if present then removeFile link else pure ()
  copyFile image link
  pure (FakeKubectl link absolute)

spawn :: Executor -> [String] -> ByteString -> IO (Either Text (ExitCode, Text))
spawn executor arguments payload = do
  let process = (proc (fakeExecutable executor) arguments) {cwd = Just (fakeTranscript executor), env = Just [(transcriptVariable, fakeTranscript executor)], std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe}
  started <- try (createProcess process) :: IO (Either IOException (Maybe Handle, Maybe Handle, Maybe Handle, ProcessHandle))
  case started of
    Left problem -> pure (Left (Text.pack (show problem)))
    Right (Just input, Just output, Just failure, handle) -> do
      _ <- try (ByteString.hPut input payload) :: IO (Either IOException ())
      _ <- try (hClose input) :: IO (Either IOException ())
      out <- ByteString.hGetContents output
      _ <- ByteString.hGetContents failure
      code <- waitForProcess handle
      pure (Right (code, Encoding.decodeUtf8 out))
    Right _ -> pure (Left "the executor's pipes were not created")

-- | The body of the fake: read the whole payload first, then record the call in the
-- transcript directory and report success. It is the same program image as the product,
-- selected by the name it was invoked under.
runFakeKubectl :: IO ()
runFakeKubectl = do
  payload <- ByteString.getContents
  arguments <- getArgs
  name <- getProgName
  environment <- getEnvironment
  directory <- lookupEnv transcriptVariable
  case directory of
    Nothing -> exitWith (ExitFailure 2)
    Just transcript -> do
      let countFile = transcript </> "kubectl.count"
          combinedFile = transcript </> "stdin.combined"
      present <- doesFileExist countFile
      previous <- if present then ByteString.readFile countFile else pure ""
      let count = maybe 0 fst (Char8.readInt previous) + 1 :: Int
          stem = transcript </> ("kubectl." <> show count)
      ByteString.writeFile countFile (Encoding.encodeUtf8 (Text.pack (show count)))
      ByteString.writeFile (stem <> ".argv") (Encoding.encodeUtf8 (Text.unlines (map Text.pack (name : arguments))))
      ByteString.writeFile (stem <> ".env") (Encoding.encodeUtf8 (Text.unlines (map Text.pack (sort (map fst environment)))))
      ByteString.writeFile (stem <> ".stdin") payload
      existing <- doesFileExist combinedFile
      before <- if existing then ByteString.readFile combinedFile else pure ""
      let combined = before <> payload
      ByteString.writeFile combinedFile combined
      ByteString.writeFile (transcript </> "applied.sha256") (Encoding.encodeUtf8 (sha256Hex combined <> "\n"))
      putStrLn "fake-tool: ok"
