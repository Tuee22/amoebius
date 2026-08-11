{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostComms.Illegal
  ( illegalHostCommsTags
  ) where

import Data.Text (Text)

illegalHostCommsTags :: [Text]
illegalHostCommsTags =
  [ "HostOriginMustBeNodePort"
  , "HostOriginMustNotHaveEnvoyRoute"
  , "HostOriginMustBindLoopback"
  , "HostWorkerMustNotPublishIngress"
  ]
