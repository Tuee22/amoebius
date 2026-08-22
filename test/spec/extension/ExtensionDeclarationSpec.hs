{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( Calculus (..)
  , artifactComponent
  , budgetComponent
  , compositionKinds
  , evidenceComponent
  , liftComponent
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (..))
import Amoebius.Calculus.Lift.Layer (Layer (..))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (..), addResources, zeroResources)
import Amoebius.Extension.Declaration
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM, unless)
import Data.List (sort)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import ExtensionDeclarationMutants (omitDeclaredRecipe)
import System.Directory (canonicalizePath, createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))

data InventoryRow = InventoryRow
  { inventoryExtension :: Text
  , inventoryCalculus :: Text
  , inventoryComponent :: Text
  , inventoryCpu :: Text
  , inventoryMemory :: Text
  , inventoryEphemeral :: Text
  , inventoryPods :: Text
  , inventoryDescriptor :: Text
  , inventoryIdentity :: Text
  }
  deriving stock (Eq, Ord, Show)

data FixtureObservation = FixtureObservation
  { observedName :: Text
  , observedRows :: [InventoryRow]
  , observedDigest :: Text
  , observedResource :: ResourceVector
  , observedKinds :: [Calculus]
  , observedReaderSizes :: [Int]
  }

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  case arguments of
    [] -> runGreen root
    ["--mutant=omit-declared-recipe"] -> runOmissionMutant
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> IO ()
runGreen root = do
  expected <- loadInventory root
  actual <- fixtures
  assertEqual "two fixture declarations" 2 (length actual)
  assertEqual "independent inventory" (sort expected) (sort (concatMap observedRows actual))
  assertEqual "ten mandatory components" 10 (sum (map (length . observedRows) actual))
  mapM_ checkObservation actual
  assert (distinct (map observedDigest actual)) "declaration digests are distinct"
  assert (all validDigest (map observedDigest actual)) "declaration digests are lowercase SHA-256 hex"
  checkSemanticNegatives
  checkDigestSensitivity
  writeActual root actual
  writeResults root
  putStrLn "extension-declaration-spec: PASS (2 declarations, 10 components, 5 readers, 2 exact refusals)"

fixtures :: IO [FixtureObservation]
fixtures = do
  infernix <- observe "infernix" makeInfernix
  jitml <- observe "jitml" makeJitml
  pure [infernix, jitml]

observe
  :: Text
  -> (forall scope. RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope))
  -> IO FixtureObservation
observe name build = do
  tenant <- either (die . show) pure (trustedTenant (name <> "-tenant"))
  subject <- either (die . show) pure (trustedSubject tenant (name <> "-subject"))
  membership <- either (die . show) pure (activeMembership tenant subject)
  nested <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    declaration <- mapLeft show (build scope)
    let components = declarationComponents declaration
    pure FixtureObservation
      { observedName = extensionName declaration
      , observedRows = map (inventoryRow name) components
      , observedDigest = declarationDigest declaration
      , observedResource = declarationResource declaration
      , observedKinds = compositionKinds (declarationComposition declaration)
      , observedReaderSizes =
          [ Set.size (declarationArtifactSet declaration)
          , Set.size (declarationBudgetSet declaration)
          , Set.size (declarationLiftSet declaration)
          , Set.size (declarationWorkflowSet declaration)
          , Set.size (declarationEvidenceSet declaration)
          ]
      }
  either die pure nested

makeInfernix :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
makeInfernix = makeInfernixNamed "infernix"

makeInfernixNamed :: Text -> RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
makeInfernixNamed name scope =
  declareExtension
    name
    (artifactComponent scope "infernix-image" (ResourceVector 2 1024 20 1) (RecipeId "infernix-image" 3))
    (budgetComponent scope "inference-budget" (ResourceVector 1 512 5 1) (allowance (Bytes 4096) (Slots 2) (Bytes 2048)))
    (liftComponent scope "inference-layer" (ResourceVector 0 0 0 0) InContainer)
    (workflowComponent scope "inference-workflow" (ResourceVector 1 256 1 1) emptyLedger)
    (evidenceComponent scope "inference-evidence" (ResourceVector 0 0 0 0) SimulationRegister)

makeJitml :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
makeJitml scope =
  declareExtension
    "jitml"
    (artifactComponent scope "jitml-model" (ResourceVector 4 2048 40 1) (RecipeId "jitml-model" 5))
    (budgetComponent scope "training-budget" (ResourceVector 2 1024 10 1) (allowance (Bytes 8192) (Slots 3) (Bytes 4096)))
    (liftComponent scope "training-layer" (ResourceVector 0 0 0 0) InFrame)
    (workflowComponent scope "training-workflow" (ResourceVector 1 512 2 1) emptyLedger)
    (evidenceComponent scope "training-evidence" (ResourceVector 0 0 0 0) BoundaryRegister)

checkObservation :: FixtureObservation -> IO ()
checkObservation observation = do
  assertEqual (Text.unpack (observedName observation) <> " calculus order")
    [ArtifactCalculus, BudgetCalculus, LiftCalculus, WorkflowCalculus, EvidenceCalculus]
    (observedKinds observation)
  assertEqual (Text.unpack (observedName observation) <> " reader cardinalities")
    [1, 1, 1, 1, 1]
    (observedReaderSizes observation)
  let expectedResource = foldl addResources zeroResources (map rowResource (observedRows observation))
  assertEqual (Text.unpack (observedName observation) <> " exact resource fold")
    expectedResource
    (observedResource observation)

checkSemanticNegatives :: IO ()
checkSemanticNegatives = do
  tenant <- either (die . show) pure (trustedTenant "negative-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "negative-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  outcome <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope ->
    let artifact = artifactComponent scope "a" zeroResources (RecipeId "a" 1)
        budget = budgetComponent scope "b" zeroResources (allowance (Bytes 1) (Slots 1) (Bytes 1))
        lift = liftComponent scope "l" zeroResources OnHost
        workflow = workflowComponent scope "w" zeroResources emptyLedger
        evidence = evidenceComponent scope "e" zeroResources PureRegister
    in
      ( () <$ declareExtension "wrong-slot" budget budget lift workflow evidence
      , () <$ declareExtension "" artifact budget lift workflow evidence
      )
  let (wrongSlot, emptyName) = outcome
  assertEqual "wrong artifact slot refusal"
    (Left (UnexpectedCalculus ArtifactCalculus BudgetCalculus)) wrongSlot
  assertEqual "empty extension name refusal" (Left EmptyExtensionName) emptyName

checkDigestSensitivity :: IO ()
checkDigestSensitivity = do
  original <- observe "infernix" makeInfernix
  renamed <- observe "infernix-renamed" (makeInfernixNamed "infernix-renamed")
  assert (observedDigest original /= observedDigest renamed) "extension name participates in digest"

runOmissionMutant :: IO ()
runOmissionMutant = do
  tenant <- either (die . show) pure (trustedTenant "mutant-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "mutant-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  nested <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    declaration <- makeInfernix scope
    pure (Set.size (declarationArtifactSet declaration), Set.size (omitDeclaredRecipe declaration))
  omitted <- either (die . show) pure nested
  case omitted of
    (1, 0) -> do
      putStrLn "extension-declaration-mutant: RED omit-declared-recipe ArtifactReaderComplete"
      exitFailure
    counts -> die ("omission mutant was not distinguishable: " <> show counts)

inventoryRow :: Text -> DeclaredComponent -> InventoryRow
inventoryRow extension component =
  InventoryRow
    { inventoryExtension = extension
    , inventoryCalculus = calculusText (declaredCalculus component)
    , inventoryComponent = declaredName component
    , inventoryCpu = naturalText (resourceCpu resources)
    , inventoryMemory = naturalText (resourceMemory resources)
    , inventoryEphemeral = naturalText (resourceEphemeralStorage resources)
    , inventoryPods = naturalText (resourcePodSlots resources)
    , inventoryDescriptor = declaredDescriptor component
    , inventoryIdentity = Text.intercalate "|" (declaredIdentityFields component)
    }
 where
  resources = declaredResource component

rowResource :: InventoryRow -> ResourceVector
rowResource row =
  ResourceVector
    (read (Text.unpack (inventoryCpu row)))
    (read (Text.unpack (inventoryMemory row)))
    (read (Text.unpack (inventoryEphemeral row)))
    (read (Text.unpack (inventoryPods row)))

calculusText :: Calculus -> Text
calculusText calculus = case calculus of
  ArtifactCalculus -> "artifact"
  BudgetCalculus -> "budget"
  LiftCalculus -> "lift"
  WorkflowCalculus -> "workflow"
  EvidenceCalculus -> "evidence"

naturalText :: Show value => value -> Text
naturalText = Text.pack . show

loadInventory :: FilePath -> IO [InventoryRow]
loadInventory root = do
  rows <- rowsOf (root </> "test/oracle/extension_declaration/inventory.tsv")
  case rows of
    header : body -> do
      assertEqual "inventory header"
        ["extension", "calculus", "component", "cpu", "memory", "ephemeral", "pods", "descriptor", "identity"] header
      forM body $ \row -> case row of
        [extension, calculus, component, cpu, memory, ephemeral, pods, descriptor, identity] ->
          pure (InventoryRow extension calculus component cpu memory ephemeral pods descriptor identity)
        _ -> die ("invalid inventory row: " <> show row)
    [] -> die "empty extension declaration inventory"

writeActual :: FilePath -> [FixtureObservation] -> IO ()
writeActual root observations = do
  let output = root </> ".build/dsl/extension-declaration"
  createDirectoryIfMissing True output
  writeFile (output </> "actual-declarations.tsv")
    ( "extension\tcalculus\tcomponent\tcpu\tmemory\tephemeral\tpods\tdescriptor\tidentity\tdigest\n"
        <> concatMap renderObservation observations
    )
 where
  renderObservation observation = concatMap (renderRow (observedDigest observation)) (observedRows observation)
  renderRow digest row = Text.unpack (Text.intercalate "\t"
    [ inventoryExtension row
    , inventoryCalculus row
    , inventoryComponent row
    , inventoryCpu row
    , inventoryMemory row
    , inventoryEphemeral row
    , inventoryPods row
    , inventoryDescriptor row
    , inventoryIdentity row
    , digest
    ]) <> "\n"

writeResults :: FilePath -> IO ()
writeResults root = do
  let output = root </> ".build/dsl/extension-declaration"
      metrics =
        [ ("declarations", "2/2-concrete")
        , ("components", "10/10-mandatory")
        , ("calculus-slots", "2x5-exact-and-ordered")
        , ("reader-sets", "10/10-match-independent-inventory")
        , ("resource-folds", "2/2-exact-natural-sums")
        , ("digests", "2/2-stable-distinct")
        , ("semantic-refusals", "2/2-exact")
        , ("runtime", "UNVERIFIED")
        ]
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [key <> "\t" <> value <> "\n" | (key, value) <- metrics])

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines <$> readFileText path

readFileText :: FilePath -> IO Text
readFileText path = Text.pack <$> readFile path

validDigest :: Text -> Bool
validDigest digest = Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest

distinct :: Ord value => [value] -> Bool
distinct values = Set.size (Set.fromList values) == length values

mapLeft :: (problem -> other) -> Either problem value -> Either other value
mapLeft function value = case value of
  Left problem -> Left (function problem)
  Right result -> Right result

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
