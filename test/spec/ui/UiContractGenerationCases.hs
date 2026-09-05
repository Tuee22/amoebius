module UiContractGenerationCases (calculusRows, generatedPaths) where

calculusRows :: [[String]]
calculusRows =
  [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
  , ["component-names", "generated-browser-artifacts,closed-runtime-abi,browser-contract-inventory,deterministic-render-workflow,mutant-evidence"]
  , ["projection-counts", "3,1,22,2,3"]
  , ["resource-vector", "5,31,0,0"]
  ]

generatedPaths :: [FilePath]
generatedPaths = ["Amoebius/Ui/Generated/Contracts.purs", "Amoebius/Ui/Generated/Codecs.purs", "GeneratedBundleMain.purs"]
