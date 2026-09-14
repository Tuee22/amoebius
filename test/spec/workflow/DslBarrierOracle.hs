{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored Phase-49 expectations. This module deliberately
-- imports no production, fixture, or case module.
--
-- The oracle owns the meaning of every stage in the hardware-free spine: the
-- surface text that enters the decoder, the exact refusal each minimally
-- different illegal surface must produce, the service and object inventory the
-- bind/provision/render stages must yield for that surface, the ordered plan
-- the kernel must descend, and the argv and byte relay the fake application
-- boundary must perform. Digests are not stated here: a digest binds an
-- observation only after the subject has been compared against these
-- independent semantic declarations.
module DslBarrierOracle
  ( OracleStage (..)
  , expectedApplyIdentity
  , expectedBoundaryArgv
  , expectedDecodedController
  , expectedDecodedOwner
  , expectedDecodedSurface
  , expectedDecodedTenant
  , expectedFakeArgv
  , expectedLegalityRefusals
  , expectedMutantLabels
  , expectedNegativeLabels
  , expectedObjectIdentities
  , expectedPlanRows
  , expectedProvisionedServiceKeys
  , expectedPlanningTag
  , expectedStages
  , expectedToolInvocationCounts
  , illegalWorldSources
  , legalWorldSource
  , oracleNeedName
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

-- | The nine stages of the hardware-free spine, in the only admissible order.
data OracleStage
  = OracleDecode
  | OracleLegality
  | OracleBindExpand
  | OraclePlanResolve
  | OracleProvision
  | OracleRenderAll
  | OraclePlan
  | OracleDryRun
  | OracleFakeApply
  deriving stock (Bounded, Enum, Eq, Ord, Show)

expectedStages :: [OracleStage]
expectedStages = [minBound .. maxBound]

-- | The run-scoped identity carried from the decoded surface through bind,
-- provision, render and the applied bytes. The challenge is generated after
-- the fake boundary announces readiness, so this name cannot be predeclared.
oracleNeedName :: Text -> Text
oracleNeedName challenge = "p49-" <> challenge

-- | The identity prefix a recovered challenge must be found behind inside the
-- bytes the fake application boundary actually received.
expectedApplyIdentity :: Text
expectedApplyIdentity = "p49-"

expectedDecodedSurface, expectedDecodedController :: Text
expectedDecodedSurface = "Cluster"
expectedDecodedController = "Deployment"

expectedDecodedTenant, expectedDecodedOwner :: Text
expectedDecodedTenant = "phase49-tenant"
expectedDecodedOwner = "phase49-tenant"

-- | The legal surface the decoder must accept, parameterised by the run-scoped
-- identity so that no run reuses a previous run's decoded value.
legalWorldSource :: Text -> Text
legalWorldSource challenge =
  worldSource
    expectedDecodedSurface
    expectedDecodedController
    "Pod"
    "Vault"
    expectedDecodedTenant
    expectedDecodedOwner
    1
    (oracleNeedName challenge)

-- | Minimally different illegal surfaces and the exact refusal each must draw.
-- Every row changes exactly one field of the legal surface above.
illegalWorldSources :: Text -> [(Text, Text, Text)]
illegalWorldSources challenge =
  [ ( "unknown-surface"
    , worldSource "Unknown" expectedDecodedController "Pod" "Vault" expectedDecodedTenant expectedDecodedOwner 1 identity
    , "UnknownSurface"
    )
  , ( "unknown-controller"
    , worldSource expectedDecodedSurface "Unknown" "Pod" "Vault" expectedDecodedTenant expectedDecodedOwner 1 identity
    , "UnknownController"
    )
  , ( "unknown-resource-arm"
    , worldSource expectedDecodedSurface expectedDecodedController "Gpu" "Vault" expectedDecodedTenant expectedDecodedOwner 1 identity
    , "UnknownResourceArm"
    )
  , ( "empty-execution-id"
    , worldSource expectedDecodedSurface expectedDecodedController "Pod" "Vault" expectedDecodedTenant expectedDecodedOwner 1 ""
    , "EmptyExecutionId"
    )
  , ( "zero-revision"
    , worldSource expectedDecodedSurface expectedDecodedController "Pod" "Vault" expectedDecodedTenant expectedDecodedOwner 0 identity
    , "ZeroRevision"
    )
  , ( "tenant-mismatch"
    , worldSource expectedDecodedSurface expectedDecodedController "Pod" "Vault" expectedDecodedTenant "phase49-other" 1 identity
    , "TenantMismatch"
    )
  , ( "plaintext-secret"
    , worldSource expectedDecodedSurface expectedDecodedController "Pod" "PlainText" expectedDecodedTenant expectedDecodedOwner 1 identity
    , "PlaintextSecret"
    )
  , ( "resource-arm-mismatch"
    , worldSource expectedDecodedSurface expectedDecodedController "Host" "Vault" expectedDecodedTenant expectedDecodedOwner 1 identity
    , "ResourceArmMismatch"
    )
  , ("forbidden-environment-import", "env:AMOEBIUS_PHASE49", "ForbiddenImport")
  , ("forbidden-remote-import", "https://example.invalid/phase49.dhall", "ForbiddenImport")
  , ("malformed-surface", "{ this is not Dhall", "DhallFailure")
  ]
 where
  identity = oracleNeedName challenge

-- | The exact refusal tags, in order, the legality stage must observe.
expectedLegalityRefusals :: Text -> [(Text, Text)]
expectedLegalityRefusals challenge =
  [(name, tag) | (name, _, tag) <- illegalWorldSources challenge]

worldSource :: Text -> Text -> Text -> Text -> Text -> Text -> Integer -> Text -> Text
worldSource surface controller arm secret tenant owner revision executionId =
  "{ surface = \""
    <> surface
    <> "\", tenant = \""
    <> tenant
    <> "\", owner = \""
    <> owner
    <> "\", executionId = \""
    <> executionId
    <> "\", revision = "
    <> Text.pack (show revision)
    <> ", controller = \""
    <> controller
    <> "\", resourceArm = \""
    <> arm
    <> "\", secretKind = \""
    <> secret
    <> "\", secretValue = \"secret-ref\" }"

-- | The bind and provision stages must produce exactly one service, keyed by
-- the run-scoped identity.
expectedProvisionedServiceKeys :: Text -> [Text]
expectedProvisionedServiceKeys challenge = [oracleNeedName challenge]

-- | The supply presented to the resolver already holds the infrastructure, so
-- resolution must report that no infrastructure action is required.
expectedPlanningTag :: Text
expectedPlanningTag = "NoInfrastructureRequired"

-- | The whole-deployment render inventory for a single-node object store.
expectedObjectIdentities :: Text -> [Text]
expectedObjectIdentities challenge =
  [ "global/bootstrap-addon-cutover"
  , "global/capacity-scheduler"
  , "global/managed-capacity-admission"
  , "global/namespace"
  , "objectstore/" <> name <> "/config"
  , "objectstore/" <> name <> "/member-0"
  , "objectstore/" <> name <> "/service"
  ]
 where
  name = oracleNeedName challenge

-- | The ordered descent the kernel must plan for that inventory. Each row is
-- (position, label, activation frame, step kind).
expectedPlanRows :: Text -> [(Int, Text, Text, Text)]
expectedPlanRows challenge =
  zipWith
    (\position (label, frame) -> (position, label, frame, "ApplyObjects"))
    [1 ..]
    [ ("global/bootstrap-addon-cutover", "AfterBootstrapAddonCutoverFrame")
    , ("global/capacity-scheduler", "BootstrapSchedulerFrame")
    , ("global/managed-capacity-admission", "AfterManagedCapacityReadyFrame")
    , ("global/namespace", "ImmediateFrame")
    , ("objectstore/" <> name <> "/config", "ImmediateFrame")
    , ("objectstore/" <> name <> "/member-0", "AfterBootstrapAddonCutoverFrame")
    , ("objectstore/" <> name <> "/service", "AfterBootstrapAddonCutoverFrame")
    ]
 where
  name = oracleNeedName challenge

-- | The argv every fake boundary child must be observed to have received, in
-- invocation order. The application child is the first row.
expectedBoundaryArgv :: [(FilePath, [String])]
expectedBoundaryArgv =
  [ ("kubectl.1.argv", ["apply", "--server-side=true", "-f", "-"])
  , ("docker.1.argv", ["build", "--pull=false", "."])
  , ("docker.2.argv", ["push", "amoebius:test"])
  , ("pulumi.1.argv", ["up", "--yes", "--skip-preview"])
  ]

-- | The argv of the application child alone, as an ordered word list.
expectedFakeArgv :: [Text]
expectedFakeArgv = ["apply", "--server-side=true", "-f", "-"]

-- | Exactly how many times each fake tool must be observed to run. The helm
-- row is the zero-invocation control.
expectedToolInvocationCounts :: [(FilePath, Int)]
expectedToolInvocationCounts =
  [("kubectl", 1), ("docker", 2), ("helm", 0), ("pulumi", 1)]

expectedNegativeLabels :: [Text]
expectedNegativeLabels =
  [ "decode-failure"
  , "stage-inventory"
  , "demand-digest"
  , "provision-identity"
  , "fake-argv"
  , "fake-request"
  , "challenge"
  , "dry-run-effect"
  , "self-observer"
  , "teardown"
  , "workflow-evidence"
  , "workflow-balance"
  ]

expectedMutantLabels :: [Text]
expectedMutantLabels =
  [ "decoder-widening"
  , "legality-drop"
  , "bind-arm-swap"
  , "demand-omission"
  , "provision-identity-collapse"
  , "render-omission"
  , "plan-reorder"
  , "dry-run-execution"
  , "fake-call-bypass"
  , "workflow-observation-skip"
  , "teardown-leak"
  , "skip-mutant"
  ]
