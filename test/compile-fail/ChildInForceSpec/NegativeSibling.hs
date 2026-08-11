{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.ChildInForceSpec

main :: IO ()
main = case projectSubtree ["child-a"] representativeForest of
  Left problem -> fail (show problem)
  Right child -> print (childSiblingBranches child)

representativeForest :: ParentForest
representativeForest =
  parentForest "root" "root-only"
    [ subtree "child-a" "alpha-only" []
    , subtree "child-b" "beta-only" []
    ]
