module HostEnsureKernelOracle
  ( expectedFrames
  , expectedPlans
  , expectedTable
  , expectedRefusals
  , expectedLift
  , expectedReplay
  ) where

import Data.List (intercalate)

data Step = Step String String String

substrates :: [String]
substrates = ["linux-cpu", "linux-cuda", "apple", "windows"]

expectedFrames :: [String]
expectedFrames =
  [ "linux-cpu\tnative-linux\tdocker-engine\tincus"
  , "linux-cuda\tnative-linux\tdocker-engine\tincus"
  , "apple\tlima-guest\tprovider-supplied-engine\tlima"
  , "windows\twsl2-guest\tprovider-supplied-engine\twsl2"
  ]

stepsFor :: String -> [Step]
stepsFor substrate =
  [ Step "package-manager-root" "verified-only" (rootName substrate)
  , Step "disk-observer" "verified-only" "df"
  , Step "ghcup" "package-manager-root" (install substrate "ghcup")
  , Step "cabal" "ghcup" "install cabal $(cabal) --set"
  ]
    <> [Step "docker" "package-manager-root" (install substrate "docker.io") | substrate `elem` ["linux-cpu", "linux-cuda"]]
    <> [ Step "kubectl" "package-manager-root" (install substrate (kubectlName substrate))
       , Step "kind" "package-manager-root" (install substrate "kind")
       ]

rootName :: String -> String
rootName substrate = case substrate of
  "linux-cpu" -> "apt-get"
  "linux-cuda" -> "apt-get"
  "apple" -> "brew"
  "windows" -> "winget"
  _ -> error "closed oracle substrate"

install :: String -> String -> String
install substrate package = case substrate of
  "linux-cpu" -> "install -y " <> package
  "linux-cuda" -> "install -y " <> package
  "apple" -> "install " <> package
  "windows" -> "install --exact " <> package
  _ -> error "closed oracle substrate"

kubectlName :: String -> String
kubectlName substrate = case substrate of
  "apple" -> "kubernetes-cli"
  "windows" -> "Kubernetes.kubectl"
  _ -> "kubectl"

renderStep :: String -> Int -> Step -> String
renderStep substrate ordinal (Step provides performer arguments) =
  intercalate "\t" [substrate, show ordinal, provides, performer, arguments]

expectedPlans :: [String]
expectedPlans =
  [ renderStep substrate ordinal step
  | substrate <- substrates
  , (ordinal, step) <- zip [1 :: Int ..] (stepsFor substrate)
  ]

expectedTable :: [String]
expectedTable =
  [ "applies\tpackage-manager-root\tlinux-cpu,linux-cuda,apple,windows"
  , "applies\thaskell-toolchain\tlinux-cpu,linux-cuda,apple,windows"
  , "applies\tcontainer-engine\tlinux-cpu,linux-cuda"
  , "applies\tcluster-tools\tlinux-cpu,linux-cuda,apple,windows"
  ] <> map ("step\t" <>) expectedPlans

expectedRefusals :: [String]
expectedRefusals = concatMap rows reconcilers
 where
  reconcilers :: [(String, [String], String -> Int)]
  reconcilers =
    [ ("package-manager-root", substrates, const 2)
    , ("haskell-toolchain", substrates, const 2)
    , ("container-engine", ["linux-cpu", "linux-cuda"], const 1)
    , ("cluster-tools", substrates, const 2)
    ]
  rows (name, admitted, count) =
    [ intercalate "\t"
        [ name
        , substrate
        , if substrate `elem` admitted
            then "admitted\t" <> show (count substrate)
            else "refused\tnot-applicable:" <> name <> ":" <> substrate
        , name <> " applies to " <> intercalate ", " admitted <> "; it was driven on " <> substrate
        ]
    | substrate <- substrates
    ]

expectedLift :: [String]
expectedLift = concatMap lifted contexts
 where
  executableSteps =
    [ ("package-manager-root", "install -y ghcup")
    , ("ghcup", "install cabal 3.16.1.0 --set")
    , ("package-manager-root", "install -y docker.io")
    , ("package-manager-root", "install -y kubectl")
    , ("package-manager-root", "install -y kind")
    ]
  contexts = ["on-host", "in-frame:lima-guest", "in-container:amoebius-base"]
  lifted context =
    [ context <> "\t" <> prefix context tool <> arguments
    | (tool, arguments) <- executableSteps
    ]
  prefix context tool = case context of
    "on-host" -> "/opt/amoebius/bin/" <> tool <> " "
    "in-frame:lima-guest" -> "/opt/amoebius/bin/limactl -- " <> command tool <> " "
    "in-container:amoebius-base" -> "/opt/amoebius/bin/docker run --rm amoebius-base " <> command tool <> " "
    _ -> error "closed oracle context"
  command "package-manager-root" = "package-manager-root"
  command other = other

expectedReplay :: [String]
expectedReplay =
  [ "1\tmutation\tstubs/package-manager-root install -y ghcup"
  , "1\tmutation\tstubs/ghcup install cabal 3.16.1.0 --set"
  , "1\tmutation\tstubs/package-manager-root install -y docker.io"
  , "1\tmutation\tstubs/package-manager-root install -y kubectl"
  , "1\tmutation\tstubs/package-manager-root install -y kind"
  ] <> concatMap passRows [1 :: Int, 2, 3]
 where
  passRows pass =
    [ show pass <> "\tconverged\tconverged\t"
    , show pass <> "\tprobe\tpackage-manager-root"
    , show pass <> "\tprobe\tghcup"
    , show pass <> "\tprobe\tcabal"
    , show pass <> "\tprobe\tdocker"
    , show pass <> "\tprobe\tkubectl"
    , show pass <> "\tprobe\tkind"
    , show pass <> "\tprobe\tdisk-observer"
    ]
