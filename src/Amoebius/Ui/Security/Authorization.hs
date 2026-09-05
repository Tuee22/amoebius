{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Security.Authorization (
    ActionId,
    ActionEffect (..),
    Permission (..),
    Visibility (..),
    ActionSpec (..),
    ActionProjection (..),
    BoundActionRegistry,
    AuthorityEpochs,
    AuthoritySnapshot,
    AuthorizedAction,
    CanRead,
    CanInvoke,
    EffectEvent (..),
    AuthorizationError (..),
    trustedActionId,
    actionIdText,
    bindActionRegistry,
    clientProjection,
    serverProjection,
    authorizationDigestSource,
    authorityEpochs,
    authoritySnapshot,
    authorize,
    canRead,
    canInvoke,
    interpretAuthorized,
    authorizationErrorTag,
) where

import Amoebius.Ui.Security.Scope (
    Owner,
    RequestContext,
    ResourceId,
    ScopeError,
    ScopedUiProgram,
    resolveOwned,
    scopedProgramCase,
 )
import Data.Char (isAlphaNum)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

newtype ActionId = ActionId Text
    deriving stock (Eq, Ord, Show)

data ActionEffect
    = ReadData
    | MutateData
    | StartWorkflow
    | ObserveWorkflow
    | EndSession
    deriving stock (Bounded, Enum, Eq, Ord, Show)

data Permission
    = ReadPermission
    | WritePermission
    | InvokePermission
    deriving stock (Bounded, Enum, Eq, Ord, Show)

data Visibility = Visible | Hidden
    deriving stock (Bounded, Enum, Eq, Ord, Show)

data ActionSpec = ActionSpec
    { specAction :: ActionId
    , specEffect :: ActionEffect
    , specPermission :: Permission
    , specVisibility :: Visibility
    , specIdempotent :: Bool
    }
    deriving stock (Eq, Ord, Show)

data ActionProjection = ActionProjection
    { projectionAction :: ActionId
    , projectionEffect :: ActionEffect
    , projectionPermission :: Permission
    , projectionVisibility :: Visibility
    , projectionIdempotent :: Bool
    }
    deriving stock (Eq, Ord, Show)

data BoundActionRegistry = BoundActionRegistry Text (Map ActionId ActionSpec)

data AuthorityEpochs = AuthorityEpochs
    { policyEpoch :: Int
    , membershipEpoch :: Int
    , grantEpoch :: Int
    , scopeEpoch :: Int
    }
    deriving stock (Eq, Ord, Show)

data AuthoritySnapshot = AuthoritySnapshot AuthorityEpochs (Map ActionId Permission)

data AuthorizedAction = AuthorizedAction ActionSpec

newtype CanRead = CanRead AuthorizedAction

newtype CanInvoke = CanInvoke AuthorizedAction

data EffectEvent = EffectEvent ActionId ActionEffect
    deriving stock (Eq, Ord, Show)

data AuthorizationError
    = InvalidActionId Text
    | InvalidAuthorityEpoch Int
    | MissingAction ActionId
    | UnexpectedAction ActionId
    | DuplicateAction ActionId
    | ProjectionMismatch ActionId
    | PolicyAbsent ActionId
    | PermissionMismatch ActionId
    | WrongScope ScopeError
    | StalePolicyEpoch
    | StaleMembershipEpoch
    | StaleGrantEpoch
    | StaleScopeEpoch
    deriving stock (Eq, Ord, Show)

trustedActionId :: Text -> Either AuthorizationError ActionId
trustedActionId value
    | validIdentifier value = Right (ActionId value)
    | otherwise = Left (InvalidActionId value)

actionIdText :: ActionId -> Text
actionIdText (ActionId value) = value

bindActionRegistry ::
    ScopedUiProgram ->
    [ActionSpec] ->
    [ActionProjection] ->
    Either AuthorizationError BoundActionRegistry
bindActionRegistry scoped specs projections = do
    specMap <- uniqueMap specAction specs
    projectionMap <- uniqueMap projectionAction projections
    checkSetParity (Map.keysSet specMap) (Map.keysSet projectionMap)
    traverse_ (checkProjection projectionMap) specs
    pure (BoundActionRegistry (scopedProgramCase scoped) specMap)

clientProjection :: BoundActionRegistry -> [ActionProjection]
clientProjection (BoundActionRegistry _ registry) = normalizedProjection registry

serverProjection :: BoundActionRegistry -> [ActionProjection]
serverProjection (BoundActionRegistry _ registry) = normalizedProjection registry

authorizationDigestSource :: BoundActionRegistry -> [Text]
authorizationDigestSource (BoundActionRegistry programCase registry) =
    ("program:" <> programCase) : map renderAction (normalizedProjection registry)
  where
    renderAction projection =
        Text.intercalate
            ":"
            [ "action"
            , actionIdText (projectionAction projection)
            , Text.pack (show (projectionEffect projection))
            , Text.pack (show (projectionPermission projection))
            , Text.pack (show (projectionVisibility projection))
            , if projectionIdempotent projection then "true" else "false"
            ]

authorityEpochs :: Int -> Int -> Int -> Int -> Either AuthorizationError AuthorityEpochs
authorityEpochs policy membership grant scope
    | any (< 0) [policy, membership, grant, scope] =
        Left (InvalidAuthorityEpoch (minimum [policy, membership, grant, scope]))
    | otherwise = Right (AuthorityEpochs policy membership grant scope)

authoritySnapshot :: AuthorityEpochs -> Map ActionId Permission -> AuthoritySnapshot
authoritySnapshot = AuthoritySnapshot

authorize ::
    BoundActionRegistry ->
    AuthoritySnapshot ->
    AuthorityEpochs ->
    RequestContext ->
    Owner ->
    ResourceId ->
    ActionId ->
    Permission ->
    Either AuthorizationError AuthorizedAction
authorize (BoundActionRegistry _ registry) (AuthoritySnapshot current policy) presented context owner resource action requested = do
    spec <- maybe (Left (MissingAction action)) Right (Map.lookup action registry)
#ifdef UI_AUTH_VISIBILITY_MUTANT
    if specVisibility spec == Visible
        then Right (AuthorizedAction spec)
        else Left (PermissionMismatch action)
#else
    _ <- either (Left . WrongScope) Right (resolveOwned context owner resource)
    checkEpochs current presented
#ifdef UI_AUTH_DEFAULT_ALLOW_MUTANT
    let granted = Map.findWithDefault (specPermission spec) action policy
#else
    granted <- maybe (Left (PolicyAbsent action)) Right (Map.lookup action policy)
#endif
    if requested == specPermission spec && granted == specPermission spec
        then Right (AuthorizedAction spec)
        else Left (PermissionMismatch action)
#endif

canRead :: AuthorizedAction -> Maybe CanRead
canRead action@(AuthorizedAction spec)
    | specPermission spec == ReadPermission = Just (CanRead action)
    | otherwise = Nothing

canInvoke :: AuthorizedAction -> Maybe CanInvoke
canInvoke action@(AuthorizedAction spec)
    | specPermission spec == InvokePermission = Just (CanInvoke action)
    | otherwise = Nothing

interpretAuthorized :: AuthorizedAction -> [EffectEvent]
interpretAuthorized (AuthorizedAction spec) = [EffectEvent (specAction spec) (specEffect spec)]

authorizationErrorTag :: AuthorizationError -> Text
authorizationErrorTag problem = case problem of
    InvalidActionId _ -> "InvalidActionId"
    InvalidAuthorityEpoch _ -> "InvalidAuthorityEpoch"
    MissingAction _ -> "MissingAction"
    UnexpectedAction _ -> "UnexpectedAction"
    DuplicateAction _ -> "DuplicateAction"
    ProjectionMismatch _ -> "ProjectionMismatch"
    PolicyAbsent _ -> "PolicyAbsent"
    PermissionMismatch _ -> "PermissionMismatch"
    WrongScope _ -> "WrongScope"
    StalePolicyEpoch -> "StalePolicyEpoch"
    StaleMembershipEpoch -> "StaleMembershipEpoch"
    StaleGrantEpoch -> "StaleGrantEpoch"
    StaleScopeEpoch -> "StaleScopeEpoch"

uniqueMap :: (value -> ActionId) -> [value] -> Either AuthorizationError (Map ActionId value)
uniqueMap keyOf values = go Map.empty values
  where
    go result [] = Right result
    go result (value : rest)
        | Map.member key result = Left (DuplicateAction key)
        | otherwise = go (Map.insert key value result) rest
      where
        key = keyOf value

checkSetParity :: Set ActionId -> Set ActionId -> Either AuthorizationError ()
checkSetParity expected actual = case (Set.lookupMin (expected Set.\\ actual), Set.lookupMin (actual Set.\\ expected)) of
    (Just action, _) -> Left (MissingAction action)
    (Nothing, Just action) -> Left (UnexpectedAction action)
    (Nothing, Nothing) -> Right ()

checkProjection :: Map ActionId ActionProjection -> ActionSpec -> Either AuthorizationError ()
checkProjection projections spec = case Map.lookup (specAction spec) projections of
    Nothing -> Left (MissingAction (specAction spec))
    Just projection
        | projection == project spec -> Right ()
        | otherwise -> Left (ProjectionMismatch (specAction spec))

normalizedProjection :: Map ActionId ActionSpec -> [ActionProjection]
normalizedProjection registry = sortOn projectionAction (map project (Map.elems registry))

project :: ActionSpec -> ActionProjection
project spec =
    ActionProjection
        { projectionAction = specAction spec
        , projectionEffect = specEffect spec
        , projectionPermission = specPermission spec
        , projectionVisibility = specVisibility spec
        , projectionIdempotent = specIdempotent spec
        }

checkEpochs :: AuthorityEpochs -> AuthorityEpochs -> Either AuthorizationError ()
checkEpochs current presented
    | policyEpoch current /= policyEpoch presented = Left StalePolicyEpoch
    | membershipEpoch current /= membershipEpoch presented = Left StaleMembershipEpoch
    | grantEpoch current /= grantEpoch presented = Left StaleGrantEpoch
    | scopeEpoch current /= scopeEpoch presented = Left StaleScopeEpoch
    | otherwise = Right ()

traverse_ :: (value -> Either problem ()) -> [value] -> Either problem ()
traverse_ check = go
  where
    go [] = Right ()
    go (value : rest) = check value >> go rest

validIdentifier :: Text -> Bool
validIdentifier value =
    not (Text.null value)
        && Text.all (\character -> isAlphaNum character || character `elem` ['-', '_', '.', ':']) value
