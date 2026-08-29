{-# LANGUAGE OverloadedStrings #-}

-- | Refusal-only raw diagnostic for the compiler/source-graph seam.
--
-- No snapshot, graph, compiler fact, problem, constructor, projection,
-- eliminator, or success branch crosses this facade. The claimed identity and
-- inventory are caller input. The package-hidden implementation bounds them
-- before traversal and never treats internal consistency as compiler,
-- source-binding, or semantic evidence.
module Amoebius.Validation.CompilerSourceGraph
  ( compilerSourceGraphDiagnostic
  ) where

import Amoebius.Validation.CompilerSourceGraph.Internal
  ( rawCompilerSourceGraphDiagnostic
  )
import Amoebius.Validation.Types (CheckResult)
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Diagnose a claimed raw compiler-input identity and canonical inventory.
-- Each tuple is @(POSIX path, Git mode, Git object identity, exact blob bytes)@.
-- The compiler is deliberately not invoked by this caller-authored diagnostic.
compilerSourceGraphDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> IO CheckResult
compilerSourceGraphDiagnostic claimedIdentity entries =
  pure (rawCompilerSourceGraphDiagnostic claimedIdentity entries)
