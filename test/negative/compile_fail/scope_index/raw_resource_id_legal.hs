{-# LANGUAGE OverloadedStrings #-}
module RawResourceIdLegal where
import Amoebius.Scope.Index
legal :: Either ScopeError ResourceId
legal = trustedResourceId "trusted-resource"
