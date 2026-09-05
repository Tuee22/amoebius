{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.AstCheck (CheckedExtensionSource (CheckedExtensionSource))

main :: IO ()
main = print (CheckedExtensionSource "unchecked")
