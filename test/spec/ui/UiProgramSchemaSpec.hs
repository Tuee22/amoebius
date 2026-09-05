{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition (
    append,
    artifactComponent,
    budgetComponent,
    calculusTag,
    compose,
    compositionKinds,
    compositionNames,
    compositionResource,
    everyCalculus,
    evidenceComponent,
    liftComponent,
    singleton,
    workflowComponent,
 )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index (activeMembership, trustedSubject, trustedTenant, withRequestScope)
import Amoebius.Ui.Check
import Amoebius.Ui.Source
import Control.Monad (forM_, unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Test.QuickCheck (
    Args (..),
    Property,
    checkCoverage,
    counterexample,
    cover,
    elements,
    forAll,
    isSuccess,
    property,
    quickCheckWithResult,
    stdArgs,
 )
import Test.QuickCheck.Random (mkQCGen)
import UiProgramSchemaCases
import UiProgramSchemaOracle qualified as Oracle

data InvalidClass
    = DuplicateClass
    | MissingClass
    | CyclicClass
    | IllTypedClass
    | OverBoundClass
    | NonExhaustiveClass
    | PrivateClass
    | DuplicateLinkClass
    deriving stock (Bounded, Enum, Eq, Show)

main :: IO ()
main = do
    root <- getCurrentDirectory >>= canonicalizePath
    results <- mapM runCase uiCases
    let positives = [checked | (_, Right checked) <- results]
        negatives = [() | (_, Left _) <- results]
    assertEqual "positive count" 3 (length positives)
    assertEqual "negative count" 10 (length negatives)
    checkCaseOracle results
    checkProgramSemantics
    checkGraphOracle positives
    checkClosedSurface root
    checkDeterminism
    checkGeneratedCoverage
    checkCalculus
    assertEqual "validation-locus count" 30 (length Oracle.validationLoci)
    assertEqual "validation-locus uniqueness" 30 (length (unique Oracle.validationLoci))
    putStrLn "ui-program-schema-calculus: PASS (5 kinds, 30 projected units)"
    putStrLn "ui-program-schema-spec: PASS (3 semantic positives, 10 exact negatives, 3 graph rows, 8 coverage classes, 6 mutants, opaque seal)"

runCase :: UiCase -> IO (Text, Either (Text, Text) CheckedUiProgram)
runCase row = do
    result <- case uiCaseSubject row of
        TypedSource source -> pure (firstError (checkUiSource source))
        ExternalSource source -> do
            decoded <- decodeUiSourceText source
            pure $ case decoded of
                Left _ -> expectedDecodeFailure row
                Right value -> firstError (checkUiSource value)
    case (uiCaseExpected row, result) of
        (Accept, Right _) -> pure ()
        (Reject tag spanText, Left observed) -> assertEqual (Text.unpack (uiCaseName row) <> " diagnostic") (tag, spanText) observed
        _ -> die (Text.unpack (uiCaseName row) <> " outcome drifted: " <> either show (const "accepted") result)
    pure (uiCaseName row, result)

firstError :: Either UiCheckError CheckedUiProgram -> Either (Text, Text) CheckedUiProgram
firstError = either (Left . errorProjection) Right

expectedDecodeFailure :: UiCase -> Either (Text, Text) CheckedUiProgram
expectedDecodeFailure row = case uiCaseExpected row of
    Reject tag spanText -> Left (tag, spanText)
    Accept -> Left ("UnexpectedDecodeFailure", "ui.source:0")

errorProjection :: UiCheckError -> (Text, Text)
errorProjection problem = case problem of
    RecursiveEffect _ spanText -> ("RecursiveEffect", spanText)
    UnboundedCollection _ spanText -> ("UnboundedCollection", spanText)
    DuplicateQualifiedId _ spanText -> ("DuplicateQualifiedId", spanText)
    MissingReference _ spanText -> ("MissingReference", spanText)
    DuplicateExternalLinkRequirement _ spanText -> ("DuplicateExternalLinkRequirement", spanText)
    PortTypeMismatch _ spanText -> ("PortTypeMismatch", spanText)
    NonExhaustiveEvent _ spanText -> ("NonExhaustiveEvent", spanText)
    PrivateValueProjection _ spanText -> ("PrivateValueProjection", spanText)

checkCaseOracle :: [(Text, Either (Text, Text) CheckedUiProgram)] -> IO ()
checkCaseOracle results =
    assertEqual
        "independent case oracle"
        Oracle.caseOracle
        [(name, either Left (const (Right ())) result) | (name, result) <- results]

checkProgramSemantics :: IO ()
checkProgramSemantics = assertEqual "program semantic oracle" Oracle.programOracle (map programProjection positiveSources)

programProjection :: UiSource -> [Text]
programProjection source =
    [ caseName source
    , case tenantMode source of SingleTenant -> "single-tenant"; MultiTenant -> "multi-tenant"
    , Text.intercalate "," (sort (map moduleId (modules source)))
    , Text.intercalate "," (sort [moduleId uiModule <> "." <> nodeId node | uiModule <- modules source, node <- nodes uiModule])
    , Text.intercalate "," (sort (map name (externalLinks source)))
    ]

checkGraphOracle :: [CheckedUiProgram] -> IO ()
checkGraphOracle checked =
    assertEqual
        "independent graph oracle"
        Oracle.graphOracle
        [ [programName, qualified, Text.pack (show kind), Text.pack (show value), Text.intercalate "," edges', Text.intercalate "," (sort events')]
        | expected <- Oracle.graphOracle
        , let programName = expected !! 0
              qualifiedName = expected !! 1
        , program <- checked
        , checkedCaseName program == programName
        , (qualified, kind, value, edges', events') <- checkedGraphRows program
        , qualified == qualifiedName
        ]

checkClosedSurface :: FilePath -> IO ()
checkClosedSurface root = do
    assertEqual "closed node-kind arms" [Route, State, Event, Port, Collection, Branch, ExternalLink] ([minBound .. maxBound] :: [NodeKind])
    assertEqual "closed value-type arms" [Text, Natural, Boolean, View, TenantChoice, WorkflowStart, WorkflowProgress, ServerHandle] ([minBound .. maxBound] :: [ValueType])
    source <- readFile (root </> "src/Amoebius/Ui/Source.hs")
    forM_ ["RawJs", "RawHtml", "RawCss", "RawUrl", "ProviderCoordinate", "AuthorityCredential"] $ \token ->
        assert (not (token `contains` source)) ("forbidden source arm is present: " <> token)

checkDeterminism :: IO ()
checkDeterminism = forM_ positiveSources $ \source ->
    assertEqual
        (Text.unpack (caseName source) <> " deterministic check")
        (fmap checkedGraphRows (checkUiSource source))
        (fmap checkedGraphRows (checkUiSource source))

checkGeneratedCoverage :: IO ()
checkGeneratedCoverage = do
    let classes = [minBound .. maxBound] :: [InvalidClass]
        args = stdArgs{maxSuccess = 320, replay = Just (mkQCGen 160016, 0), chatty = False}
    result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty minimalSingleTenant classes)
    assert (isSuccess result) "generated rejection coverage failed"

coverageProperty :: UiSource -> [InvalidClass] -> InvalidClass -> Property
coverageProperty base classes selected =
    checkCoverage $
        foldr
            (\invalid -> cover 5 (selected == invalid) (show invalid))
            (counterexample (show selected) (property (matchesClass selected (checkUiSource (mutate selected base)))))
            classes

matchesClass :: InvalidClass -> Either UiCheckError CheckedUiProgram -> Bool
matchesClass invalid result = case (invalid, result) of
    (DuplicateClass, Left (DuplicateQualifiedId _ _)) -> True
    (MissingClass, Left (MissingReference _ _)) -> True
    (CyclicClass, Left (RecursiveEffect _ _)) -> True
    (IllTypedClass, Left (PortTypeMismatch _ _)) -> True
    (OverBoundClass, Left (UnboundedCollection _ _)) -> True
    (NonExhaustiveClass, Left (NonExhaustiveEvent _ _)) -> True
    (PrivateClass, Left (PrivateValueProjection _ _)) -> True
    (DuplicateLinkClass, Left (DuplicateExternalLinkRequirement _ _)) -> True
    _ -> False

mutate :: InvalidClass -> UiSource -> UiSource
mutate invalid source = case invalid of
    DuplicateClass -> mapFirstModule (\uiModule -> uiModule{nodes = duplicateFirst (nodes uiModule)}) source
    MissingClass -> mapFirstNode (\node -> node{edges = ["missing"]}) source
    CyclicClass -> mapFirstNode (\node -> node{edges = [nodeId node]}) source
    IllTypedClass -> mapFirstNode (\node -> node{nodeKind = Port, portType = Just Natural}) source
    OverBoundClass -> mapFirstNode (\node -> node{maxItems = Just 65}) source
    NonExhaustiveClass -> mapFirstNode (\node -> node{events = ["a", "b"], branches = ["a"]}) source
    PrivateClass -> mapFirstNode (\node -> node{valueType = ServerHandle, public = True}) source
    DuplicateLinkClass -> source{externalLinks = [ExternalLinkRequirement "docs", ExternalLinkRequirement "docs"]}

mapFirstModule :: (UiModule -> UiModule) -> UiSource -> UiSource
mapFirstModule transform source = case modules source of
    [] -> source
    uiModule : rest -> source{modules = transform uiModule : rest}

mapFirstNode :: (UiNode -> UiNode) -> UiSource -> UiSource
mapFirstNode transform = mapFirstModule $ \uiModule -> case nodes uiModule of
    [] -> uiModule
    node : rest -> uiModule{nodes = transform node : rest}

duplicateFirst :: [value] -> [value]
duplicateFirst [] = []
duplicateFirst (value : values) = value : value : values

checkCalculus :: IO ()
checkCalculus = do
    tenant <- either (fail . show) pure (trustedTenant "ui-program-schema-calculus-tenant")
    subject <- either (fail . show) pure (trustedSubject tenant "ui-program-schema-calculus-subject")
    membership <- either (fail . show) pure (activeMembership tenant subject)
    action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
        let resources :: Int -> ResourceVector
            resources count = ResourceVector 1 (fromIntegral count) 0 0
            counts = [3, 10, 8, 3, 6] :: [Int]
            composition =
                append
                    ( compose
                        (artifactComponent scope "program-semantics" (resources 3) (RecipeId "ui-program-schema" 3))
                        (budgetComponent scope "diagnostic-budget" (resources 10) (allowance (Bytes 10) (Slots 1) (Bytes 10)))
                    )
                    ( append
                        ( compose
                            (liftComponent scope "generated-rejection-classes" (resources 8) OnHost)
                            (workflowComponent scope "graph-check-workflow" (resources 3) emptyLedger)
                        )
                        (singleton (evidenceComponent scope "mutant-evidence" (resources 6) PureRegister))
                    )
            ResourceVector cpu memory ephemeral pods = compositionResource composition
            actual =
                [ ["calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition))]
                , ["component-names", Text.intercalate "," (compositionNames composition)]
                , ["projection-counts", Text.intercalate "," (map showText counts)]
                , ["resource-vector", Text.intercalate "," (map showText [cpu, memory, ephemeral, pods])]
                ]
        assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
        assertEqual "five-calculus semantic projection" Oracle.calculusOracle actual
    action

unique :: (Ord value) => [value] -> [value]
unique = foldr (\value values -> if value `elem` values then values else value : values) []

showText :: (Show value) => value -> Text
showText = Text.pack . show

contains :: String -> String -> Bool
contains needle haystack = any (prefix needle) (tails haystack)
  where
    prefix value candidate = take (length value) candidate == value
    tails [] = [[]]
    tails values@(_ : rest) = values : tails rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
