{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the @toolchain_spike@ runner.
--
-- The expectations are authored from the capability's own claim — its two owned
-- legacy families, the absence of committed resolution output, and the contract
-- rows it leaves unbound — never restated from a run. Each negative differs
-- from 'cleanSnapshot' in exactly one dimension and must add exactly one
-- refusal code.
module ToolchainSpikeRunOracle
  ( runToolchainSpikeRunOracle
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( IndexEntry (..)
  , IndexMode (RegularFile)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , sourceClosureInternalTestAcquire
  )
import Amoebius.Validation.ToolchainSpikeRun (toolchainSpikeRunCheck)
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Monad (unless)
import Data.ByteString.Char8 qualified as ByteString8
import Data.Text (Text)
import Data.Text qualified as Text

runToolchainSpikeRunOracle :: IO ()
runToolchainSpikeRunOracle = do
  unless (null problems) (fail (unlines ("ToolchainSpikeRunOracle:" : map ("  " <>) problems)))
  putStrLn
    ( "ToolchainSpikeRunOracle: the public diagnostic independently decides its two owned source-debt "
        <> "families and committed resolution output. Process authority remains package-hidden."
    )
 where
  problems =
    exactly "a snapshot with no open toolchain debt" cleanSnapshot []
      <> exactly
        "a tracked foreign probe input"
        (cleanSnapshot <> [entry "probe/cases/expected.txt"])
        ["TOOLCHAIN-SPIKE-PROBE-DEBT-OPEN"]
      <> exactly
        "a tracked top-level vendor path"
        (cleanSnapshot <> [entry "vendor/dual/dual.cabal"])
        ["TOOLCHAIN-SPIKE-VENDOR-DEBT-OPEN"]
      <> exactly
        "committed resolution output"
        (cleanSnapshot <> [entry "cabal.project.freeze"])
        ["TOOLCHAIN-SPIKE-RESOLUTION-OUTPUT-TRACKED"]

  exactly label entries expected =
    [ label
        <> " must produce exactly "
        <> show expected
        <> ", observed "
        <> show (observed entries)
    | observed entries /= expected
    ]

  observed entries =
    map (Text.unpack . findingCode)
      ( checkFindings
          ( toolchainSpikeRunCheck
              (sourceClosureInternalTestAcquire (SourceSnapshot "/fixture" snapshotIdentityValue entries))
          )
      )

-- | A probe root holding only Haskell and its Cabal declaration, no top-level
-- vendor root, and no committed resolution output.
cleanSnapshot :: [TrackedEntry]
cleanSnapshot =
  [ entry "probe/probe.cabal"
  , entry "probe/Main.hs"
  , entry "src/Amoebius/Kernel.hs"
  ]

entry :: FilePath -> TrackedEntry
entry path =
  TrackedEntry
    { trackedIndex = IndexEntry path RegularFile objectIdentityValue
    , trackedBytes = ByteString8.pack "module A where\n"
    }

snapshotIdentityValue, objectIdentityValue :: Text
snapshotIdentityValue = Text.replicate 64 "0"
objectIdentityValue = Text.replicate 64 "1"
