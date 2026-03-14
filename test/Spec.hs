{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

import Accessor (dot, fdot, over, set, view)
import qualified Accessor
import FlexRecord (Field, FlexRecord, field, flexRecord, frAcc, frGet, frSet)
import Test.HUnit (Test (TestCase, TestList), assertEqual, errors, failures, runTestTT)

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

ageAcc :: Accessor.Accessor Person Int Int
ageAcc = frAcc @"age"

firstScoreAcc :: Accessor.Accessor Person Int Int
firstScoreAcc = dot (frAcc @"scores") Accessor._0

eachScoreAcc :: Accessor.Accessor Person Int [Int]
eachScoreAcc = fdot (frAcc @"scores") Accessor.self

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
    ]

main :: IO ()
main = do
  counts <- runTestTT tests
  if errors counts + failures counts == 0
    then pure ()
    else error "Tests failed"
