{-# LANGUAGE OverloadedStrings #-}

module Phase48ContentAddressPositive where

import Amoebius.Kernel.ContentAddress (BlobSha, contentAddress)
import Data.ByteString (ByteString)

derived :: ByteString -> BlobSha
derived = contentAddress
