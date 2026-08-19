{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Cluster.Bootstrap
  ( runBootstrap
  ) where

import Amoebius.Cluster.Inventory
import Amoebius.Cluster.Kind
import Amoebius.Host.Context
import Amoebius.Host.Frame (Frame (..), frameFor, frameProvider, renderFrame)
import Amoebius.Host.Substrate (renderPristineLinuxProvider, renderSubstrate)
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString.Lazy qualified as ByteString
import Data.List (stripPrefix)
import System.Exit (die)
import System.FilePath ((</>))
import Text.Read (readMaybe)

runBootstrap :: [String] -> IO ()
runBootstrap arguments = do
  (distro, replicas, layout) <- either die pure (parseArguments arguments)
  context <- mkBinaryContext distro replicas >>= either die pure
  -- Every catalogue member reaches a Linux frame; the wildcard arm that refused
  -- `apple` and `windows` outright is replaced by entry into the frame their rows
  -- name. The arms are exhaustive and wildcard-free, so a new frame is a compile
  -- error here rather than a substrate silently taking the native path.
  case frameFor (contextSubstrate context) of
    NativeLinux -> pure ()
    LimaGuest -> enterFrame context LimaGuest
    Wsl2Guest -> enterFrame context Wsl2Guest
  before <- discoverCluster context
  token <- if clusterRegistered before
    then pure Nothing
    else do
      observed <- observePhysicalHost context >>= either (die . renderHostAdmissionError) pure
      Just <$> (admitKindCreate defaultKindEngineDemand observed >>= either (die . renderHostAdmissionError) pure)
  report <- reconcileKind context layout token >>= either die pure
  printReport report
  inventory <- observeInventory context layout >>= either (die . show) pure
  let declared = defaultDeclaredTarget
        { declaredFilesystemLayout = case layout of
            KindUnified -> "Unified"
            KindSplitRuntime -> "SplitRuntime"
            KindSplitImage -> "SplitImage"
        }
  either (die . show) pure (validateDeclaredTarget declared inventory)
  let inventoryPath = contextStateDirectory context </> "observed-inventory.json"
  ByteString.writeFile inventoryPath (encodePretty inventory)
  putStrLn ("bootstrap-inventory: " <> inventoryPath)
  putStrLn "bootstrap-handoff: ready"

parseArguments :: [String] -> Either String (BootstrapDistro, Int, KindFilesystemLayout)
parseArguments arguments = do
  distro <- case [value | argument <- arguments, Just value <- [stripPrefix "--distro=" argument]] of
    ["kind"] -> Right KindDistro
    ["rke2"] -> Right Rke2Distro
    _ -> Left "usage: amoebius bootstrap --distro={kind,rke2} [--replicas=n]"
  replicas <- case [value | argument <- arguments, Just value <- [stripPrefix "--replicas=" argument]] of
    [] -> Right 1
    [value] -> maybe (Left "invalid-replicas") Right (readMaybe value)
    _ -> Left "duplicate-replicas"
  layout <- case [value | argument <- arguments, Just value <- [stripPrefix "--layout=" argument]] of
    [] -> Right KindUnified
    ["unified"] -> Right KindUnified
    ["split-runtime"] -> Right KindSplitRuntime
    ["split-image"] -> Right KindSplitImage
    _ -> Left "invalid-filesystem-layout"
  pure (distro, replicas, layout)

printReport :: ReconcileReport -> IO ()
printReport report = do
  putStrLn ("bootstrap-discover-before: " <> show (reconcileBefore report))
  putStrLn ("bootstrap-diff: " <> show (reconcileActions report))
  putStrLn ("bootstrap-discover-after: " <> show (reconcileAfter report))
  if reconcileBefore report == reconcileAfter report
    then putStrLn "bootstrap-reconcile: already-converged"
    else putStrLn "bootstrap-reconcile: converged"

-- | Enter the Linux frame a non-native substrate reaches its workload through.
--
-- The frame is created and driven by the phase that owns its provider -- Colima and
-- Lima on Apple, WSL2 on Windows -- so this is the handoff point rather than the
-- implementation. It names the provider the row selected instead of refusing the
-- substrate, which is the whole difference the frame table makes.
enterFrame :: BinaryContext -> Frame -> IO ()
enterFrame context frame =
  die $
    "bootstrap-enters-frame;substrate="
      <> renderSubstrate (contextSubstrate context)
      <> ";frame="
      <> renderFrame frame
      <> ";provider="
      <> renderPristineLinuxProvider (frameProvider frame)
      <> ";owner=the phase that materializes this frame"
