{-# LANGUAGE OverloadedStrings #-}
module CheckedCtorLegal where
import Amoebius.Dsl.AstCheck
legal :: ExtensionSourceVerdict
legal = checkExtensionSource "Legal.hs" "module Legal where\n"
