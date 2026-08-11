{-# LANGUAGE OverloadedStrings #-}
module Main(main) where
import Amoebius.Ui.Projection.Cursor
import Amoebius.Ui.Realtime.Drain
import Amoebius.Ui.ReleaseTransition
import Control.Monad(forM_,unless)
import Data.Text qualified as Text
import System.Directory(doesFileExist,getCurrentDirectory,setCurrentDirectory)
import System.Exit(die)
import System.FilePath((</>),takeDirectory)
main=do
 projectRoot>>=setCurrentDirectory; verifyCustody
 let a=TransitionState ReleaseA ReleaseA ReleaseA [ReleaseA]; bPending=beginRelease ReleaseB a
 assertEqual "hold before watermark" (Left ProjectorNotCaughtUp) (shiftGateway bPending)
 b<-either (die.show) pure (shiftGateway (observeWatermark ReleaseB bPending));assertEqual "B shifted" ReleaseB (gatewayRelease b)
 assertEqual "stale A" (Left ReloadRequired) (stalePlanDecision ReleaseA b)
 let rollback=beginRelease ReleaseA b
 assertEqual "hold rollback" (Left ProjectorNotCaughtUp) (shiftGateway rollback)
 aAgain<-either (die.show) pure (shiftGateway (observeWatermark ReleaseA rollback));assertEqual "A rollback" ReleaseA (gatewayRelease aAgain)
 let own=cursorKey "t-a" "alice" "projection";other=cursorKey "t-a" "bob" "projection";foreignTenant=cursorKey "t-b" "alice" "projection"
 assertEqual "resume" (Right (Cursor 42)) (resumeCursor own own (Just (Cursor 42)))
 assertLeft "other owner" (resumeCursor own other (Just (Cursor 42)));assertLeft "foreign tenant" (resumeCursor own foreignTenant (Just (Cursor 42)))
 let epochA=ProgramEpoch "A";drained=drainEpoch epochA (registrations [epochA,ProgramEpoch "B"])
 assert (not (routable epochA drained)) "stale registration routable"
 putStrLn "phase57-ui-rollout-reconnect: PASS-SCOPED (watermark-gated A-B-A; stale-plan reload; scoped cursor resume; registration drain; live Gateway/Pulsar/browser UNVERIFIED)"
verifyCustody=do
 rows<-lines<$>readFile "test/phase0_oracle_manifest.tsv"
 let xs=filter(Text.isPrefixOf "57\t".Text.pack) rows
 assertEqual "custody" 7(length xs)
 forM_ xs $ \r->case splitTabs r of
  (_:_:p:_)->doesFileExist p>>=flip assert("missing "<>p)
  _->die "bad custody"
assertLeft l v=case v of Left _->pure();Right _->die(l<>" success")
splitTabs s=case break(=='\t')s of(f,[])->[f];(f,_:r)->f:splitTabs r
assert c m=unless c(die m)
assertEqual l e a=unless(e==a)(die(l<>": "<>show a))
projectRoot=getCurrentDirectory>>=go where go p=do f<-doesFileExist(p</>"cabal.project");if f then pure p else let q=takeDirectory p in if q==p then die"p57-root" else go q
