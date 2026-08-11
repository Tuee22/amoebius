module Phase49CatalogPositive where

import Infernix.Adapter.Engine (CatalogIdentity, tinyLlamaCpuCatalog)

selected :: CatalogIdentity
selected = tinyLlamaCpuCatalog
