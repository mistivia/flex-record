import Data.Accessor (dot, facc, over, set, view)
import qualified Data.Accessor as Accessor
import Data.Aeson (Value (Object), eitherDecode, encode)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.FlexRecord (Field (..), FlexRecord, FlexEnum (..), field, flexRecord, frAcc, frGet, frSet, flexEnum)
import Data.FlexRecord.Json ()
import Test.HUnit (Test (TestCase, TestList), assertEqual, assertFailure, errors, failures, runTestTT)

type Person =
  FlexRecord
    [ Field "name" String
    , Field "age" Int
    , Field "height" Float
    , Field "scores" [Int]
    ]

person :: Person
person =
  flexRecord
    $ field @"name" "uwu"
    . field @"age" 1
    . field @"height" 42.0
    . field @"scores"
      [ 10
      , 20
      , 30
      ]

type PersonMaybe =
  FlexRecord
    [ Field "name" String
    , Field "nick" (Maybe String)
    ]

personMaybeNothing :: PersonMaybe
personMaybeNothing =
  flexRecord
    $ field @"name" "uwu"
    . field @"nick" Nothing

personMaybeJust :: PersonMaybe
personMaybeJust =
  flexRecord
    $ field @"name" "uwu"
    . field @"nick" (Just "u")

ageAcc :: Accessor.Accessor Person Int Int
ageAcc = frAcc @"age"

firstScoreAcc :: Accessor.Accessor Person Int Int
firstScoreAcc = dot (frAcc @"scores") Accessor._0

eachScoreAcc :: Accessor.Accessor Person Int [Int]
eachScoreAcc = dot (frAcc @"scores") $ facc Accessor.self

tests :: Test
tests =
  TestList
    [ TestCase (assertEqual "frGet age" 1 (frGet @"age" person))
    , TestCase (assertEqual "frSet age" 2 (frGet @"age" (frSet @"age" 2 person)))
    , TestCase (assertEqual "accessor view age" 1 (view ageAcc person))
    , TestCase (assertEqual "accessor set age" 3 (frGet @"age" (set ageAcc 3 person)))
    , TestCase (assertEqual "accessor over age" 11 (frGet @"age" (over ageAcc (+ 10) person)))
    , TestCase (assertEqual "dot view first score" 10 (view firstScoreAcc person))
    , TestCase (assertEqual "dot set first score" [99, 20, 30] (frGet @"scores" (set firstScoreAcc 99 person)))
    , TestCase (assertEqual "fdot view each score" [10, 20, 30] (view eachScoreAcc person))
    , TestCase (assertEqual "fdot over each score" [11, 21, 31] (frGet @"scores" (over eachScoreAcc (+ 1) person)))
    , TestCase $
        case eitherDecode (encode personMaybeNothing) of
          Left err -> assertFailure ("decode Value failed: " ++ err)
          Right (Object obj) ->
            assertEqual "toJSON omit Nothing field" False (KM.member (Key.fromString "nick") obj)
          Right _ -> assertFailure "expected JSON object"
    , TestCase $
        case (eitherDecode (LBS.pack "{\"name\":\"uwu\"}") :: Either String PersonMaybe) of
          Left err -> assertFailure ("parseJSON missing Maybe field failed: " ++ err)
          Right v ->
            assertEqual "parseJSON missing Maybe field -> Nothing" Nothing (frGet @"nick" v)
    , TestCase $
        case eitherDecode (encode personMaybeJust) of
          Left err -> assertFailure ("decode Value failed: " ++ err)
          Right (Object obj) ->
            assertEqual "toJSON include Just field" True (KM.member (Key.fromString "nick") obj)
          Right _ -> assertFailure "expected JSON object"
    -- FlexEnum tests
    -- Test 1: Creating a FlexEnum for the first field should produce FEThis
    , TestCase
        ( let
            fe = flexEnum @"name" "alice" :: FlexEnum '[Field "name" String]
          in
            case fe of
              FEThis _ -> assertEqual "flexEnum first field produces FEThis" True True
              _ -> assertFailure "expected FEThis"
        )
    -- Test 2: Creating a FlexEnum for a different type should produce FENext when recursed
    , TestCase
        ( let
            fe = flexEnum @"x" True :: FlexEnum '[Field "x" Bool]
          in
            case fe of
              FEThis _ -> assertEqual "flexEnum bool field produces FEThis" True True
              _ -> assertFailure "expected FEThis"
        )
    -- Test 3: Test pattern matching on nested FlexEnum
    , TestCase
        ( let
            fe = flexEnum @"x" 42 :: FlexEnum '[Field "x" Int, Field "y" String]
          in
            case fe of
              FEThis (Field 42) -> assertEqual "flexEnum nested FEThis matches" True True
              _ -> assertFailure "expected FEThis with Field 42"
        )
    -- Test 4: Test selecting second field in a FlexEnum (produces FENext)
    , TestCase
        ( let
            fe = flexEnum @"y" "abc" :: FlexEnum '[Field "x" Int, Field "y" String]
          in
            case fe of
              FENext (FEThis (Field "abc")) -> assertEqual "flexEnum second field produces FENext(FEThis)" True True
              _ -> assertFailure "expected FENext(FEThis(Field \"abc\"))"
        )
    ]

main :: IO ()
main = do
  counts <- runTestTT tests
  if errors counts + failures counts == 0
    then pure ()
    else error "Tests failed"
