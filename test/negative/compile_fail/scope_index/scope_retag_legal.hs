module ScopeRetagLegal where
import Amoebius.Scope.Index
legal tenant subject membership =
  withRequestScope tenant subject membership $ \scope ->
    scopedValue (pairScoped (scoped scope ()) (scoped scope ()))
