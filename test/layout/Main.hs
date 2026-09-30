{-# LANGUAGE OverloadedStrings #-}

-- | Produce layout observations for the independently authored oracle.
module Main (main) where

import Amoebius.Layout.Classify
import Amoebius.Layout.PackageMap
  ( emptyPackageCatalog, maintainedForkPaths, packageCatalogFromInputs
  , packageCatalogWithPrelude, packageCatalogWithModuleExports
  , packageCatalogWithModuleMembers)
import Amoebius.Layout.PbGrammar
import Amoebius.Layout.Report (runLayoutReport)
import Amoebius.Layout.SourceGraph (sourceGraph, sourceGraphWithPackageCatalog)
import Amoebius.Plan.Legacy (LegacyId (..), LegacyOwner (..), legacyOwner)
import Amoebius.Plan.PhaseIdentity (lookupCapabilityOrdinal)
import Amoebius.Toolchain.Provenance (forkModules)
import Control.Exception (SomeException, fromException, try)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (isPrefixOf, sort)
import Data.Char (isAlphaNum)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock.POSIX (getPOSIXTime)
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, getCurrentDirectory, listDirectory)
import System.Environment (getArgs)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import System.Process (readProcess)

main :: IO ()
main = do
  arguments <- getArgs
  let directory = case arguments of
        [path] -> path
        _ -> ".build/runs/layout-suite"
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  discovered <- concat <$> mapM (walk root) sourceRoots
  let paths = sort (metadata <> filter (`notElem` metadata) discovered)
      pathFile = directory </> "paths.txt"
  TextIO.writeFile pathFile (Text.unlines (map Text.pack paths))
  bootstrap <- ByteString.readFile (root </> "pb/__main__.py")
  gitIgnore <- TextIO.readFile (root </> ".gitignore")
  let miniature = directory </> "miniature"
      miniaturePaths = paths
      miniaturePathFile = directory </> "miniature-paths.txt"
  createDirectoryIfMissing True miniature
  mapM_ (copyInto root miniature) miniaturePaths
  TextIO.writeFile miniaturePathFile (Text.unlines (map Text.pack miniaturePaths))
  badOptions <- reportExit (runLayoutReport ["--unexpected"])
  nestedOutput <- reportExit (runLayoutReport ["--root", miniature, "--paths-file", miniaturePathFile, "--output", directory </> "nested" </> "output" </> "report.tsv"])
  createDirectoryIfMissing True (miniature </> "test")
  TextIO.writeFile (miniature </> "test" </> "shebang.hs") "#!/bin/sh\n"
  TextIO.writeFile (directory </> "shebang-paths.txt") (Text.unlines (map Text.pack (miniaturePaths <> ["test/shebang.hs"])))
  shebangExit <- reportExit (runLayoutReport ["--root", miniature, "--paths-file", directory </> "shebang-paths.txt", "--output", directory </> "shebang.tsv"])
  gitRoot <- Text.strip . Text.pack <$> readProcess "git" ["rev-parse", "--show-toplevel"] ""
  defaultExit <- reportExit (runLayoutReport ["--root", Text.unpack gitRoot, "--output", directory </> "default.tsv"])
  let graphRoot = directory </> "graph-challenge"
  createDirectoryIfMissing True graphRoot
  createDirectoryIfMissing True (graphRoot </> "other")
  TextIO.writeFile (graphRoot </> "Duplicate.hs")
    "module Duplicate (value, Item(..)) where\nvalue = ()\ndata Item = Item { itemField :: () }\ndata Hidden = Hidden\n"
  TextIO.writeFile (graphRoot </> "other/Duplicate.hs") "module Duplicate where\nvalue = ()\n"
  TextIO.writeFile (graphRoot </> "Mismatched.hs") "module Wrong where\nvalue = ()\n"
  TextIO.writeFile (graphRoot </> "Calls.hs")
    "module Calls where\nimport qualified Data.Text as Text\ndata Box a = Box { boxValue :: a } deriving (Eq)\ncallee x = x\ncaller y = callee y\ndoubleCall = (callee (), callee ())\nlocalCaller y = let helper z = callee z in helper y\nshadow y = let callee z = z in callee y\nparameterShadow callee = callee ()\ncaseShadow value = case value of callee -> callee ()\nifBranch flag = if flag then callee () else ()\ndoShadow action = do\n  callee <- action\n  callee ()\nguardShadow value\n  | Just callee <- value = callee ()\n  | otherwise = ()\ntupleCaller y = (callee y, y)\nrecordCaller y = Box { boxValue = callee y }\nupdateCaller y = (Box y) { boxValue = callee y }\nselectorCaller y = boxValue y\napply f x = f x\nhigherOrder = apply callee ()\n(patternA, patternB) = (callee (), ())\nrange = [1..3]\nclass C a where\n  method :: a -> a\n  method x = callee x\ninstance C Int where\n  method x = callee x\n"
  TextIO.appendFile (graphRoot </> "Calls.hs")
    "effectful :: () -> IO ()\neffectful _ = pure ()\neffectCaller x = effectful x\neffectTop = effectCaller ()\neffectShadow effectful = effectful ()\naliasCaller x = let forward = callee in forward x\naliasEffect = let forward = effectful in forward ()\naliasParameter f x = let forward = f in forward x\naliasTuple = let (left, right) = (callee, callee) in left ()\naliasQualified = let forward = Text.pack in forward \"x\"\npairCtor = (,) () ()\n"
  TextIO.writeFile (graphRoot </> "PlainData.hs")
    "module PlainData where\ndata Plain = Plain { plainValue :: Int }\n"
  TextIO.writeFile (graphRoot </> "ClassProvider.hs")
    "module ClassProvider (C(doThing)) where\nclass C a where\n  doThing :: a -> a\ninstance C () where\n  doThing x = x\n"
  TextIO.writeFile (graphRoot </> "UseClass.hs")
    "module UseClass where\nimport ClassProvider (C(doThing))\nuse = doThing ()\n"
  TextIO.writeFile (graphRoot </> "UseClassHidden.hs")
    "module UseClassHidden where\nimport ClassProvider (C)\nuse = doThing ()\n"
  TextIO.writeFile (graphRoot </> "UseClassInstance.hs")
    "module UseClassInstance where\nimport ClassProvider (C(..))\ninstance C Bool where\n  doThing x = x\n"
  TextIO.writeFile (graphRoot </> "UseClassInstanceHidden.hs")
    "module UseClassInstanceHidden where\nimport ClassProvider (C)\ninstance C Char where\n  doThing x = x\n"
  TextIO.writeFile (graphRoot </> "RecordProvider.hs")
    "module RecordProvider (Box(..)) where\ndata Box = Box { field :: Int }\n"
  TextIO.writeFile (graphRoot </> "UseDot.hs")
    "{-# LANGUAGE OverloadedRecordDot #-}\nmodule UseDot where\nimport qualified RecordProvider as P\nuse value = value.field\nmissing value = value.absent\nproject = (.field)\n"
  TextIO.writeFile (graphRoot </> "Use.hs")
    "module Use where\nimport Duplicate\nuse = Duplicate.value ()\nmakeItem = Duplicate.Item ()\nreadItem = Duplicate.itemField (Duplicate.Item ())\n"
  TextIO.writeFile (graphRoot </> "UseAlias.hs")
    "module UseAlias where\nimport qualified Duplicate as D\nuse = D.value ()\naliasUse = let forward = D.value in forward ()\n"
  TextIO.writeFile (graphRoot </> "EffectProvider.hs")
    "module EffectProvider where\neffectful :: () -> IO ()\neffectful _ = pure ()\n"
  TextIO.writeFile (graphRoot </> "UseEffect.hs")
    "module UseEffect where\nimport EffectProvider (effectful)\ninvoke = let forward = effectful in forward ()\n"
  TextIO.writeFile (graphRoot </> "UseSelective.hs")
    "module UseSelective where\nimport Duplicate (Item(..))\nmakeItem = Item ()\nreadItem = itemField (Item ())\n"
  TextIO.writeFile (graphRoot </> "UseConstructorOnly.hs")
    "module UseConstructorOnly where\nimport Duplicate (Item(Item))\nmakeItem = Item ()\nreadItem = itemField (Item ())\n"
  TextIO.writeFile (graphRoot </> "UseHidden.hs")
    "module UseHidden where\nimport Duplicate\nmakeHidden = Hidden\n"
  TextIO.writeFile (graphRoot </> "UseValue.hs")
    "module UseValue where\nimport Duplicate (value)\npass x = x\nuse = pass Duplicate.value\n"
  TextIO.writeFile (graphRoot </> "Reexport.hs")
    "module Reexport (module Duplicate) where\nimport Duplicate\n"
  TextIO.writeFile (graphRoot </> "UseReexport.hs")
    "module UseReexport where\nimport Reexport\nuse = value ()\n"
  TextIO.writeFile (graphRoot </> "AliasReexport.hs")
    "module AliasReexport (module D) where\nimport Duplicate as D\n"
  TextIO.writeFile (graphRoot </> "UseAliasReexport.hs")
    "module UseAliasReexport where\nimport AliasReexport\nuse = value ()\n"
  TextIO.writeFile (graphRoot </> "QualifiedReexport.hs")
    "module QualifiedReexport (module D) where\nimport qualified Duplicate as D\n"
  TextIO.writeFile (graphRoot </> "UseQualifiedReexport.hs")
    "module UseQualifiedReexport where\nimport QualifiedReexport\nuse = value ()\n"
  TextIO.writeFile (graphRoot </> "ExplicitReexport.hs")
    "module ExplicitReexport (value) where\nimport Duplicate (value)\n"
  TextIO.writeFile (graphRoot </> "UseExplicitReexport.hs")
    "module UseExplicitReexport where\nimport ExplicitReexport\nuse = value ()\n"
  TextIO.writeFile (graphRoot </> "ExplicitDataReexport.hs")
    "module ExplicitDataReexport (Item(..)) where\nimport Duplicate (Item(..))\n"
  TextIO.writeFile (graphRoot </> "UseExplicitDataReexport.hs")
    "module UseExplicitDataReexport where\nimport ExplicitDataReexport (Item(..))\nmakeItem = Item ()\nreadItem = itemField (Item ())\n"
  TextIO.writeFile (graphRoot </> "HiddenReexport.hs")
    "module HiddenReexport (module Duplicate) where\nimport Duplicate hiding (value)\n"
  TextIO.writeFile (graphRoot </> "UseHiddenReexport.hs")
    "module UseHiddenReexport where\nimport HiddenReexport\nuse = value ()\nmakeItem = Item ()\n"
  TextIO.writeFile (graphRoot </> "UseHiding.hs")
    "module UseHiding where\nimport Duplicate hiding (value)\nuse = value ()\nmakeItem = Item ()\n"
  TextIO.writeFile (graphRoot </> "UseHidingType.hs")
    "module UseHidingType where\nimport Duplicate hiding (Item)\nuse = Item ()\n"
  TextIO.writeFile (graphRoot </> "SpliceExpr.hs")
    "{-# LANGUAGE TemplateHaskell #-}\nmodule SpliceExpr where\nvalue = $(generateValue)\n"
  TextIO.writeFile (graphRoot </> "SpliceDecl.hs")
    "{-# LANGUAGE TemplateHaskell #-}\nmodule SpliceDecl where\n$(makeSomething)\n"
  TextIO.writeFile (graphRoot </> "Foreign.hs")
    "{-# LANGUAGE ForeignFunctionInterface #-}\nmodule Foreign where\nforeign import ccall \"foreign_value\" foreignValue :: Int -> IO Int\nuse = foreignValue 1\n"
  TextIO.writeFile (graphRoot </> "Derive.hs")
    "{-# LANGUAGE StandaloneDeriving #-}\nmodule Derive where\ndata Mark = Mark\nderiving instance Eq Mark\n"
  TextIO.writeFile (graphRoot </> "NoPreludeStandaloneDerive.hs")
    "{-# LANGUAGE NoImplicitPrelude #-}\n{-# LANGUAGE StandaloneDeriving #-}\nmodule NoPreludeStandaloneDerive where\ndata Mark = Mark\nderiving instance Eq Mark\n"
  TextIO.writeFile (graphRoot </> "ExplicitPreludeStandaloneDerive.hs")
    "{-# LANGUAGE NoImplicitPrelude #-}\n{-# LANGUAGE StandaloneDeriving #-}\nmodule ExplicitPreludeStandaloneDerive where\nimport Prelude (Eq(..))\ndata Mark = Mark\nderiving instance Eq Mark\n"
  TextIO.writeFile (graphRoot </> "UseFiltered.hs")
    "module UseFiltered where\nimport Duplicate ()\nuse = Duplicate.value ()\n"
  TextIO.writeFile (graphRoot </> "UsePackage.hs")
    "{-# LANGUAGE PackageImports #-}\nmodule UsePackage where\nimport \"foreign\" Duplicate\nuse = Duplicate.value ()\n"
  TextIO.writeFile (graphRoot </> "UseExternal.hs")
    "module UseExternal where\nimport Example.Provider (helper)\nuse = helper ()\n"
  TextIO.writeFile (graphRoot </> "UseRegisteredOnly.hs")
    "module UseRegisteredOnly where\nimport Example.Provider (helper)\nuse = helper ()\nmissing = absent ()\n"
  TextIO.writeFile (graphRoot </> "UseExternalMember.hs")
    "module UseExternalMember where\nimport Example.Provider (Thing(..))\nuse = field ()\nwrong = unrelated ()\n"
  TextIO.writeFile (graphRoot </> "UseExternalWrongMember.hs")
    "module UseExternalWrongMember where\nimport Example.Provider (Other(..))\nwrong = field ()\n"
  TextIO.writeFile (graphRoot </> "UseFuture.hs")
    "module UseFuture where\nimport Infernix.Topic.Metadata\nvalue = ()\n"
  TextIO.writeFile (graphRoot </> "UseFutureCall.hs")
    "module UseFutureCall where\nimport Infernix.Topic.Metadata (lookupCompactedView, KeyedEvent(..))\nuse = lookupCompactedView ()\nconstruct = KeyedEvent ()\nmissing = notListed ()\n"
  TextIO.writeFile (graphRoot </> "StandaloneLocal.hs")
    "module StandaloneLocal where\ncallee x = x\nuse = callee ()\nshadow callee = callee ()\n"
  TextIO.writeFile (graphRoot </> "StandaloneProvider.hs")
    "module StandaloneProvider (provided) where\nprovided x = x\nhidden x = x\n"
  TextIO.writeFile (graphRoot </> "StandaloneUse.hs")
    "module StandaloneUse where\nimport StandaloneProvider (provided)\nuse = provided ()\nmissing = hidden ()\n"
  TextIO.writeFile (graphRoot </> "UseJitFuture.hs")
    "module UseJitFuture where\nimport JitML.Codegen.RuntimeOperationsCuda\nvalue = ()\n"
  TextIO.writeFile (graphRoot </> "UseExternalBroad.hs")
    "module UseExternalBroad where\nimport Example.Provider\nuse = helper ()\n"
  TextIO.writeFile (graphRoot </> "UseExternalOpen.hs")
    "module UseExternalOpen where\nimport Example.Provider\nuse = helper ()\nmissing = absent ()\nqualifiedGood = Example.Provider.helper ()\nqualifiedMissing = Example.Provider.absent ()\naliasGood = let forward = Example.Provider.helper in forward ()\naliasOpen = let forward = helper in forward ()\naliasMissing = let forward = Example.Provider.absent in forward ()\n"
  TextIO.writeFile (graphRoot </> "UseExternalHiding.hs")
    "module UseExternalHiding where\nimport Example.Provider hiding (absent)\nuse = helper ()\nhidden = absent ()\nhiddenQualified = Example.Provider.absent ()\n"
  TextIO.writeFile (graphRoot </> "ImplicitPrelude.hs")
    "module ImplicitPrelude where\nuse = map id []\ncompose = id . id\n"
  TextIO.writeFile (graphRoot </> "NoPrelude.hs")
    "{-# LANGUAGE NoImplicitPrelude #-}\nmodule NoPrelude where\nuse = map id []\ncons x xs = x : xs\n"
  TextIO.writeFile (graphRoot </> "NoPreludeDerive.hs")
    "{-# LANGUAGE NoImplicitPrelude #-}\nmodule NoPreludeDerive where\ndata Mark = Mark deriving (Eq)\n"
  TextIO.writeFile (graphRoot </> "ExplicitPreludeDerive.hs")
    "{-# LANGUAGE NoImplicitPrelude #-}\nmodule ExplicitPreludeDerive where\nimport Prelude (Eq(..))\ndata Mark = Mark deriving (Eq)\n"
  let selectedPlan = ByteString8.pack
        "{\"compiler-id\":\"ghc-9.12.4\",\"compiler-abi\":\"5301\",\"install-plan\":[{\"id\":\"provider-unit\",\"pkg-name\":\"provider\"},{\"id\":\"consumer-unit\",\"pkg-name\":\"amoebius\",\"component-name\":\"test:consumer\",\"depends\":[\"provider-unit\"]}]}"
      registeredProvider = "name: provider\nid:\n    provider-unit\nexposed-modules:\n    Example.Provider\n"
      preludePlan = ByteString8.pack
        "{\"compiler-id\":\"ghc-9.12.4\",\"compiler-abi\":\"5301\",\"install-plan\":[{\"id\":\"base-unit\",\"pkg-name\":\"base\"},{\"id\":\"consumer-unit\",\"pkg-name\":\"amoebius\",\"component-name\":\"test:consumer\",\"depends\":[\"base-unit\"]}]}"
      registeredPrelude = "name: base\nid:\n    base-unit\nexposed-modules:\n    Prelude\n"
      registeredOnlyCatalog = packageCatalogWithModuleExports
        (Map.singleton ("provider-unit", "Example.Provider") (Set.singleton "helper")) <$>
          packageCatalogFromInputs (Map.singleton "test:consumer" ["base"]) preludePlan
            (registeredPrelude <> "---\n" <> registeredProvider)
      preludeCatalog = packageCatalogWithPrelude
        (Map.singleton "base-unit" (Set.fromList ["map", "id", "."])) <$>
          packageCatalogFromInputs
            (Map.fromList [("test:consumer", ["base"]), ("test:unplanned", ["base"])])
            preludePlan registeredPrelude
      selectedCatalog = packageCatalogFromInputs
        (Map.singleton "test:consumer" ["provider"]) selectedPlan registeredProvider
      unselectedCatalog = packageCatalogFromInputs
        (Map.fromList [("test:consumer", ["provider"]), ("test:unplanned", ["provider"])])
        selectedPlan registeredProvider
      futureCatalog = packageCatalogFromInputs
        (Map.fromList [("test:consumer", ["provider"]), ("library:infernix", ["infernix"]),
          ("library:jitml", ["jitml"]), ("test:other", ["infernix"])]) selectedPlan registeredProvider
      mismatchedPlan = packageCatalogFromInputs
        (Map.singleton "test:consumer" ["other"]) selectedPlan registeredProvider
      absentUnit = packageCatalogFromInputs
        (Map.singleton "test:consumer" ["provider"]) selectedPlan ""
  (externalFindings, externalRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternal.hs"]
      (Map.singleton "UseExternal.hs" ["test:consumer"]) Map.empty catalog Map.empty
  let memberCatalog = packageCatalogWithModuleMembers
        (Map.singleton ("provider-unit", "Example.Provider", "Thing") (Set.singleton "field"))
        . packageCatalogWithModuleExports
          (Map.singleton ("provider-unit", "Example.Provider") (Set.fromList ["field", "unrelated"]))
  (externalMemberFindings, externalMemberRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot
      ["UseExternalMember.hs", "UseExternalWrongMember.hs"]
      (Map.fromList [("UseExternalMember.hs", ["test:consumer"]),
        ("UseExternalWrongMember.hs", ["test:consumer"])]) Map.empty
      (memberCatalog catalog) Map.empty
  (availableMemberFindings, availableMemberRows) <- case unselectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalMember.hs"]
      (Map.singleton "UseExternalMember.hs" ["test:unplanned"]) Map.empty
      (memberCatalog catalog) Map.empty
  (standaloneExternalMemberFindings, standaloneExternalMemberRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalMember.hs"]
      Map.empty Map.empty (memberCatalog catalog) Map.empty
  (broadExternalFindings, broadExternalRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalBroad.hs"]
      (Map.singleton "UseExternalBroad.hs" ["test:consumer"]) Map.empty catalog Map.empty
  (openExternalFindings, openExternalRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalOpen.hs"]
      (Map.singleton "UseExternalOpen.hs" ["test:consumer"]) Map.empty
      (packageCatalogWithModuleExports
        (Map.singleton ("provider-unit", "Example.Provider") (Set.singleton "helper")) catalog) Map.empty
  (standaloneExternalFindings, standaloneExternalRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalOpen.hs"]
      Map.empty Map.empty (packageCatalogWithModuleExports
      (Map.singleton ("provider-unit", "Example.Provider") (Set.singleton "helper")) catalog) Map.empty
  (registeredOnlyFindings, registeredOnlyRows) <- case registeredOnlyCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseRegisteredOnly.hs"]
      Map.empty Map.empty catalog Map.empty
  (hidingExternalFindings, hidingExternalRows) <- case selectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalHiding.hs"]
      (Map.singleton "UseExternalHiding.hs" ["test:consumer"]) Map.empty
      (packageCatalogWithModuleExports
        (Map.singleton ("provider-unit", "Example.Provider") (Set.fromList ["helper", "absent"])) catalog) Map.empty
  (implicitPreludeFindings, implicitPreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["ImplicitPrelude.hs"]
      (Map.singleton "ImplicitPrelude.hs" ["test:consumer"]) Map.empty catalog Map.empty
  (noPreludeFindings, noPreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["NoPrelude.hs"]
      (Map.singleton "NoPrelude.hs" ["test:consumer"]) Map.empty catalog Map.empty
  (availablePreludeFindings, availablePreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["ImplicitPrelude.hs"]
      (Map.singleton "ImplicitPrelude.hs" ["test:unplanned"]) Map.empty catalog Map.empty
  (availableNoPreludeFindings, availableNoPreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["NoPrelude.hs"]
      (Map.singleton "NoPrelude.hs" ["test:unplanned"]) Map.empty catalog Map.empty
  let derivedPreludeCatalog = packageCatalogWithModuleMembers
        (Map.singleton ("base-unit", "Prelude", "Eq") (Set.fromList ["==", "/="]))
        . packageCatalogWithModuleExports
          (Map.singleton ("base-unit", "Prelude") (Set.fromList ["Eq", "==", "/="]))
  (derivedPreludeFindings, derivedPreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["Calls.hs"]
      (Map.singleton "Calls.hs" ["test:consumer"]) Map.empty
      (derivedPreludeCatalog catalog) Map.empty
  (noPreludeDeriveFindings, noPreludeDeriveRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["NoPreludeDerive.hs"]
      (Map.singleton "NoPreludeDerive.hs" ["test:consumer"]) Map.empty
      (derivedPreludeCatalog catalog) Map.empty
  (explicitPreludeDeriveFindings, explicitPreludeDeriveRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["ExplicitPreludeDerive.hs"]
      (Map.singleton "ExplicitPreludeDerive.hs" ["test:consumer"]) Map.empty
      (derivedPreludeCatalog catalog) Map.empty
  (standaloneDerivePreludeFindings, standaloneDerivePreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["Derive.hs"]
      (Map.singleton "Derive.hs" ["test:consumer"]) Map.empty
      (derivedPreludeCatalog catalog) Map.empty
  (noPreludeStandaloneDeriveFindings, noPreludeStandaloneDeriveRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["NoPreludeStandaloneDerive.hs"]
      (Map.singleton "NoPreludeStandaloneDerive.hs" ["test:consumer"]) Map.empty
      (derivedPreludeCatalog catalog) Map.empty
  (explicitPreludeStandaloneDeriveFindings, explicitPreludeStandaloneDeriveRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["ExplicitPreludeStandaloneDerive.hs"]
      (Map.singleton "ExplicitPreludeStandaloneDerive.hs" ["test:consumer"]) Map.empty
      (derivedPreludeCatalog catalog) Map.empty
  (standalonePreludeFindings, standalonePreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["ImplicitPrelude.hs"]
      Map.empty Map.empty catalog Map.empty
  (standaloneNoPreludeFindings, standaloneNoPreludeRows) <- case preludeCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["NoPrelude.hs"]
      Map.empty Map.empty catalog Map.empty
  (unplannedFindings, unplannedRows) <- sourceGraph graphRoot ["UseExternal.hs"]
    (Map.singleton "UseExternal.hs" ["test:consumer"]) Map.empty
  (forwardFindings, forwardRows) <- sourceGraphWithPackageCatalog graphRoot ["UseExternal.hs"]
    (Map.singleton "UseExternal.hs" ["test:consumer"]) Map.empty emptyPackageCatalog
    (Map.singleton ("test:consumer", "Example.Provider") ("Example/Provider.hs", "generated-control"))
  (unselectedFindings, unselectedRows) <- case unselectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternal.hs"]
      (Map.singleton "UseExternal.hs" ["test:unplanned"]) Map.empty catalog Map.empty
  (availableFindings, availableRows) <- case unselectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternal.hs"]
      (Map.singleton "UseExternal.hs" ["test:unplanned"]) Map.empty
      (packageCatalogWithModuleExports
        (Map.singleton ("provider-unit", "Example.Provider") (Set.singleton "helper")) catalog) Map.empty
  (availableCallFindings, availableCallRows) <- case unselectedCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseExternalOpen.hs"]
      (Map.singleton "UseExternalOpen.hs" ["test:unplanned"]) Map.empty
      (packageCatalogWithModuleExports
        (Map.singleton ("provider-unit", "Example.Provider") (Set.singleton "helper")) catalog) Map.empty
  (futureFindings, futureRows) <- case futureCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseFuture.hs"]
      (Map.singleton "UseFuture.hs" ["library:infernix"]) Map.empty catalog Map.empty
  (futureCallFindings, futureCallRows) <- case futureCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseFutureCall.hs"]
      (Map.singleton "UseFutureCall.hs" ["library:infernix"]) Map.empty catalog Map.empty
  (futureWrongOwnerFindings, futureWrongOwnerRows) <- case futureCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseFuture.hs"]
      (Map.singleton "UseFuture.hs" ["test:other"]) Map.empty catalog Map.empty
  (jitFutureFindings, jitFutureRows) <- case futureCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseJitFuture.hs"]
      (Map.singleton "UseJitFuture.hs" ["test:jitml-cuda-artifact-lift-contract"])
      (Map.singleton "test:jitml-cuda-artifact-lift-contract" ["library:jitml"]) catalog Map.empty
  (jitFutureMissingDependencyFindings, jitFutureMissingDependencyRows) <- case futureCatalog of
    Left problem -> pure ([problem], [])
    Right catalog -> sourceGraphWithPackageCatalog graphRoot ["UseJitFuture.hs"]
      (Map.singleton "UseJitFuture.hs" ["test:jitml-cuda-artifact-lift-contract"])
      Map.empty catalog Map.empty
  let sharedComponent = Map.fromList
        [("Duplicate.hs", ["test:graph"]), ("other/Duplicate.hs", ["test:graph"]), ("Use.hs", ["test:graph"])]
      separateComponents = Map.fromList
        [("Duplicate.hs", ["test:first"]), ("other/Duplicate.hs", ["test:second"]), ("Use.hs", ["test:first"])]
  (localFindings, localRows) <- sourceGraph graphRoot ["Duplicate.hs", "Use.hs"]
    (Map.delete "other/Duplicate.hs" separateComponents) Map.empty
  (classMethodFindings, classMethodRows) <- sourceGraph graphRoot
    ["ClassProvider.hs", "UseClass.hs", "UseClassHidden.hs",
     "UseClassInstance.hs", "UseClassInstanceHidden.hs"]
    (Map.fromList [("ClassProvider.hs", ["test:graph"]),
      ("UseClass.hs", ["test:graph"]), ("UseClassHidden.hs", ["test:graph"]),
      ("UseClassInstance.hs", ["test:graph"]),
      ("UseClassInstanceHidden.hs", ["test:graph"])]) Map.empty
  (recordDotFindings, recordDotRows) <- sourceGraph graphRoot
    ["RecordProvider.hs", "UseDot.hs"]
    (Map.fromList [("RecordProvider.hs", ["test:graph"]),
      ("UseDot.hs", ["test:graph"])]) Map.empty
  (ambiguousFindings, ambiguousRows) <- sourceGraph graphRoot ["Duplicate.hs", "other/Duplicate.hs", "Use.hs"]
    sharedComponent Map.empty
  (separateFindings, separateRows) <- sourceGraph graphRoot ["Duplicate.hs", "other/Duplicate.hs", "Use.hs"]
    separateComponents Map.empty
  let dependencyOwners = Map.fromList [("Duplicate.hs", ["test:provider"]), ("Use.hs", ["test:consumer"])]
  (dependencyFindings, dependencyRows) <- sourceGraph graphRoot ["Duplicate.hs", "Use.hs"]
    dependencyOwners (Map.singleton "test:consumer" ["test:provider"])
  (unlistedFindings, unlistedRows) <- sourceGraph graphRoot ["Duplicate.hs", "Use.hs"]
    dependencyOwners Map.empty
  (packageFindings, packageRows) <- sourceGraph graphRoot ["Duplicate.hs", "UsePackage.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UsePackage.hs", ["test:first"])]) Map.empty
  (aliasFindings, aliasRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseAlias.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UseAlias.hs", ["test:first"])]) Map.empty
  (effectAliasFindings, effectAliasRows) <- sourceGraph graphRoot ["EffectProvider.hs", "UseEffect.hs"]
    (Map.fromList [("EffectProvider.hs", ["test:provider"]), ("UseEffect.hs", ["test:consumer"])])
    (Map.singleton "test:consumer" ["test:provider"])
  (selectiveFindings, selectiveRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseSelective.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UseSelective.hs", ["test:first"])]) Map.empty
  (constructorOnlyFindings, constructorOnlyRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseConstructorOnly.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UseConstructorOnly.hs", ["test:first"])]) Map.empty
  (hiddenFindings, hiddenRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseHidden.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UseHidden.hs", ["test:first"])]) Map.empty
  (valueFindings, valueRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseValue.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UseValue.hs", ["test:first"])]) Map.empty
  let reexportOwners ownedPaths = Map.fromList [(path, ["test:first"]) | path <- ownedPaths]
      reexportSource through consumer = ["Duplicate.hs", through, consumer]
  (reexportFindings, reexportRows) <- sourceGraph graphRoot (reexportSource "Reexport.hs" "UseReexport.hs")
    (reexportOwners (reexportSource "Reexport.hs" "UseReexport.hs")) Map.empty
  (aliasReexportFindings, aliasReexportRows) <- sourceGraph graphRoot
    (reexportSource "AliasReexport.hs" "UseAliasReexport.hs")
    (reexportOwners (reexportSource "AliasReexport.hs" "UseAliasReexport.hs")) Map.empty
  (qualifiedReexportFindings, qualifiedReexportRows) <- sourceGraph graphRoot
    (reexportSource "QualifiedReexport.hs" "UseQualifiedReexport.hs")
    (reexportOwners (reexportSource "QualifiedReexport.hs" "UseQualifiedReexport.hs")) Map.empty
  (explicitReexportFindings, explicitReexportRows) <- sourceGraph graphRoot
    (reexportSource "ExplicitReexport.hs" "UseExplicitReexport.hs")
    (reexportOwners (reexportSource "ExplicitReexport.hs" "UseExplicitReexport.hs")) Map.empty
  (explicitDataReexportFindings, explicitDataReexportRows) <- sourceGraph graphRoot
    (reexportSource "ExplicitDataReexport.hs" "UseExplicitDataReexport.hs")
    (reexportOwners (reexportSource "ExplicitDataReexport.hs" "UseExplicitDataReexport.hs")) Map.empty
  (hiddenReexportFindings, hiddenReexportRows) <- sourceGraph graphRoot
    (reexportSource "HiddenReexport.hs" "UseHiddenReexport.hs")
    (reexportOwners (reexportSource "HiddenReexport.hs" "UseHiddenReexport.hs")) Map.empty
  (hidingFindings, hidingRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseHiding.hs"]
    (reexportOwners ["Duplicate.hs", "UseHiding.hs"]) Map.empty
  (hidingTypeFindings, hidingTypeRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseHidingType.hs"]
    (reexportOwners ["Duplicate.hs", "UseHidingType.hs"]) Map.empty
  (spliceFindings, spliceRows) <- sourceGraph graphRoot ["SpliceExpr.hs", "SpliceDecl.hs"]
    (Map.fromList [("SpliceExpr.hs", ["test:graph"]), ("SpliceDecl.hs", ["test:graph"])]) Map.empty
  (foreignFindings, foreignRows) <- sourceGraph graphRoot ["Foreign.hs"]
    (Map.singleton "Foreign.hs" ["test:graph"]) Map.empty
  (derivingFindings, derivingRows) <- sourceGraph graphRoot ["Derive.hs"]
    (Map.singleton "Derive.hs" ["test:graph"]) Map.empty
  (filteredFindings, filteredRows) <- sourceGraph graphRoot ["Duplicate.hs", "UseFiltered.hs"]
    (Map.fromList [("Duplicate.hs", ["test:first"]), ("UseFiltered.hs", ["test:first"])]) Map.empty
  (standaloneFindings, standaloneRows) <- sourceGraph graphRoot ["Duplicate.hs"] Map.empty Map.empty
  (standaloneLocalFindings, standaloneLocalRows) <- sourceGraph graphRoot
    ["StandaloneLocal.hs"] Map.empty Map.empty
  (standaloneImportedFindings, standaloneImportedRows) <- sourceGraph graphRoot
    ["StandaloneProvider.hs", "StandaloneUse.hs"] Map.empty Map.empty
  (mismatchedFindings, _) <- sourceGraph graphRoot ["Mismatched.hs"]
    (Map.singleton "Mismatched.hs" ["test:graph"]) Map.empty
  (callFindings, callRows) <- sourceGraph graphRoot ["Calls.hs"]
    (Map.singleton "Calls.hs" ["test:graph"]) Map.empty
  (plainDataFindings, plainDataRows) <- sourceGraph graphRoot ["PlainData.hs"]
    (Map.singleton "PlainData.hs" ["test:graph"]) Map.empty
  issued <- getPOSIXTime
  let nonce = filter isAlphaNum (show issued)
      challenges =
        [ ("python", "src/Challenge" <> nonce <> ".py", "NonHaskellSource")
        , ("dhall", "dhall/Challenge" <> nonce <> ".dhall", "ForeignSourceOwed")
        , ("pulumi", "pulumi/Pulumi" <> nonce <> ".yaml", "TrackedPulumiProgram")
        , ("ordinal", "src/Amoebius/Challenge" <> nonce <> ".hs", "OrdinalRuntimeIdentity")
        , ("unmapped", "src/Amoebius/Challenge" <> nonce <> ".hs", "UnmappedHaskellSource")
        , ("vendor", "src/vendor/Challenge" <> nonce <> ".hs", "UnmappedHaskellSource")
        , ("syntax", "test/negative/Challenge" <> nonce <> ".hs", "HaskellSourceUnparsable")
        ]
  challenged <- mapM (runChallenge root directory paths) challenges
  TextIO.writeFile (directory </> "challenge-paths.tsv")
    (Text.unlines [Text.intercalate "\t" [Text.pack name, Text.pack path, tag] | (name, path, tag) <- challenges])
  let cases =
        [ ("positive.test-module", pathResult "test/unit/Main.hs")
        , ("positive.probe-package", pathResult "probe/probe.cabal")
        , ("positive.bootstrap", bootstrapResult bootstrap)
        , ("positive.archive", pathResult archiveExample)
        , ("negative.test-script", pathResult "test/unit/check.py")
        , ("negative.test-table", pathResult "test/layout/expected.tsv")
        , ("negative.python", pathResult "src/example.py")
        , ("negative.dhall", pathResult "dhall/example.dhall")
        , ("negative.pulumi", pathResult "pulumi/Pulumi.yaml")
        , ("negative.tool", pathResult "tools/check")
        , ("negative.archive", pathResult "validation-records/extra.tsv")
        , ("negative.ordinal", pathResult "src/Amoebius/Phase42Runtime.hs")
        , ("negative.absolute", pathResult "/src/Amoebius/Layout/Classify.hs")
        , ("positive.void", pathResult voidExample)
        , ("negative.void-extra", pathResult ("validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-02-extra-" <> replicate 64 'a' <> "-" <> replicate 64 'b' <> ".tsv"))
        , ("negative.bootstrap-change", bootstrapResult (bootstrap <> "\n# changed\n"))
        , ("negative.bootstrap-import", bootstrapResult (bootstrap <> "\nimport socket\n"))
        , ("negative.bootstrap-syntax", bootstrapResult (bootstrap <> "\n@decorator\n"))
        , ("negative.bootstrap-indentation", bootstrapResult (bootstrap <> "\n  extra = 1\n"))
        , ("negative.bootstrap-control", bootstrapResult (bootstrap <> "\nwhile True:\n    pass\n"))
        , ("negative.bootstrap-dynamic", bootstrapResult (bootstrap <> "\neval(\"1\")\n"))
        , ("negative.bootstrap-call", bootstrapResult (bootstrap <> "\nunknown_call()\n"))
        , ("negative.bootstrap-indirect", bootstrapResult (bootstrap <> "\nfn[0](\"1\")\n"))
        , ("negative.bootstrap-comprehension", bootstrapResult (bootstrap <> "\nvalues = [value for value in source]\n"))
        , ("negative.bootstrap-effect", bootstrapResult (bootstrap <> "\nos.system(\"true\")\n"))
        , ("negative.bootstrap-nested-effect", bootstrapResult (bootstrap <> "\npayload = str(target.write_bytes(\"x\"))\n"))
        , ("negative.bootstrap-effect-string", bootstrapResult (bootstrap <> "\nvalue = \"os.system()\"\n"))
        , ("negative.ignore-root", Text.intercalate "," [findingCode finding | finding <- checkIgnorePolicy ".gitignore" (gitIgnore <> "\n/ui/output/\n"), findingCode finding == "RetiredIgnoreRoot"])
        , ("negative.ignore-source", Text.intercalate "," [findingCode finding | finding <- checkIgnorePolicy ".gitignore" (gitIgnore <> "\n/src/Amoebius/generated/\n"), findingCode finding == "UnexpectedIgnorePattern"])
        , ("report.bad-options", badOptions)
        , ("report.nested-output", nestedOutput)
        , ("report.shebang-exit", shebangExit)
        , ("report.default-exit", defaultExit)
        , ("graph.local-link", if null localFindings &&
              "graph-link\ttest:first\tUse.hs\ttest:first\tDuplicate.hs\tDuplicate" `elem` localRows then "linked" else "missing")
        , ("graph.ambiguous-import", if ambiguousFindings ==
              [LayoutFinding "AmbiguousSourceImport" "test:graph:Use.hs:Duplicate"] then "refused" else "missing")
        , ("graph.component-select", if null separateFindings &&
              [row | row <- separateRows, "graph-link\t" `Text.isPrefixOf` row] ==
                ["graph-link\ttest:first\tUse.hs\ttest:first\tDuplicate.hs\tDuplicate"] then "selected" else "missing")
        , ("graph.dependency-link", if null dependencyFindings &&
              "graph-link\ttest:consumer\tUse.hs\ttest:provider\tDuplicate.hs\tDuplicate" `elem` dependencyRows
              then "linked" else "missing")
        , ("graph.unlisted-dependency", if unlistedFindings ==
              [LayoutFinding "InternalImportDependencyMissing" "test:consumer:Use.hs:Duplicate"] &&
              null [row | row <- unlistedRows, "graph-link\t" `Text.isPrefixOf` row]
              then "refused" else "unexpected")
        , ("graph.inaccessible-internal", if unlistedFindings ==
              [LayoutFinding "InternalImportDependencyMissing" "test:consumer:Use.hs:Duplicate"] &&
              "graph-import-unresolved\ttest:consumer\tUse.hs\tDuplicate\tinternal-not-declared" `elem` unlistedRows
              && "graph-import-inaccessible-internal\ttest:consumer\tUse.hs\tDuplicate\ttest:provider\tDuplicate.hs" `elem` unlistedRows
              then "located" else "missing")
        , ("graph.package-qualified", if null packageFindings &&
              null [row | row <- packageRows, "graph-link\t" `Text.isPrefixOf` row]
              && null [row | row <- packageRows, "graph-call-candidate\t" `Text.isPrefixOf` row]
              && "graph-import-unresolved\ttest:first\tUsePackage.hs\tDuplicate\tpackage-qualified" `elem` packageRows
              then "external" else "missing")
        , ("graph.external-unit", if null externalFindings &&
              "graph-import-external\ttest:consumer\tUseExternal.hs\tExample.Provider\tprovider\tprovider-unit" `elem` externalRows
              && null [row | row <- externalRows, "graph-import-unresolved\t" `Text.isPrefixOf` row]
              then "resolved" else "missing")
        , ("graph.external-call-candidate", if null externalFindings &&
              any (\row -> "graph-call-external-candidate\ttest:consumer\tUseExternal.hs\tuse\t" `Text.isPrefixOf` row
                && "\thelper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) externalRows
              then "candidate" else "missing")
        , ("graph.external-member-parent", if null externalMemberFindings &&
              any (\row -> "graph-call-external-member-candidate\ttest:consumer\tUseExternalMember.hs\tuse\t" `Text.isPrefixOf` row
                && "\tfield\tExample.Provider\tprovider\tprovider-unit\tThing\tfield" `Text.isSuffixOf` row) externalMemberRows
              && null [row | row <- externalMemberRows,
                "graph-call-external-member-candidate\ttest:consumer\tUseExternalMember.hs\twrong\t" `Text.isPrefixOf` row
                  || "graph-call-external-member-candidate\ttest:consumer\tUseExternalWrongMember.hs\twrong\t" `Text.isPrefixOf` row]
              then "matched" else "missing")
        , ("graph.available-member-parent", if null availableMemberFindings &&
              any (\row -> "graph-call-available-member-candidate\ttest:unplanned\tUseExternalMember.hs\tuse\t" `Text.isPrefixOf` row
                && "\tfield\tExample.Provider\tprovider\tprovider-unit\tThing\tfield" `Text.isSuffixOf` row) availableMemberRows
              && null [row | row <- availableMemberRows,
                "graph-call-available-member-candidate\ttest:unplanned\tUseExternalMember.hs\twrong\t" `Text.isPrefixOf` row]
              then "matched" else "missing")
        , ("graph.standalone-external-member", if null standaloneExternalMemberFindings
              && any ("graph-call-standalone-external-member-candidate\tUseExternalMember.hs\tuse\t" `Text.isPrefixOf`) standaloneExternalMemberRows
              && null [row | row <- standaloneExternalMemberRows,
                "graph-call-standalone-external-member-candidate\tUseExternalMember.hs\twrong\t" `Text.isPrefixOf` row]
              then "matched" else "missing")
        , ("graph.external-open-import-call", if null broadExternalFindings &&
              "graph-import-external\ttest:consumer\tUseExternalBroad.hs\tExample.Provider\tprovider\tprovider-unit" `elem` broadExternalRows
              && null [row | row <- broadExternalRows,
                "graph-call-external-candidate\t" `Text.isPrefixOf` row]
              then "unattributed" else "unexpected")
        , ("graph.open-import-call-opaque", if any
              (\row -> "graph-call-site-opaque\ttest:consumer\tUseExternalBroad.hs\tuse\t" `Text.isPrefixOf` row
                && "\thelper\tunattributed" `Text.isSuffixOf` row) broadExternalRows
              then "accounted" else "missing")
        , ("graph.open-import-interface-export", if null openExternalFindings &&
              any (\row -> "graph-call-external-candidate\ttest:consumer\tUseExternalOpen.hs\tuse\t" `Text.isPrefixOf` row
                && "\thelper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) openExternalRows
              && null [row | row <- openExternalRows,
                "graph-call-external-candidate\ttest:consumer\tUseExternalOpen.hs\tmissing\t" `Text.isPrefixOf` row]
              && any (\row -> "graph-call-site-opaque\ttest:consumer\tUseExternalOpen.hs\tmissing\t" `Text.isPrefixOf` row
                && "\tabsent\tunattributed" `Text.isSuffixOf` row) openExternalRows
              && any (\row -> "graph-call-external-candidate\ttest:consumer\tUseExternalOpen.hs\tqualifiedGood\t" `Text.isPrefixOf` row
                && "\tExample.Provider.helper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) openExternalRows
              && null [row | row <- openExternalRows,
                "graph-call-external-candidate\ttest:consumer\tUseExternalOpen.hs\tqualifiedMissing\t" `Text.isPrefixOf` row]
              && any (\row -> "graph-call-site-opaque\ttest:consumer\tUseExternalOpen.hs\tqualifiedMissing\t" `Text.isPrefixOf` row
                && "\tExample.Provider.absent\tunattributed" `Text.isSuffixOf` row) openExternalRows
              then "filtered" else "missing")
        , ("graph.standalone-external-call", if null standaloneExternalFindings
              && any ("graph-call-standalone-external-candidate\tUseExternalOpen.hs\tuse\t" `Text.isPrefixOf`) standaloneExternalRows
              && null [row | row <- standaloneExternalRows,
                "graph-call-standalone-external-candidate\tUseExternalOpen.hs\tmissing\t" `Text.isPrefixOf` row]
              then "exported" else "missing")
        , ("graph.standalone-registered-only", if null registeredOnlyFindings
              && "graph-import-standalone-registered-only-unit\tUseRegisteredOnly.hs\tExample.Provider\tprovider\tprovider-unit"
                `elem` registeredOnlyRows
              && any ("graph-call-standalone-registered-only-candidate\tUseRegisteredOnly.hs\tuse\t" `Text.isPrefixOf`)
                registeredOnlyRows
              && null [row | row <- registeredOnlyRows,
                "graph-call-standalone-registered-only-candidate\tUseRegisteredOnly.hs\tmissing\t" `Text.isPrefixOf` row]
              && any ("graph-call-site-opaque\t-\tUseRegisteredOnly.hs\tuse\t" `Text.isPrefixOf`)
                registeredOnlyRows
              then "provisional" else "missing")
        , ("graph.alias-external-interface", if null openExternalFindings &&
              any (\row -> "graph-call-lexical-alias-external-candidate\ttest:consumer\tUseExternalOpen.hs\taliasGood\t" `Text.isPrefixOf` row
                && "\tExample.Provider.helper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) openExternalRows
              && any (\row -> "graph-call-lexical-alias-external-candidate\ttest:consumer\tUseExternalOpen.hs\taliasOpen\t" `Text.isPrefixOf` row
                && "\thelper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) openExternalRows
              && null [row | row <- openExternalRows,
                "graph-call-lexical-alias-external-candidate\ttest:consumer\tUseExternalOpen.hs\taliasMissing\t" `Text.isPrefixOf` row]
              then "filtered" else "missing")
        , ("graph.external-hiding-import", if null hidingExternalFindings &&
              any (\row -> "graph-call-external-candidate\ttest:consumer\tUseExternalHiding.hs\tuse\t" `Text.isPrefixOf` row
                && "\thelper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) hidingExternalRows
              && null [row | row <- hidingExternalRows,
                "graph-call-external-candidate\ttest:consumer\tUseExternalHiding.hs\thidden\t" `Text.isPrefixOf` row
                  || "graph-call-external-candidate\ttest:consumer\tUseExternalHiding.hs\thiddenQualified\t" `Text.isPrefixOf` row]
              then "filtered" else "missing")
        , ("graph.implicit-prelude-export", if null implicitPreludeFindings &&
              "graph-import-implicit-prelude\ttest:consumer\tImplicitPrelude.hs\tbase\tbase-unit" `elem` implicitPreludeRows
              && any (\row -> "graph-call-prelude-candidate\ttest:consumer\tImplicitPrelude.hs\tuse\t" `Text.isPrefixOf` row
                && "\tmap\tbase\tbase-unit" `Text.isSuffixOf` row) implicitPreludeRows
              && any (\row -> "graph-call-prelude-candidate\ttest:consumer\tImplicitPrelude.hs\tcompose\t" `Text.isPrefixOf` row
                && "\t.\tbase\tbase-unit" `Text.isSuffixOf` row) implicitPreludeRows
              then "candidate" else "missing")
        , ("graph.available-prelude-export", if null availablePreludeFindings &&
              "graph-import-implicit-prelude-available\ttest:unplanned\tImplicitPrelude.hs\tbase\tbase-unit" `elem` availablePreludeRows
              && any (\row -> "graph-call-prelude-available-candidate\ttest:unplanned\tImplicitPrelude.hs\tuse\t" `Text.isPrefixOf` row
                && "\tmap\tbase\tbase-unit" `Text.isSuffixOf` row) availablePreludeRows
              && null availableNoPreludeFindings
              && null [row | row <- availableNoPreludeRows,
                "graph-import-implicit-prelude-available\t" `Text.isPrefixOf` row
                  || "graph-call-prelude-available-candidate\t" `Text.isPrefixOf` row]
              then "candidate" else "missing")
        , ("graph.standalone-prelude-export", if null standalonePreludeFindings
              && "graph-import-implicit-prelude-standalone\tImplicitPrelude.hs\tbase\tbase-unit" `elem` standalonePreludeRows
              && any ("graph-call-prelude-standalone-candidate\tImplicitPrelude.hs\tuse\t" `Text.isPrefixOf`) standalonePreludeRows
              && null standaloneNoPreludeFindings
              && null [row | row <- standaloneNoPreludeRows,
                "graph-import-implicit-prelude-standalone\t" `Text.isPrefixOf` row
                  || "graph-call-prelude-standalone-candidate\t" `Text.isPrefixOf` row]
              then "candidate" else "missing")
        , ("graph.standalone-wired-cons", if null standaloneNoPreludeFindings
              && any ("graph-call-standalone-wired-cons-candidate\tNoPrelude.hs\tcons\t" `Text.isPrefixOf`) standaloneNoPreludeRows
              then "candidate" else "missing")
        , ("graph.no-implicit-prelude", if null noPreludeFindings &&
              null [row | row <- noPreludeRows,
                "graph-import-implicit-prelude\t" `Text.isPrefixOf` row
                  || "graph-call-prelude-candidate\t" `Text.isPrefixOf` row]
              && any (\row -> "graph-call-site-opaque\ttest:consumer\tNoPrelude.hs\tuse\t" `Text.isPrefixOf` row
                && "\tmap\tunattributed" `Text.isSuffixOf` row) noPreludeRows
              then "suppressed" else "unexpected")
        , ("graph.wired-cons-no-prelude", if null noPreludeFindings &&
              any (\row -> "graph-call-wired-cons-candidate\ttest:consumer\tNoPrelude.hs\tcons\t" `Text.isPrefixOf` row
                && "\t:\tGHC.Types\tghc-prim" `Text.isSuffixOf` row) noPreludeRows
              then "candidate" else "missing")
        , ("graph.wired-tuple-constructor", if null callFindings &&
              any (\row -> "graph-call-wired-tuple-candidate\ttest:graph\tCalls.hs\tpairCtor\t" `Text.isPrefixOf` row
                && "\t(,)\tGHC.Tuple\tghc-prim" `Text.isSuffixOf` row) callRows
              then "candidate" else "missing")
        , ("graph.unplanned-component", if null unplannedFindings &&
              "graph-import-unresolved\ttest:consumer\tUseExternal.hs\tExample.Provider\tcomponent-not-in-plan" `elem` unplannedRows
              then "located" else "missing")
        , ("graph.forward-owned-import", if null forwardFindings &&
              "graph-import-forward-owned\ttest:consumer\tUseExternal.hs\tExample.Provider\tExample/Provider.hs\tgenerated-control" `elem` forwardRows
              && null [row | row <- forwardRows, "graph-import-unresolved\t" `Text.isPrefixOf` row]
              then "owned" else "missing")
        , ("graph.unselected-unit-candidate", if null unselectedFindings &&
              "graph-import-unselected-unit-candidate\ttest:unplanned\tUseExternal.hs\tExample.Provider\tprovider\tprovider-unit" `elem` unselectedRows
              && "graph-import-unresolved\ttest:unplanned\tUseExternal.hs\tExample.Provider\tcomponent-not-in-plan" `elem` unselectedRows
              && null [row | row <- unselectedRows, "graph-import-external\t" `Text.isPrefixOf` row]
              then "candidate" else "missing")
        , ("graph.available-unit-interface", if null availableFindings &&
              "graph-import-available-unit\ttest:unplanned\tUseExternal.hs\tExample.Provider\tprovider\tprovider-unit" `elem` availableRows
              && null [row | row <- availableRows, "graph-import-unresolved\t" `Text.isPrefixOf` row]
              && null [row | row <- availableRows, "graph-import-external\t" `Text.isPrefixOf` row]
              then "resolved" else "missing")
        , ("graph.available-unit-call", if null availableCallFindings &&
              any (\row -> "graph-call-available-unit-candidate\ttest:unplanned\tUseExternalOpen.hs\tuse\t" `Text.isPrefixOf` row
                && "\thelper\tExample.Provider\tprovider\tprovider-unit\thelper" `Text.isSuffixOf` row) availableCallRows
              && null [row | row <- availableCallRows,
                "graph-call-available-unit-candidate\ttest:unplanned\tUseExternalOpen.hs\tmissing\t" `Text.isPrefixOf` row]
              then "exported" else "missing")
        , ("graph.deferred-seed-import", if null futureFindings &&
              "graph-import-deferred-seed\tlibrary:infernix\tUseFuture.hs\tInfernix.Topic.Metadata\tinfernix\tinfernix-rederivation" `elem` futureRows
              && null [row | row <- futureRows, "graph-import-unresolved\t" `Text.isPrefixOf` row]
              then "owned" else "missing")
        , ("graph.deferred-seed-call", if null futureCallFindings &&
              any (\row -> "graph-call-deferred-seed-candidate\tlibrary:infernix\tUseFutureCall.hs\tuse\t" `Text.isPrefixOf` row
                && "\tlookupCompactedView\tInfernix.Topic.Metadata\tinfernix\tinfernix-rederivation\tlookupCompactedView" `Text.isSuffixOf` row) futureCallRows
              && any (\row -> "graph-call-deferred-seed-candidate\tlibrary:infernix\tUseFutureCall.hs\tconstruct\t" `Text.isPrefixOf` row
                && "\tKeyedEvent\tInfernix.Topic.Metadata\tinfernix\tinfernix-rederivation\tKeyedEvent" `Text.isSuffixOf` row) futureCallRows
              && null [row | row <- futureCallRows,
                "graph-call-deferred-seed-candidate\tlibrary:infernix\tUseFutureCall.hs\tmissing\t" `Text.isPrefixOf` row]
              then "bounded" else "missing")
        , ("graph.deferred-seed-owner-filter", if null futureWrongOwnerFindings &&
              "graph-import-unresolved\ttest:other\tUseFuture.hs\tInfernix.Topic.Metadata\tcomponent-not-in-plan" `elem` futureWrongOwnerRows
              && null [row | row <- futureWrongOwnerRows, "graph-import-deferred-seed\t" `Text.isPrefixOf` row]
              then "filtered" else "unexpected")
        , ("graph.deferred-seed-indirect-owner", if null jitFutureFindings &&
              "graph-import-deferred-seed\ttest:jitml-cuda-artifact-lift-contract\tUseJitFuture.hs\tJitML.Codegen.RuntimeOperationsCuda\tjitml\tjitml-rederivation" `elem` jitFutureRows
              && null [row | row <- jitFutureRows, "graph-import-unresolved\t" `Text.isPrefixOf` row]
              && null jitFutureMissingDependencyFindings
              && "graph-import-unresolved\ttest:jitml-cuda-artifact-lift-contract\tUseJitFuture.hs\tJitML.Codegen.RuntimeOperationsCuda\tcomponent-not-in-plan" `elem` jitFutureMissingDependencyRows
              then "bound" else "missing")
        , ("graph.package-plan-mismatch", case mismatchedPlan of
              Left (LayoutFinding "PackagePlanDependencyMismatch" "test:consumer") -> "refused"
              _ -> "missing")
        , ("graph.package-unit-missing", case absentUnit of
              Left (LayoutFinding "PackageUnitMetadataMissing" "test:consumer:provider-unit") -> "refused"
              _ -> "missing")
        , ("graph.imported-call-candidate", if null localFindings &&
              "graph-call-candidate\ttest:first\tUse.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tDuplicate" `elem` localRows
              then "candidate" else "missing")
        , ("graph.class-method-import", if null classMethodFindings &&
              "graph-class-method\tClassProvider.hs\tC\tdoThing" `elem` classMethodRows
              && "graph-call-candidate\ttest:graph\tUseClass.hs\tuse\ttest:graph\tClassProvider.hs\tdoThing\tClassProvider" `elem` classMethodRows
              && null [row | row <- classMethodRows,
                "graph-call-candidate\ttest:graph\tUseClassHidden.hs\tuse\t" `Text.isPrefixOf` row]
              then "bound" else "missing")
        , ("graph.instance-source-contract", if null classMethodFindings
              && "graph-instance-method-source-contract\tUseClassInstance.hs\tC Bool\tC\tdoThing\tClassProvider.hs\tClassProvider" `elem` classMethodRows
              && null [row | row <- classMethodRows,
                "graph-instance-method-source-contract\tUseClassInstanceHidden.hs\t" `Text.isPrefixOf` row]
              then "bound" else "missing")
        , ("graph.class-call-dispatch", if null classMethodFindings
              && any (\row -> "graph-class-call-dispatch-candidate\ttest:graph\tUseClass.hs\tuse\t" `Text.isPrefixOf` row
                && "\tClassProvider.hs\tClassProvider.hs\tC ()\tC\tdoThing" `Text.isSuffixOf` row) classMethodRows
              && any (\row -> "graph-class-call-dispatch-candidate\ttest:graph\tUseClass.hs\tuse\t" `Text.isPrefixOf` row
                && "\tClassProvider.hs\tUseClassInstance.hs\tC Bool\tC\tdoThing" `Text.isSuffixOf` row) classMethodRows
              && null [row | row <- classMethodRows,
                "graph-class-call-dispatch-candidate\ttest:graph\tUseClass.hs\tuse\t" `Text.isPrefixOf` row
                  && "\tUseClassInstanceHidden.hs\t" `Text.isInfixOf` row]
              then "potential" else "missing")
        , ("graph.record-dot-selector", if null recordDotFindings &&
              any (\row -> "graph-record-field-site\tUseDot.hs\tuse\t" `Text.isPrefixOf` row
                && "\tfield" `Text.isSuffixOf` row) recordDotRows
              && any (\row -> "graph-record-selector-candidate\ttest:graph\tUseDot.hs\tuse\t" `Text.isPrefixOf` row
                && "\tget\tfield\ttest:graph\tRecordProvider.hs\tBox\tRecordProvider" `Text.isSuffixOf` row) recordDotRows
              && any (\row -> "graph-record-projection-site\tUseDot.hs\tproject\t" `Text.isPrefixOf` row
                && "\tfield" `Text.isSuffixOf` row) recordDotRows
              && null [row | row <- recordDotRows,
                "graph-record-selector-candidate\ttest:graph\tUseDot.hs\tmissing\t" `Text.isPrefixOf` row
                  || "graph-unscanned\tUseDot.hs\t" `Text.isPrefixOf` row]
              then "projected" else "missing")
        , ("graph.module-reexport-call", if null reexportFindings &&
              "graph-module-reexport\tReexport.hs\tDuplicate" `elem` reexportRows
              && "graph-call-candidate\ttest:first\tUseReexport.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tReexport" `elem` reexportRows
              then "traced" else "missing")
        , ("graph.alias-reexport-call", if null aliasReexportFindings &&
              "graph-module-reexport\tAliasReexport.hs\tD" `elem` aliasReexportRows
              && "graph-call-candidate\ttest:first\tUseAliasReexport.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tAliasReexport" `elem` aliasReexportRows
              then "traced" else "missing")
        , ("graph.qualified-reexport-filter", if null qualifiedReexportFindings &&
              null [row | row <- qualifiedReexportRows, "graph-call-candidate\ttest:first\tUseQualifiedReexport.hs\tuse\t" `Text.isPrefixOf` row]
              then "filtered" else "unexpected")
        , ("graph.explicit-reexport-call", if null explicitReexportFindings &&
              "graph-call-candidate\ttest:first\tUseExplicitReexport.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tExplicitReexport" `elem` explicitReexportRows
              then "traced" else "missing")
        , ("graph.explicit-data-reexport", if null explicitDataReexportFindings &&
              "graph-call-candidate\ttest:first\tUseExplicitDataReexport.hs\tmakeItem\ttest:first\tDuplicate.hs\tItem\tExplicitDataReexport" `elem` explicitDataReexportRows
              && "graph-call-candidate\ttest:first\tUseExplicitDataReexport.hs\treadItem\ttest:first\tDuplicate.hs\titemField\tExplicitDataReexport" `elem` explicitDataReexportRows
              then "traced" else "missing")
        , ("graph.hidden-reexport-filter", if null hiddenReexportFindings &&
              null [row | row <- hiddenReexportRows, "graph-call-candidate\ttest:first\tUseHiddenReexport.hs\tuse\t" `Text.isPrefixOf` row]
              && "graph-call-candidate\ttest:first\tUseHiddenReexport.hs\tmakeItem\ttest:first\tDuplicate.hs\tItem\tHiddenReexport" `elem` hiddenReexportRows
              then "selective" else "unexpected")
        , ("graph.direct-hiding-selective", if null hidingFindings &&
              null [row | row <- hidingRows, "graph-call-candidate\ttest:first\tUseHiding.hs\tuse\t" `Text.isPrefixOf` row]
              && "graph-call-candidate\ttest:first\tUseHiding.hs\tmakeItem\ttest:first\tDuplicate.hs\tItem\tDuplicate" `elem` hidingRows
              then "selective" else "unexpected")
        , ("graph.hiding-type-constructor", if null hidingTypeFindings &&
              null [row | row <- hidingTypeRows, "graph-call-candidate\ttest:first\tUseHidingType.hs\tuse\t" `Text.isPrefixOf` row]
              then "filtered" else "unexpected")
        , ("graph.unique-internal-call", if any
              (\row -> "graph-call-unique-internal\ttest:first\tUse.hs\tuse\t" `Text.isPrefixOf` row
                && "\tDuplicate.value\ttest:first\tDuplicate.hs\tvalue\timported:Duplicate" `Text.isSuffixOf` row) localRows
              && any (\row -> "graph-call-unique-internal\ttest:graph\tCalls.hs\tcaller\t" `Text.isPrefixOf` row
                && "\tcallee\ttest:graph\tCalls.hs\tcallee\tlocal" `Text.isSuffixOf` row) callRows
              then "unique" else "missing")
        , ("graph.ambiguous-internal-call", if any
              (\row -> "graph-call-ambiguous-internal\ttest:graph\tUse.hs\tuse\t" `Text.isPrefixOf` row
                && "\tDuplicate.value\t2" `Text.isSuffixOf` row) ambiguousRows
              then "ambiguous" else "missing")
        , ("graph.shadow-no-internal-call", if null
              [row | row <- callRows, "graph-call-unique-internal\ttest:graph\tCalls.hs\tshadow\t" `Text.isPrefixOf` row]
              then "absent" else "unexpected")
        , ("graph.alias-call-candidate", if null aliasFindings &&
              "graph-call-candidate\ttest:first\tUseAlias.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tDuplicate" `elem` aliasRows
              then "candidate" else "missing")
        , ("graph.alias-imported-call", if null aliasFindings &&
              any (\row -> "graph-call-lexical-alias-imported-candidate\ttest:first\tUseAlias.hs\taliasUse\t" `Text.isPrefixOf` row
                && "\tD.value\ttest:first\tDuplicate.hs\tvalue\tDuplicate" `Text.isSuffixOf` row) aliasRows
              then "linked" else "missing")
        , ("graph.alias-imported-effect-route", if null effectAliasFindings &&
              any (\row -> "graph-call-lexical-alias-imported-candidate\ttest:consumer\tUseEffect.hs\tinvoke\t" `Text.isPrefixOf` row
                && "\teffectful\ttest:provider\tEffectProvider.hs\teffectful\tEffectProvider" `Text.isSuffixOf` row) effectAliasRows
              && "graph-effect-route-candidate\ttest:consumer\tUseEffect.hs\tinvoke\tIO" `elem` effectAliasRows
              then "potential" else "missing")
        , ("graph.filtered-call", if null filteredFindings &&
              null [row | row <- filteredRows, "graph-call-candidate\t" `Text.isPrefixOf` row]
              then "absent" else "unexpected")
        , ("graph.no-component", if null standaloneFindings &&
              "graph-no-component\tDuplicate.hs" `elem` standaloneRows then "accounted" else "missing")
        , ("graph.standalone-local-call", if null standaloneLocalFindings
              && any ("graph-call-standalone-local-candidate\tStandaloneLocal.hs\tuse\t" `Text.isPrefixOf`) standaloneLocalRows
              && null [row | row <- standaloneLocalRows,
                "graph-call-standalone-local-candidate\tStandaloneLocal.hs\tshadow\t" `Text.isPrefixOf` row]
              then "candidate" else "missing")
        , ("graph.standalone-lexical-call", if null standaloneLocalFindings
              && any ("graph-call-standalone-lexical-candidate\tStandaloneLocal.hs\tshadow\t" `Text.isPrefixOf`) standaloneLocalRows
              && null [row | row <- standaloneLocalRows,
                "graph-call-standalone-lexical-candidate\tStandaloneLocal.hs\tuse\t" `Text.isPrefixOf` row]
              then "bound" else "missing")
        , ("graph.standalone-imported-call", if null standaloneImportedFindings
              && any ("graph-call-standalone-imported-candidate\tStandaloneUse.hs\tuse\t" `Text.isPrefixOf`) standaloneImportedRows
              && null [row | row <- standaloneImportedRows,
                "graph-call-standalone-imported-candidate\tStandaloneUse.hs\tmissing\t" `Text.isPrefixOf` row]
              then "exported" else "missing")
        , ("graph.standalone-source-denied", if null standaloneImportedFindings
              && any (\row -> "graph-call-standalone-source-denied\tStandaloneUse.hs\tmissing\t"
                    `Text.isPrefixOf` row
                    && "\tStandaloneProvider.hs\thidden\tprovider-not-exported"
                      `Text.isSuffixOf` row) standaloneImportedRows
              && null [row | row <- standaloneImportedRows,
                "graph-call-standalone-source-denied\tStandaloneUse.hs\tuse\t"
                  `Text.isPrefixOf` row]
              && any ("graph-call-site-opaque\t-\tStandaloneUse.hs\tmissing\t"
                    `Text.isPrefixOf`) standaloneImportedRows
              then "provisional" else "missing")
        , ("graph.module-path-mismatch", if mismatchedFindings ==
              [LayoutFinding "ModuleDeclarationPathMismatch" "Mismatched.hs"] then "refused" else "missing")
        , ("graph.local-call", if null callFindings &&
              "graph-call-local-candidate\ttest:graph\tCalls.hs\tcaller\ttest:graph\tCalls.hs\tcallee" `elem` callRows
              then "candidate" else "missing")
        , ("graph.type-signature", if
              "graph-type-signature\tCalls.hs\teffectful\t() -> IO ()" `elem` callRows
              then "located" else "missing")
        , ("graph.effect-type-seed", if
              "graph-effect-type-candidate\tCalls.hs\teffectful\tIO\t() -> IO ()" `elem` callRows
              then "potential" else "missing")
        , ("graph.effect-route-candidate", if
              all (`elem` callRows)
                ["graph-effect-route-candidate\ttest:graph\tCalls.hs\teffectful\tIO",
                 "graph-effect-route-candidate\ttest:graph\tCalls.hs\teffectCaller\tIO",
                 "graph-effect-route-candidate\ttest:graph\tCalls.hs\teffectTop\tIO",
                 "graph-effect-route-candidate\ttest:graph\tCalls.hs\taliasEffect\tIO"]
              && "graph-effect-route-candidate\ttest:graph\tCalls.hs\teffectShadow\tIO" `notElem` callRows
              then "potential" else "missing")
        , ("graph.local-alias-route", if null callFindings &&
              any (\row -> case Text.splitOn "\t" row of
                ["graph-call-lexical-alias-route", "test:graph", "Calls.hs", "aliasCaller", callSite,
                 "forward", binderSite, "callee", "unqualified"] ->
                   Text.intercalate "\t" ["graph-local-alias", "Calls.hs", "aliasCaller",
                     "forward", binderSite, "callee", "unqualified"] `elem` callRows
                     && Text.intercalate "\t" ["graph-call-lexical-alias-local-candidate",
                       "test:graph", "Calls.hs", "aliasCaller", callSite, "forward", binderSite,
                       "test:graph", "Calls.hs", "callee"] `elem` callRows
                _ -> False) callRows
              then "linked" else "missing")
        , ("graph.alias-parameter-route", if null callFindings &&
              any (\row -> "graph-local-alias\tCalls.hs\taliasParameter\tforward\t" `Text.isPrefixOf` row
                && "\tf\tparameter" `Text.isSuffixOf` row) callRows
              && null [row | row <- callRows,
                "graph-call-lexical-alias-local-candidate\ttest:graph\tCalls.hs\taliasParameter\t" `Text.isPrefixOf` row]
              then "bounded" else "missing")
        , ("graph.alias-pattern-filter", if null callFindings &&
              null [row | row <- callRows,
                "graph-local-alias\tCalls.hs\taliasTuple\t" `Text.isPrefixOf` row
                  || "graph-call-lexical-alias-local-candidate\ttest:graph\tCalls.hs\taliasTuple\t" `Text.isPrefixOf` row]
              && any (\row -> "graph-call-lexical-binding-candidate\ttest:graph\tCalls.hs\taliasTuple\t" `Text.isPrefixOf` row
                && "\tleft\t" `Text.isInfixOf` row) callRows
              then "bounded" else "unexpected")
        , ("graph.alias-qualified-route", if null callFindings &&
              any (\row -> "graph-local-alias\tCalls.hs\taliasQualified\tforward\t" `Text.isPrefixOf` row
                && "\tText.pack\tqualified" `Text.isSuffixOf` row) callRows
              && null [row | row <- callRows,
                "graph-call-lexical-alias-local-candidate\ttest:graph\tCalls.hs\taliasQualified\t" `Text.isPrefixOf` row]
              then "bounded" else "missing")
        , ("graph.distinct-call-sites", if length
              [row | row <- callRows, "graph-call-site\tCalls.hs\tdoubleCall\t" `Text.isPrefixOf` row,
                "\tcallee" `Text.isSuffixOf` row] == 2
              && length [row | row <- callRows,
                "graph-call-site-local-candidate\ttest:graph\tCalls.hs\tdoubleCall\t" `Text.isPrefixOf` row,
                "\ttest:graph\tCalls.hs\tcallee" `Text.isSuffixOf` row] == 2
              && length [row | row <- callRows, "graph-reference-site\tCalls.hs\tdoubleCall\t" `Text.isPrefixOf` row,
                "\tcallee" `Text.isSuffixOf` row] == 2
              then "distinct" else "missing")
        , ("graph.local-binding-call", if null callFindings &&
              "graph-call-local-candidate\ttest:graph\tCalls.hs\tlocalCaller\ttest:graph\tCalls.hs\tcallee" `elem` callRows
              then "candidate" else "missing")
        , ("graph.shadowed-call", if null callFindings &&
              "graph-call-lexical\tCalls.hs\tshadow\tcallee" `elem` callRows
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\tshadow\ttest:graph\tCalls.hs\tcallee" `notElem` callRows
              && null [row | row <- callRows,
                "graph-call-site-local-candidate\ttest:graph\tCalls.hs\tshadow\t" `Text.isPrefixOf` row]
              then "lexical" else "missing")
        , ("graph.lexical-local-binding", if null callFindings &&
              any (\row -> case Text.splitOn "\t" row of
                ["graph-call-lexical-binding-candidate", "test:graph", "Calls.hs", "shadow", _, "callee", binderSite] ->
                  binderSite /= "unlocated"
                    && Text.intercalate "\t"
                      ["graph-local-binder", "Calls.hs", "shadow", "callee", binderSite] `elem` callRows
                _ -> False) callRows
              && null [row | row <- callRows,
                "graph-call-site-opaque\ttest:graph\tCalls.hs\tshadow\t" `Text.isPrefixOf` row]
              then "bound" else "missing")
        , ("graph.lexical-parameter-binding", if any
              (\row -> case Text.splitOn "\t" row of
                ["graph-call-lexical-binding-candidate", "test:graph", "Calls.hs", "apply", _, "f", binderSite] ->
                  Text.intercalate "\t" ["graph-parameter-binder", "Calls.hs", "apply", "f", binderSite] `elem` callRows
                _ -> False) callRows
              && null [row | row <- callRows,
                "graph-call-site-opaque\ttest:graph\tCalls.hs\tapply\t" `Text.isPrefixOf` row]
              then "bound" else "missing")
        , ("graph.parameter-shadow", if
              "graph-call-lexical\tCalls.hs\tparameterShadow\tcallee" `elem` callRows
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\tparameterShadow\ttest:graph\tCalls.hs\tcallee" `notElem` callRows
              then "lexical" else "missing")
        , ("graph.case-shadow", if
              "graph-call-lexical\tCalls.hs\tcaseShadow\tcallee" `elem` callRows
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\tcaseShadow\ttest:graph\tCalls.hs\tcallee" `notElem` callRows
              then "lexical" else "missing")
        , ("graph.if-control-edges", if all
              (\kind -> any (\row -> "graph-control-edge\tCalls.hs\tifBranch\t" `Text.isPrefixOf` row
                && ("\t" <> kind <> "\t") `Text.isInfixOf` row) callRows)
              ["if-condition", "if-true", "if-false"]
              && length [row | row <- callRows,
                "graph-control-edge\tCalls.hs\tifBranch\t" `Text.isPrefixOf` row] == 3
              then "linked" else "missing")
        , ("graph.case-control-edges", if all
              (\kind -> any (\row -> "graph-control-edge\tCalls.hs\tcaseShadow\t" `Text.isPrefixOf` row
                && ("\t" <> kind <> "\t") `Text.isInfixOf` row) callRows)
              ["case-scrutinee", "case-alternative"]
              then "linked" else "missing")
        , ("graph.do-control-edges", if all
              (\kind -> any (\row -> "graph-control-edge\tCalls.hs\tdoShadow\t" `Text.isPrefixOf` row
                && ("\t" <> kind <> "\t") `Text.isInfixOf` row
                && not ("unlocated" `Text.isInfixOf` row)) callRows)
              ["do-first", "statement-next"]
              then "linked" else "missing")
        , ("graph.guard-control-edges", if length
              [row | row <- callRows, "graph-control-edge\tCalls.hs\tguardShadow\t" `Text.isPrefixOf` row,
                "\tguard-body\t" `Text.isInfixOf` row,
                not ("unlocated" `Text.isInfixOf` row)] == 2
              then "linked" else "missing")
        , ("graph.do-shadow", if
              "graph-call-lexical\tCalls.hs\tdoShadow\tcallee" `elem` callRows
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\tdoShadow\ttest:graph\tCalls.hs\tcallee" `notElem` callRows
              then "lexical" else "missing")
        , ("graph.guard-shadow", if
              "graph-call-lexical\tCalls.hs\tguardShadow\tcallee" `elem` callRows
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\tguardShadow\ttest:graph\tCalls.hs\tcallee" `notElem` callRows
              then "lexical" else "missing")
        , ("graph.nested-call-coverage", if null callFindings &&
              all (`elem` callRows)
                ["graph-call-local-candidate\ttest:graph\tCalls.hs\ttupleCaller\ttest:graph\tCalls.hs\tcallee",
                 "graph-call-local-candidate\ttest:graph\tCalls.hs\trecordCaller\ttest:graph\tCalls.hs\tcallee",
                 "graph-call-local-candidate\ttest:graph\tCalls.hs\tupdateCaller\ttest:graph\tCalls.hs\tcallee"]
              then "accounted" else "missing")
        , ("graph.implicit-sequence-call", if
              "graph-call-syntax\tCalls.hs\trange\tenumFromTo" `elem` callRows
              && "graph-unscanned\tCalls.hs\trange\tArithSeqImplicit" `notElem` callRows
              then "projected" else "missing")
        , ("graph.pattern-binding", if
              all (`elem` callRows)
                ["graph-top-level\tCalls.hs\tpatternA",
                 "graph-top-level\tCalls.hs\tpatternB",
                 "graph-call-local-candidate\ttest:graph\tCalls.hs\tpatternA\ttest:graph\tCalls.hs\tcallee"]
              then "accounted" else "missing")
        , ("graph.declaration-gap", if
              all (`elem` callRows)
                ["graph-unscanned-declaration\tCalls.hs\tDataDerivingDispatch",
                 "graph-unscanned-declaration\tCalls.hs\tClassDispatch",
                 "graph-unscanned-declaration\tCalls.hs\tInstanceDispatch"]
              then "accounted" else "missing")
        , ("graph.plain-data-declaration", if null plainDataFindings &&
              all (`elem` plainDataRows)
                ["graph-data\tPlainData.hs\tPlain",
                 "graph-constructor\tPlainData.hs\tPlain\tPlain",
                 "graph-selector\tPlainData.hs\tPlain\tplainValue"]
              && null [row | row <- plainDataRows,
                "graph-unscanned-declaration\tPlainData.hs\t" `Text.isPrefixOf` row]
              then "projected" else "missing")
        , ("graph.class-default-call", if
              "graph-call-syntax\tCalls.hs\tclass[C].method\tcallee" `elem` callRows
              && "graph-class-declaration\tCalls.hs\tC" `elem` callRows
              && "graph-class-method-signature\tCalls.hs\tC\tmethod\ta -> a" `elem` callRows
              && "graph-class-default\tCalls.hs\tC\tmethod" `elem` callRows
              && "graph-unscanned-declaration\tCalls.hs\tClassDispatch" `elem` callRows
              && "graph-class-method-signature\tClassProvider.hs\tC\tdoThing\ta -> a"
                   `elem` classMethodRows
              && not ("graph-unscanned-declaration\tClassProvider.hs\tClassDispatch"
                   `elem` classMethodRows)
              && null [row | row <- classMethodRows,
                "graph-class-default\tClassProvider.hs\tC\t" `Text.isPrefixOf` row]
              then "accounted" else "missing")
        , ("graph.instance-method-call", if any
              (\row -> "graph-call-syntax\tCalls.hs\tinstance[" `Text.isPrefixOf` row
                && "].method\tcallee" `Text.isSuffixOf` row) callRows
              then "accounted" else "missing")
        , ("graph.instance-declaration", if all (`elem` callRows)
              ["graph-instance-declaration\tCalls.hs\tC Int\tC",
               "graph-instance-method\tCalls.hs\tC Int\tC\tmethod"]
              then "projected" else "missing")
        , ("graph.data-symbols", if all (`elem` callRows)
              ["graph-data\tCalls.hs\tBox",
               "graph-constructor\tCalls.hs\tBox\tBox",
               "graph-selector\tCalls.hs\tBox\tboxValue",
               "graph-derived-type\tCalls.hs\tBox",
               "graph-derived-instance\tCalls.hs\tBox\tEq\tinferred"]
              then "accounted" else "missing")
        , ("graph.derived-class-head", if
              "graph-derived-class-head\tCalls.hs\tBox\tEq\tEq\tinferred" `elem` callRows
              then "projected" else "missing")
        , ("graph.derived-interface-members", if null derivedPreludeFindings
              && any (\row -> "graph-derived-class-member-candidate\tCalls.hs\tBox\tEq\tEq\tinferred\tPrelude\tbase\tbase-unit\t" `Text.isPrefixOf` row
                && "\timplicit" `Text.isSuffixOf` row) derivedPreludeRows
              && null noPreludeDeriveFindings
              && null [row | row <- noPreludeDeriveRows,
                "graph-derived-class-member-candidate\t" `Text.isPrefixOf` row]
              && null explicitPreludeDeriveFindings
              && any (\row -> "graph-derived-class-member-candidate\tExplicitPreludeDerive.hs\tMark\tEq\tEq\tinferred\tPrelude\tbase\tbase-unit\t" `Text.isPrefixOf` row
                && "\texplicit" `Text.isSuffixOf` row) explicitPreludeDeriveRows
              then "bounded" else "missing")
        , ("graph.data-call-candidates", if all (`elem` localRows)
              ["graph-call-candidate\ttest:first\tUse.hs\tmakeItem\ttest:first\tDuplicate.hs\tItem\tDuplicate",
               "graph-call-candidate\ttest:first\tUse.hs\treadItem\ttest:first\tDuplicate.hs\titemField\tDuplicate"]
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\tselectorCaller\ttest:graph\tCalls.hs\tboxValue" `elem` callRows
              then "candidate" else "missing")
        , ("graph.record-constructor-call", if
              "graph-call-syntax\tCalls.hs\trecordCaller\tBox" `elem` callRows
              && "graph-call-local-candidate\ttest:graph\tCalls.hs\trecordCaller\ttest:graph\tCalls.hs\tBox" `elem` callRows
              then "candidate" else "missing")
        , ("graph.higher-order-reference", if
              "graph-reference-syntax\tCalls.hs\thigherOrder\tcallee" `elem` callRows
              && "graph-reference-local-candidate\ttest:graph\tCalls.hs\thigherOrder\ttest:graph\tCalls.hs\tcallee" `elem` callRows
              && "graph-call-lexical\tCalls.hs\tapply\tf" `elem` callRows
              && "graph-call-syntax\tCalls.hs\thigherOrder\tapply" `elem` callRows
              && "graph-call-syntax\tCalls.hs\thigherOrder\tcallee" `notElem` callRows
              then "accounted" else "missing")
        , ("graph.explicit-member-import", if null selectiveFindings && all (`elem` selectiveRows)
              ["graph-call-candidate\ttest:first\tUseSelective.hs\tmakeItem\ttest:first\tDuplicate.hs\tItem\tDuplicate",
               "graph-call-candidate\ttest:first\tUseSelective.hs\treadItem\ttest:first\tDuplicate.hs\titemField\tDuplicate"]
              then "candidate" else "missing")
        , ("graph.explicit-member-filter", if null constructorOnlyFindings
              && "graph-call-candidate\ttest:first\tUseConstructorOnly.hs\tmakeItem\ttest:first\tDuplicate.hs\tItem\tDuplicate" `elem` constructorOnlyRows
              && "graph-call-candidate\ttest:first\tUseConstructorOnly.hs\treadItem\ttest:first\tDuplicate.hs\titemField\tDuplicate" `notElem` constructorOnlyRows
              then "filtered" else "missing")
        , ("graph.unexported-member", if null hiddenFindings
              && null [row | row <- hiddenRows, "graph-call-candidate\t" `Text.isPrefixOf` row]
              then "absent" else "unexpected")
        , ("graph.imported-value-reference", if null valueFindings
              && "graph-reference-candidate\ttest:first\tUseValue.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tDuplicate" `elem` valueRows
              && any (\row -> "graph-reference-site-candidate\ttest:first\tUseValue.hs\tuse\t" `Text.isPrefixOf` row
                && "\ttest:first\tDuplicate.hs\tvalue\tDuplicate" `Text.isSuffixOf` row) valueRows
              && "graph-call-candidate\ttest:first\tUseValue.hs\tuse\ttest:first\tDuplicate.hs\tvalue\tDuplicate" `notElem` valueRows
              then "candidate" else "missing")
        , ("graph.expression-splice", if null spliceFindings
              && any (\row -> "graph-dynamic-load\tSpliceExpr.hs\tvalue\t" `Text.isPrefixOf` row
                && "\ttemplate-haskell-splice\tgenerateValue" `Text.isSuffixOf` row) spliceRows
              && "graph-unscanned\tSpliceExpr.hs\tvalue\tUntypedSplice" `notElem` spliceRows
              then "located" else "missing")
        , ("graph.declaration-splice", if null spliceFindings
              && any (\row -> "graph-dynamic-load\tSpliceDecl.hs\tmodule-splice\t" `Text.isPrefixOf` row
                && "\ttemplate-haskell-splice\tmakeSomething" `Text.isSuffixOf` row) spliceRows
              then "located" else "missing")
        , ("graph.foreign-boundary", if null foreignFindings
              && any (\row -> "graph-foreign-symbol\tForeign.hs\tforeignValue\timport\tforeign_value\t" `Text.isPrefixOf` row) foreignRows
              && "graph-call-local-candidate\ttest:graph\tForeign.hs\tuse\ttest:graph\tForeign.hs\tforeignValue" `elem` foreignRows
              then "located" else "missing")
        , ("graph.standalone-deriving", if null derivingFindings
              && "graph-standalone-deriving\tDerive.hs\tEq Mark\tinferred" `elem` derivingRows
              then "accounted" else "missing")
        , ("graph.standalone-deriving-member", if
              null standaloneDerivePreludeFindings
              && null noPreludeStandaloneDeriveFindings
              && null explicitPreludeStandaloneDeriveFindings
              && "graph-standalone-deriving-class-head\tDerive.hs\tEq Mark\tEq\tinferred"
                `elem` standaloneDerivePreludeRows
              && any ("graph-standalone-deriving-member-candidate\tDerive.hs\tEq Mark\tEq\tinferred\tPrelude\tbase\tbase-unit\t==\timplicit" ==)
                standaloneDerivePreludeRows
              && null [row | row <- noPreludeStandaloneDeriveRows,
                   "graph-standalone-deriving-member-candidate\t" `Text.isPrefixOf` row]
              && "graph-standalone-deriving-member-candidate\tExplicitPreludeStandaloneDerive.hs\tEq Mark\tEq\tinferred\tPrelude\tbase\tbase-unit\t==\texplicit"
                `elem` explicitPreludeStandaloneDeriveRows
              then "bounded" else "missing")
        ] <> [("challenge." <> Text.pack name, result) | (name, result) <- challenged] <>
        [ ("owner.dhall", ownerText LtdSrc002)
        , ("owner.proto", ownerText LtdSrc003)
        , ("owner.ui-language", ownerText LtdSrc004)
        , ("owner.ui-artifact", ownerText LtdUi001)
        , ("identity.layout", maybe "absent" (Text.pack . show) (lookupCapabilityOrdinal "repository_layout_conformance"))
        , ("fork.paths", Text.intercalate "," (map Text.pack (sort maintainedForkPaths)))
        , ("fork.provenance", if sort maintainedForkPaths == sort provenancePaths
              && sort maintainedForkPaths == sort (filter ("src/vendor/" `isPrefixOf`) paths)
            then "matched" else "mismatch")
        ]
  TextIO.writeFile (directory </> "cases.tsv") (Text.unlines [name <> "\t" <> value | (name, value) <- cases])
  runLayoutReport ["--root", root, "--paths-file", pathFile, "--output", directory </> "layout.tsv"]
 where
  pathResult path = either findingCode renderPathClass (classifyPath path)
  bootstrapResult bytes = either (Text.takeWhile (/= ':') . renderBootstrapRefusal) (const "admitted") (admitBootstrap bytes)
  ownerText identifier = case legacyOwner identifier of
    PhaseOwner capability -> capability
    LaterPhasesTrack -> "later-phases-track"
  archiveExample = "validation-records/generation-aaaaaaaaaaaaaaaa/receipts/phase-02-" <> replicate 64 'a' <> "-" <> replicate 64 'b' <> "/receipt.tsv"
  voidExample = "validation-records/generation-aaaaaaaaaaaaaaaa/voids/phase-02-" <> replicate 64 'a' <> "-" <> replicate 64 'b' <> ".tsv"
  provenancePaths = ["src/vendor/" <> Text.unpack (Text.replace "." "/" name) <> ".hs" | name <- forkModules]

runChallenge :: FilePath -> FilePath -> [FilePath] -> (String, FilePath, Text.Text) -> IO (String, Text.Text)
runChallenge root directory basePaths (name, planted, _) = do
  let tree = directory </> "challenge" </> name
      manifest = directory </> "challenge-" <> name <> "-paths.txt"
      output = directory </> "challenge-" <> name <> ".tsv"
  mapM_ (copyInto root tree) basePaths
  createDirectoryIfMissing True (takeDirectory (tree </> planted))
  TextIO.writeFile (tree </> planted)
    (if name == "ordinal" then "module Amoebius.Challenge where\nruntimeName = \"phase42\"\n"
      else if name `elem` ["unmapped", "vendor"] then "module Amoebius.Challenge where\nchallenge = ()\n"
      else if name == "syntax" then "module Bad where\nvalue = (\n" else "challenge\n")
  TextIO.writeFile manifest (Text.unlines (map Text.pack (basePaths <> [planted])))
  result <- reportExit (runLayoutReport ["--root", tree, "--paths-file", manifest, "--output", output])
  pure (name, result)

sourceRoots :: [FilePath]
sourceRoots = ["src", "app", "test", "probe", "pb", "documents", "DEVELOPMENT_PLAN"]

metadata :: [FilePath]
metadata = [".gitignore", ".dockerignore", "amoebius.cabal", "cabal.project", "probe/probe.cabal", "LICENSE", "AGENTS.md", "CLAUDE.md", "README.md"]

walk :: FilePath -> FilePath -> IO [FilePath]
walk root relative = do
  entries <- listDirectory (root </> relative)
  concat <$> mapM step entries
 where
  step name = do
    let path = relative </> name
    directory <- doesDirectoryExist (root </> path)
    if directory then walk root path else pure [path]

copyInto :: FilePath -> FilePath -> FilePath -> IO ()
copyInto root destination path = do
  createDirectoryIfMissing True (takeDirectory (destination </> path))
  copyFile (root </> path) (destination </> path)

reportExit :: IO () -> IO Text.Text
reportExit action = do
  outcome <- try action :: IO (Either SomeException ())
  pure $ case outcome of
    Right () -> "success"
    Left problem -> case fromException problem of
      Just ExitSuccess -> "success"
      Just (ExitFailure code) -> Text.pack ("exit-" <> show code)
      Nothing -> "io-error"
