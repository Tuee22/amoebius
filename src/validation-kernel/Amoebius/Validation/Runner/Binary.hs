{-# LANGUAGE OverloadedStrings #-}
-- | Runner stage 4: perturb an input, observe the shipped binary, and recover its nonce.
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
import Amoebius.Validation.Runner.Hygiene (copyTree, trackedFiles)
import Amoebius.Validation.Runner.Observer
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock.POSIX (getPOSIXTime)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, takeFileName, (</>))
newtype Nonce = Nonce Text
  deriving (Eq, Show)
-- | A nonce issued after acquisition from the run root, clock, and challenge chain.
freshNonce :: FilePath -> Text -> IO Nonce
freshNonce runRoot chain = do
  now <- getPOSIXTime
  pure (Nonce (Text.take 32 (sha256Hex (Text.pack runRoot <> "\n" <> Text.pack (show now) <> "\n" <> chain))))
-- | Refuse a textual input when the required perturbation cannot be applied.
perturbInput :: Perturbation -> Nonce -> Text -> Either Text Text
perturbInput perturbation (Nonce nonce) contents = case perturbation of
  SentinelToNonce sentinel
    | sentinel `Text.isInfixOf` contents -> Right (Text.replace sentinel nonce contents)
    | otherwise -> Left ("sentinel absent from the input: " <> sentinel)
  ReplicaCount from to ->
    let needle = "replicas = " <> Text.pack (show from)
     in if needle `Text.isInfixOf` contents then Right (Text.replace needle ("replicas = " <> Text.pack (show to)) contents)
          else Left ("replica count absent from the input: " <> needle)
  PlantHaskellPath -> Left "planted paths require the runner's source-copy input"
  PlantForeignPaths _ -> Left "planted paths require the runner's source-copy input"
data BinaryOutcome = BinaryOutcome
  { binaryRuns :: [ObservedRun], binaryNonce :: Nonce
  , binaryOutputDigests :: [(FilePath, Text)], binaryNonceRecovered :: [(FilePath, Bool)]
  , binaryProblems :: [Text]
  }
  deriving (Eq, Show)
-- | Run the fact beneath a fresh run root and digest every declared output.
runBinaryFact :: FilePath -> FilePath -> FilePath -> BinaryFact -> Nonce -> IO BinaryOutcome
runBinaryFact root runRoot productBinary fact nonce@(Nonce nonceText) = case factPerturbation fact of
  PlantForeignPaths challenges -> do
    outcomes <- forM (zip [1 :: Int ..] challenges) $ \(index, challenge) -> runOne (runRoot </> show index) (Just challenge)
    pure (BinaryOutcome (concatMap binaryRuns outcomes) nonce (concatMap binaryOutputDigests outcomes)
      (concatMap binaryNonceRecovered outcomes) (["foreign challenge set empty" | null challenges] <> concatMap binaryProblems outcomes))
  _ -> runOne runRoot Nothing
 where
  runOne workRoot challenge = do
    let inputPath = workRoot </> "input" </> takeFileName (factInput fact)
        planted = fmap (\(path, tag) -> (Text.unpack (Text.replace "{nonce}" nonceText (Text.pack path)), tag)) challenge
    source <- case planted of
      Just (path, _) -> plantPath root workRoot path
      Nothing -> case factPerturbation fact of
        PlantHaskellPath -> plantHaskellPath root workRoot nonceText
        other -> do
          original <- try (TextIO.readFile (root </> factInput fact)) :: IO (Either IOException Text)
          pure (original >>= either (Left . userError . Text.unpack) Right . perturbInput other nonce)
    case source of
      Left problem -> pure (BinaryOutcome [] nonce [] [] [Text.pack (show problem)])
      Right perturbed -> do
        createDirectoryIfMissing True (takeDirectory inputPath)
        TextIO.writeFile inputPath perturbed
        let substitute argument = Text.unpack (Text.replace "{tree}" (Text.pack (workRoot </> "tree")) (Text.replace "{run}" (Text.pack workRoot) (Text.replace "{input}" (Text.pack inputPath) argument)))
        run <- observe root productBinary (map substitute (factCommand fact))
        outputs <- mapM (readOutput . substitute . Text.pack) (factOutputs fact)
        let expectedExit = maybe ExitSuccess (const (ExitFailure 1)) planted
            expectedFinding = fmap (\(path, tag) -> "finding\t" <> tag <> "\t" <> Text.pack path) planted
            findingSeen = maybe True (\line -> any (maybe False (line `elem`) . fmap Text.lines . snd) outputs) expectedFinding
        pure (BinaryOutcome [run] nonce
          [(path, sha256Hex contents) | (path, Just contents) <- outputs]
          [(path, maybe False (nonceText `Text.isInfixOf`) contents) | (path, contents) <- outputs]
          ([Text.pack path <> ": output absent" | (path, Nothing) <- outputs]
            <> ["unexpected binary exit" | runExit run /= expectedExit]
            <> ["required foreign finding absent" | not findingSeen]))
  readOutput path = do
    exists <- doesFileExist path
    if exists then (\contents -> (path, Just contents)) <$> TextIO.readFile path else pure (path, Nothing)
plantHaskellPath :: FilePath -> FilePath -> Text -> IO (Either IOException Text)
plantHaskellPath root runRoot nonce = plantPathWithContent root runRoot
  ("src/Amoebius/RunChallenge/Path" <> Text.unpack nonce <> ".hs") ("module Amoebius.RunChallenge.Path" <> nonce <> " where\n")
plantPath :: FilePath -> FilePath -> FilePath -> IO (Either IOException Text)
plantPath root runRoot planted = plantPathWithContent root runRoot planted "challenge\n"
plantPathWithContent :: FilePath -> FilePath -> FilePath -> Text -> IO (Either IOException Text)
plantPathWithContent root runRoot planted content = try $ do
  names <- trackedFiles root
  copied <- filterM (doesFileExist . (root </>)) names
  let tree = runRoot </> "tree"
  copyTree root tree copied
  createDirectoryIfMissing True (takeDirectory (tree </> planted))
  TextIO.writeFile (tree </> planted) content
  pure (Text.unlines (map Text.pack (copied <> [planted])))
data SpineOutcome = SpineOutcome
  { spineRenderDigest :: Maybe Text, spineAppliedDigest :: Maybe Text
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
  pure (SpineOutcome renderDigest appliedDigest
    (renderDigest /= Nothing && renderDigest == appliedDigest) (spineStages fact))
 where
  readIfPresent path = doesFileExist path >>= \exists -> if exists then Just <$> TextIO.readFile path else pure Nothing
