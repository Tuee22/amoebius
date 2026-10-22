-- | Private product wire. The public graph exposes only the subject type.
-- Dsl.Spec produces it by selecting an actual member of a refined AppSpec;
-- contributed code cannot import this private module or its constructor.
module Amoebius.Extension.BindingSubject.Internal
  ( BindingSubject (..), subjectApplication, subjectNeed, subjectCapability ) where

import Amoebius.Vocabulary (CapabilityArm)
import Data.Text (Text)

data BindingSubject = BindingSubject !Text !Text !CapabilityArm

subjectApplication :: BindingSubject -> Text
subjectApplication (BindingSubject application _ _) = application

subjectNeed :: BindingSubject -> Text
subjectNeed (BindingSubject _ need _) = need

subjectCapability :: BindingSubject -> CapabilityArm
subjectCapability (BindingSubject _ _ capability) = capability
