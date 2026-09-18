
module Main (main) where

import Amoebius.Extension.Conformance.Gate
  ( AdmissionError
  , ConformanceVerdict
  , GatePlan
  , LinkSet
  , admitExtension
  )
import Amoebius.Extension.Declaration (ExtensionDeclaration)

main :: IO ()
main = putStrLn "extension-conformance-compile: PASS verdict-gated admission signature"



crossScopeAdmission
  :: GatePlan left
  -> ExtensionDeclaration left
  -> ConformanceVerdict right
  -> LinkSet left
  -> Either AdmissionError (LinkSet left)
crossScopeAdmission = admitExtension
