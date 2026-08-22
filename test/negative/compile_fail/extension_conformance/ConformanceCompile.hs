{-# LANGUAGE CPP #-}

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

#ifdef EXTENSION_CONFORMANCE_TEST_FORGE_VERDICT
forgeVerdict :: ConformanceVerdict scope
forgeVerdict = ConformanceVerdict "declaration" "core" "suite" "passed" "digest"
#endif

#ifdef EXTENSION_CONFORMANCE_TEST_UNSEALED_ADMISSION
unsealedAdmission
  :: GatePlan scope
  -> ExtensionDeclaration scope
  -> LinkSet scope
  -> Either AdmissionError (LinkSet scope)
unsealedAdmission plan declaration linkSet = admitExtension plan declaration linkSet
#endif

#ifdef EXTENSION_CONFORMANCE_TEST_CROSS_SCOPE_VERDICT
crossScopeAdmission
  :: GatePlan left
  -> ExtensionDeclaration left
  -> ConformanceVerdict right
  -> LinkSet left
  -> Either AdmissionError (LinkSet left)
crossScopeAdmission = admitExtension
#endif
