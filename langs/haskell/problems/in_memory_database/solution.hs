module Solution (InMemoryDatabase, newTarget) where

import Data.Int (Int64)
import Data.List (intercalate, sort)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Harness

type FieldVal = (String, Maybe Int64)

data InMemoryDatabase = InMemoryDatabase
  { dbData :: Map String (Map String FieldVal)
  , dbBackupTs :: [Int64]
  , dbBackupStates :: [Map String (Map String FieldVal)]
  }

newTarget :: InMemoryDatabase
newTarget =
  InMemoryDatabase
    { dbData = Map.empty
    , dbBackupTs = []
    , dbBackupStates = []
    }

setInternal :: InMemoryDatabase -> String -> String -> String -> Maybe Int64 -> InMemoryDatabase
setInternal db key field value expiry =
  let fields = Map.findWithDefault Map.empty key (dbData db)
   in db {dbData = Map.insert key (Map.insert field (value, expiry) fields) (dbData db)}

isAlive :: InMemoryDatabase -> String -> String -> Int64 -> Bool
isAlive db key field timestamp =
  case Map.lookup key (dbData db) >>= Map.lookup field of
    Nothing -> False
    Just (_, Nothing) -> True
    Just (_, Just expiry) -> timestamp < expiry

fieldsOf :: InMemoryDatabase -> String -> Map String FieldVal
fieldsOf db key = Map.findWithDefault Map.empty key (dbData db)

joinParts :: [String] -> String
joinParts = intercalate ", "

instance Target InMemoryDatabase where
  set db key field value = ("", setInternal db key field value Nothing)

  get2 db key field =
    case Map.lookup key (dbData db) >>= Map.lookup field of
      Nothing -> ("", db)
      Just (value, _) -> (value, db)

  delete db key field =
    case Map.lookup key (dbData db) >>= Map.lookup field of
      Nothing -> ("false", db)
      Just _ ->
        let fields = Map.delete field (fieldsOf db key)
         in ("true", db {dbData = Map.insert key fields (dbData db)})

  scan db key =
    case Map.lookup key (dbData db) of
      Nothing -> ("", db)
      Just fields ->
        let parts =
              [ field ++ "(" ++ value ++ ")"
              | field <- sort (Map.keys fields)
              , let (value, _) = fields Map.! field
              ]
         in (joinParts parts, db)

  scanByPrefix db key prefix =
    case Map.lookup key (dbData db) of
      Nothing -> ("", db)
      Just fields ->
        let parts =
              [ field ++ "(" ++ value ++ ")"
              | field <- sort (Map.keys fields)
              , take (length prefix) field == prefix
              , let (value, _) = fields Map.! field
              ]
         in (joinParts parts, db)

  setAt db key field value _timestamp = ("", setInternal db key field value Nothing)

  setAtWithTtl db key field value timestamp ttl =
    ("", setInternal db key field value (Just (timestamp + ttl)))

  deleteAt db key field timestamp
    | not (isAlive db key field timestamp) = ("false", db)
    | otherwise =
        let fields = Map.delete field (fieldsOf db key)
         in ("true", db {dbData = Map.insert key fields (dbData db)})

  getAt db key field timestamp
    | not (isAlive db key field timestamp) = ("", db)
    | otherwise =
        let (value, _) = fieldsOf db key Map.! field
         in (value, db)

  scanAt db key timestamp =
    case Map.lookup key (dbData db) of
      Nothing -> ("", db)
      Just fields ->
        let parts =
              [ field ++ "(" ++ value ++ ")"
              | field <- sort (Map.keys fields)
              , isAlive db key field timestamp
              , let (value, _) = fields Map.! field
              ]
         in (joinParts parts, db)

  scanByPrefixAt db key prefix timestamp =
    case Map.lookup key (dbData db) of
      Nothing -> ("", db)
      Just fields ->
        let parts =
              [ field ++ "(" ++ value ++ ")"
              | field <- sort (Map.keys fields)
              , take (length prefix) field == prefix
              , isAlive db key field timestamp
              , let (value, _) = fields Map.! field
              ]
         in (joinParts parts, db)

  backup db timestamp =
    let state =
          Map.fromList
            [ ( key
              , Map.fromList
                  [ (field, (value, remaining))
                  | (field, (value, expiry)) <- Map.toList fields
                  , isAlive db key field timestamp
                  , let remaining = fmap (\expTs -> expTs - timestamp) expiry
                  ]
              )
            | (key, fields) <- Map.toList (dbData db)
            , let kept =
                    [ field
                    | (field, _) <- Map.toList fields
                    , isAlive db key field timestamp
                    ]
            , not (null kept)
            ]
        state' = Map.filter (not . Map.null) state
     in ( show (Map.size state')
        , db
            { dbBackupTs = dbBackupTs db ++ [timestamp]
            , dbBackupStates = dbBackupStates db ++ [state']
            }
        )

  restore db timestamp timestampToRestore =
    let idx = length (takeWhile (<= timestampToRestore) (dbBackupTs db)) - 1
        backupState = dbBackupStates db !! idx
        empty = db {dbData = Map.empty}
        restored =
          foldl
            ( \acc (key, fields) ->
                foldl
                  ( \acc' (field, (value, remaining)) ->
                      setInternal acc' key field value (fmap (timestamp +) remaining)
                  )
                  acc
                  (Map.toList fields)
            )
            empty
            (Map.toList backupState)
     in ("", restored)
