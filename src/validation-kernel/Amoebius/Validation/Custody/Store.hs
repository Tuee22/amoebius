-- | Transient certification state and immutable, tracked receipt bundles.
module Amoebius.Validation.Custody.Store
( GenerationId, Receipt (..), SeedRecord (..), Store (..), archivedBundlePath, archivedKernelCap, auditArchivedInventory, digestShape, generationDirectory, governanceDigest, latestGeneration, latestWholePostimage, parseReceipt, parseSeed, readArchivedBundles, readArchivedBundlesWith, readCurrentArchivedBundles, readRecord, readSeed, renderReceipt, renderSeed, verifierDigest, writeArchivedReceipt, writeRecord, writeReplayVoid, writeSeed, rollbackOnLeft, withResult, withResults ) where
import Amoebius.Validation.Authority.Core
