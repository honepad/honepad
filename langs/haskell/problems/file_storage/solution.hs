module Solution (Simulation, newTarget) where

import Data.Int (Int64)
import Data.List (intercalate, sortBy)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, isNothing)
import Harness

data StoredFile = StoredFile
  { fileName :: String
  , fileSize :: Int64
  , fileOwner :: String
  }

data Simulation = Simulation
  { simFiles :: Map String StoredFile
  , simCapacity :: Map String (Maybe Int64)
  , simBackups :: Map String (Map String Int64)
  }

newTarget :: Simulation
newTarget =
  Simulation
    { simFiles = Map.empty
    , simCapacity = Map.singleton "admin" Nothing
    , simBackups = Map.empty
    }

used :: Simulation -> String -> Int64
used sim userId =
  sum [fileSize item | item <- Map.elems (simFiles sim), fileOwner item == userId]

remaining :: Simulation -> String -> Maybe Int64
remaining sim userId =
  case Map.lookup userId (simCapacity sim) of
    Nothing -> Nothing
    Just Nothing -> Nothing
    Just (Just cap) -> Just (cap - used sim userId)

joinParts :: [String] -> String
joinParts = intercalate ", "

instance Target Simulation where
  addFile sim name size
    | Map.member name (simFiles sim) = ("false", sim)
    | otherwise =
        ( "true"
        , sim {simFiles = Map.insert name (StoredFile name size "admin") (simFiles sim)}
        )

  copyFile sim source dest =
    case Map.lookup source (simFiles sim) of
      Nothing -> ("", sim)
      Just src
        | source == dest -> (show (fileSize src), sim)
        | otherwise ->
            let destItem = Map.lookup dest (simFiles sim)
                owner = maybe (fileOwner src) fileOwner destItem
                extra = maybe (fileSize src) (\item -> fileSize src - fileSize item) destItem
             in if maybe False (extra >) (remaining sim owner)
                  then ("", sim)
                  else
                    let destFile = case destItem of
                          Nothing -> StoredFile dest (fileSize src) owner
                          Just item -> item {fileSize = fileSize src}
                        sim' = sim {simFiles = Map.insert dest destFile (simFiles sim)}
                     in (show (fileSize src), sim')

  getFileSize sim name =
    case Map.lookup name (simFiles sim) of
      Nothing -> ("", sim)
      Just item -> (show (fileSize item), sim)

  deleteFile sim name =
    case Map.lookup name (simFiles sim) of
      Nothing -> ("", sim)
      Just item -> (show (fileSize item), sim {simFiles = Map.delete name (simFiles sim)})

  getNLargest sim prefix n =
    let matched =
          [item | item <- Map.elems (simFiles sim), take (length prefix) (fileName item) == prefix]
        ordered =
          sortBy
            ( \a b ->
                compare (fileSize b) (fileSize a) <> compare (fileName a) (fileName b)
            )
            matched
        top = take (fromIntegral n) ordered
        parts = [fileName item ++ "(" ++ show (fileSize item) ++ ")" | item <- top]
     in (joinParts parts, sim)

  addUser sim userId capacity
    | Map.member userId (simCapacity sim) = ("false", sim)
    | otherwise = ("true", sim {simCapacity = Map.insert userId (Just capacity) (simCapacity sim)})

  addFileBy sim userId name size
    | Map.notMember userId (simCapacity sim) || Map.member name (simFiles sim) = ("", sim)
    | maybe False (size >) (remaining sim userId) = ("", sim)
    | otherwise =
        let sim' = sim {simFiles = Map.insert name (StoredFile name size userId) (simFiles sim)}
         in (maybe "" show (remaining sim' userId), sim')

  mergeUser sim userId1 userId2
    | userId1 == userId2 = ("", sim)
    | Map.notMember userId1 (simCapacity sim) || Map.notMember userId2 (simCapacity sim) = ("", sim)
    | isNothing (fromMaybe Nothing (Map.lookup userId1 (simCapacity sim)))
        || isNothing (fromMaybe Nothing (Map.lookup userId2 (simCapacity sim))) =
        ("", sim)
    | otherwise =
        let cap1 = fromMaybe 0 (fromMaybe Nothing (Map.lookup userId1 (simCapacity sim)))
            cap2 = fromMaybe 0 (fromMaybe Nothing (Map.lookup userId2 (simCapacity sim)))
            files =
              Map.map
                ( \item ->
                    if fileOwner item == userId2 then item {fileOwner = userId1} else item
                )
                (simFiles sim)
            sim' =
              sim
                { simFiles = files
                , simCapacity =
                    Map.delete userId2 (Map.insert userId1 (Just (cap1 + cap2)) (simCapacity sim))
                , simBackups = Map.delete userId2 (simBackups sim)
                }
         in (maybe "" show (remaining sim' userId1), sim')

  backupUser sim userId
    | Map.notMember userId (simCapacity sim) = ("", sim)
    | otherwise =
        let snapshot =
              Map.fromList
                [ (fileName item, fileSize item)
                | item <- Map.elems (simFiles sim)
                , fileOwner item == userId
                ]
         in ( show (Map.size snapshot)
            , sim {simBackups = Map.insert userId snapshot (simBackups sim)}
            )

  restoreUser sim userId
    | Map.notMember userId (simCapacity sim) = ("", sim)
    | otherwise =
        let cleared =
              Map.filter (\item -> fileOwner item /= userId) (simFiles sim)
            simCleared = sim {simFiles = cleared}
         in case Map.lookup userId (simBackups sim) of
              Nothing -> ("0", simCleared)
              Just snapshot -> restoreAll simCleared userId (Map.toList snapshot) 0

restoreAll :: Simulation -> String -> [(String, Int64)] -> Int -> (String, Simulation)
restoreAll sim _ [] restored = (show restored, sim)
restoreAll sim userId ((name, size) : rest) restored
  | Map.member name (simFiles sim) = restoreAll sim userId rest restored
  | maybe False (size >) (remaining sim userId) = restoreAll sim userId rest restored
  | otherwise =
      let sim' = sim {simFiles = Map.insert name (StoredFile name size userId) (simFiles sim)}
       in restoreAll sim' userId rest (restored + 1)
