module ClassEffectRoute where

import System.IO.Unsafe (unsafePerformIO)

class RouteAction a where
  runRoute :: a -> Int

data Token = Token

effectSeed :: () -> IO Int
effectSeed () = length <$> getLine

instance RouteAction Token where
  runRoute _ = unsafePerformIO (effectSeed ())

caller :: Token -> Int
caller token = runRoute token

class DirectIoRoute a where
  runDirectIo :: a -> IO Int

directCaller :: DirectIoRoute a => a -> Int
directCaller value = unsafePerformIO (runDirectIo value)
