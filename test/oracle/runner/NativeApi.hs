{-# LANGUAGE OverloadedStrings #-}

-- | Fixed serial compiler transport for independently authored API twins.
module NativeApi (nativeApiChecks, writeAuthorityCheckers, seedAuthorityRows) where

import Control.Exception (IOException, try)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, findExecutable)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

-- Independent native boundary fakes. The constant and incomplete checkers are
-- negative inputs to the shipped runner, not alternative acceptance oracles.
writeAuthorityCheckers :: FilePath -> IO ()
writeAuthorityCheckers directory = do
  createDirectoryIfMissing True directory
  TextIO.writeFile (directory </> "seed-rows.data") (Text.unlines seedAuthorityRows)
  mapM_ (\(name,body) -> TextIO.writeFile (directory </> name <> ".hs") body)
    [("honest", checker ["authority.value","authority.discovery"])
    ,("omitted", checker ["authority.value"]), ("seed", checker seedAuthorityRows)
    ,("constant", Text.unlines ["module Main where", "main = mapM_ putStrLn [\"authority.value\\tgreen\\tconstant\",\"authority.discovery\\tgreen\\tconstant\"]"])]
 where
  checker :: [Text] -> Text
  checker keys = Text.unlines
    ["module Main where", "import Control.Monad (unless)", "import System.Environment (getArgs)", "import System.Directory (doesFileExist)", "import System.Exit (exitFailure)", "import System.FilePath ((</>))"
    ,"main = do", "  [root] <- getArgs", "  let path = root </> \"subject.txt\"", "  present <- doesFileExist path"
    ,"  bytes <- if present then readFile path else pure \"\"", "  let okay = bytes == \"observed input\\n\""
    ,"  hasOmission <- doesFileExist (root </> \"omit.txt\")", "  omitted <- if hasOmission then readFile (root </> \"omit.txt\") else pure \"\""
    ,"  mapM_ (\\key -> putStrLn (key ++ \"\\t\" ++ (if okay then \"green\" else \"red\") ++ \"\\tobserved\")) (filter (/= omitted) " <> Text.pack (show keys) <> ")"
    ,"  unless okay exitFailure"]

seedAuthorityRows :: [Text]
seedAuthorityRows =
  ["phase.cardinality","phase.table","phase.resource-required","phase.paths"
  ,"predecessor.50","predecessor.0","predecessor.1","successor.9","successor.95"
  ,"role.DSL_BARRIER","role.BOOTSTRAP_HANDOFF","role.HOST_ENSURE","role.FIRST_HARDWARE","role.REGISTRY_BOUNDARY"
  ,"gap","integrity.problems","legacy.cardinality","legacy.owners","decision.ids"
  ,"frozen.paths","frozen.digests","frozen.decisions","frozen.amendments","frozen.amendment-digests"
  ,"evidence-path.cardinality","evidence-path.results","evidence-parser.bundle-only","evidence-parser.void-only","evidence-parser.void-fields"
  ,"doc.findings","doc.governed-count-observed","negative.discovery"
  ,"negative.broken-link","negative.stale-backlink","negative.missing-status-line","negative.non-frontier-status-vector"
  ,"negative.unauthorised-frozen-edit","negative.uncited-module-claim","negative.gate-spec-block-mismatch"
  ,"negative.decision-log-out-of-order","negative.receipt-line-unexpected"]

nativeApiChecks :: FilePath -> [String] -> [FilePath] -> [Text]
  -> [(Text, Text, Text, Text, Int, [Text])] -> IO [(Text, Bool, Text)]
nativeApiChecks directory unitIds sourceRoots imports pairs = do
  compiler <- findExecutable "ghc"
  cabal <- findExecutable "cabal"
  mapM (observe compiler cabal) pairs
 where
  observe compiler cabal (name, signature, legal, illegal, column, fragments) = do
    admitted <- compile compiler cabal name "Legal" signature legal
    refused <- compile compiler cabal name "Illegal" signature illegal
    let positive = case admitted of Right (ExitSuccess, out, err) -> null out && null err; _ -> False
        negative = case refused of
          Right (ExitFailure 1, _, err) -> let message = Text.pack err in
            all (`Text.isInfixOf` message) fragments
            && ("Illegal.hs:5:" <> Text.pack (show column) <> ": error:") `Text.isInfixOf` message
            && Text.count ": error:" message == 1
          _ -> False
    pure (name, positive && negative, Text.pack (show (admitted, refused)))
  compile (Just compiler) (Just cabal) name role signature expression = do
    let root = directory </> Text.unpack name </> role
        path = root </> role <> ".hs"
    createDirectoryIfMissing True root
    TextIO.writeFile path (Text.unlines (["module Client where"] <> imports <> ["bad :: " <> signature, "bad = " <> expression]))
    result <- try (readProcessWithExitCode cabal
      (["exec", "-v0", "--jobs=1", "--builddir=.build/dist-native", "--with-compiler=" <> compiler, "--", compiler,
        "-v0", "-j1", "-XGHC2024", "--make", "-fno-code", "-fforce-recomp",
        "-fdiagnostics-color=never", "-fno-diagnostics-show-caret"] <> map ("-i" <>) sourceRoots
        <> ["-package", "cryptohash-sha256"] <> concatMap (\unitId -> ["-package-id", unitId]) unitIds
        <> ["-outputdir", root, path]) "")
      :: IO (Either IOException (ExitCode, String, String))
    case result of
      Left problem -> pure (Left (show problem))
      Right observed@(code, out, err) -> do
        TextIO.writeFile (root </> "stdout") (Text.pack out)
        TextIO.writeFile (root </> "stderr") (Text.pack err)
        TextIO.writeFile (root </> "exit") (Text.pack (show code))
        pure (Right observed)
  compile _ _ _ _ _ _ = pure (Left "native GHC or Cabal unavailable")
