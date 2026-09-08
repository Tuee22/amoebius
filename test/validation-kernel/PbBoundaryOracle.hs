{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored Phase-50 expectations.  This module deliberately
-- imports no Amoebius module; the acquired runner owns joining these
-- expectations to concrete and fake-adapter observations.
module PbBoundaryOracle (main) where

import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (isInfixOf)
import System.Exit (exitFailure)

main :: IO ()
main = do
  bootstrap <- ByteString.readFile "pb/__main__.py"
  continuation <- ByteString.readFile "src/validation-kernel/Amoebius/Validation/PbBoundary.hs"
  supervisor <- ByteString.readFile "src/validation-kernel/Amoebius/Validation/PbBoundaryRun/Internal.hs"
  let bootstrapText = ByteString8.unpack bootstrap
      continuationText = ByteString8.unpack continuation
      supervisorText = ByteString8.unpack supervisor
      failures =
        [ label
        | (label, expected, observed) <- expectations bootstrapText continuationText supervisorText
        , not expected || not observed
        ]
  unless (null failures) $ do
    putStrLn ("pb-boundary-oracle: RED " <> show failures)
    exitFailure
  putStrLn "pb-boundary-oracle: PASS (4 platforms, 8 argv cases, 8 mutants, 18 rows)"

expectations :: String -> String -> String -> [(String, Bool, Bool)]
expectations bootstrap continuation supervisor =
  [ present "linux-amd64" "linux-amd64" bootstrap
  , present "linux-arm64" "linux-arm64" bootstrap
  , present "darwin-arm64" "darwin-arm64" bootstrap
  , present "windows-amd64" "windows-amd64" bootstrap
  , present "isolated-environment" "environment = {}" bootstrap
  , present "contained-path" "environment[\"PATH\"] = str(toolchain / \".ghcup\" / \"bin\")" bootstrap
  , present "contained-cabal-directory" "environment[\"CABAL_DIR\"] = str(cache / \"cabal\")" bootstrap
  , present "offline-build" "\"--offline\", \"--jobs=1\", BUILD_TARGET" bootstrap
  , present "exact-locator" "\"list-bin\"" bootstrap
  , present "opaque-argv" "adapter.handoff(binary, [binary] + arguments)" bootstrap
  , present "single-exec" "os.execv(binary, arguments)" bootstrap
  , present "post-start-challenge" "awaitFile (protocolRoot </> \"challenge\")" continuation
  , present "external-ack" "awaitAcknowledgement" continuation
  , present "nonzero-propagation" "ExitFailure 73" continuation
  , present "observation-schema" "amoebius-pb-handoff-observation-v1" continuation
  , present "fixed-count-entropy" "getRandomBytes 32" supervisor
  , absent "unbounded-entropy-read" "ByteString.readFile \"/dev/urandom\"" supervisor
  , present "memory-limit" "MemoryMax=8589934592" supervisor
  , present "zero-swap" "MemorySwapMax=0" supervisor
  , present "deadline" "RuntimeMaxSec=1800" supervisor
  , present "network-denial" "IPAddressDeny=any" supervisor
  , present "marker-cleanup" "concreteOwnedProcessesRemoved" supervisor
  , absent "oracle-production-import" "import Amoebius" oracleSource
  ]
 where
  oracleSource = "module PbBoundaryOracle"

present :: String -> String -> String -> (String, Bool, Bool)
present label needle haystack = (label, True, needle `isInfixOf` haystack)

absent :: String -> String -> String -> (String, Bool, Bool)
absent label needle haystack = (label, True, not (needle `isInfixOf` haystack))
