{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module FlexRecord.Json () where

import Data.Aeson (FromJSON (parseJSON), ToJSON (toJSON), object, withObject, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as Key
import Data.Aeson.Types (Object, Pair, Parser)
import Data.Kind (Type)
import Data.Proxy (Proxy (Proxy))
import FlexRecord (Field (Field), FlexRecord (FRCons, FRNil))
import GHC.TypeLits (KnownSymbol, symbolVal)

type family IsMaybe (t :: Type) :: Bool where
  IsMaybe (Maybe _) = 'True
  IsMaybe _ = 'False

class FieldToPairsImpl (isMaybe :: Bool) t where
  fieldToPairsImpl :: Key.Key -> t -> [Pair]

instance (ToJSON t) => FieldToPairsImpl 'False t where
  fieldToPairsImpl key value = [key .= value]

instance (ToJSON t) => FieldToPairsImpl 'True (Maybe t) where
  fieldToPairsImpl _ Nothing = []
  fieldToPairsImpl key (Just value) = [key .= value]

class FieldToPairs t where
  fieldToPairs :: Key.Key -> t -> [Pair]

instance (FieldToPairsImpl (IsMaybe t) t) => FieldToPairs t where
  fieldToPairs = fieldToPairsImpl @(IsMaybe t)

class FlexRecordToPairs (fs :: [Type]) where
  flexRecordToPairs :: FlexRecord fs -> [Pair]

instance FlexRecordToPairs '[] where
  flexRecordToPairs FRNil = []

instance
  ( KnownSymbol name
  , FieldToPairs t
  , FlexRecordToPairs fs
  ) =>
  FlexRecordToPairs (Field name t ': fs)
  where
  flexRecordToPairs (FRCons (Field value) rest) =
    fieldToPairs (Key.fromString (symbolVal (Proxy @name))) value ++ flexRecordToPairs rest

instance (FlexRecordToPairs fs) => ToJSON (FlexRecord fs) where
  toJSON record = object (flexRecordToPairs record)

class ParseFieldImpl (isMaybe :: Bool) t where
  parseFieldImpl :: Object -> Key.Key -> Parser t

instance (FromJSON t) => ParseFieldImpl 'False t where
  parseFieldImpl obj key = obj Aeson..: key

instance (FromJSON t) => ParseFieldImpl 'True (Maybe t) where
  parseFieldImpl obj key = obj Aeson..:? key

class ParseField t where
  parseField :: Object -> Key.Key -> Parser t

instance (ParseFieldImpl (IsMaybe t) t) => ParseField t where
  parseField = parseFieldImpl @(IsMaybe t)

class FlexRecordFromObject (fs :: [Type]) where
  parseFlexRecordObject :: Object -> Parser (FlexRecord fs)

instance FlexRecordFromObject '[] where
  parseFlexRecordObject _ = pure FRNil

instance
  ( KnownSymbol name
  , ParseField t
  , FlexRecordFromObject fs
  ) =>
  FlexRecordFromObject (Field name t ': fs)
  where
  parseFlexRecordObject obj = do
    value <- parseField obj (Key.fromString (symbolVal (Proxy @name)))
    rest <- parseFlexRecordObject obj
    pure (FRCons (Field @name value) rest)

instance (FlexRecordFromObject fs) => FromJSON (FlexRecord fs) where
  parseJSON = withObject "FlexRecord" parseFlexRecordObject
