module Main (main) where

import DslOracle (oracleMain, coreRows)

main :: IO ()
main = oracleMain coreRows
