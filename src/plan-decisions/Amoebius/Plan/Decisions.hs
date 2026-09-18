{-# LANGUAGE OverloadedStrings #-}

-- | The frozen governance baseline: the closed set of documents whose bodies change
-- only through a decision-log entry, each with the SHA-256 of its bytes with the
-- @**Referenced by**:@ line removed and the entry that last amended it
-- (@documentation_standards.md@ section 17, DL-0006 through DL-0010).
--
-- This module is data. Comparing the baseline with the tree, and refusing a body
-- change that lands without an entry, is the documentation checker's work.
module Amoebius.Plan.Decisions
  ( DecisionId (..)
  , FrozenRow (..)
  , allDecisionIds
  , decisionLogPath
  , frozenBaseline
  , frozenPaths
  , parseDecisionId
  , renderDecisionId
  ) where

import Data.Text (Text)

-- | Every entry of the decision log, in identifier order. The log is append-only, so
-- this enumeration only grows.
data DecisionId
  = DL0001
  | DL0002
  | DL0003
  | DL0004
  | DL0005
  | DL0006
  | DL0007
  | DL0008
  | DL0009
  | DL0010
  | DL0011
  | DL0012
  | DL0013
  | DL0014
  deriving (Bounded, Enum, Eq, Ord, Show)

allDecisionIds :: [DecisionId]
allDecisionIds = [minBound .. maxBound]

renderDecisionId :: DecisionId -> Text
renderDecisionId identifier = case identifier of
  DL0001 -> "DL-0001"
  DL0002 -> "DL-0002"
  DL0003 -> "DL-0003"
  DL0004 -> "DL-0004"
  DL0005 -> "DL-0005"
  DL0006 -> "DL-0006"
  DL0007 -> "DL-0007"
  DL0008 -> "DL-0008"
  DL0009 -> "DL-0009"
  DL0010 -> "DL-0010"
  DL0011 -> "DL-0011"
  DL0012 -> "DL-0012"
  DL0013 -> "DL-0013"
  DL0014 -> "DL-0014"

parseDecisionId :: Text -> Maybe DecisionId
parseDecisionId rendered =
  case [identifier | identifier <- allDecisionIds, renderDecisionId identifier == rendered] of
    [identifier] -> Just identifier
    _ -> Nothing

-- | The log itself is exempt from whole-file comparison; its entries are digested one by one.
decisionLogPath :: FilePath
decisionLogPath = "documents/decision_log.md"

data FrozenRow = FrozenRow
  { frozenPath :: FilePath
  , frozenDigest :: Text
  , frozenDecision :: DecisionId
  }
  deriving (Eq, Ord, Show)

frozenPaths :: [FilePath]
frozenPaths = map frozenPath frozenBaseline

-- | One row per frozen path, in path order. The digest is the lowercase SHA-256 of the
-- file bytes with the single @**Referenced by**:@ line (and its newline) removed.
frozenBaseline :: [FrozenRow]
frozenBaseline =
  [ FrozenRow "documents/README.md" "52457a50a9e279d1190bf63ac5d6ff0097a4f4f4cdc1fb6f6a5d535333c0a32a" DL0006
  , FrozenRow "documents/documentation_standards.md" "d7d369cac0007647790fd91b8c7692498073fe3d5b01fb7732dc5e580d44e5d4" DL0011
  , FrozenRow "documents/engineering/README.md" "cab4b86e5865d899685dc8c897d745b641c4f8ad49e3f791998dfbfc67b5b910" DL0013
  , FrozenRow "documents/engineering/app_vs_deployment_doctrine.md" "2dc44dae95dd21e1a2f4fbde0116bd2fa2d26ee19e4791afc96266fbeb192c78" DL0003
  , FrozenRow "documents/engineering/apple_metal_headless_builds.md" "b4522cdecff7d4e6dcfcec9989c9460ec39609ae3dfd6f08449c534ae3d4c282" DL0006
  , FrozenRow "documents/engineering/backup_recovery_doctrine.md" "eb228a7896f527a243d43783cb205e71f605f0de99fc76af45204cd9e2341252" DL0006
  , FrozenRow "documents/engineering/behavioural_verification_doctrine.md" "80054d24afbc2642a08023841a9a1e9abd29019ebff06d86957603ad0f78507b" DL0006
  , FrozenRow "documents/engineering/bootstrap_sequence_doctrine.md" "a07528ecbc9da5abce0791325a14e58d279817540932267675ef89bf68bb6bae" DL0006
  , FrozenRow "documents/engineering/browser_offline_runtime_doctrine.md" "7af404f6c058114d2839e36dc6d6b2809b3c5ccbcb4c869ae83794b39c985202" DL0006
  , FrozenRow "documents/engineering/capability_extension_doctrine.md" "9724107168ce05aceb057f415ecacd244e3667d67ac7f17ed7946a6ad59d3137" DL0002
  , FrozenRow "documents/engineering/chaos_failover_doctrine.md" "d777db9849af25cf38e04672cdb2dd71026447c6e82f00deea4d0c015838fb36" DL0006
  , FrozenRow "documents/engineering/chaos_failover_second_axis.md" "9f19f6261ca370b2ca4e5099805cc4b8c91c7a13ea39dcb3d242ec2d171ec128" DL0006
  , FrozenRow "documents/engineering/chaos_failover_worked_examples.md" "7fb041f3444bf05698a477f8403525dc4f1a109c57b0b234cab07afaf4d273b6" DL0006
  , FrozenRow "documents/engineering/cluster_lifecycle_doctrine.md" "6e720934dac98d9b93d6ae24d7855f7ea50268fefdbd9ff30eae091e8b281e77" DL0006
  , FrozenRow "documents/engineering/cluster_topology_doctrine.md" "9b10888ec7f949561b40e9f06359909d2b2995750bb76e28b973e7207094b6bd" DL0006
  , FrozenRow "documents/engineering/conformance_harness_doctrine.md" "b9c0044ae6cd81b00a31edb803504c3f0c8e33aba0258d4f25612099e6e94b9d" DL0007
  , FrozenRow "documents/engineering/consistency_pacelc_doctrine.md" "18afce4ff586ee57ba39b4f74ad003dbec4bb3ff6ea67086a21937d312ad0ae7" DL0006
  , FrozenRow "documents/engineering/content_addressing_determinism.md" "bcd3a10f73e21c58f5d4606b23875bede84da37190932158e1aaf0013450779b" DL0006
  , FrozenRow "documents/engineering/content_addressing_doctrine.md" "61ff22afb49b86804028ef8532ff891e80ac3df5e8cabb1514dd37e790d84180" DL0006
  , FrozenRow "documents/engineering/daemon_topology_doctrine.md" "13c2cf54a879f863194250491113c2a609199dd79b35bea2f687786c35c982de" DL0006
  , FrozenRow "documents/engineering/deterministic_simulation_doctrine.md" "c2b6fdafb4ca897d7c5b6e560576e7acbfac3666fcaa0e795f2cb3644a7dde16" DL0006
  , FrozenRow "documents/engineering/diagram_conventions.md" "ad8b81272a04ad13a89bfb9c9b50bae8189929daa7725e2f4ef97a9f9a16137f" DL0006
  , FrozenRow "documents/engineering/dsl_doctrine.md" "398e193ee0af78f372a675fc382ae0e077d94be2a27a71e1a2a912f2f43b8572" DL0004
  , FrozenRow "documents/engineering/evidence_calculus_doctrine.md" "cacbe3ead801e4096d86381c2af4d9fe72e7606733cc70e04b388cec29132f83" DL0006
  , FrozenRow "documents/engineering/extension_conformance_doctrine.md" "13f88cca53666c6d4dc9526d5a2db6f2095237feceffe82efea3dee86dff3126" DL0002
  , FrozenRow "documents/engineering/extension_conformance_laws.md" "338f3b6d363ddbd7fd23f1ce6d472a7153f99d6e64c5325fdd0d85d171685ff5" DL0006
  , FrozenRow "documents/engineering/extension_conformance_security.md" "fd89f3716a43409bd4f7e2042929c83c79f1c4ada2d8a7bdb81c86e5ec389521" DL0006
  , FrozenRow "documents/engineering/extension_conformance_transactions.md" "2f8290034758aaee3ded83ee09b2bcbd4d8696fe5915de57e20ac1eb92321f81" DL0006
  , FrozenRow "documents/engineering/formal_model_doctrine.md" "dc1126d19eeda6837fc1e6ef97ef1c47c80d86590f206aa1560c15ce49c5c38b" DL0006
  , FrozenRow "documents/engineering/gate_runner_doctrine.md" "a92d2994e8b2f1bdd125cd7f2a6ecb6952138c4889ccf2ce0d98fc391694376e" DL0014
  , FrozenRow "documents/engineering/gateway_migration_doctrine.md" "d329295176510e255086fe24fc42715ec515e47be6b47a25d6bd1474c80b31df" DL0006
  , FrozenRow "documents/engineering/gateway_migration_model_doctrine.md" "11ee27ac4f7de17a67961be3bfd3d32c6d08d010ea9651e76c20835184e78353" DL0006
  , FrozenRow "documents/engineering/generated_artifacts_doctrine.md" "76f9975359648dab35937cad321ea3cd2d192762825731685cd4f5a8d35d5cf3" DL0006
  , FrozenRow "documents/engineering/host_cluster_comms_doctrine.md" "2aa99bf9fd6c6234589496105096ad7a821f75956d05b374d7f1033e6e400582" DL0006
  , FrozenRow "documents/engineering/image_build_doctrine.md" "7fafe3bbf191d466103e49493d361d3b270166b53c920f0de8c8efab6b1f8088" DL0006
  , FrozenRow "documents/engineering/inforcespec_migration_doctrine.md" "a99310c06828c8dff9e0a40f4a599a198e4d2a243a95f09570475a9fadadb431" DL0006
  , FrozenRow "documents/engineering/jit_artifact_doctrine.md" "6c07a4517944625ac92a1fdd1d311175927b68aa1b0970b29f9be52671aee07c" DL0006
  , FrozenRow "documents/engineering/jit_budget_doctrine.md" "b02911d3c3b6c6ea1d6567c4c0d67ae6a75bef585524b081c24f2dfd26d5e9f4" DL0006
  , FrozenRow "documents/engineering/lift_and_compose_doctrine.md" "4461699d02c0debd0de7804bd73cea73364d24673ca21274f3fac550c4eceaf4" DL0006
  , FrozenRow "documents/engineering/low_code_ui_runtime_doctrine.md" "6091bf6be1407e7e6e70e251150fb3d6317b670488b3f12d2f46f1ef121ffd95" DL0006
  , FrozenRow "documents/engineering/low_code_ui_workflow_lifting.md" "13b92a2b661a96f83b2399c7feec0f5153626dbdcd003af9f12591c0e98fb49d" DL0006
  , FrozenRow "documents/engineering/manifest_generation_doctrine.md" "9c6222f20d067109709edb17f6a92b26feb797c5999d8274aefd3e546e348de8" DL0011
  , FrozenRow "documents/engineering/migration_doctrine.md" "1aa7f54ab24f7e93a2babe9c1133c951b70fbd54b6de75f261907ff6bf0b8bb8" DL0013
  , FrozenRow "documents/engineering/monitoring_doctrine.md" "ed707b6a8cf3a331961e799f9bf3ed8d632250a7b35293b3b9ed448299bed08c" DL0002
  , FrozenRow "documents/engineering/namespace_layout_doctrine.md" "28a97e1a8ade560e0a114875ceb6ffd2d1090619c0186bc8e50208f80045ccdb" DL0006
  , FrozenRow "documents/engineering/network_fabric_doctrine.md" "6d85e667d3a5d1353df3be32c291e60c01ad52135ef9e741cf6f9497df17b228" DL0006
  , FrozenRow "documents/engineering/platform_services_doctrine.md" "ee086d10d7680c860ac0f73984098cbd78a79ad9e0889de478828c8c1819e929" DL0006
  , FrozenRow "documents/engineering/preflight_validation_doctrine.md" "978279404051b3747d73e4e49ec738e809749796819af5f23b00635a27ee1a2a" DL0006
  , FrozenRow "documents/engineering/pulsar_client_doctrine.md" "7df3fa9da711045ccaf3ce49515e33f69f2c8b18cdcac0732e764d9ba774cf3f" DL0006
  , FrozenRow "documents/engineering/pulumi_ebs_credential_model.md" "430e63f62e24e5cd2476a7e0c061b3807a370cbfef370d1a093972e2c966c7eb" DL0006
  , FrozenRow "documents/engineering/pulumi_iac_doctrine.md" "ad2e7aa7043fb08663f09239c3e55b9d621fffeb89b670278bf530a2c40e1ed8" DL0006
  , FrozenRow "documents/engineering/readiness_ordering_doctrine.md" "121debe68a372d858c4d6aeead55d23e2c44b0187dc68df01ba714d2e71e3b82" DL0006
  , FrozenRow "documents/engineering/release_lifecycle_doctrine.md" "081ed5fdfb69190548ebe96c2ad5af1d7b467bb2d1cc1259138e3a77f208ead0" DL0011
  , FrozenRow "documents/engineering/repository_layout_doctrine.md" "d7c04d49dc93d63f722645f2efb39f3768e4d0d1fae56d163eb0669d39fff92e" DL0013
  , FrozenRow "documents/engineering/resource_capacity_construction.md" "2ff08a1fee00539da22df63ddee66d886de5f12024b13d13992a53788832be9c" DL0006
  , FrozenRow "documents/engineering/resource_capacity_doctrine.md" "6f3fdd49b0d9c8349a3b6e2a9cc096e4b1481f0e8abc64b4033c780dd1d4dadd" DL0006
  , FrozenRow "documents/engineering/resource_capacity_folds.md" "c785a578f6837444a93edc2c6b8c399db8919adc20634cde99bd400ce90a22f7" DL0006
  , FrozenRow "documents/engineering/resource_capacity_schema.md" "e07bcc3a766265773fb7885815ddf753937c1e8b94aa67674ad46aad695a65e6" DL0006
  , FrozenRow "documents/engineering/resource_capacity_sources.md" "709c3a925b2af2fa8c6263dc2ce555e7cd487e246db1f25e1493ecf0721289c4" DL0006
  , FrozenRow "documents/engineering/resource_capacity_storage.md" "c18679c19980c809ecfe0e3e41d13925ffc62286192e12245c614f6146dd24d2" DL0006
  , FrozenRow "documents/engineering/resource_capacity_types.md" "3826154e5823c172d60a2bac22349030f052572bedbde54a7d636b4bb57345da" DL0006
  , FrozenRow "documents/engineering/service_capability_doctrine.md" "5eeb4b95bb22edc0497f85fd2feb1ac42ece3fc51b3c8afecb69fc7c7e5605a1" DL0011
  , FrozenRow "documents/engineering/single_logical_data_plane_doctrine.md" "80b7f51d35de20a3799c8a49edeab29139b27757ea70ec08a5f6bd316c3ee792" DL0006
  , FrozenRow "documents/engineering/storage_lifecycle_doctrine.md" "e2841d0bfe56773813bca8ee7b785242a769238080212f63a6a6e2da2023ad1a" DL0006
  , FrozenRow "documents/engineering/substrate_doctrine.md" "5c11085b0ca3c23bd7f85f305d017fd7007840ff3c7b2dc16ca3744fde85cc1a" DL0006
  , FrozenRow "documents/engineering/substrate_node_inventory.md" "1ad803874233ddb00b712d199293e9662f26404cdf44f1f4629de736fabfc4e1" DL0006
  , FrozenRow "documents/engineering/tenancy_doctrine.md" "282b5959061365be51af5844a7a019aadc11f084eaa27119ab13df042e8bf49e" DL0006
  , FrozenRow "documents/engineering/test_derivation_analysis.md" "a1e66c2df7273a5b180a2b8fa79c89e68cc9a04a539070bcd76a1a05f7338583" DL0006
  , FrozenRow "documents/engineering/testing_doctrine.md" "2532e0fdab05f6671ccd8938737f6a8308e510b0599fa38425f8999ddb47d9d2" DL0006
  , FrozenRow "documents/engineering/testing_spoof_resistance.md" "e4ee1dae483fd1fb9f758295a75fddad97c0129ac10f898a3b024555113b5b4a" DL0006
  , FrozenRow "documents/engineering/ui_realtime_coordination_doctrine.md" "ca85f59e30aee1353a7da820bfdeac47e0afe24af47c087c85180981aa8d6234" DL0006
  , FrozenRow "documents/engineering/validation_frame_doctrine.md" "01cef7c119558e63ec82ee311a01fc7008cfc87b9b46b31e5235feb3b8561148" DL0013
  , FrozenRow "documents/engineering/vault_pki_doctrine.md" "27e3e5b8ca512fcaf13dc1642397747a6a9a3cc5aedd58552ba034b146c03614" DL0006
  , FrozenRow "documents/engineering/workflow_calculus_doctrine.md" "6a1300faea37155de5c06df36ad6801a4b2f0a9fe37a299ca251a6bcdf905810" DL0006
  , FrozenRow "documents/glossary.md" "af8fadd52a7c96c7b9c52e772305a20ec6dc936d3a133730f4799a4ff194afa4" DL0013
  , FrozenRow "documents/illegal_state/README.md" "b3bd7f21b077e7d549f8e2bb749648b77de1323e769908949571de2a95d900bc" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_capability_messaging.md" "7f6b2f02e12415719327f4f23c060ecbb3a94897a10df8c01345e38a73bb5370" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_capacity.md" "0b783412648e4fe93615bbc8f836832c323ce2b7718eae69d0b2d1cd984159a2" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_catalog.md" "f71a574cb1d0a0072b682c014a54f27a09b4c556fe315d792e1ddcfaaf35fbfe" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_lifecycle.md" "6bcd2efba54d851f4962339ac9848fdc7dc84c3c9ca45f95cbbecab043e2f1bc" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_ml_asset.md" "23c8dff8b614c98123eb6cceffb46ee44cf147519fe0b63a111a087da1494548" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_multicluster.md" "26c46b90c8b30bd389440ffe450367a3a7b4b0aff35b688f4831f407ef2ff94a" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_security.md" "3ab6f99f05c1b8603b699fd8871b5a82d3b0f212d0d46b84a51a1f8daecd9703" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_storage.md" "92368fe49232649a57cb27b1617863bd5ddb766ce4180037780b931eea558e31" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_techniques.md" "a59bc7cad7a3b66da0932762c97fa9aba897bdae59e7b3c8bfcfe403aec19692" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_tenancy.md" "e94e2f42ac06f13843eee3d0834d7a7e7d73aa0d9a5a7b11638a0db74fb390bb" DL0006
  , FrozenRow "documents/illegal_state/illegal_state_topology.md" "a4d7f93855c0939b21ff44d777fef73ee496ba710445c807acc825ade9835120" DL0006
  , FrozenRow "documents/reading_order.md" "730ff7a80452cb90f0d6352702424be39b0e8d23b0a0154dae15ef2f8c5f0567" DL0013
  , FrozenRow "AGENTS.md" "f61fbfd3d7032543d24b92fad193aeef79a9550632eb9e2f3955a693b05a384b" DL0013
  , FrozenRow "DEVELOPMENT_PLAN/development_plan_standards.md" "40a9bd322f523fe89816b30d4c8375216e7b78da50885e188d751b12e9c408ac" DL0013
  , FrozenRow "DEVELOPMENT_PLAN/development_plan_phase_model.md" "3afdd57359e08529e128a7113114202441165eb10e531f85baf834e0329b69ce" DL0013
  , FrozenRow "DEVELOPMENT_PLAN/development_plan_gate_integrity.md" "33093d2cc3fd90d103c342c9f8ed2cf0cd9fe608a323cbd75c100d5f653e790a" DL0014
  , FrozenRow "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md" "4f89e9be76b0f0489cc5b86aab26d291c3fe85268d38398fbfb2507af436babb" DL0013
  ]
