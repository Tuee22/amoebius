{-# LANGUAGE OverloadedStrings #-}

module DhallSchemaGenerationOracle
  ( expectedModuleNames
  , expectedPositiveNames
  , expectedNegativeRows
  , expectedSchemaLoci
  ) where

import Data.Text (Text)

expectedModuleNames :: [Text]
expectedModuleNames =
  [ "App", "Backup", "BakeCatalog", "Capability", "Capacity", "Cluster", "Consistency"
  , "Deployment", "Extension", "Image", "Resources", "Retention", "SanctionedApi", "SecretRef"
  , "Storage", "Topology", "UiOffline", "prelude/package"
  ]

expectedPositiveNames :: [Text]
expectedPositiveNames =
  [ "legal_multisubstrate_cluster", "legal_managed_eks", "trivial_app", "legal_deployment_rules" ]

expectedNegativeRows :: [(Text, Text, Text)]
expectedNegativeRows =
  [ ("product_named_capability", "trivial_app", "Pulsar")
  , ("insecure_ingress", "legal_multisubstrate_cluster", "Insecure")
  , ("missing_resource_envelope", "legal_deployment_rules", "resources")
  , ("unbounded_storage", "trivial_app", "Unbounded")
  , ("topic_without_retention", "trivial_app", "retention")
  , ("growth_without_scaling_policy", "trivial_app", "policy")
  , ("even_rke2_servers", "legal_multisubstrate_cluster", "Ha2")
  , ("unsupported_substrate", "legal_multisubstrate_cluster", "Windows")
  , ("foreign_image", "trivial_app", "Foreign")
  , ("run_shell_bake_step", "trivial_app", "RunShell")
  , ("container_without_process", "trivial_app", "process")
  , ("plaintext_secret", "trivial_app", "SecretRef")
  , ("import_env", "trivial_app", "ForbiddenImport:env")
  , ("import_remote", "trivial_app", "ForbiddenImport:https")
  ]

expectedSchemaLoci :: [(Text, Text)]
expectedSchemaLoci =
  [ ("Capability", "InferenceEngine")
  , ("Capability", "Custom")
  , ("Resources", "requests : { cpu : Natural, memory : Natural, ephemeralStorage : Natural }")
  , ("Resources", "limits : { cpu : Natural, memory : Natural, ephemeralStorage : Natural }")
  , ("SecretRef", "TransitKey : { name : Text }")
  , ("SecretRef", "Prompt : { name : Text, purpose : Text }")
  , ("SecretRef", "PlainText")
  , ("Image", "process : Text")
  , ("Storage", "policy : Text")
  ]
