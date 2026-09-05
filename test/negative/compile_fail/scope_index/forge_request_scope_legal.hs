module ForgeRequestScopeLegal where
import Amoebius.Scope.Index
legal tenant subject membership =
  withRequestScope tenant subject membership (const ())
