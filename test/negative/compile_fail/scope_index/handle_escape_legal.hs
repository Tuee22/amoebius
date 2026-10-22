module HandleEscapeLegal where
import Amoebius.Test.ScopeFixture qualified as FixtureAuthority
import Amoebius.Scope.Index
legal tenant subject membership owner resource =
  FixtureAuthority.withFixtureScope tenant subject membership $ \scope ->
    fmap handleKind (resolveOwned scope owner resource)
