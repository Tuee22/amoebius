{-# LANGUAGE OverloadedStrings #-}

-- Product-owned bounded input variants. Expectations live in the oracle.
module Amoebius.Dsl.Examples.Extensions.ConformanceInputs
  ( ConformanceInput (..), conformanceInputs, conformanceInputName
  , LawFault (..), lawFaultInputs, lawFaultName ) where

import Data.Text (Text)

data ConformanceInput
  = LegalModel | MissingLaw | DuplicateLaw | FailedLaw | MissingCompiler
  | MissingGeneratedFile | MissingCase | DuplicateCase | FailedCase
  | WrongDeclaration | WrongCore | DuplicateAdmission
  | MissingRefusalProbe | MissingNamespaceProbe | MissingAuthorityProbe
  deriving (Eq, Ord, Enum, Bounded, Show)

conformanceInputs :: [ConformanceInput]
conformanceInputs = [minBound .. maxBound]

conformanceInputName :: ConformanceInput -> Text
conformanceInputName input = case input of
  LegalModel -> "legal"
  MissingLaw -> "missing-law"
  DuplicateLaw -> "duplicate-law"
  FailedLaw -> "failed-law"
  MissingCompiler -> "missing-compiler-premise"
  MissingGeneratedFile -> "missing-generated-file"
  MissingCase -> "missing-case"
  DuplicateCase -> "duplicate-case"
  FailedCase -> "failed-case"
  WrongDeclaration -> "wrong-declaration"
  WrongCore -> "wrong-core"
  DuplicateAdmission -> "duplicate-admission"
  MissingRefusalProbe -> "missing-refusal-probe"
  MissingNamespaceProbe -> "missing-namespace-probe"
  MissingAuthorityProbe -> "missing-authority-probe"

data LawFault = L1Fault | L2Fault | L3Fault | L4Fault | L5Fault
  | C1Fault | C2Fault | C3Fault | C4Fault | C5Fault | C6Fault | C7Fault
  | S1Fault | S2Fault | S3Fault | S4Fault | S5Fault | S6Fault
  deriving (Eq, Ord, Enum, Bounded, Show)

lawFaultInputs :: [LawFault]
lawFaultInputs = [minBound .. maxBound]

lawFaultName :: LawFault -> Text
lawFaultName input = case input of
  L1Fault -> "L1"
  L2Fault -> "L2"
  L3Fault -> "L3"
  L4Fault -> "L4"
  L5Fault -> "L5"
  C1Fault -> "C1"
  C2Fault -> "C2"
  C3Fault -> "C3"
  C4Fault -> "C4"
  C5Fault -> "C5"
  C6Fault -> "C6"
  C7Fault -> "C7"
  S1Fault -> "S1"
  S2Fault -> "S2"
  S3Fault -> "S3"
  S4Fault -> "S4"
  S5Fault -> "S5"
  S6Fault -> "S6"
