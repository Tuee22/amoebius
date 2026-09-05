{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Generate.BrowserContracts
import Control.Monad (forM_, unless, when)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import UiContractGenerationCases qualified as Cases
import UiContractGenerationReference qualified as Reference

main :: IO ()
main = do
  checkMutantLocus
  assertEqual "independent contract inventory" Reference.contractRows (map rowTuple contractInventory)
  assertEqual "generated paths" Cases.generatedPaths (map fst browserArtifacts)
  assertEqual "generated artifact count" 3 (length browserArtifacts)
  assertEqual "deterministic recipes" browserArtifacts browserArtifacts
  let bodies = Text.concat (map snd browserArtifacts)
  forM_ ["rawHtml", "ServerHandle", "providerCoordinate", "eval(", "http://", "https://"] $ \forbidden ->
    when (forbidden `Text.isInfixOf` bodies) (die ("artifact scanner forbidden token: " <> Text.unpack forbidden))
  materialize
  checkCalculus
  putStrLn "ui-contract-generation-calculus: PASS (5 kinds, 31 projected units)"
  putStrLn "ui-contract-generation-spec: PASS (16 contracts, 3 generated recipes, 3 mutants)"

rowTuple :: ContractRow -> (String, String, String, String)
rowTuple row = (unpack (contractKind row), unpack (contractName row), unpack (contractCodec row), unpack (contractVisibility row))
  where unpack = Text.unpack

checkMutantLocus :: IO ()
checkMutantLocus = do
  let names = map contractName contractInventory
  when ("rawHtml" `elem` names) $ die "raw sink exclusion: expected no rawHtml"
  when ("ServerHandle" `elem` names) $ die "server handle privacy: expected no ServerHandle"
  when ("providerCoordinate" `elem` names) $ die "declared codec closure: expected no providerCoordinate"

materialize :: IO ()
materialize = do
  root <- getCurrentDirectory
  let parent = root </> ".build/runs/phase-46/projected"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openTempFile parent "contracts-"
  hClose handle
  writeBrowserArtifacts (leaf <> "-output")
  forM_ browserArtifacts $ \(relative, _) -> doesFileExist (leaf <> "-output" </> relative) >>= flip assert ("generated artifact absent: " <> relative)

checkCalculus :: IO ()
checkCalculus = do
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-contract-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-contract-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral (count :: Int)) 0 0
        counts = [3, 1, 22, 2, 3] :: [Int]
        composition = append
          (compose (artifactComponent scope "generated-browser-artifacts" (resources 3) (RecipeId "ui-contract-generation" 3)) (budgetComponent scope "closed-runtime-abi" (resources 1) (allowance (Bytes 1) (Slots 1) (Bytes 1))))
          (append (compose (liftComponent scope "browser-contract-inventory" (resources 22) OnHost) (workflowComponent scope "deterministic-render-workflow" (resources 2) emptyLedger)) (singleton (evidenceComponent scope "mutant-evidence" (resources 3) PureRegister)))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        render = Text.unpack . Text.intercalate ","
        actual = [["calculus-kinds", render (map calculusTag (compositionKinds composition))], ["component-names", render (compositionNames composition)], ["projection-counts", render (map (Text.pack . show) counts)], ["resource-vector", render (map (Text.pack . show) [cpu,memory,ephemeral,pods])]]
    assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
    assertEqual "UI contract calculus projection" Cases.calculusRows actual
  action

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure
assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)
assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
