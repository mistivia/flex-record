{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.FlexRecord
  ( Field (..),
    FlexRecord (..),
    GetFieldType,
    FieldMatch,
    FlexRecordImpl,
    frGetImpl,
    frSetImpl,
    frGet,
    frSet,
    frAcc,
    field,
    flexRecord,
  )
where

import qualified Data.Accessor as Accessor
import Data.Kind (Type)
import GHC.TypeLits (ErrorMessage (Text), Symbol, TypeError)

data Field (name :: Symbol) t where
  Field :: forall name t. t -> Field name t

data FlexRecord (fs :: [Type]) where
  FRNil :: FlexRecord '[]
  FRCons :: Field name t -> FlexRecord xs -> FlexRecord (Field name t ': xs)

type family GetFieldType (name :: Symbol) (fs :: [Type]) :: Type where
  GetFieldType name (Field name t ': fs) = t
  GetFieldType name (Field name' t ': fs) = GetFieldType name fs
  GetFieldType name '[] = TypeError (Text "Field don't exist")

type family FieldMatch (name :: Symbol) (fs :: [Type]) :: Bool where
  FieldMatch name (Field name t ': fs) = True
  FieldMatch name fs = False

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

frGet :: forall (name :: Symbol) fs. FlexRecordImpl (FieldMatch name fs) name fs => FlexRecord fs -> GetFieldType name fs
frGet = frGetImpl @(FieldMatch name fs) @name

frSet :: forall (name :: Symbol) fs. FlexRecordImpl (FieldMatch name fs) name fs => GetFieldType name fs -> FlexRecord fs -> FlexRecord fs
frSet = frSetImpl @(FieldMatch name fs) @name

frAcc :: forall (name :: Symbol) fs. FlexRecordImpl (FieldMatch name fs) name fs => Accessor.Accessor (FlexRecord fs) (GetFieldType name fs) (GetFieldType name fs)
frAcc = Accessor.accessor (frGet @name) (frSet @name)

field :: forall s a r. a -> (FlexRecord r -> FlexRecord (Field s a ': r))
field val = FRCons (Field @s val)

flexRecord :: (FlexRecord '[] -> r) -> r
flexRecord f = f FRNil
