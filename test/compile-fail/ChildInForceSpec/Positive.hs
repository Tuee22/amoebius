{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.ChildInForceSpec

main :: IO ()
main = case projectSubtree ["child-a", "grandchild-a1"] representativeForest of
  Left problem -> fail (show problem)
  Right child
    | childClusterId child == "grandchild-a1"
        && childVisibleClusters child == ["grandchild-a1"] -> pure ()
    | otherwise -> fail "positive projection exposed the wrong subtree"

representativeForest :: ParentForest
representativeForest =
  parentForest "root" "root-only"
    [ subtree "child-a" "alpha-only"
        [subtree "grandchild-a1" "alpha-grandchild-only" []]
    , subtree "child-b" "beta-only" []
    ]
