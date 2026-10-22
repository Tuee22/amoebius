module ScopeRetagIllegal where
import Amoebius.Test.ScopeFixture qualified as FixtureAuthority
import Amoebius.Scope.Index
illegal tenantA subjectA membershipA tenantB subjectB membershipB =
  FixtureAuthority.withFixtureScope tenantA subjectA membershipA $ \scopeA ->
    FixtureAuthority.withFixtureScope tenantB subjectB membershipB $ \scopeB ->
      scopedValue (pairScoped (scoped scopeA ()) (scoped scopeB ()))
