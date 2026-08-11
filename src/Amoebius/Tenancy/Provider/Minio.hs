{-# LANGUAGE OverloadedStrings #-}
module Amoebius.Tenancy.Provider.Minio (objectTypes) where
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
objectTypes :: Set Text
objectTypes = Set.singleton "BucketPolicy"
