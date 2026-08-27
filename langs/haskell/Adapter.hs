-- argv: ./run cases.json
-- Compile with solution or stub as Solution.hs. Compare JSON encodings.
module Main where

import Control.Exception (SomeException, displayException, evaluate, try)
import Harness
import MiniJson
import Solution (newTarget)
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitSuccess, exitWith)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  argv <- getArgs
  case argv of
    [casesPath] -> runCases casesPath
    _ -> do
      hPutStrLn stderr "usage: adapter cases.json"
      exitWith (ExitFailure 2)

runCases :: FilePath -> IO ()
runCases path = do
  raw <- readFile path
  case decode raw of
    JArr rows -> do
      (passed, failed) <- replayRows rows
      putStrLn
        ( encode
            ( JObj
                [ ("passed", JInt (toInteger passed))
                , ("failed", JArr failed)
                ]
            )
        )
      if null failed then exitSuccess else exitWith (ExitFailure 1)
    _ -> do
      hPutStrLn stderr "cases.json must be a JSON list"
      exitWith (ExitFailure 2)

replayRows :: [Value] -> IO (Int, [Value])
replayRows = go 0 []
  where
    go passed failed [] = return (passed, reverse failed)
    go passed failed (row : rest) = do
      result <- replayCase row
      case result of
        Nothing -> go (passed + 1) failed rest
        Just rowFail -> go passed (rowFail : failed) rest

replayCase :: Value -> IO (Maybe Value)
replayCase row =
  replayCalls newTarget (objStr row "id") calls 0
  where
    calls =
      case objVal row "calls" of
        JArr xs -> xs
        _ -> []

replayCalls :: Target a => a -> String -> [Value] -> Int -> IO (Maybe Value)
replayCalls _ _ [] _ = return Nothing
replayCalls obj caseId (call : rest) idx = do
  let method = objStr call "m"
      expected = objVal call "e"
      args =
        case objVal call "a" of
          JArr xs -> xs
          _ -> []
  outcome <-
    try $ do
      let (actual, obj') = dispatch obj method args
      encoded <- evaluate (encode actual)
      return (actual, encoded, obj')
  case outcome of
    Left exc ->
      return (Just (failRow caseId idx method expected (excVal exc)))
    Right (actual, encoded, obj') ->
      if encoded == encode expected
        then replayCalls obj' caseId rest (idx + 1)
        else return (Just (failRow caseId idx method expected actual))

excVal :: SomeException -> Value
excVal exc = JStr ("exc:" ++ displayException exc)

failRow :: String -> Int -> String -> Value -> Value -> Value
failRow caseId idx method expected actual =
  JObj
    [ ("case", JStr caseId)
    , ("index", JInt (toInteger idx))
    , ("method", JStr method)
    , ("expected", expected)
    , ("actual", actual)
    ]
