{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the layout projection. No product package is
-- imported; the allowed classes and refusal tags are literals here.
module Main (main) where

import Control.Exception (SomeException, try)
import Control.Monad (unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeExtension, (</>))
import System.Process (readProcessWithExitCode)

main :: IO ()
main = do
  arguments <- getArgs
  let directory = case arguments of
        [path] -> path
        _ -> ".build/runs/layout-suite"
  expectedPaths <- map Text.unpack . Text.lines <$> TextIO.readFile (directory </> "paths.txt")
  report <- Text.lines <$> TextIO.readFile (directory </> "layout.tsv")
  cases <- parsePairs <$> TextIO.readFile (directory </> "cases.tsv")
  (grantCompilerValid, grantCompilerDetail) <- observeGrantTwin directory
  (methodImportValid, methodImportDetail) <- observeMethodImportTwin directory
  denialObservations <- mapM (observeDeniedConstructor directory) deniedConstructorExpectations
  scopeObservations <- mapM (observeScopeRejection directory) scopeRejectionExpectations
  topologySource <- TextIO.readFile "src/Amoebius/Pulsar/Topology.hs"
  producerSource <- TextIO.readFile "src/Amoebius/Pulsar/Producer.hs"
  topicSource <- TextIO.readFile "src/Amoebius/Pulsar/Internal/Types.hs"
  literalTopicSource <- TextIO.readFile "test/negative/pulsar_client/LiteralTopic.hs"
  rawPayloadSource <- TextIO.readFile "test/negative/pulsar_client/RawPayload.hs"
  familySource <- TextIO.readFile "src/Amoebius/Calculus/Workflow/Obligation.hs"
  foreignSource <- TextIO.readFile "test/fixture/chain_boundary/astcheck/negative_foreign.hs"
  liveGateSource <- TextIO.readFile "test/spec/integration/LiveDslDeployGate.hs"
  challengePaths <- parseChallenges <$> TextIO.readFile (directory </> "challenge-paths.tsv")
  challengeFindings <- mapM (readChallengeFinding directory) challengePaths
  let observedPaths = Map.fromList
        [(Text.unpack path, className) | line <- report, ["path", path, className] <- [Text.splitOn "\t" line]]
      findings = [line | line <- report, "finding\t" `Text.isPrefixOf` line]
      pathSet = Set.fromList expectedPaths
      reportSet = Map.keysSet observedPaths
      graphFiles = Set.fromList [Text.unpack path | line <- report,
        ["graph-file", path, _] <- [Text.splitOn "\t" line]]
      graphModules = Set.fromList [(path, name) | line <- report,
        ["graph-file", path, name] <- [Text.splitOn "\t" line]]
      graphImports = Set.fromList [(path, name) | line <- report,
        ["graph-import", path, name] <- [Text.splitOn "\t" line]]
      graphModuleReexports = Set.fromList [(path, name) | line <- report,
        ["graph-module-reexport", path, name] <- [Text.splitOn "\t" line]]
      graphTopLevel = Set.fromList [(path, name) | line <- report,
        ["graph-top-level", path, name] <- [Text.splitOn "\t" line]]
      graphClassMethods = Set.fromList [(path, className, method) | line <- report,
        ["graph-class-method", path, className, method] <- [Text.splitOn "\t" line]]
      graphClassDeclarations = Set.fromList [(path, className) | line <- report,
        ["graph-class-declaration", path, className] <- [Text.splitOn "\t" line]]
      graphClassDefaults = Set.fromList [(path, className, method) | line <- report,
        ["graph-class-default", path, className, method] <- [Text.splitOn "\t" line]]
      graphClassMethodSignatures = Set.fromList
        [(path, className, method, signature) | line <- report,
         ["graph-class-method-signature", path, className, method, signature]
           <- [Text.splitOn "\t" line]]
      graphClassEffectTypeCandidates = Set.fromList
        [(path, className, method, effect, signature) | line <- report,
         ["graph-class-effect-type-candidate", path, className, method,
          effect, signature] <- [Text.splitOn "\t" line]]
      graphClassSuperclasses = Set.fromList
        [(path, className, superclass) | line <- report,
         ["graph-class-superclass", path, className, superclass]
           <- [Text.splitOn "\t" line]]
      graphInstanceDeclarations = Set.fromList [(path, headText, className) | line <- report,
        ["graph-instance-declaration", path, headText, className] <- [Text.splitOn "\t" line]]
      graphInstanceMethods = Set.fromList [(path, headText, className, method) | line <- report,
        ["graph-instance-method", path, headText, className, method] <- [Text.splitOn "\t" line]]
      graphInstanceSourceContracts = Set.fromList
        [(path, headText, className, method, provider, imported) | line <- report,
         ["graph-instance-method-source-contract", path, headText, className,
          method, provider, imported] <- [Text.splitOn "\t" line]]
      graphInstanceExternalContracts = Set.fromList
        [(path, headText, className, method, imported, package, unit, mode)
        | line <- report,
         ["graph-instance-method-external-contract", path, headText, className,
          method, imported, package, unit, mode] <- [Text.splitOn "\t" line]]
      uncontractedInstanceMethods = graphInstanceMethods `Set.difference`
        Set.fromList ([(path, headText, className, method)
          | (path, headText, className, method, _, _) <-
              Set.toList graphInstanceSourceContracts]
          <> [(path, headText, className, method)
             | (path, headText, className, method, _, _, _, _) <-
                 Set.toList graphInstanceExternalContracts])
      graphTypeSignatures = Set.fromList [(path, name, signature) | line <- report,
        ["graph-type-signature", path, name, signature] <- [Text.splitOn "\t" line]]
      graphEffectTypeCandidates = Set.fromList [(path, name, effect, signature) | line <- report,
        ["graph-effect-type-candidate", path, name, effect, signature] <- [Text.splitOn "\t" line]]
      graphEffectRoutes = Set.fromList [(component, path, owner, effect) | line <- report,
        ["graph-effect-route-candidate", component, path, owner, effect] <- [Text.splitOn "\t" line]]
      graphCallSites = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-call-site", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphLexicalCallSites = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-call-site-lexical", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphOpaqueCallSites = Set.fromList [(component, path, owner, site, target, reason) | line <- report,
        ["graph-call-site-opaque", component, path, owner, site, target, reason] <- [Text.splitOn "\t" line]]
      graphCompilerRejectedCalls = Set.fromList
        [(path, owner, site, target, code, rootSite, sourceDigest) | line <- report,
         ["graph-call-compiler-rejected", path, owner, site, target, code, rootSite, sourceDigest]
           <- [Text.splitOn "\t" line]]
      graphStandaloneLocalCalls = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-call-standalone-local-candidate", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphStandaloneLexicalCalls = Set.fromList [(path, owner, site, target, binderSite) | line <- report,
        ["graph-call-standalone-lexical-candidate", path, owner, site, target, binderSite] <- [Text.splitOn "\t" line]]
      graphStandaloneImportedCalls = Set.fromList [(path, owner, site, target, imported, provider, callee) | line <- report,
        ["graph-call-standalone-imported-candidate", path, owner, site, target,
         imported, provider, callee] <- [Text.splitOn "\t" line]]
      graphStandaloneDeniedSourceCalls = Set.fromList
        [(path, owner, site, target, imported, provider, callee, reason) | line <- report,
         ["graph-call-standalone-source-denied", path, owner, site, target,
          imported, provider, callee, reason] <- [Text.splitOn "\t" line]]
      graphClosedExportRefusals = Set.fromList
        [(path, owner, site, target, imported, provider, callee) | line <- report,
         ["graph-call-standalone-closed-export-refused", path, owner, site,
          target, imported, provider, callee] <- [Text.splitOn "\t" line]]
      rejectedCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- Set.toList graphCompilerRejectedCalls]
      closedExportRefusalKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- Set.toList graphClosedExportRefusals]
      expectedClosedExportRefusals = Set.fromList
        [(path, owner, site, target, imported, provider, target)
        | (path, owner, site, target) <- Set.toList graphCallSites
        , (wantedPath, wantedOwner, wantedTarget, imported, provider) <-
            [("test/negative/pulsar_client/LiteralTopic.hs", "illegal", "Topic",
              "Amoebius.Pulsar.Topology", "src/Amoebius/Pulsar/Topology.hs"),
             ("test/negative/pulsar_client/RawPayload.hs", "illegal", "produceRaw",
              "Amoebius.Pulsar.Producer", "src/Amoebius/Pulsar/Producer.hs")]
        , path == wantedPath, owner == wantedOwner, target == wantedTarget]
      closedExportSourceProof =
        "  ( Topic\n" `Text.isInfixOf` topologySource
          && not ("Topic (..)" `Text.isInfixOf` fst (Text.breakOn ") where" topologySource))
          && "newtype Topic = Topic" `Text.isInfixOf` topicSource
          && "import Amoebius.Pulsar.Internal.Types (Topic (..))" `Text.isInfixOf` topologySource
          && "import Amoebius.Pulsar.Topology (Topic)" `Text.isInfixOf` literalTopicSource
          && "illegal = Topic " `Text.isInfixOf` literalTopicSource
          && "  , produce\n" `Text.isInfixOf` producerSource
          && not ("produceRaw" `Text.isInfixOf` fst (Text.breakOn ") where" producerSource))
          && "import Amoebius.Pulsar.Producer (Producer, produceRaw)" `Text.isInfixOf` rawPayloadSource
          && "produceRaw producer bytes" `Text.isInfixOf` rawPayloadSource
      expectedCompilerRejectedCalls = Set.fromList
        [(path, owner, site, target, "1928", rootSite, sourceDigest)
        | (path, owner, rootTarget, rootSite, sourceDigest, True) <- denialObservations
        , (callPath, callOwner, site, target, _, _, _, _) <-
            Set.toList graphStandaloneDeniedSourceCalls
        , callPath == path, callOwner == owner
        , siteContainedBy site rootSite
        , any (\(source, sourceOwner, rootCallSite, callTarget, _, _, _, _) ->
            source == path && sourceOwner == owner && rootCallSite == rootSite
              && callTarget == rootTarget) (Set.toList graphStandaloneDeniedSourceCalls)]
      expectedScopeRejectedCalls = Set.fromList
        [(path, owner, site, target, Text.pack (show code), rootSite, sourceDigest)
        | (path, owner, rootTarget, rootSite, code, sourceDigest, True) <- scopeObservations
        , (callPath, callOwner, site, target) <- Set.toList graphCallSites
        , callPath == path, callOwner == owner
        , siteContainedBy site rootSite
        , Set.member (path, owner, rootSite, rootTarget) graphCallSites]
      graphStandaloneExternalCalls = Set.fromList [(path, owner, site, target, imported, package, unit, callee) | line <- report,
        ["graph-call-standalone-external-candidate", path, owner, site, target,
         imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphStandaloneRegisteredOnlyCalls = Set.fromList
        [(path, owner, site, target, imported, package, unit, callee) | line <- report,
         ["graph-call-standalone-registered-only-candidate", path, owner, site, target,
          imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphStandaloneExternalMemberCalls = Set.fromList
        [(path, owner, site, target, imported, package, unit, parent, callee) | line <- report,
         ["graph-call-standalone-external-member-candidate", path, owner, site, target,
          imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphExternalCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, callee) | line <- report,
         ["graph-call-external-candidate", component, path, owner, site, target, imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphExternalMemberCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, parent, callee) | line <- report,
         ["graph-call-external-member-candidate", component, path, owner, site, target,
          imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphAvailableCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, callee) | line <- report,
         ["graph-call-available-unit-candidate", component, path, owner, site, target,
          imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphAvailableMemberCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, unit, parent, callee) | line <- report,
         ["graph-call-available-member-candidate", component, path, owner, site, target,
          imported, package, unit, parent, callee] <- [Text.splitOn "\t" line]]
      graphDeferredSeedCallCandidates = Set.fromList
        [(component, path, owner, site, target, imported, package, role, callee) | line <- report,
         ["graph-call-deferred-seed-candidate", component, path, owner, site, target,
          imported, package, role, callee] <- [Text.splitOn "\t" line]]
      graphPreludeCallCandidates = Set.fromList
        [(component, path, owner, site, target, package, unit) | line <- report,
         ["graph-call-prelude-candidate", component, path, owner, site, target, package, unit] <- [Text.splitOn "\t" line]]
      graphAvailablePreludeCallCandidates = Set.fromList
        [(component, path, owner, site, target, package, unit) | line <- report,
         ["graph-call-prelude-available-candidate", component, path, owner, site,
          target, package, unit] <- [Text.splitOn "\t" line]]
      graphStandalonePreludeCallCandidates = Set.fromList
        [(path, owner, site, target, package, unit) | line <- report,
         ["graph-call-prelude-standalone-candidate", path, owner, site,
          target, package, unit] <- [Text.splitOn "\t" line]]
      graphWiredConsCandidates = Set.fromList
        [(component, path, owner, site, target, provider, unit) | line <- report,
         ["graph-call-wired-cons-candidate", component, path, owner, site, target, provider, unit] <- [Text.splitOn "\t" line]]
      graphStandaloneWiredConsCandidates = Set.fromList
        [(path, owner, site, target, provider, unit) | line <- report,
         ["graph-call-standalone-wired-cons-candidate", path, owner, site, target, provider, unit] <- [Text.splitOn "\t" line]]
      graphWiredTupleCandidates = Set.fromList
        [(component, path, owner, site, target, provider, unit) | line <- report,
         ["graph-call-wired-tuple-candidate", component, path, owner, site, target, provider, unit] <- [Text.splitOn "\t" line]]
      graphLexicalBindingCandidates = Set.fromList
        [(component, path, owner, site, target, binderSite) | line <- report,
         ["graph-call-lexical-binding-candidate", component, path, owner, site, target, binderSite] <- [Text.splitOn "\t" line]]
      graphLocalBinders = Set.fromList
        [(path, owner, name, binderSite) | line <- report,
         ["graph-local-binder", path, owner, name, binderSite] <- [Text.splitOn "\t" line]]
      graphParameterBinders = Set.fromList
        [(path, owner, name, binderSite) | line <- report,
         ["graph-parameter-binder", path, owner, name, binderSite] <- [Text.splitOn "\t" line]]
      graphLocalAliases = Set.fromList
        [(path, owner, name, binderSite, target, targetKind) | line <- report,
         ["graph-local-alias", path, owner, name, binderSite, target, targetKind] <- [Text.splitOn "\t" line]]
      graphLexicalAliasRoutes = Set.fromList
        [(component, path, owner, site, binder, binderSite, target, targetKind) | line <- report,
         ["graph-call-lexical-alias-route", component, path, owner, site, binder, binderSite, target, targetKind] <- [Text.splitOn "\t" line]]
      graphAliasInternalCalls = Set.fromList
        [((component, path, owner), (targetComponent, targetPath, callee)) | line <- report,
         ["graph-call-lexical-alias-local-candidate", component, path, owner, _, _, _, targetComponent, targetPath, callee] <- [Text.splitOn "\t" line]]
      graphAliasImportedCalls = Set.fromList
        [(component, path, owner, site, binder, binderSite, target, targetComponent, provider, callee, imported) | line <- report,
         ["graph-call-lexical-alias-imported-candidate", component, path, owner, site, binder, binderSite,
          target, targetComponent, provider, callee, imported] <- [Text.splitOn "\t" line]]
      graphAliasExternalCalls = Set.fromList
        [(component, path, owner, site, binder, binderSite, target, imported, package, unit, callee) | line <- report,
         ["graph-call-lexical-alias-external-candidate", component, path, owner, site, binder, binderSite,
          target, imported, package, unit, callee] <- [Text.splitOn "\t" line]]
      graphReferenceSites = Set.fromList [(path, owner, site, target) | line <- report,
        ["graph-reference-site", path, owner, site, target] <- [Text.splitOn "\t" line]]
      graphControlEdges = Set.fromList [(path, owner, sourceSite, relation, targetSite) | line <- report,
        ["graph-control-edge", path, owner, sourceSite, relation, targetSite] <- [Text.splitOn "\t" line]]
      graphDynamicLoads = Set.fromList [(path, owner, site, kind, target) | line <- report,
        ["graph-dynamic-load", path, owner, site, kind, target] <- [Text.splitOn "\t" line]]
      graphRecordFields = Set.fromList [(path, owner, site, receiver, field) | line <- report,
        ["graph-record-field-site", path, owner, site, receiver, field] <- [Text.splitOn "\t" line]]
      graphRecordProjections = Set.fromList [(path, owner, site, field) | line <- report,
        ["graph-record-projection-site", path, owner, site, field] <- [Text.splitOn "\t" line]]
      graphRecordSelectorCandidates = Set.fromList
        [(component, path, owner, site, kind, field, targetComponent, provider, parent, imported) | line <- report,
         ["graph-record-selector-candidate", component, path, owner, site, kind, field,
          targetComponent, provider, parent, imported] <- [Text.splitOn "\t" line]]
      graphForeignSymbols = Set.fromList [(path, name, kind, target, site) | line <- report,
        ["graph-foreign-symbol", path, name, kind, target, site] <- [Text.splitOn "\t" line]]
      graphForeignSinks = Set.fromList [(path, name, kind, target, site) | line <- report,
        ["graph-effect-sink-foreign", path, name, kind, target, site] <- [Text.splitOn "\t" line]]
      graphTypeFamilies = Set.fromList [(path, name, site, role) | line <- report,
        ["graph-type-family", path, name, site, role] <- [Text.splitOn "\t" line]]
      expectedFamilyStarts = Map.fromList
        [(Text.takeWhile (/= ' ') rest, lineNumber)
        | (lineNumber, line) <- zip [1 :: Int ..] (Text.lines familySource)
        , Just rest <- [Text.stripPrefix "type family " line]]
      graphDerivedInstances = Set.fromList [(path, typeName, className, strategy) | line <- report,
        ["graph-derived-instance", path, typeName, className, strategy] <- [Text.splitOn "\t" line]]
      graphDerivedClassHeads = Set.fromList
        [(path, typeName, className, classHead, strategy) | line <- report,
         ["graph-derived-class-head", path, typeName, className,
          classHead, strategy] <- [Text.splitOn "\t" line]]
      graphDerivedClassMembers = Set.fromList
        [(path, typeName, className, classHead, strategy,
          imported, package, unit, member, mode) | line <- report,
         ["graph-derived-class-member-candidate", path, typeName, className,
          classHead, strategy, imported, package, unit, member, mode] <- [Text.splitOn "\t" line]]
      graphStandaloneDeriving = Set.fromList [(path, instanceType, strategy) | line <- report,
        ["graph-standalone-deriving", path, instanceType, strategy] <- [Text.splitOn "\t" line]]
      graphStandaloneDerivingHeads = Set.fromList
        [(path, instanceType, classHead, strategy) | line <- report,
         ["graph-standalone-deriving-class-head", path, instanceType, classHead, strategy]
           <- [Text.splitOn "\t" line]]
      graphStandaloneDerivingMembers = Set.fromList
        [(path, instanceType, classHead, strategy, imported, package, unit, member, mode)
        | line <- report,
         ["graph-standalone-deriving-member-candidate", path, instanceType, classHead,
          strategy, imported, package, unit, member, mode] <- [Text.splitOn "\t" line]]
      graphData = Set.fromList [(path, name) | line <- report,
        ["graph-data", path, name] <- [Text.splitOn "\t" line]]
      graphDerivedTypes = Set.fromList [path | line <- report,
        ["graph-derived-type", path, _] <- [Text.splitOn "\t" line]]
      graphConstructors = Set.fromList [(path, typeName, name) | line <- report,
        ["graph-constructor", path, typeName, name] <- [Text.splitOn "\t" line]]
      graphSelectors = Set.fromList [(path, typeName, name) | line <- report,
        ["graph-selector", path, typeName, name] <- [Text.splitOn "\t" line]]
      graphComponents = Set.fromList [(path, component) | line <- report,
        ["graph-component", path, component] <- [Text.splitOn "\t" line]]
      graphNoComponents = Set.fromList [path | line <- report,
        ["graph-no-component", path] <- [Text.splitOn "\t" line]]
      componentsByPath = Map.fromListWith (<>)
        [(path, [component]) | (path, component) <- Set.toList graphComponents]
      graphLinks = Set.fromList [(component, consumer, target, provider, name) | line <- report,
        ["graph-link", component, consumer, target, provider, name] <- [Text.splitOn "\t" line]]
      componentLinks = Map.fromListWith Set.union
        [(source, Set.singleton target)
        | (source, _, target, _, _) <- Set.toList graphLinks]
      graphLocalCallCandidates = Set.fromList [(component, consumer, owner, targetComponent, provider, callee) | line <- report,
        ["graph-call-local-candidate", component, consumer, owner, targetComponent, provider, callee] <- [Text.splitOn "\t" line]]
      graphCallCandidates = Set.fromList [(component, consumer, owner, targetComponent, provider, callee, imported) | line <- report,
        ["graph-call-candidate", component, consumer, owner, targetComponent, provider, callee, imported] <- [Text.splitOn "\t" line]]
      graphUniqueInternalCalls = Set.fromList
        [((component, consumer, owner), (targetComponent, provider, callee)) | line <- report,
         ["graph-call-unique-internal", component, consumer, owner, _, _, targetComponent, provider, callee, _] <- [Text.splitOn "\t" line]]
      graphUniqueInternalRows = Set.fromList
        [(component, consumer, owner, site, target, provider, callee) | line <- report,
         ["graph-call-unique-internal", component, consumer, owner, site, target,
          _, provider, callee, _] <- [Text.splitOn "\t" line]]
      graphClassCallDispatchCandidates = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instancePath, headText, className, method) | line <- report,
         ["graph-class-call-dispatch-candidate", component, path, owner, site,
          target, classProvider, instancePath, headText, className, method] <- [Text.splitOn "\t" line]]
      graphClassMethodBodyRoutes = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instanceComponent, instancePath, headText, className, method, methodOwner)
        | line <- report,
         ["graph-class-method-body-potential", component, path, owner, site,
          target, classProvider, instanceComponent, instancePath, headText,
          className, method, methodOwner] <- [Text.splitOn "\t" line]]
      expectedClassCallDispatchCandidates = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instancePath, headText, className, method)
        | (component, path, owner, site, target, classProvider, callee) <- Set.toList graphUniqueInternalRows
        , (instancePath, headText, className, method, provider, _) <- Set.toList graphInstanceSourceContracts
        , classProvider == provider, callee == method]
      expectedClassMethodBodyRoutes = Set.fromList
        [(component, path, owner, site, target, classProvider,
          instanceComponent, instancePath, headText, className, method,
          "instance[" <> headText <> "]." <> method)
        | (component, path, owner, site, target, classProvider,
            instancePath, headText, className, method) <-
            Set.toList graphClassCallDispatchCandidates
        , (memberPath, instanceComponent) <- Set.toList graphComponents
        , memberPath == instancePath
        , instanceComponent `Set.member`
            componentClosureFromLinks componentLinks component]
      graphUniqueCallKeys = Set.fromList [(component, consumer, owner, site, target) | line <- report,
        ["graph-call-unique-internal", component, consumer, owner, site, target, _, _, _, _] <- [Text.splitOn "\t" line]]
      graphAmbiguousCallKeys = Set.fromList [(component, consumer, owner, site, target) | line <- report,
        ["graph-call-ambiguous-internal", component, consumer, owner, site, target, _] <- [Text.splitOn "\t" line]]
      componentCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (path, owner, site, target) <- Set.toList graphCallSites
        , component <- Map.findWithDefault [] path componentsByPath]
      standaloneCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target) <- Set.toList graphCallSites
        , path `Set.member` graphNoComponents]
      standaloneLocalCallKeys = Set.map (\(path, owner, site, target) ->
        ("-", path, owner, site, target)) graphStandaloneLocalCalls
      standaloneLexicalCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _) <- Set.toList graphStandaloneLexicalCalls]
      standaloneImportedCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- Set.toList graphStandaloneImportedCalls]
      standaloneExternalCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _, _) <- Set.toList graphStandaloneExternalCalls]
      standaloneExternalMemberCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _, _, _) <- Set.toList graphStandaloneExternalMemberCalls]
      externalCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- Set.toList graphExternalCallCandidates]
      externalMemberCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _) <- Set.toList graphExternalMemberCallCandidates]
      availableCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- Set.toList graphAvailableCallCandidates]
      availableMemberCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _) <- Set.toList graphAvailableMemberCallCandidates]
      deferredSeedCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- Set.toList graphDeferredSeedCallCandidates]
      preludeCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphPreludeCallCandidates]
      availablePreludeCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphAvailablePreludeCallCandidates]
      standalonePreludeCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _) <- Set.toList graphStandalonePreludeCallCandidates]
      wiredConsCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphWiredConsCandidates]
      standaloneWiredConsCallKeys = Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _) <- Set.toList graphStandaloneWiredConsCandidates]
      wiredTupleCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- Set.toList graphWiredTupleCandidates]
      lexicalBindingCallKeys = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _) <- Set.toList graphLexicalBindingCandidates]
      unattributedCallKeys = (componentCallKeys `Set.union` standaloneCallKeys)
        `Set.difference` Set.unions
          [graphUniqueCallKeys, graphAmbiguousCallKeys,
           standaloneLocalCallKeys, standaloneLexicalCallKeys, standaloneImportedCallKeys,
           standaloneExternalCallKeys, standaloneExternalMemberCallKeys,
           externalCallKeys, externalMemberCallKeys,
           availableCallKeys, availableMemberCallKeys,
           deferredSeedCallKeys,
           preludeCallKeys, availablePreludeCallKeys, standalonePreludeCallKeys,
           wiredConsCallKeys, standaloneWiredConsCallKeys,
           wiredTupleCallKeys, lexicalBindingCallKeys, rejectedCallKeys,
           closedExportRefusalKeys]
      expectedOpaqueCallSites = Set.fromList
        [(component, path, owner, site, target,
           if component == "-" then "standalone"
           else if (path, owner, site, target) `Set.member` graphLexicalCallSites
             then "lexical" else "unattributed")
        | (component, path, owner, site, target) <- Set.toList unattributedCallKeys]
      graphUnresolved = Set.fromList [(component, consumer, name, reason) | line <- report,
        ["graph-import-unresolved", component, consumer, name, reason] <- [Text.splitOn "\t" line]]
      graphExternalImports = Set.fromList [(component, consumer, name, package, unit) | line <- report,
        ["graph-import-external", component, consumer, name, package, unit] <- [Text.splitOn "\t" line]]
      graphImplicitPreludeImports = Set.fromList [(component, consumer, package, unit) | line <- report,
        ["graph-import-implicit-prelude", component, consumer, package, unit] <- [Text.splitOn "\t" line]]
      graphAvailablePreludeImports = Set.fromList [(component, consumer, package, unit) | line <- report,
        ["graph-import-implicit-prelude-available", component, consumer, package, unit] <- [Text.splitOn "\t" line]]
      graphStandalonePreludeImports = Set.fromList [(path, package, unit) | line <- report,
        ["graph-import-implicit-prelude-standalone", path, package, unit] <- [Text.splitOn "\t" line]]
      graphPreludeInterfaces = Set.fromList [(unit, digest, count) | line <- report,
        ["graph-prelude-interface", unit, digest, count] <- [Text.splitOn "\t" line]]
      graphModuleInterfaceRows = [(unit, name, digest, count) | line <- report,
        ["graph-module-interface", unit, name, digest, count] <- [Text.splitOn "\t" line]]
      graphModuleInterfaceMembers = Set.fromList [(unit, name, parent, member) | line <- report,
        ["graph-module-interface-member", unit, name, parent, member] <- [Text.splitOn "\t" line]]
      graphModuleInterfaces = Set.fromList graphModuleInterfaceRows
      graphUnselectedCandidates = Set.fromList [(component, consumer, name, package, unit) | line <- report,
        ["graph-import-unselected-unit-candidate", component, consumer, name, package, unit] <- [Text.splitOn "\t" line]]
      graphAvailableUnits = Set.fromList [(component, consumer, name, package, unit) | line <- report,
        ["graph-import-available-unit", component, consumer, name, package, unit] <- [Text.splitOn "\t" line]]
      graphStandaloneAvailableUnits = Set.fromList [(path, name, package, unit) | line <- report,
        ["graph-import-standalone-available-unit", path, name, package, unit] <- [Text.splitOn "\t" line]]
      graphStandaloneRegisteredOnlyUnits = Set.fromList [(path, name, package, unit) | line <- report,
        ["graph-import-standalone-registered-only-unit", path, name, package, unit]
          <- [Text.splitOn "\t" line]]
      graphForwardOwned = Set.fromList [(component, consumer, name, path, role) | line <- report,
        ["graph-import-forward-owned", component, consumer, name, path, role] <- [Text.splitOn "\t" line]]
      graphDeferredSeed = Set.fromList [(component, consumer, name, package, owner) | line <- report,
        ["graph-import-deferred-seed", component, consumer, name, package, owner] <- [Text.splitOn "\t" line]]
      graphInaccessible = Set.fromList [(component, consumer, name, providerComponent, providerPath) | line <- report,
        ["graph-import-inaccessible-internal", component, consumer, name, providerComponent, providerPath] <- [Text.splitOn "\t" line]]
      graphUnscanned = Set.fromList [(path, owner, tag) | line <- report,
        ["graph-unscanned", path, owner, tag] <- [Text.splitOn "\t" line]]
      graphDeclarationGaps = Set.fromList [(path, tag) | line <- report,
        ["graph-unscanned-declaration", path, tag] <- [Text.splitOn "\t" line]]
      graphStages = [stage | line <- report,
        ["graph-stage", stage] <- [Text.splitOn "\t" line]]
      bootstrapCalls = Set.fromList [(owner, call) | line <- report,
        ["bootstrap-call", owner, call] <- [Text.splitOn "\t" line]]
      bootstrapEffects = Set.fromList [(owner, call) | line <- report,
        ["bootstrap-effect", owner, call] <- [Text.splitOn "\t" line]]
      packageOwed = Set.fromList [(source, role) | line <- report,
        ["package-owed", source, role] <- [Text.splitOn "\t" line]]
      packageBuildDependencies = Set.fromList [(component, package) | line <- report,
        ["package-build-dependency", component, package] <- [Text.splitOn "\t" line]]
      standaloneRows = [(path, role) | line <- report,
        ["package-standalone", path, role] <- [Text.splitOn "\t" line]]
      packageStandalone = Set.fromList standaloneRows
      componentImportKeys = Set.fromList
        [(component, path, name)
        | (path, component) <- Set.toList graphComponents
        , (importPath, name) <- Set.toList graphImports, importPath == path]
      internalImportKeys = Set.map (\(component, consumer, _, _, name) -> (component, consumer, name)) graphLinks
      externalImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphExternalImports
      availableImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphAvailableUnits
      forwardImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphForwardOwned
      deferredImportKeys = Set.map (\(component, consumer, name, _, _) -> (component, consumer, name)) graphDeferredSeed
      unresolvedImportKeys = Set.map (\(component, consumer, name, _) -> (component, consumer, name)) graphUnresolved
      expectedForwardOwned = Set.fromList
        [(component, consumer, name, Text.replace "." "/" name <> ".hs", "generated-proto")
        | (consumer, name) <- Set.toList graphImports
        , (path, component) <- Set.toList graphComponents, path == consumer
        , component == "library:pulsar-client"
        , name `elem` ["Proto.PulsarApi", "Proto.PulsarApi_Fields"]]
      importPartition = componentImportKeys == Set.unions
          [internalImportKeys, externalImportKeys, availableImportKeys,
           forwardImportKeys, deferredImportKeys, unresolvedImportKeys]
        && all (\(left, right) -> Set.null (Set.intersection left right))
          [(internalImportKeys, externalImportKeys), (internalImportKeys, unresolvedImportKeys),
           (internalImportKeys, forwardImportKeys), (externalImportKeys, unresolvedImportKeys),
           (externalImportKeys, forwardImportKeys), (forwardImportKeys, unresolvedImportKeys),
           (availableImportKeys, internalImportKeys), (availableImportKeys, externalImportKeys),
           (availableImportKeys, forwardImportKeys), (availableImportKeys, unresolvedImportKeys),
           (deferredImportKeys, internalImportKeys), (deferredImportKeys, externalImportKeys),
           (deferredImportKeys, availableImportKeys), (deferredImportKeys, forwardImportKeys),
           (deferredImportKeys, unresolvedImportKeys)]
        && all (\(component, _, _, package, unit) ->
             Set.member (component, package) packageBuildDependencies && not (Text.null unit))
          (Set.toList graphExternalImports)
      effectSeeds = Set.fromList
        [(component, path, name) | (path, name, "IO", _) <- Set.toList graphEffectTypeCandidates,
         (componentPath, component) <- Set.toList graphComponents, componentPath == path]
        `Set.union` Set.fromList
        [(component, path, method)
        | (path, _, method, "IO", _) <- Set.toList graphClassEffectTypeCandidates
        , (componentPath, component) <- Set.toList graphComponents
        , componentPath == path]
      aliasImportedTargets = Map.fromListWith Set.union
        [((component, path, owner, site, binder, binderSite, target),
          Set.singleton (targetComponent, provider, callee))
        | (component, path, owner, site, binder, binderSite, target, targetComponent, provider, callee, _) <-
            Set.toList graphAliasImportedCalls]
      aliasUniqueImportedCalls = Set.fromList
        [((component, path, owner), destination)
        | ((component, path, owner, _, _, _, _), destinations) <- Map.toList aliasImportedTargets,
          [destination] <- [Set.toList destinations]]
      expectedEffectRoutes = Set.map (\(component, path, owner) -> (component, path, owner, "IO"))
        (effectRouteClosure (Set.unions [graphUniqueInternalCalls, graphAliasInternalCalls,
          aliasUniqueImportedCalls,
          Set.fromList [((component, path, owner),
            (instanceComponent, instancePath, methodOwner))
          | (component, path, owner, _, _, _, instanceComponent,
             instancePath, _, _, _, methodOwner) <-
              Set.toList graphClassMethodBodyRoutes]]) effectSeeds)
      checks =
        [ ("path-set", pathSet == reportSet, Text.pack (show (Set.size reportSet)))
        , ("finding-set", null findings, Text.pack (show findings))
        , ("case:six-metadata-files", length (filter (`elem` metadata) expectedPaths) == 6, Text.pack (show (filter (`elem` metadata) expectedPaths)))
        , ("challenge-set", Set.fromList [(name, tag) | (name, _, tag) <- challengePaths] == Set.fromList expectedChallengeTags,
           Text.pack (show challengePaths))
        , ("compiler-parsed-source-set", graphFiles == Set.filter ((== ".hs") . takeExtension) pathSet,
           Text.pack (show (Set.size graphFiles)))
        , ("compiler-import-control", Set.member ("src/Amoebius/Layout/SourceGraph.hs", "GHC.Parser") graphImports,
           Text.pack (show (Set.size graphImports)))
        , ("compiler-module-reexport-control", graphModuleReexports == Set.fromList
             [("src/Amoebius/Execution/JobTerminalLive.hs", "Amoebius.Store.ControlPlaneState"),
              ("src/Amoebius/Substrate/Apple.hs", "Amoebius.HostWorker.Capacity"),
              ("src/Amoebius/Substrate/Apple.hs", "Amoebius.Substrate.Lima"),
              ("src/manifest-render/Amoebius/Manifest/K8sObject.hs", "Amoebius.Manifest.Types"),
              ("src/validation-kernel/Amoebius/Validation/StatusFrontier.hs", "Amoebius.Plan.StatusFrontier"),
              ("src/vendor/Pulsar.hs", "Pulsar.Types")],
           Text.pack (show graphModuleReexports))
        , ("compiler-declaration-control", Set.member ("src/Amoebius/Layout/Report.hs", "runLayoutReport") graphTopLevel,
           Text.pack (show (Set.size graphTopLevel)))
        , ("compiler-class-method-control",
             Set.member ("src/Amoebius/Kernel/ContentAddress.hs", "ContentAddress", "contentAddress") graphClassMethods
               && all (\(path, className, method) ->
                    Set.member (Text.unpack path) graphFiles
                      && not (Text.null className) && not (Text.null method))
                 (Set.toList graphClassMethods),
           Text.pack (show (Set.size graphClassMethods)))
        , ("compiler-class-declaration-control",
             graphClassDeclarations == Set.fromList
               [("src/Amoebius/Calculus/Artifact/Recipe.hs", "Declaration"),
                ("src/Amoebius/Kernel/ContentAddress.hs", "ContentAddress"),
                ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination"),
                ("test/layout/ClassEffectRoute.hs", "RouteAction"),
                ("test/layout/ClassEffectRoute.hs", "DirectIoRoute")]
               && graphClassMethodSignatures == Set.fromList
                 [("src/Amoebius/Calculus/Artifact/Recipe.hs", "Declaration",
                   "declarationBytes", "d -> ByteString"),
                  ("src/Amoebius/Kernel/ContentAddress.hs", "ContentAddress",
                   "contentAddress", "a -> BlobSha"),
                  ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination",
                   "registerConnection", "UiRealtimeEnvelope -> operation ()"),
                  ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination",
                   "publishRoutingHint", "UiRealtimeEnvelope -> operation ()"),
                  ("test/layout/ClassEffectRoute.hs", "RouteAction",
                   "runRoute", "a -> Int"),
                  ("test/layout/ClassEffectRoute.hs", "DirectIoRoute",
                   "runDirectIo", "a -> IO Int")]
               && Set.map (\(path, className, method, _) ->
                    (path, className, method)) graphClassMethodSignatures
                    == graphClassMethods
               && graphClassSuperclasses == Set.singleton
                    ("src/Amoebius/Ui/Realtime/Class.hs", "UiRealtimeCoordination",
                     "Monad operation")
               && Set.null graphClassDefaults
               && not (any ((== "ClassDispatch") . snd)
                    (Set.toList graphDeclarationGaps)),
           Text.pack (show (Set.size graphClassDeclarations,
             Set.size graphClassMethodSignatures,
             Set.size graphClassSuperclasses,
             Set.size graphClassDefaults)))
        , ("compiler-class-effect-type-seed-control",
             graphClassEffectTypeCandidates == Set.singleton
               ("test/layout/ClassEffectRoute.hs", "DirectIoRoute",
                "runDirectIo", "IO", "a -> IO Int")
               && Set.member ("test:layout-suite", "test/layout/ClassEffectRoute.hs",
                    "runDirectIo") effectSeeds,
           Text.pack (show (Set.size graphClassEffectTypeCandidates)))
        , ("compiler-instance-declaration-control",
             Set.fromList [path | (path, _, _) <- Set.toList graphInstanceDeclarations]
               == Set.fromList [path | (path, tag) <- Set.toList graphDeclarationGaps,
                 tag == "InstanceDispatch"]
               && Set.member ("src/Amoebius/Calculus/Artifact/Region.hs",
                    "Functor (Region s)", "Functor", "fmap") graphInstanceMethods
               && all (\(path, headText, className, method) ->
                    Set.member (path, headText, className) graphInstanceDeclarations
                      && not (Text.null method)) (Set.toList graphInstanceMethods),
           Text.pack (show (Set.size graphInstanceDeclarations,
             Set.size graphInstanceMethods)))
        , ("compiler-instance-source-contract-control",
             Set.member ("src/Amoebius/Kernel/ContentAddress.hs",
               "ContentAddress ByteString", "ContentAddress", "contentAddress",
               "src/Amoebius/Kernel/ContentAddress.hs", "-") graphInstanceSourceContracts
               && Set.member ("test/spec/calculus/ArtifactCorpus.hs",
                 "Declaration Declared", "Declaration", "declarationBytes",
                 "src/Amoebius/Calculus/Artifact/Recipe.hs",
                 "Amoebius.Calculus.Artifact.Recipe") graphInstanceSourceContracts
               && all (\(path, headText, className, method, provider, imported) ->
                    Set.member (path, headText, className, method) graphInstanceMethods
                      && Set.member (provider, className, method) graphClassMethods
                      && (if imported == "-" then provider == path
                          else Set.member (path, imported) graphImports
                            && Set.member (provider, imported) graphModules
                            && (path `Set.member` graphNoComponents
                              || any (\(_, consumer, _, targetPath, name) ->
                                  consumer == path && targetPath == provider
                                    && name == imported) (Set.toList graphLinks))))
                  (Set.toList graphInstanceSourceContracts),
           Text.pack (show (Set.size graphInstanceSourceContracts)))
        , ("compiler-instance-external-contract-control",
             Set.size graphInstanceExternalContracts == 297
               && Set.null uncontractedInstanceMethods
               && methodImportValid
               && "import Data.Aeson (FromJSON (parseJSON),"
                    `Text.isInfixOf` liveGateSource
               && any (\(path, headText, className, method, imported, package,
                          unit, mode) ->
                    path == "app/amoebius/Amoebius/Entry/ControlPlane.hs"
                      && headText == "FromJSON AdminRequest"
                      && className == "FromJSON" && method == "parseJSON"
                      && imported == "Data.Aeson" && package == "aeson"
                      && not (Text.null unit) && mode == "explicit")
                    (Set.toList graphInstanceExternalContracts)
               && any (\(path, headText, className, method, imported, package, _, mode) ->
                    path == "src/Amoebius/Calculus/Artifact/Region.hs"
                      && headText == "Functor (Region s)" && className == "Functor"
                      && method == "fmap" && imported == "Prelude"
                      && package == "base" && mode == "implicit")
                    (Set.toList graphInstanceExternalContracts)
               && any (\(path, headText, className, method, imported, package, _, mode) ->
                    path == "src/vendor/Pulsar/Types.hs"
                      && headText == "IsString Tenant" && className == "IsString"
                      && method == "fromString" && imported == "Data.String"
                      && package == "base" && mode == "explicit")
                    (Set.toList graphInstanceExternalContracts)
               && any (\(path, headText, className, method, imported, package, _, mode) ->
                    path == "test/spec/capability/BindProps.hs"
                      && headText == "Arbitrary GeneratedNeed"
                      && className == "Arbitrary" && method == "arbitrary"
                      && imported == "Test.QuickCheck" && package == "QuickCheck"
                      && mode == "explicit") (Set.toList graphInstanceExternalContracts)
               && all (\(path, headText, className, method, imported, package,
                           unit, mode) ->
                    Set.member (path, headText, className, method) graphInstanceMethods
                      && Set.member (unit, imported,
                           Text.takeWhileEnd (/= '.') className, method)
                         graphModuleInterfaceMembers
                      && (case mode of
                        "explicit" -> Set.member (path, imported) graphImports
                          && (any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphExternalImports)
                            || Set.member (path, imported, package, unit)
                              graphStandaloneAvailableUnits)
                        "implicit" -> imported == "Prelude"
                          && (any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphImplicitPreludeImports)
                            || Set.member (path, package, unit)
                              graphStandalonePreludeImports)
                        _ -> False)) (Set.toList graphInstanceExternalContracts),
           Text.pack (show (Set.size graphInstanceExternalContracts,
             Set.toAscList uncontractedInstanceMethods, methodImportDetail)))
        , ("compiler-class-call-dispatch-control",
             graphClassCallDispatchCandidates == expectedClassCallDispatchCandidates
               && not (Set.null graphClassCallDispatchCandidates)
               && any (\(component, path, owner, _, target, classProvider,
                         instancePath, headText, className, method) ->
                    component == "library:dsl-core"
                      && path == "src/Amoebius/Kernel/Determinism.hs"
                      && owner == "seededStage" && target == "contentAddress"
                      && classProvider == "src/Amoebius/Kernel/ContentAddress.hs"
                      && instancePath == classProvider
                      && headText == "ContentAddress ByteString"
                      && className == "ContentAddress" && method == "contentAddress")
                  (Set.toList graphClassCallDispatchCandidates),
           Text.pack (show (Set.size graphClassCallDispatchCandidates)))
        , ("compiler-class-method-body-route-control",
             graphClassMethodBodyRoutes == expectedClassMethodBodyRoutes
               && Set.size graphClassMethodBodyRoutes == 6
               && Set.member ("test:layout-suite", "test/layout/ClassEffectRoute.hs",
                    "caller", "17:16-17:30", "runRoute",
                    "test/layout/ClassEffectRoute.hs", "test:layout-suite",
                    "test/layout/ClassEffectRoute.hs", "RouteAction Token",
                    "RouteAction", "runRoute",
                    "instance[RouteAction Token].runRoute") graphClassMethodBodyRoutes
               && not (any (\(_, _, _, _, _, _, _, instancePath, _, _, _, _) ->
                    "test/negative/" `Text.isPrefixOf` instancePath)
                    (Set.toList graphClassMethodBodyRoutes)),
           Text.pack (show (Set.size graphClassMethodBodyRoutes,
             Set.size expectedClassMethodBodyRoutes)))
        , ("compiler-type-signature-control", Set.member
             ("src/Amoebius/Layout/Report.hs", "runLayoutReport", "[String] -> IO ()") graphTypeSignatures,
           Text.pack (show (Set.size graphTypeSignatures)))
        , ("compiler-effect-type-seed-control", Set.member
             ("src/Amoebius/Layout/Report.hs", "runLayoutReport", "IO", "[String] -> IO ()") graphEffectTypeCandidates,
           Text.pack (show (Set.size graphEffectTypeCandidates)))
        , ("compiler-effect-route-closure-control", graphEffectRoutes == expectedEffectRoutes
             && Set.member ("library:layout", "src/Amoebius/Layout/Report.hs",
                  "runLayoutReport", "IO") graphEffectRoutes
             && all (`Set.member` graphEffectRoutes)
                  [("test:layout-suite", "test/layout/ClassEffectRoute.hs", owner, "IO")
                  | owner <- ["effectSeed", "instance[RouteAction Token].runRoute",
                      "caller", "runDirectIo", "directCaller"]],
           Text.pack (show (Set.size graphEffectRoutes, Set.size expectedEffectRoutes)))
        , ("compiler-call-site-control", any
             (\(path, owner, site, target) -> path == "src/Amoebius/Layout/Report.hs"
               && owner == "runLayoutReport" && target == "parseOptions" && site /= "unlocated")
             (Set.toList graphCallSites)
             && all (\(_, _, site, _) -> site /= "unlocated") (Set.toList graphCallSites),
           Text.pack (show (Set.size graphCallSites)))
        , ("compiler-call-site-coverage-control",
             graphOpaqueCallSites == expectedOpaqueCallSites
               && graphLexicalCallSites `Set.isSubsetOf` graphCallSites,
           Text.pack (show (Set.size graphOpaqueCallSites, Set.size expectedOpaqueCallSites)))
        , ("compiler-reference-site-control", any
             (\(path, owner, site, target) -> path == "src/Amoebius/Layout/Report.hs"
               && owner == "runLayoutReport" && target == "parseOptions" && site /= "unlocated")
             (Set.toList graphReferenceSites)
             && all (\(_, _, site, _) -> site /= "unlocated") (Set.toList graphReferenceSites),
           Text.pack (show (Set.size graphReferenceSites)))
        , ("compiler-control-edge-control", any
             (\(path, owner, sourceSite, relation, targetSite) ->
               path == "src/Amoebius/Layout/Report.hs" && owner == "acquirePaths"
                 && relation == "case-scrutinee" && sourceSite /= "unlocated"
                 && targetSite /= "unlocated") (Set.toList graphControlEdges)
             && all (\(_, _, sourceSite, _, targetSite) ->
               sourceSite /= "unlocated" && targetSite /= "unlocated") (Set.toList graphControlEdges),
           Text.pack (show (Set.size graphControlEdges)))
        , ("compiler-dynamic-load-control", graphDynamicLoads == Set.singleton
             ("test/fixture/chain_boundary/astcheck/negative_template_haskell.hs",
              "value", "2:9-2:25", "template-haskell-splice", "generateValue"),
           Text.pack (show graphDynamicLoads))
        , ("compiler-record-field-control",
             not (Set.null graphRecordFields)
               && all (\(path, owner, site, receiver, field) ->
                    Set.member (Text.unpack path) graphFiles
                      && not (Text.null owner) && site /= "unlocated"
                      && receiver /= "unlocated" && not (Text.null field))
                 (Set.toList graphRecordFields)
               && all (\(path, owner, site, field) ->
                    Set.member (Text.unpack path) graphFiles
                      && not (Text.null owner) && site /= "unlocated"
                      && not (Text.null field))
                 (Set.toList graphRecordProjections)
               && all (\(component, path, owner, site, kind, field,
                        targetComponent, provider, parent, imported) ->
                    Set.member (provider, parent, field) graphSelectors
                      && Set.member (path, component) graphComponents
                      && Set.member (provider, targetComponent) graphComponents
                      && (if kind == "get" then any (\(sourcePath, sourceOwner, sourceSite, _, sourceField) ->
                            sourcePath == path && sourceOwner == owner && sourceSite == site
                              && sourceField == field) (Set.toList graphRecordFields)
                          else Set.member (path, owner, site, field) graphRecordProjections)
                      && (imported == "local" && component == targetComponent && path == provider
                        || any (\(sourceComponent, sourcePath, _, _, importName) ->
                            sourceComponent == component && sourcePath == path && importName == imported)
                          (Set.toList graphLinks)))
                 (Set.toList graphRecordSelectorCandidates),
           Text.pack (show (Set.size graphRecordFields, Set.size graphRecordProjections,
             Set.size graphRecordSelectorCandidates)))
        , ("compiler-foreign-boundary-control", graphForeignSymbols == Set.singleton
             ("test/fixture/chain_boundary/astcheck/negative_foreign.hs",
              "foreignValue", "import", "foreign_value", "2:1-2:57")
               && graphForeignSinks == graphForeignSymbols
               && "foreign import ccall \"foreign_value\" foreignValue :: Int"
                    `Text.isInfixOf` foreignSource
               && not (any ((== "Foreign") . snd) (Set.toList graphDeclarationGaps)),
           Text.pack (show (graphForeignSymbols, graphForeignSinks)))
        , ("compiler-type-family-boundary-control",
             Map.keysSet expectedFamilyStarts == Set.fromList
               ["Remove", "Append", "Disjoint", "NotElem"]
               && Set.map (\(path, name, _, role) -> (path, name, role)) graphTypeFamilies
                    == Set.fromList
                      [("src/Amoebius/Calculus/Workflow/Obligation.hs", name,
                        "type-level-only")
                      | name <- ["Remove", "Append", "Disjoint", "NotElem"]]
               && Set.size graphTypeFamilies == 4
               && all (\(_, name, site, _) -> case parseSite site of
                    Just ((line, column), _) ->
                      column == 1 && Map.lookup name expectedFamilyStarts == Just line
                    Nothing -> False) (Set.toList graphTypeFamilies)
               && not (any ((== "TypeFamily") . snd) (Set.toList graphDeclarationGaps)),
           Text.pack (show (Set.size graphTypeFamilies,
             Set.toAscList (Map.keysSet expectedFamilyStarts))))
        , ("compiler-derived-instance-control", all (`Set.member` graphDerivedInstances)
             [("src/Amoebius/Layout/Classify.hs", "PathClass", "Eq", "inferred"),
              ("src/Amoebius/Layout/Classify.hs", "PathClass", "Ord", "inferred"),
              ("src/Amoebius/Layout/Classify.hs", "PathClass", "Show", "inferred")],
           Text.pack (show (Set.size graphDerivedInstances)))
        , ("compiler-derived-class-head-control",
             Set.map (\(path, typeName, className, _, strategy) ->
               (path, typeName, className, strategy)) graphDerivedClassHeads
               == graphDerivedInstances
               && all (\(_, _, className, classHead, _) ->
                    classHead /= "unresolved"
                      && classHead == Text.takeWhile (/= ' ') className)
                  (Set.toList graphDerivedClassHeads)
               && Set.member ("src/vendor/Pulsar/Internal/Core.hs", "Pulsar",
                    "MonadReader PulsarCtx", "MonadReader", "inferred") graphDerivedClassHeads,
           Text.pack (show (Set.size graphDerivedClassHeads)))
        , ("compiler-derived-class-member-control",
             not (Set.null graphDerivedClassMembers)
               && all (\(path, typeName, className, classHead, strategy,
                        imported, package, unit, member, mode) ->
                    Set.member (path, typeName, className, classHead, strategy)
                      graphDerivedClassHeads
                      && Set.member (unit, imported,
                           Text.takeWhileEnd (/= '.') classHead, member)
                        graphModuleInterfaceMembers
                      && (case mode of
                        "explicit" -> Set.member (path, imported) graphImports
                          && (any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphExternalImports)
                            || any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailableUnits)
                            || Set.member (path, imported, package, unit)
                              graphStandaloneAvailableUnits)
                        "implicit" -> imported == "Prelude"
                          && (any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphImplicitPreludeImports)
                            || any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailablePreludeImports)
                            || Set.member (path, package, unit)
                              graphStandalonePreludeImports)
                        _ -> False)) (Set.toList graphDerivedClassMembers)
               && any (\(path, typeName, className, classHead, _, imported,
                         package, _, member, mode) ->
                    path == "src/Amoebius/Layout/Classify.hs"
                      && typeName == "PathClass" && className == "Eq"
                      && classHead == "Eq" && imported == "Prelude"
                      && package == "base" && member == "==" && mode == "implicit")
                  (Set.toList graphDerivedClassMembers),
           Text.pack (show (Set.size graphDerivedClassMembers)))
        , ("compiler-standalone-deriving-control", Set.member
             ("src/Amoebius/Calculus/Artifact/Target.hs", "Eq (Target k)", "stock")
             graphStandaloneDeriving,
           Text.pack (show (Set.size graphStandaloneDeriving)))
        , ("compiler-standalone-deriving-member-control",
             Set.map (\(path, instanceType, _, strategy) -> (path, instanceType, strategy))
               graphStandaloneDerivingHeads == graphStandaloneDeriving
               && all (\(_, instanceType, classHead, _) ->
                    classHead /= "unresolved"
                      && classHead == Text.takeWhile (/= ' ') instanceType)
                  (Set.toList graphStandaloneDerivingHeads)
               && not (Set.null graphStandaloneDerivingMembers)
               && Set.map (\(path, instanceType, classHead, strategy,
                            _, _, _, _, _) -> (path, instanceType, classHead, strategy))
                    graphStandaloneDerivingMembers == graphStandaloneDerivingHeads
               && all (\(path, instanceType, classHead, strategy,
                        imported, package, unit, member, mode) ->
                    Set.member (path, instanceType, classHead, strategy)
                      graphStandaloneDerivingHeads
                      && Set.member (unit, imported,
                           Text.takeWhileEnd (/= '.') classHead, member)
                        graphModuleInterfaceMembers
                      && (case mode of
                        "explicit" -> Set.member (path, imported) graphImports
                          && (any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphExternalImports)
                            || any (\(_, consumer, name, pkg, pkgUnit) ->
                                consumer == path && name == imported
                                  && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailableUnits)
                            || Set.member (path, imported, package, unit)
                              graphStandaloneAvailableUnits)
                        "implicit" -> imported == "Prelude"
                          && (any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphImplicitPreludeImports)
                            || any (\(_, consumer, pkg, pkgUnit) ->
                                consumer == path && pkg == package && pkgUnit == unit)
                              (Set.toList graphAvailablePreludeImports)
                            || Set.member (path, package, unit)
                              graphStandalonePreludeImports)
                        _ -> False)) (Set.toList graphStandaloneDerivingMembers)
               && Set.member ("src/Amoebius/Calculus/Artifact/Target.hs", "Eq (Target k)",
                    "Eq", "stock", "Prelude", "base")
                    (Set.map (\(path, instanceType, classHead, strategy,
                               imported, package, _, _, _) ->
                       (path, instanceType, classHead, strategy, imported, package))
                      graphStandaloneDerivingMembers),
           Text.pack (show (Set.size graphStandaloneDerivingHeads,
             Set.size graphStandaloneDerivingMembers)))
        , ("compiler-data-symbol-control",
             Set.member ("src/Amoebius/Layout/Report.hs", "Options") graphData
               && Set.member ("src/Amoebius/Layout/Report.hs", "Options", "Options") graphConstructors
               && Set.member ("src/Amoebius/Layout/Report.hs", "Options", "optionRoot") graphSelectors,
           Text.pack (show (Set.size graphData, Set.size graphConstructors, Set.size graphSelectors)))
        , ("compiler-data-declaration-gap-control",
             graphDerivedTypes == Set.fromList
               [path | (path, tag) <- Set.toList graphDeclarationGaps, tag == "DataDerivingDispatch"]
               && not (any ((== "DataConstructorAndDeriving") . snd) (Set.toList graphDeclarationGaps)),
           Text.pack (show (Set.size graphDerivedTypes)))
        , ("compiler-local-call-candidate-control", Set.member
             ("library:layout", "src/Amoebius/Layout/Report.hs", "runLayoutReport", "library:layout", "src/Amoebius/Layout/Report.hs", "parseOptions") graphLocalCallCandidates,
           Text.pack (show (Set.size graphLocalCallCandidates)))
        , ("compiler-standalone-local-call-control",
             not (Set.null graphStandaloneLocalCalls)
               && all (\(path, owner, site, target) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.notMember (path, owner, site, target) graphLexicalCallSites
                      && (Set.member (path, target) graphTopLevel
                        || any (\(provider, _, name) -> provider == path && name == target)
                          (Set.toList graphConstructors)
                        || any (\(provider, _, name) -> provider == path && name == target)
                          (Set.toList graphSelectors)
                        || any (\(provider, _, name) -> provider == path && name == target)
                          (Set.toList graphClassMethods)
                        || any (\(provider, name, _, _, _) -> provider == path && name == target)
                          (Set.toList graphForeignSymbols)))
                  (Set.toList graphStandaloneLocalCalls),
           Text.pack (show (Set.size graphStandaloneLocalCalls)))
        , ("compiler-standalone-lexical-call-control",
             not (Set.null graphStandaloneLexicalCalls)
               && all (\(path, owner, site, target, binderSite) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, owner, site, target) graphLexicalCallSites
                      && (Set.member (path, owner, target, binderSite) graphLocalBinders
                        || Set.member (path, owner, target, binderSite) graphParameterBinders))
                  (Set.toList graphStandaloneLexicalCalls),
           Text.pack (show (Set.size graphStandaloneLexicalCalls)))
        , ("compiler-standalone-imported-call-control",
             not (Set.null graphStandaloneImportedCalls)
               && all (\(path, owner, site, target, imported, provider, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.notMember (path, owner, site, target) graphLexicalCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (provider, imported) graphModules
                      && length [source | (source, name) <- Set.toList graphModules,
                        name == imported] == 1
                      && (Set.member (provider, callee) graphTopLevel
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphConstructors)
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphSelectors)
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphClassMethods)
                        || any (\(source, name, _, _, _) -> source == provider && name == callee)
                          (Set.toList graphForeignSymbols)))
                  (Set.toList graphStandaloneImportedCalls),
           Text.pack (show (Set.size graphStandaloneImportedCalls)))
        , ("compiler-standalone-source-denied-control",
             not (Set.null graphStandaloneDeniedSourceCalls)
               && all (\(path, owner, site, target, imported, provider, callee, reason) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (provider, imported) graphModules
                      && (Set.member (provider, callee) graphTopLevel
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphConstructors)
                        || any (\(source, _, name) -> source == provider && name == callee)
                          (Set.toList graphSelectors))
                      && reason `elem` ["provider-not-exported", "import-list-excludes"]
                      && (any (\(component, source, callOwner, callSite, callTarget, _) ->
                            component == "-" && source == path && callOwner == owner
                              && callSite == site && callTarget == target)
                            (Set.toList graphOpaqueCallSites)
                        || Set.member ("-", path, owner, site, target) rejectedCallKeys)
                      && not (any (\(source, callOwner, callSite, callTarget, _, _, _) ->
                           source == path && callOwner == owner && callSite == site
                             && callTarget == target) (Set.toList graphStandaloneImportedCalls)))
                  (Set.toList graphStandaloneDeniedSourceCalls)
               && any (\(path, _, _, target, _, provider, callee, reason) ->
                    path == "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
                      && target == "Grant" && provider == "src/Amoebius/Calculus/Budget/Grant.hs"
                      && callee == "Grant" && reason == "provider-not-exported")
                  (Set.toList graphStandaloneDeniedSourceCalls),
           Text.pack (show (Set.size graphStandaloneDeniedSourceCalls)))
        , ("compiler-rejected-source-call-control",
             all (\(_, _, _, _, _, valid) -> valid) denialObservations
               && all (\(_, _, _, _, _, _, valid) -> valid) scopeObservations
               && Set.fromList [path | (path, _, _, _, _, _) <- denialObservations]
                    == Set.fromList [path | (path, _, _, _, _, _, _, _) <-
                         Set.toList graphStandaloneDeniedSourceCalls]
               && graphCompilerRejectedCalls ==
                    (expectedCompilerRejectedCalls `Set.union` expectedScopeRejectedCalls)
               && Set.size graphCompilerRejectedCalls == 37,
           Text.pack (show (Set.size graphCompilerRejectedCalls,
             Set.size expectedCompilerRejectedCalls, Set.size expectedScopeRejectedCalls,
             [(path, valid) | (path, _, _, _, _, valid) <- denialObservations],
             [(path, valid) | (path, _, _, _, _, _, valid) <- scopeObservations])))
        , ("compiler-standalone-closed-export-refusal-control",
             closedExportSourceProof
               && Set.size expectedClosedExportRefusals == 3
               && graphClosedExportRefusals == expectedClosedExportRefusals
               && Set.member ("src/Amoebius/Pulsar/Internal/Types.hs", "Topic", "Topic")
                    graphConstructors
               && all (\(path, owner, site, target, imported, provider, _) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (provider, imported) graphModules
                      && not (any (\(source, callOwner, callSite, callTarget, _, _, _) ->
                        source == path && callOwner == owner && callSite == site
                          && callTarget == target) (Set.toList graphStandaloneImportedCalls)))
                    (Set.toList graphClosedExportRefusals),
           Text.pack (show (Set.size graphClosedExportRefusals,
             Set.size expectedClosedExportRefusals)))
        , ("compiler-grant-rejection-control",
             grantCompilerValid
               && any (\(path, _, _, target, imported, provider, callee, reason) ->
                    path == "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
                      && target == "Grant"
                      && imported == "Amoebius.Calculus.Budget.Grant"
                      && provider == "src/Amoebius/Calculus/Budget/Grant.hs"
                      && callee == "Grant" && reason == "provider-not-exported")
                 (Set.toList graphStandaloneDeniedSourceCalls),
           grantCompilerDetail)
        , ("compiler-standalone-external-call-control",
             any (\(path, owner, _, target, imported, package, _, callee) ->
                    path == "src/vendor/Pulsar/Connection.hs" && owner == "connect"
                      && target == "async" && imported == "Control.Concurrent.Async"
                      && package == "async" && callee == "async")
                  (Set.toList graphStandaloneExternalCalls)
               && all (\(path, owner, site, target, imported, package, unit, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (path, imported, package, unit) graphStandaloneAvailableUnits
                      && not (any ((== imported) . snd) (Set.toList graphModules))
                      && not (Text.null package) && not (Text.null callee)
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                        interfaceUnit == unit && interfaceName == imported) graphModuleInterfaceRows)
                  (Set.toList graphStandaloneExternalCalls),
           Text.pack (show (Set.size graphStandaloneExternalCalls)))
        , ("compiler-standalone-registered-only-control",
             all (\(path, owner, site, target, imported, package, unit, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported, package, unit)
                        graphStandaloneRegisteredOnlyUnits
                      && any (\(component, source, callOwner, callSite, callTarget, _) ->
                           component == "-" && source == path && callOwner == owner
                             && callSite == site && callTarget == target)
                        (Set.toList graphOpaqueCallSites)
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                           interfaceUnit == unit && interfaceName == imported)
                        graphModuleInterfaceRows
                      && not (Text.null callee))
                  (Set.toList graphStandaloneRegisteredOnlyCalls)
               && all (\(path, imported, package, unit) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, imported) graphImports
                      && not (Text.null package)
                      && not (Set.member (path, imported, package, unit)
                        graphStandaloneAvailableUnits))
                  (Set.toList graphStandaloneRegisteredOnlyUnits),
           Text.pack (show (Set.size graphStandaloneRegisteredOnlyUnits,
             Set.size graphStandaloneRegisteredOnlyCalls)))
        , ("compiler-standalone-external-member-control",
             all (\(path, owner, site, target, imported, package, unit, parent, callee) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, imported) graphImports
                      && Set.member (path, imported, package, unit) graphStandaloneAvailableUnits
                      && not (Text.null package)
                      && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
                  (Set.toList graphStandaloneExternalMemberCalls),
           Text.pack (show (Set.size graphStandaloneExternalMemberCalls)))
        , ("compiler-imported-call-candidate-control", Set.member
             ("executable:amoebius", "app/amoebius/Main.hs", "dispatch", "executable:amoebius", "app/amoebius/Amoebius/Entry/ControlPlane.hs", "runControlPlaneDaemon", "Amoebius.Entry.ControlPlane") graphCallCandidates,
           Text.pack (show (Set.size graphCallCandidates)))
        , ("compiler-local-import-control", Set.member
             ("library:layout", "src/Amoebius/Layout/SourceGraph.hs", "library:layout", "src/Amoebius/Layout/Classify.hs", "Amoebius.Layout.Classify") graphLinks,
           Text.pack (show (Set.size graphLinks)))
        , ("compiler-dependency-import-control", Set.member
             ("executable:amoebius", "app/amoebius/Main.hs", "library:layout", "src/Amoebius/Layout/Report.hs", "Amoebius.Layout.Report") graphLinks,
           Text.pack (show (Set.size graphLinks)))
        , ("compiler-component-control", Set.member
             ("src/Amoebius/Layout/SourceGraph.hs", "library:layout") graphComponents,
           Text.pack (show (Set.size graphComponents)))
        , ("compiler-cabal-dependency-control",
             all (`Set.member` packageBuildDependencies)
               [("library:layout", "ghc"), ("library:layout", "Cabal-syntax"),
                ("executable:amoebius", "aeson")]
               && all (not . Text.null . snd) (Set.toList packageBuildDependencies),
           Text.pack (show (Set.size packageBuildDependencies)))
        , ("compiler-import-partition-control", importPartition,
           Text.pack (show (Set.size componentImportKeys, Set.size internalImportKeys,
             Set.size externalImportKeys, Set.size forwardImportKeys, Set.size unresolvedImportKeys)))
        , ("compiler-external-call-candidate-control",
             not (Set.null graphExternalCallCandidates)
               && all (\(component, path, owner, site, target, imported, package, unit, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphExternalImports
                   && not (Text.null callee))
                 (Set.toList graphExternalCallCandidates),
           Text.pack (show (Set.size graphExternalCallCandidates)))
        , ("compiler-external-member-call-control",
             all (\(component, path, owner, site, target, imported, package, unit, parent, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphExternalImports
                   && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
               (Set.toList graphExternalMemberCallCandidates),
           Text.pack (show (Set.size graphExternalMemberCallCandidates)))
        , ("compiler-available-call-candidate-control",
             all (\(component, path, owner, site, target, imported, package, unit, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphAvailableUnits
                   && any (\(interfaceUnit, interfaceName, _, _) ->
                      interfaceUnit == unit && interfaceName == imported) graphModuleInterfaceRows
                   && not (Text.null callee))
               (Set.toList graphAvailableCallCandidates),
           Text.pack (show (Set.size graphAvailableCallCandidates)))
        , ("compiler-available-member-call-control",
             all (\(component, path, owner, site, target, imported, package, unit, parent, callee) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, imported, package, unit) graphAvailableUnits
                   && Set.member (unit, imported, parent, callee) graphModuleInterfaceMembers)
               (Set.toList graphAvailableMemberCallCandidates),
           Text.pack (show (Set.size graphAvailableMemberCallCandidates)))
        , ("compiler-deferred-seed-call-control",
             not (Set.null graphDeferredSeedCallCandidates)
               && all (\(component, path, owner, site, target, imported, package, role, callee) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (component, path, imported, package, role) graphDeferredSeed
                      && callee == Text.takeWhileEnd (/= '.') target)
                  (Set.toList graphDeferredSeedCallCandidates),
           Text.pack (show (Set.size graphDeferredSeedCallCandidates)))
        , ("compiler-prelude-interface-control",
             Set.size graphPreludeInterfaces == 1
               && all (\(unit, digest, count) -> Text.length digest == 64
                 && count == "259"
                 && any (\(_, _, name, package, externalUnit) ->
                   name == "Prelude" && package == "base" && externalUnit == unit)
                   (Set.toList graphExternalImports)) (Set.toList graphPreludeInterfaces)
               && all (\(component, path, owner, site, target, package, unit) ->
                 Set.member (path, owner, site, target) graphCallSites
                   && Set.member (component, path, package, unit) graphImplicitPreludeImports
                   && package == "base") (Set.toList graphPreludeCallCandidates)
               && all (\name -> any (\(_, _, _, _, target, _, _) -> target == name)
                   (Set.toList graphPreludeCallCandidates)) ["map", "pure", "Left", "<>", "."]
               && all (\(component, path, package, unit) ->
                 Set.member (path, component) graphComponents
                   && package == "base"
                   && any (\(interfaceUnit, _, _) -> interfaceUnit == unit)
                     (Set.toList graphPreludeInterfaces))
                 (Set.toList graphImplicitPreludeImports),
           Text.pack (show (Set.size graphImplicitPreludeImports, Set.size graphPreludeCallCandidates)))
        , ("compiler-available-prelude-control",
             all (\(component, path, package, unit) ->
                 Set.member (path, component) graphComponents
                   && Set.member (component, package) packageBuildDependencies
                   && package == "base"
                   && any (\(interfaceUnit, _, _) -> interfaceUnit == unit)
                     (Set.toList graphPreludeInterfaces))
               (Set.toList graphAvailablePreludeImports)
               && all (\(component, path, owner, site, target, package, unit) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (component, path, package, unit) graphAvailablePreludeImports)
                  (Set.toList graphAvailablePreludeCallCandidates),
           Text.pack (show (Set.size graphAvailablePreludeImports,
             Set.size graphAvailablePreludeCallCandidates)))
        , ("compiler-standalone-prelude-control",
             not (Set.null graphStandalonePreludeImports)
               && all (\(path, package, unit) ->
                    path `Set.member` graphNoComponents && package == "base"
                      && any (\(interfaceUnit, _, _) -> interfaceUnit == unit)
                        (Set.toList graphPreludeInterfaces))
                  (Set.toList graphStandalonePreludeImports)
               && all (\(path, owner, site, target, package, unit) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.notMember (path, owner, site, target) graphLexicalCallSites
                      && Set.member (path, package, unit) graphStandalonePreludeImports
                      && package == "base")
                  (Set.toList graphStandalonePreludeCallCandidates),
           Text.pack (show (Set.size graphStandalonePreludeImports,
             Set.size graphStandalonePreludeCallCandidates)))
        , ("compiler-wired-cons-control",
             not (Set.null graphWiredConsCandidates)
               && all (\(component, path, owner, site, target, provider, unit) ->
                    target == ":" && provider == "GHC.Types" && unit == "ghc-prim"
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, component) graphComponents)
                    (Set.toList graphWiredConsCandidates),
           Text.pack (show (Set.size graphWiredConsCandidates)))
        , ("compiler-standalone-wired-cons-control",
             not (Set.null graphStandaloneWiredConsCandidates)
               && all (\(path, owner, site, target, provider, unit) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, owner, site, target) graphCallSites
                      && target == ":" && provider == "GHC.Types" && unit == "ghc-prim")
                  (Set.toList graphStandaloneWiredConsCandidates),
           Text.pack (show (Set.size graphStandaloneWiredConsCandidates)))
        , ("compiler-wired-tuple-control",
             all (\(component, path, owner, site, target, provider, unit) ->
                    target == "(,)" && provider == "GHC.Tuple" && unit == "ghc-prim"
                      && Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, component) graphComponents)
                 (Set.toList graphWiredTupleCandidates),
           Text.pack (show (Set.size graphWiredTupleCandidates)))
        , ("compiler-lexical-binding-control",
             not (Set.null graphLexicalBindingCandidates)
               && all (\(component, path, owner, site, target, binderSite) ->
                    Set.member (path, owner, site, target) graphCallSites
                      && Set.member (path, owner, site, target) graphLexicalCallSites
                      && Set.member (path, component) graphComponents
                      && (Set.member (path, owner, target, binderSite) graphLocalBinders
                        || Set.member (path, owner, target, binderSite) graphParameterBinders)
                      && binderSite /= "unlocated" && binderSite /= site)
                    (Set.toList graphLexicalBindingCandidates),
           Text.pack (show (Set.size graphLexicalBindingCandidates)))
        , ("compiler-parameter-binder-control",
             not (Set.null graphParameterBinders)
               && all (\(path, owner, name, binderSite) ->
                    Set.member (Text.unpack path) graphFiles && not (Text.null owner)
                      && not (Text.null name) && binderSite /= "unlocated")
                 (Set.toList graphParameterBinders),
           Text.pack (show (Set.size graphParameterBinders)))
        , ("compiler-local-alias-control",
             all (\(path, owner, name, binderSite, target, targetKind) ->
               Set.member (path, owner, name, binderSite) graphLocalBinders
                 && not (Text.null target)
                 && targetKind `elem` ["unqualified", "qualified", "parameter", "local-binder"])
               (Set.toList graphLocalAliases)
               && all (\(component, path, owner, site, binder, binderSite, target, targetKind) ->
                 Set.member (path, owner, binder, binderSite, target, targetKind) graphLocalAliases
                   && Set.member (component, path, owner, site, binder, binderSite) graphLexicalBindingCandidates)
                 (Set.toList graphLexicalAliasRoutes)
               && all (\((component, path, owner), (targetComponent, targetPath, callee)) ->
                 component == targetComponent && path == targetPath
                   && any (\(sourceComponent, sourcePath, sourceOwner, _, _, _, target, targetKind) ->
                      sourceComponent == component && sourcePath == path && sourceOwner == owner
                        && target == callee && targetKind == "unqualified")
                     (Set.toList graphLexicalAliasRoutes))
                 (Set.toList graphAliasInternalCalls),
           Text.pack (show (Set.size graphLocalAliases, Set.size graphLexicalAliasRoutes,
             Set.size graphAliasInternalCalls)))
        , ("compiler-alias-external-control",
             all (\(component, path, owner, site, binder, binderSite, target, imported, package, unit, callee) ->
               Set.member (component, path, imported, package, unit) graphExternalImports
                 && any (\(sourceComponent, sourcePath, sourceOwner, sourceSite,
                          sourceBinder, sourceBinderSite, sourceTarget, targetKind) ->
                   sourceComponent == component && sourcePath == path && sourceOwner == owner
                     && sourceSite == site && sourceBinder == binder
                     && sourceBinderSite == binderSite && sourceTarget == target
                     && targetKind `elem` ["qualified", "unqualified"])
                   (Set.toList graphLexicalAliasRoutes)
                 && not (Text.null callee)
                 && any (\(interfaceUnit, interfaceName, _, _) ->
                   interfaceUnit == unit && interfaceName == imported) graphModuleInterfaceRows)
               (Set.toList graphAliasExternalCalls),
           Text.pack (show (Set.size graphAliasExternalCalls)))
        , ("compiler-alias-imported-control",
             all (\(component, path, owner, site, binder, binderSite, target,
                     targetComponent, provider, callee, imported) ->
               Set.member (component, path, targetComponent, provider, imported) graphLinks
                 && any (\(sourceComponent, sourcePath, sourceOwner, sourceSite,
                          sourceBinder, sourceBinderSite, sourceTarget, targetKind) ->
                   sourceComponent == component && sourcePath == path && sourceOwner == owner
                     && sourceSite == site && sourceBinder == binder
                     && sourceBinderSite == binderSite && sourceTarget == target
                     && targetKind `elem` ["qualified", "unqualified"])
                   (Set.toList graphLexicalAliasRoutes)
                 && (Set.member (provider, callee) graphTopLevel
                   || any (\(declarationPath, _, member) ->
                       declarationPath == provider && member == callee) (Set.toList graphConstructors)
                   || any (\(declarationPath, _, member) ->
                       declarationPath == provider && member == callee) (Set.toList graphSelectors)
                   || any (\(declarationPath, _, member) ->
                       declarationPath == provider && member == callee) (Set.toList graphClassMethods)))
               (Set.toList graphAliasImportedCalls),
           Text.pack (show (Set.size graphAliasImportedCalls)))
        , ("compiler-external-interface-control",
             length graphModuleInterfaceRows == Set.size graphModuleInterfaces
               && Set.fromList [(unit, name) | (unit, name, _, _) <- graphModuleInterfaceRows]
                    == Set.fromList
                      ([(unit, name) | (_, _, name, _, unit) <- Set.toList graphExternalImports]
                        <> [(unit, name) | (_, _, name, _, unit) <- Set.toList graphUnselectedCandidates]
                        <> [(unit, name) | (_, name, _, unit) <- Set.toList graphStandaloneAvailableUnits]
                        <> [(unit, name) | (_, name, _, unit) <- Set.toList graphStandaloneRegisteredOnlyUnits])
               && all (\(path, name, package, unit) ->
                    path `Set.member` graphNoComponents
                      && Set.member (path, name) graphImports
                      && not (Text.null package)
                      && not (any ((== name) . snd) (Set.toList graphModules))
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                        interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows)
                  (Set.toList graphStandaloneAvailableUnits)
               && all (\(unit, name, digest, count) ->
                    Text.length digest == 64 && not (Text.null unit)
                      && not (Text.null name) && not (Text.null count)) graphModuleInterfaceRows
               && all (\(_, _, _, _, _, imported, _, unit, _) ->
                    any (\(interfaceUnit, name, _, _) -> interfaceUnit == unit && name == imported)
                      graphModuleInterfaceRows) (Set.toList graphExternalCallCandidates),
           Text.pack (show (length graphModuleInterfaceRows)))
        , ("compiler-interface-member-control",
             all (\(unit, name, parent, member) ->
                  not (Text.null parent) && not (Text.null member)
                    && any (\(interfaceUnit, interfaceName, _, _) ->
                        interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows)
               (Set.toList graphModuleInterfaceMembers),
           Text.pack (show (Set.size graphModuleInterfaceMembers)))
        , ("compiler-forward-owned-import-control", graphForwardOwned == expectedForwardOwned
             && Set.size graphForwardOwned == 11,
           Text.pack (show (Set.size graphForwardOwned, Set.size expectedForwardOwned)))
        , ("compiler-deferred-seed-import-control",
             graphDeferredSeed == Set.fromList
               [("library:infernix", "src/Infernix/Adapter/Core.hs", "Infernix.Topic.Metadata",
                 "infernix", "infernix-rederivation"),
                ("test:jitml-cuda-artifact-lift-contract", "test/spec/kernel/JitMLCudaArtifactContractSpec.hs",
                 "JitML.Codegen.RuntimeOperationsCuda", "jitml", "jitml-rederivation")]
               && all (\(component, consumer, name, package, _) ->
                    (Set.member (component, package) packageBuildDependencies
                      || (component == "test:jitml-cuda-artifact-lift-contract"
                        && package == "jitml"
                        && Set.member ("library:jitml", package) packageBuildDependencies
                        && any (\(sourceComponent, sourcePath, targetComponent, _, _) ->
                            sourceComponent == component && sourcePath == consumer
                              && targetComponent == "library:jitml") (Set.toList graphLinks)))
                      && Set.member (consumer, name) graphImports
                      && Set.member (consumer, component) graphComponents)
                  (Set.toList graphDeferredSeed),
           Text.pack (show (Set.size graphDeferredSeed)))
        , ("compiler-unselected-unit-candidate-control",
             all (\(component, consumer, name, package, unit) ->
               (Set.member (component, consumer, name, "component-not-in-plan") graphUnresolved
                 || Set.member (component, consumer, name, package, unit) graphAvailableUnits)
                 && Set.member (component, package) packageBuildDependencies
                 && not (Text.null unit)
                 && any (\(interfaceUnit, interfaceName, _, _) ->
                      interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows
                 && Set.notMember (component, consumer, name) externalImportKeys)
               (Set.toList graphUnselectedCandidates),
           Text.pack (show (Set.size graphUnselectedCandidates)))
        , ("compiler-available-unit-control",
             Set.size graphAvailableUnits == Set.size availableImportKeys
               && all (\row@(_, _, name, _, unit) ->
                    Set.member row graphUnselectedCandidates
                      && any (\(interfaceUnit, interfaceName, _, _) ->
                          interfaceUnit == unit && interfaceName == name) graphModuleInterfaceRows)
                  (Set.toList graphAvailableUnits),
           Text.pack (show (Set.size graphAvailableUnits)))
        , ("compiler-residual-ownership-control",
             all (\(component, _, name, reason) -> case reason of
               "external-or-unknown" -> component == "library:pulsar-client"
                 && name `elem` ["Proto.PulsarApi", "Proto.PulsarApi_Fields"]
               "component-not-in-plan" -> component `elem`
                 ["library:infernix", "library:infernix-ui", "library:jitml", "library:jitml-ui",
                  "test:infernix-core-artifact-lift-contract", "test:infernix-native-driver",
                  "test:infernix-ui-lift-contract", "test:jitml-cuda-artifact-lift-contract",
                  "test:jitml-ui-lift-contract"]
               _ -> False) (Set.toList graphUnresolved),
           Text.pack (show (Set.size graphUnresolved)))
        , ("compiler-source-role-coverage",
             graphFiles == Set.map Text.unpack (Set.union (Set.map fst graphComponents) graphNoComponents)
               && Set.null (Set.intersection (Set.map fst graphComponents) graphNoComponents),
           Text.pack (show (Set.size graphNoComponents)))
        , ("compiler-standalone-role-coverage",
             Set.map fst packageStandalone == graphNoComponents
               && length standaloneRows == Set.size packageStandalone
               && all (\(path, role) -> expectedStandaloneRole path == Just role) standaloneRows,
           Text.pack (show (Set.size packageStandalone)))
        , ("compiler-import-classification-control", Set.member
             ("library:layout", "src/Amoebius/Layout/SourceGraph.hs", "GHC.Parser", "external-or-unknown") graphUnresolved
             || any (\(component, consumer, name, package, unit) ->
                  component == "library:layout" && consumer == "src/Amoebius/Layout/SourceGraph.hs"
                    && name == "GHC.Parser" && package == "ghc" && not (Text.null unit))
                  (Set.toList graphExternalImports),
           Text.pack (show (Set.size graphUnresolved, Set.size graphExternalImports)))
        , ("compiler-inaccessible-internal-control",
             Set.fromList [(component, consumer, name) | (component, consumer, name, reason) <- Set.toList graphUnresolved,
               reason == "internal-not-declared"]
               == Set.fromList [(component, consumer, name) | (component, consumer, name, _, _) <- Set.toList graphInaccessible]
               && all (\(component, _, _, _, _) -> component /= "executable:amoebius") (Set.toList graphInaccessible),
           Text.pack (show (Set.size graphInaccessible)))
        , ("case:graph-qualified",
             graphStages == ["resolved"] && importPartition && Set.null graphUnresolved
               && Set.null graphUnscanned && Set.null graphDeclarationGaps
               && Set.null graphOpaqueCallSites
               && graphForwardOwned == expectedForwardOwned
               && graphEffectRoutes == expectedEffectRoutes
               && any (\(component, consumer, name, package, unit) ->
                    component == "library:layout" && consumer == "src/Amoebius/Layout/SourceGraph.hs"
                      && name == "GHC.Parser" && package == "ghc" && not (Text.null unit))
                    (Set.toList graphExternalImports),
           Text.pack (show (graphStages, Set.size graphUnresolved,
             Set.size graphUnscanned, Set.size graphDeclarationGaps,
             Set.size graphOpaqueCallSites, Set.size graphExternalImports)))
        , ("bootstrap-call-sites", bootstrapCalls == Set.fromList expectedBootstrapCalls,
           Text.pack (show (Set.toAscList bootstrapCalls)))
        , ("bootstrap-effect-sites", bootstrapEffects == Set.fromList expectedBootstrapEffects,
           Text.pack (show (Set.toAscList bootstrapEffects)))
        , ("forward-owned-generated-proto", packageOwed == Set.fromList
             [("library:pulsar-client:Proto/PulsarApi.hs", "generated-proto"),
              ("library:pulsar-client:Proto/PulsarApi_Fields.hs", "generated-proto")],
           Text.pack (show packageOwed))
        ]
          <> [ ("path:" <> Text.pack path, Map.lookup path observedPaths == Just className, maybe "absent" id (Map.lookup path observedPaths))
             | path <- expectedPaths
             , let className = expectedClass path
             ]
          <> [("case:" <> name, Map.lookup name cases == Just wanted, maybe "absent" id (Map.lookup name cases)) | (name, wanted) <- expectedCases]
          <> [("challenge-finding:" <> name,
               pathMatches name path && maybe False (\wanted -> sort found == sort
                 (["finding\t" <> wanted <> "\t" <> path <> (if name == "ordinal" then ":2" else "")]
                   <> ["finding\tUnmappedHaskellSource\t" <> path | name == "ordinal"])) (lookup name expectedChallengeTags),
               Text.intercalate "," found)
             | (name, path, _, found) <- challengeFindings]
  mapM_ (TextIO.putStrLn . renderCheck) checks
  unless (all (\(_, green, _) -> green) checks) exitFailure

data CompilerDiagnostic = CompilerDiagnostic Text Text Int FilePath Int Int [Text]

parseCompilerDiagnostic :: Value -> Parser CompilerDiagnostic
parseCompilerDiagnostic = withObject "CompilerDiagnostic" $ \record -> do
    compilerVersion <- record .: "ghcVersion"
    severity <- record .: "severity"
    diagnosticCode <- record .: "code"
    messages <- record .: "message"
    located <- record .: "span"
    (path, diagnosticLine, diagnosticColumn) <- withObject "CompilerSpan" (\spanRecord -> do
      path <- spanRecord .: "file"
      start <- spanRecord .: "start"
      (diagnosticLine, diagnosticColumn) <- withObject "CompilerStart" (\position ->
        (,) <$> position .: "line" <*> position .: "column") start
      pure (path, diagnosticLine, diagnosticColumn)) located
    pure (CompilerDiagnostic compilerVersion severity diagnosticCode path
      diagnosticLine diagnosticColumn messages)

parseCompilerLines :: String -> Either String [CompilerDiagnostic]
parseCompilerLines output = traverse
  (\line -> eitherDecodeStrict' (TextEncoding.encodeUtf8 line)
    >>= parseEither parseCompilerDiagnostic)
  (filter (not . Text.null) (Text.lines (Text.pack output)))

observeGrantTwin :: FilePath -> IO (Bool, Text)
observeGrantTwin directory = do
  version <- invoke ["--numeric-version"]
  legal <- compile "grant-legal" legalPath
  illegal <- compile "grant-illegal" illegalPath
  let versionValid = case version of
        Right (ExitSuccess, output, _) -> Text.strip (Text.pack output) == "9.12.4"
        _ -> False
      legalValid = case legal of
        Right (ExitSuccess, _, stderrText) ->
          case parseCompilerLines stderrText of
            Right observed -> null [() | CompilerDiagnostic _ severity _ _ _ _ _ <- observed,
              severity == "Error"]
            Left _ -> False
        _ -> False
      illegalValid = case illegal of
        Right (ExitFailure _, _, stderrText) -> case parseCompilerLines stderrText of
          Right [CompilerDiagnostic "ghc-9.12.4" "Error" 1928 path 31 3 messages] ->
            path == illegalPath
              && all (`Text.isInfixOf` Text.intercalate "\n" messages)
                   ["Illegal term-level use", "Grant", "src/Amoebius/Calculus/Budget/Grant.hs"]
          _ -> False
        _ -> False
  pure (versionValid && legalValid && illegalValid,
    Text.pack (show (versionValid, legalValid, illegalValid)))
 where
  legalPath = "test/negative/compile_fail/budget_calculus/grant_comes_from_the_issuer.hs"
  illegalPath = "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
  invoke args = try (readProcessWithExitCode "ghc" args "")
    :: IO (Either SomeException (ExitCode, String, String))
  compile label source = do
    let outputDir = directory </> "compiler-negative" </> label
    createDirectoryIfMissing True outputDir
    invoke ["-j1", "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024",
      "-isrc/calculus-composition", "-isrc/capacity-topology", "-isrc",
      "-outputdir", outputDir, "-package", "base", "-package", "bytestring",
      "-package", "containers", "-package", "deepseq", "-package", "text", source]

observeMethodImportTwin :: FilePath -> IO (Bool, Text)
observeMethodImportTwin directory = do
  let outputDir = directory </> "compiler-negative" </> "instance-method-import"
      legalPath = outputDir </> "VisibleMethod.hs"
      illegalPath = outputDir </> "HiddenMethod.hs"
      source moduleName importLine = Text.unlines
        ["module " <> moduleName <> " where", importLine, "data X = X",
         "instance FromJSON X where", "  parseJSON _ = pure X"]
  createDirectoryIfMissing True outputDir
  TextIO.writeFile legalPath (source "VisibleMethod"
    "import Data.Aeson (FromJSON (parseJSON))")
  TextIO.writeFile illegalPath (source "HiddenMethod"
    "import Data.Aeson (FromJSON)")
  legal <- compile outputDir legalPath
  illegal <- compile outputDir illegalPath
  let legalValid = case legal of
        Right (ExitSuccess, _, stderrText) ->
          either (const False) (null . filter compilerError)
            (parseCompilerLines stderrText)
        _ -> False
      illegalValid = case illegal of
        Right (ExitFailure _, _, stderrText) -> case parseCompilerLines stderrText of
          Right [CompilerDiagnostic "ghc-9.12.4" "Error" 54721 path 5 3 messages] ->
            path == illegalPath
              && "parseJSON" `Text.isInfixOf` Text.intercalate "\n" messages
              && "visible" `Text.isInfixOf` Text.intercalate "\n" messages
          _ -> False
        _ -> False
  pure (legalValid && illegalValid,
    Text.pack (show (legalValid, illegalValid)))
 where
  compilerError (CompilerDiagnostic _ severity _ _ _ _ _) = severity == "Error"
  compile outputDir source =
    try (readProcessWithExitCode "cabal"
      ["exec", "--jobs=1", "--", "ghc", "-j1", "-fdiagnostics-as-json",
       "-fno-code", "-fforce-recomp", "-XGHC2024", "-outputdir", outputDir, source] "")
      :: IO (Either SomeException (ExitCode, String, String))

deniedConstructorExpectations :: [(FilePath, Text, Text, Text, Int, Int, FilePath)]
deniedConstructorExpectations =
  [ ("test/fixture/chain_boundary/compilefail/checked_ctor_illegal.hs",
      "illegal", "CheckedExtensionSource", "5:11-5:45", 5, 11,
      "src/Amoebius/Dsl/AstCheck.hs")
  , ("test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs",
      "forged", "Grant", "31:3-34:67", 31, 3,
      "src/Amoebius/Calculus/Budget/Grant.hs")
  , ("test/negative/compile_fail/budget_calculus/grant_forged_unbounded_budget_calculus_grant_constructors_exposed_mutant.hs",
      "forged", "Grant", "31:3-34:67", 31, 3,
      "src/Amoebius/Calculus/Budget/Grant.hs")
  , ("test/negative/compile_fail/determinism_jitcache/forge_blobsha.hs",
      "forged", "BlobSha", "6:10-6:28", 6, 10,
      "src/Amoebius/Kernel/ContentAddress.hs")
  , ("test/negative/compile_fail/extension_conformance/illegal/extension_conformance_forge_verdict.hs",
      "forgeVerdict", "ConformanceVerdict", "17:16-17:81", 17, 16,
      "src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs")
  , ("test/negative/compile_fail/infernix_lift/forge_ready_handle.hs",
      "forged", "ReadyArtifactHandle", "6:10-6:48", 6, 10,
      "src/Infernix/Adapter/Store.hs")
  , ("test/negative/compile_fail/lift_calculus/witness_asserted.hs",
      "entering", "Witness", "18:12-18:30", 18, 12,
      "src/Amoebius/Calculus/Lift/Witness.hs")
  , ("test/negative/compile_fail/lift_calculus/witness_asserted_lift_calculus_witness_constructor_exposed_mutant.hs",
      "entering", "Witness", "18:12-18:30", 18, 12,
      "src/Amoebius/Calculus/Lift/Witness.hs")
  , ("test/negative/compile_fail/scope_index/forge_request_scope_illegal.hs",
      "illegal", "RequestScope", "4:37-4:75", 4, 37,
      "src/Amoebius/Scope/Index.hs")
  , ("test/negative/compile_fail/scope_index/raw_resource_id_illegal.hs",
      "illegal", "ResourceId", "5:11-5:41", 5, 11,
      "src/Amoebius/Scope/Index.hs")
  , ("test/negative/determinism_jitcache/freestring_key.hs",
      "forged", "CacheKey", "6:10-6:51", 6, 10,
      "src/Amoebius/Jit/Cache.hs")
  ]

observeDeniedConstructor :: FilePath
  -> (FilePath, Text, Text, Text, Int, Int, FilePath)
  -> IO (Text, Text, Text, Text, Text, Bool)
observeDeniedConstructor directory (path, owner, target, rootSite, line, column, provider) = do
  let outputDir = directory </> "compiler-negative" </> "denied"
        </> Text.unpack (sha256Text (TextEncoding.encodeUtf8 (Text.pack path)))
      arguments = ["exec", "--jobs=1", "--", "ghc", "-j1",
        "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"]
        <> ["-i" <> sourceDir | sourceDir <- sourceDirs]
        <> ["-outputdir", outputDir, path]
  before <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  createDirectoryIfMissing True outputDir
  attempted <- try (readProcessWithExitCode "cabal" arguments "")
    :: IO (Either SomeException (ExitCode, String, String))
  after <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  let digest = either (const "") sha256Text before
      valid = case (before, attempted, after) of
        (Right first, Right (ExitFailure _, _, stderrText), Right lastBytes)
          | first == lastBytes
          , Right [CompilerDiagnostic "ghc-9.12.4" "Error" 1928 source diagnosticLine
              diagnosticColumn messages] <- parseCompilerLines stderrText ->
              source == path && diagnosticLine == line && diagnosticColumn == column
                && siteStartsAt (line, column) rootSite
                && all (`Text.isInfixOf` Text.intercalate "\n" messages)
                     ["type constructor `" <> target <> "'", Text.pack provider]
        _ -> False
  pure (Text.pack path, owner, target, rootSite, digest, valid)
 where
  sourceDirs =
    ["src", "src/calculus-composition", "src/capacity-topology",
     "src/extension-conformance-gate", "src/extension-declaration",
     "src/extension-laws-compositional", "src/extension-laws",
     "src/extension-security-laws"]

scopeRejectionExpectations :: [(FilePath, Text, Text, Text, Int, Int, Int, Text)]
scopeRejectionExpectations =
  [ ("test/negative/compile_fail/ChildInForceSpec/NegativeAncestor.hs",
      "main", "childAncestorOnlyPayload", "10:25-10:55", 10, 25, 88464,
      "Variable not in scope")
  , ("test/negative/compile_fail/ChildInForceSpec/NegativeSibling.hs",
      "main", "childSiblingBranches", "10:25-10:51", 10, 25, 88464,
      "Variable not in scope")
  , ("test/negative/compile_fail/infernix_lift/url_engine_arm.hs",
      "downloadFromCallerUrl", "Url", "6:25-6:60", 6, 25, 88464,
      "Data constructor not in scope")
  , ("test/negative/compile_fail/scope_index/declassify_illegal.hs",
      "illegal", "declassify", "4:24-4:47", 4, 24, 88464,
      "Variable not in scope")
  , ("test/negative/compile_fail/transaction_vocabulary/illegal/transaction_vocabulary_predicate.hs",
      "program", "Vocabulary.predicate", "24:5-24:52", 24, 5, 76037,
      "does not export `predicate'")
  , ("test/negative/compile_fail/transaction_vocabulary/illegal/transaction_vocabulary_raw_query.hs",
      "program", "Vocabulary.rawStatement", "24:5-24:60", 24, 5, 76037,
      "does not export `rawStatement'")
  , ("test/negative/determinism_jitcache/url_arm.hs",
      "authored", "Url", "6:12-6:48", 6, 12, 88464,
      "Data constructor not in scope")
  ]

observeScopeRejection :: FilePath
  -> (FilePath, Text, Text, Text, Int, Int, Int, Text)
  -> IO (Text, Text, Text, Text, Int, Text, Bool)
observeScopeRejection directory (path, owner, target, rootSite, line, column, code, fragment) = do
  let outputDir = directory </> "compiler-negative" </> "scope"
        </> Text.unpack (sha256Text (TextEncoding.encodeUtf8 (Text.pack path)))
      arguments = ["exec", "--jobs=1", "--", "ghc", "-j1",
        "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"]
        <> ["-i" <> sourceDir | sourceDir <- sourceDirs]
        <> ["-outputdir", outputDir, path]
  before <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  createDirectoryIfMissing True outputDir
  attempted <- try (readProcessWithExitCode "cabal" arguments "")
    :: IO (Either SomeException (ExitCode, String, String))
  after <- try (ByteString.readFile path) :: IO (Either SomeException ByteString.ByteString)
  let digest = either (const "") sha256Text before
      valid = case (before, attempted, after) of
        (Right first, Right (ExitFailure _, _, stderrText), Right lastBytes)
          | first == lastBytes
          , Right [CompilerDiagnostic "ghc-9.12.4" "Error" observedCode source
              diagnosticLine diagnosticColumn messages] <- parseCompilerLines stderrText ->
              source == path && observedCode == code
                && diagnosticLine == line && diagnosticColumn == column
                && siteStartsAt (line, column) rootSite
                && target `Text.isInfixOf` Text.intercalate "\n" messages
                && fragment `Text.isInfixOf` Text.intercalate "\n" messages
        _ -> False
  pure (Text.pack path, owner, target, rootSite, code, digest, valid)
 where
  sourceDirs =
    ["src", "src/transaction-vocabulary", "src/calculus-composition",
     "src/capacity-topology", "src/extension-conformance-gate",
     "src/extension-declaration", "src/extension-laws-compositional",
     "src/extension-laws", "src/extension-security-laws"]

sha256Text :: ByteString.ByteString -> Text
sha256Text = Text.pack . concatMap (\byte ->
  [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)])
  . ByteString.unpack . SHA256.hash

siteStartsAt :: (Int, Int) -> Text -> Bool
siteStartsAt position site = case parseSite site of
  Just (start, _) -> start == position
  Nothing -> False

siteContainedBy :: Text -> Text -> Bool
siteContainedBy site rootSite = case (parseSite site, parseSite rootSite) of
  (Just (start, end), Just (rootStart, rootEnd)) -> rootStart <= start && end <= rootEnd
  _ -> False

parseSite :: Text -> Maybe ((Int, Int), (Int, Int))
parseSite site = case Text.splitOn "-" site of
  [start, end] -> (,) <$> parsePosition start <*> parsePosition end
  _ -> Nothing
 where
  parsePosition position = case Text.splitOn ":" position of
    [line, column] -> (,) <$> readInt line <*> readInt column
    _ -> Nothing
  readInt value = case reads (Text.unpack value) of
    [(number, "")] -> Just number
    _ -> Nothing

metadata :: [FilePath]
metadata = [".gitignore", ".dockerignore", "amoebius.cabal", "cabal.project", "probe/probe.cabal", "LICENSE"]

expectedBootstrapCalls :: [(Text, Text)]
expectedBootstrapCalls =
  [ ("BootstrapAdapter.capture", "subprocess.run")
  , ("BootstrapAdapter.ensure_ghcup", "RuntimeError")
  , ("BootstrapAdapter.ensure_ghcup", "existing_hash_value.hexdigest")
  , ("BootstrapAdapter.ensure_ghcup", "hash_value.hexdigest")
  , ("BootstrapAdapter.ensure_ghcup", "hashlib.sha256")
  , ("BootstrapAdapter.ensure_ghcup", "response.read")
  , ("BootstrapAdapter.ensure_ghcup", "target.chmod")
  , ("BootstrapAdapter.ensure_ghcup", "target.is_file")
  , ("BootstrapAdapter.ensure_ghcup", "target.parent.mkdir")
  , ("BootstrapAdapter.ensure_ghcup", "target.read_bytes")
  , ("BootstrapAdapter.ensure_ghcup", "target.write_bytes")
  , ("BootstrapAdapter.ensure_ghcup", "urllib.request.urlopen")
  , ("BootstrapAdapter.environment", "cache.mkdir")
  , ("BootstrapAdapter.environment", "home.mkdir")
  , ("BootstrapAdapter.environment", "str")
  , ("BootstrapAdapter.environment", "temporary.mkdir")
  , ("BootstrapAdapter.handoff", "os.execv")
  , ("BootstrapAdapter.platform", "platform.machine")
  , ("BootstrapAdapter.platform", "platform.system")
  , ("BootstrapAdapter.repository_root", ".resolve")
  , ("BootstrapAdapter.repository_root", "Path")
  , ("BootstrapAdapter.run", "subprocess.run")
  , ("bootstrap", "adapter.capture")
  , ("bootstrap", "adapter.ensure_ghcup")
  , ("bootstrap", "adapter.environment")
  , ("bootstrap", "adapter.handoff")
  , ("bootstrap", "adapter.platform")
  , ("bootstrap", "adapter.repository_root")
  , ("bootstrap", "adapter.run")
  , ("bootstrap", "binary_bytes.decode")
  , ("bootstrap", "binary_text.strip")
  , ("bootstrap", "select_artifact")
  , ("bootstrap", "str")
  , ("main", "BootstrapAdapter")
  , ("main", "bootstrap")
  , ("module", "main")
  , ("select_artifact", "RuntimeError")
  ]

expectedBootstrapEffects :: [(Text, Text)]
expectedBootstrapEffects =
  [ ("BootstrapAdapter.capture", "subprocess.run")
  , ("BootstrapAdapter.ensure_ghcup", "response.read")
  , ("BootstrapAdapter.ensure_ghcup", "target.chmod")
  , ("BootstrapAdapter.ensure_ghcup", "target.is_file")
  , ("BootstrapAdapter.ensure_ghcup", "target.parent.mkdir")
  , ("BootstrapAdapter.ensure_ghcup", "target.read_bytes")
  , ("BootstrapAdapter.ensure_ghcup", "target.write_bytes")
  , ("BootstrapAdapter.ensure_ghcup", "urllib.request.urlopen")
  , ("BootstrapAdapter.environment", "cache.mkdir")
  , ("BootstrapAdapter.environment", "home.mkdir")
  , ("BootstrapAdapter.environment", "temporary.mkdir")
  , ("BootstrapAdapter.handoff", "os.execv")
  , ("BootstrapAdapter.platform", "platform.machine")
  , ("BootstrapAdapter.platform", "platform.system")
  , ("BootstrapAdapter.repository_root", ".resolve")
  , ("BootstrapAdapter.run", "subprocess.run")
  ]

expectedChallengeTags :: [(Text, Text)]
expectedChallengeTags =
  [ ("python", "NonHaskellSource")
  , ("dhall", "ForeignSourceOwed")
  , ("pulumi", "TrackedPulumiProgram")
  , ("ordinal", "OrdinalRuntimeIdentity")
  , ("unmapped", "UnmappedHaskellSource")
  , ("vendor", "UnmappedHaskellSource")
  , ("syntax", "HaskellSourceUnparsable")
  ]

-- Independently close the reported unique call edges back from parsed IO seeds.
effectRouteClosure :: Ord node => Set.Set (node, node) -> Set.Set node -> Set.Set node
effectRouteClosure edges seeds = walk seeds (Set.toList seeds)
 where
  reverseEdges = Map.fromListWith Set.union
    [(callee, Set.singleton caller) | (caller, callee) <- Set.toList edges]
  walk visited [] = visited
  walk visited (callee : remaining) =
    let next = Map.findWithDefault Set.empty callee reverseEdges `Set.difference` visited
    in walk (Set.union visited next) (Set.toList next <> remaining)

componentClosureFromLinks :: Map Text (Set.Set Text) -> Text -> Set.Set Text
componentClosureFromLinks links start = walk Set.empty [start]
 where
  walk visited [] = visited
  walk visited (component : rest)
    | component `Set.member` visited = walk visited rest
    | otherwise = walk (Set.insert component visited)
        (Set.toList (Map.findWithDefault Set.empty component links) <> rest)

pathMatches :: Text -> Text -> Bool
pathMatches name path = case name of
  "python" -> "src/Challenge" `Text.isPrefixOf` path && ".py" `Text.isSuffixOf` path
  "dhall" -> "dhall/Challenge" `Text.isPrefixOf` path && ".dhall" `Text.isSuffixOf` path
  "pulumi" -> "pulumi/Pulumi" `Text.isPrefixOf` path && ".yaml" `Text.isSuffixOf` path
  "ordinal" -> "src/Amoebius/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  "unmapped" -> "src/Amoebius/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  "vendor" -> "src/vendor/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  "syntax" -> "test/negative/Challenge" `Text.isPrefixOf` path && ".hs" `Text.isSuffixOf` path
  _ -> False

expectedClass :: FilePath -> Text
expectedClass path
  | path `elem` ["amoebius.cabal", "cabal.project", "probe/probe.cabal"] = "build-metadata"
  | path `elem` [".gitignore", ".dockerignore", "LICENSE"] = "repository-metadata"
  | path == "pb/__main__.py" = "bootstrap-source"
  | path `elem` ["AGENTS.md", "CLAUDE.md", "README.md"] = "governance-document"
  | headFolder path `elem` ["DEVELOPMENT_PLAN", "documents"] && takeExtension path == ".md" = "governance-document"
  | headFolder path `elem` ["src", "app", "test", "probe"] && takeExtension path == ".hs" = "haskell-source"
  | otherwise = "unclassified"

headFolder :: FilePath -> FilePath
headFolder = takeWhile (/= '/')

expectedCases :: [(Text, Text)]
expectedCases =
  [ ("positive.test-module", "haskell-source")
  , ("positive.probe-package", "build-metadata")
  , ("positive.bootstrap", "admitted")
  , ("positive.archive", "historical-evidence")
  , ("negative.test-script", "NonHaskellTestInput")
  , ("negative.test-table", "NonHaskellTestInput")
  , ("negative.python", "NonHaskellSource")
  , ("negative.dhall", "ForeignSourceOwed")
  , ("negative.pulumi", "TrackedPulumiProgram")
  , ("negative.tool", "TrackedToolRoot")
  , ("negative.archive", "UnexpectedValidationRecord")
  , ("negative.ordinal", "OrdinalRuntimeIdentity")
  , ("negative.absolute", "NonCanonicalPath")
  , ("positive.void", "historical-evidence")
  , ("negative.void-extra", "UnexpectedValidationRecord")
  , ("negative.bootstrap-change", "BootstrapDigestMismatch")
  , ("negative.bootstrap-import", "BootstrapImportRefusal")
  , ("negative.bootstrap-syntax", "BootstrapSyntaxRefusal")
  , ("negative.bootstrap-indentation", "BootstrapSyntaxRefusal")
  , ("negative.bootstrap-control", "BootstrapControlFlowRefusal")
  , ("negative.bootstrap-dynamic", "BootstrapDynamicCall")
  , ("negative.bootstrap-call", "BootstrapUnresolvedCall")
  , ("negative.bootstrap-indirect", "BootstrapUnresolvedCall")
  , ("negative.bootstrap-comprehension", "BootstrapSyntaxRefusal")
  , ("negative.bootstrap-effect", "BootstrapEffectOutsideAdapter")
  , ("negative.bootstrap-nested-effect", "BootstrapEffectOutsideAdapter")
  , ("negative.bootstrap-effect-string", "BootstrapDigestMismatch")
  , ("negative.ignore-root", "RetiredIgnoreRoot")
  , ("negative.ignore-source", "UnexpectedIgnorePattern")
  , ("report.bad-options", "exit-2")
  , ("report.nested-output", "success")
  , ("report.shebang-exit", "exit-1")
  , ("report.default-exit", "success")
  , ("graph.local-link", "linked")
  , ("graph.ambiguous-import", "refused")
  , ("graph.component-select", "selected")
  , ("graph.dependency-link", "linked")
  , ("graph.unlisted-dependency", "refused")
  , ("graph.inaccessible-internal", "located")
  , ("graph.package-qualified", "external")
  , ("graph.external-unit", "resolved")
  , ("graph.external-call-candidate", "candidate")
  , ("graph.external-member-parent", "matched")
  , ("graph.available-member-parent", "matched")
  , ("graph.external-open-import-call", "unattributed")
  , ("graph.implicit-prelude-export", "candidate")
  , ("graph.available-prelude-export", "candidate")
  , ("graph.standalone-prelude-export", "candidate")
  , ("graph.standalone-wired-cons", "candidate")
  , ("graph.open-import-interface-export", "filtered")
  , ("graph.external-hiding-import", "filtered")
  , ("graph.no-implicit-prelude", "suppressed")
  , ("graph.wired-cons-no-prelude", "candidate")
  , ("graph.wired-tuple-constructor", "candidate")
  , ("graph.open-import-call-opaque", "accounted")
  , ("graph.unplanned-component", "located")
  , ("graph.forward-owned-import", "owned")
  , ("graph.unselected-unit-candidate", "candidate")
  , ("graph.available-unit-interface", "resolved")
  , ("graph.available-unit-call", "exported")
  , ("graph.deferred-seed-import", "owned")
  , ("graph.deferred-seed-call", "bounded")
  , ("graph.deferred-seed-owner-filter", "filtered")
  , ("graph.deferred-seed-indirect-owner", "bound")
  , ("graph.package-plan-mismatch", "refused")
  , ("graph.package-unit-missing", "refused")
  , ("graph.imported-call-candidate", "candidate")
  , ("graph.class-method-import", "bound")
  , ("graph.instance-source-contract", "bound")
  , ("graph.class-call-dispatch", "potential")
  , ("graph.record-dot-selector", "projected")
  , ("graph.module-reexport-call", "traced")
  , ("graph.alias-reexport-call", "traced")
  , ("graph.qualified-reexport-filter", "filtered")
  , ("graph.explicit-reexport-call", "traced")
  , ("graph.explicit-data-reexport", "traced")
  , ("graph.hidden-reexport-filter", "selective")
  , ("graph.direct-hiding-selective", "selective")
  , ("graph.hiding-type-constructor", "filtered")
  , ("graph.unique-internal-call", "unique")
  , ("graph.ambiguous-internal-call", "ambiguous")
  , ("graph.shadow-no-internal-call", "absent")
  , ("graph.alias-call-candidate", "candidate")
  , ("graph.alias-imported-call", "linked")
  , ("graph.alias-imported-effect-route", "potential")
  , ("graph.filtered-call", "absent")
  , ("graph.no-component", "accounted")
  , ("graph.standalone-local-call", "candidate")
  , ("graph.standalone-lexical-call", "bound")
  , ("graph.standalone-imported-call", "exported")
  , ("graph.standalone-source-denied", "provisional")
  , ("graph.standalone-external-call", "exported")
  , ("graph.standalone-registered-only", "provisional")
  , ("graph.standalone-external-member", "matched")
  , ("graph.module-path-mismatch", "refused")
  , ("graph.local-call", "candidate")
  , ("graph.local-alias-route", "linked")
  , ("graph.alias-parameter-route", "bounded")
  , ("graph.alias-pattern-filter", "bounded")
  , ("graph.alias-qualified-route", "bounded")
  , ("graph.alias-external-interface", "filtered")
  , ("graph.type-signature", "located")
  , ("graph.effect-type-seed", "potential")
  , ("graph.effect-route-candidate", "potential")
  , ("graph.distinct-call-sites", "distinct")
  , ("graph.local-binding-call", "candidate")
  , ("graph.shadowed-call", "lexical")
  , ("graph.lexical-local-binding", "bound")
  , ("graph.lexical-parameter-binding", "bound")
  , ("graph.parameter-shadow", "lexical")
  , ("graph.case-shadow", "lexical")
  , ("graph.if-control-edges", "linked")
  , ("graph.case-control-edges", "linked")
  , ("graph.do-control-edges", "linked")
  , ("graph.guard-control-edges", "linked")
  , ("graph.do-shadow", "lexical")
  , ("graph.guard-shadow", "lexical")
  , ("graph.nested-call-coverage", "accounted")
  , ("graph.implicit-sequence-call", "projected")
  , ("graph.pattern-binding", "accounted")
  , ("graph.declaration-gap", "accounted")
  , ("graph.plain-data-declaration", "projected")
  , ("graph.class-default-call", "accounted")
  , ("graph.instance-method-call", "accounted")
  , ("graph.instance-declaration", "projected")
  , ("graph.data-symbols", "accounted")
  , ("graph.derived-class-head", "projected")
  , ("graph.derived-interface-members", "bounded")
  , ("graph.data-call-candidates", "candidate")
  , ("graph.record-constructor-call", "candidate")
  , ("graph.higher-order-reference", "accounted")
  , ("graph.explicit-member-import", "candidate")
  , ("graph.explicit-member-filter", "filtered")
  , ("graph.unexported-member", "absent")
  , ("graph.imported-value-reference", "candidate")
  , ("graph.expression-splice", "located")
  , ("graph.declaration-splice", "located")
  , ("graph.foreign-boundary", "located")
  , ("graph.standalone-deriving", "accounted")
  , ("graph.standalone-deriving-member", "bounded")
  , ("challenge.python", "exit-1")
  , ("challenge.dhall", "exit-1")
  , ("challenge.pulumi", "exit-1")
  , ("challenge.ordinal", "exit-1")
  , ("challenge.unmapped", "exit-1")
  , ("challenge.vendor", "exit-1")
  , ("challenge.syntax", "exit-1")
  , ("owner.dhall", "typed_spine")
  , ("owner.proto", "typed_spine")
  , ("owner.ui-language", "ui_program_language_binding")
  , ("owner.ui-artifact", "ui_program_release")
  , ("identity.layout", "2")
  , ("fork.paths", Text.intercalate "," (map Text.pack (sort expectedForkPaths)))
  , ("fork.provenance", "matched")
  ]

expectedForkPaths :: [FilePath]
expectedForkPaths = map ("src/vendor/" <>)
  ["Control/Category/Dual.hs", "Data/Bifunctor/Flip.hs", "Pulsar.hs",
   "Pulsar/AppState.hs", "Pulsar/Connection.hs", "Pulsar/Consumer.hs",
   "Pulsar/Core.hs", "Pulsar/Internal/Core.hs", "Pulsar/Internal/Logger.hs",
   "Pulsar/Internal/TCPClient.hs", "Pulsar/Producer.hs", "Pulsar/Protocol/CheckSum.hs",
   "Pulsar/Protocol/Commands.hs", "Pulsar/Protocol/Decoder.hs", "Pulsar/Protocol/Encoder.hs",
   "Pulsar/Protocol/Frame.hs", "Pulsar/Types.hs"]

expectedStandaloneRole :: Text -> Maybe Text
expectedStandaloneRole path
  | Text.unpack path `elem` expectedForkPaths = Just "maintained-fork"
  | "test/negative/" `Text.isPrefixOf` path = Just "compile-negative"
  | "test/fixture/" `Text.isPrefixOf` path = Just "fixture"
  | "test/mutant/" `Text.isPrefixOf` path = Just "mutant-source"
  | "test/spec/dsl/compile/" `Text.isPrefixOf` path = Just "compile-positive"
  | "test/spec/dsl/compilefail/" `Text.isPrefixOf` path = Just "compile-negative"
  | "test/spec/dsl/capacity_topology_compile_fail/" `Text.isPrefixOf` path = Just "compile-negative"
  | path == "test/spec/formal/refinement/RefinementModelProjection.hs" = Just "model-projection"
  | path == "test/spec/formal/symbolic/FakeSmtSolver.hs" = Just "fake-boundary"
  | otherwise = Nothing

parsePairs :: Text -> Map Text Text
parsePairs contents = Map.fromList [(name, Text.intercalate "\t" rest) | line <- Text.lines contents, (name : rest) <- [Text.splitOn "\t" line]]

parseChallenges :: Text -> [(Text, Text, Text)]
parseChallenges contents = [(name, path, tag) | line <- Text.lines contents, [name, path, tag] <- [Text.splitOn "\t" line]]

readChallengeFinding :: FilePath -> (Text, Text, Text) -> IO (Text, Text, Text, [Text])
readChallengeFinding directory (name, path, tag) = do
  rows <- Text.lines <$> TextIO.readFile (directory </> "challenge-" <> Text.unpack name <> ".tsv")
  pure (name, path, tag, filter ("finding\t" `Text.isPrefixOf`) rows)

renderCheck :: (Text, Bool, Text) -> Text
renderCheck (name, green, observed) = Text.intercalate "\t" [name, if green then "green" else "red", observed]
