-- Tiny JSON encoder/decoder. No cabal packages.
module MiniJson
  ( Value (..)
  , decode
  , encode
  , argInt
  , argStr
  , objVal
  , objStr
  )
where

import Data.Char (chr, isDigit, ord)
import Data.Int (Int64)
import Numeric (showHex)

data Value
  = JNull
  | JBool Bool
  | JInt Integer
  | JStr String
  | JArr [Value]
  | JObj [(String, Value)]
  deriving (Eq, Show)

argInt :: [Value] -> Int -> Int64
argInt args i =
  case args !! i of
    JInt n -> fromInteger n
    JStr s -> fromInteger (read s)
    _ -> error "expected int arg"

argStr :: [Value] -> Int -> String
argStr args i =
  case args !! i of
    JStr s -> s
    _ -> error "expected string arg"

objVal :: Value -> String -> Value
objVal (JObj pairs) key = go pairs
  where
    go [] = JNull
    go ((k, v) : rest) = if k == key then v else go rest
objVal _ _ = JNull

objStr :: Value -> String -> String
objStr row key =
  case objVal row key of
    JStr s -> s
    _ -> ""

decode :: String -> Value
decode input =
  case value (skip input) of
    (val, rest)
      | null (skip rest) -> val
      | otherwise -> error "trailing json"

encode :: Value -> String
encode JNull = "null"
encode (JBool True) = "true"
encode (JBool False) = "false"
encode (JInt n) = show n
encode (JStr s) = '"' : escape s ++ "\""
encode (JArr xs) = '[' : intercalate "," (map encode xs) ++ "]"
encode (JObj pairs) =
  '{' : intercalate "," [encode (JStr k) ++ ":" ++ encode v | (k, v) <- pairs] ++ "}"

intercalate :: [a] -> [[a]] -> [a]
intercalate _ [] = []
intercalate sep (x : xs) = x ++ concatMap (sep ++) xs

escape :: String -> String
escape = concatMap esc
  where
    esc c
      | c == '"' = "\\\""
      | c == '\\' = "\\\\"
      | c == '\b' = "\\b"
      | c == '\f' = "\\f"
      | c == '\n' = "\\n"
      | c == '\r' = "\\r"
      | c == '\t' = "\\t"
      | ord c < 32 = "\\u" ++ pad4 (showHex (ord c) "")
      | otherwise = [c]
    pad4 hex = replicate (4 - length hex) '0' ++ hex

skip :: String -> String
skip (' ' : xs) = skip xs
skip ('\t' : xs) = skip xs
skip ('\n' : xs) = skip xs
skip ('\r' : xs) = skip xs
skip xs = xs

value :: String -> (Value, String)
value ('n' : 'u' : 'l' : 'l' : xs) = (JNull, xs)
value ('t' : 'r' : 'u' : 'e' : xs) = (JBool True, xs)
value ('f' : 'a' : 'l' : 's' : 'e' : xs) = (JBool False, xs)
value ('[' : xs) = parseArray (skip xs) []
value ('{' : xs) = parseObject (skip xs) []
value ('"' : xs) =
  let (s, rest) = parseString xs []
   in (JStr s, rest)
value xs@(c : _)
  | c == '-' || isDigit c = parseNumber xs
value _ = error "bad json"

parseArray :: String -> [Value] -> (Value, String)
parseArray (']' : xs) acc = (JArr (reverse acc), xs)
parseArray xs acc =
  let (val, rest0) = value (skip xs)
      rest = skip rest0
   in case rest of
        (',' : rest1) -> parseArray (skip rest1) (val : acc)
        (']' : rest1) -> (JArr (reverse (val : acc)), rest1)
        _ -> error "bad json array"

parseObject :: String -> [(String, Value)] -> (Value, String)
parseObject ('}' : xs) acc = (JObj (reverse acc), xs)
parseObject ('"' : xs) acc =
  let (key, rest1) = parseString xs []
      rest2 = skip rest1
   in case rest2 of
        (':' : rest3) ->
          let (val, rest4) = value (skip rest3)
              rest5 = skip rest4
           in case rest5 of
                (',' : rest6) -> parseObject (skip rest6) ((key, val) : acc)
                ('}' : rest6) -> (JObj (reverse ((key, val) : acc)), rest6)
                _ -> error "bad json object"
        _ -> error "bad json object"
parseObject _ _ = error "bad json object"

parseString :: String -> String -> (String, String)
parseString ('"' : xs) acc = (reverse acc, xs)
parseString ('\\' : 'u' : a : b : c : d : xs) acc =
  parseString xs (chr (readHex4 [a, b, c, d]) : acc)
parseString ('\\' : c : xs) acc = parseString xs (unescape c : acc)
parseString (c : xs) acc = parseString xs (c : acc)
parseString [] _ = error "unterminated string"

unescape :: Char -> Char
unescape '"' = '"'
unescape '\\' = '\\'
unescape '/' = '/'
unescape 'b' = '\b'
unescape 'f' = '\f'
unescape 'n' = '\n'
unescape 'r' = '\r'
unescape 't' = '\t'
unescape c = c

readHex4 :: String -> Int
readHex4 = go 0
  where
    go n [] = n
    go n (c : cs) = go (n * 16 + hexDigit c) cs

hexDigit :: Char -> Int
hexDigit c
  | c >= '0' && c <= '9' = ord c - ord '0'
  | c >= 'a' && c <= 'f' = 10 + ord c - ord 'a'
  | c >= 'A' && c <= 'F' = 10 + ord c - ord 'A'
  | otherwise = error "bad hex"

parseNumber :: String -> (Value, String)
parseNumber ('-' : xs) =
  case parseUnsigned xs of
    (n, rest) -> (JInt (-n), rest)
parseNumber xs =
  case parseUnsigned xs of
    (n, rest) -> (JInt n, rest)

parseUnsigned :: String -> (Integer, String)
parseUnsigned xs =
  let (digits, rest) = span isDigit xs
   in if null digits
        then error "bad json number"
        else (read digits, skipExp rest)

skipExp :: String -> String
skipExp (c : xs)
  | c == 'e' || c == 'E' =
      case xs of
        (sign : rest)
          | sign == '+' || sign == '-' -> snd (span isDigit rest)
        _ -> snd (span isDigit xs)
skipExp ('.' : xs) = snd (span isDigit xs)
skipExp xs = xs
