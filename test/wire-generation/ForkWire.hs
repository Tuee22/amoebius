-- | Observe real pure command and frame encoders from the maintained fork.
-- The separately authored oracle judges these bytes.
module ForkWire (main) where

import Data.ByteString.Lazy qualified as ByteString
import Numeric (showHex)
import Pulsar.Protocol.Commands qualified as Commands
import Pulsar.Protocol.Encoder (encodeBaseCommand)

main :: IO ()
main = mapM_ write
  [ ("ping", encodeBaseCommand Nothing Nothing Commands.ping)
  , ("flow", encodeBaseCommand Nothing Nothing (Commands.flow 7 11))
  , ("send", encodeBaseCommand Nothing Nothing (Commands.send 7 11))
  ]
 where
  write (name, bytes) = putStrLn (name <> "\t" <> concatMap hex (ByteString.unpack bytes))
  hex byte = case showHex byte "" of [digit] -> ['0', digit]; digits -> digits
