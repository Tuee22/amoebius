-- | The ordinary catalog command projects the canonical CPU recipe. The
-- recipe module owns declarations; this module owns no authored inventory.
module Amoebius.Image.CanonicalBakeCatalog (canonicalBakeCatalog) where

import Amoebius.Image.Bake (bakeCatalog)
import Amoebius.Image.BakeInventory (BakeCatalog)
import Amoebius.Image.Recipe (canonicalRecipe)

canonicalBakeCatalog :: BakeCatalog
canonicalBakeCatalog = bakeCatalog canonicalRecipe
