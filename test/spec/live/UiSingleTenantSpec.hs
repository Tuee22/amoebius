{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Live.SingleTenant
import Amoebius.Ui.Realtime.Receipt
import Amoebius.Ui.Realtime.RedisCoordination
import Amoebius.Ui.Realtime.Route
import Amoebius.Ui.Server.Dispatch
import Amoebius.Ui.Server.Security
import Control.Monad (forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  verifyAccess
  verifyCsrf
  coordinated <- verifyCrossReplica
  verifyFreshEffect coordinated
  verifyEdges
  putStrLn "ui-single-tenant-live-ui-single-tenant-live: PASS-SCOPED (pinned access/CSRF/edge oracles; fresh challenge; two-replica routing model; durable receipt authority; provider/edge live infrastructure UNVERIFIED)"

verifyCustody :: IO ()
verifyCustody = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isPrefixOf "55\t" . Text.pack) rows
  assertEqual "Phase-0 custody" 11 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path)
    _ -> die "malformed Phase-55 custody row"

ownerRequest :: RequestContext
ownerRequest = RequestContext Own "https://ui.example" "https://ui.example" "csrf-1" "csrf-1" Nothing False

verifyAccess :: IO ()
verifyAccess = do
  assertEqual "owner mutation" (Right (DispatchTrace 1 1 1)) (dispatchAuthorized ownerRequest)
  forM_
    [ ownerRequest {requestAuthority = Foreign}
    , ownerRequest {requestAuthority = Revoked}
    , ownerRequest {requestAuthority = Unauthenticated}
    ] $ \request -> assertLeft "foreign/revoked/unauthenticated" (dispatchAuthorized request)
  assertLeft "direct bypass" (dispatchAuthorized ownerRequest {requestDirectHandler = True})
  assertLeft "caller tenant" (dispatchAuthorized ownerRequest {requestCallerTenantHeader = Just "forged"})

verifyCsrf :: IO ()
verifyCsrf = do
  assertEqual "valid origin/csrf" (Right ()) (authorizeMutation ownerRequest)
  assertEqual "wrong origin" (Left Forbidden) (authorizeMutation ownerRequest {requestOrigin = "https://evil.example"})
  assertEqual "wrong csrf" (Left Forbidden) (authorizeMutation ownerRequest {requestCsrf = "wrong"})

verifyCrossReplica :: IO CoordinationResult
verifyCrossReplica = do
  let owner = ReplicaId "ui-a"
      origin = ReplicaId "ui-b"
      command = CommandId "cmd:fresh"
      sources = ReceiptSources
        (Map.singleton command (Receipt "redis-nonauthoritative"))
        (Map.singleton command (Receipt "durable-terminal"))
  result <- maybe (die "cross-replica route absent") pure (coordinate owner origin sources command)
  assertEqual "cross-replica durable coordination"
    (CoordinationResult (RedisFanout origin owner) (Receipt "durable-terminal")) result
  let afterRedisFlush = sources {redisAcks = Map.empty}
  assertEqual "Redis-loss durable receipt" (Just (Receipt "durable-terminal")) (authoritativeReceipt afterRedisFlush command)
  pure result

verifyFreshEffect :: CoordinationResult -> IO ()
verifyFreshEffect coordinated = do
  let nonce = "ui-single-tenant-live-fresh-challenge-7f31"
  result <- either (die . show) pure (runSingleTenant nonce ownerRequest coordinated)
  case result of
    SingleTenantResult observed trace _ -> do
      assertEqual "fresh nonce" nonce observed
      assertEqual "effect trace" (DispatchTrace 1 1 1) trace

verifyEdges :: IO ()
verifyEdges = do
  assert (networkEdgeAllowed BrowserEnvoy) "browser->Envoy denied"
  assert (networkEdgeAllowed UiBoundProvider) "bound provider denied"
  forM_ [BrowserUiDirect, BrowserProvider, ForeignPodProvider] $ \edge ->
    assert (not (networkEdgeAllowed edge)) ("forbidden edge open: " <> show edge)

assertLeft :: Show value => String -> Either errorValue value -> IO ()
assertLeft label value = case value of Left _ -> pure (); Right found -> die (label <> ": forbidden success " <> show found)

splitTabs :: String -> [String]
splitTabs source = case break (== '\t') source of (field, []) -> [field]; (field, _ : rest) -> field : splitTabs rest
assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)
assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else let parent = takeDirectory path in if parent == path then die "ui-single-tenant-live-project-root-absent" else ascend parent
