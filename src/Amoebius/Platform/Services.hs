module Amoebius.Platform.Services
  ( renderPlatformServices
  ) where

import Amoebius.Platform.Observability
import Amoebius.Platform.Postgres
import Amoebius.Platform.Redis
import Amoebius.Platform.Types

renderPlatformServices :: ProvisionedPostgresService -> ProvisionedObservability -> ProvisionedRedis -> [PlatformObject]
renderPlatformServices postgres observability redis =
  renderPostgresService postgres <> renderObservability observability <> renderRedis redis
