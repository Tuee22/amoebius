module ExtensionDeclarationMutants
  ( omitDeclaredRecipe
  ) where

import Amoebius.Extension.Declaration
  ( DeclaredComponent
  , ExtensionDeclaration
  )
import Data.Set (Set)
import Data.Set qualified as Set

-- | Seeded omission: the derived artifact reader forgets the declaration's recipe.
omitDeclaredRecipe :: ExtensionDeclaration scope -> Set DeclaredComponent
omitDeclaredRecipe _ = Set.empty
