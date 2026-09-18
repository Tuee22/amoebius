{-# LANGUAGE OverloadedStrings #-}

-- | Contained acquisition from the GenesisTrust pins (phase_01, Sprint 1.1).
--
-- Verify the seven pinned files against their sizes and digests, check that the
-- publisher manifests agree with the pins, verify the publisher signatures with
-- the operator-supplied keyring, extract the two archives into an absent root,
-- and record the compiler and package-tool identities observed there. Two
-- acquisitions from the same pins must agree; the refusals are named so the
-- oracle can restate each one.
module Amoebius.Toolchain.Acquire
  ( Acquisition (..)
  , AcquisitionRefusal (..)
  , ChildRecord (..)
  , SignatureResult (..)
  , VerifiedPins (..)
  , acquire
  , acquireTwice
  , agreement
  , locateInputs
  , manifestEntry
  , parseManifest
  , removeAcquisition
  , renderAcquisition
  , renderChild
  , renderRefusal
  , renderSignature
  , hexEncode
  , sha256Bytes
  , sha256File
  , signedRoles
  , spawnChild
  , verifyPins
  , verifyPinsWith
  , verifySignatures
  , writeAcquisitionReceipt
  ) where

import Amoebius.Toolchain.Pins
import Control.Monad (forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.Either (lefts, rights)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , doesPathExist
  , findExecutable
  , getFileSize
  , makeAbsolute
  , pathIsSymbolicLink
  , removePathForcibly
  )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, takeDirectory, (</>))
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data AcquisitionRefusal
  = AmbientNetworkRefused Text
  | PinMissing FilePath
  | PinNotRegular FilePath
  | PinSizeMismatch FilePath Integer Integer
  | PinDigestMismatch FilePath Text Text
  | ManifestEntryAbsent FilePath FilePath
  | ManifestDisagrees FilePath Text Text
  | KeyringMissing FilePath
  | SignatureRejected FilePath Text
  | RootNotAbsent FilePath
  | ExtractionFailed FilePath Text
  | ToolMissing FilePath
  | ToolIdentityMismatch Text Text Text
  | ToolVersionMismatch Text Text Text
  | AcquisitionsDisagree Text Text Text
  deriving (Eq, Ord, Show)

renderRefusal :: AcquisitionRefusal -> Text
renderRefusal refusal = case refusal of
  AmbientNetworkRefused source -> "AmbientNetworkRefused: " <> source
  PinMissing name -> "PinMissing: " <> Text.pack name
  PinNotRegular name -> "PinNotRegular: " <> Text.pack name
  PinSizeMismatch name expected observed -> "PinSizeMismatch: " <> Text.pack name <> " expected=" <> showText expected <> " observed=" <> showText observed
  PinDigestMismatch name expected observed -> "PinDigestMismatch: " <> Text.pack name <> " expected=" <> expected <> " observed=" <> observed
  ManifestEntryAbsent manifest archive -> "ManifestEntryAbsent: " <> Text.pack manifest <> " lacks " <> Text.pack archive
  ManifestDisagrees archive claimed observed -> "ManifestDisagrees: " <> Text.pack archive <> " claimed=" <> claimed <> " observed=" <> observed
  KeyringMissing path -> "KeyringMissing: " <> Text.pack path
  SignatureRejected name detail -> "SignatureRejected: " <> Text.pack name <> " " <> detail
  RootNotAbsent path -> "RootNotAbsent: " <> Text.pack path
  ExtractionFailed name detail -> "ExtractionFailed: " <> Text.pack name <> " " <> detail
  ToolMissing path -> "ToolMissing: " <> Text.pack path
  ToolIdentityMismatch tool expected observed -> "ToolIdentityMismatch: " <> tool <> " expected=" <> expected <> " observed=" <> observed
  ToolVersionMismatch tool expected observed -> "ToolVersionMismatch: " <> tool <> " expected=" <> expected <> " observed=" <> observed
  AcquisitionsDisagree field first second -> "AcquisitionsDisagree: " <> field <> " " <> first <> " /= " <> second

-- | The pins as observed: every file present at its pinned size and digest, and
-- the digest each publisher manifest claims for each archive.
data VerifiedPins = VerifiedPins
  { verifiedDirectory :: FilePath
  , verifiedObserved :: [(Pin, Text)]
  , verifiedClaimed :: [(PinRole, Text)]
  }
  deriving (Eq, Show)

-- | A child process the acquisition started: the tool as named, the executable
-- it resolved to, that executable's digest, its arguments, and its exit.
data ChildRecord = ChildRecord
  { childTool :: Text
  , childExecutable :: FilePath
  , childDigest :: Text
  , childArgv :: [Text]
  , childExit :: Int
  }
  deriving (Eq, Show)

renderChild :: ChildRecord -> Text
renderChild child = Text.intercalate " " [childTool child, Text.pack (childExecutable child), childDigest child, "exit=" <> showText (childExit child)]

-- | One extracted toolchain: where it lives, the two executables, and the
-- identities observed from their bytes and their own version reports.
data Acquisition = Acquisition
  { acquisitionRoot :: FilePath
  , acquisitionCompiler :: FilePath
  , acquisitionPackageTool :: FilePath
  , acquisitionCompilerDigest :: Text
  , acquisitionPackageToolDigest :: Text
  , acquisitionCompilerVersion :: Text
  , acquisitionPackageToolVersion :: Text
  , acquisitionTarget :: Text
  , acquisitionChildren :: [ChildRecord]
  }
  deriving (Eq, Show)

hexEncode :: ByteString.ByteString -> Text
hexEncode bytes = Text.pack (concatMap hexByte (ByteString.unpack bytes))
 where
  hexByte byte = [intToDigit (fromIntegral (byte `div` 16)), intToDigit (fromIntegral (byte `mod` 16))]

sha256Bytes :: ByteString.ByteString -> Text
sha256Bytes = hexEncode . SHA256.hash

sha256File :: FilePath -> IO Text
sha256File path = hexEncode . SHA256.hashlazy <$> LazyByteString.readFile path

-- | The inputs directory that owns a path: the nearest ancestor (the path
-- itself included) beneath which @.build/bootstrap-inputs@ exists. A validator
-- run copy has no inputs of its own, so it resolves to the repository that owns
-- the run root.
locateInputs :: FilePath -> IO (Maybe FilePath)
locateInputs start = makeAbsolute start >>= climb
 where
  climb directory = do
    let candidate = directory </> inputsDirectory
    present <- doesDirectoryExist candidate
    if present
      then pure (Just candidate)
      else
        let parent = takeDirectory directory
         in if parent == directory then pure Nothing else climb parent

-- | A source is admissible only as a local inputs directory. A URL or any
-- location that is not the pinned inputs directory is refused by name: the
-- acquisition never reads the network or an ambient host location.
admissibleSource :: FilePath -> Maybe AcquisitionRefusal
admissibleSource directory
  | "://" `Text.isInfixOf` Text.pack directory = Just (AmbientNetworkRefused (Text.pack directory))
  | not (Text.pack inputsDirectory `Text.isSuffixOf` Text.pack directory) = Just (AmbientNetworkRefused (Text.pack directory))
  | otherwise = Nothing

verifyPins :: FilePath -> IO (Either [AcquisitionRefusal] VerifiedPins)
verifyPins directory = verifyPinsWith directory []

-- | Verify with manifest overrides: a manifest path substituted for a pinned
-- manifest name is read instead of the pinned file, so a runner-perturbed copy
-- is compared in place of the original and refused where it disagrees.
verifyPinsWith :: FilePath -> [(PinRole, FilePath)] -> IO (Either [AcquisitionRefusal] VerifiedPins)
verifyPinsWith directory overrides = case admissibleSource directory of
  Just refusal -> pure (Left [refusal])
  Nothing -> do
    observed <- forM genesisPins $ \pin -> do
      let path = fromMaybe (directory </> pinName pin) (lookup (pinRole pin) overrides)
      present <- doesFileExist path
      if not present
        then pure (Left [PinMissing (pinName pin)])
        else do
          link <- pathIsSymbolicLink path
          if link
            then pure (Left [PinNotRegular (pinName pin)])
            else do
              size <- getFileSize path
              digest <- sha256File path
              pure
                ( case [PinSizeMismatch (pinName pin) (pinBytes pin) size | size /= pinBytes pin] <> [PinDigestMismatch (pinName pin) (pinSha256 pin) digest | digest /= pinSha256 pin] of
                    [] -> Right (pin, digest)
                    problems -> Left problems
                )
    let refusals = concat (lefts observed)
        good = rights observed
    claimed <- forM [CompilerArchive, PackageToolArchive] $ \role ->
      case (pinFor role, manifestNameFor role) of
        (Just archive, Just manifestName) -> do
          let manifestRole = if role == CompilerArchive then CompilerManifest else PackageToolManifest
              path = fromMaybe (directory </> manifestName) (lookup manifestRole overrides)
          present <- doesFileExist path
          if not present
            then pure (Left (ManifestEntryAbsent manifestName (pinName archive)))
            else do
              contents <- TextIO.readFile path
              archiveDigest <- sha256File (fromMaybe (directory </> pinName archive) (lookup role overrides))
              pure $ case manifestEntry (pinName archive) contents of
                Nothing -> Left (ManifestEntryAbsent manifestName (pinName archive))
                Just claimedDigest
                  | claimedDigest /= archiveDigest -> Left (ManifestDisagrees (pinName archive) claimedDigest archiveDigest)
                  | otherwise -> Right (role, claimedDigest)
        _ -> pure (Left (ManifestEntryAbsent "manifest" "archive"))
    pure $ case refusals <> lefts claimed of
      [] -> Right VerifiedPins {verifiedDirectory = directory, verifiedObserved = good, verifiedClaimed = rights claimed}
      problems -> Left problems

-- | A publisher manifest: @<digest>  <name>@ lines, names possibly prefixed @./@.
-- The claimed digest is taken as written, so a rewritten claim is reported as
-- the claim that disagrees rather than as an absent entry.
parseManifest :: Text -> [(FilePath, Text)]
parseManifest contents =
  [ (Text.unpack (stripDot name), digest)
  | line <- Text.lines contents
  , (digest : rest) <- [Text.words line]
  , name <- take 1 rest
  ]
 where
  stripDot name = fromMaybe name (Text.stripPrefix "./" name)

manifestEntry :: FilePath -> Text -> Maybe Text
manifestEntry name contents = lookup name (parseManifest contents)

data SignatureResult
  = SignatureGood FilePath Text
  | SignatureRefused AcquisitionRefusal
  deriving (Eq, Show)

renderSignature :: SignatureResult -> Text
renderSignature result = case result of
  SignatureGood name signer -> "good " <> Text.pack name <> " " <> signer
  SignatureRefused refusal -> renderRefusal refusal

-- | The signed files: the compiler archive and both manifests.
signedRoles :: [PinRole]
signedRoles = [CompilerArchive, CompilerManifest, PackageToolManifest]

-- | Verify each signature with @gpgv@ against the keyring beside the pins. The
-- keyring is trusted, not authenticated; a missing keyring is a named refusal.
verifySignatures :: FilePath -> IO ([SignatureResult], [ChildRecord])
verifySignatures directory = do
  let keyring = directory </> keyringFile
  present <- doesFileExist keyring
  if not present
    then pure ([SignatureRefused (KeyringMissing keyring)], [])
    else do
      results <- forM signedRoles $ \role -> case (pinFor role, signatureNameFor role) of
        (Just pin, Just signature) -> do
          (child, _, err) <- spawnChild directory "gpgv" ["--keyring", keyring, directory </> signature, directory </> pinName pin]
          let goodLine = [Text.strip (Text.drop 1 (snd (Text.breakOn ":" line))) | line <- Text.lines (Text.pack err), "Good signature" `Text.isInfixOf` line]
          pure
            ( if childExit child == 0 && not (null goodLine)
                then SignatureGood (pinName pin) (Text.unwords (take 1 goodLine))
                else SignatureRefused (SignatureRejected (pinName pin) (Text.strip (Text.pack (take 160 err))))
            , child
            )
        _ -> pure (SignatureRefused (SignatureRejected "signature" "role has no signature"), ChildRecord "gpgv" "" "" [] 1)
      pure (map fst results, map snd results)

-- | Start one child by name, recording the executable it resolved to and that
-- executable's digest. A tool that does not resolve is recorded with exit 127.
spawnChild :: FilePath -> String -> [String] -> IO (ChildRecord, String, String)
spawnChild workingDirectory tool arguments = do
  resolved <- if isAbsolute tool then pure (Just tool) else findExecutable tool
  case resolved of
    Nothing -> pure (ChildRecord (Text.pack tool) "" "" (map Text.pack arguments) 127, "", "executable not found: " <> tool)
    Just executable -> do
      digest <- sha256File executable
      (exit, out, err) <- readCreateProcessWithExitCode ((proc executable arguments) {cwd = Just workingDirectory}) ""
      let code = case exit of
            ExitSuccess -> 0
            ExitFailure n -> n
      pure (ChildRecord (Text.pack tool) executable digest (map Text.pack arguments) code, out, err)

-- | Extract the pinned archives into an absent root and observe the tools.
acquire :: VerifiedPins -> FilePath -> IO (Either [AcquisitionRefusal] Acquisition)
acquire pins root = do
  exists <- doesPathExist root
  if exists
    then pure (Left [RootNotAbsent root])
    else do
      let compilerDir = root </> "compiler"
          packageToolDir = root </> "package-tool"
      extractions <- forM [(CompilerArchive, compilerDir), (PackageToolArchive, packageToolDir)] $ \(role, target) -> do
        createDirectoryIfMissing True target
        case pinFor role of
          Nothing -> pure (Left (PinMissing (renderRoleName role)), Nothing)
          Just pin -> do
            (child, _, err) <- spawnChild root "tar" ["-xJf", verifiedDirectory pins </> pinName pin, "-C", target]
            pure (if childExit child == 0 then Right () else Left (ExtractionFailed (pinName pin) (Text.strip (Text.pack (take 160 err)))), Just child)
      let extractionChildren = [child | (_, Just child) <- extractions]
      case lefts (map fst extractions) of
        (problem : more) -> pure (Left (problem : more))
        [] -> do
          let compilerExe = compilerDir </> toolExecutable compilerIdentity
              packageToolExe = packageToolDir </> toolExecutable packageToolIdentity
          compilerPresent <- doesFileExist compilerExe
          packageToolPresent <- doesFileExist packageToolExe
          case [ToolMissing compilerExe | not compilerPresent] <> [ToolMissing packageToolExe | not packageToolPresent] of
            (problem : more) -> pure (Left (problem : more))
            [] -> do
              compilerDigest <- sha256File compilerExe
              packageToolDigest <- sha256File packageToolExe
              (versionChild, compilerVersion, _) <- spawnChild root compilerExe ["--numeric-version"]
              (infoChild, info, _) <- spawnChild root compilerExe ["--info"]
              (packageChild, packageToolVersion, _) <- spawnChild root packageToolExe ["--numeric-version"]
              let target = fromMaybe "unknown" (lookup "Target platform" (parseInfo (Text.pack info)))
                  observedCompilerVersion = Text.strip (Text.pack compilerVersion)
                  observedPackageToolVersion = Text.strip (Text.pack packageToolVersion)
                  problems =
                    [ToolIdentityMismatch (toolName compilerIdentity) (toolSha256 compilerIdentity) compilerDigest | compilerDigest /= toolSha256 compilerIdentity]
                      <> [ToolIdentityMismatch (toolName packageToolIdentity) (toolSha256 packageToolIdentity) packageToolDigest | packageToolDigest /= toolSha256 packageToolIdentity]
                      <> [ToolVersionMismatch (toolName compilerIdentity) (toolVersion compilerIdentity) observedCompilerVersion | observedCompilerVersion /= toolVersion compilerIdentity]
                      <> [ToolVersionMismatch (toolName packageToolIdentity) (toolVersion packageToolIdentity) observedPackageToolVersion | observedPackageToolVersion /= toolVersion packageToolIdentity]
              pure $ case problems of
                (problem : more) -> Left (problem : more)
                [] ->
                  Right
                    Acquisition
                      { acquisitionRoot = root
                      , acquisitionCompiler = compilerExe
                      , acquisitionPackageTool = packageToolExe
                      , acquisitionCompilerDigest = compilerDigest
                      , acquisitionPackageToolDigest = packageToolDigest
                      , acquisitionCompilerVersion = observedCompilerVersion
                      , acquisitionPackageToolVersion = observedPackageToolVersion
                      , acquisitionTarget = target
                      , acquisitionChildren = extractionChildren <> [versionChild, infoChild, packageChild]
                      }
 where
  renderRoleName role = Text.unpack (renderPinRole role)

-- | @ghc --info@ as key/value pairs.
parseInfo :: Text -> [(Text, Text)]
parseInfo info =
  [ (unquote key, unquote value)
  | line <- Text.lines info
  , let trimmed = Text.dropWhile (`elem` (" ,[" :: String)) line
  , "(" `Text.isPrefixOf` trimmed
  , let inner = Text.dropEnd 1 (Text.drop 1 (Text.dropWhileEnd (`elem` ("]," :: String)) trimmed))
  , (key, rest) <- [Text.breakOn "," inner]
  , not (Text.null rest)
  , let value = Text.drop 1 rest
  ]
 where
  unquote = Text.dropAround (== '"') . Text.strip

acquireTwice :: VerifiedPins -> FilePath -> FilePath -> IO (Either [AcquisitionRefusal] (Acquisition, Acquisition))
acquireTwice pins firstRoot secondRoot = do
  first <- acquire pins firstRoot
  case first of
    Left problems -> pure (Left problems)
    Right a -> do
      second <- acquire pins secondRoot
      pure $ case second of
        Left problems -> Left problems
        Right b -> case agreement a b of
          [] -> Right (a, b)
          problems -> Left problems

-- | Two acquisitions agree when every identity they observed is equal.
agreement :: Acquisition -> Acquisition -> [AcquisitionRefusal]
agreement a b =
  [ AcquisitionsDisagree field (project a) (project b)
  | (field, project) <-
      [ ("compiler.sha256", acquisitionCompilerDigest)
      , ("package-tool.sha256", acquisitionPackageToolDigest)
      , ("compiler.version", acquisitionCompilerVersion)
      , ("package-tool.version", acquisitionPackageToolVersion)
      , ("compiler.target", acquisitionTarget)
      ]
  , project a /= project b
  ]

renderAcquisition :: Acquisition -> [(Text, Text)]
renderAcquisition acquisition =
  [ ("acquisition.root", Text.pack (acquisitionRoot acquisition))
  , ("compiler.executable", Text.pack (acquisitionCompiler acquisition))
  , ("compiler.sha256", acquisitionCompilerDigest acquisition)
  , ("compiler.version", acquisitionCompilerVersion acquisition)
  , ("compiler.target", acquisitionTarget acquisition)
  , ("package-tool.executable", Text.pack (acquisitionPackageTool acquisition))
  , ("package-tool.sha256", acquisitionPackageToolDigest acquisition)
  , ("package-tool.version", acquisitionPackageToolVersion acquisition)
  ]
    <> [("child." <> showText index, renderChild child) | (index, child) <- zip [1 :: Int ..] (acquisitionChildren acquisition)]

-- | The typed receipt, rendered beneath the acquisition root and never tracked.
writeAcquisitionReceipt :: Acquisition -> IO FilePath
writeAcquisitionReceipt acquisition = do
  let path = acquisitionRoot acquisition </> "receipt.tsv"
  createDirectoryIfMissing True (acquisitionRoot acquisition)
  TextIO.writeFile path (Text.unlines [key <> "\t" <> value | (key, value) <- renderAcquisition acquisition])
  pure path

-- | Scoped cleanup: the extracted trees go, the receipt stays.
removeAcquisition :: Acquisition -> IO ()
removeAcquisition acquisition = do
  removePathForcibly (acquisitionRoot acquisition </> "compiler")
  removePathForcibly (acquisitionRoot acquisition </> "package-tool")

showText :: Show value => value -> Text
showText = Text.pack . show
