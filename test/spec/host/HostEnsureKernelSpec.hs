{-# LANGUAGE OverloadedStrings #-}

-- | Emit what the Phase-4 gate judges.
--
-- This spec __observes and does not judge__. It renders the plans, the reconciler
-- table, the lift fold and the absent -> present -> present replay into
-- @.build\/host_ensure_kernel\/@, and @tools\/host_ensure_kernel_gate.py@ compares
-- them against the authored oracle. Keeping the two apart is what lets the same
-- emission run against a seeded mutant without the judgement travelling with it.
module Main (main) where

import Amoebius.Host.Ensure
import Amoebius.Host.Frame
import Amoebius.Host.HostTool
import Amoebius.Host.Lift
import Amoebius.Host.Reconciler
import Amoebius.Host.Substrate
import Control.Monad (forM)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.List (intercalate)
import Data.Map.Strict qualified as Map
import System.Directory
import System.Exit (die)
import System.FilePath ((</>))

outputRoot :: FilePath
outputRoot = ".build/host_ensure_kernel"

-- | The Cabal version the plans substitute. It is a *test* resolution: the authored
-- pin lives in @tools\/toolchain_requirements.json@ and never in a plan.
fixtureVersions :: HostTool -> Maybe String
fixtureVersions tool = case tool of
  Cabal -> Just "3.16.1.0"
  _ -> Nothing

main :: IO ()
main = do
  createDirectoryIfMissing True outputRoot
  -- The fake tool directory must be addressed absolutely, because `mkAbsExe`
  -- refuses anything else -- which is the invariant, not an inconvenience.
  absoluteRoot <- makeAbsolute outputRoot
  writeFile (outputRoot </> "plans.tsv") (unlines (concatMap renderPlan everySubstrate))
  writeFile (outputRoot </> "table.tsv") (unlines renderTable)
  writeFile (outputRoot </> "refusal.tsv") (unlines refusalRows)
  liftRows <- either (die . renderEnsureError) pure liftObservations
  writeFile (outputRoot </> "lift.tsv") (unlines liftRows)
  replayRows <- replay absoluteRoot
  writeFile (outputRoot </> "replay.tsv") (unlines replayRows)
  putStrLn $
    "host-ensure-kernel-spec: PASS ("
      <> show (length everySubstrate)
      <> " substrates, "
      <> show (length reconcilers)
      <> " reconcilers, "
      <> show (length liftRows)
      <> " lifted argv, "
      <> show (length replayRows)
      <> " replay rows)"

everySubstrate :: [Substrate]
everySubstrate = [minBound .. maxBound]

-- ---------------------------------------------------------------------------
-- the reconciler refusal
-- ---------------------------------------------------------------------------

-- | Driving each reconciler on every substrate, so the excluded pairs are recorded
-- as refusals with the diagnostic their applicability column renders.
refusalRows :: [String]
refusalRows =
  [ intercalate "\t" [reconcilerName reconciler, renderSubstrate substrate, outcome, diagnostic reconciler substrate]
  | reconciler <- reconcilers
  , substrate <- everySubstrate
  , let outcome = case decide reconciler substrate of
          Left problem -> "refused\t" <> renderEnsureError problem
          Right steps -> "admitted\t" <> show (length steps)
  ]

-- ---------------------------------------------------------------------------
-- the lift fold
-- ---------------------------------------------------------------------------

-- | One step list, three contexts. They must differ only in the prefix the fold
-- emits, which is what the gate compares.
liftObservations :: Either EnsureError [String]
liftObservations = do
  let steps = installPlan LinuxCpu
      resolved tool = either (const Nothing) Just (mkAbsExe ("/opt/amoebius/bin/" <> renderHostTool tool))
      entry = either (error "fixture entry point is absolute") id (mkAbsExe "/opt/amoebius/bin/limactl")
      engine = either (error "fixture engine is absolute") id (mkAbsExe "/opt/amoebius/bin/docker")
      contexts = [OnHost, InFrame LimaGuest entry, InContainer engine "amoebius-base"]
  rows <- forM contexts $ \context -> do
    argvs <- liftPlan context resolved fixtureVersions steps
    pure [renderLiftContext context <> "\t" <> unwords argv | argv <- argvs]
  pure (concat rows)

-- ---------------------------------------------------------------------------
-- the absent -> present -> present replay
-- ---------------------------------------------------------------------------

-- | Three passes of the ensure driver against one committed fake tool directory.
--
-- The first must converge; the second and third must issue no install argv at all.
-- The recorded argv is the evidence, not a return code -- a driver that returned zero
-- without acting would be indistinguishable from one that converged.
replay :: FilePath -> IO [String]
replay absoluteRoot = do
  let home = absoluteRoot </> "home"
      stubs = absoluteRoot </> "stubs"
  removePathForcibly home
  createDirectoryIfMissing True home
  createDirectoryIfMissing True stubs
  performers <- Map.fromList <$> forM [minBound .. maxBound] (\tool -> do
    let path = stubs </> renderHostTool tool
    writeFile path "#!/bin/sh\nexit 0\n"
    permissions <- getPermissions path
    setPermissions path permissions {executable = True}
    pure (tool, either (error "stub path is absolute") id (mkAbsExe path)))
  recorder <- newIORef []
  rows <- forM [1 :: Int, 2, 3] $ \pass -> do
    before <- initialHostConfigAt home LinuxCpu
    outcome <- installAndVerify
      (initialHostConfigAt home)
      (install absoluteRoot home performers recorder pass)
      (installPlan LinuxCpu)
      before
      Kind
    -- A pass that fails is *recorded*, never fatal. The gate attributes a failure to
    -- the check it belongs to, and a driver that died here would take every other
    -- replay check down with it -- which is what makes a seeded mutant unattributable.
    after <- initialHostConfigAt home LinuxCpu
    let present = [renderHostTool tool | tool <- [minBound .. maxBound], Map.member tool (hostTools after)]
        verdict = case outcome of
          Left problem -> "refused\t" <> renderEnsureError problem
          Right _ -> "converged\t"
    pure $
      [show pass <> "\tconverged\t" <> verdict]
        <> [show pass <> "\tprobe\t" <> tool | tool <- present]
  issued <- reverse <$> readIORef recorder
  pure (issued <> concat rows)

-- | The injected installer: render the step's argv through the one fold, run it by
-- the absolute path the resolver returned, and lay down what the step provides.
install
  :: FilePath
  -> FilePath
  -> Map.Map HostTool AbsExe
  -> IORef [String]
  -> Int
  -> InstallStep
  -> IO (Either EnsureError ())
install absoluteRoot home performers recorder pass step = case liftArgv OnHost (`Map.lookup` performers) fixtureVersions step of
  Left problem -> pure (Left problem)
  Right Nothing -> pure (Right ())
  Right (Just argv) -> do
    modifyIORef' recorder ((show pass <> "\tmutation\t" <> unwords (relative argv)) :)
    case Map.lookup (performerTool step) performers of
      Nothing -> pure (Left (MissingToolAfterInstall (stepProvides step)))
      Just executablePath -> do
        _ <- runTool executablePath (drop 1 argv)
        provide home (stepProvides step)
        pure (Right ())
 where
  relative = map (dropPrefix (absoluteRoot <> "/"))

performerTool :: InstallStep -> HostTool
performerTool step = case stepPerformer step of
  VerifiedOnly -> PackageManagerRoot
  PerformedBy tool -> tool

-- | Lay a tool down where the resolver looks for it, so the post-condition probe has
-- something to find. This is the fake host acting as a host would.
provide :: FilePath -> HostTool -> IO ()
provide home tool =
  case candidates home LinuxCpu tool of
    [] -> pure ()
    (target : _) -> do
      createDirectoryIfMissing True (parentOf target)
      writeFile target "#!/bin/sh\nexit 0\n"
      permissions <- getPermissions target
      setPermissions target permissions {executable = True}

parentOf :: FilePath -> FilePath
parentOf = reverse . drop 1 . dropWhile (/= '/') . reverse

dropPrefix :: String -> String -> String
dropPrefix prefix value
  | take (length prefix) value == prefix = drop (length prefix) value
  | otherwise = value
