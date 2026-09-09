module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (intercalate, sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromJust, isJust)
import Harness

data Worker = Worker
  { wId :: String
  , wPos :: String
  , wComp :: Int64
  , wInOffice :: Bool
  , wEnteredAt :: Maybe Int64
  , wFinished :: [(Int64, Int64, Int64, String)]
  , wPending :: Maybe (String, Int64, Int64)
  , wDoublePay :: [(Int64, Int64)]
  }

data Simulation = Simulation
  { simWorkers :: Map String Worker
  }

newTarget :: Simulation
newTarget = Simulation {simWorkers = Map.empty}

totalTime :: Worker -> Int64
totalTime worker = sum [endTs - startTs | (startTs, endTs, _, _) <- wFinished worker]

positionTime :: Worker -> String -> Int64
positionTime worker position =
  sum [endTs - startTs | (startTs, endTs, _, pos) <- wFinished worker, pos == position]

applyPromo :: Worker -> Int64 -> Worker
applyPromo worker timestamp =
  case wPending worker of
    Just (newPos, newComp, startTs)
      | timestamp >= startTs ->
          worker {wPos = newPos, wComp = newComp, wPending = Nothing}
    _ -> worker

joinParts :: [String] -> String
joinParts = intercalate ", "

instance Target Simulation where
  addWorker sim workerId position compensation
    | Map.member workerId (simWorkers sim) = ("false", sim)
    | otherwise =
        ( "true"
        , sim
            { simWorkers =
                Map.insert
                  workerId
                  Worker
                    { wId = workerId
                    , wPos = position
                    , wComp = compensation
                    , wInOffice = False
                    , wEnteredAt = Nothing
                    , wFinished = []
                    , wPending = Nothing
                    , wDoublePay = []
                    }
                  (simWorkers sim)
            }
        )

  register sim workerId timestamp =
    case Map.lookup workerId (simWorkers sim) of
      Nothing -> ("invalid_request", sim)
      Just worker
        | wInOffice worker ->
            let finished =
                  wFinished worker
                    ++ [(fromJust (wEnteredAt worker), timestamp, wComp worker, wPos worker)]
                worker' = worker {wFinished = finished, wInOffice = False, wEnteredAt = Nothing}
             in ("registered", sim {simWorkers = Map.insert workerId worker' (simWorkers sim)})
        | otherwise ->
            let worker' = (applyPromo worker timestamp) {wInOffice = True, wEnteredAt = Just timestamp}
             in ("registered", sim {simWorkers = Map.insert workerId worker' (simWorkers sim)})

  get1 sim workerId =
    case Map.lookup workerId (simWorkers sim) of
      Nothing -> ("", sim)
      Just worker -> (show (totalTime worker), sim)

  topNWorkers sim n position =
    let matched = [w | w <- Map.elems (simWorkers sim), wPos w == position]
        ordered =
          sortBy
            ( \a b ->
                compare (positionTime b position) (positionTime a position) <> compare (wId a) (wId b)
            )
            matched
        top = take (fromIntegral n) ordered
        parts =
          [ wId w ++ "(" ++ show (positionTime w position) ++ ")"
          | w <- top
          ]
     in (joinParts parts, sim)

  promote sim workerId newPosition newCompensation startTimestamp =
    case Map.lookup workerId (simWorkers sim) of
      Nothing -> ("invalid_request", sim)
      Just worker
        | isJust (wPending worker) -> ("invalid_request", sim)
        | otherwise ->
            let worker' = worker {wPending = Just (newPosition, newCompensation, startTimestamp)}
             in ("success", sim {simWorkers = Map.insert workerId worker' (simWorkers sim)})

  setDoublePay sim workerId intervalBegin intervalEnd =
    case Map.lookup workerId (simWorkers sim) of
      Nothing -> ("invalid_request", sim)
      Just _
        | intervalEnd <= intervalBegin -> ("invalid_request", sim)
      Just worker ->
        let worker' = worker {wDoublePay = wDoublePay worker ++ [(intervalBegin, intervalEnd)]}
         in ("true", sim {simWorkers = Map.insert workerId worker' (simWorkers sim)})

  calcSalary sim workerId startTimestamp endTimestamp =
    case Map.lookup workerId (simWorkers sim) of
      Nothing -> ("", sim)
      Just worker ->
        let total =
              sum
                [ (hi - lo - bonus) * rate + bonus * rate * 2
                | (sessionStart, sessionEnd, rate, _) <- wFinished worker
                , let lo = max sessionStart startTimestamp
                , let hi = min sessionEnd endTimestamp
                , hi > lo
                , let bonus = bonusOverlap lo hi (wDoublePay worker)
                ]
         in (show total, sim)

bonusOverlap :: Int64 -> Int64 -> [(Int64, Int64)] -> Int64
bonusOverlap lo hi windows =
  let segs =
        [ (max lo beginTs, min hi endTs)
        | (beginTs, endTs) <- windows
        , min hi endTs > max lo beginTs
        ]
      ordered = sortBy (\(a, _) (b, _) -> compare a b) segs
      merge acc [] = reverse acc
      merge [] (item : rest) = merge [item] rest
      merge ((mStart, mEnd) : acc) ((start, stop) : rest)
        | start >= mEnd = merge ((start, stop) : (mStart, mEnd) : acc) rest
        | otherwise = merge ((mStart, max mEnd stop) : acc) rest
      merged = merge [] ordered
   in sum [stop - start | (start, stop) <- merged]
