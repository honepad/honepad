module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Harness

data KeyState = KeyState
  { itemLimit :: Int64
  , itemWindow :: Int64
  , itemWindowId :: Maybe Int64
  , itemUsed :: Int64
  }

data Simulation = Simulation
  { simKeys :: Map String KeyState
  }

newTarget :: Simulation
newTarget = Simulation {simKeys = Map.empty}

fresh :: KeyState
fresh = KeyState {itemLimit = 3, itemWindow = 10, itemWindowId = Nothing, itemUsed = 0}

stateOf :: Simulation -> String -> KeyState
stateOf sim key = Map.findWithDefault fresh key (simKeys sim)

usedAt :: KeyState -> Int64 -> Bool -> (Int64, KeyState)
usedAt item timestamp persist =
  let windowId = timestamp `div` itemWindow item
   in case itemWindowId item of
        Just current | current == windowId -> (itemUsed item, item)
        _ ->
          if persist
            then (0, item {itemWindowId = Just windowId, itemUsed = 0})
            else (0, item)

putKey :: Simulation -> String -> KeyState -> Simulation
putKey sim key item = sim {simKeys = Map.insert key item (simKeys sim)}

instance Target Simulation where
  allow sim key timestamp = allowWeighted sim key 1 timestamp

  configure sim key limit window
    | limit <= 0 || window <= 0 = ("invalid_request", sim)
    | otherwise =
        ( "true"
        , putKey
            sim
            key
            ( (stateOf sim key)
                { itemLimit = limit
                , itemWindow = window
                , itemWindowId = Nothing
                , itemUsed = 0
                }
            )
        )

  remainingAt sim key timestamp =
    let item = stateOf sim key
        (used, _) = usedAt item timestamp False
     in (show (itemLimit item - used), putKey sim key item)

  allowWeighted sim key cost timestamp
    | cost <= 0 = ("invalid_request", sim)
    | otherwise =
        let item = stateOf sim key
            (_, item') = usedAt item timestamp True
         in if itemUsed item' + cost > itemLimit item'
              then ("false", putKey sim key item')
              else
                ( "true"
                , putKey sim key (item' {itemUsed = itemUsed item' + cost})
                )
