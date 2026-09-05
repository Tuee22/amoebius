module ScopeRetagIllegal where
import Amoebius.Scope.Index
illegal tenantA subjectA membershipA tenantB subjectB membershipB =
  withRequestScope tenantA subjectA membershipA $ \scopeA ->
    withRequestScope tenantB subjectB membershipB $ \scopeB ->
      scopedValue (pairScoped (scoped scopeA ()) (scoped scopeB ()))
