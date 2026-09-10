module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Harness

data Snap = Snap
  { snapBuf :: String
  , snapPos :: Int64
  }

data Simulation = Simulation
  { simBuf :: String
  , simPos :: Int64
  , simUndo :: [Snap]
  , simRedo :: [Snap]
  , simSel :: Maybe (Int64, Int64)
  , simClip :: String
  }

newTarget :: Simulation
newTarget =
  Simulation
    { simBuf = ""
    , simPos = 0
    , simUndo = []
    , simRedo = []
    , simSel = Nothing
    , simClip = ""
    }

push :: Simulation -> Simulation
push sim =
  sim
    { simUndo = Snap (simBuf sim) (simPos sim) : simUndo sim
    , simRedo = []
    , simSel = Nothing
    }

splice :: String -> Int64 -> Int64 -> String -> String
splice buf at n extra =
  take (fromIntegral at) buf ++ extra ++ drop (fromIntegral (at + n)) buf

instance Target Simulation where
  insert sim at text
    | at < 0 || at > fromIntegral (length (simBuf sim)) = ("invalid_request", sim)
    | otherwise =
        let sim' = push sim
            buf' = splice (simBuf sim') at 0 text
         in (show (length buf'), sim' {simBuf = buf'})

  erase sim at n
    | n <= 0 || at < 0 || at + n > fromIntegral (length (simBuf sim)) = ("invalid_request", sim)
    | otherwise =
        let sim' = push sim
            deleted = take (fromIntegral n) (drop (fromIntegral at) (simBuf sim'))
            buf' = splice (simBuf sim') at n ""
            pos' =
              if simPos sim' > fromIntegral (length buf')
                then fromIntegral (length buf')
                else simPos sim'
         in (deleted, sim' {simBuf = buf', simPos = pos'})

  getText sim = (simBuf sim, sim)

  bufLength sim = (show (length (simBuf sim)), sim)

  move sim at
    | at < 0 || at > fromIntegral (length (simBuf sim)) = ("invalid_request", sim)
    | otherwise = ("true", sim {simPos = at})

  typeText sim text =
    let sim' = push sim
        at = simPos sim'
        buf' = splice (simBuf sim') at 0 text
     in (show (length buf'), sim' {simBuf = buf', simPos = at + fromIntegral (length text)})

  cursor sim = (show (simPos sim), sim)

  undo sim =
    case simUndo sim of
      [] -> ("false", sim)
      snap : rest ->
        ( "true"
        , sim
            { simRedo = Snap (simBuf sim) (simPos sim) : simRedo sim
            , simUndo = rest
            , simBuf = snapBuf snap
            , simPos = snapPos snap
            , simSel = Nothing
            }
        )

  redo sim =
    case simRedo sim of
      [] -> ("false", sim)
      snap : rest ->
        ( "true"
        , sim
            { simUndo = Snap (simBuf sim) (simPos sim) : simUndo sim
            , simRedo = rest
            , simBuf = snapBuf snap
            , simPos = snapPos snap
            , simSel = Nothing
            }
        )

  select sim start end
    | start < 0 || end < 0 || start > end || end > fromIntegral (length (simBuf sim)) =
        ("invalid_request", sim)
    | otherwise = ("true", sim {simSel = Just (start, end)})

  cut sim =
    case simSel sim of
      Nothing -> ("invalid_request", sim)
      Just (start, end)
        | start == end -> ("invalid_request", sim)
        | otherwise ->
            let text = take (fromIntegral (end - start)) (drop (fromIntegral start) (simBuf sim))
                buf' = splice (simBuf sim) start (end - start) ""
             in ( text
                , sim
                    { simBuf = buf'
                    , simClip = text
                    , simPos = start
                    , simSel = Nothing
                    }
                )

  copySel sim =
    case simSel sim of
      Nothing -> ("invalid_request", sim)
      Just (start, end)
        | start == end -> ("invalid_request", sim)
        | otherwise ->
            let text = take (fromIntegral (end - start)) (drop (fromIntegral start) (simBuf sim))
             in (text, sim {simClip = text})

  paste sim
    | simClip sim == "" = ("invalid_request", sim)
    | otherwise =
        let at = simPos sim
            buf' = splice (simBuf sim) at 0 (simClip sim)
         in ( show (length buf')
            , sim {simBuf = buf', simPos = at + fromIntegral (length (simClip sim))}
            )
