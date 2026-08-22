{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Reconcile.Core

main :: IO ()
main = print witnessAction

witnessAction :: Action 'IsPresent
#ifdef RECONCILE_CORE_DELETE_UNREACHABLE_MUTANT
witnessAction = DeleteObject (ResourceId "a") (UnreachableObservation "timeout")
#else
witnessAction = DeleteObject (ResourceId "a") (PresentObservation "v1")
#endif
