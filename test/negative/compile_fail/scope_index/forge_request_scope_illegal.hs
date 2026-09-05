module ForgeRequestScopeIllegal where
import Amoebius.Scope.Index
illegal :: Tenant -> Subject -> Membership -> RequestScope scope
illegal tenant subject membership = RequestScope tenant subject membership
