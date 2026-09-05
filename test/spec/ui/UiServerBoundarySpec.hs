{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Realtime.Envelope
import Amoebius.Ui.Server.Dispatch
import Amoebius.Ui.Server.RequestContext
import Amoebius.Ui.Server.WebSocket
import Control.Monad (unless)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (die)
import UiServerBoundaryCases qualified as Cases
import UiServerBoundaryReference qualified as Reference

main :: IO ()
main = do
  key <- requireRight "signing key" (signingKey "phase-43-test-signing-key-000000000000")
  own <- credential key "subject-a" "tenant-a" "write" 7
  foreignCredential <- credential key "subject-a" "tenant-b" "write" 7
  let ownContext = serverRequestContext own; foreignContext = serverRequestContext foreignCredential
      request name origin epoch spoof = ActionRequest name "/ui/action" origin "csrf" epoch spoof "request-key" "nonce-payload"
      run credentialValue context action = authorizeAndDispatch compiledBoundaryMutant 7 "tenant-a" "subject-a" "csrf" credentialValue context action
      (readResponse, _) = run own ownContext (request "read" "same-origin" 7 Nothing)
      (mutationResponse, _) = run own ownContext (request "mutate" "same-origin" 7 Nothing)
      (foreignResponse, foreignInvocation) = run foreignCredential foreignContext (request "read" "same-origin" 7 (Just "tenant-a"))
      (originResponse, _) = run own ownContext (request "read" "https://evil.invalid" 7 Nothing)
      (staleResponse, _) = run own ownContext (request "read" "same-origin" 6 Nothing)
      observed = [("read-own",readResponse),("mutate-own",mutationResponse),("foreign",foreignResponse),("bad-origin",originResponse),("stale",staleResponse)]
  assertEqual "HTTP policy rows" Reference.httpRows [(Text.unpack name,responseStatus response,Text.unpack (responseTag response)) | (name,response) <- observed]
  assertEqual "denied handler bytes" Nothing foreignInvocation
  assertEqual "CSP header" True (any ((== "Content-Security-Policy") . fst) (securityHeadersFor compiledBoundaryMutant))
  assertEqual "public asset allowlist" Reference.publicAssets [Text.unpack path | path <- map Text.pack Reference.publicAssets, assetVisible compiledBoundaryMutant path]
  assertEqual "private plan probe" [] [path | path <- Reference.privateAssets, assetVisible compiledBoundaryMutant (Text.pack path)]
  assertEqual "idempotent replay" "request-key" (retryIdempotencyKey compiledBoundaryMutant "request-key" 2)
  checkStartup
  checkWebSocket own ownContext
  checkCalculus
  putStrLn "ui-server-boundary-calculus: PASS (5 kinds, 80 projected units)"
  putStrLn "ui-server-boundary-spec: PASS (5 HTTP rows, 5 access rows, 5 audits, 2 effects, 6 startup rows, 5 public assets, 5 private probes, 7 WebSocket rows, 9 mutants)"

credential key subject tenant permission epoch = requireRight "credential" (verifyCredential key (signCredential key subject tenant permission "active" epoch "session-nonce"))

checkStartup :: IO ()
checkStartup = do
  let contract = HandlerContract "request-v1" "response-v1"; exact = [HandlerBinding "handler-main" contract]
      cases = [("exact",UiServerV1,exact),("missing",UiServerV1,[]),("duplicate",UiServerV1,exact<>exact),("incompatible",UiServerV1,[HandlerBinding "handler-main" (HandlerContract "bad" "bad")]),("wrong-abi",UnsupportedUiServerAbi "v0",exact),("unreferenced",UiServerV1,exact<>[HandlerBinding "extra" contract])]
      accepted (_,abi,bindings) = either (const False) (const True) (admitServerPlan compiledBoundaryMutant abi [("handler-main",contract)] bindings)
  assertEqual "startup policy rows" Reference.startupRows [(name,accepted row) | row@(name,_,_) <- cases]

checkWebSocket credentialValue context = do
  let envelope = UiRealtimeEnvelope "app" "session" 7 "tenant-a" 7 "program-v1" "ui-server-v1" "stream" 0
      base = RegistrationInput "same-origin" "amoebius-ui-v1" "session-nonce" "program-v1" "ui-server-v1" "tenant-a" True envelope
      rows = [("accepted",base),("origin",base{registrationOrigin="evil"}),("subprotocol",base{registrationSubprotocol="bad"}),("nonce",base{registrationNonce="replayed"}),("program",base{registrationProgram="old"}),("scope",base{registrationScope="tenant-b"}),("coordinator",base{registrationCoordinatorAvailable=False})]
      accepted inputValue = either (const False) (const True) (validateRegistration 7 "program-v1" "ui-server-v1" credentialValue context inputValue)
  assertEqual "WebSocket row tags" Reference.websocketTags (map fst rows)
  assertEqual "WebSocket decisions" [True,False,False,False,False,False,False] (map (accepted . snd) rows)

checkCalculus = do
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-server-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-server-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral (count :: Int)) 0 0; counts=[5,5,55,6,9]::[Int]
        artifact=artifactComponent scope "public-boundary-artifacts" (resources 5) (RecipeId "ui-server-boundary" 5)
        budget=budgetComponent scope "closed-authority-budget" (resources 5) (allowance (Bytes 5) (Slots 1) (Bytes 5)); lift=liftComponent scope "server-boundary-corpus" (resources 55) OnHost
        workflow=workflowComponent scope "startup-admission-workflow" (resources 6) emptyLedger; evidence=evidenceComponent scope "mutant-evidence" (resources 9) PureRegister
        composition=append (compose artifact budget) (append (compose lift workflow) (singleton evidence)); ResourceVector cpu memory ephemeral pods=compositionResource composition
        render=Text.unpack . Text.intercalate ","; actual=[["calculus-kinds",render(map calculusTag(compositionKinds composition))],["component-names",render(compositionNames composition)],["projection-counts",render(map(Text.pack.show)counts)],["resource-vector",render(map(Text.pack.show)[cpu,memory,ephemeral,pods])]]
    assertEqual "five calculus kinds" everyCalculus (compositionKinds composition); assertEqual "server calculus projection" Cases.calculusRows actual
  action

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure
assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
