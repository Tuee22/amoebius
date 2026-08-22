module RequestScopeEliminator where

import Amoebius.Scope.Index

good tenant subject membership =
  withRequestScope tenant subject membership (const ())
