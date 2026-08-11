{-# LANGUAGE OverloadedStrings #-}
module Amoebius.Tenancy.Provider.Keycloak (objectTypes) where
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
objectTypes :: Set Text
objectTypes = Set.fromList ["RealmRole", "GroupRoleMapping"]
