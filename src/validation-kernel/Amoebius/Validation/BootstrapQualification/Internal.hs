{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden execution authority for the finite Phase-0 mutation seed.
--
-- The authority is minted only after exact source bytes from an acquired Git
-- snapshot are copied into an ignored run root, one production decision is
-- changed per mutant, all four binaries are compiled serially by the genesis
-- compiler, and the independent driver accepts only the clean binary.  The
-- generated leaf is removed before a successful value is returned.
module Amoebius.Validation.BootstrapQualification.Internal
  ( BootstrapCase (..)
  , QualifiedBootstrapProtocol
  , acquireQualifiedBootstrapProtocol
  , bootstrapCaseCount
  , bootstrapQualificationCheck
  , foldQualifiedBootstrapProtocol
  , renderBootstrapCase
#if defined(VALIDATION_BOOTSTRAP_QUALIFICATION_INTERNAL_TEST_HOOKS)
  , bootstrapQualificationInternalTestProtocol
#endif
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustCompilerExecutable
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SourceSnapshot (snapshotEntries, snapshotIdentity, snapshotRoot)
  , TrackedEntry (trackedBytes, trackedIndex)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Control.Exception (IOException, try)
import Control.Monad (forM)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( createDirectory
  , createDirectoryIfMissing
  , doesPathExist
  , removeFile
  , removePathForcibly
  )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, takeDirectory, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (readProcessWithExitCode)

data BootstrapCase
  = DigestEqualityBypass
  | SnapshotFreshnessBypass
  | BootstrapPathBypass
  deriving (Bounded, Enum, Eq, Ord, Show)

data CaseReceipt = CaseReceipt
  { receiptCase :: Maybe BootstrapCase
  , receiptSourceDigest :: Text
  , receiptBinaryDigest :: Text
  , receiptCompileExit :: ExitCode
  , receiptRunExit :: ExitCode
  , receiptRunStdout :: Text
  , receiptRunStderr :: Text
  }
  deriving (Eq, Show)

-- | All projections are read-only; the constructor remains package-hidden.
data QualifiedBootstrapProtocol = QualifiedBootstrapProtocol
  { protocolSnapshotDigest :: Text
  , protocolSubjectDigest :: Text
  , protocolOracleDigest :: Text
  , protocolHarnessDigest :: Text
  , protocolTranscriptDigest :: Text
  , protocolCompilerPath :: FilePath
  , protocolRunLeaf :: FilePath
  , protocolReceipts :: [CaseReceipt]
  }
  deriving (Eq, Show)

bootstrapCases :: [BootstrapCase]
bootstrapCases = [minBound .. maxBound]

bootstrapCaseCount :: Int
bootstrapCaseCount = length bootstrapCases

renderBootstrapCase :: BootstrapCase -> Text
renderBootstrapCase bootstrapCase = case bootstrapCase of
  DigestEqualityBypass -> "digest-equality-bypass"
  SnapshotFreshnessBypass -> "snapshot-freshness-bypass"
  BootstrapPathBypass -> "bootstrap-path-bypass"

foldQualifiedBootstrapProtocol
  :: ( Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> FilePath
       -> FilePath
       -> [(Maybe BootstrapCase, Text, Text, ExitCode, ExitCode, Text, Text)]
       -> value
     )
  -> QualifiedBootstrapProtocol
  -> value
foldQualifiedBootstrapProtocol consume protocol =
  consume
    (protocolSnapshotDigest protocol)
    (protocolSubjectDigest protocol)
    (protocolOracleDigest protocol)
    (protocolHarnessDigest protocol)
    (protocolTranscriptDigest protocol)
    (protocolCompilerPath protocol)
    (protocolRunLeaf protocol)
    [ ( receiptCase receipt
      , receiptSourceDigest receipt
      , receiptBinaryDigest receipt
      , receiptCompileExit receipt
      , receiptRunExit receipt
      , receiptRunStdout receipt
      , receiptRunStderr receipt
      )
    | receipt <- protocolReceipts protocol
    ]

acquireQualifiedBootstrapProtocol
  :: FilePath
  -> GenesisTrust
  -> AcquiredSourceSnapshot
  -> IO (Either [Finding] QualifiedBootstrapProtocol)
acquireQualifiedBootstrapProtocol repositoryRoot trust acquired = do
  let snapshot = acquiredSourceSnapshot acquired
      compilerPath = genesisTrustCompilerExecutable trust
      inputProblems =
        [ bootstrapFinding
            "BOOTSTRAP-QUALIFICATION-ROOT"
            "the dispatcher repository root differs from the acquired snapshot root"
        | repositoryRoot /= snapshotRoot snapshot
        ]
          <> [ bootstrapFinding
                 "BOOTSTRAP-QUALIFICATION-COMPILER"
                 "the genesis compiler path supplied by ghc-paths is not absolute"
             | not (isAbsolute compilerPath)
             ]
  case inputProblems <> sourceInputProblems snapshot of
    problems@(_ : _) -> pure (Left problems)
    [] -> do
      result <- try (runQualification repositoryRoot compilerPath snapshot) :: IO (Either IOException (Either [Finding] QualifiedBootstrapProtocol))
      pure $ case result of
        Left problem ->
          Left
            [ bootstrapFinding
                "BOOTSTRAP-QUALIFICATION-IO"
                (Text.pack (show problem))
            ]
        Right qualified -> qualified

runQualification
  :: FilePath
  -> FilePath
  -> SourceSnapshot
  -> IO (Either [Finding] QualifiedBootstrapProtocol)
runQualification repositoryRoot compilerPath snapshot = do
  let subjectBytes = requiredTrackedBytes snapshot subjectSourcePath
      oracleBytes = requiredTrackedBytes snapshot oracleSourcePath
      harnessBytes = requiredTrackedBytes snapshot harnessSourcePath
      runParent = repositoryRoot </> ".build" </> "runs" </> "phase-00"
  createDirectoryIfMissing True runParent
  (temporaryPath, handle) <- openBinaryTempFile runParent "bootstrap-qualification-"
  hClose handle
  removeFile temporaryPath
  createDirectory temporaryPath
  execution <- try (executeCases compilerPath temporaryPath subjectBytes oracleBytes) :: IO (Either IOException [CaseReceipt])
  cleanup <- try (removePathForcibly temporaryPath) :: IO (Either IOException ())
  remains <- doesPathExist temporaryPath
  pure $ case (execution, cleanup, remains) of
    (Left problem, _, _) ->
      Left [bootstrapFinding "BOOTSTRAP-QUALIFICATION-EXECUTION" (Text.pack (show problem))]
    (_, Left problem, _) ->
      Left [bootstrapFinding "BOOTSTRAP-QUALIFICATION-CLEANUP" (Text.pack (show problem))]
    (_, _, True) ->
      Left [bootstrapFinding "BOOTSTRAP-QUALIFICATION-RESIDUE" "the generated qualification leaf still exists after cleanup"]
    (Right receipts, Right (), False) ->
      case qualificationReceiptProblems receipts of
        problems@(_ : _) -> Left problems
        [] ->
          let transcript = qualificationTranscript snapshot compilerPath receipts
           in Right
                QualifiedBootstrapProtocol
                  { protocolSnapshotDigest = snapshotIdentity snapshot
                  , protocolSubjectDigest = sha256 subjectBytes
                  , protocolOracleDigest = sha256 oracleBytes
                  , protocolHarnessDigest = sha256 harnessBytes
                  , protocolTranscriptDigest = sha256 transcript
                  , protocolCompilerPath = compilerPath
                  , protocolRunLeaf = temporaryPath
                  , protocolReceipts = receipts
                  }

executeCases :: FilePath -> FilePath -> ByteString -> ByteString -> IO [CaseReceipt]
executeCases compilerPath runLeaf subjectBytes oracleBytes = do
  clean <- executeCase compilerPath runLeaf Nothing subjectBytes oracleBytes
  mutants <-
    forM bootstrapCases $ \bootstrapCase ->
      case mutateSubject bootstrapCase subjectBytes of
        Left detail ->
          pure
            CaseReceipt
              { receiptCase = Just bootstrapCase
              , receiptSourceDigest = sha256 subjectBytes
              , receiptBinaryDigest = ""
              , receiptCompileExit = ExitFailure 125
              , receiptRunExit = ExitFailure 125
              , receiptRunStdout = ""
              , receiptRunStderr = detail
              }
        Right mutated -> executeCase compilerPath runLeaf (Just bootstrapCase) mutated oracleBytes
  pure (clean : mutants)

executeCase :: FilePath -> FilePath -> Maybe BootstrapCase -> ByteString -> ByteString -> IO CaseReceipt
executeCase compilerPath runLeaf selected subjectBytes oracleBytes = do
  let caseName = maybe "clean" (Text.unpack . renderBootstrapCase) selected
      caseRoot = runLeaf </> caseName
      subjectRoot = caseRoot </> "subject"
      oracleRoot = caseRoot </> "oracle"
      objectRoot = caseRoot </> "objects"
      subjectFile = subjectRoot </> "Amoebius" </> "Validation" </> "BootstrapPredicate.hs"
      oracleFile = oracleRoot </> "BootstrapMutationDriver.hs"
      binaryFile = caseRoot </> "bootstrap-mutation-driver"
  createDirectoryIfMissing True (takeDirectory subjectFile)
  createDirectoryIfMissing True oracleRoot
  createDirectoryIfMissing True objectRoot
  ByteString.writeFile subjectFile subjectBytes
  ByteString.writeFile oracleFile oracleBytes
  (compileExit, _, _) <-
    readProcessWithExitCode
      compilerPath
      [ "-j1"
      , "-fforce-recomp"
      , "-v0"
      , "-outputdir"
      , objectRoot
      , "-i" <> subjectRoot
      , "-i" <> oracleRoot
      , "-main-is"
      , "BootstrapMutationDriver.main"
      , oracleFile
      , subjectFile
      , "-o"
      , binaryFile
      ]
      ""
  binaryExists <- doesPathExist binaryFile
  (runExit, runStdout, runStderr) <-
    if compileExit == ExitSuccess && binaryExists
      then readProcessWithExitCode binaryFile [] ""
      else pure (ExitFailure 126, "", "binary was not produced")
  binaryBytes <- if binaryExists then ByteString.readFile binaryFile else pure ByteString.empty
  pure
    CaseReceipt
      { receiptCase = selected
      , receiptSourceDigest = sha256 subjectBytes
      , receiptBinaryDigest = if binaryExists then sha256 binaryBytes else ""
      , receiptCompileExit = compileExit
      , receiptRunExit = runExit
      , receiptRunStdout = Text.pack runStdout
      , receiptRunStderr = Text.pack runStderr
      }

qualificationReceiptProblems :: [CaseReceipt] -> [Finding]
qualificationReceiptProblems receipts =
  inventoryProblems
    <> concatMap receiptProblems receipts
    <> distinctProblems
 where
  expectedInventory = Nothing : map Just bootstrapCases
  inventoryProblems =
    [ bootstrapFinding
        "BOOTSTRAP-QUALIFICATION-INVENTORY"
        "the executed case inventory is not the exact clean-plus-three-mutant sequence"
    | map receiptCase receipts /= expectedInventory
    ]
  receiptProblems receipt =
    [ bootstrapFinding
        "BOOTSTRAP-QUALIFICATION-COMPILE"
        (caseLabel receipt <> " did not compile successfully")
    | receiptCompileExit receipt /= ExitSuccess
    ]
      <> case receiptCase receipt of
        Nothing ->
          [ bootstrapFinding
              "BOOTSTRAP-QUALIFICATION-CONTROL"
              "the unchanged production source did not pass the independent driver"
          | receiptRunExit receipt /= ExitSuccess
          ]
            <> [ bootstrapFinding
                   "BOOTSTRAP-QUALIFICATION-CONTROL-OUTPUT"
                   "the unchanged production source emitted unexpected driver output"
               | not (Text.null (receiptRunStdout receipt))
                   || not (Text.null (receiptRunStderr receipt))
               ]
        Just bootstrapCase ->
          [ bootstrapFinding
              "BOOTSTRAP-QUALIFICATION-MUTANT-EXIT"
              (caseLabel receipt <> " did not exit with the exact independent-driver refusal status")
          | receiptRunExit receipt /= ExitFailure 1
          ]
            <> [ bootstrapFinding
                   "BOOTSTRAP-QUALIFICATION-MUTANT-STDOUT"
                   (caseLabel receipt <> " emitted unexpected standard output")
               | not (Text.null (receiptRunStdout receipt))
               ]
            <> [ bootstrapFinding
                   "BOOTSTRAP-QUALIFICATION-MUTANT-REASON"
                   (caseLabel receipt <> " did not emit its exact independent-driver refusal reason")
               | receiptRunStderr receipt /= renderBootstrapCase bootstrapCase <> "\n"
               ]
  distinctProblems = case receipts of
    [] -> []
    clean : mutants ->
      [ bootstrapFinding
          "BOOTSTRAP-QUALIFICATION-NOOP-MUTANT"
          (caseLabel mutant <> " retained the clean production source digest")
      | mutant <- mutants
      , receiptSourceDigest mutant == receiptSourceDigest clean
      ]
        <> [ bootstrapFinding
               "BOOTSTRAP-QUALIFICATION-BINARY-IDENTITY"
               (caseLabel mutant <> " retained the clean binary digest")
           | mutant <- mutants
           , receiptBinaryDigest mutant == receiptBinaryDigest clean
           ]

bootstrapQualificationCheck
  :: Either [Finding] QualifiedBootstrapProtocol
  -> CheckResult
bootstrapQualificationCheck authority = case authority of
  Left problems ->
    CheckResult
      { checkName = "bootstrap-qualification"
      , checkObservations = [observation "bootstrap.qualification" "refused"]
      , checkFindings = problems
      }
  Right protocol ->
    foldQualifiedBootstrapProtocol
      (\snapshotDigest subjectDigest oracleDigest harnessDigest transcriptDigest compilerPath runLeaf receipts ->
        CheckResult
          { checkName = "bootstrap-qualification"
          , checkObservations =
              [ observation "bootstrap.snapshot.sha256" snapshotDigest
              , observation "bootstrap.subject.sha256" subjectDigest
              , observation "bootstrap.oracle.sha256" oracleDigest
              , observation "bootstrap.harness.sha256" harnessDigest
              , observation "bootstrap.transcript.sha256" transcriptDigest
              , observation "bootstrap.compiler.path" (Text.pack compilerPath)
              , observation "bootstrap.case-count" (Text.pack (show (length receipts)))
              , observation "bootstrap.cleanup" ("absent=" <> Text.pack runLeaf)
              ]
          , checkFindings = []
          }
      )
      protocol

sourceInputProblems :: SourceSnapshot -> [Finding]
sourceInputProblems snapshot =
  concatMap exactOne [subjectSourcePath, oracleSourcePath, harnessSourcePath]
 where
  exactOne path =
    [ bootstrapFinding
        "BOOTSTRAP-QUALIFICATION-SOURCE-INVENTORY"
        ("expected exactly one acquired tracked entry for " <> Text.pack path)
    | length (trackedMatches snapshot path) /= 1
    ]

requiredTrackedBytes :: SourceSnapshot -> FilePath -> ByteString
requiredTrackedBytes snapshot path = case trackedMatches snapshot path of
  [bytes] -> bytes
  _ -> ByteString.empty

trackedMatches :: SourceSnapshot -> FilePath -> [ByteString]
trackedMatches snapshot path =
  [ trackedBytes entry
  | entry <- snapshotEntries snapshot
  , indexPath (trackedIndex entry) == path
  ]

mutateSubject :: BootstrapCase -> ByteString -> Either Text ByteString
mutateSubject bootstrapCase source = replaceExactlyOnce original replacement source
 where
  (original, replacement) = case bootstrapCase of
    DigestEqualityBypass ->
      ( "bootstrapDigestMatches actual expected = validLowerSha256 actual && actual == expected"
      , "bootstrapDigestMatches _ _ = True"
      )
    SnapshotFreshnessBypass ->
      ( "bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing"
      , "bootstrapSnapshotMatches _ _ = True"
      )
    BootstrapPathBypass ->
      ( "bootstrapInputPathAllowed path = \".build/bootstrap-inputs/\" `isPrefixOf` path && boundedRelativePath path"
      , "bootstrapInputPathAllowed _ = True"
      )

replaceExactlyOnce :: ByteString -> ByteString -> ByteString -> Either Text ByteString
replaceExactlyOnce needle replacement haystack =
  case splitOn needle haystack of
    [before, after] -> Right (before <> replacement <> after)
    parts ->
      Left
        ( "mutation marker occurrence count was "
            <> Text.pack (show (length parts - 1))
        )

splitOn :: ByteString -> ByteString -> [ByteString]
splitOn needle bytes
  | ByteString.null needle = [bytes]
  | otherwise = go bytes
 where
  go remaining =
    let (before, suffix) = ByteString8.breakSubstring needle remaining
     in if ByteString.null suffix
          then [before]
          else before : go (ByteString.drop (ByteString.length needle) suffix)

qualificationTranscript :: SourceSnapshot -> FilePath -> [CaseReceipt] -> ByteString
qualificationTranscript snapshot compilerPath receipts =
  ByteString.concat
    ( "amoebius-bootstrap-qualification-v2\0"
        : TextEncoding.encodeUtf8 (snapshotIdentity snapshot)
        : "\0"
        : ByteString8.pack compilerPath
        : "\0"
        : concatMap renderReceipt (sortOn receiptCase receipts)
    )
 where
  renderReceipt receipt =
    [ TextEncoding.encodeUtf8 (maybe "clean" renderBootstrapCase (receiptCase receipt))
    , "\0"
    , TextEncoding.encodeUtf8 (receiptSourceDigest receipt)
    , "\0"
    , TextEncoding.encodeUtf8 (receiptBinaryDigest receipt)
    , "\0"
    , ByteString8.pack (show (receiptCompileExit receipt))
    , "\0"
    , ByteString8.pack (show (receiptRunExit receipt))
    , "\0"
    , TextEncoding.encodeUtf8 (receiptRunStdout receipt)
    , "\0"
    , TextEncoding.encodeUtf8 (receiptRunStderr receipt)
    , "\0"
    ]

caseLabel :: CaseReceipt -> Text
caseLabel = maybe "clean" renderBootstrapCase . receiptCase

sha256 :: ByteString -> Text
sha256 = Text.pack . show . Crypto.hashWith Crypto.SHA256

bootstrapFinding :: Text -> Text -> Finding
bootstrapFinding code = finding code "<bootstrap-qualification>"

#if defined(VALIDATION_BOOTSTRAP_QUALIFICATION_INTERNAL_TEST_HOOKS)
-- | Direct-source-only sealed fixture for tests of downstream evidence
-- composition. Production builds expose only the executing acquisition path.
bootstrapQualificationInternalTestProtocol :: Text -> QualifiedBootstrapProtocol
bootstrapQualificationInternalTestProtocol snapshotDigest =
  QualifiedBootstrapProtocol
    { protocolSnapshotDigest = snapshotDigest
    , protocolSubjectDigest = digest "subject"
    , protocolOracleDigest = digest "oracle"
    , protocolHarnessDigest = digest "harness"
    , protocolTranscriptDigest = digest "transcript"
    , protocolCompilerPath = "/genesis/bin/ghc"
    , protocolRunLeaf = "/generated/bootstrap-qualification-removed"
    , protocolReceipts =
        CaseReceipt Nothing (digest "subject") (digest "clean-binary") ExitSuccess ExitSuccess "" ""
          : [ CaseReceipt
                (Just bootstrapCase)
                (digest ("mutated-source-" <> ByteString8.pack (show (fromEnum bootstrapCase))))
                (digest ("mutated-binary-" <> ByteString8.pack (show (fromEnum bootstrapCase))))
                ExitSuccess
                (ExitFailure 1)
                ""
                (renderBootstrapCase bootstrapCase <> "\n")
            | bootstrapCase <- bootstrapCases
            ]
    }
 where
  digest = sha256
#endif

subjectSourcePath, oracleSourcePath, harnessSourcePath :: FilePath
subjectSourcePath = "src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs"
oracleSourcePath = "test/validation-kernel/BootstrapMutationDriver.hs"
harnessSourcePath = "src/validation-kernel/Amoebius/Validation/BootstrapQualification/Internal.hs"
