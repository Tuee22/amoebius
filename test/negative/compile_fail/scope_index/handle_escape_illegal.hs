module HandleEscapeIllegal where
import Amoebius.Test.ScopeFixture qualified as FixtureAuthority
import Amoebius.Scope.Index
illegal tenant subject membership owner resource =
  FixtureAuthority.withFixtureScope tenant subject membership $ \scope ->
    resolveOwned scope owner resource
