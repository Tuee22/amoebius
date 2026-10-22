{-# LANGUAGE OverloadedStrings #-}

-- | The sections that judge the step algebra and its interpreter, and the fake image the
-- interpreter spawns. The fake here wraps the product's own fake with one scripted
-- failure, so a scenario can make the third call fail; the product's fake carries no such
-- switch.
module SpineFake
  ( fakeImage
  , chainSection
  , interpretSection
  ) where

import Amoebius.Dsl.Commands (runApply)
import Amoebius.Dsl.Pipeline (ApplyOutcome (..), applyToDirectory, compileText, compiledSteps)
import Amoebius.Kernel.Interpret
  ( Executor (..)
  , InterpretRefusal (..)
  , dryRun
  , materializeFake
  , runChainFromFrame
  , runFakeKubectl
  , stepRun
  )
import Amoebius.Kernel.Step
import Control.Exception (SomeException, try, bracket)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, exeExtension, findExecutable, makeAbsolute, removeFile)
import System.Environment (getExecutablePath, lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

writeText :: FilePath -> Text -> IO ()
writeText path contents = do
  createDirectoryIfMissing True (takeDirectory path)
  ByteString.writeFile path (Encoding.encodeUtf8 contents)

tabs :: [Text] -> Text
tabs = Text.intercalate "\t"

-- | The program image when it is invoked as @kubectl@: fail on the scripted call, and
-- otherwise do what the product's fake does.
fakeImage :: IO ()
fakeImage = do
  directory <- lookupEnv "AMOEBIUS_FAKE_TRANSCRIPT"
  failing <- maybe (pure False) failsNow directory
  if failing
    then ByteString.getContents >> exitWith (ExitFailure 1)
    else runFakeKubectl

failsNow :: FilePath -> IO Bool
failsNow directory = do
  scripted <- doesFileExist (directory </> "fail-at")
  if scripted
    then do
      wanted <- readCount (directory </> "fail-at")
      made <- readCount (directory </> "kubectl.count")
      pure (made + 1 == wanted)
    else pure False

readCount :: FilePath -> IO Int
readCount path = do
  present <- doesFileExist path
  if present
    then maybe 0 fst . Char8.readInt <$> ByteString.readFile path
    else pure 0

baselineSteps :: FilePath -> IO [Step]
baselineSteps suite = do
  text <- Encoding.decodeUtf8 <$> ByteString.readFile (suite </> "examples" </> "kind-single-objectstore.dhall")
  compiled <- compileText (suite </> "examples") text
  pure (compiledSteps compiled)

-- | The step algebra: its frames, its constructor, and its validation.
chainSection :: FilePath -> IO ()
chainSection suite = do
  steps <- baselineSteps suite
  let objects = concatMap stepObjects (take 1 steps)
  writeText (suite </> "chain.tsv") (Text.unlines (rows steps objects))
 where
  rows steps objects =
    [tabs ["count", Text.pack (show (length steps))]]
      <> [tabs ["steps-from", Text.pack (show frame), Text.pack (show (length (stepsFrom frame steps)))] | frame <- [minBound .. maxBound]]
      <> [tabs ["next-frame", Text.pack (show frame), maybe "Nothing" (Text.pack . show) (nextFrameAfter frame steps)] | frame <- [minBound .. maxBound]]
      <> [ tabs ["mk-step", "empty-label", outcome (mkStep "" ImmediateFrame ApplyObjects objects)]
         , tabs ["mk-step", "apply-without-objects", outcome (mkStep "x" ImmediateFrame ApplyObjects [])]
         , tabs ["mk-step", "objects-on-build", outcome (mkStep "x" ImmediateFrame DockerBuild objects)]
         , tabs ["mk-step", "apply", outcome (mkStep "x" ImmediateFrame ApplyObjects objects)]
         ]
      <> [tabs ["mk-step", "empty-" <> Text.pack (show kind), outcome (mkStep "x" ImmediateFrame kind [])] | kind <- [minBound .. maxBound]]
      <> [ tabs ["validate", "baseline", validated steps]
         , tabs ["validate", "reversed", validated (reverse steps)]
         , tabs ["validate", "reversed-pair", validated (reverse (take 1 steps <> take 1 (drop 3 steps)))]
         , tabs ["manifest", "skips-non-apply", if manifestBytes (steps <> buildSteps) == manifestBytes steps then "ok" else "differs"]
         , tabs ["validate", "duplicate", validated (take 1 steps <> take 1 steps)]
         , tabs ["validate", "empty", validated []]
         , tabs ["chain", "empty", either (\problem -> "refused:" <> stepRefusalTag problem) (\built -> "ok:" <> Text.pack (show (length built))) (chain [])]
         , tabs ["chain", "objects", either (\problem -> "refused:" <> stepRefusalTag problem) (\built -> "ok:" <> Text.pack (show (length built))) (chain (concatMap stepObjects steps))]
         ]
  buildSteps = either (const []) pure (mkStep "build" ImmediateFrame DockerBuild [])
  outcome = either (\problem -> "refused:" <> stepRefusalTag problem) (const "ok")
  validated = either (\problem -> "refused:" <> stepRefusalTag problem) (const "ok") . validateChain

-- | The interpreter over the fake, in every scenario that has an observable difference.
interpretSection :: FilePath -> IO ()
interpretSection suite = do
  steps <- baselineSteps suite
  image <- getExecutablePath
  full <- scenario suite image "full" Nothing (\executor -> runChainFromFrame executor ImmediateFrame steps)
  cutover <- scenario suite image "from-cutover" Nothing (\executor -> runChainFromFrame executor AfterBootstrapAddonCutoverFrame steps)
  managed <- scenario suite image "from-managed" Nothing (\executor -> runChainFromFrame executor AfterManagedCapacityReadyFrame steps)
  boundary <- scenario suite image "from-boundary" Nothing (\executor -> runChainFromFrame executor BoundaryFrame steps)
  failing <- scenario suite image "fail-at-3" (Just 3) (\executor -> runChainFromFrame executor ImmediateFrame steps)
  originalPath <- lookupEnv "PATH"
  hostile <- scenario suite image "hostile-path" Nothing (\executor -> hostilePath suite executor steps)
  restoredPath <- lookupEnv "PATH"
  unsupported <- scenario suite image "unsupported-kind" Nothing (\executor -> runUnsupported executor)
  single <- scenario suite image "single-step" Nothing (\executor -> maybe (pure (Left (ExecutorUnavailable "no step"))) (fmap (fmap pure) . stepRun executor) (firstStep steps))
  applied <- applyToDirectory False image (suite </> "examples" </> "kind-single-objectstore.dhall") (suite </> "applied-suite")
  missing <- scenario suite image "missing-environment" Nothing (\executor -> missingEnvironment executor)
  dry <- dryRunRows suite steps
  real <- realExecutor suite
  writeText (suite </> "interpret.tsv") $ Text.unlines $
    [ tabs ["full.result", chainResult full]
    , tabs ["from-cutover.result", chainResult cutover]
    , tabs ["from-managed.result", chainResult managed]
    , tabs ["from-boundary.result", chainResult boundary]
    , tabs ["fail-at-3.result", chainResult failing]
    , tabs ["hostile-path.result", chainResult hostile]
    , tabs ["hostile-path.environment-restored", Text.pack (show (originalPath == restoredPath))]
    , tabs ["unsupported-kind.result", chainResult unsupported]
    , tabs ["single-step.result", chainResult single]
    , tabs ["apply-full.result", case applied of { Applied count -> "applied:" <> Text.pack (show count); _ -> "not-applied" }]
    , tabs ["missing-environment.exit", missing]
    ]
      <> dry
      <> [tabs ["real-executor.exit", real]]
 where
  firstStep items = case items of
    item : _ -> Just item
    [] -> Nothing

-- | Run an action against a fresh fake in its own directory, with an optional scripted failure.
scenario :: FilePath -> FilePath -> String -> Maybe Int -> (Executor -> IO result) -> IO result
scenario suite image name scripted action = do
  let directory = suite </> "fake" </> name
  createDirectoryIfMissing True directory
  maybe (pure ()) (\point -> writeText (directory </> "fail-at") (Text.pack (show point) <> "\n")) scripted
  executor <- materializeFake image directory
  action executor

-- | The fake run with no environment at all has no transcript to write and exits with usage status.
missingEnvironment :: Executor -> IO Text
missingEnvironment executor = do
  (code, _, _) <- readCreateProcessWithExitCode ((proc (fakeExecutable executor) []) {cwd = Just (fakeTranscript executor), env = Just []}) ""
  pure (Text.pack (show code))

chainResult :: Either InterpretRefusal [a] -> Text
chainResult outcome = case outcome of
  Right receipts -> "ok:" <> Text.pack (show (length receipts))
  Left (ExecutorFailed label code) -> "ExecutorFailed:" <> label <> ":" <> Text.pack (show code)
  Left (UnsupportedStepKind kind) -> "UnsupportedStepKind:" <> Text.pack (show kind)
  Left (ExecutorUnavailable why) -> "ExecutorUnavailable:" <> why

-- | The PATH names a directory whose @kubectl@ would leave a marker if anything ran it.
hostilePath :: FilePath -> Executor -> [Step] -> IO (Either InterpretRefusal [()])
hostilePath suite executor steps = do
  let decoy = suite </> "decoy"
  createDirectoryIfMissing True decoy
  let source = decoy </> "Main.hs"
      image = decoy </> ("kubectl" <> exeExtension)
      marker = decoy </> "ran"
  writeFile source (unlines ["module Main where", "main :: IO ()", "main = writeFile " <> show marker <> " \"ran\\n\""])
  ghc <- findExecutable "ghc" >>= maybe (fail "hostile PATH control needs native GHC") pure
  (built, _, errors) <- readCreateProcessWithExitCode (proc ghc ["--make", "-v0", "-j1", "-outputdir", decoy </> "objects", "-o", image, source]) ""
  if built /= ExitSuccess then fail errors else pure ()
  (control, _, _) <- readCreateProcessWithExitCode (proc image []) ""
  marked <- doesFileExist marker
  if control /= ExitSuccess || not marked then fail "hostile PATH control did not run" else removeFile marker
  bracket (lookupEnv "PATH") (maybe (unsetEnv "PATH") (setEnv "PATH")) $ \_ -> do
    setEnv "PATH" decoy
    outcome <- runChainFromFrame executor AfterManagedCapacityReadyFrame steps
    pure (fmap (map (const ())) outcome)

runUnsupported :: Executor -> IO (Either InterpretRefusal [()])
runUnsupported executor = case mkStep "build" ImmediateFrame DockerBuild [] of
  Left _ -> pure (Left (ExecutorUnavailable "unbuilt step"))
  Right step -> fmap (fmap (map (const ()))) (runChainFromFrame executor ImmediateFrame [step])

-- | The dry run executes nothing: it spawns no fake and leaves no transcript directory.
dryRunRows :: FilePath -> [Step] -> IO [Text]
dryRunRows suite steps = do
  image <- getExecutablePath
  let input = suite </> "examples" </> "kind-single-objectstore.dhall"
      output = suite </> "dry"
  _ <- applyToDirectory True image input output
  spawned <- doesDirectoryExist (output </> "fake")
  let unsupported = case mkStep "build" ImmediateFrame DockerBuild [] of
        Left _ -> "unbuilt"
        Right step -> either (\problem -> "Left:" <> Text.pack (show problem)) (const "Right") (dryRun [step])
      planned = either (const "Left") (Text.pack . show . length) (dryRun steps)
  pure
    [ tabs ["dry-run.fake-directory", if spawned then "present" else "absent"]
    , tabs ["dry-run.planned", planned]
    , tabs ["dry-run.unsupported", unsupported]
    ]

-- | Any executor other than the fake is refused with usage status.
realExecutor :: FilePath -> IO Text
realExecutor suite = do
  absolute <- makeAbsolute suite
  outcome <- try (runApply ["--executor", "real", "--input", absolute </> "examples" </> "kind-single-objectstore.dhall", "--out", absolute </> "real"]) :: IO (Either SomeException ())
  pure $ case outcome of
    Left problem -> Text.pack (show problem)
    Right () -> "returned"
