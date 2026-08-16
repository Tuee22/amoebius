{ modules =
  [ "Amoebius.Kernel.Step"
  , "Amoebius.Manifest.K8sObject"
  ]
, effects =
  [ "ApplyManifest"
  , "BuildImage"
  , "PushImage"
  , "UpdateInfrastructure"
  ]
}
