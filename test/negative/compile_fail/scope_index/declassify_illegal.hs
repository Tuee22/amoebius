module DeclassifyIllegal where
import Amoebius.Scope.Flow
illegal :: FlowLabel scope -> FlowLabel scope
illegal privateValue = declassify privateValue
