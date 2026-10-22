{-# LANGUAGE OverloadedStrings #-}

-- Authored before the closed family/runtime replacement. No product import.
module DslEngineContract (engineRuntimes, inferenceFamilies, inferenceFamilyNames, familyLaneMatrix, engineRefusals, fakeDeviceModel) where

import Data.Text (Text)

engineRuntimes :: [Text]
engineRuntimes = ["AppleMetal", "Cuda", "LinuxCpu"]

inferenceFamilies :: [Text]
inferenceFamilies = ["LlamaCpp", "WhisperCpp", "Onnx", "Vllm", "Pytorch", "Diffusers", "Transformers", "Audiveris"]

-- Canonical display spellings of the closed families, including the proper
-- name Audiveris. These are literals, not projections of the product enum.
inferenceFamilyNames :: [(Text, Text)]
inferenceFamilyNames =
  [("LlamaCpp", "llama.cpp"), ("WhisperCpp", "whisper.cpp"), ("Onnx", "ONNX"),
   ("Vllm", "vLLM"), ("Pytorch", "pytorch"), ("Diffusers", "diffusers"),
   ("Transformers", "transformers"), ("Audiveris", "Audiveris")]

-- Columns are Apple-Metal, CUDA, Linux CPU. This is bounded resolver support,
-- not a statement that an engine was executed on hardware during this gate.
familyLaneMatrix :: [(Text, Bool, Bool, Bool)]
familyLaneMatrix =
  [ ("LlamaCpp", True, True, True)
  , ("WhisperCpp", True, True, True)
  , ("Onnx", False, True, True)
  , ("Vllm", False, True, False)
  , ("Pytorch", True, True, True)
  , ("Diffusers", True, True, False)
  , ("Transformers", True, True, True)
  , ("Audiveris", False, False, True)
  ]

engineRefusals :: [(Text, Text)]
engineRefusals =
  [ ("arbitrary-engine-url", "closed runtime has no text payload")
  , ("arbitrary-family", "closed family union")
  , ("family-on-app-need", "family belongs to deployment binding")
  , ("vllm-on-metal", "EngineFamilyUnavailable")
  , ("cuda-on-cpu", "LaneUnavailable")
  , ("missing-explicit-inference-binding", "InferenceBindingRequired")
  , ("missing-sealed-engine-runtime", "InvalidEngineRuntime")
  ]

-- Raw, reserved and allocatable bytes at the explicitly fake device boundary.
-- These small values model capacity accounting; they describe no real GPU.
fakeDeviceModel :: (Integer, Integer, Integer)
fakeDeviceModel = (64, 8, 56)
