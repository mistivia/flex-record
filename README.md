# flex-record

`flex-record` is a lightweight Haskell Record library based on type-level field lists.
It provides:

- Type-safe field access (`frGet`)
- Type-safe field update (`frSet`)
- Integration with [`accessor-hs`](https://github.com/mistivia/accessor-hs) (`frAcc`)


## Quick Start

### 1) Define a Record type

```haskell
import FlexRecord (Field, FlexRecord)

type Person = FlexRecord
    [ Field "name"   String
    , Field "age"    Int
    , Field "height" Float
    , Field "scores" [Int]
    ]
```

### Construct a Record value

Use `flexRecord` + `field` to build from an empty record via function composition:

```haskell
import FlexRecord (field, flexRecord)

person :: Person
person = flexRecord
    $ field @"name" "ABC"
    . field @"age" 1
    . field @"height" 42.0
    . field @"scores" [ 10, 20, 30]
```

### 3) Read and update fields

```haskell
import FlexRecord (frGet, frSet)

age1 :: Int
age1 = frGet @"age" person
-- 1

person2 :: Person
person2 = frSet @"age" 2 person

age2 :: Int
age2 = frGet @"age" person2
-- 2
```

`frGet` / `frSet` are both type-safe:  
if a field name does not exist, compilation fails.

## Using with accessor-hs

`frAcc` turns a field into an `Accessor`, so you can continue using `view` / `set` / `over` / `dot` / `fdot`.

```haskell
import qualified Accessor
import Accessor (dot, fdot, over, set, view)
import FlexRecord (frAcc)

ageAcc :: Accessor.Accessor Person Int Int
ageAcc = frAcc @"age"

firstScoreAcc :: Accessor.Accessor Person Int Int
firstScoreAcc = dot (frAcc @"scores") Accessor._0

eachScoreAcc :: Accessor.Accessor Person Int [Int]
eachScoreAcc = fdot (frAcc @"scores") Accessor.self
```

Usage examples:

```haskell
view ageAcc person
-- 1

frGet @"age" (set ageAcc 3 person)
-- 3

frGet @"age" (over ageAcc (+ 10) person)
-- 11

view firstScoreAcc person
-- 10

frGet @"scores" (set firstScoreAcc 99 person)
-- [99,20,30]

frGet @"scores" (over eachScoreAcc (+ 1) person)
-- [11,21,31]
```

