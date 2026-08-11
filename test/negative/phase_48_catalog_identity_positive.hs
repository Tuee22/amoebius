module Phase48CatalogIdentityPositive where

import Amoebius.Jit.Resolver (EngineRuntime (LlamaCppCpu))

selected :: EngineRuntime
selected = LlamaCppCpu
