{-# LANGUAGE OverloadedStrings #-}
module LiteralTopic where

import Amoebius.Pulsar.Topology (Topic)

illegal :: Topic
illegal = Topic "persistent://literal/not-derived/topic"
