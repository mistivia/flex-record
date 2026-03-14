import FlexRecord (hello)
import Test.HUnit (Test (TestCase, TestList), assertEqual, runTestTT, errors, failures)

tests :: Test
tests =
  TestList
    [ TestCase (assertEqual "hello should match expected text" "Hello, Haskell!" hello)
    ]

main :: IO ()
main = do
  counts <- runTestTT tests
  if errors counts + failures counts == 0
    then pure ()
    else error "Tests failed"
