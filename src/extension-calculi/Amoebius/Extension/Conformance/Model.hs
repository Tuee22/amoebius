{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Conditional, finite Register-1 models over actual declarations. This is
-- not authenticated execution or a proof of C1. In particular, the compiler
-- premise must also be observed with native client pairs by the parent gate.
-- No fixture name or number of generated cases supplies a law result here.
module Amoebius.Extension.Conformance.Model
  ( CompilerPremise (..), ModelRefusal (..), modelRefusalTag
  , ModeledLinkSet, qualifyDeclarations, modeledDeclarations, modeledRows, modeledFiles
  , declarationObservations, compositionObservations, securityObservations
  , securityCoverage, ModelLaw (..), bindModelLaws
  ) where

import Amoebius.Calculus.Budget.Admission qualified as Admission
import Amoebius.Calculus.Budget.Grant qualified as Budget
import Amoebius.Calculus.Budget.Retention qualified as Retention
import Amoebius.Calculus.Evidence.Claim qualified as Evidence
import Amoebius.Calculus.Evidence.Fixture qualified as Fixture
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Capacity.Vector (addResources)
import Amoebius.Extension.Conformance.Gate qualified as Gate
import Amoebius.Extension.Declaration
import Amoebius.Extension.Laws.Compositional qualified as C
import Amoebius.Extension.Laws.PerExtension qualified as L
import Amoebius.Extension.Laws.Security qualified as S
import Amoebius.Scope.Attested qualified as Scope
import Amoebius.Scope.Flow qualified as Flow
import Amoebius.Vocabulary (mkExtensionId)
import Control.Monad (foldM)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Either (isLeft, isRight)
import Data.List (sort, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Text.Read (readMaybe)

-- This value declares a premise; it is deliberately not named an observation,
-- receipt or proof. No in-process value authenticates compiler execution.
data CompilerPremise = NativeScopeClientsRequired | MissingCompilerPremise
  deriving (Eq, Show)

data ModelRefusal
  = NativeCompilerBoundaryRequired
  | InvalidModelDeclaration Text
  | MissingLawObservation [ModelLaw]
  | DuplicateLawObservation [ModelLaw]
  | ModeledLawFailed [ModelLaw]
  | RefusalProbeCoverageMismatch
  | NamespaceProbeCoverageMismatch
  | AuthorityProbeCoverageMismatch
  | ModelGateRefused Gate.GateRunError
  | ModelAdmissionRefused Gate.AdmissionError
  deriving (Eq, Show)

modelRefusalTag :: ModelRefusal -> Text
modelRefusalTag problem = case problem of
  NativeCompilerBoundaryRequired -> "NativeCompilerBoundaryRequired"
  InvalidModelDeclaration _ -> "InvalidModelDeclaration"
  MissingLawObservation _ -> "MissingLawObservation"
  DuplicateLawObservation _ -> "DuplicateLawObservation"
  ModeledLawFailed _ -> "ModeledLawFailed"
  RefusalProbeCoverageMismatch -> "RefusalProbeCoverageMismatch"
  NamespaceProbeCoverageMismatch -> "NamespaceProbeCoverageMismatch"
  AuthorityProbeCoverageMismatch -> "AuthorityProbeCoverageMismatch"
  ModelGateRefused failure -> case failure of
    Gate.GeneratedSuiteMismatch _ _ -> "GeneratedSuiteMismatch"
    Gate.CaseInventoryMismatch _ _ -> "CaseInventoryMismatch"
    Gate.CasesFailed _ -> "CasesFailed"
  ModelAdmissionRefused failure -> case failure of
    Gate.PlanDeclarationMismatch _ _ -> "PlanDeclarationMismatch"
    Gate.VerdictDidNotVerify -> "VerdictDidNotVerify"
    Gate.ExtensionAlreadyAdmitted _ -> "ExtensionAlreadyAdmitted"

type role ModeledLinkSet nominal
data ModeledLinkSet scope = ModeledLinkSet !(Gate.LinkSet scope)
  ![ExtensionDeclaration scope] ![(Text, Text)] ![(FilePath, ByteString)]

modeledDeclarations :: ModeledLinkSet scope -> [ExtensionDeclaration scope]
modeledDeclarations (ModeledLinkSet _ declarations _ _) = declarations

modeledRows :: ModeledLinkSet scope -> [(Text, Text)]
modeledRows (ModeledLinkSet _ _ observations _) = observations

modeledFiles :: ModeledLinkSet scope -> [(FilePath, ByteString)]
modeledFiles (ModeledLinkSet _ _ _ files) = files

-- A law key includes its declaration/peer axis. A missing or duplicated row
-- refuses before the pure generated-suite runner receives any CasePassed.
data ModelLaw = ModelLaw !Text !Text !(Maybe Text)
  deriving (Eq, Ord, Show)

bindModelLaws
  :: Gate.GatePlan scope -> [(ModelLaw, Bool)]
  -> Either ModelRefusal [Gate.ObservedCase]
bindModelLaws plan observations
  | not (null duplicates) = Left (DuplicateLawObservation duplicates)
  | sort expected /= sort actual = Left (MissingLawObservation expected)
  | not (null failures) = Left (ModeledLawFailed failures)
  | otherwise = Right [Gate.ObservedCase (Gate.gateCaseId entry) Gate.CasePassed | entry <- Gate.gatePlanCases plan]
 where
  key entry = ModelLaw (Gate.gateCaseLaw entry) (Gate.gateCaseAxis entry) (Gate.gateCasePeerDigest entry)
  expected = map key (Gate.gatePlanCases plan)
  actual = map fst observations
  duplicates = Map.keys (Map.filter (> (1 :: Int)) (Map.fromListWith (+) [(entry, 1) | entry <- actual]))
  failures = [entry | (entry, False) <- observations]

qualifyDeclarations
  :: CompilerPremise -> Scope.RequestScope scope -> [ExtensionDeclaration scope]
  -> Either ModelRefusal (ModeledLinkSet scope)
qualifyDeclarations premise scope declarations
  | premise == MissingCompilerPremise = Left NativeCompilerBoundaryRequired
  | null declarations = Left (InvalidModelDeclaration "empty link set")
  | any (isNothing . mkExtensionId . extensionName) declarations = Left (InvalidModelDeclaration "invalid member name")
  | otherwise = do
      version <- maybe (Left (InvalidModelDeclaration "empty core version")) Right
        (Gate.coreVersion "amoebius-finite-conformance-v1")
      security <- securityObservations premise scope
      let securityResults = S.evaluateSecurityLaws security
      (links, rows, files) <- foldM (admit version securityResults) (Gate.emptyLinkSet, [], []) declarations
      Right (ModeledLinkSet links declarations
        ([("premise.compiler-correctness", "assumed"),
          ("premise.native-scope-client-pairs-required", "parent-gate-obligation"),
          ("premise.observer-authentication-unverified", "unverified"),
          ("premise.sha256-collision-resistance", "assumed")] <> rows) files)
 where
  admit version securityResults (links, rows, files) declaration = do
    observations <- declarationObservations scope declaration
    let peers = filter ((/= declarationDigest declaration) . declarationDigest) declarations
        plan = Gate.deriveGatePlan version declaration peers
        vocabulary = L.declarationVocabulary declaration
        laws = L.evaluateLaws declaration observations
        propertyAxes = [(L.L1, L.vocabularyOperationNames vocabulary),
          (L.L2, L.vocabularyArtifactNames vocabulary), (L.L3, L.vocabularyBudgetNames vocabulary),
          (L.L4, L.vocabularyOperationNames vocabulary), (L.L5, L.vocabularyClaimNames vocabulary)]
        propertyResults = [(ModelLaw (L.lawTag law) axis Nothing, maybe False L.lawPassed (lookup law laws))
          | (law, axes) <- propertyAxes, axis <- axes]
        securityRows = [(ModelLaw (S.securityLawTag law) "security-boundary" Nothing, S.securityLawPassed verdict)
          | (law, verdict) <- securityResults]
        compileRows = [(ModelLaw "compile" claim Nothing, premise == NativeScopeClientsRequired)
          | claim <- L.vocabularyClaimNames vocabulary]
    compositionRows <- concat <$> traverse (pairResults declaration) peers
    let results = propertyResults <> compositionRows <> securityRows <> compileRows
    cases <- bindModelLaws plan results
    verdict <- first ModelGateRefused (Gate.runGeneratedGate plan (Gate.generatedFiles plan) cases)
    next <- first ModelAdmissionRefused (Gate.admitExtension plan declaration verdict links)
    let prefix = extensionName declaration <> "."
    Right (next, rows <>
      [(prefix <> "declaration", declarationDigest declaration),
       (prefix <> "suite", Gate.gatePlanSuiteDigest plan),
       (prefix <> "verdict", Gate.verdictDigest verdict),
       (prefix <> "cases", decimal (length cases)),
       (prefix <> "coverage", decimal (length (Gate.gatePlanCoverage plan))),
       (prefix <> "files", decimal (length (Gate.generatedFiles plan)))] <>
      [(prefix <> lawKey key, if passed then "model-passed" else "model-failed") | (key, passed) <- results],
      files <> [(Text.unpack (extensionName declaration <> "/" <> Gate.generatedPath file), Gate.generatedBytes file) | file <- Gate.generatedFiles plan])
  pairResults left right = do
    -- C3 is observed with every actual third operand, including the two
    -- repeated-operand triples, rather than selecting one convenient peer.
    runs <- traverse (compositionObservations scope left right) declarations
    let evaluated = [C.evaluateCompositionLaws (C.singletonComposite left) (C.singletonComposite right)
          (C.singletonComposite third) observations | (third, observations) <- zip declarations runs]
    Right [(ModelLaw (C.compositionLawTag law) (extensionName right) (Just (declarationDigest right)),
      all (maybe False C.compositionLawPassed . lookup law) evaluated) | law <- C.everyCompositionLaw]
  lawKey (ModelLaw law axis peer) = "law." <> law <> "." <> axis <> maybe "" ("." <>) peer

declarationObservations
  :: Scope.RequestScope scope -> ExtensionDeclaration scope
  -> Either ModelRefusal L.LawObservations
declarationObservations scope declaration = do
  let vocabulary = L.declarationVocabulary declaration
      operations = L.vocabularyOperationNames vocabulary
      artifacts = L.vocabularyArtifactNames vocabulary
      budgets = L.vocabularyBudgetNames vocabulary
      claims = L.vocabularyClaimNames vocabulary
      replay name = Scope.reenter scope (Scope.persist scope name (Scope.scoped scope (declarationDigest declaration)))
      operation name = L.OperationObservation name "declaration-plan" $ case replay name of
        Left problem -> L.OperationRefused (Text.pack (show problem))
        Right value -> L.OperationReturned (Scope.scopedValue value)
  budgetObservations <- case (artifacts, budgets, Set.toList (declarationBudgetSet declaration)) of
    ([artifact], [budget], [component]) -> (: []) <$> budgetObservation artifact budget component
    _ -> Left (InvalidModelDeclaration "budget/artifact inventory")
  let label = Flow.subjectLabel scope (Scope.scopeSubject scope) Flow.HighIntegrity Flow.TrustedServer
      path = do
        value <- first (const Flow.SubjectFlowMismatch) label
        Flow.checkFlowPath (Map.fromList [("source", value), ("workflow", value), ("sink", value)])
          [("source", "workflow"), ("workflow", "sink")] "source" "sink"
      sink = if either (const False) ((== 2) . length) path then L.RequestFlow else L.GlobalFlow
      fixturePath = "Amoebius.Dsl.Examples.Extensions.SourceInputs/native-scope-client-pairs"
      pinnedClaim name = do
        fixture <- Fixture.fixture Fixture.CompileFail fixturePath PureRegister
        either (const Nothing) Just (Evidence.claim name fixture Fixture.ThisExpressionRejected)
      claimObservation name = L.ClaimObservation name $ case pinnedClaim name of
        Nothing -> L.FixtureMissing
        Just claim -> L.FixturePassedAtPinnedReason (Fixture.fixturePath (Evidence.claimFixture claim))
  Right L.LawObservations
    { L.observedOperations = map operation operations
    , L.observedArtifacts = [L.ArtifactObservation name (renderDeclaration scope declaration) (renderDeclaration scope declaration) | name <- artifacts]
    , L.observedBudgets = budgetObservations
    , L.observedFlows = [L.FlowObservation name L.RequestFlow sink | name <- operations]
    -- The model binds the declared native-fixture premise. Its actual
    -- execution is a separate, mandatory parent-gate observation.
    , L.observedClaims = map claimObservation claims
    }

budgetObservation :: Text -> Text -> DeclaredComponent -> Either ModelRefusal L.BudgetObservation
budgetObservation artifact name component = case declaredIdentityFields component of
  ["allowance", ceilingText, concurrencyText, temporaryText] -> do
    ceilingBytes <- parse ceilingText
    concurrent <- parse concurrencyText
    temporary <- parse temporaryText
    let location = Budget.Location name
        granted = Budget.allowance (Budget.Bytes ceilingBytes) (Budget.Slots concurrent) (Budget.Bytes temporary)
    (grant, _) <- first (const invalid) (Budget.issue
      (Budget.pool location (Budget.Bytes ceilingBytes) (Budget.Slots concurrent)) Budget.ArtifactStore granted)
    let exhausted = Admission.admit (Admission.holding grant (Budget.Bytes ceilingBytes) (Budget.Slots concurrent))
          (Admission.Demand location Budget.ArtifactStore (Budget.Bytes temporary))
        result = if isLeft exhausted then L.RefusedBeforeMaterialization else L.ExhaustionWasNotRefused
    retention <- first (const invalid) (Retention.retain grant (Budget.Bytes (min ceilingBytes temporary))
      (Retention.DependentLifetime "declaration-plan"))
    Right (L.BudgetObservation artifact name result
      (L.RetainedWithReaper (Retention.reaperTag (Retention.retentionReaper retention))))
  _ -> Left invalid
 where
  invalid = InvalidModelDeclaration ("allowance: " <> name)
  parse :: Read number => Text -> Either ModelRefusal number
  parse = maybe (Left invalid) Right . readMaybe . Text.unpack

compositionObservations
  :: Scope.RequestScope scope -> ExtensionDeclaration scope -> ExtensionDeclaration scope
  -> ExtensionDeclaration scope -> Either ModelRefusal (C.CompositionObservations scope)
compositionObservations scope firstDeclaration secondDeclaration thirdDeclaration = do
  firstPart <- declarationObservations scope firstDeclaration
  secondPart <- declarationObservations scope secondDeclaration
  let left = C.singletonComposite firstDeclaration
      right = C.singletonComposite secondDeclaration
      third = C.singletonComposite thirdDeclaration
      pair = C.composeComposites left right
      combined = combineObservations firstPart secondPart
  Right C.CompositionObservations
    { C.compositeLawObservations = combined
    , C.partObservations = [C.PartObservation (declarationDigest firstDeclaration) firstPart,
        C.PartObservation (declarationDigest secondDeclaration) secondPart]
    , C.observedLeftIdentity = C.composeComposites C.emptyComposite pair
    , C.observedRightIdentity = C.composeComposites pair C.emptyComposite
    , C.observedAssociationLeft = C.composeComposites (C.composeComposites left right) third
    , C.observedAssociationRight = C.composeComposites left (C.composeComposites right third)
    , C.observedCompositeResource = addResources (declarationResource firstDeclaration) (declarationResource secondDeclaration)
    , C.observedArtifactAddresses = [C.ArtifactAddressObservation (L.artifactName artifact)
        (C.contentAddress (L.artifactFirstBytes artifact)) (L.artifactFirstBytes artifact) | artifact <- L.observedArtifacts combined]
    }

combineObservations :: L.LawObservations -> L.LawObservations -> L.LawObservations
combineObservations left right = L.LawObservations
  (ordered L.operationName (L.observedOperations left <> L.observedOperations right))
  (ordered L.artifactName (L.observedArtifacts left <> L.observedArtifacts right))
  (ordered L.budgetArtifact (L.observedBudgets left <> L.observedBudgets right))
  (ordered L.flowOperation (L.observedFlows left <> L.observedFlows right))
  (ordered L.claimName (L.observedClaims left <> L.observedClaims right))
 where ordered key = sortOn key

securityCoverage :: S.SecurityObservations -> Either ModelRefusal ()
securityCoverage observations
  | sort (map S.refusalOperation (S.refusalProbes observations)) /= [minBound .. maxBound] = Left RefusalProbeCoverageMismatch
  | sort (map S.namespaceKeyspace (S.namespaceProbes observations)) /= S.everyKeyspace = Left NamespaceProbeCoverageMismatch
  | map S.revocationLayerName (S.revocationProbes observations) /= ["request-grant"] = Left AuthorityProbeCoverageMismatch
  | otherwise = Right ()

securityObservations
  :: CompilerPremise -> Scope.RequestScope scope -> Either ModelRefusal S.SecurityObservations
securityObservations premise scope = do
  if premise == NativeScopeClientsRequired then Right () else Left NativeCompilerBoundaryRequired
  resource <- first (InvalidModelDeclaration . Text.pack . show) (Scope.trustedResourceId "model-resource")
  grantSubject <- first (InvalidModelDeclaration . Text.pack . show)
    (Scope.trustedSubject (Scope.scopeTenant scope) (if Scope.subjectText (Scope.scopeSubject scope) == "model-owner" then "model-other-owner" else "model-owner"))
  let tenant = Scope.tenantText (Scope.scopeTenant scope)
      subject = Scope.subjectText (Scope.scopeSubject scope)
      keyText = "bounded-conformance-model-key"
      signed = Scope.SignedIdentityEnvelope tenant subject (C.contentAddress (frame [keyText, tenant, subject]))
      verified = maybe (Left "missing key") (`Scope.verifyIdentity` signed) (Scope.verificationKey keyText)
      tampered = maybe (Left "missing key")
        (\key -> Scope.verifyIdentity key (signed {Scope.envelopeSignature = "tampered"})) (Scope.verificationKey keyText)
      store = S.insertResource tenant subject "own" "value"
        (S.insertResource (tenant <> "-foreign") subject "foreign" "value" S.emptySecurityStore)
      refusal operation =
        let foreignTrace = S.runScopedOperation scope operation "foreign" store
            absentTrace = S.runScopedOperation scope operation "absent" store
            bytes trace = either S.renderPublicRefusal Encoding.encodeUtf8 (S.operationResult trace)
            mutations trace = if S.operationStore trace == store then 0 else 1
         in S.RefusalProbe operation (bytes foreignTrace) (bytes absentTrace)
              (mutations foreignTrace) (mutations absentTrace) (S.operationSteps foreignTrace) (S.operationSteps absentTrace) 0
      namespace keyspace =
        let left = S.useScopedKey scope (S.renderScopedKey scope keyspace "plan:α")
            otherTenant = if tenant == "model-other-tenant" then "model-second-tenant" else "model-other-tenant"
            otherSigned = Scope.SignedIdentityEnvelope otherTenant subject (C.contentAddress (frame [keyText, otherTenant, subject]))
            otherIdentity = maybe (Left "missing key") (`Scope.verifyIdentity` otherSigned) (Scope.verificationKey keyText)
            otherKey = do
              identity <- otherIdentity
              first (Text.pack . show) (Scope.attest (Scope.principalAttestation identity) (\other ->
                S.useScopedKey other (S.renderScopedKey other keyspace "plan:α")))
            right = either (const "unattested") id otherKey
         in S.NamespaceProbe keyspace left right (isRightKey left) (isRightKey right)
      owner grant = Scope.grantOwner (Scope.scopeTenant scope) grantSubject grant
      granted = Scope.resolveOwned scope (owner Scope.activeGrant) resource
      revoked = Scope.resolveOwned scope (owner Scope.revokedGrant) resource
      revocation = S.RevocationProbe "request-grant" (Just (S.HasRevocationEdge "revoke-grant"))
        (isRight granted && case revoked of Left Scope.GrantRevoked -> True; _ -> False) False
      observations = S.SecurityObservations (isRight verified) (isLeft tampered)
        -- These two type properties are conditional compiler premises here;
        -- the parent gate must observe the paired native clients separately.
        True (premise == NativeScopeClientsRequired) 0 [minBound .. maxBound]
        (map refusal [minBound .. maxBound]) (map namespace S.everyKeyspace) [revocation]
  securityCoverage observations
  Right observations
 where
  isRightKey = maybe False (const True) . S.parseRenderedKey

renderDeclaration :: Scope.RequestScope scope -> ExtensionDeclaration scope -> ByteString
renderDeclaration scope declaration = frame
  (["declaration-plan/v1", Scope.scopeIssuer scope, Scope.scopeApplication scope, Scope.scopeNeed scope,
    extensionName declaration, declarationDigest declaration] <>
   concat [[declaredName component] <> declaredIdentityFields component | component <- declarationComponents declaration])

frame :: [Text] -> ByteString
frame = LazyByteString.toStrict . Builder.toLazyByteString . foldMap
  (\field -> let bytes = Encoding.encodeUtf8 field in
    Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes)

decimal :: Show number => number -> Text
decimal = Text.pack . show
