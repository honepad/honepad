module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (isNothing)
import Harness

data Gpu = Gpu
  { gpuId :: String
  , gpuMem :: Int64
  , gpuJob :: Maybe String
  }

data Job = Job
  { jobId :: String
  , jobMem :: Int64
  , jobSeq :: Int64
  , jobPriority :: Int64
  , jobState :: String
  , jobGpu :: Maybe String
  }

data Simulation = Simulation
  { simGpus :: Map String Gpu
  , simGpuOrder :: [String]
  , simJobs :: Map String Job
  , simNextSeq :: Int64
  }

newTarget :: Simulation
newTarget =
  Simulation
    { simGpus = Map.empty
    , simGpuOrder = []
    , simJobs = Map.empty
    , simNextSeq = 0
    }

place :: Job -> Gpu -> Simulation -> Simulation
place job gpu sim =
  let job' = job {jobState = "running", jobGpu = Just (gpuId gpu)}
      gpu' = gpu {gpuJob = Just (jobId job)}
   in sim
        { simJobs = Map.insert (jobId job) job' (simJobs sim)
        , simGpus = Map.insert (gpuId gpu) gpu' (simGpus sim)
        }

findGpu :: Simulation -> Int64 -> Maybe Gpu
findGpu sim need = go (simGpuOrder sim)
  where
    go [] = Nothing
    go (gid : rest) =
      case Map.lookup gid (simGpus sim) of
        Just gpu | isNothing (gpuJob gpu) && gpuMem gpu >= need -> Just gpu
        _ -> go rest

freeGpu :: Simulation -> Job -> Simulation
freeGpu sim job =
  case jobGpu job of
    Nothing -> sim
    Just gid ->
      case Map.lookup gid (simGpus sim) of
        Nothing -> sim
        Just gpu -> sim {simGpus = Map.insert gid (gpu {gpuJob = Nothing}) (simGpus sim)}

queuedJobs :: Simulation -> [Job]
queuedJobs sim =
  sortBy
    (\a b -> compare (negate (jobPriority a), jobSeq a) (negate (jobPriority b), jobSeq b))
    [job | job <- Map.elems (simJobs sim), jobState job == "queued"]

assignOne :: Simulation -> (String, Simulation)
assignOne sim = tryJobs (queuedJobs sim)
  where
    tryJobs [] = ("", sim)
    tryJobs (job : rest) =
      case findGpu sim (jobMem job) of
        Nothing -> tryJobs rest
        Just gpu -> (jobId job, place job gpu sim)

instance Target Simulation where
  addGpu sim gpuId' mem
    | mem <= 0 = ("invalid_request", sim)
    | Map.member gpuId' (simGpus sim) = ("false", sim)
    | otherwise =
        ( "true"
        , sim
            { simGpus = Map.insert gpuId' (Gpu gpuId' mem Nothing) (simGpus sim)
            , simGpuOrder = simGpuOrder sim ++ [gpuId']
            }
        )

  submitJob sim jobId' mem
    | mem <= 0 = ("invalid_request", sim)
    | Map.member jobId' (simJobs sim) = ("false", sim)
    | otherwise =
        ( "true"
        , sim
            { simJobs =
                Map.insert
                  jobId'
                  (Job jobId' mem (simNextSeq sim) 0 "queued" Nothing)
                  (simJobs sim)
            , simNextSeq = simNextSeq sim + 1
            }
        )

  status sim jobId' =
    case Map.lookup jobId' (simJobs sim) of
      Nothing -> ("", sim)
      Just job -> (jobState job, sim)

  assign = assignOne

  complete sim jobId' =
    case Map.lookup jobId' (simJobs sim) of
      Just job | jobState job == "running" ->
        case jobGpu job of
          Nothing -> ("invalid_request", sim)
          Just _ ->
            let sim' = freeGpu sim job
                job' = job {jobGpu = Nothing, jobState = "done"}
             in ("true", sim' {simJobs = Map.insert jobId' job' (simJobs sim')})
      _ -> ("invalid_request", sim)

  cancel sim jobId' =
    case Map.lookup jobId' (simJobs sim) of
      Nothing -> ("invalid_request", sim)
      Just job
        | jobState job == "done" -> ("invalid_request", sim)
        | jobState job == "running" ->
            let sim' = freeGpu sim job
                sim'' = sim' {simJobs = Map.delete jobId' (simJobs sim')}
                (_, sim''') = assignOne sim''
             in ("true", sim''')
        | otherwise -> ("true", sim {simJobs = Map.delete jobId' (simJobs sim)})

  setPriority sim jobId' priority =
    case Map.lookup jobId' (simJobs sim) of
      Just job | jobState job == "queued" ->
        ("true", sim {simJobs = Map.insert jobId' (job {jobPriority = priority}) (simJobs sim)})
      _ -> ("invalid_request", sim)
