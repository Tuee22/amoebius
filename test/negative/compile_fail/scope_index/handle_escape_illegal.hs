module HandleEscapeIllegal where
import Amoebius.Scope.Index
illegal tenant subject membership owner resource =
  withRequestScope tenant subject membership $ \scope ->
    resolveOwned scope owner resource
