{-# LANGUAGE OverloadedStrings #-}
module CheckedCtorIllegal where
import Amoebius.Dsl.AstCheck
illegal :: CheckedExtensionSource
illegal = CheckedExtensionSource "unchecked"
