{-# LANGUAGE OverloadedStrings #-}
module Amoebius.Tenancy.Provider.Pulsar (objectTypes) where
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
objectTypes :: Set Text
objectTypes = Set.singleton "NamespacePolicy"
