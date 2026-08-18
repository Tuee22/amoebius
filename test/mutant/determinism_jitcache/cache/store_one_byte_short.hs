-- mut-48-cache-one-byte-short: truncate the resolved payload before storing.
module StoreOneByteShort where

store :: [a] -> [a]
store [] = []
store values = init values
