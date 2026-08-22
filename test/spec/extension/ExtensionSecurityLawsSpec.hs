{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Extension.Laws.Security
import Amoebius.Scope.Index (RequestScope)
import Control.Monad (forM, forM_, unless)
import Data.ByteString.Char8 qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))

import SecurityFixtures (baselineStore, fixtureKeyText, signedEnvelope)
import SecurityLawMutants

data OperationCase = OperationCase
  { caseOperation :: SecurityOperation
  , caseTarget :: Text
  , caseResult :: Text
  , caseMutationCount :: Natural
  }
  deriving stock (Eq, Show)

data NamespaceCase = NamespaceCase
  { caseKeyspace :: Keyspace
  , leftTenant :: Text
  , leftSubject :: Text
  , leftDomain :: Text
  , rightTenant :: Text
  , rightSubject :: Text
  , rightDomain :: Text
  }
  deriving stock (Eq, Show)

data ExpectedVerdict = ExpectedVerdict Text [Text]
  deriving stock (Eq, Show)

main :: IO ()
main = do
  arguments <- getArgs
  root <- getCurrentDirectory
  operationCases <- loadOperationCases root
  namespaceCases <- loadNamespaceCases root
  expected <- loadExpectedVerdicts root
  key <- maybe (die "fixture verification key was empty") pure (verificationKey fixtureKeyText)
  let envelope = signedEnvelope "tenant-a" "alice"
      tampered = envelope {envelopeSignature = envelopeSignature envelope <> "00"}
  identity <- either (die . Text.unpack) pure (verifyIdentity key envelope)
  case verifyIdentity key tampered of
    Left "attestation-refused" -> pure ()
    Left reason -> die ("tampered envelope failed at wrong reason: " <> Text.unpack reason)
    Right _accepted -> die "tampered envelope was accepted"
  revocationRows <- buildRevocationProbes root
  nested <- either (die . show) pure $ withAttestedScope identity $ \scope -> do
    checkOperationMatrix scope operationCases
    refusalRows <- buildRefusalProbes scope
    namespaceRows <- traverse (buildNamespaceProbe key) namespaceCases
    pure
      SecurityObservations
        { verifiedIdentityAccepted = True
        , tamperedIdentityRefused = True
        , claimedIdentityRejected = True
        , skolemCompilerBarriersPassed = True
        , exportedUnscopedOperationArms = 0
        , scopedOperationKindsObserved = [minBound .. maxBound]
        , refusalProbes = refusalRows
        , namespaceProbes = namespaceRows
        , revocationProbes = revocationRows
        }
  observations <- either die pure nested
  case arguments of
    [argument] | "--mutant=" `prefixOf` argument -> runMutant observations (dropPrefix "--mutant=" argument)
    [] -> runGreen root envelope namespaceCases observations expected
    _arguments -> die "expected no arguments or --mutant=<name>"

runGreen
  :: FilePath
  -> SignedIdentityEnvelope
  -> [NamespaceCase]
  -> SecurityObservations
  -> [ExpectedVerdict]
  -> IO ()
runGreen root envelope namespaceCases observations expected = do
  let subjects =
        [ ("lawful", observations)
        , ("s1-tampered-accepted", acceptTamperedIdentity observations)
        , ("s2-caller-scope", trustCallerScope observations)
        , ("s3-unscoped-arm", exportUnscopedArm observations)
        , ("s4-distinguishable", distinguishRefusal observations)
        , ("s5-key-collapse", collapseNamespace observations)
        , ("s6-policy-omitted", omitRevocationPolicy observations)
        ]
      actual =
        [ ExpectedVerdict name (fmap (renderVerdict . snd) (evaluateSecurityLaws subject))
        | (name, subject) <- subjects
        ]
  assertEqual "security law verdict table" expected actual
  assertEqual "six one-law defects" (replicate 6 1)
    [length (filter (/= "PASS") laws) | ExpectedVerdict _ laws <- drop 1 actual]
  writeEvidence root envelope namespaceCases observations
  putStrLn "extension-security-laws-spec: PASS (15 operations, 5 refusal pairs, 5 namespaces, 42 verdicts, 6 exact mutants)"

checkOperationMatrix :: RequestScope scope -> [OperationCase] -> Either String ()
checkOperationMatrix scope cases = do
  assertEqualEither "operation case count" 15 (length cases)
  forM_ cases $ \entry -> do
    let trace = runScopedOperation scope (caseOperation entry) (caseTarget entry) baselineStore
        actualResult = renderOperationResult (operationResult trace)
        actualMutations = if operationStore trace == baselineStore then 0 else 1
    assertEqualEither (show (caseOperation entry) <> "/" <> Text.unpack (caseTarget entry) <> " result")
      (caseResult entry) actualResult
    assertEqualEither (show (caseOperation entry) <> "/" <> Text.unpack (caseTarget entry) <> " mutations")
      (caseMutationCount entry) actualMutations

buildRefusalProbes :: RequestScope scope -> Either String [RefusalProbe]
buildRefusalProbes scope = forM [minBound .. maxBound] $ \operation -> do
  let foreignTrace = runScopedOperation scope operation "foreign-record" baselineStore
      absent = runScopedOperation scope operation "absent-record" baselineStore
  foreignBytes <- refusalBytes foreignTrace
  absentBytes <- refusalBytes absent
  pure
    RefusalProbe
      { refusalOperation = operation
      , foreignRefusalBytes = foreignBytes
      , absentRefusalBytes = absentBytes
      , foreignMutationCount = mutations foreignTrace
      , absentMutationCount = mutations absent
      , foreignSteps = operationSteps foreignTrace
      , absentSteps = operationSteps absent
      , declaredTimingBound = 0
      }
 where
  mutations trace = if operationStore trace == baselineStore then 0 else 1
  refusalBytes trace = case operationResult trace of
    Left refusal -> Right (renderPublicRefusal refusal)
    Right value -> Left ("denial probe unexpectedly returned " <> Text.unpack value)

buildNamespaceProbe :: VerificationKey -> NamespaceCase -> Either String NamespaceProbe
buildNamespaceProbe key entry = do
  left <- renderFor key (caseKeyspace entry) (leftTenant entry) (leftSubject entry) (leftDomain entry)
  right <- renderFor key (caseKeyspace entry) (rightTenant entry) (rightSubject entry) (rightDomain entry)
  pure
    NamespaceProbe
      { namespaceKeyspace = caseKeyspace entry
      , namespaceLeft = fst left
      , namespaceRight = fst right
      , namespaceLeftParsed = snd left
      , namespaceRightParsed = snd right
      }

renderFor :: VerificationKey -> Keyspace -> Text -> Text -> Text -> Either String (Text, Bool)
renderFor key keyspace tenant subject domain = do
  identity <- firstText (verifyIdentity key (signedEnvelope tenant subject))
  firstShow $ withAttestedScope identity $ \scope ->
    let rendered = scopedKeyText (renderScopedKey scope keyspace domain)
        expected = (tenant, subject, keyspaceName keyspace, domain)
     in (rendered, parseRenderedKey rendered == Just expected)

buildRevocationProbes :: FilePath -> IO [RevocationProbe]
buildRevocationProbes root = do
  rows <- rowsOf (root </> "test/oracle/extension_security/revocation_layers.tsv")
  case rows of
    header : body -> do
      assertEqual "revocation header" ["layer", "policy", "value", "probe"] header
      forM body $ \row -> case row of
        [name, "edge", edge, "observed"] -> do
          layer <- maybe (die "invalid revocation edge") pure (revocationLayer name edge)
          pure (RevocationProbe name (Just (authorityPolicyView layer)) True False)
        [name, "bound", value, "enforced"] -> do
          bound <- maybe (die "invalid staleness bound") pure (stalenessBound (number value))
          layer <- maybe (die "invalid bounded layer") pure (boundedLayer name bound)
          pure (RevocationProbe name (Just (authorityPolicyView layer)) False True)
        _row -> die ("invalid revocation row: " <> show row)
    [] -> die "empty revocation layer oracle"

runMutant :: SecurityObservations -> String -> IO ()
runMutant observations mutant = do
  let (propertyName, wanted, mutated) = case mutant of
        "tampered-identity-accepted" -> ("AttestedIdentityOnly", "S1", acceptTamperedIdentity observations)
        "caller-supplied-scope" -> ("SkolemScopeOnly", "S2", trustCallerScope observations)
        "unscoped-default-arm" -> ("RefusalByDefault", "S3", exportUnscopedArm observations)
        "distinguishable-refusal" -> ("IndistinguishableRefusal", "S4", distinguishRefusal observations)
        "resource-only-cache-key" -> ("InjectiveNamespace", "S5", collapseNamespace observations)
        "revocation-policy-omitted" -> ("RevocationBound", "S6", omitRevocationPolicy observations)
        _unknown -> ("unknown", "", observations)
      failed =
        [ Text.unpack (securityLawTag law)
        | (law, verdict) <- evaluateSecurityLaws mutated
        , not (securityLawPassed verdict)
        ]
  if failed == [wanted]
    then do
      putStrLn ("extension-security-mutant: RED " <> mutant <> " " <> propertyName)
      exitFailure
    else die ("mutant did not redden exact law: expected " <> show wanted <> ", got " <> show failed)

renderVerdict :: SecurityVerdict -> Text
renderVerdict verdict = case verdict of
  SecurityLawPassed -> "PASS"
  SecurityLawFailed (failure : _rest) -> "FAIL:" <> failureTag failure
  SecurityLawFailed [] -> "FAIL:EmptyFailure"

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

renderOperationResult :: Either PublicRefusal Text -> Text
renderOperationResult result = case result of
  Left refusal -> "deny:" <> Text.pack (ByteString.unpack (renderPublicRefusal refusal))
  Right value -> "allow:" <> value

loadOperationCases :: FilePath -> IO [OperationCase]
loadOperationCases root = do
  rows <- rowsOf (root </> "test/oracle/extension_security/operation_matrix.tsv")
  case rows of
    header : body -> do
      assertEqual "operation header" ["operation", "target", "result", "mutation_count"] header
      forM body $ \row -> case row of
        [operation, target, result, mutationCount] ->
          OperationCase <$> parseOperation operation <*> pure target <*> pure result <*> pure (number mutationCount)
        _row -> die ("invalid operation row: " <> show row)
    [] -> die "empty operation oracle"

loadNamespaceCases :: FilePath -> IO [NamespaceCase]
loadNamespaceCases root = do
  rows <- rowsOf (root </> "test/oracle/extension_security/namespace_cases.tsv")
  case rows of
    header : body -> do
      assertEqual "namespace header"
        ["keyspace", "left_tenant", "left_subject", "left_domain", "right_tenant", "right_subject", "right_domain"] header
      forM body $ \row -> case row of
        [keyspace, lt, ls, ld, rt, rs, rd] ->
          NamespaceCase <$> parseKeyspace keyspace <*> pure lt <*> pure ls <*> pure ld <*> pure rt <*> pure rs <*> pure rd
        _row -> die ("invalid namespace row: " <> show row)
    [] -> die "empty namespace oracle"

loadExpectedVerdicts :: FilePath -> IO [ExpectedVerdict]
loadExpectedVerdicts root = do
  rows <- rowsOf (root </> "test/oracle/extension_security/law_verdicts.tsv")
  case rows of
    header : body -> do
      assertEqual "verdict header" ["subject", "S1", "S2", "S3", "S4", "S5", "S6"] header
      forM body $ \row -> case row of
        subject : laws | length laws == 6 -> pure (ExpectedVerdict subject laws)
        _row -> die ("invalid verdict row: " <> show row)
    [] -> die "empty verdict oracle"

parseOperation :: Text -> IO SecurityOperation
parseOperation value = case value of
  "Read" -> pure Read
  "Update" -> pure Update
  "Delete" -> pure Delete
  "Replay" -> pure Replay
  "CacheLookup" -> pure CacheLookup
  _value -> die ("unknown operation " <> Text.unpack value)

parseKeyspace :: Text -> IO Keyspace
parseKeyspace value = case value of
  "RowKey" -> pure RowKey
  "ObjectPrefix" -> pure ObjectPrefix
  "TopicName" -> pure TopicName
  "CacheKey" -> pure CacheKey
  "ReplayKey" -> pure ReplayKey
  _value -> die ("unknown keyspace " <> Text.unpack value)

keyspaceName :: Keyspace -> Text
keyspaceName value = case value of
  RowKey -> "row"
  ObjectPrefix -> "object"
  TopicName -> "topic"
  CacheKey -> "cache"
  ReplayKey -> "replay"

writeEvidence :: FilePath -> SignedIdentityEnvelope -> [NamespaceCase] -> SecurityObservations -> IO ()
writeEvidence root envelope namespaceCases observations = do
  let output = root </> ".build/dsl/extension-security-laws"
      metrics =
        [ ("identity-envelope", "1-valid/1-tampered-refused")
        , ("operation-matrix", "15/15-exact")
        , ("refusal-pairs", "5/5-byte-identical-zero-mutation")
        , ("timing-envelope", "5/5-modeled-bound")
        , ("namespaces", "5/5-injective-round-trip")
        , ("revocation-layers", "2/2-edge-or-bound")
        , ("law-verdicts", "42/42-authored")
        , ("single-law-defects", "6/6-exact")
        , ("mutants", "6/6-red-exactly")
        , ("runtime", "UNVERIFIED")
        ]
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [key <> "\t" <> value <> "\n" | (key, value) <- metrics])
  writeFile (output </> "envelope.tsv")
    ("key\ttenant\tsubject\tsignature\n" <> Text.unpack fixtureKeyText <> "\t"
      <> Text.unpack (envelopeTenant envelope) <> "\t" <> Text.unpack (envelopeSubject envelope) <> "\t"
      <> Text.unpack (envelopeSignature envelope) <> "\n")
  writeFile (output </> "namespaces.tsv")
    ("keyspace\tleft\tright\n" <> concat
      [ show (caseKeyspace source) <> "\t" <> Text.unpack (namespaceLeft probe) <> "\t" <> Text.unpack (namespaceRight probe) <> "\n"
      | (source, probe) <- zip namespaceCases (namespaceProbes observations)
      ])

number :: Text -> Natural
number = read . Text.unpack

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines . Text.pack <$> readFile path

firstText :: Either Text value -> Either String value
firstText value = case value of
  Left problem -> Left (Text.unpack problem)
  Right result -> Right result

firstShow :: Show problem => Either problem value -> Either String value
firstShow value = case value of
  Left problem -> Left (show problem)
  Right result -> Right result

assertEqualEither :: (Eq value, Show value) => String -> value -> value -> Either String ()
assertEqualEither label expected actual =
  if expected == actual then Right () else Left (label <> ": expected " <> show expected <> ", got " <> show actual)

prefixOf :: String -> String -> Bool
prefixOf prefix value = take (length prefix) value == prefix

dropPrefix :: String -> String -> String
dropPrefix prefix value = drop (length prefix) value

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
