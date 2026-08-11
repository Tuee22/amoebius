import Data.ProtoLens.Setup (defaultMainGeneratingProtos)
import Control.Monad (unless)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (setEnv)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  packageDirectory <- getCurrentDirectory
  let pinnedBin = takeDirectory packageDirectory </> "toolchain" </> "bin"
      protoc = pinnedBin </> "protoc"
      generator = pinnedBin </> "proto-lens-protoc"
  protocPresent <- doesFileExist protoc
  generatorPresent <- doesFileExist generator
  unless (protocPresent && generatorPresent) (fail "phase35-pinned-codegen-tools-missing")
  -- proto-lens-setup does not accept an executable path. Give that dependency a
  -- closed, deterministic search domain with the repo-pinned tools first and
  -- only Cabal's fixed compiler directories after it. Ambient host PATH can
  -- neither select nor shadow either code generator.
  setEnv "PATH" (pinnedBin <> ":/usr/bin:/bin")
  defaultMainGeneratingProtos "proto/Amoebius/Pulsar/Proto"
