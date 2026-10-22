{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- | Trusted compile-time wire. Contributions cannot import this module or
-- splice code. Each factory name is bound to the actual complete checked
-- source closure, whose bytes are compiler dependencies of the linked value.
module Amoebius.Extension.LinkSeal (admitContribution) where

import Amoebius.Extension.AstCheck
import Amoebius.Extension.SourceClosure
import Control.Monad (unless)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text qualified as Text
import Language.Haskell.TH (Exp, Name, Q, nameBase, nameModule, reify, varE)
import Language.Haskell.TH.Syntax (addDependentFile, getPackageRoot, lift, runIO)
import System.FilePath ((</>))

admitContribution :: Name -> Q Exp
admitContribution factory = do
  repository <- getPackageRoot
  result <- runIO (readContributionClosure repository)
  seal <- either (fail . Text.unpack . renderContributionRefusal) pure result
  let modules = map snd (NonEmpty.toList (checkedSourceModules seal))
      admitted = case nameModule factory of
        Just name -> Text.pack name `elem` modules
          && "Amoebius.Extension.Contributed." `Text.isPrefixOf` Text.pack name
          && nameBase factory == "contribution"
        Nothing -> False
  unless admitted (fail "UnadmittedContributionFactory")
  _ <- reify factory
  mapM_ (addDependentFile . (repository </>) . (contributionRoot </>) . fst)
    (NonEmpty.toList (checkedSourceFiles seal))
  sources <- lift [(path, Text.unpack body) | (path, body) <- NonEmpty.toList (checkedSourceFiles seal)]
  -- The constructor stays private. This expression re-derives the seal from
  -- the exact source bytes admitted above, then applies the reified factory.
  [| case NonEmpty.nonEmpty (map (\(path, body) -> (path, Text.pack body)) $(pure sources)) of
       Nothing -> error "empty admitted contribution closure"
       Just inputs -> case checkExtensionSources inputs of
         Rejected _ -> error "compiled admitted contribution no longer parses"
         Accepted checked -> $(varE factory) checked
   |]
