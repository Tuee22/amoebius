{-# LANGUAGE DataKinds #-}

-- Positive decode anchor: dhall/examples/legal_deployment_rules.dhall
module TransitionLegal where

import Amoebius.Dsl.Types

bound :: StateWitness 'Bound
bound = advanceState BindTransition AuthoredWitness
