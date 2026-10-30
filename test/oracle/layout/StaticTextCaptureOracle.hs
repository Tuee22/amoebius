{-# LANGUAGE OverloadedStrings #-}
-- | Independent physical acquisition and full-payload expectations. Product
-- diagnostics are compared with these observations; they never supply an AST,
-- source inventory, input bytes, or a qualified result to this reference.
module StaticTextCaptureOracle (staticTextReference) where
import StaticTextExpected (parseReference, referenceModuleName, referenceRows)
import SourceGraphOracle (originalSnapshot)
import Control.Exception (evaluate)
import Control.Monad (forM)
import Data.ByteString qualified as Bytes
import Crypto.Hash.SHA256 qualified as Hash
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)
import System.FilePath (takeExtension, (</>))

type Finding = (Text,Text,Text)
type Observation = (Text,Text)
type NativeInput = (FilePath,Integer,Bytes.ByteString)
type Sink = (Text,Text,Text,Text,[(Int,Text)])

staticTextReference :: [Sink] -> FilePath -> [FilePath] -> IO (Either Text ([Finding],[Observation]))
staticTextReference catalogue root requested = do
  opening <- acquire
  case opening of
    Left problem -> pure (Left problem)
    Right before
      | sort requested /= [path | (path,_,_) <- before] -> pure (Left "IndependentStaticTextInputInventoryMismatch")
      | otherwise -> do
          let parsed = [(path,parseReference path bytes)
                | path <- sort requested, takeExtension path == ".hs"
                , (found,_,bytes) <- before, found == path]
              names = [referenceModuleName native | (_,Right native) <- parsed]
              findings = [(code,Text.pack path,"Existing SourceGraph source acquisition refused.")
                | (path,Left code) <- parsed]
          _ <- evaluate (sum (map Text.length names))
          rows <- concat <$> forM parsed (\(path,parsedModule) -> case parsedModule of
            Left _ -> pure []
            Right native -> do
              let expected = referenceRows catalogue names path native
              _ <- evaluate (sum (map Text.length expected))
              pure [("static-text-observation",value) | value <- expected])
          closing <- acquire
          pure $ case closing of
            Left problem -> Left problem
            Right after | before /= after -> Left "IndependentStaticTextSourceChanged"
                        | otherwise -> Right (findings,
                [("source-opening",projection before)
                ,("source-manifest",Text.pack (show requested))]
                <> rows <> [("source-closing",projection after)])
 where
  projection inputs=Text.pack (show [(path,mode,Bytes.length bytes,digest bytes) | (path,mode,bytes)<-inputs])
  digest=Text.pack.concatMap (\byte->let hex=showHex byte "" in replicate (2-length hex) '0'<>hex).Bytes.unpack.Hash.hash
  acquire :: IO (Either Text [NativeInput])
  acquire = do
    snapshot <- originalSnapshot root
    if any (\(_,kind,_,_) -> kind /= "regular") snapshot then pure (Left "IndependentStaticTextSourceKindUnavailable")
      else do
        inputs <- forM snapshot (\(path,_,mode,_) -> do
          bytes <- Bytes.readFile (root </> path)
          pure (path,mode,bytes))
        recheck <- originalSnapshot root
        pure (if snapshot == recheck then Right inputs else Left "IndependentStaticTextCaptureChanged")
