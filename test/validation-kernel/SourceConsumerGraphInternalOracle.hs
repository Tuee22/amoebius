{-# LANGUAGE OverloadedStrings #-}

module SourceConsumerGraphInternalOracle
  ( runSourceConsumerGraphInternalOracle
  , runSourceConsumerGraphInternalSelectorControlOracle
  , runSourceConsumerGraphInternalSelectorOracle
  , sourceConsumerGraphInternalSelectorIntents
  , sourceConsumerGraphInternalSelectorNames
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( IndexEntry (..)
  , IndexMode (..)
  , SourceClass (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  )
import Amoebius.Validation.SourceConsumerGraph.Internal
  ( AuthorizedConsumer (..)
  , CompilerGraphResidue
  , ConsumerGraphProblem (..)
  , ContentBinding (..)
  , ContentRole (..)
  , ContentUse (..)
  , HaskellSubject (..)
  , RequiredCompilerFact (..)
  , ResolvedContentEffect (..)
  , ResolvedEffectTarget (..)
  , analyzeSourceConsumerGraph
  , analyzeSourceConsumerGraphWithResolvedEffects
  , auditResolvedEffects
  , bindingInvariantProblemsDiagnostic
  , consumerGraphBindings
  , consumerGraphProblems
  , consumerGraphResidue
  , consumerGraphSnapshotIdentity
  , contentModeProblemDiagnostic
  , makeCompilerGraphResidueDiagnostic
  , makeSourceConsumerGraphDiagnostic
  , problemFindingDiagnostic
  , retainComposedGraphProblemsDiagnostic
  , retainConsumerGraphProblemsDiagnostic
  , residueHaskellSubjects
  , residueRequiredFacts
  , residueSnapshotIdentity
  , roleForAdmittedPath
  , sourceConsumerGraphCheck
  , unboundProblemDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.List (sortOn)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

data ExactCase = ExactCase String [String]

runSourceConsumerGraphInternalOracle :: IO ()
runSourceConsumerGraphInternalOracle =
  finishDiagnostics
    "SourceConsumerGraphInternalOracle"
    ( sourceConsumerGraphInternalSelectorRegistryProblems
        <> concatMap exactCaseProblems sourceConsumerGraphInternalExactCases
    )

runSourceConsumerGraphInternalSelectorOracle :: String -> IO ()
runSourceConsumerGraphInternalSelectorOracle selector =
  finishDiagnostics
    "SourceConsumerGraphInternalOracle selector"
    ( sourceConsumerGraphInternalSelectorRegistryProblems
        <> case selectorExactCases selector of
          [candidate] -> exactCaseProblems candidate
          candidates ->
            [ "selector intent is not exactly resolvable: selector="
                <> selector
                <> "; exact-case-count="
                <> show (length candidates)
            ]
        <> exactCaseProblems selectorUnaffectedControl
    )

runSourceConsumerGraphInternalSelectorControlOracle :: IO ()
runSourceConsumerGraphInternalSelectorControlOracle =
  finishDiagnostics
    "SourceConsumerGraphInternalOracle control"
    ( sourceConsumerGraphInternalSelectorRegistryProblems
        <> exactCaseProblems selectorUnaffectedControl
    )

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless (null problems) (fail (name <> ":\n" <> unlines problems))

exactCaseProblems :: ExactCase -> [String]
exactCaseProblems (ExactCase label problems) =
  [label <> ": " <> problem | problem <- problems]

exactCaseLabel :: ExactCase -> String
exactCaseLabel (ExactCase label _) = label

sourceConsumerGraphInternalSelectorNames :: [String]
sourceConsumerGraphInternalSelectorNames =
  map fst sourceConsumerGraphInternalSelectorIntents

selectorExactCases :: String -> [ExactCase]
selectorExactCases selector =
  [ candidate
  | target <-
      [ label
      | (candidateSelector, label) <- sourceConsumerGraphInternalSelectorIntents
      , candidateSelector == selector
      ]
  , candidate <- sourceConsumerGraphInternalExactCases
  , exactCaseLabel candidate == target
  ]

sourceConsumerGraphInternalSelectorRegistryProblems :: [String]
sourceConsumerGraphInternalSelectorRegistryProblems =
  cardinalityProblems
    <> duplicateSelectorProblems
    <> duplicateExactLabelProblems
    <> unknownTargetProblems
    <> targetMultiplicityProblems
    <> unreferencedExactCaseProblems
 where
  selectors = map fst sourceConsumerGraphInternalSelectorIntents
  targets = map snd sourceConsumerGraphInternalSelectorIntents
  exactLabels = map exactCaseLabel sourceConsumerGraphInternalExactCases
  cardinalityProblems =
    [ "selector registry cardinality changed: expected 288; observed "
        <> show (length selectors)
    | length selectors /= 288
    ]
  duplicateSelectorProblems =
    [ "selector registry contains duplicate identity: " <> selector
    | selector <- duplicates selectors
    ]
  duplicateExactLabelProblems =
    [ "exact-case list contains duplicate label: " <> label
    | label <- duplicates exactLabels
    ]
  unknownTargetProblems =
    [ "selector registry references unknown exact case: selector="
        <> selector
        <> "; label="
        <> target
    | (selector, target) <- sourceConsumerGraphInternalSelectorIntents
    , target `notElem` exactLabels
    ]
  targetMultiplicityProblems =
    [ "selector target is not declared exactly once: selector="
        <> selector
        <> "; label="
        <> target
        <> "; count="
        <> show (length (filter (== target) exactLabels))
    | (selector, target) <- sourceConsumerGraphInternalSelectorIntents
    , length (filter (== target) exactLabels) /= 1
    ]
  unreferencedExactCaseProblems =
    [ "exact-case label is not referenced by any selector: " <> label
    | label <- exactLabels
    , label `notElem` targets
    ]

duplicates :: Ord value => [value] -> [value]
duplicates values =
  Set.toList
    ( snd
        ( foldl
            (\(seen, repeated) value ->
                if value `Set.member` seen
                  then (seen, Set.insert value repeated)
                  else (Set.insert value seen, repeated)
            )
            (Set.empty, Set.empty)
            values
        )
    )

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual =
  [ label <> " mismatch; expected=" <> show expected <> "; actual=" <> show actual
  | actual /= expected
  ]

tracked :: FilePath -> IndexMode -> Text -> TrackedEntry
tracked path mode objectId =
  TrackedEntry
    (IndexEntry path mode objectId)
    ByteString.empty

snapshot :: Text -> [TrackedEntry] -> SourceSnapshot
snapshot identity entries = SourceSnapshot "." identity entries

canonicalIdentity :: Text
canonicalIdentity = "snapshot-alpha"

canonicalSnapshot :: SourceSnapshot
canonicalSnapshot =
  snapshot
    canonicalIdentity
    [ tracked ".dockerignore" RegularFile "object-dockerignore"
    , tracked ".editorconfig" RegularFile "object-editorconfig"
    , tracked ".gitattributes" RegularFile "object-gitattributes"
    , tracked ".gitignore" RegularFile "object-gitignore"
    , tracked "README.md" RegularFile "object-readme"
    , tracked "amoebius.cabal" RegularFile "object-amoebius-cabal"
    , tracked "cabal.project" RegularFile "object-cabal-project"
    , tracked "probe/probe.cabal" RegularFile "object-probe-cabal"
    , tracked "src/A.hs" RegularFile "object-a"
    , tracked "src/B.hs" RegularFile "object-b"
    ]

expectedRequiredFacts :: [RequiredCompilerFact]
expectedRequiredFacts =
  [ CompilerParseSucceeded
  , ConditionalPreprocessingAbsent
  , CompileTimeExecutionFeaturesAbsent
  , ImportsRenamed
  , CallsResolved
  , IndirectCallsClosed
  , ControlFlowClosed
  , FilesystemEffectsClassified
  , ExternalProcessAndFfiEffectsClassified
  , TrackedContentProvenanceFlowsClosed
  , ProductBehaviourSinksClassified
  , DynamicCodeAndPluginLoadingAbsent
  ]

canonicalBindings :: [ContentBinding]
canonicalBindings =
  [ ContentBinding ".dockerignore" DockerIgnoreContract
      [HaskellSourceBoundaryStructureChecker, ContainerContextBuilder]
  , ContentBinding ".editorconfig" EditorConfiguration
      [HaskellSourceBoundaryStructureChecker, EditorTool]
  , ContentBinding ".gitattributes" GitAttributesContract
      [HaskellSourceBoundaryStructureChecker, GitClient]
  , ContentBinding ".gitignore" GitIgnoreContract
      [HaskellSourceBoundaryStructureChecker, GitClient]
  , ContentBinding "README.md" GovernanceDocumentation
      [HumanReader, HaskellSourceBoundaryStructureChecker, HaskellDocumentationStructureChecker]
  , ContentBinding "amoebius.cabal" CabalPackageDescription
      [HaskellSourceBoundaryStructureChecker, HaskellRepositoryRootLocator, CabalBuildTool]
  , ContentBinding "cabal.project" CabalProjectDescription
      [HaskellSourceBoundaryStructureChecker, HaskellRepositoryRootLocator, CabalBuildTool]
  , ContentBinding "probe/probe.cabal" CabalPackageDescription
      [HaskellSourceBoundaryStructureChecker, CabalBuildTool]
  ]

canonicalSubjects :: [HaskellSubject]
canonicalSubjects =
  [ HaskellSubject "src/A.hs" RegularFile "object-a"
  , HaskellSubject "src/B.hs" RegularFile "object-b"
  ]

expectedCheck
  :: Text
  -> [ContentBinding]
  -> [HaskellSubject]
  -> [ConsumerGraphProblem]
  -> CheckResult
expectedCheck identity bindings subjects problems =
  CheckResult
    { checkName = "source-consumer-graph"
    , checkObservations =
        expectedSummaryObservations identity (length bindings) (length subjects)
          <> map expectedBindingObservation bindings
          <> map expectedSubjectObservation subjects
    , checkFindings = map expectedProblemFinding problems
    }

expectedSummaryObservations :: Text -> Int -> Int -> [Observation]
expectedSummaryObservations identity bindingCount subjectCount =
  [ Observation "limit.snapshot-entries" "16384"
  , Observation "limit.resolved-effects" "64"
  , Observation "limit.consumer-graph-problems" "128"
  , Observation "limit.result-observations" "16392"
  , Observation "limit.result-findings" "129"
  , Observation "source-consumer.snapshot" identity
  , Observation "source-consumer.binding-count" (decimal bindingCount)
  , Observation "source-consumer.pending-haskell-count" (decimal subjectCount)
  ]

expectedBindingObservation :: ContentBinding -> Observation
expectedBindingObservation (ContentBinding path role consumers) =
  Observation
    ("source-consumer.binding." <> Text.pack path)
    ( renderRole role
        <> "\t"
        <> Text.intercalate "," (map renderConsumer consumers)
    )

expectedSubjectObservation :: HaskellSubject -> Observation
expectedSubjectObservation (HaskellSubject path mode objectId) =
  Observation
    ("source-consumer.pending-haskell." <> Text.pack path)
    (renderMode mode <> "\t" <> objectId)

expectedProblemFinding :: ConsumerGraphProblem -> Finding
expectedProblemFinding problem = case problem of
  DuplicateContentBinding path ->
    Finding
      "SRC-CONSUMER-DUPLICATE"
      path
      "admitted content received more than one binding"
  UnboundAdmittedContent path sourceClass ->
    Finding
      "SRC-CONSUMER-ROLE-UNBOUND"
      path
      ("no closed content role exists for SourceClosure class " <> renderSourceClass sourceClass)
  NonRegularAdmittedContent path mode ->
    Finding
      "SRC-CONSUMER-CONTENT-MODE"
      path
      ("admitted non-source content is not a regular non-executable file: " <> renderMode mode)
  BehaviouralConsumerAuthorized path consumer ->
    Finding
      "SRC-CONSUMER-BEHAVIOURAL-AUTHORIZATION"
      path
      ("closed role authorized a product-behaviour consumer: " <> renderConsumer consumer)
  EffectTargetIsNotAdmittedContent path ->
    Finding
      "SRC-CONSUMER-EFFECT-TARGET"
      path
      "resolved effect target has no admitted non-source content binding"
  DynamicEffectMayReachTrackedContent modulePath detail ->
    Finding
      "SRC-CONSUMER-DYNAMIC-TARGET"
      modulePath
      ("dynamic effect target may alias tracked non-source content: " <> detail)
  UnresolvedContentEffect modulePath detail ->
    Finding
      "SRC-CONSUMER-UNRESOLVED-EFFECT"
      modulePath
      ("compiler effect target did not resolve: " <> detail)
  UnauthorizedResolvedContentEffect modulePath path use name ->
    Finding
      "SRC-CONSUMER-EFFECT-UNAUTHORIZED"
      modulePath
      ( "resolved consumer "
          <> name
          <> " is not authorized for "
          <> Text.pack path
          <> " as "
          <> renderUse use
      )
  DirectBehaviouralContentConsumption modulePath path name ->
    Finding
      "SRC-CONSUMER-DIRECT-BEHAVIOUR"
      modulePath
      ( "resolved consumer "
          <> name
          <> " treats "
          <> Text.pack path
          <> " as product behaviour"
      )
  EmptyHaskellSubjectInventory ->
    Finding
      "SRC-CONSUMER-EMPTY-HASKELL"
      "."
      "the compiler graph cannot be closed over an empty Haskell subject inventory"
  CompilerDerivedSemanticGraphUnavailable identity count facts ->
    Finding
      "SRC-CONSUMER-COMPILER-GRAPH-UNAVAILABLE"
      "."
      ( "snapshot "
          <> identity
          <> " has "
          <> decimal count
          <> " exact Haskell subjects but lacks compiler-derived facts: "
          <> Text.intercalate "," (map renderFact facts)
      )
  ConsumerGraphResourceLimit resource limit observed ->
    Finding
      "SRC-CONSUMER-RESOURCE-LIMIT"
      (Text.unpack resource)
      ( resource
          <> " exceeds the "
          <> decimal limit
          <> " bound; observed "
          <> decimal observed
      )

renderSourceClass :: SourceClass -> Text
renderSourceClass sourceClass = case sourceClass of
  DocumentationInput -> "DocumentationInput"
  ProjectDeclaration -> "ProjectDeclaration"
  other -> Text.pack (show other)

renderMode :: IndexMode -> Text
renderMode mode = case mode of
  RegularFile -> "100644"
  ExecutableFile -> "100755"
  SymbolicLink -> "120000"

renderRole :: ContentRole -> Text
renderRole role = case role of
  GovernanceDocumentation -> "GovernanceDocumentation"
  CabalPackageDescription -> "CabalPackageDescription"
  CabalProjectDescription -> "CabalProjectDescription"
  GitIgnoreContract -> "GitIgnoreContract"
  DockerIgnoreContract -> "DockerIgnoreContract"
  GitAttributesContract -> "GitAttributesContract"
  EditorConfiguration -> "EditorConfiguration"

renderConsumer :: AuthorizedConsumer -> Text
renderConsumer consumer = case consumer of
  HumanReader -> "HumanReader"
  HaskellSourceBoundaryStructureChecker -> "HaskellSourceBoundaryStructureChecker"
  HaskellDocumentationStructureChecker -> "HaskellDocumentationStructureChecker"
  HaskellRepositoryRootLocator -> "HaskellRepositoryRootLocator"
  CabalBuildTool -> "CabalBuildTool"
  GitClient -> "GitClient"
  ContainerContextBuilder -> "ContainerContextBuilder"
  EditorTool -> "EditorTool"
  HaskellProductRuntime -> "HaskellProductRuntime"

renderUse :: ContentUse -> Text
renderUse use = case use of
  SourceBoundaryStructureInspection -> "SourceBoundaryStructureInspection"
  StructuralDocumentationInspection -> "StructuralDocumentationInspection"
  RepositoryRootSentinel -> "RepositoryRootSentinel"
  ProductBehaviourInput -> "ProductBehaviourInput"

renderFact :: RequiredCompilerFact -> Text
renderFact fact = case fact of
  CompilerParseSucceeded -> "CompilerParseSucceeded"
  ConditionalPreprocessingAbsent -> "ConditionalPreprocessingAbsent"
  CompileTimeExecutionFeaturesAbsent -> "CompileTimeExecutionFeaturesAbsent"
  ImportsRenamed -> "ImportsRenamed"
  CallsResolved -> "CallsResolved"
  IndirectCallsClosed -> "IndirectCallsClosed"
  ControlFlowClosed -> "ControlFlowClosed"
  FilesystemEffectsClassified -> "FilesystemEffectsClassified"
  ExternalProcessAndFfiEffectsClassified -> "ExternalProcessAndFfiEffectsClassified"
  TrackedContentProvenanceFlowsClosed -> "TrackedContentProvenanceFlowsClosed"
  ProductBehaviourSinksClassified -> "ProductBehaviourSinksClassified"
  DynamicCodeAndPluginLoadingAbsent -> "DynamicCodeAndPluginLoadingAbsent"

decimal :: Int -> Text
decimal = Text.pack . show

expectedCompilerProblem
  :: Text
  -> [HaskellSubject]
  -> ConsumerGraphProblem
expectedCompilerProblem identity subjects =
  CompilerDerivedSemanticGraphUnavailable
    identity
    (length subjects)
    expectedRequiredFacts

graphProjectionProblems
  :: String
  -> Text
  -> [ContentBinding]
  -> [HaskellSubject]
  -> [ConsumerGraphProblem]
  -> CompilerGraphResidue
  -> Text
  -> [ContentBinding]
  -> [ConsumerGraphProblem]
  -> [String]
graphProjectionProblems label identity bindings subjects problems residue actualIdentity actualBindings actualProblems =
  expectEqual (label <> " graph identity") identity actualIdentity
    <> expectEqual (label <> " graph bindings") bindings actualBindings
    <> expectEqual (label <> " graph problems") problems actualProblems
    <> expectEqual (label <> " residue identity") identity (residueSnapshotIdentity residue)
    <> expectEqual (label <> " residue subjects") subjects (residueHaskellSubjects residue)
    <> expectEqual (label <> " residue facts") expectedRequiredFacts (residueRequiredFacts residue)

canonicalCaseProblems :: [String]
canonicalCaseProblems =
  graphProjectionProblems
    "canonical"
    canonicalIdentity
    canonicalBindings
    canonicalSubjects
    canonicalProblems
    actualResidue
    (consumerGraphSnapshotIdentity actualGraph)
    (consumerGraphBindings actualGraph)
    (consumerGraphProblems actualGraph)
    <> expectEqual
      "canonical full CheckResult"
      (expectedCheck canonicalIdentity canonicalBindings canonicalSubjects canonicalProblems)
      (sourceConsumerGraphCheck actualGraph)
 where
  canonicalProblems = [expectedCompilerProblem canonicalIdentity canonicalSubjects]
  actualGraph = analyzeSourceConsumerGraph canonicalSnapshot
  actualResidue = consumerGraphResidue actualGraph

selectorUnaffectedControl :: ExactCase
selectorUnaffectedControl =
  ExactCase
    "unaffected SourceClass show control"
    ( expectEqual
        "unaffected SourceClass constructor"
        "HaskellSource"
        (Text.unpack (renderSourceClass HaskellSource))
    )

roleGrammarProblems :: [String]
roleGrammarProblems =
  expectEqual "documentation suffix admitted"
    (Just GovernanceDocumentation)
    (roleForAdmittedPath DocumentationInput "documents/design.md")
    <> expectEqual "documentation non-suffix refused"
      Nothing
      (roleForAdmittedPath DocumentationInput "documents/design.txt")
    <> expectEqual "nested licence exact refused"
      Nothing
      (roleForAdmittedPath DocumentationInput "documents/LiCeNsE")
    <> expectEqual "nested license suffix refused"
      Nothing
      (roleForAdmittedPath DocumentationInput "documents/LICENSE.md")
    <> expectEqual "licence stem refused"
      Nothing
      (roleForAdmittedPath DocumentationInput "LICENCE.notice")
    <> expectEqual "copying stem refused"
      Nothing
      (roleForAdmittedPath DocumentationInput "COPYING.txt")
    <> expectEqual "notice stem refused"
      Nothing
      (roleForAdmittedPath DocumentationInput "NOTICE")
    <> expectEqual "amoebius Cabal role"
      (Just CabalPackageDescription)
      (roleForAdmittedPath ProjectDeclaration "amoebius.cabal")
    <> expectEqual "probe Cabal role"
      (Just CabalPackageDescription)
      (roleForAdmittedPath ProjectDeclaration "probe/probe.cabal")
    <> expectEqual "Cabal project role"
      (Just CabalProjectDescription)
      (roleForAdmittedPath ProjectDeclaration "cabal.project")
    <> expectEqual "gitignore role"
      (Just GitIgnoreContract)
      (roleForAdmittedPath ProjectDeclaration ".gitignore")
    <> expectEqual "dockerignore role"
      (Just DockerIgnoreContract)
      (roleForAdmittedPath ProjectDeclaration ".dockerignore")
    <> expectEqual "gitattributes role"
      (Just GitAttributesContract)
      (roleForAdmittedPath ProjectDeclaration ".gitattributes")
    <> expectEqual "editorconfig role"
      (Just EditorConfiguration)
      (roleForAdmittedPath ProjectDeclaration ".editorconfig")
    <> expectEqual "unknown project declaration refused"
      Nothing
      (roleForAdmittedPath ProjectDeclaration "unknown.project")
    <> expectEqual "non-admitted class refused"
      Nothing
      (roleForAdmittedPath HaskellSource "src/A.hs")

contentModeCaseProblems :: [String]
contentModeCaseProblems =
  expectEqual
    "regular content mode accepted"
    (True, NonRegularAdmittedContent "README.md" RegularFile)
    (contentModeProblemDiagnostic "README.md" RegularFile)
    <> expectEqual
      "executable content mode refused and mapped"
      (False, NonRegularAdmittedContent "README.md" ExecutableFile)
      (contentModeProblemDiagnostic "README.md" ExecutableFile)
    <> expectEqual
      "symlink content mode refused and mapped"
      (False, NonRegularAdmittedContent "README.md" SymbolicLink)
      (contentModeProblemDiagnostic "README.md" SymbolicLink)

emptyCaseProblems :: [String]
emptyCaseProblems =
  graphProjectionProblems
    "empty snapshot"
    "empty-snapshot"
    []
    []
    expectedProblems
    actualResidue
    (consumerGraphSnapshotIdentity actualGraph)
    (consumerGraphBindings actualGraph)
    (consumerGraphProblems actualGraph)
    <> expectEqual
      "empty snapshot full CheckResult"
      (expectedCheck "empty-snapshot" [] [] expectedProblems)
      (sourceConsumerGraphCheck actualGraph)
 where
  expectedProblems =
    [ EmptyHaskellSubjectInventory
    , expectedCompilerProblem "empty-snapshot" []
    ]
  actualGraph = analyzeSourceConsumerGraph (snapshot "empty-snapshot" [])
  actualResidue = consumerGraphResidue actualGraph

unboundCaseProblems :: [String]
unboundCaseProblems =
  expectEqual
    "unbound documentation problem fields"
    (UnboundAdmittedContent "LICENSE.md" DocumentationInput)
    (unboundProblemDiagnostic "LICENSE.md" DocumentationInput)
    <> expectEqual
      "unbound project problem fields"
      (UnboundAdmittedContent "unknown.project" ProjectDeclaration)
      (unboundProblemDiagnostic "unknown.project" ProjectDeclaration)

duplicateCaseProblems :: [String]
duplicateCaseProblems =
  graphProjectionProblems
    "duplicate snapshot"
    "duplicate-snapshot"
    expectedBindings
    expectedSubjects
    expectedProblems
    actualResidue
    (consumerGraphSnapshotIdentity actualGraph)
    (consumerGraphBindings actualGraph)
    (consumerGraphProblems actualGraph)
    <> expectEqual
      "duplicate snapshot full CheckResult"
      (expectedCheck "duplicate-snapshot" expectedBindings expectedSubjects expectedProblems)
      (sourceConsumerGraphCheck actualGraph)
 where
  readmeBinding =
    ContentBinding "README.md" GovernanceDocumentation
      [HumanReader, HaskellSourceBoundaryStructureChecker, HaskellDocumentationStructureChecker]
  agentsBinding =
    ContentBinding "AGENTS.md" GovernanceDocumentation
      [HumanReader, HaskellSourceBoundaryStructureChecker, HaskellDocumentationStructureChecker]
  expectedBindings = [agentsBinding, agentsBinding, readmeBinding, readmeBinding]
  expectedSubjects = [HaskellSubject "src/A.hs" RegularFile "object-a"]
  expectedProblems =
    [ DuplicateContentBinding "AGENTS.md"
    , DuplicateContentBinding "README.md"
    , expectedCompilerProblem "duplicate-snapshot" expectedSubjects
    ]
  actualGraph =
    analyzeSourceConsumerGraph
      ( snapshot
          "duplicate-snapshot"
          [ tracked "README.md" RegularFile "object-readme-1"
          , tracked "README.md" RegularFile "object-readme-2"
          , tracked "AGENTS.md" RegularFile "object-agents-1"
          , tracked "AGENTS.md" RegularFile "object-agents-2"
          , tracked "src/A.hs" RegularFile "object-a"
          ]
      )
  actualResidue = consumerGraphResidue actualGraph

effect
  :: FilePath
  -> Text
  -> Text
  -> ResolvedEffectTarget
  -> ContentUse
  -> ResolvedContentEffect
effect = ResolvedContentEffect

sourceReader :: ResolvedEffectTarget -> ResolvedContentEffect
sourceReader target =
  effect
    "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
    "Amoebius.Validation.SourceClosure.Internal"
    "classifyEntry"
    target
    SourceBoundaryStructureInspection

documentationReader :: ResolvedEffectTarget -> ResolvedContentEffect
documentationReader target =
  effect
    "src/validation-kernel/Amoebius/Validation/Documentation.hs"
    "Amoebius.Validation.Documentation"
    "readDocument"
    target
    StructuralDocumentationInspection

rootReader :: ResolvedEffectTarget -> ResolvedContentEffect
rootReader target =
  effect
    "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
    "Amoebius.Validation.Dispatch"
    "discoverRepositoryRoot"
    target
    RepositoryRootSentinel

effectRoutingCaseProblems :: [String]
effectRoutingCaseProblems =
  expectEqual
    "all exact effect routes"
    expectedProblems
    (auditResolvedEffects canonicalSnapshot routingEffects)
 where
  routingEffects =
    [ sourceReader (ExactTrackedContent "README.md")
    , documentationReader (ExactTrackedContent "README.md")
    , rootReader (ExactTrackedContent "amoebius.cabal")
    , rootReader (ExactTrackedContent "cabal.project")
    , effect
        "wrong/source/path.hs"
        "Amoebius.Validation.SourceClosure.Internal"
        "classifyEntry"
        (ExactTrackedContent "README.md")
        SourceBoundaryStructureInspection
    , effect
        "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
        "Wrong.Source.Module"
        "classifyEntry"
        (ExactTrackedContent "README.md")
        SourceBoundaryStructureInspection
    , effect
        "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
        "Amoebius.Validation.SourceClosure.Internal"
        "wrongBinding"
        (ExactTrackedContent "README.md")
        SourceBoundaryStructureInspection
    , effect
        "wrong/documentation/path.hs"
        "Amoebius.Validation.Documentation"
        "readDocument"
        (ExactTrackedContent "README.md")
        StructuralDocumentationInspection
    , effect
        "src/validation-kernel/Amoebius/Validation/Documentation.hs"
        "Wrong.Documentation.Module"
        "readDocument"
        (ExactTrackedContent "README.md")
        StructuralDocumentationInspection
    , effect
        "src/validation-kernel/Amoebius/Validation/Documentation.hs"
        "Amoebius.Validation.Documentation"
        "wrongBinding"
        (ExactTrackedContent "README.md")
        StructuralDocumentationInspection
    , documentationReader (ExactTrackedContent ".gitignore")
    , effect
        "wrong/root/path.hs"
        "Amoebius.Validation.Dispatch"
        "discoverRepositoryRoot"
        (ExactTrackedContent "amoebius.cabal")
        RepositoryRootSentinel
    , effect
        "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
        "Wrong.Root.Module"
        "discoverRepositoryRoot"
        (ExactTrackedContent "amoebius.cabal")
        RepositoryRootSentinel
    , effect
        "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
        "Amoebius.Validation.Dispatch"
        "wrongBinding"
        (ExactTrackedContent "amoebius.cabal")
        RepositoryRootSentinel
    , rootReader (ExactTrackedContent "probe/probe.cabal")
    , sourceReader (ExactTrackedContent "missing.md")
    , effect
        "src/Dynamic.hs"
        "Dynamic.Module"
        "dynamicRead"
        (DynamicContentTarget "runtime path")
        SourceBoundaryStructureInspection
    , effect
        "src/Unresolved.hs"
        "Unresolved.Module"
        "unresolvedRead"
        (UnresolvedContentTarget "unknown call target")
        SourceBoundaryStructureInspection
    , effect
        "src/Product.hs"
        "Product.Module"
        "loadPolicy"
        (ExactTrackedContent "README.md")
        ProductBehaviourInput
    ]
  expectedProblems =
    [ UnauthorizedResolvedContentEffect
        "wrong/source/path.hs"
        "README.md"
        SourceBoundaryStructureInspection
        "Amoebius.Validation.SourceClosure.Internal.classifyEntry"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
        "README.md"
        SourceBoundaryStructureInspection
        "Wrong.Source.Module.classifyEntry"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
        "README.md"
        SourceBoundaryStructureInspection
        "Amoebius.Validation.SourceClosure.Internal.wrongBinding"
    , UnauthorizedResolvedContentEffect
        "wrong/documentation/path.hs"
        "README.md"
        StructuralDocumentationInspection
        "Amoebius.Validation.Documentation.readDocument"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/Documentation.hs"
        "README.md"
        StructuralDocumentationInspection
        "Wrong.Documentation.Module.readDocument"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/Documentation.hs"
        "README.md"
        StructuralDocumentationInspection
        "Amoebius.Validation.Documentation.wrongBinding"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/Documentation.hs"
        ".gitignore"
        StructuralDocumentationInspection
        "Amoebius.Validation.Documentation.readDocument"
    , UnauthorizedResolvedContentEffect
        "wrong/root/path.hs"
        "amoebius.cabal"
        RepositoryRootSentinel
        "Amoebius.Validation.Dispatch.discoverRepositoryRoot"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
        "amoebius.cabal"
        RepositoryRootSentinel
        "Wrong.Root.Module.discoverRepositoryRoot"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
        "amoebius.cabal"
        RepositoryRootSentinel
        "Amoebius.Validation.Dispatch.wrongBinding"
    , UnauthorizedResolvedContentEffect
        "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
        "probe/probe.cabal"
        RepositoryRootSentinel
        "Amoebius.Validation.Dispatch.discoverRepositoryRoot"
    , EffectTargetIsNotAdmittedContent "missing.md"
    , DynamicEffectMayReachTrackedContent "src/Dynamic.hs" "runtime path"
    , UnresolvedContentEffect "src/Unresolved.hs" "unknown call target"
    , DirectBehaviouralContentConsumption
        "src/Product.hs"
        "README.md"
        "Product.Module.loadPolicy"
    ]

effectLimitCaseProblems :: [String]
effectLimitCaseProblems =
  expectEqual
    "64 effects exact maximum"
    expected64
    (auditResolvedEffects canonicalSnapshot effects64)
    <> expectEqual
      "65 effects bounded refusal"
      [ConsumerGraphResourceLimit "resolved-effects" 64 65]
      (auditResolvedEffects canonicalSnapshot effects65)
 where
  effects64 = map dynamicEffect [0 .. 63]
  effects65 = map dynamicEffect [0 .. 64]
  dynamicEffect index =
    effect
      ("src/Dynamic" <> show index <> ".hs")
      "Dynamic.Module"
      "dynamicRead"
      (DynamicContentTarget ("runtime-" <> decimal index))
      SourceBoundaryStructureInspection
  expected64 =
    [ DynamicEffectMayReachTrackedContent
        ("src/Dynamic" <> show index <> ".hs")
        ("runtime-" <> decimal index)
    | index <- [0 .. 63]
    ]

compositionCaseProblems :: [String]
compositionCaseProblems =
  graphProjectionProblems
    "resolved-effect composition"
    canonicalIdentity
    canonicalBindings
    canonicalSubjects
    expectedProblems
    actualResidue
    (consumerGraphSnapshotIdentity actualGraph)
    (consumerGraphBindings actualGraph)
    (consumerGraphProblems actualGraph)
    <> expectEqual
      "resolved-effect composition full CheckResult"
      (expectedCheck canonicalIdentity canonicalBindings canonicalSubjects expectedProblems)
      (sourceConsumerGraphCheck actualGraph)
 where
  effects =
    [ effect
        "src/Dynamic.hs"
        "Dynamic.Module"
        "dynamicRead"
        (DynamicContentTarget "runtime path")
        SourceBoundaryStructureInspection
    , effect
        "src/Unresolved.hs"
        "Unresolved.Module"
        "unresolvedRead"
        (UnresolvedContentTarget "unknown call target")
        SourceBoundaryStructureInspection
    ]
  expectedProblems =
    [ DynamicEffectMayReachTrackedContent "src/Dynamic.hs" "runtime path"
    , UnresolvedContentEffect "src/Unresolved.hs" "unknown call target"
    , expectedCompilerProblem canonicalIdentity canonicalSubjects
    ]
  actualGraph = analyzeSourceConsumerGraphWithResolvedEffects canonicalSnapshot effects
  actualResidue = consumerGraphResidue actualGraph

problemLimitCaseProblems :: [String]
problemLimitCaseProblems =
  expectEqual
    "128 variable problems exact maximum"
    (variable128 <> mandatory)
    (retainConsumerGraphProblemsDiagnostic variable128 mandatory)
    <> expectEqual
      "129 variable problems bounded refusal"
      [ ConsumerGraphResourceLimit "consumer-graph-problems" 128 129
      , mandatoryProblem
      ]
      (retainConsumerGraphProblemsDiagnostic variable129 mandatory)
 where
  variable128 =
    [ DuplicateContentBinding ("variable-" <> show index)
    | index <- ([0 .. 127] :: [Int])
    ]
  variable129 =
    [ DuplicateContentBinding ("variable-" <> show index)
    | index <- ([0 .. 128] :: [Int])
    ]
  mandatoryProblem = expectedCompilerProblem "problem-retention" []
  mandatory = [mandatoryProblem]

compositionSaturationCaseProblems :: [String]
compositionSaturationCaseProblems =
  expectEqual
    "composition saturation retains the mandatory residue"
    [ ConsumerGraphResourceLimit "consumer-graph-problems" 128 129
    , mandatoryProblem
    ]
    (retainComposedGraphProblemsDiagnostic inputProblems)
 where
  variable128 =
    [ DuplicateContentBinding ("variable-" <> show index)
    | index <- ([0 .. 127] :: [Int])
    ]
  mandatoryProblem = expectedCompilerProblem "composition-saturation" []
  extraProblem = DynamicEffectMayReachTrackedContent "src/Dynamic.hs" "runtime path"
  inputProblems = variable128 <> [mandatoryProblem, extraProblem]

haskellInventory :: Int -> Text -> SourceSnapshot
haskellInventory entryCount identity =
  snapshot
    identity
    [ tracked
        ("src/Subject" <> show index <> ".hs")
        RegularFile
        ("object-" <> decimal index)
    | index <- [0 .. entryCount - 1]
    ]

haskellInventorySubjects :: Int -> [HaskellSubject]
haskellInventorySubjects entryCount =
  sortOn haskellSubjectPath
    [ HaskellSubject
        ("src/Subject" <> show index <> ".hs")
        RegularFile
        ("object-" <> decimal index)
    | index <- [0 .. entryCount - 1]
    ]

snapshotLimitCaseProblems :: [String]
snapshotLimitCaseProblems =
  graphProjectionProblems
    "16384 snapshot entries exact maximum"
    "snapshot-16384"
    []
    subjects16384
    problems16384
    residue16384
    (consumerGraphSnapshotIdentity graph16384)
    (consumerGraphBindings graph16384)
    (consumerGraphProblems graph16384)
    <> expectEqual
      "16384 observations payload exact maximum full CheckResult"
      (expectedCheck "snapshot-16384" [] subjects16384 problems16384)
      (sourceConsumerGraphCheck graph16384)
    <> graphProjectionProblems
      "16385 snapshot entries bounded refusal"
      "snapshot-16385"
      []
      []
      problems16385
      residue16385
      (consumerGraphSnapshotIdentity graph16385)
      (consumerGraphBindings graph16385)
      (consumerGraphProblems graph16385)
    <> expectEqual
      "16385 snapshot entries bounded full CheckResult"
      (expectedCheck "snapshot-16385" [] [] problems16385)
      (sourceConsumerGraphCheck graph16385)
 where
  subjects16384 = haskellInventorySubjects 16384
  problems16384 = [expectedCompilerProblem "snapshot-16384" subjects16384]
  graph16384 = analyzeSourceConsumerGraph (haskellInventory 16384 "snapshot-16384")
  residue16384 = consumerGraphResidue graph16384
  problems16385 =
    [ ConsumerGraphResourceLimit "snapshot-entries" 16384 16385
    , EmptyHaskellSubjectInventory
    , expectedCompilerProblem "snapshot-16385" []
    ]
  graph16385 = analyzeSourceConsumerGraph (haskellInventory 16385 "snapshot-16385")
  residue16385 = consumerGraphResidue graph16385

observationOverflowCaseProblems :: [String]
observationOverflowCaseProblems =
  expectEqual
    "16393 candidate observations bounded full CheckResult"
    expectedResult
    (sourceConsumerGraphCheck actualGraph)
 where
  bindings =
    [ ContentBinding
        ("generated/binding-" <> show index)
        GovernanceDocumentation
        [HaskellSourceBoundaryStructureChecker]
    | index <- ([0 .. 16384] :: [Int])
    ]
  residue =
    makeCompilerGraphResidueDiagnostic
      "observation-overflow"
      []
      expectedRequiredFacts
  compilerProblem = expectedCompilerProblem "observation-overflow" []
  actualGraph =
    makeSourceConsumerGraphDiagnostic
      "observation-overflow"
      bindings
      residue
      [compilerProblem]
  expectedResult =
    CheckResult
      { checkName = "source-consumer-graph"
      , checkObservations = expectedSummaryObservations "observation-overflow" 16385 0
      , checkFindings =
          [ expectedProblemFinding compilerProblem
          , expectedProblemFinding
              (ConsumerGraphResourceLimit "result-observations" 16392 16393)
          ]
      }

findingLimitCaseProblems :: [String]
findingLimitCaseProblems =
  expectEqual
    "129 findings exact maximum"
    (expectedCheck "findings-129" [] [] exactProblems)
    (sourceConsumerGraphCheck exactGraph)
    <> expectEqual
      "130 findings bounded refusal"
      boundedExpected
      (sourceConsumerGraphCheck exceededGraph)
 where
  residue129 =
    makeCompilerGraphResidueDiagnostic "findings-129" [] expectedRequiredFacts
  compiler129 = expectedCompilerProblem "findings-129" []
  exactProblems =
    [ DuplicateContentBinding ("problem-" <> show index)
    | index <- ([0 .. 127] :: [Int])
    ]
      <> [compiler129]
  exactGraph =
    makeSourceConsumerGraphDiagnostic
      "findings-129"
      []
      residue129
      exactProblems
  residue130 =
    makeCompilerGraphResidueDiagnostic "findings-130" [] expectedRequiredFacts
  compiler130 = expectedCompilerProblem "findings-130" []
  exceededProblems =
    [ DuplicateContentBinding ("problem-" <> show index)
    | index <- ([0 .. 128] :: [Int])
    ]
      <> [compiler130]
  exceededGraph =
    makeSourceConsumerGraphDiagnostic
      "findings-130"
      []
      residue130
      exceededProblems
  boundedExpected =
    CheckResult
      { checkName = "source-consumer-graph"
      , checkObservations = expectedSummaryObservations "findings-130" 0 0
      , checkFindings =
          [ expectedProblemFinding
              (ConsumerGraphResourceLimit "result-findings" 129 130)
          , expectedProblemFinding compiler130
          ]
      }

problemRenderingCaseProblems :: [String]
problemRenderingCaseProblems =
  expectEqual
    "every closed problem renders every finding field"
    (map expectedProblemFinding renderingProblems)
    (map problemFindingDiagnostic renderingProblems)
 where
  renderingProblems =
    [ DuplicateContentBinding "duplicate.md"
    , UnboundAdmittedContent "unbound-doc.md" DocumentationInput
    , UnboundAdmittedContent "unbound-project" ProjectDeclaration
    , NonRegularAdmittedContent "executable.md" ExecutableFile
    , NonRegularAdmittedContent "symlink.md" SymbolicLink
    , BehaviouralConsumerAuthorized "runtime.md" HaskellProductRuntime
    , EffectTargetIsNotAdmittedContent "missing.md"
    , DynamicEffectMayReachTrackedContent "src/Dynamic.hs" "dynamic detail"
    , UnresolvedContentEffect "src/Unresolved.hs" "unresolved detail"
    , UnauthorizedResolvedContentEffect
        "src/SourceUse.hs"
        "README.md"
        SourceBoundaryStructureInspection
        "Source.Module.read"
    , UnauthorizedResolvedContentEffect
        "src/DocumentationUse.hs"
        "README.md"
        StructuralDocumentationInspection
        "Documentation.Module.read"
    , UnauthorizedResolvedContentEffect
        "src/RootUse.hs"
        "amoebius.cabal"
        RepositoryRootSentinel
        "Root.Module.read"
    , UnauthorizedResolvedContentEffect
        "src/ProductUse.hs"
        "README.md"
        ProductBehaviourInput
        "Product.Module.read"
    , DirectBehaviouralContentConsumption
        "src/Product.hs"
        "README.md"
        "Product.Module.load"
    , EmptyHaskellSubjectInventory
    , CompilerDerivedSemanticGraphUnavailable
        "render-snapshot"
        2
        expectedRequiredFacts
    , ConsumerGraphResourceLimit "render-resource" 17 18
    ]

bindingInvariantCaseProblems :: [String]
bindingInvariantCaseProblems =
  expectEqual
    "product runtime binding invariant"
    [BehaviouralConsumerAuthorized "runtime.md" HaskellProductRuntime]
    ( bindingInvariantProblemsDiagnostic
        [ ContentBinding
            "runtime.md"
            GovernanceDocumentation
            [HaskellProductRuntime]
        ]
    )

sourceConsumerGraphInternalExactCases :: [ExactCase]
sourceConsumerGraphInternalExactCases =
  [ ExactCase "canonical Internal graph and full result" canonicalCaseProblems
  , ExactCase "closed role grammar" roleGrammarProblems
  , ExactCase "content mode acceptance and refusal" contentModeCaseProblems
  , ExactCase "empty Haskell inventory" emptyCaseProblems
  , ExactCase "unbound admitted content" unboundCaseProblems
  , ExactCase "duplicate bindings and analysis order" duplicateCaseProblems
  , ExactCase "all resolved-effect routes" effectRoutingCaseProblems
  , ExactCase "resolved-effect maximum and refusal" effectLimitCaseProblems
  , ExactCase "resolved-effect composition" compositionCaseProblems
  , ExactCase "problem maximum and refusal" problemLimitCaseProblems
  , ExactCase "composition saturation retains residue" compositionSaturationCaseProblems
  , ExactCase "snapshot and observation maximum/refusal" snapshotLimitCaseProblems
  , ExactCase "result observation overflow" observationOverflowCaseProblems
  , ExactCase "result finding maximum/refusal" findingLimitCaseProblems
  , ExactCase "all problem finding mappings" problemRenderingCaseProblems
  , ExactCase "behavioural authorization invariant" bindingInvariantCaseProblems
  ]

sourceConsumerGraphInternalSelectorIntents :: [(String, String)]
sourceConsumerGraphInternalSelectorIntents =
  [ ( "VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_BYPASS_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_BUILD_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_CONSUMER_ROUTE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_ROOT_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_ROOT_PATH_ALTERNATIVE_DROP_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ANALYSIS_PROBLEM_ORDER_MUTANT"
    , "duplicate bindings and analysis order"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AUDIT_PROBLEM_ORDER_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_AUTHORIZED_CONSUMER_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_AUTHORIZATION_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_AUTHORIZATION_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_AUTHORIZATION_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_CONSUMER_FIELD_MAPPING_MUTANT"
    , "behavioural authorization invariant"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_INVARIANT_BYPASS_MUTANT"
    , "behavioural authorization invariant"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_PATH_FIELD_MAPPING_MUTANT"
    , "behavioural authorization invariant"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_CONSUMERS_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_CONSUMER_SEPARATOR_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_PATH_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_PREFIX_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_ROLE_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_SEPARATOR_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_PATH_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_ROLE_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_BUILD_TOOL_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PACKAGE_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_BUILD_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_ROOT_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_ROOT_PATH_ALTERNATIVE_DROP_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CALLS_RESOLVED_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CALLS_RESOLVED_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CALLS_RESOLVED_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMMON_SOURCE_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_COUNT_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_FACTS_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_GRAPH_UNAVAILABLE_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_GRAPH_UNAVAILABLE_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_GRAPH_UNAVAILABLE_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_IDENTITY_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PARSE_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PARSE_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PARSE_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PROBLEM_COUNT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PROBLEM_FACT_SEPARATOR_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PROBLEM_IDENTITY_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILE_TIME_EXECUTION_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILE_TIME_EXECUTION_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILE_TIME_EXECUTION_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_BASE_PROBLEM_CARRIER_DROP_MUTANT"
    , "resolved-effect composition"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_BINDING_CARRIER_DROP_MUTANT"
    , "resolved-effect composition"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_EFFECT_PROBLEM_CARRIER_DROP_MUTANT"
    , "resolved-effect composition"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_IDENTITY_MAPPING_MUTANT"
    , "resolved-effect composition"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_PROBLEM_ORDER_MUTANT"
    , "resolved-effect composition"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_RESIDUE_MAPPING_MUTANT"
    , "resolved-effect composition"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONDITIONAL_PREPROCESSING_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONDITIONAL_PREPROCESSING_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONDITIONAL_PREPROCESSING_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTAINER_CONTEXT_BUILDER_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_MODE_FIELD_MAPPING_MUTANT"
    , "content mode acceptance and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_PATH_FIELD_MAPPING_MUTANT"
    , "content mode acceptance and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTROL_FLOW_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTROL_FLOW_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTROL_FLOW_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_COPYING_STEM_ALTERNATIVE_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DETAIL_OBSERVATION_COMPOSITION_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_BEHAVIOUR_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_BEHAVIOUR_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_BEHAVIOUR_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_MODULE_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_NAME_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_PROBLEM_NAME_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_PROBLEM_PATH_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCKERIGNORE_BUILDER_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCKERIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCKERIGNORE_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_ACCEPTANCE_REFUSAL_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_BINDING_ROLE_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_CLASS_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_READER_BINDING_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_READER_MODULE_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_READER_PATH_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_SOURCE_CLASS_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_STRUCTURE_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_SUFFIX_BYPASS_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_USE_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_PATH_FIELD_MAPPING_MUTANT"
    , "duplicate bindings and analysis order"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_PROBLEM_BYPASS_MUTANT"
    , "duplicate bindings and analysis order"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_DETAIL_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_LOADING_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_LOADING_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_LOADING_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_MODULE_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_PROBLEM_DETAIL_VALUE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_TARGET_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_TARGET_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_TARGET_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITORCONFIG_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITORCONFIG_TOOL_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITOR_CONFIGURATION_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITOR_TOOL_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_LIMIT_ROUTE_BYPASS_MUTANT"
    , "resolved-effect maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_LIMIT_WIDEN_MUTANT"
    , "resolved-effect maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_BYPASS_MUTANT"
    , "empty Haskell inventory"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EXACT_TARGET_PROBLEM_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EXECUTABLE_MODE_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EXTERNAL_EFFECTS_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EXTERNAL_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_EXTERNAL_EFFECTS_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_FILESYSTEM_EFFECTS_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_FILESYSTEM_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_FILESYSTEM_EFFECTS_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_FINDING_LIMIT_NARROW_MUTANT"
    , "result finding maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_FINDING_LIMIT_ROUTE_BYPASS_MUTANT"
    , "result finding maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GITATTRIBUTES_CLIENT_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GITATTRIBUTES_CONTRACT_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GITATTRIBUTES_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GITIGNORE_CLIENT_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GITIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GITIGNORE_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GIT_CLIENT_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GOVERNANCE_DOCUMENTATION_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GOVERNANCE_DOCUMENTATION_ROLE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GOVERNANCE_HUMAN_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_BINDINGS_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_BINDING_CARRIER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_IDENTITY_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_IDENTITY_PROJECTION_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_PROBLEMS_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_PROBLEM_CARRIER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_RESIDUE_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_RESIDUE_PROJECTION_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_HASKELL_EXTENSION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_HUMAN_READER_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_IMPORTS_RENAMED_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_IMPORTS_RENAMED_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_IMPORTS_RENAMED_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_INDIRECT_CALLS_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_INDIRECT_CALLS_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_INDIRECT_CALLS_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_CASE_NORMALIZATION_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_EXACT_MATCH_ALTERNATIVE_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_FILENAME_MAPPING_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_NAME_REFUSAL_BYPASS_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_SUFFIX_MATCH_ALTERNATIVE_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LICENCE_STEM_ALTERNATIVE_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LICENSE_STEM_ALTERNATIVE_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_EFFECTS_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_EFFECTS_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_EFFECTS_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_PROBLEMS_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_PROBLEMS_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_PROBLEMS_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_FINDINGS_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_FINDINGS_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_FINDINGS_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_SNAPSHOT_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_SNAPSHOT_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_SNAPSHOT_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_MANDATORY_RESIDUE_CLASSIFICATION_BYPASS_MUTANT"
    , "composition saturation retains residue"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_NOTICE_STEM_ALTERNATIVE_DROP_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_OBSERVATION_LIMIT_NARROW_MUTANT"
    , "snapshot and observation maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_OBSERVATION_LIMIT_ROUTE_BYPASS_MUTANT"
    , "result observation overflow"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBE_CABAL_BUILD_CONSUMER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBE_CABAL_ROLE_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBLEM_LIMIT_ROUTE_BYPASS_MUTANT"
    , "problem maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBLEM_LIMIT_WIDEN_MUTANT"
    , "problem maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_BEHAVIOUR_USE_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_RUNTIME_CONSUMER_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_SINKS_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_SINKS_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_SINKS_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROJECT_CLASS_ALTERNATIVE_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROJECT_SOURCE_CLASS_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROVENANCE_FLOWS_FACT_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROVENANCE_FLOWS_FACT_IDENTITY_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_PROVENANCE_FLOWS_FACT_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_REGULAR_MODE_BYPASS_MUTANT"
    , "content mode acceptance and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_REGULAR_MODE_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_REPOSITORY_ROOT_LOCATOR_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_REQUIRED_FACT_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_FACTS_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_FACT_CARRIER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_IDENTITY_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_IDENTITY_PROJECTION_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_SUBJECTS_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_SUBJECT_CARRIER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOLVED_EFFECT_NAME_BINDING_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOLVED_EFFECT_NAME_MODULE_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOLVED_EFFECT_NAME_SEPARATOR_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_LIMIT_FIELD_MAPPING_MUTANT"
    , "resolved-effect maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_NAME_FIELD_MAPPING_MUTANT"
    , "resolved-effect maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_OBSERVED_FIELD_MAPPING_MUTANT"
    , "resolved-effect maximum and refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_PROBLEM_LIMIT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_PROBLEM_NAME_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_PROBLEM_OBSERVED_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_FINDING_CARRIER_DROP_MUTANT"
    , "result finding maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_FINDING_ORDER_MUTANT"
    , "result finding maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_NAME_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_OBSERVATION_CARRIER_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_OBSERVATION_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_PROBLEM_COMPOSITION_ORDER_MUTANT"
    , "result observation overflow"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ROLE_DEFAULT_AUTHORIZATION_MUTANT"
    , "closed role grammar"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_ACCEPTANCE_REFUSAL_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_READER_BINDING_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_READER_MODULE_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_READER_PATH_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_SENTINEL_USE_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SNAPSHOT_LIMIT_ROUTE_BYPASS_MUTANT"
    , "snapshot and observation maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SNAPSHOT_LIMIT_WIDEN_MUTANT"
    , "snapshot and observation maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SNAPSHOT_REFUSAL_EMPTY_HASKELL_DROP_MUTANT"
    , "snapshot and observation maximum/refusal"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_BOUNDARY_ACCEPTANCE_REFUSAL_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_BOUNDARY_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_BOUNDARY_USE_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_READER_BINDING_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_READER_MODULE_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_READER_PATH_CONJUNCT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_MODE_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBJECT_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_MODE_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_OBJECT_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_PATH_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_PREFIX_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_SEPARATOR_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_PATH_FIELD_MAPPING_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_BINDING_COUNT_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_BINDING_COUNT_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_BINDING_COUNT_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_HASKELL_COUNT_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_HASKELL_COUNT_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_HASKELL_COUNT_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_OBSERVATION_ORDER_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_SNAPSHOT_OBSERVATION_DROP_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_SNAPSHOT_OBSERVATION_KEY_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_SNAPSHOT_OBSERVATION_VALUE_MUTANT"
    , "canonical Internal graph and full result"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_SYMLINK_MODE_RENDER_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_EFFECT_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_EFFECT_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_EFFECT_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_MODULE_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_NAME_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_PROBLEM_NAME_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_PROBLEM_PATH_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_TARGET_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_USE_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_CLASS_FIELD_MAPPING_MUTANT"
    , "unbound admitted content"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_PATH_FIELD_MAPPING_MUTANT"
    , "unbound admitted content"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_DETAIL_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_EFFECT_CODE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_EFFECT_DETAIL_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_EFFECT_SUBJECT_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_MODULE_PATH_FIELD_MAPPING_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_PROBLEM_DETAIL_VALUE_MAPPING_MUTANT"
    , "all problem finding mappings"
    )
  , ( "VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_TARGET_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_DIRECT_BEHAVIORAL_EFFECT_BYPASS_MUTANT"
    , "all resolved-effect routes"
    )
  , ( "VALIDATION_SOURCE_ROLE_BEHAVIORAL_AUTHORIZATION_MUTANT"
    , "canonical Internal graph and full result"
    )
  ]
