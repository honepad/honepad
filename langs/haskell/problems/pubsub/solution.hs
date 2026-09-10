module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (intercalate, sort)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Harness

data Simulation = Simulation
  { simSubs :: Map String [String]
  , simInbox :: Map String [String]
  , simRetained :: Map String String
  }

newTarget :: Simulation
newTarget =
  Simulation
    { simSubs = Map.empty
    , simInbox = Map.empty
    , simRetained = Map.empty
    }

joinParts :: [String] -> String
joinParts = intercalate ", "

pushInbox :: String -> String -> Simulation -> Simulation
pushInbox client payload sim =
  sim
    { simInbox =
        Map.insert client (Map.findWithDefault [] client (simInbox sim) ++ [payload]) (simInbox sim)
    }

instance Target Simulation where
  subscribe sim topic client =
    let clients = Map.findWithDefault [] topic (simSubs sim)
     in if client `elem` clients
          then ("false", sim)
          else
            let sim' = sim {simSubs = Map.insert topic (clients ++ [client]) (simSubs sim)}
             in case Map.lookup topic (simRetained sim') of
                  Nothing -> ("true", sim')
                  Just message -> ("true", pushInbox client (topic ++ ":" ++ message) sim')

  unsubscribe sim topic client =
    case Map.lookup topic (simSubs sim) of
      Nothing -> ("false", sim)
      Just clients
        | client `notElem` clients -> ("false", sim)
        | otherwise ->
            let rest = filter (/= client) clients
                subs' =
                  if null rest
                    then Map.delete topic (simSubs sim)
                    else Map.insert topic rest (simSubs sim)
             in ("true", sim {simSubs = subs'})

  publish sim topic message =
    let clients = Map.findWithDefault [] topic (simSubs sim)
        payload = topic ++ ":" ++ message
        sim' = foldl (\acc client -> pushInbox client payload acc) sim clients
     in (show (length clients), sim')

  inbox sim client =
    (joinParts (Map.findWithDefault [] client (simInbox sim)), sim)

  listTopics sim =
    (joinParts (sort (Map.keys (simSubs sim))), sim)

  subscribers sim topic =
    (joinParts (sort (Map.findWithDefault [] topic (simSubs sim))), sim)

  peek sim client =
    case Map.findWithDefault [] client (simInbox sim) of
      [] -> ("", sim)
      (headMsg : _) -> (headMsg, sim)

  ack sim client n =
    case Map.lookup client (simInbox sim) of
      Nothing -> ("invalid_request", sim)
      _
        | n <= 0 -> ("invalid_request", sim)
      Just items
        | n > fromIntegral (length items) -> ("invalid_request", sim)
        | otherwise ->
            let rest = drop (fromIntegral n) items
             in (show (length rest), sim {simInbox = Map.insert client rest (simInbox sim)})

  retain sim topic message =
    ("", sim {simRetained = Map.insert topic message (simRetained sim)})
