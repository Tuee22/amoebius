module UiLocalCompositionCases (calculusRows, interactionNames) where

calculusRows :: [[String]]
calculusRows =
  [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
  , ["component-names", "generic-composition-artifact,closed-scope-budget,local-composition-corpus,ordered-effect-workflow,mutant-evidence"]
  , ["projection-counts", "1,3,42,4,5"]
  , ["resource-vector", "5,55,0,0"]
  ]

interactionNames :: [String]
interactionNames = ["single-start", "single-observe", "single-use", "multi-start", "multi-foreign-use"]
