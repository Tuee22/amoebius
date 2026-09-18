{-# LANGUAGE OverloadedStrings #-}

-- | Closure-based predecessor chaining (gate integrity section M.6). The
-- predecessor's closure is the digest of every source file in the stanzas its
-- specification names and their transitive internal dependencies, plus the
-- verifier and governance digests. An edit outside the closure keeps the receipt;
-- an edit inside it reopens the predecessor.
module Amoebius.Validation.Compatibility
  ( closureDigest
  , closureStanzas
  ) where

import Amoebius.Validation.GateSpec (GateSpec, gateSubjects)
import Amoebius.Validation.Runner.Observer (sha256Hex)
import Amoebius.Validation.Runner.Spec (PackageGraph (..), VerifiedSpec (..))
import Control.Monad (filterM)
import Data.List (isSuffixOf, sort)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath (makeRelative, (</>))

-- | The subject stanzas and everything they depend on inside the package.
closureStanzas :: PackageGraph -> VerifiedSpec -> Set Text
closureStanzas graph verified = close Set.empty (Map.elems (verifiedStanzaOf verified))
 where
  close seen [] = seen
  close seen (stanza : rest)
    | Set.member stanza seen = close seen rest
    | otherwise =
        let deps = maybe Set.empty (\(_, internal, _) -> internal) (Map.lookup stanza (graphLibraries graph))
         in close (Set.insert stanza seen) (Set.toList deps <> rest)

-- | The closure digest for a verified specification against the tree.
closureDigest :: FilePath -> PackageGraph -> VerifiedSpec -> Text -> Text -> IO Text
closureDigest root graph verified verifier governance = do
  let stanzas = closureStanzas graph verified
      directories = Set.toList (Set.fromList (concat [dirs | stanza <- Set.toList stanzas, Just (_, _, dirs) <- [Map.lookup stanza (graphLibraries graph)]]))
  files <- concat <$> mapM (haskellFilesUnder root) directories
  digests <- mapM (\file -> (\contents -> Text.pack file <> "\t" <> sha256Hex contents) <$> TextIO.readFile (root </> file)) (sort files)
  pure (sha256Hex (Text.unlines (digests <> ["verifier\t" <> verifier, "governance\t" <> governance, "subjects\t" <> Text.pack (show (gateSubjects (verifiedSpec verified)))])))

haskellFilesUnder :: FilePath -> FilePath -> IO [FilePath]
haskellFilesUnder root relative = do
  exists <- doesDirectoryExist (root </> relative)
  if not exists then pure [] else map (makeRelative root) <$> walk (root </> relative)
 where
  walk directory = do
    names <- listDirectory directory
    directories <- filterM (doesDirectoryExist . (directory </>)) names
    nested <- concat <$> mapM (walk . (directory </>)) directories
    files <- filterM (doesFileExist . (directory </>)) [name | name <- names, ".hs" `isSuffixOf` name]
    pure ([directory </> name | name <- files] <> nested)

_unusedSpec :: GateSpec -> GateSpec
_unusedSpec = id
