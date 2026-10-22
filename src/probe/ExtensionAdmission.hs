{-# LANGUAGE OverloadedStrings #-}

-- | The native build transport imports the product checker directly, without
-- compiling or evaluating a contribution. Tool selection supplies native paths.
module Main (main) where

import Amoebius.Extension.SourceClosure
import Amoebius.Extension.AstCheck (CheckedExtensionSource, checkedSourceFiles)
import Data.List (isPrefixOf)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (canonicalizePath, createDirectoryIfMissing, doesFileExist, getCurrentDirectory, makeAbsolute)
import System.Environment (getArgs, getExecutablePath)
import System.Exit (ExitCode (..), exitFailure, exitWith)
import System.FilePath ((</>), isAbsolute, makeRelative, splitDirectories, takeDirectory)
import System.IO (hClose, openTempFile, stderr)
import System.Process (rawSystem)


main :: IO ()
main = do
  args <- getArgs
  case args of
    [root] -> admit root >> pure ()
    ["--write-compiler-wrapper", compiler, output] -> writeCompilerWrapper compiler output >>= exitWith
    "--cabal" : compiler : cabal : command : arguments
      | command `elem` ["build", "run", "list-bin"]
      , not (any forbiddenCabal arguments) -> do
          root <- getCurrentDirectory
          seal <- admit root
          (wrapper, snapshot) <- compilerTransport compiler root seal
          prepared <- writeCompilerWrapper compiler wrapper
          case prepared of
            ExitSuccess -> do
              let directory = root </> ".build/source-admission"
              Text.writeFile (directory </> "admitted-source.snapshot") snapshot
              Text.writeFile (directory </> "current-compiler") (Text.pack wrapper)
              rawSystem cabal (command : ["--jobs=1", "--with-compiler=" <> wrapper] <> arguments) >>= exitWith
            failure -> exitWith failure
    "--compiler" : compiler : root : compilerArgs -> do
      _ <- admit root
      if any parallel compilerArgs then fail "compiler concurrency must remain one"
        else rawSystem compiler (compilerArgs <> ["-j1"]) >>= exitWith
    _ -> fail "extension admission expects a source root or a native compiler transport"
 where
  parallel argument = "-j" `isPrefixOf` argument && argument /= "-j1"
  parallelCabal argument = parallel argument || ("--jobs" `isPrefixOf` argument && argument /= "--jobs=1")
  forbiddenCabal argument = parallelCabal argument
    || any (`isPrefixOf` argument) ["--with-compiler", "--with-ghc", "-w"]
    || ("--builddir" `isPrefixOf` argument && argument /= "--builddir=.build/dist-native")

admit :: FilePath -> IO CheckedExtensionSource
admit root = do
  result <- readContributionClosure root
  case result of
    Left refusal -> Text.hPutStrLn stderr (renderContributionRefusal refusal) >> exitFailure
    Right seal -> pure seal

-- Source cache bookkeeping uses the exact admitted bytes. A changed inventory
-- gets a fresh compiler path, invalidating Cabal configuration reuse; the link
-- boundary then reissues its seal. Native tool admission still checks versions.
compilerTransport :: FilePath -> FilePath -> CheckedExtensionSource -> IO (FilePath, Text.Text)
compilerTransport compiler root seal = do
  helper <- getExecutablePath
  let directory = root </> ".build/source-admission"
      snapshotPath = directory </> "admitted-source.snapshot"
      pointerPath = directory </> "current-compiler"
      snapshot = Text.pack (show (compiler, helper, NonEmpty.toList (checkedSourceFiles seal)))
  createDirectoryIfMissing True directory
  cached <- (&&) <$> doesFileExist snapshotPath <*> doesFileExist pointerPath
  previous <- if cached then Text.readFile snapshotPath else pure ""
  pointer <- if cached then Text.readFile pointerPath else pure ""
  present <- doesFileExist (Text.unpack pointer)
  if cached && previous == snapshot && present then pure (Text.unpack pointer, snapshot) else do
    (ticket, handle) <- openTempFile directory "compiler-"
    hClose handle
    pure (ticket <> ".d" </> "ghc", snapshot)

-- The portable bridge embeds only explicit paths. Every compiler invocation
-- enters the product checker before GHC can read file pragmas or run a plugin.
-- The bridge itself contains no source judgment and has fixed serial creation.
writeCompilerWrapper :: FilePath -> FilePath -> IO ExitCode
writeCompilerWrapper compiler output = do
  compilerPath <- makeAbsolute compiler
  helper <- getExecutablePath
  root <- getCurrentDirectory
  wrapper <- makeAbsolute output
  let relative = makeRelative (root </> ".build") wrapper
  if isAbsolute relative || ".." `elem` splitDirectories relative
    then fail "compiler transport output must remain beneath .build" else pure ()
  let directory = takeDirectory wrapper </> "compiler-transport"
      source = directory </> "Main.hs"
  createDirectoryIfMissing True directory
  actualDirectory <- canonicalizePath directory
  buildDirectory <- canonicalizePath (root </> ".build")
  let actualRelative = makeRelative buildDirectory actualDirectory
  if isAbsolute actualRelative || ".." `elem` splitDirectories actualRelative
    then fail "compiler transport directory escapes .build" else pure ()
  writeFile source (unlines
    [ "module Main (main) where"
    , "import System.Environment (getArgs)"
    , "import System.Exit (exitWith)"
    , "import System.Process (rawSystem)"
    , "main :: IO ()"
    , "main = do"
    , "  args <- getArgs"
    , "  rawSystem " <> show helper <> " (" <> show ["--compiler", compilerPath, root] <> " ++ args) >>= exitWith"
    ])
  rawSystem compilerPath
    ["--make", "-j1", "-fforce-recomp", "-v0", "-hide-all-packages", "-package", "base", "-package", "process",
     "-outputdir", directory, source, "-o", wrapper]
