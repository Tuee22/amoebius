{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Generate.BrowserContracts
import Control.Monad (forM_, unless, when)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  setCurrentDirectory root
  arguments <- getArgs
  output <- case arguments of
    ["--output", path] -> pure path
    _ -> die "usage: ui-contract-generation-spec --output DIRECTORY"
  verifyCustody root
  expected <- loadInventory (root </> "test/oracle/ui_contract_generation/contract_inventory.tsv")
  writeBrowserArtifacts output
  checkMutantLocus
  assertEqual "independent contract inventory" expected contractInventory
  assertEqual "generated artifact count" 3 (length browserArtifacts)
  forM_ browserArtifacts $ \(relative, _body) ->
    doesFileExist (output </> relative) >>= flip assert ("generated artifact absent: " <> relative)
  checkCalculus root
  putStrLn "ui-contract-generation-calculus: PASS (5 kinds, 31 projected units)"
  putStrLn "ui-contract-generation-spec: PASS (16 contracts, 3 generated recipes, 3 mutants)"

checkMutantLocus :: IO ()
checkMutantLocus = do
  let names = map contractName contractInventory
  when ("rawHtml" `elem` names) $ die "ui-contract-generation-mutant: RED raw_sink raw-sink-catalog"
  when ("ServerHandle" `elem` names) $ die "ui-contract-generation-mutant: RED serialize_server_handle server-handle-private"
  when ("providerCoordinate" `elem` names) $ die "ui-contract-generation-mutant: RED undeclared_codec undeclared-codec"

loadInventory :: FilePath -> IO [ContractRow]
loadInventory path = do
  rows <- drop 1 . lines <$> readFile path
  traverse parse rows
  where
    parse row = case splitTabs row of
      [kind, name, codec, visibility] -> pure (ContractRow (pack kind) (pack name) (pack codec) (pack visibility))
      _ -> die ("invalid contract inventory row: " <> row)
    pack = Text.pack

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadWordsTable (root </> "test/oracle/ui_contract_generation/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-contract-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-contract-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [3, 1, 22, 2, 3] :: [Int]
          artifact = artifactComponent scope "generated-browser-artifacts" (resources 3)
            (RecipeId "ui-contract-generation" 3)
          budget = budgetComponent scope "closed-runtime-abi" (resources 1)
            (allowance (Bytes 1) (Slots 1) (Bytes 1))
          lift = liftComponent scope "browser-contract-inventory" (resources 22) OnHost
          workflow = workflowComponent scope "deterministic-render-workflow" (resources 2) emptyLedger
          evidence = evidenceComponent scope "mutant-evidence" (resources 3) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          ResourceVector cpu memory ephemeral pods = compositionResource composition
          render = Text.unpack . Text.intercalate ","
          actual =
            [ ["calculus-kinds", render (map calculusTag (compositionKinds composition))]
            , ["component-names", render (compositionNames composition)]
            , ["projection-counts", render (map (Text.pack . show) counts)]
            , ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
            ]
      assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
      assertEqual "UI contract calculus projection" expected actual
  action

verifyCustody :: FilePath -> IO ()
verifyCustody root = do
  rows <- drop 1 . lines <$> readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  let phaseRows = [fields | fields@(phase : _) <- map splitTabs rows, phase == "29"]
  assertEqual "phase-0 custody" 5 (length phaseRows)
  forM_ phaseRows $ \row -> case row of
    (_phase : _kind : path : _) -> doesFileExist (root </> path) >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-29 custody row"

loadWordsTable :: FilePath -> IO [[String]]
loadWordsTable path = do
  rows <- lines <$> readFile path
  case rows of
    [] -> die ("empty table: " <> path)
    _header : body -> pure (map words body)

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label wanted actual = unless (wanted == actual) $
  die (label <> ": expected " <> show wanted <> ", got " <> show actual)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
  where
    go path = do
      found <- doesFileExist (path </> "cabal.project")
      if found then pure path else
        let parent = takeDirectory path
        in if parent == path then die "ui-contract-generation-root" else go parent
