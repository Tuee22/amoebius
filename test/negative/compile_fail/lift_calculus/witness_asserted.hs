{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the witness pair: evidence written down rather than observed.
--
-- This is the step section 7 forbids — one that claims to have crossed a boundary it did
-- not cross. It is unspellable because 'Amoebius.Calculus.Lift.Witness' exports the type
-- and not its constructor, so what 'Witness' names here is a type where a term belongs
-- and the compiler says exactly that: an illegal term-level use of a type constructor.
-- The claim is about the module boundary and so is the diagnostic.
module LiftCalculusWitnessAsserted where

import Amoebius.Calculus.Lift.Layer (Layer (..))
import Amoebius.Calculus.Lift.Witness (Witness)

-- The rejected program: nothing was observed, and the witness exists anyway.
entering :: Witness 'OnHost 'InFrame
entering = Witness "asserted"
