{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Storage.StorageClass
import System.Exit (die)

main :: IO ()
main = do
  let exact = ObservedStorageClass retainedStorageClass False
  assertEqual "one inert class" (Right retainedStorageClass) (validateStorageClassInventory [exact])
  assertEqual "count != 1" (Left (StorageClassCountMismatch 2)) (validateStorageClassInventory [exact, exact])
  assertEqual
    "default-class annotation present"
    (Left (DefaultStorageClassAnnotationPresent "amoebius-retained"))
    (validateStorageClassInventory [exact {observedStorageClassDefault = True}])
  let dynamic = retainedStorageClass {storageClassProvisioner = "rancher.io/local-path"}
  assertEqual
    "dynamic provisioner mismatch"
    (Left (StorageClassDefinitionMismatch retainedStorageClass dynamic))
    (validateStorageClassInventory [ObservedStorageClass dynamic False])
  putStrLn "retained-storage-class-spec: PASS (one inert non-default no-provisioner StorageClass)"

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
