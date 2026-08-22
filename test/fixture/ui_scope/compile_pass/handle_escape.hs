module HandleStaysInScope where

import Amoebius.Scope.Index

good tenant subject membership owner resource =
  withRequestScope tenant subject membership $ \scope ->
    fmap handleKind (resolveOwned scope owner resource)
