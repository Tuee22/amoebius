[ { name = "aws-ebs-csi-controller"
  , path = "/usr/local/libexec/amoebius/aws-ebs-csi-driver"
  , version = "v1.48.0"
  , architectures = [ "amd64", "arm64" ]
  }
, { name = "aws-ebs-csi-node"
  , path = "/usr/local/libexec/amoebius/aws-ebs-csi-driver"
  , version = "v1.48.0"
  , architectures = [ "amd64", "arm64" ]
  }
, { name = "csi-attacher"
  , path = "/usr/local/libexec/amoebius/csi-attacher"
  , version = "v4.9.0"
  , architectures = [ "amd64", "arm64" ]
  }
, { name = "csi-node-driver-registrar"
  , path = "/usr/local/libexec/amoebius/csi-node-driver-registrar"
  , version = "v2.14.0"
  , architectures = [ "amd64", "arm64" ]
  }
, { name = "csi-liveness-probe"
  , path = "/usr/local/libexec/amoebius/livenessprobe"
  , version = "v2.16.0"
  , architectures = [ "amd64", "arm64" ]
  }
]
