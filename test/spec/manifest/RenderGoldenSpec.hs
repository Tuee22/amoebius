{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text qualified as Text
import RenderGoldenGate (printRenderSemanticOracle, runRenderGoldenGate)
import RenderMutants (runRenderMutant)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--print-semantics"] -> printRenderSemanticOracle
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runRenderMutant mutant
          if caught
            then do
              putStrLn ("render-manifest-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-34 mutant rejected at its semantic-property locus: " <> Text.unpack mutant)
            else putStrLn ("render-manifest-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runRenderGoldenGate
