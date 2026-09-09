(* Reference rate limiter. *)

open Minijson

type key_state = {
  mutable limit : int64;
  mutable window : int64;
  mutable window_id : int64 option;
  mutable used : int64;
}

type t = { keys : (string, key_state) Hashtbl.t }

let new_target () = { keys = Hashtbl.create 16 }

let state sim key =
  match Hashtbl.find_opt sim.keys key with
  | Some item -> item
  | None ->
      let item = { limit = 3L; window = 10L; window_id = None; used = 0L } in
      Hashtbl.add sim.keys key item;
      item

let used_at item timestamp persist =
  let window_id = Int64.div timestamp item.window in
  match item.window_id with
  | Some current when current = window_id -> item.used
  | _ ->
      if persist then (
        item.window_id <- Some window_id;
        item.used <- 0L);
      0L

let rec allow_weighted sim key cost timestamp =
  if cost <= 0L then "invalid_request"
  else
    let item = state sim key in
    ignore (used_at item timestamp true);
    if Int64.add item.used cost > item.limit then "false"
    else (
      item.used <- Int64.add item.used cost;
      "true")

and allow sim key timestamp = allow_weighted sim key 1L timestamp

let configure sim key limit window =
  if limit <= 0L || window <= 0L then "invalid_request"
  else
    let item = state sim key in
    item.limit <- limit;
    item.window <- window;
    item.window_id <- None;
    item.used <- 0L;
    "true"

let remaining sim key timestamp =
  let item = state sim key in
  let used = used_at item timestamp false in
  Int64.to_string (Int64.sub item.limit used)

let call t meth args =
  match meth with
  | "allow" -> JStr (allow t (arg_str args 0) (arg_int args 1))
  | "configure" ->
      JStr (configure t (arg_str args 0) (arg_int args 1) (arg_int args 2))
  | "remaining" -> JStr (remaining t (arg_str args 0) (arg_int args 1))
  | "allow_weighted" ->
      JStr (allow_weighted t (arg_str args 0) (arg_int args 1) (arg_int args 2))
  | _ -> failwith ("missing method " ^ meth)
