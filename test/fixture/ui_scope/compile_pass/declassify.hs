module ScopePreservingFlow where

import Amoebius.Scope.Flow

good :: FlowLabel scope -> FlowLabel scope -> Either FlowError (CanFlowTo scope)
good = checkFlow
