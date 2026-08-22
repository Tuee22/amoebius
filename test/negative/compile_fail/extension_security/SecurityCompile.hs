{-# LANGUAGE CPP #-}
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
#ifdef EXTENSION_SECURITY_TEST_CLAIMED_AS_ATTESTED
main = case claimedIdentity "tenant-a" "alice" of
  Left problem -> fail (show problem)
  Right identity -> print (attestedOnly identity)
#elif defined(EXTENSION_SECURITY_TEST_PROMOTION)
main = case claimedIdentity "tenant-a" "alice" of
  Left problem -> fail (show problem)
  Right identity -> print (attestedOnly (promote identity))
#elif defined(EXTENSION_SECURITY_TEST_MISSING_SCOPE)
main = print (unscopedRead emptySecurityStore)
#elif defined(EXTENSION_SECURITY_TEST_CROSS_KEY)
main = case crossKeyProgram of
  Left problem -> fail problem
  Right value -> print value
#else
main = case claimedIdentity "tenant-a" "alice" of
  Left problem -> fail (show problem)
  Right _identity -> putStrLn "extension-security-compile: PASS legal claimed/attested boundary"
#endif

attestedOnly :: Identity 'Attested -> Text
attestedOnly _identity = "attested"

#ifdef EXTENSION_SECURITY_TEST_PROMOTION
promote :: Identity 'Claimed -> Identity 'Attested
promote identity = identity
#endif

#ifdef EXTENSION_SECURITY_TEST_MISSING_SCOPE
unscopedRead :: SecurityStore -> a
unscopedRead store = runScopedOperation Read "record" store
#endif

#ifdef EXTENSION_SECURITY_TEST_CROSS_KEY
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
#endif

firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result
