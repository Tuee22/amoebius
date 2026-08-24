{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar
  ( pbBootstrapGrammarDiagnostic
  )
import Amoebius.Validation.Types (checkName)

main :: IO ()
main =
  checkName (pbBootstrapGrammarDiagnostic []) `seq` pure ()
