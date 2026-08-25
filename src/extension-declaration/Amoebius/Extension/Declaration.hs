{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The complete, inspectable declaration of one extension.
--
-- An extension has one mandatory component from each of the five core calculi.  The
-- constructor is private and 'declareExtension' checks the calculus occupying each slot,
-- so a declaration cannot silently substitute (for example) a budget component for its
-- artifact component.  All five arguments share one request-scope index in the normal
-- API.  Each component retains its own resource vector and 'declarationResource' is the
-- exact natural-number sum supplied by Phase 11's composition algebra.
module Amoebius.Extension.Declaration
  ( ExtensionDeclaration
  , DeclarationError (..)
  , DeclaredComponent (..)
  , declareExtension
  , extensionName
  , declarationDigest
  , declarationComponents
  , declarationComposition
  , declarationResource
  , declarationArtifactSet
  , declarationBudgetSet
  , declarationLiftSet
  , declarationWorkflowSet
  , declarationEvidenceSet
  ) where

import Amoebius.Calculus.Composition
  ( Calculus (..)
  , Component
  , Composition
  , append
  , calculusTag
  , componentCalculus
  , componentDescriptor
  , componentIdentityFields
  , componentName
  , componentResource
  , compositionResource
  , singleton
  )
import Amoebius.Capacity.Types (ResourceVector (..))
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)
#ifdef EXTENSION_DECLARATION_DROPS_SCOPE_INDEX_MUTANT
import Unsafe.Coerce (unsafeCoerce)
#endif

-- | A calculus slot received a component from another calculus, or the declaration was
-- given no name.  The error names both calculi so the refusal is externally observable.
data DeclarationError
  = EmptyExtensionName
  | UnexpectedCalculus
      { expectedCalculus :: Calculus
      , observedCalculus :: Calculus
      }
  deriving stock (Eq, Show)

-- | The semantic projection exposed by every calculus-specific reader.  It contains the
-- component's real Phase 11 observations, not a second authored inventory.
data DeclaredComponent = DeclaredComponent
  { declaredCalculus :: Calculus
  , declaredName :: Text
  , declaredResource :: ResourceVector
  , declaredDescriptor :: Text
  , declaredIdentityFields :: [Text]
  }
  deriving stock (Eq, Ord, Show)

#ifdef EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT
-- Seeded defect: the evidence component and its field have become optional by absence.
data ExtensionDeclaration scope = ExtensionDeclaration
  { extensionName :: Text
  , extensionArtifact :: Component scope
  , extensionBudget :: Component scope
  , extensionLift :: Component scope
  , extensionWorkflow :: Component scope
  }
#else
data ExtensionDeclaration scope = ExtensionDeclaration
  { extensionName :: Text
  , extensionArtifact :: Component scope
  , extensionBudget :: Component scope
  , extensionLift :: Component scope
  , extensionWorkflow :: Component scope
  , extensionEvidence :: Component scope
  }
#endif

-- | Construct the only declaration shape admitted by the core.
#ifdef EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT
declareExtension
  :: Text
  -> Component scope
  -> Component scope
  -> Component scope
  -> Component scope
  -> Either DeclarationError (ExtensionDeclaration scope)
declareExtension name artifact budget lift workflow = do
  validateName name
  validateSlot ArtifactCalculus artifact
  validateSlot BudgetCalculus budget
  validateSlot LiftCalculus lift
  validateSlot WorkflowCalculus workflow
  pure (ExtensionDeclaration name artifact budget lift workflow)
#elif defined(EXTENSION_DECLARATION_DROPS_SCOPE_INDEX_MUTANT)
-- Seeded defect: independent scope indices are erased before the declaration is stored.
declareExtension
  :: Text
  -> Component artifactScope
  -> Component budgetScope
  -> Component liftScope
  -> Component workflowScope
  -> Component evidenceScope
  -> Either DeclarationError (ExtensionDeclaration artifactScope)
declareExtension name artifact budget lift workflow evidence =
  declareExtensionSameScope
    name artifact (unsafeCoerce budget) (unsafeCoerce lift) (unsafeCoerce workflow) (unsafeCoerce evidence)
#else
declareExtension
  :: Text
  -> Component scope
  -> Component scope
  -> Component scope
  -> Component scope
  -> Component scope
  -> Either DeclarationError (ExtensionDeclaration scope)
declareExtension = declareExtensionSameScope
#endif

#ifndef EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT
declareExtensionSameScope
  :: Text
  -> Component scope
  -> Component scope
  -> Component scope
  -> Component scope
  -> Component scope
  -> Either DeclarationError (ExtensionDeclaration scope)
declareExtensionSameScope name artifact budget lift workflow evidence = do
  validateName name
  validateSlot ArtifactCalculus artifact
  validateSlot BudgetCalculus budget
  validateSlot LiftCalculus lift
  validateSlot WorkflowCalculus workflow
  validateSlot EvidenceCalculus evidence
  pure (ExtensionDeclaration name artifact budget lift workflow evidence)
#endif

validateName :: Text -> Either DeclarationError ()
validateName name
  | Text.null name = Left EmptyExtensionName
  | otherwise = Right ()

validateSlot :: Calculus -> Component scope -> Either DeclarationError ()
validateSlot wanted component
  | componentCalculus component == wanted = Right ()
  | otherwise = Left (UnexpectedCalculus wanted (componentCalculus component))

declarationComponents :: ExtensionDeclaration scope -> [DeclaredComponent]
declarationComponents declaration = fmap project (rawComponents declaration)

project :: Component scope -> DeclaredComponent
project component =
  DeclaredComponent
    { declaredCalculus = componentCalculus component
    , declaredName = componentName component
    , declaredResource = componentResource component
    , declaredDescriptor = componentDescriptor component
    , declaredIdentityFields = componentIdentityFields component
    }

rawComponents :: ExtensionDeclaration scope -> [Component scope]
rawComponents declaration =
  [ extensionArtifact declaration
  , extensionBudget declaration
  , extensionLift declaration
  , extensionWorkflow declaration
#ifndef EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT
  , extensionEvidence declaration
#endif
  ]

declarationComposition :: ExtensionDeclaration scope -> Composition scope
declarationComposition declaration =
  append
    (append
      (append
        (singleton (extensionArtifact declaration))
        (singleton (extensionBudget declaration)))
      (singleton (extensionLift declaration)))
#ifdef EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT
    (singleton (extensionWorkflow declaration))
#else
    (append
      (singleton (extensionWorkflow declaration))
      (singleton (extensionEvidence declaration)))
#endif

declarationResource :: ExtensionDeclaration scope -> ResourceVector
declarationResource = compositionResource . declarationComposition

declarationArtifactSet :: ExtensionDeclaration scope -> Set DeclaredComponent
declarationArtifactSet = setFor ArtifactCalculus

declarationBudgetSet :: ExtensionDeclaration scope -> Set DeclaredComponent
declarationBudgetSet = setFor BudgetCalculus

declarationLiftSet :: ExtensionDeclaration scope -> Set DeclaredComponent
declarationLiftSet = setFor LiftCalculus

declarationWorkflowSet :: ExtensionDeclaration scope -> Set DeclaredComponent
declarationWorkflowSet = setFor WorkflowCalculus

declarationEvidenceSet :: ExtensionDeclaration scope -> Set DeclaredComponent
declarationEvidenceSet = setFor EvidenceCalculus

setFor :: Calculus -> ExtensionDeclaration scope -> Set DeclaredComponent
setFor wanted = Set.fromList . filter ((== wanted) . declaredCalculus) . declarationComponents

-- | SHA-256 over a fixed-version, length-prefixed semantic projection.  Each field is
-- framed separately, so embedded delimiters cannot change the parse.  The component
-- order is the closed calculus order rather than a caller-controlled traversal.
declarationDigest :: ExtensionDeclaration scope -> Text
declarationDigest declaration =
  Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash canonicalBytes)))
 where
  canonicalBytes = frame ("amoebius-extension-declaration-v1" : Encoding.encodeUtf8 (extensionName declaration) : componentFields)
  componentFields = concatMap fields (declarationComponents declaration)
  fields component =
    [ Encoding.encodeUtf8 (calculusTag (declaredCalculus component))
    , Encoding.encodeUtf8 (declaredName component)
    , decimalBytes (resourceCpu resources)
    , decimalBytes (resourceMemory resources)
    , decimalBytes (resourceEphemeralStorage resources)
    , decimalBytes (resourcePodSlots resources)
    ]
      <> fmap Encoding.encodeUtf8 (declaredIdentityFields component)
   where
    resources = declaredResource component

frame :: [ByteString] -> ByteString
frame = LazyByteString.toStrict . Builder.toLazyByteString . foldMap framed
 where
  framed bytes = Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

decimalBytes :: Show number => number -> ByteString
decimalBytes = Encoding.encodeUtf8 . Text.pack . show

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
