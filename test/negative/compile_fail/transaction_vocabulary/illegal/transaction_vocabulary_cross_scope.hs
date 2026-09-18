{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Amoebius.Transaction.Vocabulary qualified as Vocabulary

main :: IO ()
main = case program of
  Left problem -> fail problem
  Right () -> putStrLn "transaction-vocabulary-compile: PASS scoped closed-surface twin"

program :: Either String ()
program = do
  tenant <- firstShow (trustedTenant "transaction-tenant")
  subject <- firstShow (trustedSubject tenant "transaction-subject")
  membership <- firstShow (activeMembership tenant subject)
  nested <- firstShow $ withRequestScope tenant subject membership $ \leftScope ->
    withRequestScope tenant subject membership $ \rightScope ->
      sameScope
        (Vocabulary.readDocument leftScope (Vocabulary.DocumentId "document-1"))
        (Vocabulary.listSubjectJobs rightScope)
  firstShow nested

sameScope
  :: Vocabulary.Transaction scope leftResult
  -> Vocabulary.Transaction scope rightResult
  -> ()
sameScope _ _ = ()

firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result
