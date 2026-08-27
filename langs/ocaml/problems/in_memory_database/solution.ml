(* Reference in-memory database. Traces ported from public LibreSignal tests (MIT). *)

open Minijson

type field_val = string * int64 option
type fields = (string, field_val) Hashtbl.t

type t = {
  database : (string, fields) Hashtbl.t;
  mutable backup_ts : int64 list;
  mutable backup_states : (string * (string * field_val) list) list list;
}

let new_target () =
  { database = Hashtbl.create 16; backup_ts = []; backup_states = [] }

let fields_of db key =
  match Hashtbl.find_opt db.database key with
  | Some fields -> fields
  | None ->
      let fields = Hashtbl.create 8 in
      Hashtbl.add db.database key fields;
      fields

let set_internal db key field value expiry =
  Hashtbl.replace (fields_of db key) field (value, expiry);
  ""

let is_alive db key field timestamp =
  match Hashtbl.find_opt db.database key with
  | None -> false
  | Some fields -> (
      match Hashtbl.find_opt fields field with
      | None -> false
      | Some (_, None) -> true
      | Some (_, Some expiry) -> timestamp < expiry)

let set db key field value = set_internal db key field value None

let get db key field =
  match Hashtbl.find_opt db.database key with
  | None -> ""
  | Some fields -> (
      match Hashtbl.find_opt fields field with
      | None -> ""
      | Some (value, _) -> value)

let delete db key field =
  match Hashtbl.find_opt db.database key with
  | None -> "false"
  | Some fields ->
      if not (Hashtbl.mem fields field) then "false"
      else (
        Hashtbl.remove fields field;
        "true")

let join_parts parts = String.concat ", " parts

let scan_fields fields pred =
  let items =
    Hashtbl.fold
      (fun field (value, _) acc ->
        if pred field then (field, value) :: acc else acc)
      fields []
  in
  let items = List.sort (fun (a, _) (b, _) -> String.compare a b) items in
  join_parts (List.map (fun (field, value) -> field ^ "(" ^ value ^ ")") items)

let scan db key =
  match Hashtbl.find_opt db.database key with
  | None -> ""
  | Some fields -> scan_fields fields (fun _ -> true)

let scan_by_prefix db key prefix =
  match Hashtbl.find_opt db.database key with
  | None -> ""
  | Some fields -> scan_fields fields (fun field -> String.starts_with ~prefix field)

let set_at db key field value _timestamp = set_internal db key field value None

let set_at_with_ttl db key field value timestamp ttl =
  set_internal db key field value (Some (Int64.add timestamp ttl))

let delete_at db key field timestamp =
  if not (is_alive db key field timestamp) then "false"
  else (
    Hashtbl.remove (fields_of db key) field;
    "true")

let get_at db key field timestamp =
  if not (is_alive db key field timestamp) then ""
  else
    match Hashtbl.find_opt (fields_of db key) field with
    | None -> ""
    | Some (value, _) -> value

let scan_at db key timestamp =
  match Hashtbl.find_opt db.database key with
  | None -> ""
  | Some fields ->
      let items =
        Hashtbl.fold
          (fun field (value, _) acc ->
            if is_alive db key field timestamp then (field, value) :: acc else acc)
          fields []
      in
      let items = List.sort (fun (a, _) (b, _) -> String.compare a b) items in
      join_parts (List.map (fun (field, value) -> field ^ "(" ^ value ^ ")") items)

let scan_by_prefix_at db key prefix timestamp =
  match Hashtbl.find_opt db.database key with
  | None -> ""
  | Some fields ->
      let items =
        Hashtbl.fold
          (fun field (value, _) acc ->
            if String.starts_with ~prefix field && is_alive db key field timestamp
            then (field, value) :: acc
            else acc)
          fields []
      in
      let items = List.sort (fun (a, _) (b, _) -> String.compare a b) items in
      join_parts (List.map (fun (field, value) -> field ^ "(" ^ value ^ ")") items)

let backup db timestamp =
  let state =
    Hashtbl.fold
      (fun key fields acc ->
        let kept =
          Hashtbl.fold
            (fun field (value, expiry) acc ->
              if is_alive db key field timestamp then
                let remaining =
                  match expiry with None -> None | Some exp_ts -> Some (Int64.sub exp_ts timestamp)
                in
                (field, (value, remaining)) :: acc
              else acc)
            fields []
        in
        if kept = [] then acc else (key, kept) :: acc)
      db.database []
  in
  db.backup_ts <- db.backup_ts @ [ timestamp ];
  db.backup_states <- db.backup_states @ [ state ];
  string_of_int (List.length state)

let restore db timestamp timestamp_to_restore =
  let rec find_idx i last = function
    | t :: rest when t <= timestamp_to_restore -> find_idx (i + 1) i rest
    | _ -> last
  in
  let idx = find_idx 0 (-1) db.backup_ts in
  let backup_state = List.nth db.backup_states idx in
  Hashtbl.clear db.database;
  List.iter
    (fun (key, fields) ->
      List.iter
        (fun (field, (value, remaining)) ->
          let expiry =
            match remaining with None -> None | Some rem -> Some (Int64.add timestamp rem)
          in
          ignore (set_internal db key field value expiry))
        fields)
    backup_state;
  ""

let call t meth args =
  match meth with
  | "set" -> JStr (set t (arg_str args 0) (arg_str args 1) (arg_str args 2))
  | "get" ->
      if List.length args = 1 then failwith "missing method get"
      else JStr (get t (arg_str args 0) (arg_str args 1))
  | "delete" -> JStr (delete t (arg_str args 0) (arg_str args 1))
  | "scan" -> JStr (scan t (arg_str args 0))
  | "scan_by_prefix" -> JStr (scan_by_prefix t (arg_str args 0) (arg_str args 1))
  | "set_at" ->
      JStr
        (set_at t (arg_str args 0) (arg_str args 1) (arg_str args 2) (arg_int args 3))
  | "set_at_with_ttl" ->
      JStr
        (set_at_with_ttl t (arg_str args 0) (arg_str args 1) (arg_str args 2)
           (arg_int args 3) (arg_int args 4))
  | "delete_at" ->
      JStr (delete_at t (arg_str args 0) (arg_str args 1) (arg_int args 2))
  | "get_at" -> JStr (get_at t (arg_str args 0) (arg_str args 1) (arg_int args 2))
  | "scan_at" -> JStr (scan_at t (arg_str args 0) (arg_int args 1))
  | "scan_by_prefix_at" ->
      JStr (scan_by_prefix_at t (arg_str args 0) (arg_str args 1) (arg_int args 2))
  | "backup" -> JStr (backup t (arg_int args 0))
  | "restore" -> JStr (restore t (arg_int args 0) (arg_int args 1))
  | _ -> failwith ("missing method " ^ meth)
