{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module SeedCustodyPrerequisitesOracle
  ( main
  , runSeedCustodyPrerequisitesOracle
  ) where

-- Component refusal checks with generated filesystem fixtures. These cases neither launch a candidate
-- nor observe the four required OS denials. Path/identity prerequisites remain
-- unqualified even when the environment supplies every prerequisite.
-- Expectations are independent literals, not production renderers or reports.

import Amoebius.Validation.SeedCustodyPrerequisites
  ( SeedCustodyRequest (..)
  , seedCustodyPrerequisitesDiagnostic
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (forM_, unless)
import Data.List (sort)
import Data.Word (Word32)
#if !defined(mingw32_HOST_OS)
import Amoebius.Validation.SeedCustodyPrerequisites.Internal
  ( ProtectedFile (AcceptedSeed)
  , seedCustodyFileMetadataDiagnostic
  )
import System.Directory (canonicalizePath, createDirectory)
import System.FilePath ((</>))
import System.IO.Temp (withTempDirectory)
import System.Posix.Files (createNamedPipe, createSymbolicLink)
import System.Posix.User (getEffectiveUserID, getRealUserID)
import System.Timeout (timeout)
#endif

main :: IO ()
main = runSeedCustodyPrerequisitesOracle

runSeedCustodyPrerequisitesOracle :: IO ()
runSeedCustodyPrerequisitesOracle = do
  forM_ malformedRoots $ \(label, root) ->
    expectRefusal label root 1 [rootRefusal, unqualifiedRefusal]
  expectRefusal "zero candidate UID" "/" 0 [candidateRefusal, unqualifiedRefusal]
  expectRefusal "reserved candidate UID" "/" maxBound [candidateRefusal, unqualifiedRefusal]
  -- Invalid root syntax has priority even when the UID is also invalid.
  expectRefusal "invalid root before zero UID" "relative" 0 [rootRefusal, unqualifiedRefusal]
  expectRefusal "invalid root before reserved UID" "relative" maxBound [rootRefusal, unqualifiedRefusal]
  expectRefusal "root byte bound before zero UID" asciiOverflowRoot 0 [rootRefusal, unqualifiedRefusal]
  expectRefusal "root component bound before reserved UID" componentOverflowRoot maxBound [rootRefusal, unqualifiedRefusal]
  nativeIdentityCases
  nativeLeafMetadataCases

malformedRoots :: [(String, FilePath)]
malformedRoots =
  [ ("empty root", "")
  , ("relative root", "relative")
  , ("parent component", "/a/../b")
  , ("dot component", "/a/./b")
  , ("NUL in root", "/a" <> ['\NUL'] <> "b")
  , ("newline in root", "/a\nb")
  , ("tab in root", "/a\tb")
  , ("DEL in root", "/a" <> ['\DEL'] <> "b")
  , ("4097 ASCII bytes", asciiOverflowRoot)
  , ("4097 UTF-8 bytes below the character bound", utf8OverflowRoot)
  , ("65 root components", componentOverflowRoot)
  ]

asciiOverflowRoot, utf8OverflowRoot, componentOverflowRoot :: FilePath
asciiOverflowRoot = '/' : replicate 4096 'a'
-- Each U+00E9 occupies two UTF-8 bytes: one slash plus 2048 copies is
-- exactly 4097 bytes but only 2049 characters. An ASCII-only length check
-- cannot reject this control for the required reason.
utf8OverflowRoot = '/' : replicate 2048 '\x00E9'
componentOverflowRoot = concat (replicate 65 "/a")

nativeIdentityCases :: IO ()
#if defined(mingw32_HOST_OS)
nativeIdentityCases =
  fail "SeedCustodyPrerequisitesOracle: native POSIX UID observations are unavailable on this platform."
#else
nativeIdentityCases = do
  realUid <- getRealUserID
  effectiveUid <- getEffectiveUserID
  -- Native identities are observed independently through unix. A matching UID
  -- must refuse before platform, supervisor-floor, or filesystem diagnostics.
  expectRefusal
    "candidate equals native real UID"
    "/"
    (fromIntegral realUid)
    [candidateRefusal, unqualifiedRefusal]
  expectRefusal
    "candidate equals native effective UID"
    "/"
    (fromIntegral effectiveUid)
    [candidateRefusal, unqualifiedRefusal]
#endif

nativeLeafMetadataCases :: IO ()
#if defined(mingw32_HOST_OS)
nativeLeafMetadataCases =
  fail "SeedCustodyPrerequisitesOracle: POSIX leaf metadata fixtures are unavailable on this platform."
#else
nativeLeafMetadataCases = do
  repositoryRoot <- canonicalizePath "."
  let buildRoot = repositoryRoot </> ".build"
  physicalBuildRoot <- canonicalizePath buildRoot
  unless (physicalBuildRoot == buildRoot) $
    fail "SeedCustodyPrerequisitesOracle: fixture .build root must not resolve outside its physical repository path."
  withTempDirectory buildRoot "seed-custody-metadata-oracle-" $ \parent -> do
    let fifo = parent </> "fifo"
        target = parent </> "regular-target"
        symbolic = parent </> "symlink"
        directory = parent </> "directory"
    createNamedPipe fifo 0o600
    writeFile target "seed-custody-metadata-fixture\n"
    createSymbolicLink target symbolic
    createDirectory directory
    forM_ [("FIFO", fifo), ("symlink", symbolic), ("directory", directory)] $ \(label, path) -> do
      completed <- timeout (2 * 1000 * 1000) (seedCustodyFileMetadataDiagnostic path AcceptedSeed)
      case completed of
        Nothing -> fail ("SeedCustodyPrerequisitesOracle: " <> label <> ": metadata inspection timed out.")
        Just observed -> do
          let expected = leafKindRefusal path
          unless (observed == expected) $
            fail
              ( unlines
                  [ "SeedCustodyPrerequisitesOracle: " <> label <> ": exact leaf metadata refusal differs."
                  , "Expected: " <> show expected
                  , "Observed: " <> show observed
                  ]
              )
  -- Temporary fixtures are removed by withTempDirectory, including failures.
  -- Timeout and exceptions fail; neither is accepted as a file-kind refusal.
#endif

leafKindRefusal :: FilePath -> CheckResult
leafKindRefusal path =
  CheckResult
    { checkName = "seed-custody-file-metadata"
    , checkObservations =
        [ Observation "seed-custody.status" "NOT QUALIFIED"
        , Observation "seed-custody.scope" "leaf-metadata-only; ancestors-and-credentials-unverified"
        ]
    , checkFindings =
        [ Finding "SEED-CUSTODY-KIND" path "An authority input is not a regular file."
        , unqualifiedRefusal
        ]
    }

expectRefusal :: String -> FilePath -> Word32 -> [Finding] -> IO ()
expectRefusal label root candidateUid expected = do
  result <-
    seedCustodyPrerequisitesDiagnostic
      SeedCustodyRequest
        { seedCustodyRepositoryRoot = root
        , seedCustodyCandidateUid = candidateUid
        }
  -- Exceptions escape and fail the component. Neither an exception nor an
  -- arbitrary refusal is accepted as the specified prerequisite finding.
  unless (checkName result == "seed-custody-prerequisites") $
    fail ("SeedCustodyPrerequisitesOracle: " <> label <> ": unexpected check name " <> show (checkName result))
  unless (sort (checkFindings result) == sort expected) $
    fail
      ( unlines
          [ "SeedCustodyPrerequisitesOracle: " <> label <> ": exact refusal findings differ."
          , "Expected: " <> show expected
          , "Observed: " <> show (checkFindings result)
          ]
      )
  unless (length (filter (== unqualifiedRefusal) (checkFindings result)) == 1) $
    fail ("SeedCustodyPrerequisitesOracle: " <> label <> ": exactly one mandatory unqualified finding is required.")

rootRefusal :: Finding
rootRefusal =
  Finding
    "SEED-CUSTODY-ROOT"
    "<seed-custody>"
    "The protected repository root must be an absolute normalized path of at most 4096 UTF-8 bytes and 64 components, without control characters, dot, or parent components."

candidateRefusal :: Finding
candidateRefusal =
  Finding
    "SEED-CUSTODY-CANDIDATE"
    "<seed-custody>"
    "The candidate UID must be nonzero, non-reserved, and different from the supervisor real and effective UIDs."

unqualifiedRefusal :: Finding
unqualifiedRefusal =
  Finding
    "SEED-CUSTODY-NOT-QUALIFIED"
    "<seed-custody>"
    "Path and identity prerequisites do not qualify OS custody; candidate credential, inherited-authority, and denial probes remain required."
