{-# LANGUAGE OverloadedStrings #-}

module Main where

import Amoebius.Validation.CompilerSourceGraph (compilerSourceGraphDiagnostic)

main :: IO ()
main = compilerSourceGraphDiagnostic "" [] >>= print
