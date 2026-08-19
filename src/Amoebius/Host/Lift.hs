{-# LANGUAGE CPP #-}

-- | One fold from a step list to argv, for every context a step can execute in.
--
-- The same step list must run on the host, inside a VM, and inside a container. Two
-- deployment paths for one step list is how a fix reaches one substrate and not the
-- others, so there is one fold and the context is its argument.
--
-- The rule it implements is the exact boundary of the no-@PATH@ rule
-- ("substrate_doctrine.md"): __only the outermost tool is resolved to an absolute
-- path__. A nested command runs against the guest's own environment under the guest's
-- own name, which is legitimate because it is that guest's environment and not the
-- host's. The invariant is "amoebius never resolves a tool against the /host's/ PATH",
-- not "no PATH exists anywhere".
--
-- The fold creates no process and reads no environment variable, so it is a pure
-- function and testable as one.
module Amoebius.Host.Lift
  ( LiftContext (..)
  , renderLiftContext
  , liftArgv
  , liftPlan
  ) where

import Amoebius.Host.Ensure
import Amoebius.Host.Frame
import Amoebius.Host.HostTool

-- | Where a step executes.
data LiftContext
  = -- | Directly on the host. The step's own tool is the outermost one.
    OnHost
  | -- | Inside a frame, entered through the frame's own resolved entry point. The
    -- entry point is the outermost tool; the step's tool becomes a guest name.
    InFrame Frame AbsExe
  | -- | Inside a container, entered through a resolved engine.
    InContainer AbsExe String
  deriving stock (Eq, Show)

renderLiftContext :: LiftContext -> String
renderLiftContext context = case context of
  OnHost -> "on-host"
  InFrame frame _ -> "in-frame:" <> renderFrame frame
  InContainer _ image -> "in-container:" <> image

-- | The argv one step issues in one context.
--
-- @resolve@ answers where a host tool is, and is consulted only for the outermost
-- tool. @version@ answers the authored requirements. A 'VerifiedOnly' step issues no
-- argv at all: it asserts a floor member is present, which is not a command.
liftArgv
  :: LiftContext
  -> (HostTool -> Maybe AbsExe)
  -> (HostTool -> Maybe String)
  -> InstallStep
  -> Either EnsureError (Maybe [String])
liftArgv context resolve version step = case stepPerformer step of
  VerifiedOnly -> Right Nothing
  PerformedBy tool -> do
    arguments <- stepArgv version step
    fmap Just (prefixed tool arguments)
 where
  prefixed tool arguments = case context of
    OnHost -> case resolve tool of
      Nothing -> Left (MissingToolAfterInstall tool)
      Just absolute -> Right (absExePath absolute : arguments)
    -- Across a context boundary the *entry point* is the outermost tool and is the
    -- only thing resolved; the step's tool is handed on as the guest's own name.
#ifdef HOST_ENSURE_LIFT_DROPS_FRAME_PREFIX_MUTANT
    InFrame _ _ -> Right (toolCommandName tool : arguments)
#else
    InFrame _ entry -> Right (absExePath entry : "--" : toolCommandName tool : arguments)
#endif
    InContainer engine image ->
      Right (absExePath engine : "run" : "--rm" : image : toolCommandName tool : arguments)

-- | The whole plan folded once, dropping the steps that issue no argv.
liftPlan
  :: LiftContext
  -> (HostTool -> Maybe AbsExe)
  -> (HostTool -> Maybe String)
  -> [InstallStep]
  -> Either EnsureError [[String]]
liftPlan context resolve version steps = do
  rendered <- traverse (liftArgv context resolve version) steps
  pure [argv | Just argv <- rendered]
