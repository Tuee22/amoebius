module UiBrowserInterpreterReference (traceRows, accessibilityRows, focusRows, transportRows) where

-- Independent strings constrain the production interpreter without importing it.
traceRows :: [[String]]
traceRows =
  [ ["single-edit", "Editing", "NoEffect", "home", "1"]
  , ["single-submit", "Pending", "PortRequest \"submit\"", "workflow", "1"]
  , ["single-cancel", "Cancelled", "PortRequest \"cancel\"", "workflow", "1"]
  , ["named-link", "Home", "Navigate \"docs\"", "home", "1"]
  , ["multi-choose", "Ready", "PortRequest \"scope\"", "home", "1"]
  ]

accessibilityRows :: [[String]]
accessibilityRows = [["heading", "Workflow"], ["status", "Pending"], ["button", "Submit"]]
focusRows :: [[String]]
focusRows = [["Escape", "modal-opener"], ["route", "new-route-h1"], ["Enter", "modal-first-control"], ["Tab", "modal-first-control"], ["validation", "modal-first-control"]]
transportRows :: [[String]]
transportRows = [["POST", "same-origin", "/ui/action/submit", "allow"], ["WS", "same-origin", "/ui/socket", "allow"], ["GET", "https://provider.invalid", "/api", "deny"], ["GET", "https://canary.invalid", "/", "deny"]]
