{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The @serve-ui@ boundary ABI: what a request has to satisfy before a handler sees it.
--
-- The boundary's whole job is that authority is derived, never accepted. Every value the
-- caller controls — the tenant header, the origin, the CSRF token, the presented authority
-- epoch, the idempotency key, the body — is an input to a decision, and only the verified
-- credential and the server's own current epoch decide it. 'authorizeAndDispatch' returns
-- the refusal *and* the invocation as one value so the caller cannot dispatch without
-- having a decision in hand; a denial carries 'Nothing' and there is no other constructor
-- for a handler call.
--
-- The seeded mutants are inputs rather than compile-time flags. A boundary whose mutant
-- lives behind CPP needs a rebuild per mutant, and a rebuild is a different binary from the
-- one the gate observed; carrying 'BoundaryMutant' through the decision means all nine run
-- against exactly the binary under test.
module Amoebius.Ui.Server.Dispatch
  ( -- * The in-process authorization trace consumed by the live single-tenant path
    DispatchTrace (..)
  , dispatchAuthorized

    -- * The @serve-ui@ boundary ABI
  , UiServerAbi (..)
  , HandlerContract (..)
  , HandlerBinding (..)
  , BoundaryMutant (..)
  , StartupRefusal (..)
  , ActionRequest (..)
  , BoundaryResponse (..)
  , HandlerInvocation (..)
  , admitServerPlan
  , authorizeAndDispatch
  , parseBoundaryMutant
  , publicResponse
  , unavailableResponse
  ) where

import Amoebius.Ui.Server.RequestContext
  ( ServerRequestContext
  , VerifiedCredential
  , contextSubject
  , contextTenant
  , credentialEpoch
  , credentialGrant
  , credentialPermission
  )
import Amoebius.Ui.Server.Security
import Data.Text (Text)

data DispatchTrace = DispatchTrace
  { handlerEffects :: Int
  , providerEffects :: Int
  , artifactDispatches :: Int
  }
  deriving stock (Eq, Show)

dispatchAuthorized :: RequestContext -> Either SecurityError DispatchTrace
#ifdef UI_SINGLE_TENANT_LIVE_DISPATCH_BEFORE_AUTH_MUTANT
dispatchAuthorized _ = Right (DispatchTrace 1 1 1)
#else
dispatchAuthorized request = do
  authorizeMutation request
  Right (DispatchTrace 1 1 1)
#endif

-- | The wire contract the linked handler registry was compiled against.
data UiServerAbi
  = UiServerV1
  | UnsupportedUiServerAbi Text
  deriving stock (Eq, Show)

-- | A handler's request and response codec identities.
data HandlerContract = HandlerContract
  { contractRequest :: Text
  , contractResponse :: Text
  }
  deriving stock (Eq, Show)

-- | One handler identity linked into the binary, with the contract it implements.
data HandlerBinding = HandlerBinding
  { bindingIdentity :: Text
  , bindingContract :: HandlerContract
  }
  deriving stock (Eq, Show)

-- | The seeded boundary mutants. Each deletes or weakens exactly one guard.
data BoundaryMutant
  = NoBoundaryMutant
  | TrustTenantHeader
  | DispatchBeforeAuthorize
  | SkipCurrentEpoch
  | DisableOriginCheck
  | DropCspHeader
  | ReadyWithUnresolvedHandler
  | ServerFirstHandlerWins
  | ServeServerPlanAsClientAsset
  | NewIdempotencyKeyOnRetry
  deriving stock (Bounded, Enum, Eq, Show)

-- | Why the worker refused to become ready. Startup refusals are pre-readiness by
-- construction: an HTTP error from an already-serving worker is a different, weaker claim.
data StartupRefusal
  = UnsupportedAbi Text
  | UnresolvedHandler Text
  | DuplicateHandlerBinding Text
  | IncompatibleHandlerContract Text
  deriving stock (Eq, Show)

parseBoundaryMutant :: Text -> Maybe BoundaryMutant
parseBoundaryMutant name = lookup name
  [ ("M-trust-tenant-header", TrustTenantHeader)
  , ("M-dispatch-before-authorize", DispatchBeforeAuthorize)
  , ("M-skip-current-epoch", SkipCurrentEpoch)
  , ("M-disable-origin-check", DisableOriginCheck)
  , ("M-drop-csp-header", DropCspHeader)
  , ("M-ready-with-unresolved-handler", ReadyWithUnresolvedHandler)
  , ("M-server-first-handler-wins", ServerFirstHandlerWins)
  , ("M-serve-server-plan-as-client-asset", ServeServerPlanAsClientAsset)
  , ("M-new-idempotency-key-on-retry", NewIdempotencyKeyOnRetry)
  ]

-- | Admit the serialized plan against the registry linked into this binary, before serving.
--
-- Each referenced identity must resolve to exactly one linked binding whose contract
-- matches. Linked handlers the plan never references stay legal and unreachable — the
-- registry is a superset of what a plan may use, and refusing on extra bindings would make
-- one binary serve exactly one plan.
admitServerPlan
  :: BoundaryMutant
  -> UiServerAbi
  -> [(Text, HandlerContract)]
  -> [HandlerBinding]
  -> Either StartupRefusal ()
admitServerPlan mutant abi required linked = do
  case abi of
    UiServerV1 -> Right ()
    UnsupportedUiServerAbi value -> Left (UnsupportedAbi value)
  mapM_ admit required
  where
    admit (identity, contract) = case filter ((== identity) . bindingIdentity) linked of
      [] ->
        if mutant == ReadyWithUnresolvedHandler
          then Right ()
          else Left (UnresolvedHandler identity)
      [binding] -> compatible identity contract binding
      binding : _ : _ ->
        if mutant == ServerFirstHandlerWins
          then compatible identity contract binding
          else Left (DuplicateHandlerBinding identity)
    compatible identity contract binding
      | bindingContract binding == contract = Right ()
      | otherwise = Left (IncompatibleHandlerContract identity)

-- | One decoded action request. Every field here is caller-controlled.
data ActionRequest = ActionRequest
  { actionCase :: Text
  , actionPath :: Text
  , actionOrigin :: Text
  , actionCsrf :: Text
  , actionPresentedEpoch :: Int
  , actionSpoofedTenant :: Maybe Text
  , actionIdempotencyKey :: Text
  , actionBody :: Text
  }
  deriving stock (Eq, Show)

-- | The boundary's answer: a status and public tag for the client, and the audit
-- classification for the append-only record. The audit fields are deliberately separate
-- from the body so a sanitized audit line cannot pick up request content.
data BoundaryResponse = BoundaryResponse
  { responseStatus :: Int
  , responseTag :: Text
  , responseBody :: Text
  , responseAuditClass :: Text
  , responseAuditScope :: Text
  }
  deriving stock (Eq, Show)

-- | A handler call. It exists only where 'authorizeAndDispatch' produced one.
data HandlerInvocation = HandlerInvocation
  { invocationCase :: Text
  , invocationHandler :: Text
  , invocationTenant :: Text
  , invocationSubject :: Text
  , invocationIdempotencyKey :: Text
  , invocationBody :: Text
  }
  deriving stock (Eq, Show)

-- | Whether an action's effect class is a read or a mutation.
data ActionKind = ReadAction | MutateAction
  deriving stock (Eq, Show)

-- | The closed action-to-handler table, one row per Phase-19 port effect. A case with no
-- row has no handler and cannot be reached by spelling one: there is no name-based fallback
-- and no reflection, so an unknown case is refused by the same non-enumerating response as
-- a foreign-scope one.
boundHandlers :: [(Text, (Text, ActionKind))]
boundHandlers =
  [ ("read", ("data-read", ReadAction))
  , ("mutate", ("data-write", MutateAction))
  , ("start", ("workflow-start", MutateAction))
  , ("observe", ("workflow-observe", ReadAction))
  , ("subscribe", ("stream-subscribe", ReadAction))
  , ("upload", ("blob-upload", MutateAction))
  , ("use-artifact", ("artifact-use", MutateAction))
  ]

publicResponse :: Text -> BoundaryResponse
publicResponse body = BoundaryResponse 200 "OK" body "public-asset" "anonymous"

-- | The single non-enumerating refusal. Every unknown, private, unauthenticated, and
-- foreign-scope path returns the same shape, so a prober cannot tell "no such route" from
-- "route exists and you may not have it".
unavailableResponse :: BoundaryResponse
unavailableResponse = BoundaryResponse 404 "Unavailable" "" "denied" "unauthenticated"

-- | Decide one action request, and produce the handler call only if it was authorized.
authorizeAndDispatch
  :: BoundaryMutant
  -> Int
  -> Text
  -> Text
  -> Text
  -> VerifiedCredential
  -> ServerRequestContext
  -> ActionRequest
  -> (BoundaryResponse, Maybe HandlerInvocation)
authorizeAndDispatch mutant currentEpoch expectedTenant expectedSubject expectedCsrf credential context action =
  case refusal of
    Nothing -> (accepted, invocation)
    Just denied
      -- The mutant dispatches first and decides afterwards, which is the ordering the
      -- external handler observer exists to catch: the response still says no.
      | mutant == DispatchBeforeAuthorize -> (denied, invocation)
      | otherwise -> (denied, Nothing)
  where
    -- The tenant the boundary acts on. Only the verified credential decides it; the
    -- caller-authored header is read by exactly one seeded mutant, which is what makes the
    -- mutant a real attack rather than a strawman.
    actingTenant = case (mutant, actionSpoofedTenant action) of
      (TrustTenantHeader, Just claimed) -> claimed
      _ -> contextTenant context
    actingSubject = contextSubject context

    refusal
      | actingTenant /= expectedTenant || actingSubject /= expectedSubject =
          Just (BoundaryResponse 404 "Unavailable" "" "denied" "foreign-hidden")
      | mutant /= DisableOriginCheck && actionOrigin action /= "same-origin" =
          Just (BoundaryResponse 403 "Forbidden" "" "origin-denied" "own")
      | mutant /= DisableOriginCheck && actionCsrf action /= expectedCsrf =
          Just (BoundaryResponse 403 "Forbidden" "" "origin-denied" "own")
      | mutant /= SkipCurrentEpoch
          && (actionPresentedEpoch action /= currentEpoch || credentialEpoch credential /= currentEpoch) =
          Just (BoundaryResponse 409 "ReloadRequired" "" "stale-authority" "own")
      | credentialGrant credential /= "active" =
          Just (BoundaryResponse 404 "Unavailable" "" "denied" "own")
      | otherwise = case bound of
          Nothing -> Just (BoundaryResponse 404 "Unavailable" "" "denied" "own")
          Just (_handler, MutateAction)
            | credentialPermission credential /= "write" ->
                Just (BoundaryResponse 403 "Forbidden" "" "denied" "own")
          Just _ -> Nothing

    bound = lookup (actionCase action) boundHandlers

    invocation = fmap
      (\(handler, _kind) -> HandlerInvocation
        { invocationCase = actionCase action
        , invocationHandler = handler
        , invocationTenant = actingTenant
        , invocationSubject = actingSubject
        , invocationIdempotencyKey = actionIdempotencyKey action
        , invocationBody = actionBody action
        })
      bound

    accepted = case bound of
      Just (_handler, ReadAction) -> BoundaryResponse 200 "OK" echoed "authorized-read" "own"
      Just (_handler, MutateAction) -> BoundaryResponse 202 "Accepted" echoed "authorized-mutation" "own"
      Nothing -> unavailableResponse

    -- The result the client reads back. It carries the caller's own payload, which is what
    -- lets a harness-minted nonce be recovered from the HTTP side as well as from the
    -- handler process — two independent observations of the same authorized effect.
    echoed = "{\"case\":\"" <> actionCase action <> "\",\"result\":\"" <> actionBody action <> "\"}"
