{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.FlexRecord
  ( Field (..),
    FlexRecord (..),
    FlexEnum (..),
    NoDuplicateField,
    FlexEnumMatcher,
    frGet,
    frSet,
    frAcc,
    field,
    flexRecord,
    flexEnum,
    flexMatch,
    inCase,
  )
where

import qualified Data.Accessor as Accessor
import Data.Kind (Constraint, Type)
import GHC.TypeLits (ErrorMessage (Text, (:<>:)), Symbol, TypeError)

data Field (name :: Symbol) t where
  Field :: forall name t. t -> Field name t

data FlexRecord (fs :: [Type]) where
  FRNil :: FlexRecord '[]
  FRCons :: NoDuplicateField name xs => Field name t -> FlexRecord xs -> FlexRecord (Field name t ': xs)

data FlexEnum (fs :: [Type]) where
  FEThis :: NoDuplicateField name xs => Field name t -> FlexEnum (Field name t ': xs)
  FENext :: NoDuplicateField name xs => FlexEnum xs -> FlexEnum (Field name t ': xs)

type family GetFieldType (name :: Symbol) (fs :: [Type]) :: Type where
  GetFieldType name (Field name t ': fs) = t
  GetFieldType name (Field name' t ': fs) = GetFieldType name fs
  GetFieldType name '[] = TypeError (Text "Field don't exist")

type family FieldMatch (name :: Symbol) (fs :: [Type]) :: Bool where
  FieldMatch name (Field name t ': fs) = True
  FieldMatch name fs = False

type family NoDuplicateField (name :: Symbol) (fs :: [Type]) :: Constraint where
  NoDuplicateField name fs = NoDuplicateFieldImpl (FieldMatch name fs) name

type family NoDuplicateFieldImpl (match :: Bool) (name :: Symbol) :: Constraint where
  NoDuplicateFieldImpl True name = TypeError (Text "Duplicate field name: " :<>: Text name)
  NoDuplicateFieldImpl False name = ()

class FlexRecordImpl (fieldMatch :: Bool) (name :: Symbol) (fs :: [Type]) where
  frGetImpl :: FlexRecord fs -> GetFieldType name fs
  frSetImpl :: GetFieldType name fs -> FlexRecord fs -> FlexRecord fs

instance FlexRecordImpl True name (Field name t : fs) where
  frGetImpl (FRCons (Field v) _) = v
  frSetImpl v (FRCons _ xs) = FRCons (Field @name v) xs

instance
  ( GetFieldType name (Field name' t : fs) ~ GetFieldType name fs,
    FlexRecordImpl (FieldMatch name fs) name fs
  ) =>
  FlexRecordImpl False name (Field name' t ': fs)
  where
  frGetImpl (FRCons _ xs) = frGetImpl @(FieldMatch name fs) @name @fs xs
  frSetImpl v (FRCons f xs) = FRCons f (frSetImpl @(FieldMatch name fs) @name @fs v xs)

class FrClass (name :: Symbol) (fs :: [Type]) where
  frGet :: FlexRecord fs -> GetFieldType name fs
  frSet :: GetFieldType name fs -> FlexRecord fs -> FlexRecord fs

instance (FlexRecordImpl (FieldMatch name fs) name fs) => FrClass name fs where
  frGet = frGetImpl @(FieldMatch name fs) @name
  frSet = frSetImpl @(FieldMatch name fs) @name

frAcc :: forall name fs. (FrClass name fs)
  => Accessor.Accessor (FlexRecord fs) (GetFieldType name fs) (GetFieldType name fs)
frAcc = Accessor.accessor (frGet @name) (frSet @name)

field :: forall s a r. NoDuplicateField s r => a -> (FlexRecord r -> FlexRecord (Field s a ': r))
field val = FRCons (Field @s val)

class FlexEnumImpl matched name fs where
  flexEnumImpl :: (GetFieldType name fs) -> FlexEnum fs

instance (NoDuplicateField name xs) =>
    FlexEnumImpl True name (Field name t ': xs) where
  flexEnumImpl val = FEThis (Field @name val)

instance ( NoDuplicateField name' xs
         , GetFieldType name (Field name' t : xs) ~ GetFieldType name xs
         , FlexEnumImpl (FieldMatch name xs) name xs) =>
  FlexEnumImpl False name (Field name' t ': xs) where
  flexEnumImpl val = FENext (flexEnumImpl @(FieldMatch name xs) @name val :: FlexEnum xs)

flexEnum :: forall (name :: Symbol) xs. (FlexEnumImpl (FieldMatch name xs) name xs) => GetFieldType name xs -> FlexEnum xs
flexEnum val = flexEnumImpl @(FieldMatch name xs) @name @xs val

flexRecord :: (FlexRecord '[] -> r) -> r
flexRecord f = f FRNil

type family FlexEnumMatcher (fe :: Type) (res :: Type) :: Type where
  FlexEnumMatcher (FlexEnum fs) res = FlexRecord (FlexEnumMatcherList fs res)

type family FlexEnumMatcherList (fs :: [Type]) (res :: Type) :: [Type] where
  FlexEnumMatcherList '[] res = '[]
  FlexEnumMatcherList (Field name t ': fs) res =
    Field name (t -> res) ': FlexEnumMatcherList fs res

flexEnumMatch :: FlexEnum fs -> FlexEnumMatcher (FlexEnum fs) res -> res
flexEnumMatch (FEThis (Field val)) (FRCons (Field f) _) = f val
flexEnumMatch (FENext enum) (FRCons _ matcher) = flexEnumMatch enum matcher

inCase :: forall name t r res. NoDuplicateField name r => (t -> res) -> (FlexRecord r -> FlexRecord (Field name (t -> res) ': r))
inCase f = FRCons (Field @name f)

flexMatch :: FlexEnum fs -> ((FlexRecord '[] -> FlexRecord (FlexEnumMatcherList fs res)) -> res)
flexMatch fe builder = flexEnumMatch fe (builder FRNil)
