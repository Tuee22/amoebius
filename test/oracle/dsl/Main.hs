module Main (main) where

import DslLegacy (legacyKeys, legacyRows)
import DslLowering (loweringRows)
import DslWireDefaults (wireRoundTripRows, wireLinkedRoundTripRows)
import DslForkWire (forkWireRows)
import DslNativeWire (nativeWireRows)
import DslWireDescriptor (descriptorRow, preparationRows, requestRow)
import DslCompletion (completionMain)
import Data.Text (pack)
import DslOracle (oracleMain, coreRows)
import DslParse (renderRow, rowGreen)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitWith)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    "--oracle-invocation" : _ -> completionMain arguments
    "--oracle-inventory" : _ -> completionMain arguments
    "--oracle-profile" : _ -> completionMain arguments
    ["--wire-descriptor", directory] -> do
      row <- descriptorRow directory
      putStrLn (renderRow row)
      exitWith (if rowGreen row then ExitSuccess else ExitFailure 1)
    ["--wire-request", path] -> do
      row <- requestRow path
      putStrLn (renderRow row)
      exitWith (if rowGreen row then ExitSuccess else ExitFailure 1)
    ["--wire-preparation", directory] -> do
      rows <- preparationRows directory
      mapM_ (putStrLn . renderRow) rows
      exitWith (if all rowGreen rows then ExitSuccess else ExitFailure 1)
    ["--wire-native", path] -> do
      rows <- nativeWireRows path
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    ["--wire-fork", path] -> do
      rows <- forkWireRows path
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    ["--wire-roundtrip", path] -> do
      rows <- wireRoundTripRows path
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    ["--wire-linked-roundtrip", path] -> do
      rows <- wireLinkedRoundTripRows path
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    ["--decoded-lowering", directory] -> do
      rows <- loweringRows directory
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    [flag, directory] | ('-' : '-' : key) <- flag, pack key `elem` legacyKeys -> do
      rows <- legacyRows (pack key) directory
      mapM_ (putStrLn . renderRow) rows
      exitWith (if not (null rows) && all rowGreen rows then ExitSuccess else ExitFailure 1)
    _ -> oracleMain coreRows
