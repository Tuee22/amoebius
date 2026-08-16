{ snapshot = "phase25-bootstrap-snapshot-v1"
, identities =
  [ "Namespace/amoebius-bootstrap"
  , "ConfigMap/amoebius-bootstrap/registry-config"
  , "Deployment/amoebius-bootstrap/distribution"
  , "Service/amoebius-bootstrap/distribution-read"
  , "Deployment/amoebius-bootstrap/registry-mutation-proxy"
  , "Service/amoebius-bootstrap/registry-mutation-proxy"
  ]
, initializedFields =
  [ "metadata.labels"
  , "metadata.annotations.amoebius.io/source-digest"
  , "spec.selector"
  , "spec.template"
  , "spec.ports"
  , "data.registry-config"
  ]
, handoffDigest = "sha256:67e357a79427c167049e50114204e327660e40c66ed8ea34653441de8136527d"
, equalVerdict = "AdoptedOnce"
, mismatchTag = "BootstrapHandoffDigestMismatch"
, staleTag = "BootstrapSnapshotChanged"
, repeatedTag = "BootstrapHandoffAlreadyConsumed"
}
