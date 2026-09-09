(* Reference inventory register. *)

open Minijson

type item = {
  sku : string;
  name : string;
  mutable qty : int64;
  mutable reserved : int64;
}

type t = { items : (string, item) Hashtbl.t }

let new_target () = { items = Hashtbl.create 16 }

let create_item sim sku name =
  if Hashtbl.mem sim.items sku then "false"
  else (
    Hashtbl.add sim.items sku { sku; name; qty = 0L; reserved = 0L };
    "true")

let stock sim sku delta =
  match Hashtbl.find_opt sim.items sku with
  | None -> ""
  | Some item ->
      let nxt = Int64.add item.qty delta in
      if nxt < item.reserved then "invalid_request"
      else (
        item.qty <- nxt;
        Int64.to_string item.qty)

let get_qty sim sku =
  match Hashtbl.find_opt sim.items sku with
  | None -> ""
  | Some item -> Int64.to_string item.qty

let list_low sim threshold =
  let matched =
    Hashtbl.fold
      (fun _ item acc -> if item.qty <= threshold then item :: acc else acc)
      sim.items []
  in
  let ordered =
    List.sort
      (fun a b ->
        let c = compare a.qty b.qty in
        if c <> 0 then c else compare a.sku b.sku)
      matched
  in
  String.concat ", "
    (List.map (fun item -> item.sku ^ "(" ^ Int64.to_string item.qty ^ ")") ordered)

let reserve sim sku n =
  match Hashtbl.find_opt sim.items sku with
  | None -> "invalid_request"
  | Some item ->
      if n <= 0L || Int64.add item.reserved n > item.qty then "invalid_request"
      else (
        item.reserved <- Int64.add item.reserved n;
        "true")

let release sim sku n =
  match Hashtbl.find_opt sim.items sku with
  | None -> "invalid_request"
  | Some item ->
      if n <= 0L || n > item.reserved then "invalid_request"
      else (
        item.reserved <- Int64.sub item.reserved n;
        "true")

let ship sim sku n =
  match Hashtbl.find_opt sim.items sku with
  | None -> "invalid_request"
  | Some item ->
      if n <= 0L || n > item.reserved then "invalid_request"
      else (
        item.reserved <- Int64.sub item.reserved n;
        item.qty <- Int64.sub item.qty n;
        "true")

let call t meth args =
  match meth with
  | "create_item" -> JStr (create_item t (arg_str args 0) (arg_str args 1))
  | "stock" -> JStr (stock t (arg_str args 0) (arg_int args 1))
  | "get_qty" -> JStr (get_qty t (arg_str args 0))
  | "list_low" -> JStr (list_low t (arg_int args 0))
  | "reserve" -> JStr (reserve t (arg_str args 0) (arg_int args 1))
  | "release" -> JStr (release t (arg_str args 0) (arg_int args 1))
  | "ship" -> JStr (ship t (arg_str args 0) (arg_int args 1))
  | _ -> failwith ("missing method " ^ meth)
