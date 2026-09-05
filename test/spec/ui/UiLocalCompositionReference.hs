module UiLocalCompositionReference (accessRows, denialRows, effectRows, visibleRows) where

accessRows :: [(String, Bool)]
accessRows = [("own", True), ("same-tenant-foreign", False), ("foreign-tenant", False)]

visibleRows :: [(String, String)]
visibleRows =
  [ ("single-start", "Workflow running")
  , ("single-observe", "Artifact ready")
  , ("single-use", "Result fresh-challenge-43-to-44")
  , ("multi-foreign-use", "Unavailable")
  ]

effectRows :: [(String, String)]
effectRows =
  [ ("ui-server", "workflow-start:fresh-challenge-43-to-44")
  , ("fake-workflow", "workflow-ready:fresh-challenge-43-to-44")
  , ("ui-server", "artifact-use:fresh-challenge-43-to-44")
  , ("multi-foreign", "zero-effects")
  ]

denialRows :: [(String, Int, String)]
denialRows =
  [ ("same-tenant-foreign", 404, "Unavailable")
  , ("foreign-tenant", 404, "Unavailable")
  , ("caller-tenant-header", 404, "Unavailable")
  , ("non-ready-handle", 409, "NotReady")
  , ("direct-browser-backend", 403, "BypassDenied")
  ]
