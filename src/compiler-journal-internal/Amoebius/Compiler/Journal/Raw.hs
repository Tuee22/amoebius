-- Declarations only; exact unsealed journal raw block from immutable B713.
-- Proposed private component. No parser/IO/judgment/permission/live resources.
module Amoebius.Compiler.Journal.Raw where

import Data.ByteString (ByteString)
import Data.Text (Text)
import Numeric.Natural (Natural)
import System.Exit (ExitCode)

data IOFailureView = IOFailureView
  { failureDisplay :: String, failureOperation :: String
  , failureLocation :: String, failurePath :: Maybe FilePath
  , failureType :: String, failureStoredErrno :: Maybe Integer }
  deriving (Eq, Read, Show)
data Attempt value = NotAttempted String | StartedWithoutReturn
  | Returned value | ThrewActualIOException IOFailureView deriving (Eq, Read, Show)

-- Intrinsic source sites ONLY; no Primary/Stillborn or caller classification.
data CompilerSite = BridgeBootstrapCompiler | ReAdmittedDelegatedCompiler
  deriving (Eq, Read, Show)
data AggregateSite = OuterCabal | GeneratedBridgeHelper deriving (Eq, Read, Show)
data Profile = CabalWindow | StandaloneWrapperBuildWindow
  | StandaloneDelegatedCompilerWindow deriving (Eq, Read, Show)
data ExistingModes = InheritStdinStdoutStderrEnvironmentAndCwdDelegateControlCTrue
  deriving (Eq, Read, Show)
data SourceAdmission = ActualCheckedContributionProjection [(FilePath, Text)]
  | NotPerformedByExistingStandaloneBootstrapEntrypoint deriving (Eq, Read, Show)

data SourceReference = SourceReference
  { sourceRequestedPath :: FilePath, sourceCompleteBytes :: Attempt ByteString }
  deriving (Eq, Read, Show)
data ImageMeasure = ImageMeasure Integer Text deriving (Eq, Read, Show)
data ImageReference = ImageReference
  { imageRequestedPath :: FilePath, imageResolvedPath :: Attempt FilePath
  , imageCompleteReadMeasure :: Attempt ImageMeasure }
  deriving (Eq, Read, Show)
-- Full image buffers stay private in memory for actual copying/equality. Only
-- actual length/hash measures persist here; no raw-binary archive floor is added.
-- These unsealed views retain actual observations; they do not impose executable
-- pins or prove which memory image/native provider was selected or executed.

data BridgeTemplate = CabalWindowLocatedBridge | ExistingStandaloneFixedPathBridge
  deriving (Eq, Read, Show)

data WindowInput = WindowInput
  { windowProfile :: Profile, freshPhysicalWindowRoot :: FilePath
  , checkedRepositoryRoot :: FilePath, admittedSources :: SourceAdmission
  , requestedNativeCompiler :: FilePath, preparedNativeCompilerPath :: Attempt FilePath
  , requestedHelper :: FilePath
  , requestedCabal :: Maybe FilePath, requestedConfig :: Maybe FilePath
  , selectedCabalCommand :: Maybe String, receivedCabalArguments :: [String]
  , exactForwardedCabalArguments :: [String]
  , bridgeTemplate :: Maybe BridgeTemplate
  , bootstrapBridgeSource :: Maybe SourceReference, bootstrapOutputPath :: Maybe FilePath
  , callableBridgeCopyPath :: Maybe FilePath
  , standaloneRequestedWrapperOutput :: Maybe FilePath
  , inheritedModes :: ExistingModes }
  deriving (Eq, Read, Show)

data WindowReady = WindowReady
  { readyWindowRoot :: FilePath, actualBootstrapOutput :: ImageReference
  , actualCallableBridgeCopy :: ImageReference
  , forcedCompleteImageCopyEquality :: Attempt Bool
  , readySourceAdmission :: SourceAdmission }
  deriving (Eq, Read, Show)

data CompilerRequest = CompilerRequest
  { compilerSite :: CompilerSite, requestWindowRoot :: FilePath
  , requestOrdinal :: Natural, requestedCompiler :: FilePath
  , checkedRoot :: FilePath, callAdmittedSources :: SourceAdmission
  , receivedBridgeLocation :: Maybe FilePath
  , receivedCompilerArguments :: [String]
  , exactForwardedCompilerArguments :: [String]
  , actualCwdRead :: Attempt FilePath, modeRequest :: ExistingModes }
  deriving (Eq, Read, Show)

data CompilerCallBegin = CompilerCallBegin
  { beginRequest :: CompilerRequest }
  deriving (Eq, Read, Show)
-- A begin means the strict journal prerequisite completed BEFORE rawSystem.
-- It is NOT an observed child spawn/PID, wait result, stream/EOF or quiescence.

data RawCompilerReturn = ActualRawSystemReturned ExitCode
  | ActualRawSystemThrewIOException IOFailureView deriving (Eq, Read, Show)
data CompilerCallReturn = CompilerCallReturn
  { returnRequest :: CompilerRequest, actualRawCompilerReturn :: RawCompilerReturn }
  deriving (Eq, Read, Show)
-- The REAL IOException object remains local and is rethrown unchanged. Its view
-- is not decoded back into a substitute exception or ExitFailure127.

data AggregateBegin = AggregateBegin AggregateSite FilePath [String] ExistingModes
  deriving (Eq, Read, Show)
data AggregateReturn = AggregateReturned AggregateSite ExitCode
  | AggregateThrewIOException AggregateSite IOFailureView deriving (Eq, Read, Show)
-- Cabal/helper aggregate returns never substitute for an actual compiler return.

data RetentionStage = WindowSetup | CallReservation | BeginWriteOrClose
  | GateReleaseBeforeCompiler | ReturnedRecordWriteOrClose
  | WindowCloseWriteOrClose | OptionalFailureRecordWriteOrClose
  deriving (Eq, Read, Show)
data RetentionFailure = RetentionFailure
  { retentionStage :: RetentionStage, retentionFailure :: IOFailureView }
  deriving (Eq, Read, Show)
-- An optional failure record can itself fail. No synthetic record/empty prefix
-- promises that all logging failures were observed or persisted.

data CallFiles = CallFiles
  { callOrdinal :: Natural, callDirectory :: FilePath
  , beginCompleteBytes :: Attempt ByteString
  , returnedCompleteBytes :: Attempt ByteString
  , optionalRetentionFailureBytes :: Attempt ByteString }
  deriving (Eq, Read, Show)
data WindowClose = WindowClose
  { closedWindowRoot :: FilePath
  , actualAggregateReturn :: Attempt AggregateReturn
  , actualCallDirectoryInventory :: [FilePath]
  , actualCallFilesInOrdinalOrder :: [CallFiles]
  , actualOtherWindowRelativeFiles :: [FilePath] }
  deriving (Eq, Read, Show)
-- This closes admission to NEW calls, not a process group or lifetime theorem.
-- Counted consumers re-read/rederive every field; a producer close is not a seal.

