{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Cluster.Bootstrap
  ( runBootstrap
  ) where

import Amoebius.Cluster.Inventory
import Amoebius.Cluster.Kind
import Amoebius.Host.Context
import Amoebius.Host.Substrate (Substrate (..), renderSubstrate)
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
  case contextSubstrate context of
    LinuxCpu -> pure ()
    LinuxCuda -> pure ()
    substrate -> die ("phase24-linux-cpu-lane-requires-linux-guest;detected=" <> renderSubstrate substrate)
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
