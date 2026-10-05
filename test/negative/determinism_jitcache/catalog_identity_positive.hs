module Phase48CatalogIdentityPositive where

import Amoebius.Jit.Resolver (JitEngine (LlamaCppCpu))

selected :: JitEngine
selected = LlamaCppCpu
