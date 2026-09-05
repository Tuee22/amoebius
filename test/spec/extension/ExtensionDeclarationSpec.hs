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
import Control.Monad (unless)
import Data.List (sort)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import ExtensionDeclarationOracle
  ( OracleRow (..)
  , declarationCases
  , oracleDeclarationDigest
  )
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

data FixtureObservation = FixtureObservation
  { observedName :: Text
  , observedRows :: [OracleRow]
  , observedDigest :: Text
  , observedResource :: ResourceVector
  , observedKinds :: [Calculus]
  , observedReaderSizes :: [Int]
  }

main :: IO ()
main = do
  actual <- fixtures
  assertEqual "DeclarationCount" 2 (length actual)
  assertEqual "CompleteIndexedDeclaration" (sort (concatMap snd declarationCases)) (sort (concatMap observedRows actual))
  assertEqual "RequiredComponents" 10 (sum (map (length . observedRows) actual))
  mapM_ checkObservation actual
  assert (distinct (map observedDigest actual)) "ContentDerivedIdentity: declaration digests are not distinct"
  assert (all validDigest (map observedDigest actual)) "ContentDerivedIdentity: digest is not lowercase SHA-256 hex"
  checkSemanticPairs
  checkDigestSensitivity
  output <- maybe ".build/dsl/extension-declaration" id <$> lookupEnv "AMOEBIUS_EXTENSION_DECLARATION_OUTPUT"
  writeActual output actual
  writeResults output
  putStrLn "extension-declaration-spec: PASS (2 declarations, 10 components, 5 readers, 2 digests, 2 refusal pairs)"

fixtures :: IO [FixtureObservation]
fixtures = sequence [observe "infernix" makeInfernix, observe "jitml" makeJitml]

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
    let rows = map (oracleRow name) (declarationComponents declaration)
    pure FixtureObservation
      { observedName = extensionName declaration
      , observedRows = rows
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
  declareExtension name
    (artifactComponent scope "infernix-image" (ResourceVector 2 1024 20 1) (RecipeId "infernix-image" 3))
    (budgetComponent scope "inference-budget" (ResourceVector 1 512 5 1) (allowance (Bytes 4096) (Slots 2) (Bytes 2048)))
    (liftComponent scope "inference-layer" zeroResources InContainer)
    (workflowComponent scope "inference-workflow" (ResourceVector 1 256 1 1) emptyLedger)
    (evidenceComponent scope "inference-evidence" zeroResources SimulationRegister)

makeJitml :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
makeJitml scope =
  declareExtension "jitml"
    (artifactComponent scope "jitml-model" (ResourceVector 4 2048 40 1) (RecipeId "jitml-model" 5))
    (budgetComponent scope "training-budget" (ResourceVector 2 1024 10 1) (allowance (Bytes 8192) (Slots 3) (Bytes 4096)))
    (liftComponent scope "training-layer" zeroResources InFrame)
    (workflowComponent scope "training-workflow" (ResourceVector 1 512 2 1) emptyLedger)
    (evidenceComponent scope "training-evidence" zeroResources BoundaryRegister)

checkObservation :: FixtureObservation -> IO ()
checkObservation observation = do
  expected <- case lookup (observedName observation) declarationCases of
    Nothing -> die ("IndependentOracle: undeclared fixture " <> Text.unpack (observedName observation))
    Just rows -> pure rows
  assertEqual "CalculusOrder"
    [ArtifactCalculus, BudgetCalculus, LiftCalculus, WorkflowCalculus, EvidenceCalculus]
    (observedKinds observation)
  assertEqual "ArtifactReaderComplete" [1, 1, 1, 1, 1] (observedReaderSizes observation)
  assertEqual "ReaderInventory" expected (observedRows observation)
  assertEqual "ExactResourceFold"
    (foldl addResources zeroResources (map oracleResource expected))
    (observedResource observation)
  assertEqual "ContentDerivedIdentity"
    (oracleDeclarationDigest (observedName observation) expected)
    (observedDigest observation)

checkSemanticPairs :: IO ()
checkSemanticPairs = do
  tenant <- either (die . show) pure (trustedTenant "negative-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "negative-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  result <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope ->
    let artifact = artifactComponent scope "a" zeroResources (RecipeId "a" 1)
        budget = budgetComponent scope "b" zeroResources (allowance (Bytes 1) (Slots 1) (Bytes 1))
        lift = liftComponent scope "l" zeroResources OnHost
        workflow = workflowComponent scope "w" zeroResources emptyLedger
        evidence = evidenceComponent scope "e" zeroResources PureRegister
        legal = () <$ declareExtension "legal" artifact budget lift workflow evidence
    in (legal, () <$ declareExtension "wrong-slot" budget budget lift workflow evidence,
        legal, () <$ declareExtension "" artifact budget lift workflow evidence)
  case result of
    (Right _, Left (UnexpectedCalculus ArtifactCalculus BudgetCalculus), Right _, Left EmptyExtensionName) -> pure ()
    other -> die ("ExactRefusalPairs: " <> show other)

checkDigestSensitivity :: IO ()
checkDigestSensitivity = do
  original <- observe "infernix" makeInfernix
  renamed <- observe "infernix-renamed" (makeInfernixNamed "infernix-renamed")
  assert (observedDigest original /= observedDigest renamed) "ContentDerivedIdentity: name was omitted"

oracleRow :: Text -> DeclaredComponent -> OracleRow
oracleRow extension component =
  OracleRow extension (calculusText (declaredCalculus component)) (declaredName component)
    (declaredResource component) (declaredDescriptor component) (declaredIdentityFields component)

calculusText :: Calculus -> Text
calculusText calculus = case calculus of
  ArtifactCalculus -> "artifact"
  BudgetCalculus -> "budget"
  LiftCalculus -> "lift"
  WorkflowCalculus -> "workflow"
  EvidenceCalculus -> "evidence"

writeActual :: FilePath -> [FixtureObservation] -> IO ()
writeActual output observations = do
  createDirectoryIfMissing True output
  writeFile (output </> "actual-declarations.tsv")
    ("extension\tcalculus\tcomponent\tcpu\tmemory\tephemeral\tpods\tdescriptor\tidentity\tdigest\n"
      <> concatMap renderObservation observations)
 where
  renderObservation observation = concatMap (renderRow (observedDigest observation)) (observedRows observation)
  renderRow digest row = Text.unpack (Text.intercalate "\t"
    [ oracleExtension row, oracleCalculus row, oracleComponent row
    , number (resourceCpu resources), number (resourceMemory resources)
    , number (resourceEphemeralStorage resources), number (resourcePodSlots resources)
    , oracleDescriptor row, Text.intercalate "|" (oracleIdentityFields row), digest
    ]) <> "\n"
   where resources = oracleResource row

writeResults :: FilePath -> IO ()
writeResults output = do
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> unlines
      [ "declarations\t2/2-concrete"
      , "components\t10/10-mandatory"
      , "calculus-slots\t2x5-exact-and-ordered"
      , "reader-sets\t10/10-match-independent-haskell-oracle"
      , "resource-folds\t2/2-exact-natural-sums"
      , "digests\t2/2-independently-recomputed"
      , "semantic-refusal-pairs\t2/2-exact"
      , "runtime\tUNVERIFIED"
      ])

number :: Show value => value -> Text
number = Text.pack . show

validDigest :: Text -> Bool
validDigest digest = Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest

distinct :: Ord value => [value] -> Bool
distinct values = Set.size (Set.fromList values) == length values

mapLeft :: (problem -> other) -> Either problem value -> Either other value
mapLeft function value = case value of Left problem -> Left (function problem); Right result -> Right result

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
