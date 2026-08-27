module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Ord (comparing)
import Harness

cashbackDelay :: Int64
cashbackDelay = 24 * 60 * 60 * 1000

data Account = Account
  { accId :: String
  , accBalance :: Int64
  , accOutgoing :: Int64
  , accPayments :: Map String String
  , accCreatedAt :: Int64
  , accHistory :: [(Int64, Int64)]
  }

data Simulation = Simulation
  { simAccounts :: Map String Account
  , simPayCount :: Int
  , simPending :: [(Int64, String, Int64, String)]
  }

newTarget :: Simulation
newTarget =
  Simulation
    { simAccounts = Map.empty
    , simPayCount = 0
    , simPending = []
    }

newAccount :: String -> Int64 -> Account
newAccount accountId createdAt =
  Account
    { accId = accountId
    , accBalance = 0
    , accOutgoing = 0
    , accPayments = Map.empty
    , accCreatedAt = createdAt
    , accHistory = [(createdAt, 0)]
    }

recordBalance :: Account -> Int64 -> Account
recordBalance acc ts = acc {accHistory = accHistory acc ++ [(ts, accBalance acc)]}

credit :: Account -> Int64 -> Account
credit acc amount = acc {accBalance = accBalance acc + amount}

withdraw :: Account -> Int64 -> Maybe Account
withdraw acc amount
  | accBalance acc < amount = Nothing
  | otherwise =
      Just
        acc
          { accBalance = accBalance acc - amount
          , accOutgoing = accOutgoing acc + amount
          }

balanceAt :: Account -> Int64 -> Maybe Int64
balanceAt acc timeAt
  | timeAt < accCreatedAt acc = Nothing
  | otherwise = go Nothing (accHistory acc)
  where
    go found [] = found
    go found ((ts, bal) : rest)
      | ts <= timeAt = go (Just bal) rest
      | otherwise = found

processCashbacks :: Simulation -> Int64 -> Simulation
processCashbacks sim timestamp =
  case simPending sim of
    (cbTs, accountId, amount, paymentId) : rest
      | cbTs <= timestamp ->
          let sim' = sim {simPending = rest}
              sim'' =
                case Map.lookup accountId (simAccounts sim') of
                  Nothing -> sim'
                  Just acc ->
                    let acc' = recordBalance (credit acc amount) cbTs
                        acc'' = acc' {accPayments = Map.insert paymentId "CASHBACK_RECEIVED" (accPayments acc')}
                     in sim' {simAccounts = Map.insert accountId acc'' (simAccounts sim')}
           in processCashbacks sim'' timestamp
    _ -> sim

putAccount :: Simulation -> String -> Account -> Simulation
putAccount sim accountId acc =
  sim {simAccounts = Map.insert accountId acc (simAccounts sim)}

instance Target Simulation where
  createAccount sim timestamp accountId =
    let sim' = processCashbacks sim timestamp
     in if Map.member accountId (simAccounts sim')
          then (False, sim')
          else (True, putAccount sim' accountId (newAccount accountId timestamp))

  deposit sim timestamp accountId amount =
    let sim' = processCashbacks sim timestamp
     in case Map.lookup accountId (simAccounts sim') of
          Nothing -> (Nothing, sim')
          Just acc ->
            let acc' = recordBalance (credit acc amount) timestamp
             in (Just (accBalance acc'), putAccount sim' accountId acc')

  transfer sim timestamp sourceId targetId amount =
    let sim' = processCashbacks sim timestamp
        source = Map.lookup sourceId (simAccounts sim')
        target = Map.lookup targetId (simAccounts sim')
     in case (source, target) of
          (Just src, Just tgt)
            | sourceId /= targetId ->
                case withdraw src amount of
                  Nothing -> (Nothing, sim')
                  Just src' ->
                    let tgt' = recordBalance (credit tgt amount) timestamp
                        src'' = recordBalance src' timestamp
                        sim'' = putAccount (putAccount sim' sourceId src'') targetId tgt'
                     in (Just (accBalance src''), sim'')
          _ -> (Nothing, sim')

  topSpenders sim timestamp n =
    let sim' = processCashbacks sim timestamp
        ids =
          take (fromIntegral n) $
            sortBy
              ( \a b ->
                  compare (accOutgoing (simAccounts sim' Map.! b)) (accOutgoing (simAccounts sim' Map.! a))
                    <> compare a b
              )
              (Map.keys (simAccounts sim'))
        result = [accId' ++ "(" ++ show (accOutgoing (simAccounts sim' Map.! accId')) ++ ")" | accId' <- ids]
     in (result, sim')

  pay sim timestamp accountId amount =
    let sim' = processCashbacks sim timestamp
     in case Map.lookup accountId (simAccounts sim') of
          Nothing -> (Nothing, sim')
          Just acc ->
            case withdraw acc amount of
              Nothing -> (Nothing, sim')
              Just acc' ->
                let count = simPayCount sim' + 1
                    paymentId = "payment" ++ show count
                    acc'' =
                      recordBalance
                        (acc' {accPayments = Map.insert paymentId "IN_PROGRESS" (accPayments acc')})
                        timestamp
                    cashback = (amount * 2) `div` 100
                    simAcc = putAccount sim' accountId acc''
                    sim'' =
                      simAcc
                        { simPayCount = count
                        , simPending =
                            simPending sim'
                              ++ [(timestamp + cashbackDelay, accountId, cashback, paymentId)]
                        }
                 in (Just paymentId, sim'')

  getPaymentStatus sim timestamp accountId payment =
    let sim' = processCashbacks sim timestamp
     in case Map.lookup accountId (simAccounts sim') of
          Nothing -> (Nothing, sim')
          Just acc -> (Map.lookup payment (accPayments acc), sim')

  mergeAccounts sim timestamp accountId1 accountId2
    | accountId1 == accountId2 = (False, processCashbacks sim timestamp)
    | otherwise =
        let sim' = processCashbacks sim timestamp
            a1 = Map.lookup accountId1 (simAccounts sim')
            a2 = Map.lookup accountId2 (simAccounts sim')
         in case (a1, a2) of
              (Just acc1, Just acc2) ->
                let mergedHistory =
                      sortBy (comparing fst) (accHistory acc1 ++ accHistory acc2)
                    acc1' =
                      recordBalance
                        acc1
                          { accBalance = accBalance acc1 + accBalance acc2
                          , accOutgoing = accOutgoing acc1 + accOutgoing acc2
                          , accPayments = Map.union (accPayments acc2) (accPayments acc1)
                          , accHistory = mergedHistory
                          , accCreatedAt = min (accCreatedAt acc1) (accCreatedAt acc2)
                          }
                        timestamp
                    pending =
                      [ (cbTs, if accId' == accountId2 then accountId1 else accId', amount, paymentId)
                      | (cbTs, accId', amount, paymentId) <- simPending sim'
                      ]
                    sim'' =
                      sim'
                        { simAccounts = Map.delete accountId2 (Map.insert accountId1 acc1' (simAccounts sim'))
                        , simPending = pending
                        }
                 in (True, sim'')
              _ -> (False, sim')

  getBalance sim timestamp accountId timeAt =
    let sim' = processCashbacks sim timestamp
     in case Map.lookup accountId (simAccounts sim') of
          Nothing -> (Nothing, sim')
          Just acc -> (balanceAt acc timeAt, sim')
