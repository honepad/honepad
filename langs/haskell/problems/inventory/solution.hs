module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (intercalate, sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Harness

data Item = Item
  { itemSku :: String
  , itemName :: String
  , itemQty :: Int64
  , itemReserved :: Int64
  }

data Simulation = Simulation
  { simItems :: Map String Item
  }

newTarget :: Simulation
newTarget = Simulation {simItems = Map.empty}

joinParts :: [String] -> String
joinParts = intercalate ", "

instance Target Simulation where
  createItem sim sku name
    | Map.member sku (simItems sim) = ("false", sim)
    | otherwise =
        ( "true"
        , sim {simItems = Map.insert sku (Item sku name 0 0) (simItems sim)}
        )

  stock sim sku delta =
    case Map.lookup sku (simItems sim) of
      Nothing -> ("", sim)
      Just item ->
        let nxt = itemQty item + delta
         in if nxt < itemReserved item
              then ("invalid_request", sim)
              else
                let item' = item {itemQty = nxt}
                 in (show nxt, sim {simItems = Map.insert sku item' (simItems sim)})

  getQty sim sku =
    case Map.lookup sku (simItems sim) of
      Nothing -> ("", sim)
      Just item -> (show (itemQty item), sim)

  listLow sim threshold =
    let matched =
          [item | item <- Map.elems (simItems sim), itemQty item <= threshold]
        ordered =
          sortBy
            (\a b -> compare (itemQty a, itemSku a) (itemQty b, itemSku b))
            matched
        parts = [itemSku item ++ "(" ++ show (itemQty item) ++ ")" | item <- ordered]
     in (joinParts parts, sim)

  reserve sim sku n =
    case Map.lookup sku (simItems sim) of
      Nothing -> ("invalid_request", sim)
      Just item
        | n <= 0 || itemReserved item + n > itemQty item -> ("invalid_request", sim)
        | otherwise ->
            let item' = item {itemReserved = itemReserved item + n}
             in ("true", sim {simItems = Map.insert sku item' (simItems sim)})

  release sim sku n =
    case Map.lookup sku (simItems sim) of
      Nothing -> ("invalid_request", sim)
      Just item
        | n <= 0 || n > itemReserved item -> ("invalid_request", sim)
        | otherwise ->
            let item' = item {itemReserved = itemReserved item - n}
             in ("true", sim {simItems = Map.insert sku item' (simItems sim)})

  ship sim sku n =
    case Map.lookup sku (simItems sim) of
      Nothing -> ("invalid_request", sim)
      Just item
        | n <= 0 || n > itemReserved item -> ("invalid_request", sim)
        | otherwise ->
            let item' =
                  item
                    { itemReserved = itemReserved item - n
                    , itemQty = itemQty item - n
                    }
             in ("true", sim {simItems = Map.insert sku item' (simItems sim)})
