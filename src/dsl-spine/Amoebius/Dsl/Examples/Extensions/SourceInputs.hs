{-# LANGUAGE OverloadedStrings #-}
-- Source corpus values, paired with independently authored AST expectations.
module Amoebius.Dsl.Examples.Extensions.SourceInputs
  ( extensionInputs, transportPureProbe, transportUnsafeProbe
  , transportPluginProbe, transportOptionPrefix, transportTrustedEffect
  , conformanceRoleInputs, closedApiInputs, sourceTreeInputs, mergeInputs ) where
import Amoebius.Extension.Capability (DeclaredCapability (..))
import Amoebius.Vocabulary (CapabilityArm (ObjectStore, InferenceEngine))
import Data.Text (Text)
import Data.Text qualified as Text

-- Complete file-tree inputs, including explicit link observations. Ordinary
-- files also run through a disposable native tree; link refusals need no host
-- link-creation capability.
sourceTreeInputs :: [(FilePath, Text)] -> [(Text, [(FilePath, Text)], [(FilePath, FilePath)])]
sourceTreeInputs sources =
  [("legal-tree", sources, []), ("pure-helper-closure", sources <> [(probe, transportPureProbe)], []),
   ("empty-source-root", [], []),
   ("module-path-mismatch", sources <> [(probe, "module Different where\nidentity value = value\n")], []),
   ("duplicate-module", sources <> [(probe, "module Amoebius.Extension.Contributed.JitBuild where\nidentity value = value\n")], []),
   ("source-symlink", sources, [(probe, "JitBuild.hs")]),
   ("alternate-source-suffix", sources <> [("forbidden.lhs", "value = 1\n")], []),
   ("unchecked-helper-import", sources <> [(probe, "module Amoebius.Extension.Contributed.GuardProbe where\nimport System.IO\nidentity value = value\n")], [])]
 where probe = "Amoebius/Extension/Contributed/GuardProbe.hs"

-- Graph inputs contain declarations, never an oracle result or a source seal.
mergeInputs :: [(Text, [(Text, [DeclaredCapability], [DeclaredCapability])])]
mergeInputs =
  [("legal-peer", [build, inference]), ("missing-requirement", [inference]),
   ("duplicate-id", [("same", [JitBuild], []), ("same", [Coordination], [])]),
   ("duplicate-provider", [("one", [JitBuild], []), ("two", [JitBuild], [])]),
   ("cyclic-requirements", [("one", [JitBuild], [Coordination]), ("two", [Coordination], [JitBuild])])]
 where
  build = ("build", [JitBuild], [ServiceCapability ObjectStore])
  inference = ("inference", [ServiceCapability InferenceEngine], [JitBuild])

-- Native boundary inputs. The effect marker is bounded to disposable scratch;
-- the independent oracle, rather than these source values, owns the verdicts.
transportPureProbe, transportUnsafeProbe, transportPluginProbe, transportOptionPrefix, transportTrustedEffect :: Text
transportPureProbe = "module Amoebius.Extension.Contributed.GuardProbe where\nidentity value = value\n"
transportUnsafeProbe = Text.unlines
  [ "{-# LANGUAGE TemplateHaskell #-}", "module Amoebius.Extension.Contributed.GuardProbe where"
  , "import Language.Haskell.TH.Syntax qualified as TH"
  , "$(TH.runIO (writeFile \".build/effect.marker\" \"executed\") >> pure [])" ]
transportPluginProbe = "{-# OPTIONS_GHC -fplugin=Missing.Unsafe.Plugin #-}\n" <> transportPureProbe
transportOptionPrefix = "{-# OPTIONS_GHC -pgmF missing-unsafe-preprocessor #-}\n"
transportTrustedEffect = Text.unlines
  [ "{-# LANGUAGE TemplateHaskell #-}", "module TrustedEffect where"
  , "import Language.Haskell.TH.Syntax qualified as TH"
  , "$(TH.runIO (writeFile \".build/effect.marker\" \"executed\") >> pure [])" ]

-- Public-client type inputs. The independent oracle states whether each
-- client can compile; these values contain no expectation or success flag.
conformanceRoleInputs :: [(Text, Text, Text)]
conformanceRoleInputs = map pair
  [("gate-plan", "Amoebius.Extension.Conformance.Gate", "GatePlan"),
   ("conformance-verdict", "Amoebius.Extension.Conformance.Gate", "ConformanceVerdict"),
   ("guarded-link-set", "Amoebius.Extension.Conformance.Gate", "LinkSet"),
   ("modeled-link-set", "Amoebius.Extension.Conformance.Model", "ModeledLinkSet"),
   ("request-scope", "Amoebius.Scope.Attested", "RequestScope"),
   ("scoped-value", "Amoebius.Scope.Attested", "Scoped %scope% Int"),
   ("scoped-handle", "Amoebius.Scope.Attested", "ScopedHandle %scope% ()"),
   ("flow-label", "Amoebius.Scope.Flow", "FlowLabel"),
   ("flow-witness", "Amoebius.Scope.Flow", "CanFlowTo"),
   ("declaration", "Amoebius.Extension.Declaration", "ExtensionDeclaration"),
   ("monitor-access", "Amoebius.Extension.Monitoring", "AccessScope"),
   ("workflow-monitor", "Amoebius.Extension.Monitoring", "WorkflowMonitor"),
   ("monitor-store-reference", "Amoebius.Extension.Monitoring", "ObjectStoreRef"),
   ("monitoring-surface", "Amoebius.Extension.Monitoring", "MonitoringSurface")]
 where
  pair (name, owner, boundary) = (name, source owner boundary "ScopeAlpha", source owner boundary "ScopeBeta")
  source owner boundary target = Text.unlines
    [ "module RoleProbe where"
    , "import Data.Coerce (coerce)"
    , "import " <> owner <> " (" <> Text.takeWhile (/= ' ') boundary <> ")"
    , "data ScopeAlpha"
    , "data ScopeBeta"
    , "retag :: " <> indexed boundary "ScopeAlpha" <> " -> " <> indexed boundary target
    , "retag = coerce"
    ]
  indexed boundary scope = if "%scope%" `Text.isInfixOf` boundary
    then Text.replace "%scope%" scope boundary else boundary <> " " <> scope

closedApiInputs :: [(Text, Text, Text)]
closedApiInputs =
  [ordinary name owner legal illegal | (name, owner, legal, illegal) <-
    [("scope-constructor", "Amoebius.Scope.Attested", "scopeIssuer", "RequestScope"),
     ("scope-text-factory", "Amoebius.Scope.Attested", "attest", "withRequestScope"),
     ("binding-subject-constructor", "Amoebius.Extension.Graph", "bindingIssuer", "BindingSubject"),
     ("source-seal-constructor", "Amoebius.Extension.AstCheck", "checkExtensionSource", "CheckedExtensionSource"),
     ("spec-constructor", "Amoebius.Extension.Spec", "extId", "ExtensionSpec"),
     ("public-monitor-access", "Amoebius.Extension.Monitoring", "accessKind", "Public")]] <>
  [("spec-record-update", Text.unlines ["module ClosedProbe where", "import Amoebius.Extension.Spec qualified as Api", "change value = Api.extId value"],
      Text.unlines ["module ClosedProbe where", "import Amoebius.Extension.Spec qualified as Api", "change value = value {Api.extId = Api.extId value}"]),
   ("spec-generic", specGeneric "id", specGeneric "to . from"),
   ("claimed-identity", identityClient "'Api.Attested", identityClient "'Api.Claimed"),
   ("workflow-before-retag", workflowClient False False, workflowClient True False),
   ("workflow-after-retag", workflowClient False False, workflowClient False True),
   ("missing-monitoring", monitoringClient "(() :| [])", monitoringClient "[]"),
   ("empty-sli-set", Text.unlines ["module ClosedProbe where", "import Amoebius.Extension.Monitoring qualified as Api", "value = Api.sloBuilder"],
      Text.unlines ["module ClosedProbe where", "import Amoebius.Extension.Monitoring qualified as Api", "value = Api.sloBuilder []"]),
   ("unrelated-factory-seal", factoryClient "Factory.contribution", factoryClient "id")]
 where
  ordinary name owner legal illegal = (name, source legal, source illegal)
   where source value = Text.unlines ["module ClosedProbe where", "import " <> owner <> " qualified as Api", "value = Api." <> value]
  specGeneric expression = Text.unlines
    ["module ClosedProbe where", "import Amoebius.Extension.Spec (ExtensionSpec)", "import GHC.Generics (from, to)",
     "type Spec = ExtensionSpec () () () () () () () () () ()", "value :: Spec -> Spec", "value = " <> expression]
  identityClient trust = Text.unlines
    ["{-# LANGUAGE DataKinds #-}", "module ClosedProbe where", "import Amoebius.Scope.Attested qualified as Api",
     "value :: Api.Identity " <> trust <> " -> Api.Attestation", "value = Api.principalAttestation"]
  monitoringClient monitors = Text.unlines
    ["module ClosedProbe where", "import Amoebius.Extension.Spec qualified as Api", "import Data.List.NonEmpty (NonEmpty (..))",
     "value = Api.mkExtensionSpec () () ([] :: [()]) [] () (const ([] :: [()])) [] " <> monitors <> " () ()"]
  factoryClient factory = Text.unlines
    ["{-# LANGUAGE TemplateHaskell #-}", "module ClosedProbe where", "import Amoebius.Extension.LinkSeal qualified as Api",
     "import Amoebius.Extension.Contributed.JitBuild qualified as Factory", "value = $(Api.admitContribution '" <> factory <> ")"]
  workflowClient before after = Text.unlines
    ["{-# LANGUAGE DataKinds #-}", "module ClosedProbe where", "import Amoebius.Calculus.Workflow.Run (Workflow)",
     "import Data.Coerce (coerce)", "type ScopeAlpha = '[\"alpha\"]", "type ScopeBeta = '[\"beta\"]",
     "value :: Workflow ScopeAlpha ScopeAlpha () -> Workflow " <> (if before then "ScopeBeta" else "ScopeAlpha") <> " " <>
       (if after then "ScopeBeta" else "ScopeAlpha") <> " ()", "value = coerce"]

extensionInputs :: [(Text, Text)]
extensionInputs =
  [ ("pure-simple", "module Pure where\nanswer :: Int\nanswer = 42\n")
  , ("qualified-safe", "module Qualified where\nimport qualified Amoebius.Kernel.Step as K\nlabel = K.stepLabel\n")
  , ("forbidden-words-are-data", "module Words where\n-- foreign import unsafePerformIO :: IO $( instance\nunsafeMarker = \"foreign import unsafePerformIO :: IO $( instance\"\n")
  , ("local-instance", "module Local where\ndata Box = Box\ninstance Show Box where\n  show _ = \"box\"\n")
  , ("qualified-alias", "module Alias where\nimport qualified Prelude as P\nwork = P.putStrLn \"x\"\n")
  , ("forbidden-reexport", "module Reexport (module P) where\nimport Prelude as P\n")
  , ("template-splice", "{-# LANGUAGE TemplateHaskell #-}\nmodule Splice where\nvalue = $(undefined)\n")
  , ("cpp-guarded", "{-# LANGUAGE CPP #-}\nmodule Cpp where\n#if 1\nvalue = 1\n#else\nwork :: IO ()\nwork = pure ()\n#endif\n")
  , ("foreign-import", "{-# LANGUAGE ForeignFunctionInterface #-}\nmodule Foreign where\nforeign {- split -} import ccall \"abs\" absInt :: Int -> Int\n")
  , ("string-built-identifier", "{-# LANGUAGE TemplateHaskell #-}\nmodule Strings where\nimport qualified Language.Haskell.TH as T\nwork = $(T.varE (T.mkName (\"put\" ++ \"StrLn\")))\n")
  , ("comment-split-type", "module CommentSplit where\nwork :: {- gap -} IO ()\nwork = pure ()\n")
  , ("orphan-instance", "{-# LANGUAGE FlexibleInstances #-}\nmodule Orphan where\ninstance Show (Int -> Int) where\n  show _ = \"function\"\n")
  , ("compiler-options", "{-# OPTIONS_GHC -fno-code #-}\nmodule Options where\nvalue = 1\n")
  , ("qualified-alias-twin", "module Alias where\nimport qualified Prelude as P\nwork = P.length \"x\"\n")
  , ("explicit-export-twin", "module Reexport (answer) where\nimport Prelude as P\nanswer = P.length \"x\"\n")
  , ("template-free-twin", "{-# LANGUAGE TemplateHaskell #-}\nmodule Splice where\nvalue = 42\n")
  , ("cpp-free-twin", "{-# LANGUAGE NoCPP #-}\nmodule Cpp where\nvalue = 1\n")
  , ("foreign-free-twin", "{-# LANGUAGE ForeignFunctionInterface #-}\nmodule Foreign where\nabsInt :: Int -> Int\nabsInt = abs\n")
  , ("string-data-twin", "module Strings where\nwork = \"put\" ++ \"StrLn\"\n")
  , ("comment-split-pure-twin", "module CommentSplit where\nwork :: {- gap -} Int\nwork = 1\n")
  , ("compiler-options-free-twin", "{-# LANGUAGE OverloadedStrings #-}\nmodule Options where\nvalue = 1\n")
  , ("abstract-manifest-type", "module Abstract where\nimport qualified Amoebius.Manifest.K8sObject as M\nidentity :: M.K8sObject -> M.K8sObject\nidentity value = value\n")
  , ("local-record-constructor", "module LocalRecord where\ndata Box = Box { count :: Int }\nmake x = Box x\n")
  , ("manifest-constructor", "module Constructor where\nimport qualified Amoebius.Manifest.K8sObject as M\nvalue = M.K8sObject\n")
  , ("foreign-record-update", "module Update where\nimport qualified Amoebius.Manifest.K8sObject as M\nchange x = x { M.objectApiVersion = \"v1\" }\n")
  , ("foreign-record-projection", "{-# LANGUAGE OverloadedRecordDot #-}\nmodule Projection where\nreadMeta x = x.objectMetadata\n")
  , ("read-method", "module Reader where\nimport qualified Prelude as P\nwork = P.readsPrec\n")
  , ("enumeration", "module Enumeration where\nimport qualified Amoebius.Kernel.Step as K\nvalue = [K.ApplyObjects ..]\n")
  , ("position-pragma", "{-# LINE 500 \"hidden.hs\" #-}\nmodule Hidden where\nvalue = 1\n")
  , ("unknown-language", "{-# LANGUAGE NoSuchExtension #-}\nmodule Unknown where\nvalue = 1\n")
  , ("unbounded-import", "module Unbounded where\nimport Amoebius.Manifest.K8sObject\nvalue = K8sObject\n")
  , ("reserved-local-shadow", "module Shadow where\nputStrLn = length\nwork = putStrLn \"x\"\n")
  , ("local-pure-name", "module Shadow where\ndisplay = length\nwork = display \"x\"\n")
  , ("explicit-abstract-import", "module Abstract where\nimport Amoebius.Manifest.K8sObject (K8sObject)\nidentity :: K8sObject -> K8sObject\nidentity value = value\n")
  , ("self-alias-collision", "module SelfAlias where\nimport qualified Amoebius.Manifest.K8sObject as SelfAlias\nvalue = SelfAlias.K8sObject\n")
  , ("pattern-constructor-import", "{-# LANGUAGE PatternSynonyms, ExplicitNamespaces #-}\nmodule PatternConstructor where\nimport Amoebius.Manifest.K8sObject (pattern K8sObject)\nvalue = K8sObject\n")
  , ("source-import", "module Boot where\nimport {-# SOURCE #-} Prelude\nvalue = 1\n")
  , ("qualified-orphan-shadow", "{-# LANGUAGE FlexibleInstances #-}\nmodule OrphanShadow where\nimport qualified Amoebius.Manifest.K8sObject as M\ndata K8sObject = LocalObject\ninstance Semigroup M.K8sObject where\n  (<>) = const\n")
  , ("local-semigroup-instance", "module LocalSemigroup where\ndata Box = Box\ninstance Semigroup Box where\n  (<>) = const\n")
  , ("open-family-instance", "{-# LANGUAGE TypeFamilies #-}\nmodule OpenFamily where\ntype family Open value\ntype instance Open Int = Bool\nvalue = 1\n")
  , ("closed-type-family", "{-# LANGUAGE TypeFamilies #-}\nmodule ClosedFamily where\ntype family Closed value where\n  Closed Int = Bool\nvalue = 1\n")
  , ("foreign-standalone-deriving", "{-# LANGUAGE StandaloneDeriving #-}\nmodule ForeignDeriving where\nderiving instance Show Int\n")
  , ("local-standalone-deriving", "{-# LANGUAGE StandaloneDeriving #-}\nmodule LocalDeriving where\ndata Box = Box\nderiving instance Show Box\n")
  ]
