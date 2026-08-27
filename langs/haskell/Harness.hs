-- Typed method table. Defaults throw so a bank stub compiles and traces fail.
module Harness
  ( Target (..)
  , dispatch
  )
where

import Data.Int (Int64)
import MiniJson

missing :: String -> a
missing name = error ("missing method " ++ name)

class Target a where
  createAccount :: a -> Int64 -> String -> (Bool, a)
  createAccount _ _ _ = missing "create_account"
  deposit :: a -> Int64 -> String -> Int64 -> (Maybe Int64, a)
  deposit _ _ _ _ = missing "deposit"
  transfer :: a -> Int64 -> String -> String -> Int64 -> (Maybe Int64, a)
  transfer _ _ _ _ _ = missing "transfer"
  topSpenders :: a -> Int64 -> Int64 -> ([String], a)
  topSpenders _ _ _ = missing "top_spenders"
  pay :: a -> Int64 -> String -> Int64 -> (Maybe String, a)
  pay _ _ _ _ = missing "pay"
  getPaymentStatus :: a -> Int64 -> String -> String -> (Maybe String, a)
  getPaymentStatus _ _ _ _ = missing "get_payment_status"
  mergeAccounts :: a -> Int64 -> String -> String -> (Bool, a)
  mergeAccounts _ _ _ _ = missing "merge_accounts"
  getBalance :: a -> Int64 -> String -> Int64 -> (Maybe Int64, a)
  getBalance _ _ _ _ = missing "get_balance"
  addFile :: a -> String -> Int64 -> (String, a)
  addFile _ _ _ = missing "add_file"
  getFileSize :: a -> String -> (String, a)
  getFileSize _ _ = missing "get_file_size"
  deleteFile :: a -> String -> (String, a)
  deleteFile _ _ = missing "delete_file"
  getNLargest :: a -> String -> Int64 -> (String, a)
  getNLargest _ _ _ = missing "get_n_largest"
  addUser :: a -> String -> Int64 -> (String, a)
  addUser _ _ _ = missing "add_user"
  addFileBy :: a -> String -> String -> Int64 -> (String, a)
  addFileBy _ _ _ _ = missing "add_file_by"
  mergeUser :: a -> String -> String -> (String, a)
  mergeUser _ _ _ = missing "merge_user"
  backupUser :: a -> String -> (String, a)
  backupUser _ _ = missing "backup_user"
  restoreUser :: a -> String -> (String, a)
  restoreUser _ _ = missing "restore_user"
  addWorker :: a -> String -> String -> Int64 -> (String, a)
  addWorker _ _ _ _ = missing "add_worker"
  register :: a -> String -> Int64 -> (String, a)
  register _ _ _ = missing "register"
  get1 :: a -> String -> (String, a)
  get1 _ _ = missing "get"
  topNWorkers :: a -> Int64 -> String -> (String, a)
  topNWorkers _ _ _ = missing "top_n_workers"
  promote :: a -> String -> String -> Int64 -> Int64 -> (String, a)
  promote _ _ _ _ _ = missing "promote"
  calcSalary :: a -> String -> Int64 -> Int64 -> (String, a)
  calcSalary _ _ _ _ = missing "calc_salary"
  set :: a -> String -> String -> String -> (String, a)
  set _ _ _ _ = missing "set"
  get2 :: a -> String -> String -> (String, a)
  get2 _ _ _ = missing "get"
  delete :: a -> String -> String -> (String, a)
  delete _ _ _ = missing "delete"
  scan :: a -> String -> (String, a)
  scan _ _ = missing "scan"
  scanByPrefix :: a -> String -> String -> (String, a)
  scanByPrefix _ _ _ = missing "scan_by_prefix"
  setAt :: a -> String -> String -> String -> Int64 -> (String, a)
  setAt _ _ _ _ _ = missing "set_at"
  setAtWithTtl :: a -> String -> String -> String -> Int64 -> Int64 -> (String, a)
  setAtWithTtl _ _ _ _ _ _ = missing "set_at_with_ttl"
  deleteAt :: a -> String -> String -> Int64 -> (String, a)
  deleteAt _ _ _ _ = missing "delete_at"
  getAt :: a -> String -> String -> Int64 -> (String, a)
  getAt _ _ _ _ = missing "get_at"
  scanAt :: a -> String -> Int64 -> (String, a)
  scanAt _ _ _ = missing "scan_at"
  scanByPrefixAt :: a -> String -> String -> Int64 -> (String, a)
  scanByPrefixAt _ _ _ _ = missing "scan_by_prefix_at"
  backup :: a -> Int64 -> (String, a)
  backup _ _ = missing "backup"
  restore :: a -> Int64 -> Int64 -> (String, a)
  restore _ _ _ = missing "restore"

maybeInt :: Maybe Int64 -> Value
maybeInt Nothing = JNull
maybeInt (Just n) = JInt (toInteger n)

maybeStr :: Maybe String -> Value
maybeStr Nothing = JNull
maybeStr (Just s) = JStr s

dispatch :: Target a => a -> String -> [Value] -> (Value, a)
dispatch obj method args =
  case method of
    "create_account" ->
      let (r, obj') = createAccount obj (argInt args 0) (argStr args 1)
       in (JBool r, obj')
    "deposit" ->
      let (r, obj') = deposit obj (argInt args 0) (argStr args 1) (argInt args 2)
       in (maybeInt r, obj')
    "transfer" ->
      let (r, obj') =
            transfer obj (argInt args 0) (argStr args 1) (argStr args 2) (argInt args 3)
       in (maybeInt r, obj')
    "top_spenders" ->
      let (r, obj') = topSpenders obj (argInt args 0) (argInt args 1)
       in (JArr (map JStr r), obj')
    "pay" ->
      let (r, obj') = pay obj (argInt args 0) (argStr args 1) (argInt args 2)
       in (maybeStr r, obj')
    "get_payment_status" ->
      let (r, obj') = getPaymentStatus obj (argInt args 0) (argStr args 1) (argStr args 2)
       in (maybeStr r, obj')
    "merge_accounts" ->
      let (r, obj') = mergeAccounts obj (argInt args 0) (argStr args 1) (argStr args 2)
       in (JBool r, obj')
    "get_balance" ->
      let (r, obj') = getBalance obj (argInt args 0) (argStr args 1) (argInt args 2)
       in (maybeInt r, obj')
    "add_file" -> wrapStr (addFile obj (argStr args 0) (argInt args 1))
    "get_file_size" -> wrapStr (getFileSize obj (argStr args 0))
    "delete_file" -> wrapStr (deleteFile obj (argStr args 0))
    "get_n_largest" -> wrapStr (getNLargest obj (argStr args 0) (argInt args 1))
    "add_user" -> wrapStr (addUser obj (argStr args 0) (argInt args 1))
    "add_file_by" -> wrapStr (addFileBy obj (argStr args 0) (argStr args 1) (argInt args 2))
    "merge_user" -> wrapStr (mergeUser obj (argStr args 0) (argStr args 1))
    "backup_user" -> wrapStr (backupUser obj (argStr args 0))
    "restore_user" -> wrapStr (restoreUser obj (argStr args 0))
    "add_worker" -> wrapStr (addWorker obj (argStr args 0) (argStr args 1) (argInt args 2))
    "register" -> wrapStr (register obj (argStr args 0) (argInt args 1))
    "get" ->
      if length args == 1
        then wrapStr (get1 obj (argStr args 0))
        else wrapStr (get2 obj (argStr args 0) (argStr args 1))
    "top_n_workers" -> wrapStr (topNWorkers obj (argInt args 0) (argStr args 1))
    "promote" ->
      wrapStr (promote obj (argStr args 0) (argStr args 1) (argInt args 2) (argInt args 3))
    "calc_salary" -> wrapStr (calcSalary obj (argStr args 0) (argInt args 1) (argInt args 2))
    "set" -> wrapStr (set obj (argStr args 0) (argStr args 1) (argStr args 2))
    "delete" -> wrapStr (delete obj (argStr args 0) (argStr args 1))
    "scan" -> wrapStr (scan obj (argStr args 0))
    "scan_by_prefix" -> wrapStr (scanByPrefix obj (argStr args 0) (argStr args 1))
    "set_at" ->
      wrapStr (setAt obj (argStr args 0) (argStr args 1) (argStr args 2) (argInt args 3))
    "set_at_with_ttl" ->
      wrapStr
        ( setAtWithTtl
            obj
            (argStr args 0)
            (argStr args 1)
            (argStr args 2)
            (argInt args 3)
            (argInt args 4)
        )
    "delete_at" -> wrapStr (deleteAt obj (argStr args 0) (argStr args 1) (argInt args 2))
    "get_at" -> wrapStr (getAt obj (argStr args 0) (argStr args 1) (argInt args 2))
    "scan_at" -> wrapStr (scanAt obj (argStr args 0) (argInt args 1))
    "scan_by_prefix_at" ->
      wrapStr (scanByPrefixAt obj (argStr args 0) (argStr args 1) (argInt args 2))
    "backup" -> wrapStr (backup obj (argInt args 0))
    "restore" -> wrapStr (restore obj (argInt args 0) (argInt args 1))
    _ -> missing method
  where
    wrapStr (r, obj') = (JStr r, obj')
