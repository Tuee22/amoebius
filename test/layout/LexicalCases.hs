{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- Supplied whole compiler ASTs exercise the pure API; no native capture result
-- is constructed here. All cases and compiler work are executed serially.
module LexicalCases (runLexicalCases) where
import Amoebius.Internal.SourceText.Lexical qualified as Subject
import Control.Exception (SomeAsyncException,SomeException,displayException,evaluate,fromException,throwIO,try)
import Control.Monad (forM)
import Data.Data (Data,cast,gmapT,showConstr,toConstr)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import GHC.Data.EnumSet qualified as EnumSet
import GHC.Data.FastString (FastString,mkFastString)
import GHC.Data.StringBuffer (stringToStringBuffer)
import GHC.Hs (GhcPs,HsModule,HsBindLR(..),HsLocalBindsLR(..),HsValBindsLR(..))
import GHC.LanguageExtensions.Type qualified as Extension
import GHC.Parser (parseModule)
import GHC.Parser.Lexer (ParseResult(..),initParserState,mkParserOpts,unP)
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.Name.Reader (RdrName,rdrNameOcc)
import GHC.Types.SrcLoc (SrcSpan,mkRealSrcLoc,mkSrcLoc,mkSrcSpan,noSrcSpan,unLoc)
import GHC.Utils.Error (emptyDiagOpts)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

runLexicalCases :: FilePath -> IO ()
runLexicalCases directory=do
  let owner=directory </> "lexical"
  createDirectoryIfMissing True owner
  records<-forM Subject.lexicalCompatibilityExamples $ \(name,source,flavor)->do
    let tree=owner </> Text.unpack name
    written<-attempt "source" $ do
      createDirectoryIfMissing True tree
      TextIO.writeFile (tree </> "Fixture.hs") source
    outcome<-case written of
      Left problem->pure (Left problem)
      Right ()->do
        parsed<-attempt "parse" (parseFixture source)
        case parsed of
          Left problem->pure (Left problem)
          Right native->do
            observed<-attempt "queries" $ do
              let supplied=case flavor of
                    Subject.PreserveSuppliedSpans->native
                    Subject.ShareHelpfulSpans->rewriteSpans (mkSrcSpan (mkSrcLoc (mkFastString "Shared.hs") 1 1) (mkSrcLoc (mkFastString "Shared.hs") 1 2)) native
                    Subject.RemoveHelpfulSpans->rewriteSpans noSrcSpan native
                  model=Subject.prepareLexicalModule supplied
                  facts=Subject.inspectLexicalModule model
                  values=concatMap flatten (Subject.moduleRoots facts)
                  rows=[Text.pack (show (Subject.occurrenceId view,Subject.occurrencePath view,
                          Subject.occurrenceRawSpan view,Subject.occurrenceCompatibilityScope view,
                          Subject.queryFunctionSpelling occurrence,Subject.queryWholeText occurrence))
                    | occurrence<-values,let view=Subject.inspectOccurrence occurrence]
                  views=map Subject.inspectOccurrence values
                  identities=map (Text.pack.show.Subject.occurrenceId) views
                  paths=map (Text.pack.show.Subject.occurrencePath) views
                  locations=map (Text.pack.show.Subject.occurrenceRawSpan) views
              writeForced (owner </> Text.unpack name<>".data") (Text.pack (show (rows,identities,paths,locations)))
              pure facts
            case observed of
              Left problem->pure (Left problem)
              Right facts->if "empty-let." `Text.isPrefixOf` name
                then attempt "local-groups" (writeForced (owner </> Text.unpack name<>".groups.data") (Text.pack (show (groupRows facts))))
                else if "alias." `Text.isPrefixOf` name
                  then attempt "declaration-keys" (writeForced (owner </> Text.unpack name<>".declaration-keys.data") (Text.pack (show (declarationKeys facts))))
                else pure (Right ())
    writeForced (owner </> Text.unpack name<>".outcome.data")
      (Text.pack (show ("lexical-case-outcome.v1" :: Text,name,Text.pack (show flavor),outcome)))
    pure (name,Text.pack (show flavor))
  writeForced (owner </> "cases.data") (Text.pack (show records))
 where
  flatten occurrence=occurrence:concatMap flatten (Subject.occurrenceChildren (Subject.inspectOccurrence occurrence))
  groupRows facts=
    [(Text.pack (show (Subject.localGroupPath group)),Text.pack (showConstr (toConstr locals)),
      Text.pack . show <$> Subject.localGroupRecognizedScope group,bindingCount locals)
    | group<-Subject.moduleLocalGroups facts,let locals=Subject.localGroupAst group]
  bindingCount locals=case locals of
    HsValBinds _ (ValBinds _ binds _)->length binds
    _->0 :: Int
  declarationKeys facts=
    [(Text.pack (occNameString (rdrNameOcc (unLoc name))),Subject.declarationLookupKeys declaration)
    | declaration<-Subject.moduleDeclarations facts
    , FunBind {fun_id=name}<-[Subject.declarationAst declaration]]

-- Failures are observations of this case, never a successful query result.
-- Keep subsequent shipped cases and the manifest observable after a refusal.
attempt :: Text -> IO value -> IO (Either (Text,Text) value)
attempt stage action=do
  result<-try action
  case result of
    Left (problem :: SomeException)->case fromException problem :: Maybe SomeAsyncException of
      Just _->throwIO problem
      Nothing->pure (Left (stage,Text.pack (displayException problem)))
    Right value->pure (Right value)

writeForced :: FilePath -> Text -> IO ()
writeForced path contents=do
  _<-evaluate (Text.length contents)
  TextIO.writeFile path (contents<>"\n")

parseFixture :: Text -> IO (HsModule GhcPs)
parseFixture source=case unP parseModule state of
  POk _ located->pure (unLoc located)
  PFailed _->fail "SuppliedLexicalFixtureUnparsable"
 where
  options=mkParserOpts (EnumSet.fromList [Extension.OverloadedStrings]) emptyDiagOpts ["OverloadedStrings"] False False False False
  state=initParserState options (stringToStringBuffer (Text.unpack source)) (mkRealSrcLoc (mkFastString "Fixture.hs") 1 1)

-- Rebuild the whole typed value. Expression identities are subsequently derived
-- from its structural forest, even when all source locations are unhelpful.
rewriteSpans :: Data value => SrcSpan -> value -> value
rewriteSpans target value
  | Just _ <- cast value :: Maybe SrcSpan = fromMaybe (error "SuppliedSpanTypeUnavailable") (cast target)
  | Just _ <- cast value :: Maybe FastString = value
  | Just _ <- cast value :: Maybe RdrName = value
  | otherwise = gmapT (rewriteSpans target) value
