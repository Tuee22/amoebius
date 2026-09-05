module DeclassifyLegal where
import Amoebius.Scope.Flow
legal :: FlowLabel scope -> FlowLabel scope -> Either FlowError (CanFlowTo scope)
legal = checkFlow
