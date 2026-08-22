module SameScopePair where

import Amoebius.Scope.Index

good tenant subject membership =
  withRequestScope tenant subject membership $ \scope ->
    scopedValue (pairScoped (scoped scope ()) (scoped scope ()))
