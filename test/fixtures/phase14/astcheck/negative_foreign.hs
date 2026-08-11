module BadForeign where
foreign import ccall "foreign_value" foreignValue :: Int
