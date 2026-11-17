-- | Confine preparation to physical directories inside the source tree.
module Owner (preparationOwner) where

import Control.Monad (unless)
import System.Directory (canonicalizePath, createDirectoryIfMissing)
import System.FilePath (equalFilePath, (</>))

-- Check each parent before creating the next one so a redirected parent does
-- not cause the preparation command to create files outside the source tree.
preparationOwner :: FilePath -> IO FilePath
preparationOwner source = do
  root <- canonicalizePath source
  let build = root </> ".build"
      owner = build </> "proto"
  createDirectoryIfMissing True build
  actualBuild <- canonicalizePath build
  unless (equalFilePath actualBuild build) (ioError (userError "build directory escapes source tree"))
  createDirectoryIfMissing True owner
  actualOwner <- canonicalizePath owner
  unless (equalFilePath actualOwner owner) (ioError (userError "wire generation directory escapes source tree"))
  pure owner
