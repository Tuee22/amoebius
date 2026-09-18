{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Extension.Laws.Security
  ( Identity
  , Keyspace (RowKey)
  , SecurityStore
  , Trust (Attested, Claimed)
  , claimedIdentity
  , emptySecurityStore
  , renderScopedKey
  , runScopedOperation
  , SecurityOperation (Read)
  , useScopedKey
  )
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Data.Text (Text)

main :: IO ()
main = case claimedIdentity "tenant-a" "alice" of
  Left problem -> fail (show problem)
  Right identity -> print (attestedOnly identity)

attestedOnly :: Identity 'Attested -> Text
attestedOnly _identity = "attested"




firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result
