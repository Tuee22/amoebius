{-# LANGUAGE OverloadedStrings #-}

-- | Stage 4 of the runner (gate_runner_doctrine.md section 3): rewrite the
-- binary-fact input after the run starts, run the public command through the
-- shipped binary, recover the nonce from every declared output, and for a spine
-- fact require the fake-applied digest to equal the render digest.
module Amoebius.Validation.Runner.Binary
  ( BinaryOutcome (..)
  , Nonce (..)
  , SpineOutcome (..)
  , freshNonce
  , perturbInput
  , runBinaryFact
  , runSpineFact
  ) where

import Amoebius.Validation.GateSpec
import Amoebius.Validation.Runner.Observer
import Control.Exception (IOException, try)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock.POSIX (getPOSIXTime)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.FilePath (takeDirectory, takeFileName, (</>))

newtype Nonce = Nonce Text
  deriving (Eq, Show)

-- | A nonce issued after acquisition: the digest of the run root, the wall clock,
-- and the challenge chain, so no input authored before the run can carry it.
freshNonce :: FilePath -> Text -> IO Nonce
freshNonce runRoot chain = do
  now <- getPOSIXTime
  pure (Nonce (Text.take 32 (sha256Hex (Text.pack runRoot <> "\n" <> Text.pack (show now) <> "\n" <> chain))))

-- | Apply the perturbation. Left when the sentinel or replica count is absent, so
-- an input that cannot be perturbed cannot be reported as perturbed.
perturbInput :: Perturbation -> Nonce -> Text -> Either Text Text
perturbInput perturbation (Nonce nonce) contents = case perturbation of
  SentinelToNonce sentinel
    | sentinel `Text.isInfixOf` contents -> Right (Text.replace sentinel nonce contents)
    | otherwise -> Left ("sentinel absent from the input: " <> sentinel)
  ReplicaCount from to ->
    let needle = "replicas = " <> Text.pack (show from)
     in if needle `Text.isInfixOf` contents
          then Right (Text.replace needle ("replicas = " <> Text.pack (show to)) contents)
          else Left ("replica count absent from the input: " <> needle)

data BinaryOutcome = BinaryOutcome
  { binaryRun :: Maybe ObservedRun
  , binaryPerturbedInput :: FilePath
  , binaryNonce :: Nonce
  , binaryOutputDigests :: [(FilePath, Text)]
  , binaryNonceRecovered :: [(FilePath, Bool)]
  , binaryProblems :: [Text]
  }
  deriving (Eq, Show)

-- | Run the binary fact: perturb the input beneath the run root, run the command
-- with @{input}@ and @{run}@ substituted, then digest every declared output and
-- check that the nonce reached it.
runBinaryFact :: FilePath -> FilePath -> FilePath -> BinaryFact -> Nonce -> IO BinaryOutcome
runBinaryFact root runRoot productBinary fact nonce@(Nonce nonceText) = do
  let inputPath = runRoot </> "input" </> takeFileName (factInput fact)
  original <- try (TextIO.readFile (root </> factInput fact)) :: IO (Either IOException Text)
  case original >>= either (Left . userError . Text.unpack) Right . perturbInput (factPerturbation fact) nonce of
    Left problem -> pure (BinaryOutcome Nothing inputPath nonce [] [] [Text.pack (show problem)])
    Right perturbed -> do
      createDirectoryIfMissing True (takeDirectory inputPath)
      TextIO.writeFile inputPath perturbed
      let substitute argument = Text.unpack (Text.replace "{run}" (Text.pack runRoot) (Text.replace "{input}" (Text.pack inputPath) argument))
      run <- observe root productBinary (map substitute (factCommand fact))
      outputs <- mapM (readOutput . substitute . Text.pack) (factOutputs fact)
      pure
        BinaryOutcome
          { binaryRun = Just run
          , binaryPerturbedInput = inputPath
          , binaryNonce = nonce
          , binaryOutputDigests = [(path, sha256Hex contents) | (path, Just contents) <- outputs]
          , binaryNonceRecovered = [(path, maybe False (nonceText `Text.isInfixOf`) contents) | (path, contents) <- outputs]
          , binaryProblems = [Text.pack path <> ": output absent" | (path, Nothing) <- outputs]
          }
 where
  readOutput path = do
    exists <- doesFileExist path
    if exists then (\contents -> (path, Just contents)) <$> TextIO.readFile path else pure (path, Nothing)

data SpineOutcome = SpineOutcome
  { spineRenderDigest :: Maybe Text
  , spineAppliedDigest :: Maybe Text
  , spineDigestsEqual :: Bool
  , spineStageOrder :: [Text]
  }
  deriving (Eq, Show)

-- | Compare the render digest with the applied digest the executor wrote.
runSpineFact :: FilePath -> SpineFact -> IO SpineOutcome
runSpineFact runRoot fact = do
  rendered <- readIfPresent (runRoot </> spineRendered fact)
  applied <- readIfPresent (runRoot </> spineAppliedDigestFile fact)
  let renderDigest = sha256Hex <$> rendered
      appliedDigest = Text.strip <$> applied
  pure
    SpineOutcome
      { spineRenderDigest = renderDigest
      , spineAppliedDigest = appliedDigest
      , spineDigestsEqual = renderDigest /= Nothing && renderDigest == appliedDigest
      , spineStageOrder = spineStages fact
      }
 where
  readIfPresent path = do
    exists <- doesFileExist path
    if exists then Just <$> TextIO.readFile path else pure Nothing
