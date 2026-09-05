{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Declaration-derived suite inventory, passing-run seal, and verdict-gated link set.
--
-- This is a pure Register-1 boundary.  It derives the cases and verifies an explicit
-- run observation; it does not execute an extension or authenticate the observer.
module Amoebius.Extension.Conformance.Gate
  ( CoreVersion
  , coreVersion
  , coreVersionText
  , SuiteKind (..)
  , suiteKindTag
  , everySuiteKind
  , GateCase (..)
  , CoverageStatus (..)
  , CoverageCell (..)
  , GatePlan
  , deriveGatePlan
  , gatePlanDeclarationDigest
  , gatePlanCoreVersion
  , gatePlanCases
  , gatePlanCoverage
  , gatePlanSuiteDigest
  , GeneratedFile (..)
  , generatedFiles
  , CaseResult (..)
  , ObservedCase (..)
  , ConformanceVerdict
  , VerdictResult (..)
  , verdictDeclarationDigest
  , verdictCoreVersion
  , verdictSuiteDigest
  , verdictResult
  , verdictDigest
  , GateRunError (..)
  , runGeneratedGate
  , verifyVerdict
  , LinkSet
  , emptyLinkSet
  , linkSetMembers
  , AdmissionError (..)
  , admitExtension
  ) where

import Amoebius.Extension.Declaration
  ( ExtensionDeclaration
  , declarationDigest
  , extensionName
  )
import Amoebius.Extension.Laws.Compositional
  ( compositionLawTag
  , everyCompositionLaw
  )
import Amoebius.Extension.Laws.PerExtension
  ( Law (..)
  , declarationVocabulary
  , lawTag
  , vocabularyArtifactNames
  , vocabularyBudgetNames
  , vocabularyClaimNames
  , vocabularyOperationNames
  )
import Amoebius.Extension.Laws.Security
  ( everySecurityLaw
  , securityLawTag
  )
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)

newtype CoreVersion = CoreVersion Text
  deriving stock (Eq, Ord, Show)

coreVersion :: Text -> Maybe CoreVersion
coreVersion value
  | Text.null value = Nothing
  | otherwise = Just (CoreVersion value)

coreVersionText :: CoreVersion -> Text
coreVersionText (CoreVersion value) = value

data SuiteKind
  = PropertySuite
  | CompositionSuite
  | CompileFailSuite
  | SecuritySuite
  | TransactionSuite
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everySuiteKind :: [SuiteKind]
everySuiteKind = [minBound .. maxBound]

suiteKindTag :: SuiteKind -> Text
suiteKindTag kind = case kind of
  PropertySuite -> "property"
  CompositionSuite -> "composition"
  CompileFailSuite -> "compile-fail"
  SecuritySuite -> "security"
  TransactionSuite -> "transaction"

data GateCase = GateCase
  { gateCaseId :: Text
  , gateCaseSuite :: SuiteKind
  , gateCaseLaw :: Text
  , gateCaseAxis :: Text
  , gateCasePeerDigest :: Maybe Text
  }
  deriving stock (Eq, Ord, Show)

data CoverageStatus
  = CoverageRequired
  | CoverageNotApplicable Text
  deriving stock (Eq, Ord, Show)

data CoverageCell = CoverageCell
  { coverageLaw :: Text
  , coverageAxis :: Text
  , coverageStatus :: CoverageStatus
  }
  deriving stock (Eq, Ord, Show)

data GatePlan scope = GatePlan
  { internalDeclarationDigest :: Text
  , internalCoreVersion :: CoreVersion
  , internalCases :: [GateCase]
  , internalCoverage :: [CoverageCell]
  }

gatePlanDeclarationDigest :: GatePlan scope -> Text
gatePlanDeclarationDigest = internalDeclarationDigest

gatePlanCoreVersion :: GatePlan scope -> CoreVersion
gatePlanCoreVersion = internalCoreVersion

gatePlanCases :: GatePlan scope -> [GateCase]
gatePlanCases = internalCases

gatePlanCoverage :: GatePlan scope -> [CoverageCell]
gatePlanCoverage = internalCoverage

deriveGatePlan
  :: CoreVersion
  -> ExtensionDeclaration scope
  -> [ExtensionDeclaration scope]
  -> GatePlan scope
deriveGatePlan version declaration peers =
  GatePlan
    { internalDeclarationDigest = declarationDigest declaration
    , internalCoreVersion = version
    , internalCases = sortOn gateCaseId cases
    , internalCoverage = sortOn (\cell -> (coverageLaw cell, coverageAxis cell)) coverage
    }
 where
  vocabulary = declarationVocabulary declaration
  propertyAxes =
    [ (lawTag L1, vocabularyOperationNames vocabulary)
    , (lawTag L2, vocabularyArtifactNames vocabulary)
    , (lawTag L3, vocabularyBudgetNames vocabulary)
    , (lawTag L4, vocabularyOperationNames vocabulary)
    , (lawTag L5, vocabularyClaimNames vocabulary)
    ]
  propertyCases =
    [ makeCase PropertySuite law axis Nothing
    | (law, axes) <- propertyAxes
    , axis <- axes
#if defined(EXTENSION_CONFORMANCE_OMIT_LAW_MUTANT)
    , law /= "L5"
#endif
    ]
  normalizedPeers = sortOn (\peer -> (extensionName peer, declarationDigest peer)) peers
  compositionCases =
    [ makeCase CompositionSuite (compositionLawTag law) (extensionName peer) (Just (declarationDigest peer))
    | peer <- normalizedPeers
    , law <- everyCompositionLaw
    ]
  compileCases =
    [ makeCase CompileFailSuite "compile" claim Nothing
    | claim <- vocabularyClaimNames vocabulary
    ]
  securityCases =
    [ makeCase SecuritySuite (securityLawTag law) "security-boundary" Nothing
    | law <- everySecurityLaw
    ]
  cases = propertyCases <> compositionCases <> compileCases <> securityCases
  requiredCoverage =
    [ CoverageCell (gateCaseLaw entry) (gateCaseAxis entry) CoverageRequired
    | entry <- propertyCases <> compositionCases <> securityCases
    ]
  transactionCoverage =
    [ CoverageCell law "transaction-vocabulary" (CoverageNotApplicable "transaction-vocabulary-not-declared")
    | law <- ["P1", "P2", "P3", "P4", "P5", "P6"]
    ]
  coverage = requiredCoverage <> transactionCoverage

makeCase :: SuiteKind -> Text -> Text -> Maybe Text -> GateCase
makeCase suite law axis peer = GateCase identifier suite law axis peer
 where
  identifier = "case-" <> digestText (frameText [suiteKindTag suite, law, axis, maybe "" id peer])

data GeneratedFile = GeneratedFile
  { generatedPath :: Text
  , generatedBytes :: ByteString
  }
  deriving stock (Eq, Ord, Show)

generatedFiles :: GatePlan scope -> [GeneratedFile]
generatedFiles plan =
  sortOn generatedPath
    ( [ GeneratedFile (suiteKindTag suite <> "-suite.tsv") (renderSuite plan suite)
      | suite <- everySuiteKind
      ]
        <> [GeneratedFile "coverage-grid.tsv" (renderCoverage plan)]
    )

renderSuite :: GatePlan scope -> SuiteKind -> ByteString
renderSuite plan suite = Encoding.encodeUtf8 . Text.unlines $
  metadata plan
    <> ["case_id\tlaw\taxis_hex\tpeer_digest"]
    <> [ Text.intercalate "\t"
          [ gateCaseId entry
          , gateCaseLaw entry
          , hexText (gateCaseAxis entry)
          , maybe "-" id (gateCasePeerDigest entry)
          ]
       | entry <- gatePlanCases plan
       , gateCaseSuite entry == suite
       ]

renderCoverage :: GatePlan scope -> ByteString
renderCoverage plan = Encoding.encodeUtf8 . Text.unlines $
  metadata plan
    <> ["law\taxis_hex\tstatus\treason_hex"]
    <> fmap row (gatePlanCoverage plan)
 where
  row cell = case coverageStatus cell of
    CoverageRequired -> Text.intercalate "\t" [coverageLaw cell, hexText (coverageAxis cell), "required", "-"]
    CoverageNotApplicable reason ->
      Text.intercalate "\t" [coverageLaw cell, hexText (coverageAxis cell), "not-applicable", hexText reason]

metadata :: GatePlan scope -> [Text]
metadata plan =
  [ "# declaration\t" <> gatePlanDeclarationDigest plan
  , "# core\t" <> hexText (coreVersionText (gatePlanCoreVersion plan))
  ]

gatePlanSuiteDigest :: GatePlan scope -> Text
gatePlanSuiteDigest = generatedDigest . generatedFiles

generatedDigest :: [GeneratedFile] -> Text
generatedDigest files = digestText . frameBytes . concatMap fields $ sortOn generatedPath files
 where
  fields file = [Encoding.encodeUtf8 (generatedPath file), generatedBytes file]

data CaseResult
  = CasePassed
  | CaseFailed Text
  deriving stock (Eq, Ord, Show)

data ObservedCase = ObservedCase
  { observedCaseId :: Text
  , observedCaseResult :: CaseResult
  }
  deriving stock (Eq, Ord, Show)

data VerdictResult = VerdictPassed
  deriving stock (Eq, Ord, Show)

data ConformanceVerdict scope = ConformanceVerdict
  { internalVerdictDeclarationDigest :: Text
  , internalVerdictCoreVersion :: CoreVersion
  , internalVerdictSuiteDigest :: Text
  , internalVerdictResult :: VerdictResult
  , internalVerdictDigest :: Text
  }

verdictDeclarationDigest :: ConformanceVerdict scope -> Text
verdictDeclarationDigest = internalVerdictDeclarationDigest

verdictCoreVersion :: ConformanceVerdict scope -> CoreVersion
verdictCoreVersion = internalVerdictCoreVersion

verdictSuiteDigest :: ConformanceVerdict scope -> Text
verdictSuiteDigest = internalVerdictSuiteDigest

verdictResult :: ConformanceVerdict scope -> VerdictResult
verdictResult = internalVerdictResult

verdictDigest :: ConformanceVerdict scope -> Text
verdictDigest = internalVerdictDigest

data GateRunError
  = GeneratedSuiteMismatch Text Text
  | CaseInventoryMismatch [Text] [Text]
  | CasesFailed [(Text, Text)]
  deriving stock (Eq, Ord, Show)

runGeneratedGate
  :: GatePlan scope
  -> [GeneratedFile]
  -> [ObservedCase]
  -> Either GateRunError (ConformanceVerdict scope)
runGeneratedGate plan observedFiles observations
  | actualSuiteDigest /= wantedSuiteDigest = Left (GeneratedSuiteMismatch wantedSuiteDigest actualSuiteDigest)
  | observedIds /= wantedIds = Left (CaseInventoryMismatch wantedIds observedIds)
  | not (null failures) = Left (CasesFailed failures)
  | otherwise = Right verdict
 where
  wantedSuiteDigest = gatePlanSuiteDigest plan
#if defined(EXTENSION_CONFORMANCE_IGNORE_SUITE_DIGEST_MUTANT)
  actualSuiteDigest = wantedSuiteDigest
#else
  actualSuiteDigest = generatedDigest observedFiles
#endif
  wantedIds = sort (fmap gateCaseId (gatePlanCases plan))
  observedIds = sort (fmap observedCaseId observations)
  failures =
    [ (observedCaseId entry, reason)
    | entry <- observations
    , CaseFailed reason <- [observedCaseResult entry]
    ]
  declaration = gatePlanDeclarationDigest plan
  version = gatePlanCoreVersion plan
  address = verdictAddress declaration version wantedSuiteDigest VerdictPassed
  verdict = ConformanceVerdict declaration version wantedSuiteDigest VerdictPassed address

verifyVerdict :: GatePlan scope -> ConformanceVerdict scope -> Bool
verifyVerdict plan verdict =
  verdictDeclarationDigest verdict == gatePlanDeclarationDigest plan
    && verdictCoreVersion verdict == gatePlanCoreVersion plan
    && verdictSuiteDigest verdict == gatePlanSuiteDigest plan
    && verdictDigest verdict
      == verdictAddress
          (verdictDeclarationDigest verdict)
          (verdictCoreVersion verdict)
          (verdictSuiteDigest verdict)
          (verdictResult verdict)

verdictAddress :: Text -> CoreVersion -> Text -> VerdictResult -> Text
verdictAddress declaration version suite result =
  digestText (frameText ["amoebius-extension-verdict-v1", declaration, coreVersionText version, suite, resultTag result])

resultTag :: VerdictResult -> Text
resultTag VerdictPassed = "passed"

newtype LinkSet scope = LinkSet [(Text, Text, Text)]
  deriving stock (Eq, Show)

emptyLinkSet :: LinkSet scope
emptyLinkSet = LinkSet []

linkSetMembers :: LinkSet scope -> [(Text, Text, Text)]
linkSetMembers (LinkSet members) = members

data AdmissionError
  = PlanDeclarationMismatch Text Text
  | VerdictDidNotVerify
  | ExtensionAlreadyAdmitted Text
  deriving stock (Eq, Ord, Show)

admitExtension
  :: GatePlan scope
  -> ExtensionDeclaration scope
  -> ConformanceVerdict scope
  -> LinkSet scope
  -> Either AdmissionError (LinkSet scope)
admitExtension plan declaration verdict (LinkSet members)
  | gatePlanDeclarationDigest plan /= declarationDigest declaration =
      Left (PlanDeclarationMismatch (declarationDigest declaration) (gatePlanDeclarationDigest plan))
#if defined(EXTENSION_CONFORMANCE_IGNORE_VERDICT_MUTANT)
  | False = Left VerdictDidNotVerify
#else
  | not (verifyVerdict plan verdict) = Left VerdictDidNotVerify
#endif
  | declarationDigest declaration `elem` [digest | (_name, digest, _seal) <- members] =
      Left (ExtensionAlreadyAdmitted (declarationDigest declaration))
  | otherwise =
      Right . LinkSet . sort $
        (extensionName declaration, declarationDigest declaration, verdictDigest verdict) : members

hexText :: Text -> Text
hexText = Text.pack . concatMap hexByte . ByteString.unpack . Encoding.encodeUtf8

frameText :: [Text] -> ByteString
frameText = frameBytes . fmap Encoding.encodeUtf8

frameBytes :: [ByteString] -> ByteString
frameBytes = LazyByteString.toStrict . Builder.toLazyByteString . foldMap framed
 where
  framed bytes = Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

digestText :: ByteString -> Text
digestText bytes = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
