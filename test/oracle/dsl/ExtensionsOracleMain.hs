{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import DslOracle (oracleMain)
import ExtensionsOracle (extensionRows)
import DslExtensionRegistry (extensionRegistryRows)
import DslExtensionAst (extensionAstRows)
import DslParse (renderRow, rowGreen)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitWith)
main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--astcheck", directory] -> do
      rows <- extensionAstRows directory
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    ["--registry", directory] -> do
      rows <- extensionRegistryRows "." directory
      mapM_ (\(name, passed, detail) -> Text.putStrLn (name <> "\t" <> (if passed then "green" else "red") <> "\t" <> Text.replace "\n" "\\n" detail)) rows
      exitWith (if not (null rows) && all (\(_, passed, _) -> passed) rows then ExitSuccess else ExitFailure 1)
    _ -> oracleMain extensionRows
