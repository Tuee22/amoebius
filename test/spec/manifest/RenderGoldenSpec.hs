{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text qualified as Text
import RenderGoldenGate (printRenderGoldenOracle, runRenderGoldenGate)
import RenderMutants (runRenderMutant)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--print-goldens"] -> printRenderGoldenOracle
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runRenderMutant mutant
          if caught
            then do
              putStrLn ("render-manifest-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-13 mutant rejected by its safety property: " <> Text.unpack mutant)
            else putStrLn ("render-manifest-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runRenderGoldenGate
