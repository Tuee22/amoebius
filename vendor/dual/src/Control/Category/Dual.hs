{-# LANGUAGE DerivingVia #-}

module Control.Category.Dual where

import Control.Category
import Data.Bifoldable
import Data.Bifunctor
import Data.Bitraversable
import Data.Foldable
import Data.Functor
import Data.Functor.Classes
import Data.Monoid (Monoid (..))
import Data.Semigroup (Semigroup)
import Data.Traversable
import Prelude hiding ((.), id)

newtype Dual k a b = Dual {dual :: k b a}
  deriving (Eq, Ord, Read, Show)
  deriving (Bounded, Semigroup, Monoid) via (k b a)

instance Category k => Category (Dual k) where
  id = Dual id
  Dual f . Dual g = Dual (g . f)

instance (Eq2 k, Eq a) => Eq1 (Dual k a) where
  liftEq f (Dual x) (Dual y) = liftEq2 f (==) x y

instance Eq2 k => Eq2 (Dual k) where
  liftEq2 f g (Dual x) (Dual y) = liftEq2 g f x y

instance (Ord2 k, Ord a) => Ord1 (Dual k a) where
  liftCompare f (Dual x) (Dual y) = liftCompare2 f compare x y

instance Ord2 k => Ord2 (Dual k) where
  liftCompare2 f g (Dual x) (Dual y) = liftCompare2 g f x y

instance (Read2 k, Read a) => Read1 (Dual k a) where
  liftReadsPrec rp rl =
    readsData $ readsUnaryWith (liftReadsPrec2 rp rl readsPrec readList) "Dual" Dual

instance Read2 k => Read2 (Dual k) where
  liftReadsPrec2 arp arl brp brl =
    readsData $ readsUnaryWith (liftReadsPrec2 brp brl arp arl) "Dual" Dual

instance (Show2 k, Show a) => Show1 (Dual k a) where
  liftShowsPrec sp sl n =
    showsUnaryWith (liftShowsPrec2 sp sl showsPrec showList) "Dual" n . dual

instance Show2 k => Show2 (Dual k) where
  liftShowsPrec2 asp asl bsp bsl n =
    showsUnaryWith (liftShowsPrec2 bsp bsl asp asl) "Dual" n . dual

instance Bifunctor k => Functor (Dual k b) where
  fmap = bimap id

instance Bifoldable k => Foldable (Dual k b) where
  foldMap = bifoldMap mempty

instance Bitraversable k => Traversable (Dual k b) where
  traverse = bitraverse pure

instance Bifunctor k => Bifunctor (Dual k) where
  bimap f g = Dual . bimap g f . dual

instance Bifoldable k => Bifoldable (Dual k) where
  bifold = bifold . dual
  bifoldMap f g = bifoldMap g f . dual

instance Bitraversable k => Bitraversable (Dual k) where
  bitraverse f g = fmap Dual . bitraverse g f . dual
