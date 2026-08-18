module RawPayload where

import Amoebius.Pulsar.Producer (Producer, produceRaw)
import Data.ByteString (ByteString)

illegal :: Producer -> ByteString -> IO ()
illegal producer bytes = produceRaw producer bytes >> pure ()
