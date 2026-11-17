{-# LANGUAGE OverloadedStrings #-}

-- | The native build transport imports the product checker directly, without
-- compiling or evaluating a contribution. Tool selection supplies native paths.
module Main (main) where

import Amoebius.Extension.SourceClosure
import Amoebius.Extension.AstCheck (CheckedExtensionSource)
import CompilerJournalWindow
  ( runRecordedCabal, runRecordedCompiler, runRecordedWindowCompiler
  , writeRecordedCompilerWrapper )
import Data.List (isPrefixOf)
import Data.Text.IO qualified as Text
import System.Directory (getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitWith)
import System.IO (stderr)


main :: IO ()
main = do
  args <- getArgs
  case args of
    [root] -> admit root >> pure ()
    ["--write-compiler-wrapper", compiler, output] -> writeRecordedCompilerWrapper compiler output >>= exitWith
    "--cabal" : compiler : cabal : config : command : arguments
      | command `elem` ["build", "run", "list-bin"]
      , not (any forbiddenCabal arguments) -> do
          root <- getCurrentDirectory
          seal <- admit root
          runRecordedCabal seal root compiler cabal config command arguments >>= exitWith
    "--compiler-window" : window : bridge : compiler : root : compilerArgs -> do
      seal <- admit root
      if any parallel compilerArgs then fail "compiler concurrency must remain one"
        else runRecordedWindowCompiler seal window bridge compiler root compilerArgs >>= exitWith
    "--compiler" : compiler : root : compilerArgs -> do
      seal <- admit root
      if any parallel compilerArgs then fail "compiler concurrency must remain one"
        else runRecordedCompiler seal compiler root compilerArgs >>= exitWith
    _ -> fail "extension admission expects a source root or a native compiler transport"
 where
  parallel argument = "-j" `isPrefixOf` argument && argument /= "-j1"
  parallelCabal argument = parallel argument || ("--jobs" `isPrefixOf` argument && argument /= "--jobs=1")
  forbiddenCabal argument = parallelCabal argument
    || any (`isPrefixOf` argument) ["--with-compiler", "--with-ghc", "--with-hc-pkg", "-w"]
    || ("--builddir" `isPrefixOf` argument && argument /= "--builddir=.build/dist-native")

admit :: FilePath -> IO CheckedExtensionSource
admit root = do
  result <- readContributionClosure root
  case result of
    Left refusal -> Text.hPutStrLn stderr (renderContributionRefusal refusal) >> exitFailure
    Right seal -> pure seal
