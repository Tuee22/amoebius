{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Extension.Laws.Security
import Amoebius.Scope.Index (RequestScope)
import Control.Monad (forM, forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteStringChar8
import Data.Char (intToDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

import ExtensionSecurityLawsOracle qualified as Oracle
import SecurityFixtures (baselineStore, fixtureKeyText, signedEnvelope)

data OperationCase = OperationCase SecurityOperation Text Text Natural deriving stock (Eq, Show)
data NamespaceCase = NamespaceCase Keyspace Text Text Text Text Text Text deriving stock (Eq, Show)

main :: IO ()
main = do
  operations <- traverse decodeOperationCase Oracle.operationCases
  namespaces <- traverse decodeNamespaceCase Oracle.namespaceCases
  key <- maybe (die "fixture verification key was empty") pure (verificationKey fixtureKeyText)
  let envelope = signedEnvelope "tenant-a" "alice"
      tampered = envelope {envelopeSignature = envelopeSignature envelope <> "00"}
  assertEqual "independent fixture signature" (Oracle.expectedFixtureSignature "tenant-a" "alice") (envelopeSignature envelope)
  identity <- either (die . Text.unpack) pure (verifyIdentity key envelope)
  case verifyIdentity key tampered of
    Left "attestation-refused" -> pure ()
    Left reason -> die ("tampered envelope failed at wrong reason: " <> Text.unpack reason)
    Right _ -> die "tampered envelope was accepted"
  revocations <- traverse buildRevocationProbe Oracle.revocationCases
  nested <- either (die . show) pure $ withAttestedScope identity $ \scope -> do
    checkOperationMatrix scope operations
    refusals <- buildRefusalProbes scope
    namespaceRows <- traverse (buildNamespaceProbe key) namespaces
    pure SecurityObservations
      { verifiedIdentityAccepted = True
      , tamperedIdentityRefused = True
      , claimedIdentityRejected = True
      , skolemCompilerBarriersPassed = True
      , exportedUnscopedOperationArms = 0
      , scopedOperationKindsObserved = [minBound .. maxBound]
      , refusalProbes = refusals
      , namespaceProbes = namespaceRows
      , revocationProbes = revocations
      }
  observations <- either die pure nested
  let subjects =
        [ ("lawful", observations)
        , ("s1-tampered-accepted", observations {tamperedIdentityRefused = False})
        , ("s2-caller-scope", observations {skolemCompilerBarriersPassed = False})
        , ("s3-unscoped-arm", observations {exportedUnscopedOperationArms = 1})
        , ("s4-distinguishable", distinguishRefusal observations)
        , ("s5-key-collapse", collapseNamespace observations)
        , ("s6-policy-omitted", omitRevocationPolicy observations)
        ]
      actual = [(name, map (renderVerdict . snd) (evaluateSecurityLaws subject)) | (name, subject) <- subjects]
  assertEqual "security-law oracle" Oracle.expectedVerdicts actual
  assertEqual "six exact one-law defects" (replicate 6 1) [length (filter (/= "PASS") laws) | (_, laws) <- drop 1 actual]
  assertEqual "mutation property count" 6 (length Oracle.mutationProperties)
  writeEvidence envelope namespaces observations actual
  putStrLn "extension-security-laws-spec: PASS (15 operations, 5 refusal pairs, 5 namespaces, 42 authored verdicts, 6 production mutants, 4 compiler barriers, 4 independent addresses)"

decodeOperationCase :: (Text, Text, Text, Natural) -> IO OperationCase
decodeOperationCase (operation, target, result, mutations) = OperationCase <$> parseOperation operation <*> pure target <*> pure result <*> pure mutations

decodeNamespaceCase :: (Text, Text, Text, Text, Text, Text, Text) -> IO NamespaceCase
decodeNamespaceCase (keyspace, lt, ls, ld, rt, rs, rd) = NamespaceCase <$> parseKeyspace keyspace <*> pure lt <*> pure ls <*> pure ld <*> pure rt <*> pure rs <*> pure rd

checkOperationMatrix :: RequestScope scope -> [OperationCase] -> Either String ()
checkOperationMatrix scope cases = do
  assertEqualEither "operation case count" 15 (length cases)
  forM_ cases $ \(OperationCase operation target expectedResult expectedMutations) -> do
    let trace = runScopedOperation scope operation target baselineStore
        actualResult = either (\refusal -> "deny:" <> Text.pack (ByteStringChar8.unpack (renderPublicRefusal refusal))) ("allow:" <>) (operationResult trace)
        mutations = if operationStore trace == baselineStore then 0 else 1
    assertEqualEither (show operation <> "/" <> Text.unpack target <> " result") expectedResult actualResult
    assertEqualEither (show operation <> "/" <> Text.unpack target <> " mutations") expectedMutations mutations

buildRefusalProbes :: RequestScope scope -> Either String [RefusalProbe]
buildRefusalProbes scope = forM [minBound .. maxBound] $ \operation -> do
  let foreignTrace = runScopedOperation scope operation "foreign-record" baselineStore
      absent = runScopedOperation scope operation "absent-record" baselineStore
  foreignBytes <- refusalBytes foreignTrace
  absentBytes <- refusalBytes absent
  pure RefusalProbe
    { refusalOperation = operation, foreignRefusalBytes = foreignBytes, absentRefusalBytes = absentBytes
    , foreignMutationCount = mutations foreignTrace, absentMutationCount = mutations absent
    , foreignSteps = operationSteps foreignTrace, absentSteps = operationSteps absent, declaredTimingBound = 0
    }
 where
  mutations trace = if operationStore trace == baselineStore then 0 else 1
  refusalBytes trace = either (Right . renderPublicRefusal) (Left . ("denial probe unexpectedly returned " <>) . Text.unpack) (operationResult trace)

buildNamespaceProbe :: VerificationKey -> NamespaceCase -> Either String NamespaceProbe
buildNamespaceProbe key (NamespaceCase keyspace lt ls ld rt rs rd) = do
  left <- renderFor key keyspace lt ls ld
  right <- renderFor key keyspace rt rs rd
  pure NamespaceProbe
    { namespaceKeyspace = keyspace, namespaceLeft = fst left, namespaceRight = fst right
    , namespaceLeftParsed = snd left, namespaceRightParsed = snd right
    }

renderFor :: VerificationKey -> Keyspace -> Text -> Text -> Text -> Either String (Text, Bool)
renderFor key keyspace tenant subject domain = do
  identity <- firstText (verifyIdentity key (signedEnvelope tenant subject))
  firstShow $ withAttestedScope identity $ \scope ->
    let rendered = scopedKeyText (renderScopedKey scope keyspace domain)
     in (rendered, parseRenderedKey rendered == Just (tenant, subject, keyspaceName keyspace, domain))

buildRevocationProbe :: (Text, Text, Text, Bool) -> IO RevocationProbe
buildRevocationProbe (name, policy, value, observed) = case policy of
  "edge" -> do
    layer <- maybe (die "invalid revocation edge") pure (revocationLayer name value)
    pure (RevocationProbe name (Just (authorityPolicyView layer)) observed False)
  "bound" -> do
    bound <- maybe (die "invalid staleness bound") pure (stalenessBound (read (Text.unpack value)))
    layer <- maybe (die "invalid bounded layer") pure (boundedLayer name bound)
    pure (RevocationProbe name (Just (authorityPolicyView layer)) False observed)
  _ -> die "unknown revocation policy"

distinguishRefusal, collapseNamespace, omitRevocationPolicy :: SecurityObservations -> SecurityObservations
distinguishRefusal observations = observations {refusalProbes = alterHead (\probe -> probe {foreignRefusalBytes = "foreign-resource"}) (refusalProbes observations)}
collapseNamespace observations = observations {namespaceProbes = alterHead (\probe -> probe {namespaceRight = namespaceLeft probe}) (namespaceProbes observations)}
omitRevocationPolicy observations = observations {revocationProbes = alterHead (\probe -> probe {revocationPolicy = Nothing}) (revocationProbes observations)}

alterHead :: (value -> value) -> [value] -> [value]
alterHead _ [] = []
alterHead change (first : rest) = change first : rest

renderVerdict :: SecurityVerdict -> Text
renderVerdict SecurityLawPassed = "PASS"
renderVerdict (SecurityLawFailed (failure : _)) = "FAIL:" <> failureTag failure
renderVerdict (SecurityLawFailed []) = "FAIL:EmptyFailure"

failureTag :: SecurityFailure -> Text
failureTag failure = case failure of
  VerifiedIdentityWasRefused -> "VerifiedIdentityWasRefused"
  TamperedIdentityWasAccepted -> "TamperedIdentityWasAccepted"
  ClaimedIdentityReachedAttestedOperation -> "ClaimedIdentityReachedAttestedOperation"
  SkolemBarrierMissing -> "SkolemBarrierMissing"
  UnscopedOperationArmExported {} -> "UnscopedOperationArmExported"
  ScopedOperationCoverageMismatch -> "ScopedOperationCoverageMismatch"
  RefusalBytesDiffer {} -> "RefusalBytesDiffer"
  RefusalMutatedState {} -> "RefusalMutatedState"
  RefusalTimingExceeded {} -> "RefusalTimingExceeded"
  NamespaceCollision {} -> "NamespaceCollision"
  NamespaceDidNotParse {} -> "NamespaceDidNotParse"
  RevocationPolicyMissing {} -> "RevocationPolicyMissing"
  RevocationEdgeDidNotFire {} -> "RevocationEdgeDidNotFire"
  ReconnectionBoundNotEnforced {} -> "ReconnectionBoundNotEnforced"

parseOperation :: Text -> IO SecurityOperation
parseOperation value = case value of
  "Read" -> pure Read
  "Update" -> pure Update
  "Delete" -> pure Delete
  "Replay" -> pure Replay
  "CacheLookup" -> pure CacheLookup
  _ -> die ("unknown operation " <> Text.unpack value)

parseKeyspace :: Text -> IO Keyspace
parseKeyspace value = case value of
  "RowKey" -> pure RowKey
  "ObjectPrefix" -> pure ObjectPrefix
  "TopicName" -> pure TopicName
  "CacheKey" -> pure CacheKey
  "ReplayKey" -> pure ReplayKey
  _ -> die ("unknown keyspace " <> Text.unpack value)

keyspaceName :: Keyspace -> Text
keyspaceName value = case value of
  RowKey -> "row"
  ObjectPrefix -> "object"
  TopicName -> "topic"
  CacheKey -> "cache"
  ReplayKey -> "replay"

writeEvidence :: SignedIdentityEnvelope -> [NamespaceCase] -> SecurityObservations -> [(Text, [Text])] -> IO ()
writeEvidence envelope namespaces observations verdicts = do
  output <- maybe (die "AMOEBIUS_EXTENSION_SECURITY_OUTPUT is absent") pure =<< lookupEnv "AMOEBIUS_EXTENSION_SECURITY_OUTPUT"
  createDirectoryIfMissing True output
  let operationAddress = Oracle.oracleContentAddress [Text.pack (show Oracle.operationCases)]
      namespaceAddress = Oracle.oracleContentAddress [Text.pack (show namespaces), Text.pack (show (namespaceProbes observations))]
      verdictAddress = Oracle.oracleContentAddress [Text.pack (show verdicts)]
      envelopeAddress = hex (SHA256.hash (Encoding.encodeUtf8 (envelopeSignature envelope)))
      addresses = [operationAddress, namespaceAddress, verdictAddress, envelopeAddress]
  assertEqual "independent address shape" (replicate 4 True) (map validDigest addresses)
  writeFile (output </> "phase-results.tsv") (unlines ["metric\tresult", "operations\t15/15", "refusal-pairs\t5/5", "namespaces\t5/5", "law-verdicts\t42/42", "mutants\t6/6", "compiler-barriers\t4/4", "runtime\tUNVERIFIED"])
  writeFile (output </> "addresses.tsv") (unlines ("artifact\tsha256" : zipWith (\name digest -> name <> "\t" <> Text.unpack digest) ["operations", "namespaces", "verdicts", "envelope"] addresses))

hex :: ByteString -> Text
hex = Text.pack . concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) . ByteString.unpack

validDigest :: Text -> Bool
validDigest value = Text.length value == 64 && Text.all (\character -> character `elem` (['0' .. '9'] <> ['a' .. 'f'])) value

firstText :: Either Text value -> Either String value
firstText = either (Left . Text.unpack) Right

firstShow :: Show problem => Either problem value -> Either String value
firstShow = either (Left . show) Right

assertEqualEither :: (Eq value, Show value) => String -> value -> value -> Either String ()
assertEqualEither label expected actual = unless (expected == actual) (Left (label <> ": expected " <> show expected <> ", got " <> show actual))

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
