-- | Package-private Cabal syntax and graph mechanics. Callers own all policy.
module Amoebius.Internal.Cabal.ComponentDescription
  ( DescriptionAttempt (..), ComponentTree (..), parseDescription
  , enumerateComponents, conditionalValues, aggregateAll
  , dependencyLibrariesFor, reachableFrom
  ) where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import Data.Set (Set)
import Data.Set qualified as Set
import Distribution.Compat.NonEmptySet qualified as NonEmptySet
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.PackageDescription
  ( GenericPackageDescription (..), BuildInfo (..), Library, Executable
  , TestSuite, Benchmark, ForeignLib )
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Parsec.Error (PError)
import Distribution.Parsec.Warning (PWarning)
import Distribution.Types.CondTree (CondBranch (..), CondTree (..))
import Distribution.Types.ConfVar (ConfVar)
import Distribution.Types.Dependency (Dependency (..))
import Distribution.Types.LibraryName (LibraryName)
import Distribution.Types.PackageName (PackageName)
import Distribution.Types.UnqualComponentName (UnqualComponentName)
import Distribution.Version (Version)

data DescriptionAttempt = DescriptionAttempt
  { descriptionInput :: ByteString
  , descriptionWarnings :: [PWarning]
  , descriptionResult :: Either (Maybe Version, NonEmpty PError) GenericPackageDescription
  }

parseDescription :: ByteString -> DescriptionAttempt
parseDescription bytes =
  let (warnings, result) = runParseResult (parseGenericPackageDescription bytes)
  in DescriptionAttempt bytes warnings result

data ComponentTree
  = MainLibraryTree (CondTree ConfVar [Dependency] Library)
  | SubLibraryTree UnqualComponentName (CondTree ConfVar [Dependency] Library)
  | ExecutableTree UnqualComponentName (CondTree ConfVar [Dependency] Executable)
  | TestSuiteTree UnqualComponentName (CondTree ConfVar [Dependency] TestSuite)
  | BenchmarkTree UnqualComponentName (CondTree ConfVar [Dependency] Benchmark)
  | ForeignLibraryTree UnqualComponentName (CondTree ConfVar [Dependency] ForeignLib)

enumerateComponents :: GenericPackageDescription -> [ComponentTree]
enumerateComponents description =
  [MainLibraryTree tree | Just tree <- [condLibrary description]]
  <> [SubLibraryTree name tree | (name, tree) <- condSubLibraries description]
  <> [ExecutableTree name tree | (name, tree) <- condExecutables description]
  <> [TestSuiteTree name tree | (name, tree) <- condTestSuites description]
  <> [BenchmarkTree name tree | (name, tree) <- condBenchmarks description]
  <> [ForeignLibraryTree name tree | (name, tree) <- condForeignLibs description]

conditionalValues :: CondTree v c a -> [a]
conditionalValues tree = condTreeData tree : concatMap branchValues (condTreeComponents tree)
 where
  branchValues branch = conditionalValues (condBranchIfTrue branch)
    <> maybe [] conditionalValues (condBranchIfFalse branch)

aggregateAll :: Monoid a => CondTree v c a -> a
aggregateAll = mconcat . conditionalValues

dependencyLibrariesFor :: PackageName -> BuildInfo -> [LibraryName]
dependencyLibrariesFor selected info =
  [library | Dependency package _ libraries <- targetBuildDepends info,
    package == selected, library <- NonEmptySet.toList libraries]

reachableFrom :: Ord node => (node -> [node]) -> [node] -> Set node
reachableFrom successors = visit Set.empty
 where
  visit reached [] = reached
  visit reached (node : remaining)
    | node `Set.member` reached = visit reached remaining
    | otherwise = visit (Set.insert node reached) (successors node <> remaining)
