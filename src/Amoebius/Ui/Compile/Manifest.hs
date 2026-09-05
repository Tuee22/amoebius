{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Compile.Manifest
  ( CompiledUiPlans
  , PlanDigests (..)
  , UiPlanError (..)
  , compileUiPlans
  , compiledClientPlan
  , compiledServerPlan
  , compiledClientBytes
  , compiledServerBytes
  , compiledContractBytes
  , compiledContentManifestBytes
  , compiledDigests
  , compiledDemand
  , digestAuthoritySources
  , validatePublicField
  , validateNavigationInstruction
  , uiPlanErrorTag
  ) where

import Amoebius.Ui.Bind
  ( BoundPortProjection
  , BoundUiProgram
  , Codec
  , PortId
  , UiClientInstruction (..)
  , boundAuthoritySource
  , boundExternalLinkProjection
  , boundPort
  , boundPortProjection
  , boundRequest
  , boundResponse
  , boundUiProjection
  , codecText
  , compiledInstruction
  , portIdText
  )
import Amoebius.Ui.Compile.ClientPlan
  ( ClientPlan
  , clientActionPorts
  , compileClientPlan
  , encodeClientPlan
  )
import Amoebius.Ui.Compile.Demand (RuntimeDemand, compileRuntimeDemand)
import Amoebius.Ui.Compile.ServerPlan
  ( UiServerPlan
  , compileServerPlan
  , encodeServerPlan
  , serverActionPorts
  )
import Amoebius.Ui.ExternalLinkCatalog
  ( externalLinkIdText
  , resolvedLinkId
  , resolvedLinkUrl
  )
import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.Aeson as Aeson
import qualified Data.ByteString as Strict
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as Lazy
import Data.List (intersperse, sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric (showHex)

data PlanDigests = PlanDigests
  { authorityDigest :: Text
  , clientDigest :: Text
  , serverDigest :: Text
  , contractsDigest :: Text
  }
  deriving stock (Eq, Ord, Show)

data CompiledUiPlans = CompiledUiPlans
  ClientPlan
  UiServerPlan
  ByteString
  ByteString
  PlanDigests
  RuntimeDemand

data UiPlanError
  = EmptyUiProjection
  | ClientServerActionMismatch
  | AuthoritySourceOmitted
  | PrivateFieldForbidden Text
  | LinkNavigationAsEffect Text
  deriving stock (Eq, Ord, Show)

compileUiPlans :: BoundUiProgram -> Either UiPlanError CompiledUiPlans
compileUiPlans program = do
  if null (boundUiProjection program) then Left EmptyUiProjection else Right ()
  let client = compileClientPlan program
      server = compileServerPlan program
  if clientActionPorts client /= serverActionPorts server
    then Left ClientServerActionMismatch
    else Right ()
  let authoritySources = fullAuthoritySources program
  if null authoritySources then Left AuthoritySourceOmitted else Right ()
  let clientBytes = encodeClientPlan client
      serverBytes = encodeServerPlan server
      contractBytes = encodeContracts program
      digests = PlanDigests
        {
#ifdef UI_PLAN_CLIENT_ONLY_AUTHORITY_MUTANT
          authorityDigest = digestBytes clientBytes
#else
          authorityDigest = digestAuthoritySources authoritySources
#endif
        , clientDigest = digestBytes clientBytes
        , serverDigest = digestBytes serverBytes
        , contractsDigest = digestBytes contractBytes
        }
      manifestBytes = encodeContentManifest digests
  pure (CompiledUiPlans client server contractBytes manifestBytes digests (compileRuntimeDemand program))

compiledClientPlan :: CompiledUiPlans -> ClientPlan
compiledClientPlan (CompiledUiPlans client _ _ _ _ _) = client

compiledServerPlan :: CompiledUiPlans -> UiServerPlan
compiledServerPlan (CompiledUiPlans _ server _ _ _ _) = server

compiledClientBytes :: CompiledUiPlans -> ByteString
compiledClientBytes = encodeClientPlan . compiledClientPlan

compiledServerBytes :: CompiledUiPlans -> ByteString
compiledServerBytes = encodeServerPlan . compiledServerPlan

compiledContractBytes :: CompiledUiPlans -> ByteString
compiledContractBytes (CompiledUiPlans _ _ contracts _ _ _) = contracts

compiledContentManifestBytes :: CompiledUiPlans -> ByteString
compiledContentManifestBytes (CompiledUiPlans _ _ _ manifest _ _) = manifest

compiledDigests :: CompiledUiPlans -> PlanDigests
compiledDigests (CompiledUiPlans _ _ _ _ digests _) = digests

compiledDemand :: CompiledUiPlans -> RuntimeDemand
compiledDemand (CompiledUiPlans _ _ _ _ _ demand) = demand

digestAuthoritySources :: [Text] -> Text
digestAuthoritySources = digestBytes . Lazy.fromStrict . TextEncoding.encodeUtf8 . Text.intercalate "\n"

validatePublicField :: Text -> Either UiPlanError Text
validatePublicField value
  | any (`Text.isPrefixOf` value) ["private:", "handle:", "credential:", "server:"] =
      Left (PrivateFieldForbidden value)
  | otherwise = Right value

validateNavigationInstruction :: Text -> Either UiPlanError Text
validateNavigationInstruction value
  | any (`Text.isPrefixOf` value) ["fetch:", "effect:", "media:", "form:"] =
      Left (LinkNavigationAsEffect value)
  | otherwise = Right value

uiPlanErrorTag :: UiPlanError -> Text
uiPlanErrorTag problem = case problem of
  EmptyUiProjection -> "EmptyUiProjection"
  ClientServerActionMismatch -> "ClientServerActionMismatch"
  AuthoritySourceOmitted -> "AuthoritySourceOmitted"
  PrivateFieldForbidden _ -> "PrivateFieldForbidden"
  LinkNavigationAsEffect _ -> "LinkNavigationAsEffect"

fullAuthoritySources :: BoundUiProgram -> [Text]
fullAuthoritySources program =
  boundAuthoritySource program
    <> [ "link:" <> externalLinkIdText (resolvedLinkId link) <> ":" <> resolvedLinkUrl link
       | link <- boundExternalLinkProjection program
       ]

encodeContracts :: BoundUiProgram -> ByteString
encodeContracts program = object
  [ (portIdText port, object [("request", string (codecText request)), ("response", string (codecText response))])
  | (port, request, response) <- contractRows program
  ]

contractRows :: BoundUiProgram -> [(PortId, Codec, Codec)]
contractRows program =
  let portMap = Map.fromList [(portIdText (boundPort row), row) | row <- boundPortProjection program]
      eventPorts =
        [ port
        | row <- boundUiProjection program
        , EmitEvent _ port <- [compiledInstruction row]
        ]
   in sortOn (portIdText . firstOfThree) (mapMaybe (contractFor portMap) eventPorts)

contractFor :: Map.Map Text BoundPortProjection -> PortId -> Maybe (PortId, Codec, Codec)
contractFor portMap port = do
  row <- Map.lookup (portIdText port) portMap
  pure (port, boundRequest row, boundResponse row)

firstOfThree :: (first, second, third) -> first
firstOfThree (first, _, _) = first

encodeContentManifest :: PlanDigests -> ByteString
encodeContentManifest digests = object
  [ ("client-plan", string (clientDigest digests))
  , ("contracts", string (contractsDigest digests))
  , ("server-plan", string (serverDigest digests))
  ]

digestBytes :: ByteString -> Text
digestBytes bytes = "sha256:" <> Text.pack (concatMap byteHex (Strict.unpack (SHA256.hashlazy bytes)))
  where
    byteHex byte = case showHex byte "" of
      [digit] -> ['0', digit]
      digits -> digits

string :: Text -> ByteString
string = Aeson.encode

object :: [(Text, ByteString)] -> ByteString
object fields = "{" <> mconcat (intersperse "," (map renderField fields)) <> "}"
  where
    renderField (key, value) = string key <> ":" <> value
