{-# LANGUAGE OverloadedStrings #-}

-- | Compiler-parsed Haskell source inventory. Import links use Cabal's
-- component map; direct calls from top-level functions are projected, with
-- possible same-module and imported callees retained as candidates. Potential
-- IO reachability uses only unique internal call candidates. Indirect calls,
-- full effects, sinks, provenance, and consumers remain open.
module Amoebius.Layout.SourceGraph (sourceGraph, sourceGraphWithPackageCatalog) where

import Amoebius.Layout.Classify (LayoutFinding (..))
import Amoebius.Layout.PackageMap
  ( ComponentDependencyMap, ForwardOwnedModuleMap, PackageCatalog, SourceComponentMap
  , emptyPackageCatalog, lookupExternalModule, lookupUnselectedModule
  , implicitPreludeUnit, lookupImplicitPrelude, implicitAvailablePreludeUnit
  , lookupImplicitAvailablePrelude, implicitStandalonePreludeUnit
  , lookupImplicitStandalonePrelude, lookupExternalExport, lookupAvailableExternalExport
  , lookupStandaloneExternalModule, lookupStandaloneExternalExport
  , lookupStandaloneRegisteredOnlyModule, lookupStandaloneRegisteredOnlyExport
  , lookupStandaloneExternalMemberExport
  , packageCatalogMemberNames
  , lookupExternalMemberExport, lookupAvailableExternalMemberExport
  , lookupDeferredSeedModule
  , loadExternalInterfaces, packageCatalogHasComponent, packageCatalogHasModuleInterface)
import Control.Applicative ((<|>))
import Control.Exception (IOException, SomeException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isUpper)
import Data.Foldable (toList)
import Data.List (isPrefixOf, isSuffixOf, sort, stripPrefix)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import GHC.Data.EnumSet qualified as EnumSet
import GHC.Data.FastString (mkFastString, unpackFS)
import GHC.Data.StringBuffer (StringBuffer, hGetStringBuffer)
import GHC.Builtin.Types (consDataConName, tupleDataCon)
import GHC.Core.DataCon (dataConName)
import GHC.Hs
  ( ArithSeqInfo (..), CImportSpec (..), ClsInstDecl (..), ConDecl (..), ConDeclField (..)
  , DerivClauseTys (..), DerivDecl (..), DerivStrategy (..)
  , DotFieldOcc (..), FieldOcc (..), GhcPs, GRHS (..), GRHSs (..)
  , ForeignDecl (..), ForeignExport (..), ForeignImport (..)
  , HsBindLR (..), HsConDeclGADTDetails (..), HsConDetails (..)
  , FamilyDecl (..), HsDataDefn (..), HsDecl (..), HsDerivingClause (..), HsSigType (..), HsType (..)
  , HsUntypedSplice (..), InstDecl (..), LHsDecl
  , HsExpr (..), HsLocalBindsLR (..), HsRecFields (..), HsTupArg (..)
  , HsValBindsLR (..), IE (..), IEWrappedName (..), IEWildcard (..), LPat
  , ImportDeclQualifiedStyle (..), ImportListInterpretation (..)
  , LHsRecUpdFields (..), LHsType, LIE, LIEWrappedName, LHsExpr, Match (..), MatchGroup (..), Pat (..)
  , Sig (..), SpliceDecl (..), StmtLR (..), TyClDecl (..), hfbRHS, hswc_body, hsmodDecls
  , hsmodExports, hsmodImports, hsmodName, ideclAs, ideclImportList
  , ideclName, ideclPkgQual, ideclQualified
  )
import GHC.Internal.LanguageExtensions qualified as Extension
import GHC.Hs.Utils (CollectFlag (..), collectPatBinders)
import GHC.Parser (parseModule)
import GHC.Parser.Annotation (HasLoc, getLocA)
import GHC.Parser.Header (getOptions)
import GHC.Parser.Lexer (ParseResult (..), initParserState, mkParserOpts, unP)
import GHC.Types.SrcLoc
  (GenLocated, SrcSpan (..), mkRealSrcLoc, srcSpanEndCol, srcSpanEndLine,
   srcSpanStartCol, srcSpanStartLine, unLoc)
import GHC.Types.PkgQual (RawPkgQual (..))
import GHC.Types.ForeignCall (CCallTarget (..), CExportSpec (..))
import GHC.Types.Name (nameModule, nameOccName)
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.Name.Reader (RdrName (..), rdrNameOcc)
import GHC.Unit.Module (moduleName, moduleNameString, moduleUnitId)
import GHC.Unit.Types (unitIdString)
import Language.Haskell.Syntax.Basic (Boxity (..), FieldLabelString (..))
import GHC.Utils.Error (emptyDiagOpts)
import GHC.Utils.Outputable (Outputable, ppr, showSDocUnsafe)
import System.Directory (createDirectoryIfMissing, makeAbsolute)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, takeExtension, (</>))
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

sourceGraph :: FilePath -> [FilePath] -> SourceComponentMap -> ComponentDependencyMap -> IO ([LayoutFinding], [Text])
sourceGraph root paths componentMap dependencyMap =
  sourceGraphWithPackageCatalog root paths componentMap dependencyMap emptyPackageCatalog Map.empty

sourceGraphWithPackageCatalog :: FilePath -> [FilePath] -> SourceComponentMap -> ComponentDependencyMap -> PackageCatalog -> ForwardOwnedModuleMap -> IO ([LayoutFinding], [Text])
sourceGraphWithPackageCatalog root paths componentMap dependencyMap initialCatalog forwardOwned = do
  parsed <- mapM parseSource (sort [path | path <- paths, takeExtension path == ".hs"])
  let modules = [entry | Right entry <- parsed]
      moduleNames = Set.fromList (map entryName modules)
      requestedInterfaces =
        [(unit, importName importRef)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , importRef <- entryImports entry
        , importPackageFree importRef
        , (_, unit) <- lookupExternalModule initialCatalog component (importName importRef)
            <> if packageCatalogHasComponent initialCatalog component then []
                 else lookupUnselectedModule initialCatalog component (importName importRef)]
        <> [(unit, importName importRef)
           | entry <- modules
           , Map.notMember (entryPath entry) componentMap
           , importRef <- entryImports entry
           , importPackageFree importRef
           , importName importRef `Set.notMember` moduleNames
           , (_, unit) <- lookupStandaloneExternalModule initialCatalog (importName importRef)]
        <> [(unit, importName importRef)
           | entry <- modules
           , Map.notMember (entryPath entry) componentMap
           , importRef <- entryImports entry
           , importPackageFree importRef
           , importName importRef `Set.notMember` moduleNames
           , null (lookupStandaloneExternalModule initialCatalog (importName importRef))
           , (_, unit) <- lookupStandaloneRegisteredOnlyModule initialCatalog (importName importRef)]
  interfaceResult <- loadExternalInterfaces initialCatalog requestedInterfaces
  let catalog = either (const initialCatalog) fst interfaceResult
      interfaceFindings = either pure (const []) interfaceResult
      interfaceRows = either (const []) snd interfaceResult
      byPath = Map.fromList [(entryPath entry, entry) | entry <- modules]
      byModuleName = Map.fromListWith (<>)
        [(entryName entry, [entryPath entry]) | entry <- modules]
      byComponentName = Map.fromListWith (<>)
        [((component, entryName entry), [entryPath entry])
        | entry <- modules, component <- Map.findWithDefault [] (entryPath entry) componentMap]
      byName = Map.fromListWith (<>)
        [(entryName entry, [(component, entryPath entry)])
        | entry <- modules, component <- Map.findWithDefault [] (entryPath entry) componentMap]
      instanceSourceContracts = Set.toAscList . Set.fromList $
        [(entryPath entry, instanceHead instance_, instanceClass instance_, method,
          providerPath, imported)
        | entry <- modules
        , instance_ <- entryClassInstances entry
        , method <- instanceMethods instance_
        , (providerPath, imported) <-
            [(entryPath entry, "-")
            | (instanceClass instance_, method) `elem` entryClassMethods entry]
            <> [(providerPath, importName importRef)
               | importRef <- entryImports entry
               , importPackageFree importRef
               , Just className <- [importedCallName importRef (instanceClass instance_)]
               , classImportPermits importRef className method
               , [providerPath] <- [Map.findWithDefault [] (importName importRef) byModuleName]
               , providerPath /= entryPath entry
               , Just provider <- [Map.lookup providerPath byPath]
               , (className, method) `elem` entryClassMethods provider
               , maybe True (method `elem`) (entryExports provider)
               , let owners = Map.findWithDefault [] (entryPath entry) componentMap
               , null owners || any (\component ->
                   any ((== providerPath) . snd) (candidates component (importName importRef))) owners]]
      instanceExternalContracts = Set.toAscList . Set.fromList $
        [(entryPath entry, instanceHead instance_, instanceClass instance_, method,
          importName importRef, package, unit, "explicit")
        | entry <- modules
        , instance_ <- entryClassInstances entry
        , method <- instanceMethods instance_
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , Just className <- [importedCallName importRef (instanceClass instance_)]
        , classImportPermits importRef className method
        , [(package, unit)] <- [selectedExternalProviders entry (importName importRef)]
        , packageCatalogHasModuleInterface catalog unit (importName importRef)
        , method `elem` packageCatalogMemberNames catalog unit (importName importRef) className]
        <> [(entryPath entry, instanceHead instance_, instanceClass instance_, method,
             "Prelude", package, unit, "implicit")
           | entry <- modules
           , entryImplicitPrelude entry
           , instance_ <- entryClassInstances entry
           , method <- instanceMethods instance_
           , not (looksQualified (instanceClass instance_))
           , instanceClass instance_ `notElem` entryClassNames entry
           , [(package, unit)] <- [selectedImplicitProviders entry]
           , packageCatalogHasModuleInterface catalog unit "Prelude"
           , method `elem` packageCatalogMemberNames catalog unit "Prelude"
               (instanceClass instance_)]
      derivedClassMemberCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, symbolType symbols, classText, classHead, strategy,
          importName importRef, package, unit, member, "explicit")
        | entry <- modules
        , symbols <- entryData entry
        , (classText, classHead, strategy) <- symbolDerivedTypes symbols
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , Just importedClass <- [importedCallName importRef classHead]
        , classTypeImportPermits importRef importedClass
        , (package, unit) <- externalProviders entry (importName importRef)
        , packageCatalogHasModuleInterface catalog unit (importName importRef)
        , member <- packageCatalogMemberNames catalog unit (importName importRef) importedClass]
        <> [(entryPath entry, symbolType symbols, classText, classHead, strategy,
             "Prelude", package, unit, member, "implicit")
           | entry <- modules
           , entryImplicitPrelude entry
           , symbols <- entryData entry
           , (classText, classHead, strategy) <- symbolDerivedTypes symbols
           , not (looksQualified classHead)
           , classHead `notElem` entryClassNames entry
           , (package, unit) <- implicitProviders entry
           , packageCatalogHasModuleInterface catalog unit "Prelude"
           , member <- packageCatalogMemberNames catalog unit "Prelude" classHead]
      standaloneDerivingMemberCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, instanceType, classHead, strategy,
          importName importRef, package, unit, member, "explicit")
        | entry <- modules
        , (instanceType, classHead, strategy) <- entryStandaloneDeriving entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , Just importedClass <- [importedCallName importRef classHead]
        , classTypeImportPermits importRef importedClass
        , (package, unit) <- externalProviders entry (importName importRef)
        , packageCatalogHasModuleInterface catalog unit (importName importRef)
        , member <- packageCatalogMemberNames catalog unit (importName importRef) importedClass]
        <> [(entryPath entry, instanceType, classHead, strategy,
             "Prelude", package, unit, member, "implicit")
           | entry <- modules
           , entryImplicitPrelude entry
           , (instanceType, classHead, strategy) <- entryStandaloneDeriving entry
           , not (looksQualified classHead)
           , classHead `notElem` entryClassNames entry
           , (package, unit) <- implicitProviders entry
           , packageCatalogHasModuleInterface catalog unit "Prelude"
           , member <- packageCatalogMemberNames catalog unit "Prelude" classHead]
      externalProviders entry imported = case Map.findWithDefault [] (entryPath entry) componentMap of
        [] -> lookupStandaloneExternalModule catalog imported
        components -> concatMap (\component ->
          case (if packageCatalogHasComponent catalog component
                 then lookupExternalModule catalog component imported
                 else lookupUnselectedModule catalog component imported) of
            [provider] -> [provider]
            _ -> []) components
      selectedExternalProviders entry imported =
        Set.toAscList . Set.fromList $ case Map.findWithDefault [] (entryPath entry) componentMap of
          [] -> lookupStandaloneExternalModule catalog imported
          components -> concatMap (\component ->
            lookupExternalModule catalog component imported) components
      selectedImplicitProviders entry =
        Set.toAscList . Set.fromList $ case Map.findWithDefault [] (entryPath entry) componentMap of
          [] -> implicitStandalonePreludeUnit catalog
          components -> concatMap (implicitPreludeUnit catalog) components
      implicitProviders entry = case Map.findWithDefault [] (entryPath entry) componentMap of
        [] -> implicitStandalonePreludeUnit catalog
        components -> concatMap (\component ->
          implicitPreludeUnit catalog component
            <> implicitAvailablePreludeUnit catalog component) components
      candidates component imported =
        let local = [(component, path) | path <- Map.findWithDefault [] (component, imported) byComponentName]
        in if null local
          then [(dependency, path)
               | dependency <- Map.findWithDefault [] component dependencyMap
               , path <- Map.findWithDefault [] (dependency, imported) byComponentName]
          else local
      exportedTargets component provider name visited
        | (component, provider) `Set.member` visited = []
        | otherwise = case Map.lookup provider byPath of
            Nothing -> []
            Just entry ->
              let seen = Set.insert (component, provider) visited
                  explicit = maybe False (name `elem`) (entryExports entry)
                  local = [(component, provider, name)
                    | name `elem` entryValueNames entry
                    , maybe True (const explicit) (entryExports entry)]
                  imported =
                    [target
                    | importRef <- entryImports entry
                    , importPackageFree importRef
                    , let reexported = not (importQualifiedOnly importRef)
                            && (importQualifier importRef `elem` entryReexports entry
                                  || importName importRef `elem` entryReexports entry)
                    , (targetComponent, targetPath) <- candidates component (importName importRef)
                    , Just targetEntry <- [Map.lookup targetPath byPath]
                    , let explicitFromProvider = maybe False (name `elem`)
                            (exportedValueNames (entryData targetEntry)
                              (entryClassMethods targetEntry) <$> entryExportItems entry)
                    , reexported || explicit || explicitFromProvider
                    , reexported || importedCallName importRef name == Just name
                    , target@(_, physicalPath, _) <- exportedTargets targetComponent targetPath name seen
                    , Just physicalEntry <- [Map.lookup physicalPath byPath]
                    , importPermits importRef targetEntry name || importPermits importRef physicalEntry name]
              in Set.toAscList (Set.fromList (local <> imported))
      links = Set.toAscList . Set.fromList $
        [ (component, entryPath entry, imported, Set.toAscList (Set.fromList providers))
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , importRef <- entryImports entry
        , let imported = importName importRef
        , importPackageFree importRef
        , let providers = candidates component imported
        , not (null providers)
        ]
      externalLinks = Set.toAscList . Set.fromList $
        [(component, entryPath entry, imported, package, unit)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , importRef <- entryImports entry
        , let imported = importName importRef
        , importPackageFree importRef
        , null (candidates component imported)
        , [(package, unit)] <- [lookupExternalModule catalog component imported]]
      unselectedLinks = Set.toAscList . Set.fromList $
        [(component, entryPath entry, imported, package, unit)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , not (packageCatalogHasComponent catalog component)
        , importRef <- entryImports entry
        , let imported = importName importRef
        , importPackageFree importRef
        , null (candidates component imported)
        , (package, unit) <- lookupUnselectedModule catalog component imported]
      resolvedUnselected component imported =
        case lookupUnselectedModule catalog component imported of
          [(package, unit)]
            | not (packageCatalogHasComponent catalog component)
            , packageCatalogHasModuleInterface catalog unit imported -> Just (package, unit)
          _ -> Nothing
      resolvedUnselectedLinks = Set.toAscList . Set.fromList $
        [(component, consumer, imported, package, unit)
        | (component, consumer, imported, _, _) <- unselectedLinks
        , Just (package, unit) <- [resolvedUnselected component imported]]
      standaloneAvailableLinks = Set.toAscList . Set.fromList $
        [(entryPath entry, importName importRef, package, unit)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , (package, unit) <- lookupStandaloneExternalModule catalog (importName importRef)
        , packageCatalogHasModuleInterface catalog unit (importName importRef)]
      standaloneRegisteredOnlyLinks = Set.toAscList . Set.fromList $
        [(entryPath entry, importName importRef, package, unit)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , null (lookupStandaloneExternalModule catalog (importName importRef))
        , (package, unit) <- lookupStandaloneRegisteredOnlyModule catalog (importName importRef)
        , packageCatalogHasModuleInterface catalog unit (importName importRef)]
      forwardLinks = Set.toAscList . Set.fromList $
        [(component, entryPath entry, imported, expectedPath, role)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , importRef <- entryImports entry
        , let imported = importName importRef
        , importPackageFree importRef
        , null (candidates component imported)
        , null (lookupExternalModule catalog component imported)
        , Just (expectedPath, role) <- [Map.lookup (component, imported) forwardOwned]]
      deferredSeedLinks = Set.toAscList . Set.fromList $
        [(component, entryPath entry, imported, package, owner)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , importRef <- entryImports entry
        , let imported = importName importRef
        , importPackageFree importRef
        , null (candidates component imported)
        , Just (package, owner) <- [lookupDeferredSeedModule dependencyMap catalog component imported]]
      unresolved = Set.toAscList . Set.fromList $
        [ (component, entryPath entry, imported,
            if not (importPackageFree importRef) then "package-qualified"
            else if Map.member imported byName then "internal-not-declared"
            else if length (lookupExternalModule catalog component imported) > 1 then "external-ambiguous"
            else if not (packageCatalogHasComponent catalog component) then "component-not-in-plan"
            else "external-or-unknown")
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , importRef <- entryImports entry
        , let imported = importName importRef
        , not (importPackageFree importRef)
            || (null (candidates component imported)
                && length (lookupExternalModule catalog component imported) /= 1
                && resolvedUnselected component imported == Nothing
                && lookupDeferredSeedModule dependencyMap catalog component imported == Nothing
                && (not (null (lookupExternalModule catalog component imported))
                    || Map.notMember (component, imported) forwardOwned))
        ]
      localCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `elem` entryValueNames entry]
      standaloneLocalCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `elem` entryValueNames entry]
      standaloneLexicalCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, binderSite)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, binderSite) <- entryLexicalBindingCalls entry]
      standaloneImportedCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, importName importRef, providerPath, callee)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , Just callee <- [importedCallName importRef target]
        , [providerPath] <- [Map.findWithDefault [] (importName importRef) byModuleName]
        , providerPath /= entryPath entry
        , Just provider <- [Map.lookup providerPath byPath]
        , callee `elem` entryValueNames provider
        , maybe True (callee `elem`) (entryExports provider)
        , importPermits importRef provider callee]
      standaloneDeniedSourceCallSites = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, importName importRef,
          providerPath, callee, reason)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , Just callee <- [importedCallName importRef target]
        , [providerPath] <- [Map.findWithDefault [] (importName importRef) byModuleName]
        , providerPath /= entryPath entry
        , Just provider <- [Map.lookup providerPath byPath]
        , callee `elem` entryValueNames provider
        , reason <- if maybe True (callee `elem`) (entryExports provider)
            then ["import-list-excludes" | not (importPermits importRef provider callee)]
            else ["provider-not-exported"]]
      standaloneClosedExportRefusals = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, importName importRef,
          providerPath, callee)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , Just callee <- [importedCallName importRef target]
        , [providerPath] <- [Map.findWithDefault [] (importName importRef) byModuleName]
        , providerPath /= entryPath entry
        , Just provider <- [Map.lookup providerPath byPath]
        , callee `notElem` entryValueNames provider
        , explicitImportMentions importRef callee
        , ("-", entryPath entry, owner, site, target) `elem` opaqueCallSites
        , closedExportExcludes provider callee]
      standaloneExternalCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, importName importRef, package, unit, callee)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , [(package, unit)] <- [lookupStandaloneExternalModule catalog (importName importRef)]
        , packageCatalogHasModuleInterface catalog unit (importName importRef)
        , Just callee <- [externalCallName importRef target <|> externalOpenCallName importRef target]
        , (package, unit) `elem` lookupStandaloneExternalExport catalog (importName importRef) callee]
      standaloneRegisteredOnlyCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, importName importRef, package, unit, callee)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , null (lookupStandaloneExternalModule catalog (importName importRef))
        , [(package, unit)] <- [lookupStandaloneRegisteredOnlyModule catalog (importName importRef)]
        , packageCatalogHasModuleInterface catalog unit (importName importRef)
        , Just callee <- [externalCallName importRef target <|> externalOpenCallName importRef target]
        , (package, unit) `elem`
            lookupStandaloneRegisteredOnlyExport catalog (importName importRef) callee]
      standaloneExternalMemberCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, importName importRef, package, unit, parent, callee)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (Map.findWithDefault [] (importName importRef) byModuleName)
        , [(package, unit)] <- [lookupStandaloneExternalModule catalog (importName importRef)]
        , packageCatalogHasModuleInterface catalog unit (importName importRef)
        , (parent, callee) <- externalMemberCallNames importRef target
        , (package, unit) `elem` lookupStandaloneExternalMemberExport catalog (importName importRef) parent callee]
      localCallCandidates = Set.toAscList . Set.fromList $
        [(component, path, owner, target)
        | (component, path, owner, _, target) <- localCallSiteCandidates]
      localReferenceSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryReferences entry
        , not lexical
        , target `elem` entryValueNames entry]
      localReferenceCandidates = Set.toAscList . Set.fromList $
        [(component, path, owner, target)
        | (component, path, owner, _, target) <- localReferenceSiteCandidates]
      importedCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, targetComponent, provider, callee, importName importRef)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , importRef <- entryImports entry
        , importPackageFree importRef
        , Just callee <- [importedCallName importRef target]
        , (importComponent, importedPath) <- candidates component (importName importRef)
        , Just providerEntry <- [Map.lookup importedPath byPath]
        , (targetComponent, provider, _) <- exportedTargets importComponent importedPath callee Set.empty
        , Just physicalEntry <- [Map.lookup provider byPath]
        , importPermits importRef providerEntry callee || importPermits importRef physicalEntry callee]
      importedCallCandidates = Set.toAscList . Set.fromList $
        [(component, path, owner, targetComponent, provider, callee, imported)
        | (component, path, owner, _, _, targetComponent, provider, callee, imported) <- importedCallSiteCandidates]
      localCallIndex = Map.fromListWith (<>)
        [((component, path, owner, site, target), [(component, path, target, "local")])
        | (component, path, owner, site, target) <- localCallSiteCandidates]
      importedCallIndex = Map.fromListWith (<>)
        [((component, path, owner, site, target), [(targetComponent, provider, callee, "imported:" <> imported)])
        | (component, path, owner, site, target, targetComponent, provider, callee, imported) <- importedCallSiteCandidates]
      externalCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, importName importRef, package, unit, callee)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , null (Map.findWithDefault [] (component, entryPath entry, owner, site, target) localCallIndex)
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (candidates component (importName importRef))
        , [(package, unit)] <- [lookupExternalModule catalog component (importName importRef)]
        , let syntactic = externalCallName importRef target
        , Just callee <- [syntactic <|> externalOpenCallName importRef target]
        , let exported = (package, unit) `elem`
                lookupExternalExport catalog component (importName importRef) callee
        , exported || (syntactic /= Nothing
            && not (packageCatalogHasModuleInterface catalog unit (importName importRef)))]
      externalMemberCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, importName importRef,
          package, unit, parent, callee)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , null (Map.findWithDefault [] (component, entryPath entry, owner, site, target) localCallIndex)
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (candidates component (importName importRef))
        , (parent, callee) <- externalMemberCallNames importRef target
        , (package, unit) <- lookupExternalMemberExport catalog component (importName importRef) parent callee]
      availableCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, importName importRef, package, unit, callee)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , null (Map.findWithDefault [] (component, entryPath entry, owner, site, target) localCallIndex)
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (candidates component (importName importRef))
        , Just callee <- [externalCallName importRef target <|> externalOpenCallName importRef target]
        , (package, unit) <- lookupAvailableExternalExport catalog component (importName importRef) callee]
      availableMemberCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, importName importRef,
          package, unit, parent, callee)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , null (Map.findWithDefault [] (component, entryPath entry, owner, site, target) localCallIndex)
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (candidates component (importName importRef))
        , (parent, callee) <- externalMemberCallNames importRef target
        , (package, unit) <- lookupAvailableExternalMemberExport catalog component (importName importRef) parent callee]
      deferredSeedCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, importName importRef,
          package, role, callee)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , importRef <- entryImports entry, importPackageFree importRef
        , null (candidates component (importName importRef))
        , Just (package, role) <- [lookupDeferredSeedModule dependencyMap catalog component (importName importRef)]
        , Just callee <- [deferredSeedCallName importRef target]]
      implicitPreludeImports = Set.toAscList . Set.fromList $
        [(component, entryPath entry, package, unit)
        | entry <- modules
        , entryImplicitPrelude entry
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (package, unit) <- implicitPreludeUnit catalog component]
      availablePreludeImports = Set.toAscList . Set.fromList $
        [(component, entryPath entry, package, unit)
        | entry <- modules
        , entryImplicitPrelude entry
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (package, unit) <- implicitAvailablePreludeUnit catalog component]
      standalonePreludeImports = Set.toAscList . Set.fromList $
        [(entryPath entry, package, unit)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , entryImplicitPrelude entry
        , (package, unit) <- implicitStandalonePreludeUnit catalog]
      preludeCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, package, unit)
        | entry <- modules
        , entryImplicitPrelude entry
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , not (looksQualified target)
        , null (Map.findWithDefault [] (component, entryPath entry, owner, site, target) localCallIndex)
        , (package, unit) <- lookupImplicitPrelude catalog component target]
      availablePreludeCallSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, package, unit)
        | entry <- modules
        , entryImplicitPrelude entry
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , not (looksQualified target)
        , null (Map.findWithDefault [] (component, entryPath entry, owner, site, target) localCallIndex)
        , (package, unit) <- lookupImplicitAvailablePrelude catalog component target]
      standalonePreludeCallSiteCandidates = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target, package, unit)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , entryImplicitPrelude entry
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , not (looksQualified target)
        , target `notElem` entryValueNames entry
        , (package, unit) <- lookupImplicitStandalonePrelude catalog target]
      wiredConsName = Text.pack (occNameString (nameOccName consDataConName))
      wiredConsModule = Text.pack (moduleNameString (moduleName (nameModule consDataConName)))
      wiredConsUnit = Text.pack (unitIdString (moduleUnitId (nameModule consDataConName)))
      wiredConsCallSites = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical, target == wiredConsName]
      standaloneWiredConsCallSites = Set.toAscList . Set.fromList $
        [(entryPath entry, owner, site, target)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical, target == wiredConsName]
      wiredTupleName = Text.pack (occNameString (nameOccName tupleName))
      tupleName = dataConName (tupleDataCon Boxed 2)
      wiredTupleModule = Text.pack (moduleNameString (moduleName (nameModule tupleName)))
      wiredTupleUnit = Text.pack (unitIdString (moduleUnitId (nameModule tupleName)))
      wiredTupleCallSites = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical, target == wiredTupleName]
      callInternalTargets = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, Set.toAscList (Set.fromList chosen))
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryCalls entry
        , not lexical
        , let key = (component, entryPath entry, owner, site, target)
        , let local = Map.findWithDefault [] key localCallIndex
        , let chosen = if null local then Map.findWithDefault [] key importedCallIndex else local]
      classCallDispatchCandidates = Set.toAscList . Set.fromList $
        [(component, path, owner, site, target, classProvider,
          instancePath, headText, className, method)
        | (component, path, owner, site, target,
            [(_, classProvider, callee, _)]) <- callInternalTargets
        , (instancePath, headText, className, method, provider, _) <- instanceSourceContracts
        , classProvider == provider, callee == method]
      componentReachability = Map.fromList
        [(component, reachableComponents dependencyMap component)
        | component <- Set.toAscList (Set.fromList (concat (Map.elems componentMap)))]
      classMethodBodyRoutes = Set.toAscList . Set.fromList $
        [(component, path, owner, site, target, classProvider,
          instanceComponent, instancePath, headText, className, method,
          "instance[" <> headText <> "]." <> method)
        | (component, path, owner, site, target, classProvider,
            instancePath, headText, className, method) <- classCallDispatchCandidates
        , instanceComponent <- Map.findWithDefault [] instancePath componentMap
        , instanceComponent `Set.member`
            Map.findWithDefault Set.empty component componentReachability]
      externalInstanceContracts = Map.fromListWith (<>)
        [((imported, package, unit, method), [(instancePath, headText, className)])
        | (instancePath, headText, className, method, imported, package, unit, _)
            <- instanceExternalContracts]
      externalClassMethodBodyRoutes = Set.toAscList . Set.fromList $
        [(component, path, owner, site, target, imported, package, unit,
          instanceComponent, instancePath, headText, className, method,
          "instance[" <> headText <> "]." <> method)
        | (component, path, owner, site, target, imported, package, unit,
            method, parent) <-
            [(callerComponent, callerPath, callerOwner, callerSite, callerTarget,
              callerImport, callerPackage, callerUnit, callee, Nothing)
            | (callerComponent, callerPath, callerOwner, callerSite, callerTarget,
                callerImport, callerPackage, callerUnit, callee)
                <- externalCallSiteCandidates]
            <> [(callerComponent, callerPath, callerOwner, callerSite, callerTarget,
                 callerImport, callerPackage, callerUnit, callee, Just className)
               | (callerComponent, callerPath, callerOwner, callerSite, callerTarget,
                   callerImport, callerPackage, callerUnit, className, callee)
                   <- externalMemberCallSiteCandidates]
            <> [(callerComponent, callerPath, callerOwner, callerSite, callerTarget,
                 "Prelude", callerPackage, callerUnit, callerTarget, Nothing)
               | (callerComponent, callerPath, callerOwner, callerSite, callerTarget,
                   callerPackage, callerUnit) <- preludeCallSiteCandidates]
        , (instancePath, headText, className) <- Map.findWithDefault []
            (imported, package, unit, method) externalInstanceContracts
        , maybe True (== className) parent
        , instanceComponent <- Map.findWithDefault [] instancePath componentMap
        , instanceComponent `Set.member`
            Map.findWithDefault Set.empty component componentReachability]
      componentCallSites = Set.fromList
        [(component, entryPath entry, owner, site, target)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, _) <- entryCalls entry]
      standaloneCallSites = Set.fromList
        [("-", entryPath entry, owner, site, target)
        | entry <- modules
        , Map.notMember (entryPath entry) componentMap
        , (owner, target, site, _) <- entryCalls entry]
      lexicalCallSites = Set.fromList
        [(component, entryPath entry, owner, site, target)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, True) <- entryCalls entry]
      lexicalBindingSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, target, binderSite)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, binderSite) <- entryLexicalBindingCalls entry]
      lexicalAliasRoutes = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, binder, binderSite, target, targetKind)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, binder, site, binderSite) <- entryLexicalBindingCalls entry
        , (aliasOwner, aliasName, aliasSite, target, targetKind) <- entryLocalAliases entry
        , owner == aliasOwner, binder == aliasName, binderSite == aliasSite]
      lexicalAliasInternalCalls = Set.toAscList . Set.fromList $
        [(component, path, owner, site, binder, binderSite, target)
        | (component, path, owner, site, binder, binderSite, target, "unqualified") <- lexicalAliasRoutes
        , Just entry <- [Map.lookup path byPath]
        , target `elem` entryValueNames entry]
      lexicalAliasImportedCalls = Set.toAscList . Set.fromList $
        [(component, path, owner, site, binder, binderSite, target,
          targetComponent, provider, callee, importName importRef)
        | (component, path, owner, site, binder, binderSite, target, targetKind) <- lexicalAliasRoutes
        , targetKind `elem` ["qualified", "unqualified"]
        , Just entry <- [Map.lookup path byPath]
        , targetKind /= "unqualified" || target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , Just callee <- [importedCallName importRef target]
        , (importComponent, importedPath) <- candidates component (importName importRef)
        , Just providerEntry <- [Map.lookup importedPath byPath]
        , (targetComponent, provider, _) <- exportedTargets importComponent importedPath callee Set.empty
        , Just physicalEntry <- [Map.lookup provider byPath]
        , importPermits importRef providerEntry callee || importPermits importRef physicalEntry callee]
      aliasImportedGroups = Map.fromListWith Set.union
        [((component, path, owner, site, binder, binderSite, target),
          Set.singleton (targetComponent, provider, callee))
        | (component, path, owner, site, binder, binderSite, target,
           targetComponent, provider, callee, _) <- lexicalAliasImportedCalls]
      lexicalAliasUniqueImportedCalls =
        [(component, path, owner, targetComponent, provider, callee)
        | ((component, path, owner, _, _, _, _), targets) <- Map.toAscList aliasImportedGroups
        , [(targetComponent, provider, callee)] <- [Set.toAscList targets]]
      lexicalAliasExternalCalls = Set.toAscList . Set.fromList $
        [(component, path, owner, site, binder, binderSite, target,
          importName importRef, package, unit, callee)
        | (component, path, owner, site, binder, binderSite, target, targetKind) <- lexicalAliasRoutes
        , targetKind `elem` ["qualified", "unqualified"]
        , Just entry <- [Map.lookup path byPath]
        , targetKind /= "unqualified" || target `notElem` entryValueNames entry
        , importRef <- entryImports entry
        , importPackageFree importRef
        , null (candidates component (importName importRef))
        , [(package, unit)] <- [lookupExternalModule catalog component (importName importRef)]
        , Just callee <- [externalCallName importRef target <|> externalOpenCallName importRef target]
        , (package, unit) `elem` lookupExternalExport catalog component (importName importRef) callee]
      attributedCallSites = Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, targets) <- callInternalTargets
        , not (null targets)]
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target) <- standaloneLocalCallSiteCandidates]
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _) <- standaloneLexicalCallSiteCandidates]
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- standaloneImportedCallSiteCandidates]
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _, _) <- standaloneExternalCallSiteCandidates]
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _, _, _, _) <- standaloneExternalMemberCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- externalCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _) <- externalMemberCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- availableCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _, _) <- availableMemberCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _, _, _) <- deferredSeedCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- preludeCallSiteCandidates]
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _, _) <- availablePreludeCallSiteCandidates]
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target, _, _) <- standalonePreludeCallSiteCandidates]
        `Set.union` Set.fromList wiredConsCallSites
        `Set.union` Set.fromList
        [("-", path, owner, site, target)
        | (path, owner, site, target) <- standaloneWiredConsCallSites]
        `Set.union` Set.fromList wiredTupleCallSites
        `Set.union` Set.fromList
        [(component, path, owner, site, target)
        | (component, path, owner, site, target, _) <- lexicalBindingSiteCandidates]
      opaqueCallSites = Set.toAscList
        ((componentCallSites `Set.union` standaloneCallSites) `Set.difference` attributedCallSites)
      effectSeeds = Set.fromList
        [(component, entryPath entry, name)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (name, _, Just "IO") <- entrySignatures entry]
        `Set.union` Set.fromList
        [(component, entryPath entry, method)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (_, method, _, Just "IO") <- entryClassSignatures entry]
      callersByCallee = Map.fromListWith Set.union $
        [((targetComponent, provider, callee), Set.singleton (component, path, owner))
        | (component, path, owner, _, _, [(targetComponent, provider, callee, _)]) <- callInternalTargets]
        <> [((component, path, target), Set.singleton (component, path, owner))
           | (component, path, owner, _, _, _, target) <- lexicalAliasInternalCalls]
        <> [((targetComponent, provider, callee), Set.singleton (component, path, owner))
           | (component, path, owner, targetComponent, provider, callee) <- lexicalAliasUniqueImportedCalls]
        <> [((instanceComponent, instancePath, methodOwner),
             Set.singleton (component, path, owner))
           | (component, path, owner, _, _, _, instanceComponent,
              instancePath, _, _, _, methodOwner) <- classMethodBodyRoutes]
        <> [((instanceComponent, instancePath, methodOwner),
             Set.singleton (component, path, owner))
           | (component, path, owner, _, _, _, _, _, instanceComponent,
              instancePath, _, _, _, methodOwner) <- externalClassMethodBodyRoutes]
      potentialEffectRoutes = reverseReachable callersByCallee effectSeeds
      importedReferenceSiteCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, targetComponent, provider, referent, importName importRef)
        | entry <- modules
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , (owner, target, site, lexical) <- entryReferences entry
        , not lexical
        , importRef <- entryImports entry
        , importPackageFree importRef
        , Just referent <- [importedCallName importRef target]
        , (importComponent, importedPath) <- candidates component (importName importRef)
        , Just providerEntry <- [Map.lookup importedPath byPath]
        , (targetComponent, provider, _) <- exportedTargets importComponent importedPath referent Set.empty
        , Just physicalEntry <- [Map.lookup provider byPath]
        , importPermits importRef providerEntry referent || importPermits importRef physicalEntry referent]
      importedReferenceCandidates = Set.toAscList . Set.fromList $
        [(component, path, owner, targetComponent, provider, referent, imported)
        | (component, path, owner, _, targetComponent, provider, referent, imported) <- importedReferenceSiteCandidates]
      recordUseSites =
        [(entry, owner, site, field, "get")
        | entry <- modules, (owner, site, _, field) <- entryRecordFields entry]
        <> [(entry, owner, site, field, "projection")
           | entry <- modules, (owner, site, field) <- entryProjections entry]
      recordSelectorCandidates = Set.toAscList . Set.fromList $
        [(component, entryPath entry, owner, site, kind, field,
          component, entryPath entry, symbolType symbols, "local")
        | (entry, owner, site, field, kind) <- recordUseSites
        , component <- Map.findWithDefault [] (entryPath entry) componentMap
        , symbols <- entryData entry, field `elem` symbolSelectors symbols]
        <> [(component, entryPath entry, owner, site, kind, field,
             targetComponent, provider, symbolType symbols, importName importRef)
           | (entry, owner, site, field, kind) <- recordUseSites
           , component <- Map.findWithDefault [] (entryPath entry) componentMap
           , importRef <- entryImports entry, importPackageFree importRef
           , (importComponent, importedPath) <- candidates component (importName importRef)
           , (targetComponent, provider, _) <- exportedTargets importComponent importedPath field Set.empty
           , Just targetEntry <- [Map.lookup provider byPath]
           , symbols <- entryData targetEntry, field `elem` symbolSelectors symbols]
  compilerRejections <- observeRejectedNegativeCalls root modules byModuleName
    [(path, owner, site, target)
    | ("-", path, owner, site, target) <- opaqueCallSites]
  let rejectedCallKeys = Set.fromList
        [(path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- compilerRejections]
      closedExportRefusalKeys = Set.fromList
        [(path, owner, site, target)
        | (path, owner, site, target, _, _, _) <- standaloneClosedExportRefusals]
  pure
    ( interfaceFindings <> [finding | Left finding <- parsed]
        <> [LayoutFinding "ModuleDeclarationPathMismatch" (entryPath entry)
           | entry <- modules
           , Map.member (entryPath entry) componentMap
           , entryName entry /= "Main"
           , let expected = modulePath (entryName entry)
           , entryPath entry /= expected
           , not (('/' : expected) `isSuffixOf` entryPath entry)]
        <> [LayoutFinding "AmbiguousSourceImport" (Text.unpack component <> ":" <> consumer <> ":" <> Text.unpack imported)
           | (component, consumer, imported, providers) <- links, length providers > 1]
        <> [LayoutFinding "InternalImportDependencyMissing"
              (Text.unpack component <> ":" <> consumer <> ":" <> Text.unpack imported)
           | (component, consumer, imported, "internal-not-declared") <- unresolved]
        <> [LayoutFinding "AmbiguousPackageImport"
              (Text.unpack component <> ":" <> consumer <> ":" <> Text.unpack imported)
           | (component, consumer, imported, "external-ambiguous") <- unresolved],
      "graph-stage\tpartial-calls" : interfaceRows
        <> concatMap renderEntry modules
        <> [Text.intercalate "\t" ["graph-component", Text.pack path, component]
           | (path, components) <- Map.toAscList componentMap, component <- components]
        <> [Text.intercalate "\t" ["graph-no-component", Text.pack (entryPath entry)]
           | entry <- modules, Map.notMember (entryPath entry) componentMap]
        <> [Text.intercalate "\t" ["graph-link", component, Text.pack consumer, targetComponent, Text.pack provider, imported]
           | (component, consumer, imported, [(targetComponent, provider)]) <- links]
        <> [Text.intercalate "\t" ["graph-import-external", component,
             Text.pack consumer, imported, package, unit]
           | (component, consumer, imported, package, unit) <- externalLinks]
        <> [Text.intercalate "\t" ["graph-import-implicit-prelude", component,
             Text.pack consumer, package, unit]
           | (component, consumer, package, unit) <- implicitPreludeImports]
        <> [Text.intercalate "\t" ["graph-import-implicit-prelude-available", component,
             Text.pack consumer, package, unit]
           | (component, consumer, package, unit) <- availablePreludeImports]
        <> [Text.intercalate "\t" ["graph-import-implicit-prelude-standalone",
             Text.pack path, package, unit]
           | (path, package, unit) <- standalonePreludeImports]
        <> [Text.intercalate "\t" ["graph-import-unselected-unit-candidate", component,
             Text.pack consumer, imported, package, unit]
           | (component, consumer, imported, package, unit) <- unselectedLinks]
        <> [Text.intercalate "\t" ["graph-import-available-unit", component,
             Text.pack consumer, imported, package, unit]
           | (component, consumer, imported, package, unit) <- resolvedUnselectedLinks]
        <> [Text.intercalate "\t" ["graph-import-standalone-available-unit",
             Text.pack path, imported, package, unit]
           | (path, imported, package, unit) <- standaloneAvailableLinks]
        <> [Text.intercalate "\t" ["graph-import-standalone-registered-only-unit",
             Text.pack path, imported, package, unit]
           | (path, imported, package, unit) <- standaloneRegisteredOnlyLinks]
        <> [Text.intercalate "\t" ["graph-import-forward-owned", component,
             Text.pack consumer, imported, Text.pack expectedPath, role]
           | (component, consumer, imported, expectedPath, role) <- forwardLinks]
        <> [Text.intercalate "\t" ["graph-import-deferred-seed", component,
             Text.pack consumer, imported, package, owner]
           | (component, consumer, imported, package, owner) <- deferredSeedLinks]
        <> [Text.intercalate "\t" ["graph-import-unresolved", component, Text.pack consumer, imported, reason]
           | (component, consumer, imported, reason) <- unresolved]
        <> [Text.intercalate "\t" ["graph-import-inaccessible-internal", component,
             Text.pack consumer, imported, providerComponent, Text.pack providerPath]
           | (component, consumer, imported, "internal-not-declared") <- unresolved
           , (providerComponent, providerPath) <- Map.findWithDefault [] imported byName]
        <> [Text.intercalate "\t" ["graph-call-local-candidate", component, Text.pack path, owner,
             component, Text.pack path, target]
           | (component, path, owner, target) <- localCallCandidates]
        <> [Text.intercalate "\t" ["graph-call-site-local-candidate", component, Text.pack path, owner, site,
             component, Text.pack path, target]
           | (component, path, owner, site, target) <- localCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-local-candidate", Text.pack path,
             owner, site, target]
           | (path, owner, site, target) <- standaloneLocalCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-lexical-candidate", Text.pack path,
             owner, site, target, binderSite]
           | (path, owner, site, target, binderSite) <- standaloneLexicalCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-imported-candidate", Text.pack path,
             owner, site, target, imported, Text.pack provider, callee]
           | (path, owner, site, target, imported, provider, callee) <- standaloneImportedCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-source-denied", Text.pack path,
             owner, site, target, imported, Text.pack provider, callee, reason]
           | (path, owner, site, target, imported, provider, callee, reason)
               <- standaloneDeniedSourceCallSites]
        <> [Text.intercalate "\t" ["graph-call-standalone-closed-export-refused",
             Text.pack path, owner, site, target, imported, Text.pack provider, callee]
           | (path, owner, site, target, imported, provider, callee)
               <- standaloneClosedExportRefusals]
        <> [Text.intercalate "\t" ["graph-instance-method-source-contract", Text.pack path,
             headText, className, method, Text.pack provider, imported]
           | (path, headText, className, method, provider, imported) <- instanceSourceContracts]
        <> [Text.intercalate "\t" ["graph-instance-method-external-contract", Text.pack path,
             headText, className, method, imported, package, unit, mode]
           | (path, headText, className, method, imported, package, unit, mode)
               <- instanceExternalContracts]
        <> [Text.intercalate "\t" ["graph-derived-class-member-candidate", Text.pack path,
             typeName, classText, classHead, strategy, imported, package, unit, member, mode]
           | (path, typeName, classText, classHead, strategy, imported,
              package, unit, member, mode) <- derivedClassMemberCandidates]
        <> [Text.intercalate "\t" ["graph-standalone-deriving-member-candidate", Text.pack path,
             instanceType, classHead, strategy, imported, package, unit, member, mode]
           | (path, instanceType, classHead, strategy, imported, package, unit, member, mode)
               <- standaloneDerivingMemberCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-external-candidate", Text.pack path,
             owner, site, target, imported, package, unit, callee]
           | (path, owner, site, target, imported, package, unit, callee) <- standaloneExternalCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-registered-only-candidate", Text.pack path,
             owner, site, target, imported, package, unit, callee]
           | (path, owner, site, target, imported, package, unit, callee)
               <- standaloneRegisteredOnlyCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-standalone-external-member-candidate", Text.pack path,
             owner, site, target, imported, package, unit, parent, callee]
           | (path, owner, site, target, imported, package, unit, parent, callee) <- standaloneExternalMemberCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-candidate", component, Text.pack path, owner,
             targetComponent, Text.pack provider, callee, imported]
           | (component, path, owner, targetComponent, provider, callee, imported) <- importedCallCandidates]
        <> [Text.intercalate "\t" ["graph-call-site-candidate", component, Text.pack path, owner, site,
             targetComponent, Text.pack provider, callee, imported]
           | (component, path, owner, site, _, targetComponent, provider, callee, imported) <- importedCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-unique-internal", component, Text.pack path, owner, site,
             target, targetComponent, Text.pack provider, callee, relation]
           | (component, path, owner, site, target, [(targetComponent, provider, callee, relation)]) <- callInternalTargets]
        <> [Text.intercalate "\t" ["graph-class-call-dispatch-candidate", component,
             Text.pack path, owner, site, target, Text.pack classProvider,
             Text.pack instancePath, headText, className, method]
           | (component, path, owner, site, target, classProvider,
              instancePath, headText, className, method) <- classCallDispatchCandidates]
        <> [Text.intercalate "\t" ["graph-class-method-body-potential", component,
             Text.pack path, owner, site, target, Text.pack classProvider,
             instanceComponent, Text.pack instancePath, headText, className, method,
             methodOwner]
           | (component, path, owner, site, target, classProvider,
              instanceComponent, instancePath, headText, className, method,
              methodOwner) <- classMethodBodyRoutes]
        <> [Text.intercalate "\t" ["graph-external-class-method-body-potential",
             component, Text.pack path, owner, site, target, imported, package, unit,
             instanceComponent, Text.pack instancePath, headText, className, method,
             methodOwner]
           | (component, path, owner, site, target, imported, package, unit,
              instanceComponent, instancePath, headText, className, method,
              methodOwner) <- externalClassMethodBodyRoutes]
        <> [Text.intercalate "\t" ["graph-call-ambiguous-internal", component, Text.pack path, owner, site,
             target, Text.pack (show (length targets))]
           | (component, path, owner, site, target, targets) <- callInternalTargets, length targets > 1]
        <> [Text.intercalate "\t" ["graph-call-external-candidate", component, Text.pack path, owner, site,
             target, imported, package, unit, callee]
           | (component, path, owner, site, target, imported, package, unit, callee) <- externalCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-external-member-candidate", component,
             Text.pack path, owner, site, target, imported, package, unit, parent, callee]
           | (component, path, owner, site, target, imported, package, unit, parent, callee) <- externalMemberCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-available-unit-candidate", component, Text.pack path, owner, site,
             target, imported, package, unit, callee]
           | (component, path, owner, site, target, imported, package, unit, callee) <- availableCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-available-member-candidate", component,
             Text.pack path, owner, site, target, imported, package, unit, parent, callee]
           | (component, path, owner, site, target, imported, package, unit, parent, callee) <- availableMemberCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-deferred-seed-candidate", component,
             Text.pack path, owner, site, target, imported, package, role, callee]
           | (component, path, owner, site, target, imported, package, role, callee) <- deferredSeedCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-prelude-candidate", component, Text.pack path, owner, site,
             target, package, unit]
           | (component, path, owner, site, target, package, unit) <- preludeCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-prelude-available-candidate", component, Text.pack path, owner, site,
             target, package, unit]
           | (component, path, owner, site, target, package, unit) <- availablePreludeCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-prelude-standalone-candidate", Text.pack path,
             owner, site, target, package, unit]
           | (path, owner, site, target, package, unit) <- standalonePreludeCallSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-wired-cons-candidate", component, Text.pack path, owner,
             site, target, wiredConsModule, wiredConsUnit]
           | (component, path, owner, site, target) <- wiredConsCallSites]
        <> [Text.intercalate "\t" ["graph-call-standalone-wired-cons-candidate", Text.pack path,
             owner, site, target, wiredConsModule, wiredConsUnit]
           | (path, owner, site, target) <- standaloneWiredConsCallSites]
        <> [Text.intercalate "\t" ["graph-call-wired-tuple-candidate", component, Text.pack path, owner,
             site, target, wiredTupleModule, wiredTupleUnit]
           | (component, path, owner, site, target) <- wiredTupleCallSites]
        <> [Text.intercalate "\t" ["graph-call-lexical-binding-candidate", component, Text.pack path,
             owner, site, target, binderSite]
           | (component, path, owner, site, target, binderSite) <- lexicalBindingSiteCandidates]
        <> [Text.intercalate "\t" ["graph-call-lexical-alias-route", component, Text.pack path,
             owner, site, binder, binderSite, target, targetKind]
           | (component, path, owner, site, binder, binderSite, target, targetKind) <- lexicalAliasRoutes]
        <> [Text.intercalate "\t" ["graph-call-lexical-alias-local-candidate", component, Text.pack path,
             owner, site, binder, binderSite, component, Text.pack path, target]
           | (component, path, owner, site, binder, binderSite, target) <- lexicalAliasInternalCalls]
        <> [Text.intercalate "\t" ["graph-call-lexical-alias-imported-candidate", component, Text.pack path,
             owner, site, binder, binderSite, target, targetComponent, Text.pack provider, callee, imported]
           | (component, path, owner, site, binder, binderSite, target,
              targetComponent, provider, callee, imported) <- lexicalAliasImportedCalls]
        <> [Text.intercalate "\t" ["graph-call-lexical-alias-external-candidate", component, Text.pack path,
             owner, site, binder, binderSite, target, imported, package, unit, callee]
           | (component, path, owner, site, binder, binderSite, target, imported, package, unit, callee)
               <- lexicalAliasExternalCalls]
        <> [Text.intercalate "\t" ["graph-call-site-opaque", component, Text.pack path, owner, site,
             target, if component == "-" then "standalone"
               else if (component, path, owner, site, target) `Set.member` lexicalCallSites
                 then "lexical" else "unattributed"]
           | (component, path, owner, site, target) <- opaqueCallSites
           , (path, owner, site, target) `Set.notMember` rejectedCallKeys
           , (path, owner, site, target) `Set.notMember` closedExportRefusalKeys]
        <> [Text.intercalate "\t" ["graph-call-compiler-rejected", Text.pack path,
             owner, site, target, Text.pack (show code), rootSite, sourceDigest]
           | (path, owner, site, target, code, rootSite, sourceDigest) <- compilerRejections]
        <> [Text.intercalate "\t" ["graph-effect-route-candidate", component, Text.pack path, owner, "IO"]
           | (component, path, owner) <- Set.toAscList potentialEffectRoutes]
        <> [Text.intercalate "\t" ["graph-reference-local-candidate", component, Text.pack path, owner,
             component, Text.pack path, target]
           | (component, path, owner, target) <- localReferenceCandidates]
        <> [Text.intercalate "\t" ["graph-reference-site-local-candidate", component, Text.pack path, owner, site,
             component, Text.pack path, target]
           | (component, path, owner, site, target) <- localReferenceSiteCandidates]
        <> [Text.intercalate "\t" ["graph-reference-candidate", component, Text.pack path, owner,
             targetComponent, Text.pack provider, referent, imported]
           | (component, path, owner, targetComponent, provider, referent, imported) <- importedReferenceCandidates]
        <> [Text.intercalate "\t" ["graph-reference-site-candidate", component, Text.pack path, owner, site,
             targetComponent, Text.pack provider, referent, imported]
           | (component, path, owner, site, targetComponent, provider, referent, imported) <- importedReferenceSiteCandidates]
        <> [Text.intercalate "\t" ["graph-record-selector-candidate", component, Text.pack path,
             owner, site, kind, field, targetComponent, Text.pack provider, parent, imported]
           | (component, path, owner, site, kind, field, targetComponent, provider, parent, imported)
               <- recordSelectorCandidates])
 where
  baseExtensions =
    [Extension.PackageImports, Extension.PatternSynonyms, Extension.TemplateHaskell,
     Extension.TemplateHaskellQuotes, Extension.ForeignFunctionInterface]
  parserOptions = parserOptionsFor baseExtensions
  parserOptionsFor extensions = mkParserOpts
    (EnumSet.fromList extensions) emptyDiagOpts extensionPragmas False False False False
  extensionPragmas = ["GHC2024", "GHC2021", "Haskell2010", "Haskell98"] <> concatMap
    (\extension -> let name = show extension in [name, "No" <> name])
    ([minBound .. maxBound] :: [Extension.Extension])
  extensionsFor options = Set.toList (foldl' apply (Set.fromList baseExtensions) options)
  apply enabled option = case stripPrefix "-XNo" option of
    Just name | Just extension <- lookup name extensionNames -> Set.delete extension enabled
    _ -> case stripPrefix "-X" option of
      Just name | Just extension <- lookup name extensionNames -> Set.insert extension enabled
      _ -> enabled
  extensionNames = [(show extension, extension)
    | extension <- ([minBound .. maxBound] :: [Extension.Extension])]
  parseSource path = do
    let absolute = root </> path
    source <- try (hGetStringBuffer absolute) :: IO (Either IOException StringBuffer)
    pure $ case source of
      Left _ -> Left (LayoutFinding "HaskellSourceUnreadable" path)
      Right buffer ->
        let options = map unLoc (snd (getOptions parserOptions buffer path))
            state = initParserState (parserOptionsFor (extensionsFor options)) buffer
              (mkRealSrcLoc (mkFastString path) 1 1)
        in case unP parseModule state of
          PFailed _ -> Left (LayoutFinding "HaskellSourceUnparsable" path)
          POk _ located ->
            let parsedModule = unLoc located
                moduleName = maybe "Main" (moduleNameString . unLoc) (hsmodName parsedModule)
                imports =
                  [let imported = Text.pack (moduleNameString (unLoc (ideclName declaration)))
                   in ImportRef
                     { importName = imported
                     , importPackageFree = case ideclPkgQual declaration of NoRawPkgQual -> True; RawPkgQual _ -> False
                     , importQualifier = maybe imported (Text.pack . moduleNameString . unLoc) (ideclAs declaration)
                     , importQualifiedOnly = ideclQualified declaration /= NotQualified
                     , importSelection = case ideclImportList declaration of
                         Nothing -> Nothing
                         Just (mode, selected) -> Just (mode, unLoc selected)
                     }
                  | locatedImport <- hsmodImports parsedModule, let declaration = unLoc locatedImport]
                implicitPrelude = not (any (`elem` options)
                  ["-XNoImplicitPrelude", "-XRebindableSyntax"])
                    && not (any ((== "Prelude") . importName) imports)
                topBindings = concatMap (topLevelBindings . unLoc) (hsmodDecls parsedModule)
                nestedBindings = concatMap declarationBindings (hsmodDecls parsedModule)
                dataDeclarations = concatMap (dataSymbols . unLoc) (hsmodDecls parsedModule)
                classDeclarations = concatMap (classMethodSymbols . unLoc) (hsmodDecls parsedModule)
                classNames = concatMap (classDeclarationNames . unLoc) (hsmodDecls parsedModule)
                classDefaults = concatMap (classDefaultSymbols . unLoc) (hsmodDecls parsedModule)
                classSignatures = concatMap (classMethodSignatures . unLoc) (hsmodDecls parsedModule)
                classSuperclasses = concatMap (classSuperclassSymbols . unLoc) (hsmodDecls parsedModule)
                foreignDeclarations = concatMap foreignSymbols (hsmodDecls parsedModule)
                typeFamilies = concatMap typeFamilySymbols (hsmodDecls parsedModule)
                standaloneDeriving = concatMap standaloneDerivingSymbol (hsmodDecls parsedModule)
                classInstances = concatMap (classInstanceSymbols . unLoc) (hsmodDecls parsedModule)
                topLevel = map fst topBindings
                signatures = concatMap (topLevelSignature . unLoc) (hsmodDecls parsedModule)
                observed =
                  [(owner, observation)
                  | (owner, observations) <- topBindings <> nestedBindings
                  , observation <- observations]
                calls = [(owner, target, site, False) | (owner, DirectCall target site) <- observed]
                  <> [(owner, target, site, True) | (owner, LexicalCall target site _) <- observed]
                lexicalBindingCalls =
                  [(owner, target, site, binderSite)
                  | (owner, LexicalCall target site (Just binderSite)) <- observed]
                localBinders =
                  [(owner, name, binderSite)
                  | (owner, LocalBinding name binderSite) <- observed]
                parameterBinders =
                  [(owner, name, binderSite)
                  | (owner, ParameterBinding name binderSite) <- observed]
                localAliases =
                  [(owner, name, binderSite, target, targetKind)
                  | (owner, LocalAlias name binderSite target targetKind) <- observed]
                references = [(owner, target, site, False) | (owner, ValueReference target site) <- observed]
                  <> [(owner, target, site, True) | (owner, LexicalReference target site) <- observed]
                controls = [(owner, sourceSite, relation, targetSite)
                  | (owner, ControlEdge sourceSite relation targetSite) <- observed]
                dynamicLoads = [(owner, site, kind, target)
                  | (owner, DynamicLoad site kind target) <- observed]
                recordFields = [(owner, site, receiver, field)
                  | (owner, RecordField site receiver field) <- observed]
                projections = [(owner, site, field)
                  | (owner, RecordProjection site field) <- observed]
                gaps = [(owner, tag) | (owner, Unscanned tag) <- observed]
                declarationGaps =
                  [tag | declaration <- hsmodDecls parsedModule
                  , tag <- unscannedDeclaration (unLoc declaration)]
                exportItems = unLoc <$> hsmodExports parsedModule
                exports = exportedValueNames dataDeclarations classDeclarations <$> exportItems
                reexports = maybe [] (reexportedModuleNames . unLoc) (hsmodExports parsedModule)
            in Right (SourceEntry path (Text.pack moduleName) exports exportItems reexports imports implicitPrelude topLevel signatures calls lexicalBindingCalls localBinders parameterBinders localAliases references controls dynamicLoads recordFields projections gaps declarationGaps dataDeclarations classDeclarations classNames classDefaults classSignatures classSuperclasses foreignDeclarations typeFamilies standaloneDeriving classInstances)

reverseReachable :: Ord node => Map.Map node (Set.Set node) -> Set.Set node -> Set.Set node
reverseReachable predecessors seeds = visit seeds (Set.toList seeds)
 where
  visit reached [] = reached
  visit reached (node : remaining) =
    let fresh = Map.findWithDefault Set.empty node predecessors `Set.difference` reached
    in visit (reached `Set.union` fresh) (Set.toList fresh <> remaining)

reachableComponents :: ComponentDependencyMap -> Text -> Set.Set Text
reachableComponents dependencies start = visit Set.empty [start]
 where
  visit reached [] = reached
  visit reached (component : remaining)
    | component `Set.member` reached = visit reached remaining
    | otherwise = visit (Set.insert component reached)
        (Map.findWithDefault [] component dependencies <> remaining)

data ImportRef = ImportRef
  { importName :: Text
  , importPackageFree :: Bool
  , importQualifier :: Text
  , importQualifiedOnly :: Bool
  , importSelection :: Maybe (ImportListInterpretation, [LIE GhcPs])
  }

data SourceEntry = SourceEntry
  { entryPath :: FilePath
  , entryName :: Text
  , entryExports :: Maybe [Text]
  , entryExportItems :: Maybe [LIE GhcPs]
  , entryReexports :: [Text]
  , entryImports :: [ImportRef]
  , entryImplicitPrelude :: Bool
  , entryTopLevel :: [Text]
  , entrySignatures :: [(Text, Text, Maybe Text)]
  , entryCalls :: [(Text, Text, Text, Bool)]
  , entryLexicalBindingCalls :: [(Text, Text, Text, Text)]
  , entryLocalBinders :: [(Text, Text, Text)]
  , entryParameterBinders :: [(Text, Text, Text)]
  , entryLocalAliases :: [(Text, Text, Text, Text, Text)]
  , entryReferences :: [(Text, Text, Text, Bool)]
  , entryControls :: [(Text, Text, Text, Text)]
  , entryDynamicLoads :: [(Text, Text, Text, Text)]
  , entryRecordFields :: [(Text, Text, Text, Text)]
  , entryProjections :: [(Text, Text, Text)]
  , entryGaps :: [(Text, Text)]
  , entryDeclarationGaps :: [Text]
  , entryData :: [DataSymbols]
  , entryClassMethods :: [(Text, Text)]
  , entryClassNames :: [Text]
  , entryClassDefaults :: [(Text, Text)]
  , entryClassSignatures :: [(Text, Text, Text, Maybe Text)]
  , entryClassSuperclasses :: [(Text, Text)]
  , entryForeign :: [ForeignSymbol]
  , entryTypeFamilies :: [(Text, Text)]
  , entryStandaloneDeriving :: [(Text, Text, Text)]
  , entryClassInstances :: [ClassInstance]
  }

data CompilerRejection = CompilerRejection Text Int FilePath Int Int [Text]

parseCompilerRejection :: Value -> Parser CompilerRejection
parseCompilerRejection = withObject "CompilerRejection" $ \record -> do
  compilerVersion <- record .: "ghcVersion"
  severity <- record .: "severity"
  diagnosticCode <- record .: "code"
  messages <- record .: "message"
  located <- record .: "span"
  (path, line, column) <- withObject "CompilerSpan" (\spanRecord -> do
    path <- spanRecord .: "file"
    start <- spanRecord .: "start"
    (line, column) <- withObject "CompilerStart" (\position ->
      (,) <$> position .: "line" <*> position .: "column") start
    pure (path, line, column)) located
  if compilerVersion == ("ghc-9.12.4" :: Text) && severity == ("Error" :: Text)
    then pure (CompilerRejection severity diagnosticCode path line column messages)
    else fail "not a pinned compiler error"

observeRejectedNegativeCalls :: FilePath -> [SourceEntry] -> Map.Map Text [FilePath]
  -> [(FilePath, Text, Text, Text)]
  -> IO [(FilePath, Text, Text, Text, Int, Text, Text)]
observeRejectedNegativeCalls root modules byModuleName calls = do
  absoluteRoot <- makeAbsolute root
  concat <$> mapM (observeFile absoluteRoot) (zip [1 :: Int ..] (Map.toAscList grouped))
 where
  grouped = Map.fromListWith (<>)
    [(path, [(owner, site, target)])
    | (path, owner, site, target) <- calls
    , "test/negative/" `isPrefixOf` path
        || "test/fixture/chain_boundary/compilefail/" `isPrefixOf` path]
  entries = Map.fromList [(entryPath entry, entry) | entry <- modules]
  sourceRoot entry = iterate takeDirectory (entryPath entry)
    !! length (Text.splitOn "." (entryName entry))
  reachable seen [] = seen
  reachable seen (path : rest)
    | path `Set.member` seen = reachable seen rest
    | otherwise = case Map.lookup path entries of
        Nothing -> reachable seen rest
        Just entry ->
          let providers =
                [provider
                | importRef <- entryImports entry
                , importPackageFree importRef
                , [provider] <- [Map.findWithDefault [] (importName importRef) byModuleName]]
          in reachable (Set.insert path seen) (rest <> providers)
  observeFile absoluteRoot (index, (path, fileCalls)) = do
    let sourcePath = absoluteRoot </> path
        outputDir = absoluteRoot </> ".build/layout-source-rejections" </> show index
        sourceRoots = Set.toAscList (Set.fromList
          [absoluteRoot </> sourceRoot entry
          | reached <- Set.toList (reachable Set.empty [path])
          , Just entry <- [Map.lookup reached entries]])
        arguments = ["exec", "--jobs=1", "--", "ghc", "-j1",
          "-fdiagnostics-as-json", "-fno-code", "-fforce-recomp", "-XGHC2024"]
          <> ["-i" <> directory | directory <- sourceRoots]
          <> ["-outputdir", outputDir, path]
        needsForwardProto = case Map.lookup path entries of
          Just entry -> any (Text.isPrefixOf "Proto." . importName) (entryImports entry)
          Nothing -> True
    if needsForwardProto then pure [] else do
      before <- try (ByteString.readFile sourcePath) :: IO (Either IOException ByteString.ByteString)
      createDirectoryIfMissing True outputDir
      observed <- try (readCreateProcessWithExitCode
        ((proc "cabal" arguments) {cwd = Just absoluteRoot}) "")
        :: IO (Either SomeException (ExitCode, String, String))
      after <- try (ByteString.readFile sourcePath) :: IO (Either IOException ByteString.ByteString)
      pure $ case (before, observed, after) of
        (Right first, Right (ExitFailure _, _, compilerStderr), Right lastBytes)
          | first == lastBytes
          , Right [CompilerRejection _ code diagnosticPath line column messages] <-
              traverse (\textLine -> eitherDecodeStrict' (TextEncoding.encodeUtf8 textLine)
                >>= parseEither parseCompilerRejection)
                (filter (not . Text.null) (Text.lines (Text.pack compilerStderr)))
          , code `elem` [1928, 88464, 76037]
          , diagnosticPath == path ->
              let position = (line, column)
                  roots = [site
                    | (_, site, target) <- fileCalls
                    , siteStartsAt position site
                    , diagnosticNamesTarget code target messages]
                  selectedRoot = case sort
                    [(end, site) | site <- roots, Just (_, end) <- [parseSite site]] of
                      [] -> []
                      ordered -> [snd (last ordered)]
                  sourceDigest = sha256Text first
              in Set.toAscList . Set.fromList $
                [(path, owner, site, target, code, rootSite, sourceDigest)
                | (owner, site, target) <- fileCalls
                , rootSite <- selectedRoot
                , siteContainedBy site rootSite
                , any (\(rootOwner, observedSite, _) ->
                    rootOwner == owner && observedSite == rootSite) fileCalls]
        _ -> []
  diagnosticNamesTarget code target messages = case messages of
    first : _
      | code == 1928 -> ("type constructor `" <> target <> "'") `Text.isInfixOf` first
      | code == 88464 -> ("not in scope" `Text.isInfixOf` Text.toLower first)
          && target `Text.isInfixOf` first
      | code == 76037 -> ("Not in scope: `" <> target <> "'") `Text.isInfixOf` first
    _ -> False
  siteStartsAt position site = case parseSite site of
    Just (start, _) -> start == position
    Nothing -> False
  siteContainedBy site rootSite = case (parseSite site, parseSite rootSite) of
    (Just (start, end), Just (rootStart, rootEnd)) -> rootStart <= start && end <= rootEnd
    _ -> False
  parseSite :: Text -> Maybe ((Int, Int), (Int, Int))
  parseSite site = case Text.splitOn "-" site of
    [start, end] -> (,) <$> parsePosition start <*> parsePosition end
    _ -> Nothing
  parsePosition :: Text -> Maybe (Int, Int)
  parsePosition position = case Text.splitOn ":" position of
    [line, column] -> (,) <$> readInt line <*> readInt column
    _ -> Nothing
  readInt value = case reads (Text.unpack value) of
    [(number, "")] -> Just number
    _ -> Nothing
  sha256Text = Text.pack . concatMap (\byte ->
    [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)])
    . ByteString.unpack . SHA256.hash

data ScanObservation
  = DirectCall Text Text
  | LexicalCall Text Text (Maybe Text)
  | LocalBinding Text Text
  | ParameterBinding Text Text
  | LocalAlias Text Text Text Text
  | ValueReference Text Text
  | LexicalReference Text Text
  | ControlEdge Text Text Text
  | DynamicLoad Text Text Text
  | RecordField Text Text Text
  | RecordProjection Text Text
  | Unscanned Text

data DataSymbols = DataSymbols
  { symbolType :: Text
  , symbolConstructors :: [Text]
  , symbolSelectors :: [Text]
  , symbolDeriving :: Bool
  , symbolDerivedTypes :: [(Text, Text, Text)]
  }

data ForeignSymbol = ForeignSymbol
  { foreignName :: Text
  , foreignKind :: Text
  , foreignTarget :: Text
  , foreignSite :: Text
  }

data ClassInstance = ClassInstance
  { instanceHead :: Text
  , instanceClass :: Text
  , instanceMethods :: [Text]
  }

entryValueNames :: SourceEntry -> [Text]
entryValueNames entry =
  entryTopLevel entry
    <> concatMap symbolConstructors (entryData entry)
    <> concatMap symbolSelectors (entryData entry)
    <> map snd (entryClassMethods entry)
    <> map foreignName (entryForeign entry)

-- An explicit export list can refute a name only when every child-expanding
-- item is backed by a declaration in this module. Imported open children or
-- module reexports leave the export boundary unresolved here.
closedExportExcludes :: SourceEntry -> Text -> Bool
closedExportExcludes entry name = case entryExportItems entry of
  Nothing -> False
  Just items ->
    null (entryReexports entry)
      && all bounded (map unLoc items)
      && name `notElem` exportedValueNames
        (entryData entry) (entryClassMethods entry) items
 where
  bounded exportItem = case exportItem of
    IEThingAll _ wrapped _ -> locallyDeclared (wrappedNameText wrapped)
    IEThingWith _ wrapped _ _ _ -> locallyDeclared (wrappedNameText wrapped)
    IEModuleContents {} -> False
    _ -> True
  locallyDeclared parent =
    any ((== parent) . symbolType) (entryData entry)
      || any ((== parent) . fst) (entryClassMethods entry)

explicitImportMentions :: ImportRef -> Text -> Bool
explicitImportMentions importRef name = case importSelection importRef of
  Just (Exactly, selected) -> any (mentions . unLoc) selected
  _ -> False
 where
  mentions item = case item of
    IEVar _ wrapped _ -> wrappedNameText wrapped == name
    IEThingAbs _ wrapped _ -> wrappedNameText wrapped == name
    IEThingAll _ wrapped _ -> wrappedNameText wrapped == name
    IEThingWith _ wrapped _ children _ ->
      wrappedNameText wrapped == name || name `elem` map wrappedNameText children
    _ -> False

topLevelBindings :: HsDecl GhcPs -> [(Text, [ScanObservation])]
topLevelBindings declaration = case declaration of
  ValD _ binding -> bindingObservations "" binding
  _ -> []

topLevelSignature :: HsDecl GhcPs -> [(Text, Text, Maybe Text)]
topLevelSignature declaration = case declaration of
  SigD _ (TypeSig _ names signature) ->
    let body = sig_body (unLoc (hswc_body signature))
    in [(renderRdr (unLoc name), renderType body, effectHead body)
       | name <- names]
  _ -> []

-- A parsed result head is a potential-effect seed, not a resolved effect route.
effectHead :: LHsType GhcPs -> Maybe Text
effectHead located = case unLoc located of
  HsForAllTy {hst_body = body} -> effectHead body
  HsQualTy {hst_body = body} -> effectHead body
  HsFunTy _ _ _ result -> effectHead result
  HsAppTy _ constructor _ -> typeHead constructor
  HsParTy _ inner -> effectHead inner
  HsKindSig _ inner _ -> effectHead inner
  HsDocTy _ inner _ -> effectHead inner
  HsBangTy _ _ inner -> effectHead inner
  _ -> typeHead located
 where
  typeHead expression = case unLoc expression of
    HsTyVar _ _ name | renderRdr (unLoc name) `elem` ["IO", "GHC.Types.IO"] -> Just "IO"
    HsAppTy _ constructor _ -> typeHead constructor
    HsParTy _ inner -> typeHead inner
    _ -> Nothing

declarationBindings :: LHsDecl GhcPs -> [(Text, [ScanObservation])]
declarationBindings located = case unLoc located of
  TyClD _ ClassDecl {tcdLName = className, tcdMeths = methods} ->
    concatMap (bindingObservations ("class[" <> renderRdr (unLoc className) <> "].") . unLoc) methods
  InstD _ ClsInstD {cid_inst = instanceDecl} ->
    let instanceName = Text.unwords (Text.words (Text.pack (showSDocUnsafe (ppr (cid_poly_ty instanceDecl)))))
    in concatMap (bindingObservations ("instance[" <> instanceName <> "].") . unLoc) (cid_binds instanceDecl)
  SpliceD _ (SpliceDecl _ splice _) ->
    [("module-splice", scanSplice Map.empty (sourceSpanText splice) (unLoc splice))]
  _ -> []

bindingObservations :: Text -> HsBindLR GhcPs GhcPs -> [(Text, [ScanObservation])]
bindingObservations prefix binding = case binding of
  FunBind {fun_id = name, fun_matches = matches} ->
    [(prefix <> renderRdr (unLoc name), scanMatches Map.empty matches)]
  PatBind {pat_lhs = pattern_, pat_rhs = rightHandSides} ->
    [(prefix <> renderRdr name, scanGRHSs Map.empty rightHandSides)
    | name <- collectPatBinders CollNoDictBinders pattern_]
  _ -> []

unscannedDeclaration :: HsDecl GhcPs -> [Text]
unscannedDeclaration declaration = case declaration of
  TyClD _ typeDecl -> case typeDecl of
    FamDecl {} -> []
    SynDecl {} -> []
    DataDecl {tcdDataDefn = definition}
      | null (dd_derivs definition) -> []
      | otherwise -> ["DataDerivingDispatch"]
    ClassDecl {tcdSigs = signatures, tcdMeths = methods,
               tcdATs = associatedTypes, tcdATDefs = associatedDefaults,
               tcdFDs = dependencies}
      | null methods && null associatedTypes && null associatedDefaults
          && null dependencies && all isMethodSignature signatures -> []
      | otherwise -> ["ClassDispatch"]
  InstD _ instanceDecl -> case instanceDecl of
    ClsInstD {} -> ["InstanceDispatch"]
    DataFamInstD {} -> ["DataFamily"]
    TyFamInstD {} -> ["TypeFamilyInstance"]
  DerivD {} -> ["Deriving"]
  ForD {} -> []
  AnnD {} -> ["Annotation"]
  RuleD {} -> ["Rule"]
  SpliceD {} -> ["Splice"]
  _ -> []
 where
  isMethodSignature located = case unLoc located of
    ClassOpSig {} -> True
    _ -> False

dataSymbols :: HsDecl GhcPs -> [DataSymbols]
dataSymbols declaration = case declaration of
  TyClD _ DataDecl {tcdLName = typeName, tcdDataDefn = definition} ->
    let constructors = map unLoc (toList (dd_cons definition))
    in [DataSymbols
      { symbolType = renderRdr (unLoc typeName)
      , symbolConstructors = concatMap constructorNames constructors
      , symbolSelectors = concatMap selectorNames constructors
      , symbolDeriving = not (null (dd_derivs definition))
      , symbolDerivedTypes = derivingSymbols definition
      }]
  _ -> []

classMethodSymbols :: HsDecl GhcPs -> [(Text, Text)]
classMethodSymbols declaration = case declaration of
  TyClD _ ClassDecl {tcdLName = className, tcdSigs = signatures, tcdMeths = defaults} ->
    let owner = renderRdr (unLoc className)
        names = [renderRdr (unLoc name)
          | signature <- signatures
          , ClassOpSig _ _ methods _ <- [unLoc signature]
          , name <- methods]
          <> concatMap (bindingNames . unLoc) defaults
    in [(owner, name) | name <- Set.toAscList (Set.fromList names)]
  _ -> []

classDeclarationNames :: HsDecl GhcPs -> [Text]
classDeclarationNames declaration = case declaration of
  TyClD _ ClassDecl {tcdLName = className} -> [renderRdr (unLoc className)]
  _ -> []

classDefaultSymbols :: HsDecl GhcPs -> [(Text, Text)]
classDefaultSymbols declaration = case declaration of
  TyClD _ ClassDecl {tcdLName = className, tcdMeths = defaults} ->
    [(renderRdr (unLoc className), method)
    | method <- Set.toAscList (Set.fromList (concatMap (bindingNames . unLoc) defaults))]
  _ -> []

classMethodSignatures :: HsDecl GhcPs -> [(Text, Text, Text, Maybe Text)]
classMethodSignatures declaration = case declaration of
  TyClD _ ClassDecl {tcdLName = className, tcdSigs = signatures} ->
    [(renderRdr (unLoc className), renderRdr (unLoc method), renderType body,
      effectHead body)
    | located <- signatures
    , ClassOpSig _ _ methods signature <- [unLoc located]
    , let body = sig_body (unLoc signature)
    , method <- methods]
  _ -> []

classSuperclassSymbols :: HsDecl GhcPs -> [(Text, Text)]
classSuperclassSymbols declaration = case declaration of
  TyClD _ ClassDecl {tcdLName = className, tcdCtxt = context} ->
    [(renderRdr (unLoc className), renderType superclass)
    | superclass <- maybe [] unLoc context]
  _ -> []

classInstanceSymbols :: HsDecl GhcPs -> [ClassInstance]
classInstanceSymbols declaration = case declaration of
  InstD _ ClsInstD {cid_inst = instanceDecl} ->
    let signature = cid_poly_ty instanceDecl
        headText = renderType signature
        methods = Set.toAscList (Set.fromList
          (concatMap (bindingNames . unLoc) (cid_binds instanceDecl)))
    in [ClassInstance headText className methods
       | Just className <- [typeConstructorHead (sig_body (unLoc signature))]]
  _ -> []

typeConstructorHead :: LHsType GhcPs -> Maybe Text
typeConstructorHead located = case unLoc located of
  HsForAllTy {hst_body = body} -> typeConstructorHead body
  HsQualTy {hst_body = body} -> typeConstructorHead body
  HsAppTy _ constructor _ -> typeConstructorHead constructor
  HsAppKindTy _ constructor _ -> typeConstructorHead constructor
  HsParTy _ body -> typeConstructorHead body
  HsTyVar _ _ name -> Just (renderRdr (unLoc name))
  _ -> Nothing

constructorNames :: ConDecl GhcPs -> [Text]
constructorNames constructor = case constructor of
  ConDeclH98 {con_name = name} -> [renderRdr (unLoc name)]
  ConDeclGADT {con_names = names} -> map (renderRdr . unLoc) (NonEmpty.toList names)

selectorNames :: ConDecl GhcPs -> [Text]
selectorNames constructor = case constructor of
  ConDeclH98 {con_args = RecCon fields} -> fieldNames (unLoc fields)
  ConDeclGADT {con_g_args = RecConGADT _ fields} -> fieldNames (unLoc fields)
  _ -> []
 where
  fieldNames fields =
    [renderRdr (unLoc (foLabel (unLoc name)))
    | field <- fields
    , name <- cd_fld_names (unLoc field)]

derivingSymbols :: HsDataDefn GhcPs -> [(Text, Text, Text)]
derivingSymbols definition =
  [(renderType body, classHead, strategyName (deriv_clause_strategy clause))
  | locatedClause <- dd_derivs definition
  , let clause = unLoc locatedClause
  , signature <- case unLoc (deriv_clause_tys clause) of
      DctSingle _ single -> [single]
      DctMulti _ multiple -> multiple
  , let body = sig_body (unLoc signature)
  , let classHead = maybe "unresolved" id (typeConstructorHead body)]

standaloneDerivingSymbol :: LHsDecl GhcPs -> [(Text, Text, Text)]
standaloneDerivingSymbol located = case unLoc located of
  DerivD _ declaration ->
    [(renderType signature, maybe "unresolved" id
        (typeConstructorHead (sig_body (unLoc (hswc_body signature)))),
      strategyName (deriv_strategy declaration))]
    where signature = deriv_type declaration
  _ -> []

strategyName :: Maybe (GenLocated l (DerivStrategy GhcPs)) -> Text
strategyName Nothing = "inferred"
strategyName (Just located) = case unLoc located of
  StockStrategy {} -> "stock"
  AnyclassStrategy {} -> "anyclass"
  NewtypeStrategy {} -> "newtype"
  ViaStrategy {} -> "via"

renderType :: Outputable a => a -> Text
renderType = Text.unwords . Text.words . Text.pack . showSDocUnsafe . ppr

foreignSymbols :: LHsDecl GhcPs -> [ForeignSymbol]
foreignSymbols located = case unLoc located of
  ForD _ declaration -> case declaration of
    ForeignImport {fd_name = name, fd_fi = CImport _ _ _ _ specification} ->
      [ForeignSymbol (renderRdr (unLoc name)) "import" (importTarget specification) (sourceSpanText located)]
    ForeignExport {fd_name = name, fd_fe = CExport _ exportSpec} ->
      [ForeignSymbol (renderRdr (unLoc name)) "export" (exportTarget (unLoc exportSpec)) (sourceSpanText located)]
  _ -> []
 where
  importTarget specification = case specification of
    CLabel label -> Text.pack (unpackFS label)
    CFunction target -> case target of
      StaticTarget _ label _ _ -> Text.pack (unpackFS label)
      DynamicTarget -> "dynamic"
    CWrapper -> "wrapper"
  exportTarget (CExportStatic _ label _) = Text.pack (unpackFS label)

typeFamilySymbols :: LHsDecl GhcPs -> [(Text, Text)]
typeFamilySymbols located = case unLoc located of
  TyClD _ FamDecl {tcdFam = FamilyDecl {fdLName = name}} ->
    [(renderRdr (unLoc name), sourceSpanText located)]
  _ -> []

importedCallName :: ImportRef -> Text -> Maybe Text
importedCallName importRef target =
  case Text.stripPrefix (importQualifier importRef <> ".") target of
    Just name | not (Text.null name) -> Just name
    _ | not (importQualifiedOnly importRef) && not (looksQualified target) -> Just target
    _ -> Nothing

-- A dot in an operator such as (.) or (.:) is not a module separator.
-- Module qualifiers start with an uppercase identifier in Haskell source.
looksQualified :: Text -> Bool
looksQualified target = case Text.uncons target of
  Just (first, _) -> isUpper first && "." `Text.isInfixOf` target
  Nothing -> False

-- An open unqualified import needs interface evidence. Explicit and hiding
-- lists are checked syntactically here; the caller checks the actual export.
externalCallName :: ImportRef -> Text -> Maybe Text
externalCallName importRef target = do
  callee <- importedCallName importRef target
  case importSelection importRef of
    Nothing | Text.isPrefixOf (importQualifier importRef <> ".") target -> Just callee
    Just (Exactly, selected)
      | callee `elem` [wrappedNameText wrapped
                       | located <- selected, IEVar _ wrapped _ <- [unLoc located]] -> Just callee
    Just (EverythingBut, selected)
      | Just hidden <- traverse hiddenValue selected
      , callee `notElem` hidden -> Just callee
    _ -> Nothing
 where
  hiddenValue located = case unLoc located of
    IEVar _ wrapped _ -> Just (wrappedNameText wrapped)
    _ -> Nothing

-- Open unqualified imports need an exact compiler export check in addition to
-- the syntactic import. The caller performs that check against its selected
-- package unit before emitting a candidate.
externalOpenCallName :: ImportRef -> Text -> Maybe Text
externalOpenCallName importRef target = case importSelection importRef of
  Nothing | not (importQualifiedOnly importRef) && not (looksQualified target) -> Just target
  _ -> Nothing

externalMemberCallNames :: ImportRef -> Text -> [(Text, Text)]
externalMemberCallNames importRef target =
  [(parent, callee)
  | Just callee <- [importedCallName importRef target]
  , Just (Exactly, selected) <- [importSelection importRef]
  , located <- selected
  , parent <- case unLoc located of
      IEThingAll _ wrapped _ -> [wrappedNameText wrapped]
      IEThingWith _ wrapped wildcard children _
        | callee `elem` map wrappedNameText children || wildcard /= NoIEWildcard ->
            [wrappedNameText wrapped]
      _ -> []]

deferredSeedCallName :: ImportRef -> Text -> Maybe Text
deferredSeedCallName importRef target = do
  callee <- importedCallName importRef target
  case importSelection importRef of
    Just (Exactly, selected)
      | any (selectedName callee . unLoc) selected -> Just callee
    _ -> Nothing
 where
  selectedName name entry = case entry of
    IEVar _ wrapped _ -> wrappedNameText wrapped == name
    IEThingAll _ wrapped _ -> wrappedNameText wrapped == name
    IEThingWith _ wrapped _ children _ ->
      wrappedNameText wrapped == name || name `elem` map wrappedNameText children
    _ -> False

classImportPermits :: ImportRef -> Text -> Text -> Bool
classImportPermits importRef className method = case importSelection importRef of
  Nothing -> True
  Just (Exactly, selected) ->
    classTypeImportPermits importRef className
      && (any (allows . unLoc) selected || any (separateMethod . unLoc) selected)
  Just (EverythingBut, selected) -> not (any (hides . unLoc) selected)
 where
  allows entry = case entry of
    IEThingAll _ wrapped _ -> wrappedNameText wrapped == className
    IEThingWith _ wrapped wildcard children _ ->
      wrappedNameText wrapped == className
        && (wildcard /= NoIEWildcard || method `elem` map wrappedNameText children)
    _ -> False
  hides entry = case entry of
    IEVar _ wrapped _ -> wrappedNameText wrapped == method
    IEThingAbs _ wrapped _ -> wrappedNameText wrapped == className
    IEThingAll _ wrapped _ -> wrappedNameText wrapped == className
    IEThingWith _ wrapped wildcard children _ ->
      wrappedNameText wrapped == className
        && (wildcard /= NoIEWildcard || method `elem` map wrappedNameText children)
    _ -> False
  separateMethod entry = case entry of
    IEVar _ wrapped _ -> wrappedNameText wrapped == method
    _ -> False

classTypeImportPermits :: ImportRef -> Text -> Bool
classTypeImportPermits importRef className = case importSelection importRef of
  Nothing -> True
  Just (Exactly, selected) -> any (namesClass . unLoc) selected
  Just (EverythingBut, selected) -> not (any (namesClass . unLoc) selected)
 where
  namesClass entry = case entry of
    IEThingAbs _ wrapped _ -> wrappedNameText wrapped == className
    IEThingAll _ wrapped _ -> wrappedNameText wrapped == className
    IEThingWith _ wrapped _ _ _ -> wrappedNameText wrapped == className
    _ -> False

importPermits :: ImportRef -> SourceEntry -> Text -> Bool
importPermits importRef provider name = case importSelection importRef of
  Nothing -> True
  Just (Exactly, selected) -> name `elem` exportedValueNames
    (entryData provider) (entryClassMethods provider) selected
  Just (EverythingBut, selected) ->
    name `notElem` (exportedValueNames (entryData provider) (entryClassMethods provider) selected
      <> concatMap (hiddenParentName . unLoc) selected)
      && not (any (unknownChildren . unLoc) selected)
 where
  hiddenParentName entry = case entry of
    IEThingAbs _ wrapped _ -> [wrappedNameText wrapped]
    IEThingAll _ wrapped _ -> [wrappedNameText wrapped]
    IEThingWith _ wrapped _ _ _ -> [wrappedNameText wrapped]
    _ -> []
  unknownChildren entry = case entry of
    IEThingAll _ wrapped _ -> unknownType wrapped
    IEThingWith _ wrapped (IEWildcard _) _ _ -> unknownType wrapped
    _ -> False
  unknownType wrapped =
    not (any ((== wrappedNameText wrapped) . symbolType) (entryData provider))

exportedValueNames :: [DataSymbols] -> [(Text, Text)] -> [LIE GhcPs] -> [Text]
exportedValueNames dataDeclarations classMethods declarations = concatMap (namesFromIE . unLoc) declarations
 where
  namesFromIE entry = case entry of
    IEVar _ wrapped _ -> [wrappedNameText wrapped]
    IEThingAll _ wrapped _ -> symbolsForType (wrappedNameText wrapped)
    IEThingWith _ wrapped wildcard children _ ->
      [name | child <- children, let name = wrappedNameText child,
        name `elem` symbolsForType (wrappedNameText wrapped)]
        <> case wildcard of
             NoIEWildcard -> []
             IEWildcard _ -> symbolsForType (wrappedNameText wrapped)
    _ -> []
  symbolsForType typeName =
    [name | symbols <- dataDeclarations, symbolType symbols == typeName,
      name <- symbolConstructors symbols <> symbolSelectors symbols]
      <> [name | (className, name) <- classMethods, className == typeName]

reexportedModuleNames :: [LIE GhcPs] -> [Text]
reexportedModuleNames declarations =
  [Text.pack (moduleNameString (unLoc name))
  | located <- declarations, IEModuleContents _ name <- [unLoc located]]

wrappedNameText :: LIEWrappedName GhcPs -> Text
wrappedNameText wrapped = case unLoc wrapped of
  IEName _ identifier -> renderRdr (unLoc identifier)
  IEDefault _ identifier -> renderRdr (unLoc identifier)
  IEPattern _ identifier -> renderRdr (unLoc identifier)
  IEType _ identifier -> renderRdr (unLoc identifier)

-- Parsed direct applications are an intermediate inventory. The graph stage
-- remains unqualified until all expression forms and name resolution close.
data ScopeBinding = ScopeParameter Text | ScopeLocal Text

type Scope = Map.Map Text ScopeBinding

patternNames :: LPat GhcPs -> Scope
patternNames pattern_ = Map.fromList
  [(renderRdr name, ScopeParameter (sourceSpanText pattern_))
  | name <- collectPatBinders CollNoDictBinders pattern_]

parameterDeclarations :: Scope -> [ScanObservation]
parameterDeclarations names =
  [ParameterBinding name binderSite
  | (name, ScopeParameter binderSite) <- Map.toAscList names]

bindingNames :: HsBindLR GhcPs GhcPs -> [Text]
bindingNames binding = case binding of
  FunBind {fun_id = name} -> [renderRdr (unLoc name)]
  PatBind {pat_lhs = pattern_} -> Map.keys (patternNames pattern_)
  _ -> []

localNames :: HsLocalBindsLR GhcPs GhcPs -> Scope
localNames locals = case locals of
  HsValBinds _ (ValBinds _ bindings _) ->
    Map.fromList [(name, ScopeLocal (sourceSpanText binding))
      | binding <- bindings, name <- bindingNames (unLoc binding)]
  _ -> Map.empty

observeCall :: Scope -> Text -> Text -> ScanObservation
observeCall scope site target
  = case Map.lookup target scope of
      Just (ScopeLocal binderSite) -> LexicalCall target site (Just binderSite)
      Just (ScopeParameter binderSite) -> LexicalCall target site (Just binderSite)
      Nothing -> DirectCall target site

observeReference :: Scope -> Text -> Text -> ScanObservation
observeReference scope site target
  | target `Map.member` scope = LexicalReference target site
  | otherwise = ValueReference target site

sourceSpanText :: HasLoc l => GenLocated l a -> Text
sourceSpanText located = case getLocA located of
  RealSrcSpan span_ _ -> Text.pack
    (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_)
      <> "-" <> show (srcSpanEndLine span_) <> ":" <> show (srcSpanEndCol span_))
  UnhelpfulSpan _ -> "unlocated"

scanMatches :: Scope -> MatchGroup GhcPs (LHsExpr GhcPs) -> [ScanObservation]
scanMatches scope MG {mg_alts = alternatives} = concatMap scanMatch (unLoc alternatives)
 where
  scanMatch located =
    let match = unLoc located
        parameters = map patternNames (unLoc (m_pats match))
        matchScope = Map.unions parameters `Map.union` scope
    in concatMap parameterDeclarations parameters <> scanGRHSs matchScope (m_grhss match)

scanGRHSs :: Scope -> GRHSs GhcPs (LHsExpr GhcPs) -> [ScanObservation]
scanGRHSs scope GRHSs {grhssGRHSs = alternatives, grhssLocalBinds = locals} =
  let scoped = localNames locals `Map.union` scope
  in concatMap (scanGRHS scoped . unLoc) alternatives <> scanLocalBinds scope locals

scanLocalBinds :: Scope -> HsLocalBindsLR GhcPs GhcPs -> [ScanObservation]
scanLocalBinds scope locals = case locals of
  HsValBinds _ (ValBinds _ bindings _) ->
    let scoped = localNames locals `Map.union` scope
        declarations = [LocalBinding name binderSite
          | (name, ScopeLocal binderSite) <- Map.toAscList (localNames locals)]
        aliases = [LocalAlias name (sourceSpanText binding) target (aliasTargetKind scoped target)
          | binding <- bindings
          , Just (name, target) <- [simpleAliasTarget (unLoc binding)]]
    in declarations <> aliases <> concatMap (scanBinding scoped . unLoc) bindings
  EmptyLocalBinds {} -> []
  _ -> [Unscanned "LocalBinds"]

aliasTargetKind :: Scope -> Text -> Text
aliasTargetKind scope target = case Map.lookup target scope of
  Just (ScopeLocal _) -> "local-binder"
  Just (ScopeParameter _) -> "parameter"
  Nothing | looksQualified target -> "qualified"
  Nothing -> "unqualified"

-- Only a single unguarded variable expression is a direct alias. An applied
-- expression, section, or guarded binding needs separate value-flow analysis.
simpleAliasTarget :: HsBindLR GhcPs GhcPs -> Maybe (Text, Text)
simpleAliasTarget binding = case binding of
  FunBind {fun_id = name, fun_matches = matches} -> case unLoc (mg_alts matches) of
    [locatedMatch] | null (unLoc (m_pats (unLoc locatedMatch))) ->
      (renderRdr (unLoc name),) <$> simpleRhs (m_grhss (unLoc locatedMatch))
    _ -> Nothing
  PatBind {pat_lhs = pattern_, pat_rhs = rightHandSides} -> case unLoc pattern_ of
    VarPat _ name -> (renderRdr (unLoc name),) <$> simpleRhs rightHandSides
    _ -> Nothing
  _ -> Nothing
 where
  simpleRhs GRHSs {grhssGRHSs = [alternative], grhssLocalBinds = EmptyLocalBinds {}} =
    case unLoc alternative of
      GRHS _ [] body -> simpleVariable body
      _ -> Nothing
  simpleRhs _ = Nothing
  simpleVariable located = case unLoc located of
    HsVar _ name -> Just (renderRdr (unLoc name))
    HsPar _ inner -> simpleVariable inner
    _ -> Nothing

scanBinding :: Scope -> HsBindLR GhcPs GhcPs -> [ScanObservation]
scanBinding scope binding = case binding of
  FunBind {fun_matches = matches} -> scanMatches scope matches
  PatBind {pat_rhs = rightHandSides} -> scanGRHSs scope rightHandSides
  _ -> [Unscanned "Bind"]

scanGRHS :: Scope -> GRHS GhcPs (LHsExpr GhcPs) -> [ScanObservation]
scanGRHS scope (GRHS _ guards body) =
  let (guardObservations, bodyScope) = scanStatements scope guards
      guardBody = [ControlEdge (sourceSpanText lastGuard) "guard-body" (sourceSpanText body)
        | lastGuard <- take 1 (reverse guards)]
  in guardObservations <> guardBody <> scanExpr bodyScope body

scanStatements :: HasLoc l => Scope -> [GenLocated l (StmtLR GhcPs GhcPs (LHsExpr GhcPs))] -> ([ScanObservation], Scope)
scanStatements scope statements =
  let sites = map sourceSpanText statements
      edges = [ControlEdge earlier "statement-next" later | (earlier, later) <- zip sites (drop 1 sites)]
      (observations, finalScope) = foldl' step ([], scope) (map unLoc statements)
  in (edges <> observations, finalScope)
 where
  step (observations, currentScope) statement =
    let (nextObservations, nextScope) = scanStmt currentScope statement
    in (observations <> nextObservations, nextScope)

scanStmt :: Scope -> StmtLR GhcPs GhcPs (LHsExpr GhcPs) -> ([ScanObservation], Scope)
scanStmt scope statement = case statement of
  LastStmt _ body _ _ -> (scanExpr scope body, scope)
  BindStmt _ pattern_ body ->
    let names = patternNames pattern_
    in (scanExpr scope body <> parameterDeclarations names, names `Map.union` scope)
  BodyStmt _ body _ _ -> (scanExpr scope body, scope)
  LetStmt _ locals -> (scanLocalBinds scope locals, localNames locals `Map.union` scope)
  _ -> ([Unscanned "Stmt"], scope)

scanExpr :: Scope -> LHsExpr GhcPs -> [ScanObservation]
scanExpr scope located = case unLoc located of
  HsVar _ name -> [observeReference scope (sourceSpanText located) (renderRdr (unLoc name))]
  HsUnboundVar {} -> [Unscanned "UnboundVar"]
  HsOverLabel {} -> []
  HsIPVar {} -> []
  HsOverLit {} -> []
  HsLit {} -> []
  HsLam _ _ alternatives -> scanMatches scope alternatives
  HsApp _ function argument -> maybe [] (pure . observeCall scope (sourceSpanText located)) (callHead function) <> scanExpr scope function <> scanExpr scope argument
  HsAppType _ function _ -> scanExpr scope function
  OpApp _ left operator right -> maybe [] (pure . observeCall scope (sourceSpanText located)) (callHead operator) <> scanExpr scope left <> scanExpr scope right
  NegApp _ argument _ -> observeCall scope (sourceSpanText located) "negate" : scanExpr scope argument
  HsPar _ inner -> scanExpr scope inner
  SectionL _ left operator -> maybe [] (pure . observeCall scope (sourceSpanText located)) (callHead operator) <> scanExpr scope left <> scanExpr scope operator
  SectionR _ operator right -> maybe [] (pure . observeCall scope (sourceSpanText located)) (callHead operator) <> scanExpr scope operator <> scanExpr scope right
  ExplicitTuple _ arguments _ -> concatMap (scanTupArg scope) arguments
  ExplicitSum _ _ _ inner -> scanExpr scope inner
  HsCase _ scrutinee alternatives ->
    ControlEdge (sourceSpanText located) "case-scrutinee" (sourceSpanText scrutinee)
      : [ControlEdge (sourceSpanText located) "case-alternative" (sourceSpanText alternative)
        | alternative <- unLoc (mg_alts alternatives)]
      <> scanExpr scope scrutinee <> scanMatches scope alternatives
  HsIf _ condition yes no ->
    [ ControlEdge (sourceSpanText located) "if-condition" (sourceSpanText condition)
    , ControlEdge (sourceSpanText located) "if-true" (sourceSpanText yes)
    , ControlEdge (sourceSpanText located) "if-false" (sourceSpanText no)
    ] <> scanExpr scope condition <> scanExpr scope yes <> scanExpr scope no
  HsMultiIf _ alternatives ->
    [ControlEdge (sourceSpanText located) "multi-if-alternative" (sourceSpanText alternative)
      | alternative <- alternatives]
      <> concatMap (scanGRHS scope . unLoc) alternatives
  HsLet _ locals body -> scanLocalBinds scope locals <> scanExpr (localNames locals `Map.union` scope) body
  HsDo _ _ statements ->
    [ControlEdge (sourceSpanText located) "do-first" (sourceSpanText first)
      | first <- take 1 (unLoc statements)] <> fst (scanStatements scope (unLoc statements))
  ExplicitList _ items -> concatMap (scanExpr scope) items
  RecordCon {rcon_con = constructor, rcon_flds = fields} ->
    observeCall scope (sourceSpanText located) (renderRdr (unLoc constructor)) : concatMap (scanExpr scope . hfbRHS . unLoc) (rec_flds fields)
  RecordUpd {rupd_expr = subject, rupd_flds = fields} -> scanExpr scope subject <> scanRecordUpdate scope fields
  HsGetField {gf_expr = object, gf_field = field} ->
    RecordField (sourceSpanText located) (sourceSpanText object) (dotFieldName (unLoc field))
      : scanExpr scope object
  HsProjection {proj_flds = fields} ->
    [RecordProjection (sourceSpanText located) (dotFieldName field)
    | field <- NonEmpty.toList fields]
  ExprWithTySig _ inner _ -> scanExpr scope inner
  ArithSeq _ _ sequenceInfo -> observeCall scope (sourceSpanText located) (arithSeqCall sequenceInfo) : scanArithSeq scope sequenceInfo
  HsTypedBracket _ inner -> scanExpr scope inner
  HsUntypedBracket {} -> [Unscanned "UntypedBracket"]
  HsTypedSplice _ inner -> scanExpr scope inner
  HsUntypedSplice _ splice -> scanSplice scope (sourceSpanText located) splice
  HsProc {} -> [Unscanned "Proc"]
  HsStatic _ inner -> Unscanned "Static" : scanExpr scope inner
  HsPragE _ _ inner -> scanExpr scope inner
  HsEmbTy {} -> []
  HsForAll _ _ inner -> scanExpr scope inner
  HsQual _ guards inner -> concatMap (scanExpr scope) (unLoc guards) <> scanExpr scope inner
  HsFunArr _ _ left right -> scanExpr scope left <> scanExpr scope right

scanTupArg :: Scope -> HsTupArg GhcPs -> [ScanObservation]
scanTupArg scope argument = case argument of
  Present _ value -> scanExpr scope value
  Missing {} -> []

scanRecordUpdate :: Scope -> LHsRecUpdFields GhcPs -> [ScanObservation]
scanRecordUpdate scope fields = case fields of
  RegularRecUpdFields {recUpdFields = updated} ->
    concatMap (scanExpr scope . hfbRHS . unLoc) updated
  OverloadedRecUpdFields {olRecUpdFields = updated} ->
    Unscanned "OverloadedRecordUpdate" : concatMap (scanExpr scope . hfbRHS . unLoc) updated

scanArithSeq :: Scope -> ArithSeqInfo GhcPs -> [ScanObservation]
scanArithSeq scope sequenceInfo = case sequenceInfo of
  From first -> scanExpr scope first
  FromThen first second -> scanExpr scope first <> scanExpr scope second
  FromTo first lastValue -> scanExpr scope first <> scanExpr scope lastValue
  FromThenTo first second lastValue -> scanExpr scope first <> scanExpr scope second <> scanExpr scope lastValue

scanSplice :: Scope -> Text -> HsUntypedSplice GhcPs -> [ScanObservation]
scanSplice scope site splice = case splice of
  HsUntypedSpliceExpr _ expression ->
    DynamicLoad site "template-haskell-splice" (maybe "indirect" id (callHead expression))
      : scanExpr scope expression
  HsQuasiQuote _ quoter _ ->
    [DynamicLoad site "template-haskell-quasiquote" (renderRdr quoter)]

arithSeqCall :: ArithSeqInfo GhcPs -> Text
arithSeqCall sequenceInfo = case sequenceInfo of
  From {} -> "enumFrom"
  FromThen {} -> "enumFromThen"
  FromTo {} -> "enumFromTo"
  FromThenTo {} -> "enumFromThenTo"

callHead :: LHsExpr GhcPs -> Maybe Text
callHead located = case unLoc located of
  HsVar _ name -> Just (renderRdr (unLoc name))
  HsPar _ inner -> callHead inner
  HsAppType _ inner _ -> callHead inner
  HsApp _ inner _ -> callHead inner
  _ -> Nothing

renderRdr :: RdrName -> Text
renderRdr name = case name of
  Qual qualifier occurrence -> Text.pack (moduleNameString qualifier <> "." <> occNameString occurrence)
  _ -> Text.pack (occNameString (rdrNameOcc name))

dotFieldName :: DotFieldOcc GhcPs -> Text
dotFieldName (DotFieldOcc _ label) = Text.pack (unpackFS (field_label (unLoc label)))

modulePath :: Text -> FilePath
modulePath name = Text.unpack (Text.replace "." "/" name) <> ".hs"

renderEntry :: SourceEntry -> [Text]
renderEntry entry =
  Text.intercalate "\t" ["graph-file", Text.pack (entryPath entry), entryName entry]
    : [Text.intercalate "\t" ["graph-import", Text.pack (entryPath entry), importName importRef]
      | importRef <- entryImports entry]
    <> [Text.intercalate "\t" ["graph-module-reexport", Text.pack (entryPath entry), name]
       | name <- entryReexports entry]
    <> [Text.intercalate "\t" ["graph-top-level", Text.pack (entryPath entry), name]
       | name <- entryTopLevel entry]
    <> [Text.intercalate "\t" ["graph-class-method", Text.pack (entryPath entry), className, method]
       | (className, method) <- entryClassMethods entry]
    <> [Text.intercalate "\t" ["graph-class-declaration", Text.pack (entryPath entry), className]
       | className <- entryClassNames entry]
    <> [Text.intercalate "\t" ["graph-class-default", Text.pack (entryPath entry), className, method]
       | (className, method) <- entryClassDefaults entry]
    <> [Text.intercalate "\t" ["graph-class-method-signature", Text.pack (entryPath entry),
          className, method, signature]
       | (className, method, signature, _) <- entryClassSignatures entry]
    <> [Text.intercalate "\t" ["graph-class-effect-type-candidate",
          Text.pack (entryPath entry), className, method, effect, signature]
       | (className, method, signature, Just effect) <- entryClassSignatures entry]
    <> [Text.intercalate "\t" ["graph-class-superclass", Text.pack (entryPath entry),
          className, superclass]
       | (className, superclass) <- entryClassSuperclasses entry]
    <> [Text.intercalate "\t" ["graph-type-signature", Text.pack (entryPath entry), name, signature]
       | (name, signature, _) <- Set.toAscList (Set.fromList (entrySignatures entry))]
    <> [Text.intercalate "\t" ["graph-effect-type-candidate", Text.pack (entryPath entry), name, effect, signature]
       | (name, signature, Just effect) <- Set.toAscList (Set.fromList (entrySignatures entry))]
    <> [Text.intercalate "\t" ["graph-call-syntax", Text.pack (entryPath entry), owner, target]
       | (owner, target) <- Set.toAscList (Set.fromList [(owner, target) | (owner, target, _, _) <- entryCalls entry])]
    <> [Text.intercalate "\t" ["graph-call-site", Text.pack (entryPath entry), owner, site, target]
       | (owner, site, target) <- Set.toAscList (Set.fromList [(owner, site, target) | (owner, target, site, _) <- entryCalls entry])]
    <> [Text.intercalate "\t" ["graph-call-lexical", Text.pack (entryPath entry), owner, target]
       | (owner, target) <- Set.toAscList (Set.fromList [(owner, target) | (owner, target, _, True) <- entryCalls entry])]
    <> [Text.intercalate "\t" ["graph-call-site-lexical", Text.pack (entryPath entry), owner, site, target]
       | (owner, site, target) <- Set.toAscList (Set.fromList
           [(owner, site, target) | (owner, target, site, True) <- entryCalls entry])]
    <> [Text.intercalate "\t" ["graph-local-binder", Text.pack (entryPath entry), owner, name, binderSite]
       | (owner, name, binderSite) <- Set.toAscList (Set.fromList (entryLocalBinders entry))]
    <> [Text.intercalate "\t" ["graph-parameter-binder", Text.pack (entryPath entry), owner, name, binderSite]
       | (owner, name, binderSite) <- Set.toAscList (Set.fromList (entryParameterBinders entry))]
    <> [Text.intercalate "\t" ["graph-local-alias", Text.pack (entryPath entry), owner, name,
         binderSite, target, targetKind]
       | (owner, name, binderSite, target, targetKind) <- Set.toAscList (Set.fromList (entryLocalAliases entry))]
    <> [Text.intercalate "\t" ["graph-reference-syntax", Text.pack (entryPath entry), owner, target]
       | (owner, target) <- Set.toAscList (Set.fromList [(owner, target) | (owner, target, _, _) <- entryReferences entry])]
    <> [Text.intercalate "\t" ["graph-reference-site", Text.pack (entryPath entry), owner, site, target]
       | (owner, site, target) <- Set.toAscList (Set.fromList [(owner, site, target) | (owner, target, site, _) <- entryReferences entry])]
    <> [Text.intercalate "\t" ["graph-reference-lexical", Text.pack (entryPath entry), owner, target]
       | (owner, target) <- Set.toAscList (Set.fromList [(owner, target) | (owner, target, _, True) <- entryReferences entry])]
    <> [Text.intercalate "\t" ["graph-control-edge", Text.pack (entryPath entry), owner,
         sourceSite, relation, targetSite]
       | (owner, sourceSite, relation, targetSite) <- Set.toAscList (Set.fromList (entryControls entry))]
    <> [Text.intercalate "\t" ["graph-dynamic-load", Text.pack (entryPath entry), owner,
         site, kind, target]
       | (owner, site, kind, target) <- Set.toAscList (Set.fromList (entryDynamicLoads entry))]
    <> [Text.intercalate "\t" ["graph-record-field-site", Text.pack (entryPath entry), owner,
         site, receiver, field]
       | (owner, site, receiver, field) <- Set.toAscList (Set.fromList (entryRecordFields entry))]
    <> [Text.intercalate "\t" ["graph-record-projection-site", Text.pack (entryPath entry), owner,
         site, field]
       | (owner, site, field) <- Set.toAscList (Set.fromList (entryProjections entry))]
    <> [Text.intercalate "\t" ["graph-unscanned", Text.pack (entryPath entry), owner, tag]
       | (owner, tag) <- Set.toAscList (Set.fromList (entryGaps entry))]
    <> [Text.intercalate "\t" ["graph-unscanned-declaration", Text.pack (entryPath entry), tag]
       | tag <- Set.toAscList (Set.fromList (entryDeclarationGaps entry))]
    <> [Text.intercalate "\t" ["graph-data", Text.pack (entryPath entry), symbolType symbols]
       | symbols <- entryData entry]
    <> [Text.intercalate "\t" ["graph-constructor", Text.pack (entryPath entry), symbolType symbols, name]
       | symbols <- entryData entry, name <- symbolConstructors symbols]
    <> [Text.intercalate "\t" ["graph-selector", Text.pack (entryPath entry), symbolType symbols, name]
       | symbols <- entryData entry, name <- symbolSelectors symbols]
    <> [Text.intercalate "\t" ["graph-derived-type", Text.pack (entryPath entry), symbolType symbols]
       | symbols <- entryData entry, symbolDeriving symbols]
    <> [Text.intercalate "\t" ["graph-derived-instance", Text.pack (entryPath entry),
         symbolType symbols, className, strategy]
       | symbols <- entryData entry, (className, _, strategy) <- symbolDerivedTypes symbols]
    <> [Text.intercalate "\t" ["graph-derived-class-head", Text.pack (entryPath entry),
         symbolType symbols, className, classHead, strategy]
       | symbols <- entryData entry, (className, classHead, strategy) <- symbolDerivedTypes symbols]
    <> [Text.intercalate "\t" ["graph-standalone-deriving", Text.pack (entryPath entry),
         instanceType, strategy]
       | (instanceType, _, strategy) <- entryStandaloneDeriving entry]
    <> [Text.intercalate "\t" ["graph-standalone-deriving-class-head", Text.pack (entryPath entry),
         instanceType, classHead, strategy]
       | (instanceType, classHead, strategy) <- entryStandaloneDeriving entry]
    <> [Text.intercalate "\t" ["graph-instance-declaration", Text.pack (entryPath entry),
         instanceHead instance_, instanceClass instance_]
       | instance_ <- entryClassInstances entry]
    <> [Text.intercalate "\t" ["graph-instance-method", Text.pack (entryPath entry),
         instanceHead instance_, instanceClass instance_, method]
       | instance_ <- entryClassInstances entry, method <- instanceMethods instance_]
    <> [Text.intercalate "\t" ["graph-foreign-symbol", Text.pack (entryPath entry),
         foreignName symbol, foreignKind symbol, foreignTarget symbol, foreignSite symbol]
       | symbol <- entryForeign entry]
    <> [Text.intercalate "\t" ["graph-effect-sink-foreign", Text.pack (entryPath entry),
         foreignName symbol, foreignKind symbol, foreignTarget symbol, foreignSite symbol]
       | symbol <- entryForeign entry]
    <> [Text.intercalate "\t" ["graph-type-family", Text.pack (entryPath entry), name, site,
         "type-level-only"]
       | (name, site) <- entryTypeFamilies entry]
