{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (sourceConsumerGraphDiagnostic)
import Amoebius.Validation.Types (checkName)
main :: IO ()
main = seq (checkName (sourceConsumerGraphDiagnostic "" [] [])) (pure ())
