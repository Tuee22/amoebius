{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Release.Projection
  ( UiProgramSource (..)
  , UiProgramRelease (..)
  , projectUiProgram
  , releaseContentDigest
  ) where

import Amoebius.Ui.Release.ArtifactManifest
import Amoebius.Ui.Release.PlanPair
import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy (ByteString)
import Data.List (intersperse)
import Data.Text (Text)

data UiProgramSource = UiProgramSource
  { sourceRevision :: ProgramRevision
  , sourceVisibleLabel :: Text
  , sourcePolicyEpoch :: Int
  , sourceRuntimeAbi :: Text
  }
  deriving stock (Eq, Show)

data UiProgramRelease = UiProgramRelease
  { uiReleasePair :: PlanPair
  , uiReleaseContracts :: ByteString
  , uiReleaseAuthority :: ArtifactDigest
  , uiReleaseManifest :: ArtifactManifest
  }
  deriving stock (Eq, Show)

projectUiProgram :: RuntimeImageDigest -> UiProgramSource -> Either PairError UiProgramRelease
projectUiProgram runtime source = do
  pair <- publishPlanPair (Just client) (Just server)
  let manifest = ArtifactManifest
        { manifestRevision = revisionText revision
        , manifestClientPlan = planDigest client
        , manifestServerPlan = planDigest server
        , manifestPublicContracts = digestArtifact contracts
        , manifestAuthority = authority
        , manifestWebSocketSubprotocol = "amoebius.ui.v1"
        , manifestRoutingEnvelopeSchema = "amoebius.routing.v1"
        , manifestCursorCodec = "amoebius.cursor.v1"
        , manifestRuntimeImage = selectedRuntime
        }
  pure UiProgramRelease
    { uiReleasePair = pair
    , uiReleaseContracts = contracts
    , uiReleaseAuthority = authority
    , uiReleaseManifest = manifest
    }
 where
  revision = sourceRevision source
  client = planArtifact revision ClientRole (object
    [ ("abi", string (sourceRuntimeAbi source))
    , ("label", string (sourceVisibleLabel source))
    , ("revision", string (revisionText revision))
    ])
  server = planArtifact revision ServerRole (object
    [ ("abi", string (sourceRuntimeAbi source))
    , ("handler", string "linked:test-action")
    , ("policy-epoch", Aeson.encode (sourcePolicyEpoch source))
    , ("revision", string (revisionText revision))
    ])
  contracts = object
    [ ("request", string "phase40-action-v1")
    , ("response", string "phase40-receipt-v1")
    ]
  authority = digestArtifact (Aeson.encode (sourcePolicyEpoch source))
  selectedRuntime =
#ifdef PHASE40_REBUILD_RUNTIME_PER_PROGRAM_MUTANT
    RuntimeImageDigest (runtimeImageDigestText runtime <> "-program-" <> revisionText revision)
#else
    runtime
#endif

releaseContentDigest :: UiProgramRelease -> ArtifactDigest
releaseContentDigest release = manifestDigest (uiReleaseManifest release)

string :: Text -> ByteString
string = Aeson.encode

object :: [(Text, ByteString)] -> ByteString
object fields = "{" <> mconcat (intersperse "," (map render fields)) <> "}"
 where
  render (key, value) = string key <> ":" <> value
