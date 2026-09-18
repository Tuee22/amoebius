
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


unsealedAdmission
  :: GatePlan scope
  -> ExtensionDeclaration scope
  -> LinkSet scope
  -> Either AdmissionError (LinkSet scope)
unsealedAdmission plan declaration linkSet = admitExtension plan declaration linkSet

