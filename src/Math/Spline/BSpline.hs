{-# LANGUAGE MultiParamTypeClasses, StandaloneDeriving, FlexibleContexts, UndecidableInstances, TypeFamilies #-}
module Math.Spline.BSpline
    ( BSpline
    , bSpline
    , splitBSpline
    , derivBSpline
    ) where

import Math.Spline.Knots
import Math.Spline.BSpline.Internal

import Data.Foldable (Foldable(foldMap))
import Data.List (zipWith4)
import Data.Maybe (fromMaybe)
import Data.VectorSpace (VectorSpace(..), Scalar, (^-^), lerp)

-- |@bSpline kts cps@ creates a B-spline with the given knot vector and control 
-- points.  The degree is automatically inferred as the difference between the 
-- number of spans in the knot vector (@numKnots kts - 1@) and the number of 
-- control points (@length cps@).
bSpline :: Knots (Scalar a) -> [a] -> BSpline a
bSpline kts cps = fromMaybe (error "bSpline: too many control points") (maybeSpline kts cps)

maybeSpline :: Knots (Scalar a) -> [a] -> Maybe (BSpline a)
maybeSpline kts cps 
    | n > m     = Nothing
    | otherwise = Just (Spline (m - n) kts cps)
    where
        n = length cps
        m = numKnots kts - 1

deriving instance (Eq   (Scalar v), Eq   v) => Eq   (BSpline v)
deriving instance (Ord  (Scalar v), Ord  v) => Ord  (BSpline v)
instance (Show (Scalar v), Show v) => Show (BSpline v) where
    showsPrec p (Spline _ kts cps) = showParen (p>10) 
        ( showString "bSpline "
        . showsPrec 11 kts
        . showChar ' '
        . showsPrec 11 cps
        )

derivBSpline
  :: (VectorSpace v, Fractional (Scalar v)) => BSpline v -> BSpline v
derivBSpline spline = spline {controlPoints = ds'}
    where
        ds' = zipWith (*^) (tail cs) (zipWith (^-^) (tail ds) ds)
        
        p  = degree spline
        us = knots (knotVector spline)
        ds = controlPoints spline
        cs = [fromIntegral p / (u0 - u1) | (u0, u1) <- spans p us]

spans n xs = zip xs (drop n xs)

splitBSpline
  :: (VectorSpace v, Ord (Scalar v), Fractional (Scalar v)) =>
     BSpline v -> Scalar v -> Maybe (BSpline v, BSpline v)
splitBSpline spline@(Spline p kv ds) t 
    | inDomain  = Just (Spline p (knotsFromList us0) ds0, Spline p (knotsFromList us1) ds1)
    | otherwise = Nothing
    where
        inDomain = case knotDomain kv p of
            Nothing         -> False
            Just (t0, t1)   -> t >= t0 || t <= t1
        
        us = knots kv
        dss = deBoor spline t
        
        us0 = takeWhile (<t) us ++ replicate (p+1) t
        ds0 = trimTo (drop (p+1) us0) (map head dss)
        
        us1 = replicate (p+1) t ++ dropWhile (<=t) us
        ds1 = reverse (trimTo (drop (p+1) us1) (map last dss))

        trimTo list  xs = zipWith const xs list
