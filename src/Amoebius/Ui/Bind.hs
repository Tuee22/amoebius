{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Bind
  ( PortId
  , HandlerId
  , Codec
  , SourceId
  , RouteId
  , EventName
  , PortEffect (..)
  , ScopeRequirement (..)
  , RetryPolicy (..)
  , AuditClass (..)
  , CapabilityName (..)
  , PortRequirement (..)
  , HandlerSpec (..)
  , CapabilityBinding (..)
  , UiClientInstruction (..)
  , UiProjectionRequirement (..)
  , BoundPortProjection (..)
  , BoundUiProjection (..)
  , BindEvent (..)
  , BoundUiProgram
  , UiBindError (..)
  , trustedPortId
  , trustedHandlerId
  , trustedCodec
  , trustedSourceId
  , trustedRouteId
  , trustedEventName
  , portIdText
  , handlerIdText
  , codecText
  , sourceIdText
  , routeIdText
  , eventNameText
  , parsePortEffectTarget
  , bindUiProgram
  , bindUiProgramWithProjection
  , boundPortProjection
  , boundUiProjection
  , boundExternalLinkProjection
  , boundAuthoritySource
  , interpretBoundProgram
  , uiBindErrorTag
  ) where

import Amoebius.Ui.ExternalLinkCatalog
  ( BoundExternalLinks
  , ExternalLinkId
  , ResolvedExternalLink
  , resolvedLinkId
  , resolvedExternalLinks
  )
import Amoebius.Ui.Security.Authorization (BoundActionRegistry, authorizationDigestSource)
import Data.Char (isAlphaNum)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text

newtype PortId = PortId Text
  deriving stock (Eq, Ord, Show)

newtype HandlerId = HandlerId Text
  deriving stock (Eq, Ord, Show)

newtype Codec = Codec Text
  deriving stock (Eq, Ord, Show)

newtype SourceId = SourceId Text
  deriving stock (Eq, Ord, Show)

newtype RouteId = RouteId Text
  deriving stock (Eq, Ord, Show)

newtype EventName = EventName Text
  deriving stock (Eq, Ord, Show)

data PortEffect
  = PortReadData
  | PortMutateData
  | PortStartWorkflow
  | PortObserveWorkflow
  | PortSubscribe
  | PortUploadBounded
  | PortUseReadyArtifact
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ScopeRequirement = OwnerScope | TenantScope | GrantScope
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data RetryPolicy = NoRetryContract | IdempotentRetry
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data AuditClass
  = ReadAudit
  | MutationAudit
  | WorkflowAudit
  | StreamAudit
  | BlobAudit
  | ArtifactAudit
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data CapabilityName
  = SqlRead
  | SqlWrite
  | Workflow
  | PulsarSubscription
  | ContentStore
  | InferenceEngine
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data PortRequirement = PortRequirement
  { requiredPort :: PortId
  , requiredRequest :: Codec
  , requiredResponse :: Codec
  , requiredScope :: ScopeRequirement
  , requiredEffect :: PortEffect
  }
  deriving stock (Eq, Ord, Show)

data HandlerSpec = HandlerSpec
  { handlerId :: HandlerId
  , handlerRequest :: Codec
  , handlerResponse :: Codec
  , handlerScope :: ScopeRequirement
  , handlerRetry :: RetryPolicy
  , handlerAudit :: AuditClass
  }
  deriving stock (Eq, Ord, Show)

data CapabilityBinding = CapabilityBinding HandlerId CapabilityName
  deriving stock (Eq, Ord, Show)

data UiClientInstruction
  = ViewText
  | EmitEvent EventName PortId
  | NavigateExternal ExternalLinkId
  deriving stock (Eq, Ord, Show)

data UiProjectionRequirement = UiProjectionRequirement
  { uiProjectionSource :: SourceId
  , uiProjectionInstruction :: UiClientInstruction
  , uiProjectionRoute :: Maybe RouteId
  , uiProjectionContract :: Maybe Codec
  }
  deriving stock (Eq, Ord, Show)

data BoundPortProjection = BoundPortProjection
  { boundPort :: PortId
  , boundHandler :: HandlerId
  , boundCapability :: CapabilityName
  , boundRequest :: Codec
  , boundResponse :: Codec
  , boundEffect :: PortEffect
  , boundScope :: ScopeRequirement
  , boundRetry :: RetryPolicy
  , boundAudit :: AuditClass
  }
  deriving stock (Eq, Ord, Show)

data BoundUiProjection = BoundUiProjection
  { compiledSource :: SourceId
  , compiledInstruction :: UiClientInstruction
  , compiledRoute :: RouteId
  , compiledContract :: Maybe Codec
  , compiledAudit :: Maybe AuditClass
  , compiledHandler :: Maybe HandlerId
  }
  deriving stock (Eq, Ord, Show)

data BindEvent = PortBound PortId HandlerId CapabilityName
  deriving stock (Eq, Ord, Show)

data BoundUiProgram = BoundUiProgram
  BoundActionRegistry
  (Map PortId BoundPortProjection)
  BoundExternalLinks
  (Map SourceId BoundUiProjection)

data UiBindError
  = InvalidPortId Text
  | InvalidHandlerId Text
  | InvalidCodec Text
  | InvalidSourceId Text
  | InvalidRouteId Text
  | InvalidEventName Text
  | MissingHandler PortId
  | DuplicateHandler HandlerId
  | UnexpectedHandler HandlerId
  | DuplicatePort PortId
  | ContractMismatch PortId
  | MissingCapability HandlerId
  | DuplicateCapability HandlerId
  | UnexpectedCapability HandlerId
  | ScopeMismatch PortId
  | IdempotencyRequired PortId
  | UnboundedUpload PortId
  | UnboundedSubscription PortId
  | ArtifactNotReady PortId
  | ProviderCoordinateForbidden Text
  | ExternalLinkNotAnEffect Text
  | UnknownPortEffect Text
  | DuplicateProjection SourceId
  | MissingRouteGuard SourceId
  | ProjectionMissingPort PortId
  | ProjectionContractMismatch SourceId
  | ProjectionMissingExternalLink ExternalLinkId
  deriving stock (Eq, Ord, Show)

trustedPortId :: Text -> Either UiBindError PortId
trustedPortId value
  | validIdentifier value = Right (PortId value)
  | otherwise = Left (InvalidPortId value)

trustedHandlerId :: Text -> Either UiBindError HandlerId
trustedHandlerId value
  | validIdentifier value = Right (HandlerId value)
  | otherwise = Left (InvalidHandlerId value)

trustedCodec :: Text -> Either UiBindError Codec
trustedCodec value
  | validIdentifier value = Right (Codec value)
  | otherwise = Left (InvalidCodec value)

trustedSourceId :: Text -> Either UiBindError SourceId
trustedSourceId value
  | validIdentifier value = Right (SourceId value)
  | otherwise = Left (InvalidSourceId value)

trustedRouteId :: Text -> Either UiBindError RouteId
trustedRouteId value
  | validIdentifier value = Right (RouteId value)
  | otherwise = Left (InvalidRouteId value)

trustedEventName :: Text -> Either UiBindError EventName
trustedEventName value
  | validIdentifier value = Right (EventName value)
  | otherwise = Left (InvalidEventName value)

portIdText :: PortId -> Text
portIdText (PortId value) = value

handlerIdText :: HandlerId -> Text
handlerIdText (HandlerId value) = value

codecText :: Codec -> Text
codecText (Codec value) = value

sourceIdText :: SourceId -> Text
sourceIdText (SourceId value) = value

routeIdText :: RouteId -> Text
routeIdText (RouteId value) = value

eventNameText :: EventName -> Text
eventNameText (EventName value) = value

parsePortEffectTarget :: Text -> Either UiBindError PortEffect
parsePortEffectTarget value = case value of
  "ReadData" -> Right PortReadData
  "MutateData" -> Right PortMutateData
  "StartWorkflow" -> Right PortStartWorkflow
  "ObserveWorkflow" -> Right PortObserveWorkflow
  "Subscribe" -> Right PortSubscribe
  "UploadBounded" -> Right PortUploadBounded
  "UseReadyArtifact" -> Right PortUseReadyArtifact
  _
#ifdef UI_EFFECT_RAW_TOPIC_MUTANT
    | any (`Text.isPrefixOf` value) ["pulsar://", "topic:"] -> Right PortSubscribe
#endif
#ifdef UI_EFFECT_LINK_AS_URL_MUTANT
    | any (`Text.isPrefixOf` value) ["https://", "http://", "link:"] -> Right PortReadData
#endif
    | any (`Text.isPrefixOf` value) ["pulsar://", "topic:", "sql:", "bucket:", "vault:"] ->
        Left (ProviderCoordinateForbidden value)
    | any (`Text.isPrefixOf` value) ["https://", "http://", "link:"] ->
        Left (ExternalLinkNotAnEffect value)
    | otherwise -> Left (UnknownPortEffect value)

bindUiProgram
  :: BoundActionRegistry
  -> [PortRequirement]
  -> [HandlerSpec]
  -> [CapabilityBinding]
  -> BoundExternalLinks
  -> Either UiBindError BoundUiProgram
bindUiProgram authorization ports handlers capabilities links = do
  portMap <- uniqueMap requiredPort DuplicatePort ports
  handlerMap <- uniqueMap handlerId DuplicateHandler handlers
  capabilityMap <- uniqueCapabilities capabilities
  projections <- traverse (bindPort handlers capabilityMap) (Map.elems portMap)
  let usedHandlers = Set.fromList (map boundHandler projections)
  checkNoUnexpected UnexpectedHandler usedHandlers (Map.keysSet handlerMap)
  checkNoUnexpected UnexpectedCapability usedHandlers (Map.keysSet capabilityMap)
  pure (BoundUiProgram authorization (Map.fromList [(boundPort row, row) | row <- projections]) links Map.empty)

bindUiProgramWithProjection
  :: BoundActionRegistry
  -> [PortRequirement]
  -> [HandlerSpec]
  -> [CapabilityBinding]
  -> BoundExternalLinks
  -> [UiProjectionRequirement]
  -> Either UiBindError BoundUiProgram
bindUiProgramWithProjection authorization ports handlers capabilities links requirements = do
  BoundUiProgram sealed portMap sealedLinks _ <- bindUiProgram authorization ports handlers capabilities links
  sourceMap <- uniqueMap uiProjectionSource DuplicateProjection requirements
  compiled <- traverse (bindProjection portMap sealedLinks) (Map.elems sourceMap)
  pure (BoundUiProgram sealed portMap sealedLinks (Map.fromList [(compiledSource row, row) | row <- compiled]))

boundPortProjection :: BoundUiProgram -> [BoundPortProjection]
boundPortProjection (BoundUiProgram _ ports _ _) = sortOn boundPort (Map.elems ports)

boundUiProjection :: BoundUiProgram -> [BoundUiProjection]
boundUiProjection (BoundUiProgram _ _ _ projections) = sortOn compiledSource (Map.elems projections)

boundExternalLinkProjection :: BoundUiProgram -> [ResolvedExternalLink]
boundExternalLinkProjection (BoundUiProgram _ _ links _) = resolvedExternalLinks links

boundAuthoritySource :: BoundUiProgram -> [Text]
boundAuthoritySource (BoundUiProgram authorization ports _ _) =
  authorizationDigestSource authorization <> map renderPort (sortOn boundPort (Map.elems ports))
  where
    renderPort row = Text.intercalate ":"
      [ "port"
      , portIdText (boundPort row)
      , handlerIdText (boundHandler row)
      , Text.pack (show (boundCapability row))
      , codecText (boundRequest row)
      , codecText (boundResponse row)
      , Text.pack (show (boundEffect row))
      , Text.pack (show (boundScope row))
      , Text.pack (show (boundRetry row))
      , Text.pack (show (boundAudit row))
      ]

interpretBoundProgram :: BoundUiProgram -> [BindEvent]
interpretBoundProgram program =
  [PortBound (boundPort row) (boundHandler row) (boundCapability row) | row <- boundPortProjection program]

uiBindErrorTag :: UiBindError -> Text
uiBindErrorTag problem = case problem of
  InvalidPortId _ -> "InvalidPortId"
  InvalidHandlerId _ -> "InvalidHandlerId"
  InvalidCodec _ -> "InvalidCodec"
  InvalidSourceId _ -> "InvalidSourceId"
  InvalidRouteId _ -> "InvalidRouteId"
  InvalidEventName _ -> "InvalidEventName"
  MissingHandler _ -> "MissingHandler"
  DuplicateHandler _ -> "DuplicateHandler"
  UnexpectedHandler _ -> "UnexpectedHandler"
  DuplicatePort _ -> "DuplicatePort"
  ContractMismatch _ -> "ContractMismatch"
  MissingCapability _ -> "MissingCapability"
  DuplicateCapability _ -> "DuplicateCapability"
  UnexpectedCapability _ -> "UnexpectedCapability"
  ScopeMismatch _ -> "ScopeMismatch"
  IdempotencyRequired _ -> "IdempotencyRequired"
  UnboundedUpload _ -> "UnboundedUpload"
  UnboundedSubscription _ -> "UnboundedSubscription"
  ArtifactNotReady _ -> "ArtifactNotReady"
  ProviderCoordinateForbidden _ -> "ProviderCoordinateForbidden"
  ExternalLinkNotAnEffect _ -> "ExternalLinkNotAnEffect"
  UnknownPortEffect _ -> "UnknownPortEffect"
  DuplicateProjection _ -> "DuplicateProjection"
  MissingRouteGuard _ -> "MissingRouteGuard"
  ProjectionMissingPort _ -> "ProjectionMissingPort"
  ProjectionContractMismatch _ -> "ProjectionContractMismatch"
  ProjectionMissingExternalLink _ -> "ProjectionMissingExternalLink"

bindPort
  :: [HandlerSpec]
  -> Map HandlerId CapabilityName
  -> PortRequirement
  -> Either UiBindError BoundPortProjection
bindPort handlers capabilities port = do
  checkBounded port
  handler <- selectHandler port handlers
#ifndef UI_EFFECT_SWAP_RESPONSE_MUTANT
  if handlerResponse handler /= requiredResponse port
    then Left (ContractMismatch (requiredPort port))
    else Right ()
#endif
#ifndef UI_EFFECT_ERASE_SCOPE_MUTANT
  if handlerScope handler /= requiredScope port
    then Left (ScopeMismatch (requiredPort port))
    else Right ()
#endif
#ifndef UI_EFFECT_RETRY_MUTANT
  if requiresIdempotency (requiredEffect port) && handlerRetry handler /= IdempotentRetry
    then Left (IdempotencyRequired (requiredPort port))
    else Right ()
#endif
#ifdef UI_EFFECT_DROP_CAPABILITY_MUTANT
  let capability = Map.findWithDefault SqlRead (handlerId handler) capabilities
#else
  capability <- maybe (Left (MissingCapability (handlerId handler))) Right
    (Map.lookup (handlerId handler) capabilities)
#endif
  pure BoundPortProjection
    { boundPort = requiredPort port
    , boundHandler = handlerId handler
    , boundCapability = capability
    , boundRequest = requiredRequest port
    , boundResponse = requiredResponse port
    , boundEffect = requiredEffect port
    , boundScope = handlerScope handler
    , boundRetry = handlerRetry handler
    , boundAudit = handlerAudit handler
    }

bindProjection
  :: Map PortId BoundPortProjection
  -> BoundExternalLinks
  -> UiProjectionRequirement
  -> Either UiBindError BoundUiProjection
bindProjection portMap links requirement = do
  route <- maybe (Left (MissingRouteGuard (uiProjectionSource requirement))) Right (uiProjectionRoute requirement)
  case uiProjectionInstruction requirement of
    ViewText -> Right BoundUiProjection
      { compiledSource = uiProjectionSource requirement
      , compiledInstruction = ViewText
      , compiledRoute = route
      , compiledContract = uiProjectionContract requirement
      , compiledAudit = Nothing
      , compiledHandler = Nothing
      }
    instruction@(EmitEvent _ port) -> do
      bound <- maybe (Left (ProjectionMissingPort port)) Right (Map.lookup port portMap)
      if uiProjectionContract requirement /= Just (boundRequest bound)
        then Left (ProjectionContractMismatch (uiProjectionSource requirement))
        else Right BoundUiProjection
          { compiledSource = uiProjectionSource requirement
          , compiledInstruction = instruction
          , compiledRoute = route
          , compiledContract = uiProjectionContract requirement
          , compiledAudit = Just (boundAudit bound)
          , compiledHandler = Just (boundHandler bound)
          }
    instruction@(NavigateExternal link) ->
      if any ((== link) . resolvedLinkId) (resolvedExternalLinks links)
        then Right BoundUiProjection
          { compiledSource = uiProjectionSource requirement
          , compiledInstruction = instruction
          , compiledRoute = route
          , compiledContract = uiProjectionContract requirement
          , compiledAudit = Nothing
          , compiledHandler = Nothing
          }
        else Left (ProjectionMissingExternalLink link)

selectHandler :: PortRequirement -> [HandlerSpec] -> Either UiBindError HandlerSpec
selectHandler port handlers = case filter ((== requiredRequest port) . handlerRequest) handlers of
  [] -> Left (MissingHandler (requiredPort port))
  [handler] -> Right handler
#ifdef UI_EFFECT_FIRST_HANDLER_MUTANT
  first : _ -> Right first
#else
  _first : second : _ -> Left (DuplicateHandler (handlerId second))
#endif

checkBounded :: PortRequirement -> Either UiBindError ()
checkBounded port = case requiredEffect port of
  PortUploadBounded
    | codecText (requiredRequest port) /= "BoundedBlob" -> Left (UnboundedUpload (requiredPort port))
  PortSubscribe
    | codecText (requiredRequest port) /= "Subscription" -> Left (UnboundedSubscription (requiredPort port))
  PortUseReadyArtifact
    | codecText (requiredRequest port) /= "ReadyArtifactHandle" -> Left (ArtifactNotReady (requiredPort port))
  _ -> Right ()

requiresIdempotency :: PortEffect -> Bool
requiresIdempotency effect = case effect of
  PortReadData -> False
  PortMutateData -> True
  PortStartWorkflow -> True
  PortObserveWorkflow -> False
  PortSubscribe -> False
  PortUploadBounded -> True
  PortUseReadyArtifact -> True

uniqueMap
  :: Ord key
  => (value -> key)
  -> (key -> UiBindError)
  -> [value]
  -> Either UiBindError (Map key value)
uniqueMap keyOf duplicate = go Map.empty
  where
    go result [] = Right result
    go result (value : rest)
      | Map.member key result = Left (duplicate key)
      | otherwise = go (Map.insert key value result) rest
      where
        key = keyOf value

uniqueCapabilities :: [CapabilityBinding] -> Either UiBindError (Map HandlerId CapabilityName)
uniqueCapabilities = go Map.empty
  where
    go result [] = Right result
    go result (CapabilityBinding handler capability : rest)
      | Map.member handler result = Left (DuplicateCapability handler)
      | otherwise = go (Map.insert handler capability result) rest

checkNoUnexpected
  :: (HandlerId -> UiBindError)
  -> Set HandlerId
  -> Set HandlerId
  -> Either UiBindError ()
checkNoUnexpected problem expected actual = case Set.lookupMin (actual Set.\\ expected) of
  Just handler -> Left (problem handler)
  Nothing -> Right ()

validIdentifier :: Text -> Bool
validIdentifier value =
  not (Text.null value)
    && Text.all (\character -> isAlphaNum character || character `elem` ['-', '_', '.', ':']) value
