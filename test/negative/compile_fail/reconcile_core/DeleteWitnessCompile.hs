{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Reconcile.Core

main :: IO ()
main = print witnessAction

witnessAction :: Action 'IsPresent
witnessAction = DeleteObject (ResourceId "a") (PresentObservation "v1")
