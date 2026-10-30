-- | Runner stage 4: perturb an input, observe the shipped binary, and recover its nonce.
module Amoebius.Validation.Runner.Binary
  ( BinaryOutcome (..), Nonce (..), SpineOutcome (..), freshNonce, perturbInput, runBinaryFact, runSpineFact ) where
import Amoebius.Validation.Authority.Core
