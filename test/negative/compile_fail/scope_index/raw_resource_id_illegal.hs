{-# LANGUAGE OverloadedStrings #-}
module RawResourceIdIllegal where
import Amoebius.Scope.Index (ResourceId)
illegal :: ResourceId
illegal = ResourceId "caller-controlled"
