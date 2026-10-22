{-# LANGUAGE OverloadedStrings #-}

-- Observe the actual four-member declarations and pure model admission path.
-- Native compiler observations remain a separate section of the parent gate.
module SpineExtensionConformance (extensionConformanceSection) where

import Amoebius.Dsl.Examples.Extensions (extensionRoot)
import Amoebius.Dsl.Examples.Extensions.ConformanceInputs
import Amoebius.Dsl.Lower (Lowered (..), lowerDeployment)
import Amoebius.Extension.Calculi (instantiateDeclaration)
import Amoebius.Extension.Conformance.Gate qualified as Gate
import Amoebius.Extension.Conformance.Model qualified as Model
import Amoebius.Extension.Declaration
import Amoebius.Extension.Linked qualified as Linked
import Amoebius.Extension.Spec (extDeclaration)
import Amoebius.Scope.Attested qualified as Scope
import Amoebius.Capacity.Vector (ResourceVector (..), zeroResources, addResources)
import Amoebius.Capacity.Execution (BoundExecutionUnit (executionResource))
import Amoebius.Capacity.Types (envelopeRequests)
import Amoebius.Capability.Types (BoundServiceSpec (boundServiceExecutions), BoundExecutionSet (..), boundDeploymentServices)
import Amoebius.Extension.Config (ConfigSchema (InferenceConfig), parameterSchema)
import Amoebius.Extension.Laws.Compositional qualified as C
import Amoebius.Extension.Laws.PerExtension qualified as L
import Amoebius.Extension.Laws.Security qualified as S
import Amoebius.Vocabulary (EngineRuntime (CpuRuntime), Architecture (Amd64), Gpu (GpuAbsent))
import Control.Monad (forM_, void)
import Data.Bifunctor (first)
import Data.Map.Strict qualified as Map
import Data.ByteString qualified as ByteString
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>), takeDirectory)

extensionConformanceSection :: FilePath -> IO ()
extensionConformanceSection directory = do
  createDirectoryIfMissing True directory
  root <- either (fail . Text.unpack) pure (extensionRoot CpuRuntime Amd64 GpuAbsent)
  lowered <- either (fail . show) pure (lowerDeployment root)
  proof <- case [proof | proof <- Map.elems (loweredProofs lowered), Linked.bindingIssuer proof == "extension/infernix"] of
    [proof] -> pure proof
    _ -> fail "missing actual inference binding"
  entered <- either (fail . show) pure $ Scope.attest (Scope.bindingAttestation proof) $ \scope -> do
    let resources = case Map.lookup (Linked.bindingNeed proof) (boundDeploymentServices (loweredDeployment lowered)) of
          Nothing -> zeroResources
          Just service -> let BoundExecutionSet units = boundServiceExecutions service
            in foldl addResources zeroResources [envelopeRequests (executionResource unit) | unit <- Map.elems units]
    declarations <- either (fail . show) pure (traverse (\(specification, parameters) ->
      instantiateDeclaration (extDeclaration specification) scope parameters
        (if parameterSchema parameters == InferenceConfig then resources else zeroResources)) (loweredExtensions lowered))
    four <- either (fail . show) pure (Model.qualifyDeclarations Model.NativeScopeClientsRequired scope declarations)
    two <- either (fail . show) pure (Model.qualifyDeclarations Model.NativeScopeClientsRequired scope
      (filter ((`elem` ["infernix", "jitml"]) . extensionName) declarations))
    writeRows "four-member.tsv" (Model.modeledRows four)
    writeRows "two-member.tsv" (Model.modeledRows two)
    forM_ [("four-member", four), ("two-member", two)] $ \(label, modeled) ->
      forM_ (Model.modeledFiles modeled) $ \(path, bytes) -> do
        let target = directory </> label </> path
        createDirectoryIfMissing True (takeDirectory target)
        ByteString.writeFile target bytes
    case declarations of
      firstDeclaration : secondDeclaration : _ -> do
        version <- maybe (fail "missing core version") pure (Gate.coreVersion "amoebius-finite-conformance-v1")
        otherVersion <- maybe (fail "missing changed core version") pure (Gate.coreVersion "changed-core")
        let plan = Gate.deriveGatePlan version firstDeclaration (filter ((/= declarationDigest firstDeclaration) . declarationDigest) declarations)
            otherPlan = Gate.deriveGatePlan otherVersion firstDeclaration []
            cases = [Gate.ObservedCase (Gate.gateCaseId entry) Gate.CasePassed | entry <- Gate.gatePlanCases plan]
            laws = [(Model.ModelLaw (Gate.gateCaseLaw entry) (Gate.gateCaseAxis entry) (Gate.gateCasePeerDigest entry), True) | entry <- Gate.gatePlanCases plan]
            observe files rows = first Model.ModelGateRefused (Gate.runGeneratedGate plan files rows)
        baselineVerdict <- either (fail . show) pure (observe (Gate.generatedFiles plan) cases)
        baselineLinks <- either (fail . show) pure (Gate.admitExtension plan firstDeclaration baselineVerdict Gate.emptyLinkSet)
        security <- either (fail . show) pure (Model.securityObservations Model.NativeScopeClientsRequired scope)
        let controls input = case input of
              LegalModel -> void (Model.qualifyDeclarations Model.NativeScopeClientsRequired scope declarations)
              MissingLaw -> void (Model.bindModelLaws plan (drop 1 laws))
              DuplicateLaw -> void (Model.bindModelLaws plan (take 1 laws <> laws))
              FailedLaw -> void (Model.bindModelLaws plan (mapFirst (\(key, _) -> (key, False)) laws))
              MissingCompiler -> void (Model.qualifyDeclarations Model.MissingCompilerPremise scope declarations)
              MissingGeneratedFile -> void (observe (drop 1 (Gate.generatedFiles plan)) cases)
              MissingCase -> void (observe (Gate.generatedFiles plan) (drop 1 cases))
              DuplicateCase -> void (observe (Gate.generatedFiles plan) (take 1 cases <> cases))
              FailedCase -> void (observe (Gate.generatedFiles plan) (mapFirst (\row -> row {Gate.observedCaseResult = Gate.CaseFailed "bounded negative"}) cases))
              WrongDeclaration -> first Model.ModelAdmissionRefused (void (Gate.admitExtension plan secondDeclaration baselineVerdict Gate.emptyLinkSet))
              WrongCore -> first Model.ModelAdmissionRefused (void (Gate.admitExtension otherPlan firstDeclaration baselineVerdict Gate.emptyLinkSet))
              DuplicateAdmission -> first Model.ModelAdmissionRefused (void (Gate.admitExtension plan firstDeclaration baselineVerdict baselineLinks))
              MissingRefusalProbe -> Model.securityCoverage security {S.refusalProbes = drop 1 (S.refusalProbes security)}
              MissingNamespaceProbe -> Model.securityCoverage security {S.namespaceProbes = drop 1 (S.namespaceProbes security)}
              MissingAuthorityProbe -> Model.securityCoverage security {S.revocationProbes = []}
        writeRows "controls.tsv" [(conformanceInputName input, either Model.modelRefusalTag (const "accepted") (controls input)) | input <- conformanceInputs]
        forM_ declarations $ \declaration -> do
          observations <- either (fail . show) pure (Model.declarationObservations scope declaration)
          writeRows (Text.unpack (extensionName declaration) <> "-laws.tsv")
            [(L.lawTag law, if L.lawPassed result then "model-passed" else "model-failed") | (law, result) <- L.evaluateLaws declaration observations]
        composition <- either (fail . show) pure (Model.compositionObservations scope firstDeclaration secondDeclaration firstDeclaration)
        writeRows "composition.tsv" [(C.compositionLawTag law, if C.compositionLawPassed result then "model-passed" else "model-failed")
          | (law, result) <- C.evaluateCompositionLaws (C.singletonComposite firstDeclaration) (C.singletonComposite secondDeclaration)
              (C.singletonComposite firstDeclaration) composition]
        writeRows "security.tsv" [(S.securityLawTag law, if S.securityLawPassed result then "model-passed" else "model-failed") | (law, result) <- S.evaluateSecurityLaws security]
        firstObservations <- either (fail . show) pure (Model.declarationObservations scope firstDeclaration)
        writeRows "faults.tsv" [(lawFaultName input, Text.intercalate "," (faults firstDeclaration secondDeclaration input firstObservations composition security)) | input <- lawFaultInputs]
      _ -> fail "incomplete actual link set"
  entered
 where
  writeRows path rows = Text.writeFile (directory </> path) (Text.unlines [key <> "\t" <> value | (key, value) <- rows])
  mapFirst change values = case values of [] -> []; value : rest -> change value : rest

  faults firstDeclaration secondDeclaration input observations composition security = case input of
    L1Fault -> lFailures observations {L.observedOperations = mapFirst (\row -> row {L.operationOutcome = L.OperationEscaped "partial"}) (L.observedOperations observations)}
    L2Fault -> lFailures observations {L.observedArtifacts = mapFirst (\row -> row {L.artifactSecondBytes = "ambient"}) (L.observedArtifacts observations)}
    L3Fault -> lFailures observations {L.observedBudgets = mapFirst (\row -> row {L.budgetRetention = L.RetainedWithoutReaper}) (L.observedBudgets observations)}
    L4Fault -> lFailures observations {L.observedFlows = mapFirst (\row -> row {L.flowSink = L.GlobalFlow}) (L.observedFlows observations)}
    L5Fault -> lFailures observations {L.observedClaims = mapFirst (\row -> row {L.claimFixture = L.FixtureMissing}) (L.observedClaims observations)}
    C1Fault -> cFailures composition {C.partObservations = mapFirst (\row -> row {C.isolatedObservations = (C.isolatedObservations row)
      {L.observedOperations = mapFirst (\operation -> operation {L.operationOutcome = L.OperationEscaped "partial"}) (L.observedOperations (C.isolatedObservations row))}}) (C.partObservations composition)}
    C2Fault -> cFailures composition {C.observedLeftIdentity = C.emptyComposite}
    C3Fault -> cFailures composition {C.observedAssociationRight = C.emptyComposite}
    C4Fault -> cFailures composition {C.partObservations = mapFirst (\row -> row {C.isolatedObservations = (C.isolatedObservations row)
      {L.observedOperations = mapFirst (\operation -> operation {L.operationOutcome = L.OperationReturned "changed"}) (L.observedOperations (C.isolatedObservations row))}}) (C.partObservations composition)}
    C5Fault -> cFailures composition {C.observedCompositeResource = addResources (ResourceVector 1 0 0 0) (C.observedCompositeResource composition)}
    C6Fault -> cFailures composition {C.compositeLawObservations = (C.compositeLawObservations composition)
      {L.observedFlows = mapFirst (\row -> row {L.flowSink = L.GlobalFlow}) (L.observedFlows (C.compositeLawObservations composition))}}
    C7Fault -> cFailures composition {C.observedArtifactAddresses = mapFirst (\row -> row {C.observedAddress = "wrong"}) (C.observedArtifactAddresses composition)}
    S1Fault -> sFailures security {S.tamperedIdentityRefused = False}
    S2Fault -> sFailures security {S.skolemCompilerBarriersPassed = False}
    S3Fault -> sFailures security {S.exportedUnscopedOperationArms = 1}
    S4Fault -> sFailures security {S.refusalProbes = mapFirst (\row -> row {S.foreignRefusalBytes = "different"}) (S.refusalProbes security)}
    S5Fault -> sFailures security {S.namespaceProbes = mapFirst (\row -> row {S.namespaceRight = S.namespaceLeft row}) (S.namespaceProbes security)}
    S6Fault -> sFailures security {S.revocationProbes = mapFirst (\row -> row {S.revocationEdgeObserved = False}) (S.revocationProbes security)}
   where
    lFailures altered = [L.lawTag law | (law, verdict) <- L.evaluateLaws firstDeclaration altered, not (L.lawPassed verdict)]
    cFailures altered = [C.compositionLawTag law | (law, verdict) <- C.evaluateCompositionLaws
      (C.singletonComposite firstDeclaration) (C.singletonComposite secondDeclaration)
      (C.singletonComposite firstDeclaration) altered, not (C.compositionLawPassed verdict)]
    sFailures altered = [S.securityLawTag law | (law, verdict) <- S.evaluateSecurityLaws altered, not (S.securityLawPassed verdict)]
