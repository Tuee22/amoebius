{-# LANGUAGE OverloadedStrings #-}
-- | Runner stage 4: perturb an input, observe the shipped binary, and recover its nonce.
module Amoebius.Validation.Runner.Binary
  ( BinaryOutcome (..), Nonce (..), SpineOutcome (..), freshNonce, perturbInput, runBinaryFact, runSpineFact ) where
import Amoebius.Validation.GateSpec
import Amoebius.Validation.Runner.Hygiene (CapturedSource, capturedSourceFiles, capturedSourceBytes, materializeSource, readSourceBytes, readSourceText)
import Amoebius.Validation.Runner.Observer
import Amoebius.Validation.Runner.Mutants
import Amoebius.Validation.Runner.Spec
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Control.Exception (IOException, try)
import Control.Monad (foldM, forM)
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
  Rewrite needle replacement
    | needle `Text.isInfixOf` contents -> Right (Text.replace needle replacement contents)
    | otherwise -> Left ("rewrite needle absent from the input: " <> needle)
  Staged {} -> Left "a staged perturbation applies its inner perturbations after the prelude"
  PlantForeignPaths _ -> Left "planted paths require the runner's source-copy input"
  SourceSibling _ _ _ -> Left "source sibling requires the runner's observed build boundary"
data BinaryOutcome = BinaryOutcome
  { binaryRuns :: [ObservedRun], binaryNonce :: Nonce
  , binaryOutputDigests :: [(FilePath, Text)], binaryNonceRecovered :: [(FilePath, Bool)]
  , binaryEvidence :: [(Text, Text)], binaryProblems :: [Text]
  } deriving (Eq, Show)
-- | Run the fact beneath a fresh run root and digest every declared output.
runBinaryFact :: FilePath -> Maybe FilePath -> CapturedSource -> FilePath -> FilePath -> FilePath -> BinaryFact -> Nonce -> IO BinaryOutcome
runBinaryFact cabal compiler snapshot root runRoot productBinary fact nonce@(Nonce nonceText) = case factPerturbation fact of
  PlantForeignPaths challenges -> do
    outcomes <- forM (zip [1 :: Int ..] challenges) $ \(index, challenge) -> runOne (runRoot </> show index) (Just challenge)
    pure (BinaryOutcome (concatMap binaryRuns outcomes) nonce (concatMap binaryOutputDigests outcomes)
      (concatMap binaryNonceRecovered outcomes) (concatMap binaryEvidence outcomes) (["foreign challenge set empty" | null challenges] <> concatMap binaryProblems outcomes))
  _ -> runOne runRoot Nothing
 where
  (underlying, sibling) = case factPerturbation fact of SourceSibling subject binding inner -> (inner, Just (subject, binding)); other -> (other, Nothing)
  runOne workRoot challenge = do
    let inputPath = workRoot </> "input" </> takeFileName (factInput fact)
        planted = fmap (\(path, tag) -> (Text.unpack (Text.replace "{nonce}" nonceText (Text.pack path)), tag)) challenge
        substitute base argument = Text.unpack (Text.replace "{tree}" (Text.pack (base </> "tree")) (Text.replace "{run}" (Text.pack base) (Text.replace "{input}" (Text.pack inputPath) argument)))
        execute = mapM (observe root productBinary . map (substitute workRoot))
    createDirectoryIfMissing True (takeDirectory inputPath)
    before <- case underlying of
      Staged prelude _ _ -> execute prelude
      _ -> pure []
    source <- case planted of
      Just (path, _) -> plantPath snapshot workRoot path
      Nothing -> case underlying of
        Staged _ _ inner -> do
          original <- try (readSourceText inputPath) :: IO (Either IOException Text)
          pure (original >>= \text -> either (Left . userError . Text.unpack) Right (foldM (\current perturbation -> perturbInput perturbation nonce current) text inner))
        other -> do
          original <- try (readSourceText (root </> factInput fact)) :: IO (Either IOException Text)
          pure (original >>= either (Left . userError . Text.unpack) Right . perturbInput other nonce)
    case source of
      Left problem -> pure (BinaryOutcome before nonce [] [] [] [Text.pack (show problem)])
      Right perturbed -> do
        TextIO.writeFile inputPath perturbed
        run <- observe root productBinary (map (substitute workRoot) (factCommand fact))
        after <- case underlying of
          Staged _ postlude _ -> execute postlude
          _ -> pure []
        (siblingRuns, evidence, siblingProblems) <- maybe (pure ([], [], [])) (uncurry (rebuildSibling workRoot inputPath substitute)) sibling
        outputs <- mapM (readOutput . substitute workRoot . Text.pack) (factOutputs fact)
        let expectedExit = maybe ExitSuccess (const (ExitFailure 1)) planted
            expectedFinding = fmap (\(path, tag) -> "finding\t" <> tag <> "\t" <> Text.pack path) planted
            findingSeen = maybe True (\line -> any (maybe False (line `elem`) . fmap Text.lines . snd) outputs) expectedFinding
        pure (BinaryOutcome (before <> [run] <> after <> siblingRuns) nonce
          [(path, sha256Hex contents) | (path, Just contents) <- outputs]
          [(path, maybe False (nonceText `Text.isInfixOf`) contents) | (path, contents) <- outputs]
          evidence ([Text.pack path <> ": output absent" | (path, Nothing) <- outputs]
            <> ["unexpected binary exit" | any ((/= expectedExit) . runExit) (before <> [run] <> after)]
            <> ["required foreign finding absent" | not findingSeen] <> siblingProblems))
  rebuildSibling workRoot inputPath substitute subject binding = do
    result <- try $ do
      graph <- loadPackageGraph root >>= either (fail . show) pure
      let shipped = maybe Set.empty id (executableClosure graph "amoebius")
      stanza <- one "source sibling module is not uniquely shipped" [name | (name, (modules, _, _)) <- Map.toList (graphLibraries graph), Set.member name shipped, Set.member (productionModuleName subject) modules]
      file <- moduleSourcePath root graph stanza subject >>= maybe (fail "source sibling module absent") pure
      source <- readSourceText (root </> file)
      locus <- truncateListLocus <$> one "source sibling binding is not one literal list" [entry | entry <- enumerateLoci (productionModuleName subject) file ListTruncation source, (binding <> " = ") `Text.isPrefixOf` Text.stripStart (locusBefore entry)]
      let child = workRoot </> "sibling"; tree = child </> "tree"
      _ <- materializeSource snapshot tree >>= either (fail . Text.unpack) pure
      witness <- applyLocus tree locus >>= either (fail . Text.unpack) pure
      if Text.strip (locusAfter locus) /= binding <> " = []" || witnessBeforeDigest witness == witnessAfterDigest witness then fail "source sibling did not empty its binding" else pure ()
      inputBefore <- readSourceBytes inputPath
      binaryBefore <- ByteString.readFile productBinary
      (builds, built) <- buildProductBinary tree cabal compiler
      case built of
        Left problem -> pure (builds, [], [problem])
        Right image -> do
          observed <- observe tree image (map (substitute child) (factCommand fact))
          binaryAfter <- ByteString.readFile image
          inputAfter <- readSourceBytes inputPath
          let evidence = [("nonce", nonceText), ("module", productionModuleName subject), ("binding", binding), ("operator", renderOperator (witnessOperator witness)),
                ("source-before", witnessBeforeDigest witness), ("source-after", witnessAfterDigest witness), ("source-diff", Text.pack (show (witnessDiff witness))),
                ("binary-before", sha256Bytes binaryBefore), ("binary-after", sha256Bytes binaryAfter), ("input-before", sha256Bytes inputBefore), ("input-after", sha256Bytes inputAfter)]
          TextIO.writeFile (child </> "witness.tsv") (renderTsv [[key, value] | (key, value) <- evidence])
          pure (builds <> [observed], evidence, ["source sibling binary unchanged" | binaryBefore == binaryAfter] <> ["source sibling input changed" | inputBefore /= inputAfter] <> ["source sibling did not refuse" | runExit observed /= ExitFailure 1])
    pure (either (\problem -> ([], [], [Text.pack (show (problem :: IOException))])) id result)
  one :: String -> [value] -> IO value
  one label values = case values of [value] -> pure value; _ -> fail label
  readOutput path = do
    exists <- doesFileExist path
    if exists then (\contents -> (path, Just contents)) <$> readSourceText path else pure (path, Nothing)
plantPath :: CapturedSource -> FilePath -> FilePath -> IO (Either IOException Text)
plantPath source runRoot planted = plantPathWithContent source runRoot planted "challenge\n"
plantPathWithContent :: CapturedSource -> FilePath -> FilePath -> Text -> IO (Either IOException Text)
plantPathWithContent source runRoot planted content = try $ do
  let copied = [file | file <- capturedSourceFiles source, Just _ <- [capturedSourceBytes source file]]
  let tree = runRoot </> "tree"
  _ <- materializeSource source tree >>= either (fail . Text.unpack) pure
  createDirectoryIfMissing True (takeDirectory (tree </> planted))
  TextIO.writeFile (tree </> planted) content
  pure (Text.unlines (map Text.pack (copied <> [planted])))
data SpineOutcome = SpineOutcome
  { spineRenderDigest :: Maybe Text, spineAppliedDigest :: Maybe Text
  , spineDigestsEqual :: Bool, spineStageOrder :: [Text] } deriving (Eq, Show)
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
  readIfPresent path = doesFileExist path >>= \exists -> if exists then Just <$> readSourceText path else pure Nothing
