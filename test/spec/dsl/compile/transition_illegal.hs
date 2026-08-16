{-# LANGUAGE DataKinds #-}

-- Negative twin of transition_legal.hs: only the source state index differs.
module TransitionIllegal where

import Amoebius.Dsl.Types

bound :: StateWitness 'Bound
bound = advanceState BindTransition BoundWitness
