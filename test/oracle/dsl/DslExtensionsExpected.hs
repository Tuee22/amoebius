{-# LANGUAGE OverloadedStrings #-}

-- Independent expectations authored before the replacement checker. Locations
-- name native GHC syntax and pragma nodes; no product value supplies a verdict.
module DslExtensionsExpected (AstExpected (..), astExpectations, astPairs) where

import Data.Text (Text)

data AstExpected
  = Admitted Text
  | Refused Text Text Text Int Int
  deriving (Eq, Show)

astExpectations :: [AstExpected]
astExpectations =
  [ Admitted "pure-simple"
  , Admitted "qualified-safe"
  , Admitted "forbidden-words-are-data"
  , Admitted "local-instance"
  , Admitted "qualified-alias-twin"
  , Admitted "explicit-export-twin"
  , Admitted "template-free-twin"
  , Admitted "cpp-free-twin"
  , Admitted "foreign-free-twin"
  , Admitted "string-data-twin"
  , Admitted "comment-split-pure-twin"
  , Admitted "compiler-options-free-twin"
  , Admitted "abstract-manifest-type"
  , Admitted "local-record-constructor"
  , Admitted "local-pure-name"
  , Admitted "explicit-abstract-import"
  , Admitted "local-semigroup-instance"
  , Admitted "closed-type-family"
  , Admitted "local-standalone-deriving"
  , Refused "qualified-alias" "RawIO" "identifier" 3 8
  , Refused "forbidden-reexport" "UnsafeOperation" "module-reexport" 1 18
  , Refused "template-splice" "TemplateHaskell" "splice-expression" 3 9
  , Refused "cpp-guarded" "UnsafeOperation" "language-pragma" 1 14
  , Refused "foreign-import" "ForeignCall" "foreign-declaration" 3 1
  , Refused "string-built-identifier" "UnsanctionedImport" "import-declaration" 3 1
  , Refused "comment-split-type" "RawIO" "type-variable" 2 19
  , Refused "orphan-instance" "OrphanInstance" "instance-declaration" 3 1
  , Refused "compiler-options" "UnsafeOperation" "options-pragma" 1 17
  , Refused "manifest-constructor" "UnsanctionedImport" "identifier" 3 9
  , Refused "foreign-record-update" "UnsafeOperation" "record-update" 3 12
  , Refused "foreign-record-projection" "UnsafeOperation" "record-projection" 3 14
  , Refused "read-method" "UnsafeOperation" "identifier" 3 8
  , Refused "enumeration" "UnsafeOperation" "enumeration-expression" 3 9
  , Refused "position-pragma" "UnsafeOperation" "position-pragma" 1 1
  , Refused "unknown-language" "UnsafeOperation" "language-pragma" 1 14
  , Refused "reserved-local-shadow" "RawIO" "name-reference" 2 1
  , Refused "unbounded-import" "UnsanctionedImport" "import-declaration" 2 1
  , Refused "self-alias-collision" "UnsanctionedImport" "import-declaration" 2 1
  , Refused "pattern-constructor-import" "UnsanctionedImport" "import-declaration" 3 1
  , Refused "source-import" "UnsanctionedImport" "import-declaration" 2 1
  , Refused "qualified-orphan-shadow" "OrphanInstance" "instance-declaration" 5 1
  , Refused "open-family-instance" "UnsafeOperation" "family-instance-declaration" 4 1
  , Refused "foreign-standalone-deriving" "OrphanInstance" "deriving-declaration" 3 1
  ]

astPairs :: [(Text, Text)]
astPairs =
  [ ("qualified-alias", "qualified-alias-twin")
  , ("forbidden-reexport", "explicit-export-twin")
  , ("template-splice", "template-free-twin")
  , ("cpp-guarded", "cpp-free-twin")
  , ("foreign-import", "foreign-free-twin")
  , ("string-built-identifier", "string-data-twin")
  , ("comment-split-type", "comment-split-pure-twin")
  , ("orphan-instance", "local-instance")
  , ("compiler-options", "compiler-options-free-twin")
  , ("manifest-constructor", "abstract-manifest-type")
  , ("foreign-record-update", "local-record-constructor")
  , ("foreign-record-projection", "local-record-constructor")
  , ("read-method", "string-data-twin")
  , ("enumeration", "qualified-safe")
  , ("position-pragma", "pure-simple")
  , ("unknown-language", "compiler-options-free-twin")
  , ("unbounded-import", "qualified-safe")
  , ("reserved-local-shadow", "local-pure-name")
  , ("self-alias-collision", "abstract-manifest-type")
  , ("pattern-constructor-import", "explicit-abstract-import")
  , ("source-import", "pure-simple")
  , ("qualified-orphan-shadow", "local-semigroup-instance")
  , ("open-family-instance", "closed-type-family")
  , ("foreign-standalone-deriving", "local-standalone-deriving")
  ]
