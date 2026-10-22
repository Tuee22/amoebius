{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | The closed Linux-frame vocabulary, shared by profiles and host ensure.
module Amoebius.Vocabulary.Frame (Frame (..), frameName) where

import Control.DeepSeq (NFData)
import GHC.Generics (Generic)

data Frame = NativeLinux | LimaGuest | Wsl2Guest
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)
  deriving anyclass (NFData)

frameName :: Frame -> String
frameName frame = case frame of
  NativeLinux -> "native-linux"
  LimaGuest -> "lima-guest"
  Wsl2Guest -> "wsl2-guest"
