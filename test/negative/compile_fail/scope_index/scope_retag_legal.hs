module ScopeRetagLegal where
import Amoebius.Test.ScopeFixture qualified as FixtureAuthority
import Amoebius.Scope.Index
legal tenant subject membership =
  FixtureAuthority.withFixtureScope tenant subject membership $ \scope ->
    scopedValue (pairScoped (scoped scope ()) (scoped scope ()))
