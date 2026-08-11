module Amoebius.Cli.Formal
  ( runFormalCommand
  , emitModelFiles
  ) where

import Amoebius.Formal.EmitTLA
import Amoebius.Formal.GatewayMigration
import Amoebius.Formal.Model (Model (modelName))
import Amoebius.Formal.ToyModel
import Control.Monad (unless)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

runFormalCommand :: [String] -> IO ()
runFormalCommand ["dev", "model", "emit"] = do
  emitModelFiles "gen/tla" toyModel
  putStrLn "emitted gen/tla/ToyModel.tla and gen/tla/ToyModel.cfg"
runFormalCommand ["dev", "model", "emit", "gateway-migration"] = do
  emitModelFiles "gen/tla" gatewayMigrationModel
  putStrLn "emitted gen/tla/GatewayMigration.tla and gen/tla/GatewayMigration.cfg"
runFormalCommand _ = fail "usage: amoebius dev model emit [gateway-migration]"

emitModelFiles :: FilePath -> Model -> IO ()
emitModelFiles outputDirectory model = do
  createDirectoryIfMissing True outputDirectory
  let (Tla tla, Cfg cfg) = emitTLA model
      tlaPath = outputDirectory </> modelName model <> ".tla"
      cfgPath = outputDirectory </> modelName model <> ".cfg"
  writeFile tlaPath tla
  writeFile cfgPath cfg
  tlaRoundTrip <- readFile tlaPath
  cfgRoundTrip <- readFile cfgPath
  unless (tlaRoundTrip == tla && cfgRoundTrip == cfg) (fail "emitted model did not round-trip byte-for-byte")
