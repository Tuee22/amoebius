{-# LANGUAGE OverloadedStrings #-}

module TrustedResourceId where

import Amoebius.Scope.Index

good :: Either ScopeError ResourceId
good = trustedResourceId "trusted-resource"
