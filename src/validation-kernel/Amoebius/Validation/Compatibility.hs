{-# LANGUAGE OverloadedStrings #-}
-- | Source and policy dependencies whose changes invalidate a receipt.
module Amoebius.Validation.Compatibility (closureDigest) where
import Amoebius.Doc.Check (discoverDocuments)
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.Custody.Status (patchToFrontier)
import Amoebius.Validation.GateSpec (GateRole (..), gateRole, gateSubjects, gateSuite, gateOracle, cabalTargetName, oracleExecutableName)
import Amoebius.Validation.Runner.Hygiene (haskellFilesUnder, readSourceText)
import Amoebius.Validation.Runner.Observer (sha256Hex)
import Amoebius.Validation.Runner.Spec (PackageGraph (..), VerifiedSpec (..), libraryClosure, internalDependencies)
import Control.Monad (unless)
import Distribution.PackageDescription (hsSourceDirs)
import Distribution.Utils.Path (getSymbolicPath)
import Data.List (nub, sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))
closureDigest :: FilePath -> PackageGraph -> VerifiedSpec -> Text -> Text -> IO Text
closureDigest root graph verified verifier governance = do
  let spec = verifiedSpec verified
      targets = [cabalTargetName (gateSuite spec), oracleExecutableName (gateOracle spec), "runner-suite", "oracle-runner", "symbolic-checker-spec", "refinement-checker-spec"]
      components = [info | target <- targets, Just (info,_) <- [Map.lookup target (graphTestSuites graph)]] <> [info | target <- [if gateRole spec == SeedGate then "amoebius-validate" else "amoebius", "extension-source-admission"], Just info <- [Map.lookup target (graphExecutables graph)]]
      stanzas = libraryClosure graph (Map.elems (verifiedStanzaOf verified) <> concatMap (Set.toList . internalDependencies) components)
      directories = Set.toList (Set.fromList (concat [dirs | stanza <- Set.toList stanzas, Just (_,_,dirs) <- [Map.lookup stanza (graphLibraries graph)]] <> concatMap (map getSymbolicPath . hsSourceDirs) components <> ["test/validation-kernel"]))
  files <- sort . nub . (["amoebius.cabal","cabal.project",".gitignore","pb/__main__.py"] <>) . concat <$> mapM (haskellFilesUnder root) directories
  documents <- if gateRole spec /= SeedGate then pure [] else do
    (corpus,findings,_) <- discoverDocuments root
    unless (null findings) (fail "ClosureDocumentDiscovery")
    frontier <- maybe (fail "ClosureStatusDomain") pure (Status.frontierForGate PhaseIdentity.phaseDomainLowerOrdinal)
    projection <- patchToFrontier root frontier Map.empty
    pure [(path,maybe contents id (lookup path projection)) | (path,contents) <- corpus]
  digests <- mapM (\file -> (\contents -> Text.pack file <> "\t" <> sha256Hex contents) <$> readSourceText (root </> file)) files
  pure (sha256Hex (Text.unlines (digests <> ["document\t" <> Text.pack path <> "\t" <> sha256Hex contents | (path,contents) <- sort documents] <> ["verifier\t" <> verifier, "governance\t" <> governance, "subjects\t" <> Text.pack (show (gateSubjects spec))])))
