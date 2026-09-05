module HandleEscapeLegal where
import Amoebius.Scope.Index
legal tenant subject membership owner resource =
  withRequestScope tenant subject membership $ \scope ->
    fmap handleKind (resolveOwned scope owner resource)
