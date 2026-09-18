{-# LANGUAGE OverloadedStrings #-}

-- | Stage 1 of the runner (gate_runner_doctrine.md section 3): map every subject to
-- exactly one library stanza, compute the shipped executable's closure from the
-- package description, refuse any subject outside it, and check the oracle stanza's
-- hygiene. Nothing here reads a candidate's own claims about its layout.
module Amoebius.Validation.Runner.Spec
  ( PackageGraph (..)
  , SpecProblem (..)
  , VerifiedSpec (..)
  , executableClosure
  , loadPackageGraph
  , moduleSourcePath
  , parsePackageGraph
  , renderSpecProblem
  , verifySpec
  , verifySpecAgainst
  ) where

import Amoebius.Validation.GateSpec
import Control.Monad (filterM, forM)
import Data.ByteString qualified as ByteString
import Data.List (isInfixOf, isSuffixOf, nub, sort)
import Data.List.NonEmpty (NonEmpty)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Distribution.Compat.NonEmptySet qualified as NonEmptySet
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.PackageDescription
  ( BuildInfo (..)
  , Executable (..)
  , GenericPackageDescription (..)
  , Library (..)
  , LibraryName (..)
  , TestSuite (..)
  )
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Pretty (prettyShow)
import Distribution.Types.CondTree (CondBranch (..), CondTree (..))
import Distribution.Types.Dependency (Dependency (..), depPkgName)
import Distribution.Types.PackageName (unPackageName)
import Distribution.Types.UnqualComponentName (unUnqualComponentName)
import Distribution.Utils.Path (getSymbolicPath)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath ((</>))

-- | The package description reduced to what the runner needs.
data PackageGraph = PackageGraph
  { graphLibraries :: Map Text (Set Text, Set Text, [FilePath]) -- stanza -> (modules, internal library deps, source dirs)
  , graphExecutables :: Map Text (Set Text) -- executable -> internal library deps
  , graphTestSuites :: Map Text ([FilePath], Set Text, Bool) -- suite -> (source dirs, package deps by name, depends on amoebius)
  }
  deriving (Eq, Show)

data SpecProblem
  = PackageDescriptionUnparsable Text
  | SubjectNotInPackage ProductionModule
  | SubjectInMultipleStanzas ProductionModule [Text]
  | SubjectOutsideClosure ProductionModule Text
  | ProductExecutableMissing
  | SuiteStanzaMissing CabalTarget
  | OracleStanzaMissing OracleExecutable
  | OracleDependsOnPackage OracleExecutable
  | OracleSourceDirectoryMissing OracleExecutable FilePath
  | OracleConditionalCompilation FilePath
  | OracleTemplateHaskell FilePath
  | OracleForeignImport FilePath
  | OracleEntryNotMain OracleExecutable [FilePath]
  deriving (Eq, Ord, Show)

renderSpecProblem :: SpecProblem -> Text
renderSpecProblem problem = case problem of
  PackageDescriptionUnparsable detail -> "PACKAGE-UNPARSABLE: " <> detail
  SubjectNotInPackage (ProductionModule name) -> "SUBJECT-NOT-IN-PACKAGE: " <> name
  SubjectInMultipleStanzas (ProductionModule name) stanzas -> "SUBJECT-AMBIGUOUS: " <> name <> " in " <> Text.intercalate "," stanzas
  SubjectOutsideClosure (ProductionModule name) stanza -> "SUBJECT-NOT-SHIPPED: " <> name <> " (" <> stanza <> ")"
  ProductExecutableMissing -> "PRODUCT-EXECUTABLE-MISSING"
  SuiteStanzaMissing (CabalTarget name) -> "SUITE-MISSING: " <> name
  OracleStanzaMissing (OracleExecutable name) -> "ORACLE-MISSING: " <> name
  OracleDependsOnPackage (OracleExecutable name) -> "ORACLE-DEPENDS-ON-PRODUCT: " <> name
  OracleSourceDirectoryMissing (OracleExecutable name) directory -> "ORACLE-SOURCE-MISSING: " <> name <> " " <> Text.pack directory
  OracleConditionalCompilation path -> "ORACLE-CPP: " <> Text.pack path
  OracleTemplateHaskell path -> "ORACLE-TEMPLATE-HASKELL: " <> Text.pack path
  OracleForeignImport path -> "ORACLE-FOREIGN-IMPORT: " <> Text.pack path
  OracleEntryNotMain (OracleExecutable name) files -> "ORACLE-ENTRY: " <> name <> " " <> Text.pack (show files)

data VerifiedSpec = VerifiedSpec
  { verifiedSpec :: GateSpec
  , verifiedStanzaOf :: Map ProductionModule Text
  , verifiedClosure :: Set Text
  , verifiedOracleDirectories :: [FilePath]
  }
  deriving (Eq, Show)

productExecutable :: Text
productExecutable = "amoebius"

verifierExecutable :: Text
verifierExecutable = "amoebius-validate"

loadPackageGraph :: FilePath -> IO (Either SpecProblem PackageGraph)
loadPackageGraph root = parsePackageGraph <$> ByteString.readFile (root </> "amoebius.cabal")

parsePackageGraph :: ByteString.ByteString -> Either SpecProblem PackageGraph
parsePackageGraph bytes = case runParseResult (parseGenericPackageDescription bytes) of
  (_, Left (_, problems)) -> Left (PackageDescriptionUnparsable (Text.pack (show (NonEmpty.toList problems))))
  (_, Right description) -> Right (reduce description)

reduce :: GenericPackageDescription -> PackageGraph
reduce description =
  PackageGraph
    { graphLibraries =
        Map.fromList
          ( [("amoebius", libraryEntry library) | Just tree <- [condLibrary description], let library = flatten tree]
              <> [(Text.pack (unUnqualComponentName name), libraryEntry (flatten tree)) | (name, tree) <- condSubLibraries description]
          )
    , graphExecutables =
        Map.fromList
          [ (Text.pack (unUnqualComponentName name), internalDependencies (buildInfo (flatten tree)))
          | (name, tree) <- condExecutables description
          ]
    , graphTestSuites =
        Map.fromList
          [ ( Text.pack (unUnqualComponentName name)
            , ( map getSymbolicPath (hsSourceDirs info)
              , Set.fromList (map (Text.pack . unPackageName . depPkgName) (targetBuildDepends info))
              , any ((== "amoebius") . unPackageName . depPkgName) (targetBuildDepends info)
              )
            )
          | (name, tree) <- condTestSuites description
          , let info = testBuildInfo (flatten tree)
          ]
    }
 where
  libraryEntry library =
    ( Set.fromList (map (Text.pack . prettyShow) (exposedModules library <> otherModules (libBuildInfo library)))
    , internalDependencies (libBuildInfo library)
    , map getSymbolicPath (hsSourceDirs (libBuildInfo library))
    )

internalDependencies :: BuildInfo -> Set Text
internalDependencies info =
  Set.fromList
    [ libraryStanza name
    | Dependency package _ libraries <- targetBuildDepends info
    , unPackageName package == "amoebius"
    , name <- NonEmptySet.toList libraries
    ]
 where
  libraryStanza name = case name of
    LMainLibName -> "amoebius"
    LSubLibName sub -> Text.pack (unUnqualComponentName sub)

flatten :: Monoid a => CondTree v c a -> a
flatten tree =
  condTreeData tree
    <> mconcat
      [ flatten (condBranchIfTrue branch) <> maybe mempty flatten (condBranchIfFalse branch)
      | branch <- condTreeComponents tree
      ]

-- | The library stanzas the product executable links, transitively.
executableClosure :: PackageGraph -> Text -> Maybe (Set Text)
executableClosure graph executable = do
  direct <- Map.lookup executable (graphExecutables graph)
  pure (close Set.empty (Set.toList direct))
 where
  close seen [] = seen
  close seen (stanza : rest)
    | Set.member stanza seen = close seen rest
    | otherwise =
        let deps = maybe Set.empty (\(_, internal, _) -> internal) (Map.lookup stanza (graphLibraries graph))
         in close (Set.insert stanza seen) (Set.toList deps <> rest)

verifySpec :: FilePath -> GateSpec -> IO (Either [SpecProblem] VerifiedSpec)
verifySpec root spec = do
  loaded <- loadPackageGraph root
  case loaded of
    Left problem -> pure (Left [problem])
    Right graph -> verifySpecAgainst root graph spec

-- | Verify against an already parsed graph; the oracle source scan reads the
-- oracle directories beneath the root.
verifySpecAgainst :: FilePath -> PackageGraph -> GateSpec -> IO (Either [SpecProblem] VerifiedSpec)
verifySpecAgainst root graph spec = do
  oracleProblems <- oracleHygiene
  let problems = subjectProblems <> suiteProblems <> oracleProblems
  pure $ case (problems, closure) of
    ([], Just shipped) ->
      Right
        VerifiedSpec
          { verifiedSpec = spec
          , verifiedStanzaOf = Map.fromList [(subject, stanza) | subject <- gateSubjects spec, [stanza] <- [stanzasOf subject]]
          , verifiedClosure = shipped
          , verifiedOracleDirectories = oracleDirectories
          }
    _ -> Left (nub problems)
 where
  closure = executableClosure graph (if gateRole spec == SeedGate then verifierExecutable else productExecutable)
  stanzasOf (ProductionModule name) = sort [stanza | (stanza, (modules, _, _)) <- Map.toList (graphLibraries graph), Set.member name modules]
  subjectProblems =
    [ProductExecutableMissing | closure == Nothing]
      <> concat
        [ case stanzasOf subject of
            [] -> [SubjectNotInPackage subject]
            [stanza]
              | maybe False (Set.member stanza) closure -> []
              | otherwise -> [SubjectOutsideClosure subject stanza]
            many -> [SubjectInMultipleStanzas subject many]
        | subject <- gateSubjects spec
        ]
  suiteProblems = [SuiteStanzaMissing (gateSuite spec) | Map.notMember (cabalTargetName (gateSuite spec)) (graphTestSuites graph)]
  oracle = gateOracle spec
  oracleEntry = Map.lookup (oracleExecutableName oracle) (graphTestSuites graph)
  oracleDirectories = maybe [] (\(dirs, _, _) -> dirs) oracleEntry
  oracleHygiene = case oracleEntry of
    Nothing -> pure [OracleStanzaMissing oracle]
    Just (dirs, _, dependsOnPackage) -> do
      scanned <- forM dirs $ \directory -> do
        exists <- doesDirectoryExist (root </> directory)
        if not exists
          then pure [OracleSourceDirectoryMissing oracle directory]
          else do
            files <- haskellFiles (root </> directory)
            problems <- forM files $ \file -> do
              contents <- TextIO.readFile file
              pure (sourceHygiene file contents)
            pure
              ( concat problems
                  <> [OracleEntryNotMain oracle files | not (any (("Main.hs" `isSuffixOf`)) files)]
              )
      pure ([OracleDependsOnPackage oracle | dependsOnPackage] <> concat scanned)

sourceHygiene :: FilePath -> Text -> [SpecProblem]
sourceHygiene file contents =
  [OracleConditionalCompilation file | any (\line -> "#" `Text.isPrefixOf` line) lines' || languagePragma "CPP"]
    <> [OracleTemplateHaskell file | languagePragma "TemplateHaskell" || languagePragma "TemplateHaskellQuotes" || any ("$(" `Text.isInfixOf`) lines']
    <> [OracleForeignImport file | any (\line -> "foreign import" `Text.isPrefixOf` Text.stripStart line || "foreign export" `Text.isPrefixOf` Text.stripStart line) lines']
 where
  lines' = Text.lines contents
  languagePragma extension = any (\line -> "{-# LANGUAGE" `Text.isPrefixOf` line && extension `Text.isInfixOf` line) lines'

haskellFiles :: FilePath -> IO [FilePath]
haskellFiles directory = do
  names <- listDirectory directory
  directories <- filterM (doesDirectoryExist . (directory </>)) names
  nested <- concat <$> mapM (haskellFiles . (directory </>)) directories
  pure ([directory </> name | name <- names, ".hs" `isSuffixOf` name, name `notElem` directories] <> nested)

-- | The source file of a module inside a stanza: the first source directory of
-- that stanza beneath which the module path exists.
moduleSourcePath :: FilePath -> PackageGraph -> Text -> ProductionModule -> IO (Maybe FilePath)
moduleSourcePath root graph stanza (ProductionModule name) =
  case Map.lookup stanza (graphLibraries graph) of
    Nothing -> pure Nothing
    Just (_, _, dirs) -> firstExisting [dir </> relative | dir <- dirs]
 where
  relative = Text.unpack (Text.replace "." "/" name) <> ".hs"
  firstExisting [] = pure Nothing
  firstExisting (candidate : rest) = do
    exists <- doesFileExist (root </> candidate)
    if exists then pure (Just candidate) else firstExisting rest

_unusedInfix :: String -> String -> Bool
_unusedInfix = isInfixOf

_unusedNonEmpty :: NonEmpty Int -> Int
_unusedNonEmpty = NonEmpty.head
