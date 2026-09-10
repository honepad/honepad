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
  copyFile :: a -> String -> String -> (String, a)
  copyFile _ _ _ = missing "copy_file"
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
  setDoublePay :: a -> String -> Int64 -> Int64 -> (String, a)
  setDoublePay _ _ _ _ = missing "set_double_pay"
  createItem :: a -> String -> String -> (String, a)
  createItem _ _ _ = missing "create_item"
  stock :: a -> String -> Int64 -> (String, a)
  stock _ _ _ = missing "stock"
  getQty :: a -> String -> (String, a)
  getQty _ _ = missing "get_qty"
  listLow :: a -> Int64 -> (String, a)
  listLow _ _ = missing "list_low"
  reserve :: a -> String -> Int64 -> (String, a)
  reserve _ _ _ = missing "reserve"
  release :: a -> String -> Int64 -> (String, a)
  release _ _ _ = missing "release"
  ship :: a -> String -> Int64 -> (String, a)
  ship _ _ _ = missing "ship"
  allow :: a -> String -> Int64 -> (String, a)
  allow _ _ _ = missing "allow"
  configure :: a -> String -> Int64 -> Int64 -> (String, a)
  configure _ _ _ _ = missing "configure"
  remainingAt :: a -> String -> Int64 -> (String, a)
  remainingAt _ _ _ = missing "remaining"
  allowWeighted :: a -> String -> Int64 -> Int64 -> (String, a)
  allowWeighted _ _ _ _ = missing "allow_weighted"
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
  addGpu :: a -> String -> Int64 -> (String, a)
  addGpu _ _ _ = missing "add_gpu"
  submitJob :: a -> String -> Int64 -> (String, a)
  submitJob _ _ _ = missing "submit_job"
  status :: a -> String -> (String, a)
  status _ _ = missing "status"
  assign :: a -> (String, a)
  assign _ = missing "assign"
  complete :: a -> String -> (String, a)
  complete _ _ = missing "complete"
  cancel :: a -> String -> (String, a)
  cancel _ _ = missing "cancel"
  setPriority :: a -> String -> Int64 -> (String, a)
  setPriority _ _ _ = missing "set_priority"
  addBackend :: a -> String -> (String, a)
  addBackend _ _ = missing "add_backend"
  route :: a -> (String, a)
  route _ = missing "route"
  setHealth :: a -> String -> Int64 -> (String, a)
  setHealth _ _ _ = missing "set_health"
  setWeight :: a -> String -> Int64 -> (String, a)
  setWeight _ _ _ = missing "set_weight"
  sticky :: a -> String -> (String, a)
  sticky _ _ = missing "sticky"
  doneBackend :: a -> String -> (String, a)
  doneBackend _ _ = missing "done"
  subscribe :: a -> String -> String -> (String, a)
  subscribe _ _ _ = missing "subscribe"
  unsubscribe :: a -> String -> String -> (String, a)
  unsubscribe _ _ _ = missing "unsubscribe"
  publish :: a -> String -> String -> (String, a)
  publish _ _ _ = missing "publish"
  inbox :: a -> String -> (String, a)
  inbox _ _ = missing "inbox"
  listTopics :: a -> (String, a)
  listTopics _ = missing "list_topics"
  subscribers :: a -> String -> (String, a)
  subscribers _ _ = missing "subscribers"
  peek :: a -> String -> (String, a)
  peek _ _ = missing "peek"
  ack :: a -> String -> Int64 -> (String, a)
  ack _ _ _ = missing "ack"
  retain :: a -> String -> String -> (String, a)
  retain _ _ _ = missing "retain"
  insert :: a -> Int64 -> String -> (String, a)
  insert _ _ _ = missing "insert"
  erase :: a -> Int64 -> Int64 -> (String, a)
  erase _ _ _ = missing "erase"
  getText :: a -> (String, a)
  getText _ = missing "get_text"
  bufLength :: a -> (String, a)
  bufLength _ = missing "length"
  move :: a -> Int64 -> (String, a)
  move _ _ = missing "move"
  typeText :: a -> String -> (String, a)
  typeText _ _ = missing "type_text"
  cursor :: a -> (String, a)
  cursor _ = missing "cursor"
  undo :: a -> (String, a)
  undo _ = missing "undo"
  redo :: a -> (String, a)
  redo _ = missing "redo"
  select :: a -> Int64 -> Int64 -> (String, a)
  select _ _ _ = missing "select"
  cut :: a -> (String, a)
  cut _ = missing "cut"
  copySel :: a -> (String, a)
  copySel _ = missing "copy_sel"
  paste :: a -> (String, a)
  paste _ = missing "paste"

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
    "copy_file" -> wrapStr (copyFile obj (argStr args 0) (argStr args 1))
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
    "set_double_pay" ->
      wrapStr (setDoublePay obj (argStr args 0) (argInt args 1) (argInt args 2))
    "create_item" -> wrapStr (createItem obj (argStr args 0) (argStr args 1))
    "stock" -> wrapStr (stock obj (argStr args 0) (argInt args 1))
    "get_qty" -> wrapStr (getQty obj (argStr args 0))
    "list_low" -> wrapStr (listLow obj (argInt args 0))
    "reserve" -> wrapStr (reserve obj (argStr args 0) (argInt args 1))
    "release" -> wrapStr (release obj (argStr args 0) (argInt args 1))
    "ship" -> wrapStr (ship obj (argStr args 0) (argInt args 1))
    "allow" -> wrapStr (allow obj (argStr args 0) (argInt args 1))
    "configure" ->
      wrapStr (configure obj (argStr args 0) (argInt args 1) (argInt args 2))
    "remaining" -> wrapStr (remainingAt obj (argStr args 0) (argInt args 1))
    "allow_weighted" ->
      wrapStr (allowWeighted obj (argStr args 0) (argInt args 1) (argInt args 2))
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
    "add_gpu" -> wrapStr (addGpu obj (argStr args 0) (argInt args 1))
    "submit_job" -> wrapStr (submitJob obj (argStr args 0) (argInt args 1))
    "status" -> wrapStr (status obj (argStr args 0))
    "assign" -> wrapStr (assign obj)
    "complete" -> wrapStr (complete obj (argStr args 0))
    "cancel" -> wrapStr (cancel obj (argStr args 0))
    "set_priority" -> wrapStr (setPriority obj (argStr args 0) (argInt args 1))
    "add_backend" -> wrapStr (addBackend obj (argStr args 0))
    "route" -> wrapStr (route obj)
    "set_health" -> wrapStr (setHealth obj (argStr args 0) (argInt args 1))
    "set_weight" -> wrapStr (setWeight obj (argStr args 0) (argInt args 1))
    "sticky" -> wrapStr (sticky obj (argStr args 0))
    "done" -> wrapStr (doneBackend obj (argStr args 0))
    "subscribe" -> wrapStr (subscribe obj (argStr args 0) (argStr args 1))
    "unsubscribe" -> wrapStr (unsubscribe obj (argStr args 0) (argStr args 1))
    "publish" -> wrapStr (publish obj (argStr args 0) (argStr args 1))
    "inbox" -> wrapStr (inbox obj (argStr args 0))
    "list_topics" -> wrapStr (listTopics obj)
    "subscribers" -> wrapStr (subscribers obj (argStr args 0))
    "peek" -> wrapStr (peek obj (argStr args 0))
    "ack" -> wrapStr (ack obj (argStr args 0) (argInt args 1))
    "retain" -> wrapStr (retain obj (argStr args 0) (argStr args 1))
    "insert" -> wrapStr (insert obj (argInt args 0) (argStr args 1))
    "erase" -> wrapStr (erase obj (argInt args 0) (argInt args 1))
    "get_text" -> wrapStr (getText obj)
    "length" -> wrapStr (bufLength obj)
    "move" -> wrapStr (move obj (argInt args 0))
    "type_text" -> wrapStr (typeText obj (argStr args 0))
    "cursor" -> wrapStr (cursor obj)
    "undo" -> wrapStr (undo obj)
    "redo" -> wrapStr (redo obj)
    "select" -> wrapStr (select obj (argInt args 0) (argInt args 1))
    "cut" -> wrapStr (cut obj)
    "copy_sel" -> wrapStr (copySel obj)
    "paste" -> wrapStr (paste obj)
    _ -> missing method
  where
    wrapStr (r, obj') = (JStr r, obj')
