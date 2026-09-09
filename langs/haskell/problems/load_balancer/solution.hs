module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (find)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Harness

data Backend = Backend
  { backendId :: String
  , backendHealth :: Bool
  , backendWeight :: Int64
  , backendInflight :: Int64
  }

data Simulation = Simulation
  { simBackends :: [Backend]
  , simCursor :: Int64
  , simSticky :: Map String String
  , simUseLeast :: Bool
  }

newTarget :: Simulation
newTarget =
  Simulation
    { simBackends = []
    , simCursor = 0
    , simSticky = Map.empty
    , simUseLeast = False
    }

findBackend :: String -> Simulation -> Maybe Backend
findBackend bid sim = find ((== bid) . backendId) (simBackends sim)

updateBackend :: String -> (Backend -> Backend) -> Simulation -> Simulation
updateBackend bid f sim =
  sim {simBackends = map (\item -> if backendId item == bid then f item else item) (simBackends sim)}

resetCycle :: Simulation -> Simulation
resetCycle sim =
  sim
    { simCursor = 0
    , simUseLeast = False
    , simBackends = map (\item -> item {backendInflight = 0}) (simBackends sim)
    }

tickets :: [Backend] -> [Backend]
tickets = concatMap (\item -> replicate (fromIntegral (backendWeight item)) item)

pick :: Simulation -> (Maybe Backend, Simulation)
pick sim =
  let healthy = filter backendHealth (simBackends sim)
   in if null healthy
        then (Nothing, sim)
        else
          let pool =
                if simUseLeast sim
                  then
                    let least = minimum (map backendInflight healthy)
                     in filter ((== least) . backendInflight) healthy
                  else healthy
              ticketList = tickets pool
           in if null ticketList
                then (Nothing, sim)
                else
                  let idx = fromIntegral (simCursor sim `mod` fromIntegral (length ticketList))
                      chosen = ticketList !! idx
                   in (Just chosen, sim {simCursor = simCursor sim + 1})

takeOne :: Simulation -> (String, Simulation)
takeOne sim =
  case pick sim of
    (Nothing, sim') -> ("", sim')
    (Just item, sim') ->
      ( backendId item
      , updateBackend (backendId item) (\b -> b {backendInflight = backendInflight b + 1}) sim'
      )

instance Target Simulation where
  addBackend sim backendId'
    | any ((== backendId') . backendId) (simBackends sim) = ("false", sim)
    | otherwise =
        ( "true"
        , sim {simBackends = simBackends sim ++ [Backend backendId' True 1 0]}
        )

  setHealth sim backendId' flag
    | flag /= 0 && flag /= 1 = ("invalid_request", sim)
    | otherwise =
        case findBackend backendId' sim of
          Nothing -> ("invalid_request", sim)
          Just _ ->
            ( "true"
            , resetCycle (updateBackend backendId' (\item -> item {backendHealth = flag == 1}) sim)
            )

  setWeight sim backendId' weight
    | weight <= 0 = ("invalid_request", sim)
    | otherwise =
        case findBackend backendId' sim of
          Nothing -> ("invalid_request", sim)
          Just _ ->
            ( "true"
            , resetCycle (updateBackend backendId' (\item -> item {backendWeight = weight}) sim)
            )

  route = takeOne

  sticky sim clientId =
    case Map.lookup clientId (simSticky sim) >>= (`findBackend` sim) of
      Just item | backendHealth item ->
        ( backendId item
        , updateBackend (backendId item) (\b -> b {backendInflight = backendInflight b + 1}) sim
        )
      _ ->
        let (chosen, sim') = takeOne sim
         in if chosen == ""
              then ("", sim')
              else (chosen, sim' {simSticky = Map.insert clientId chosen (simSticky sim')})

  doneBackend sim backendId' =
    case findBackend backendId' sim of
      Just item | backendInflight item > 0 ->
        ( "true"
        , (updateBackend backendId' (\b -> b {backendInflight = backendInflight b - 1}) sim)
            {simUseLeast = True}
        )
      _ -> ("invalid_request", sim)
