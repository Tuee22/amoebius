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
main = case crossKeyProgram of
  Left problem -> fail problem
  Right value -> print value

attestedOnly :: Identity 'Attested -> Text
attestedOnly _identity = "attested"



crossKeyProgram :: Either String Text
crossKeyProgram = do
  tenant <- firstShow (trustedTenant "tenant-a")
  subject <- firstShow (trustedSubject tenant "alice")
  membership <- firstShow (activeMembership tenant subject)
  nested <- firstShow $ withRequestScope tenant subject membership $ \left ->
    withRequestScope tenant subject membership $ \right ->
      crossKey left right
  firstShow nested

crossKey :: RequestScope left -> RequestScope right -> Text
crossKey left right = useScopedKey left (renderScopedKey right RowKey "record")

firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result
