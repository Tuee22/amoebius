{-# LANGUAGE OverloadedStrings #-}

module Main where

import Amoebius.Validation.CompilerComponentPlan (compilerComponentPlanDiagnostic)

main :: IO ()
main = print (compilerComponentPlanDiagnostic "" [])

