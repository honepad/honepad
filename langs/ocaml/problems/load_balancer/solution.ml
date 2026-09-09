(* Reference load balancer. *)

open Minijson

type backend = {
  bid : string;
  mutable health : bool;
  mutable weight : int64;
  mutable inflight : int64;
}

type t = {
  backends : backend list ref;
  by_id : (string, backend) Hashtbl.t;
  mutable cursor : int64;
  sticky : (string, string) Hashtbl.t;
  mutable use_least : bool;
}

let new_target () =
  {
    backends = ref [];
    by_id = Hashtbl.create 16;
    cursor = 0L;
    sticky = Hashtbl.create 16;
    use_least = false;
  }

let add_backend sim backend_id =
  if Hashtbl.mem sim.by_id backend_id then "false"
  else (
    let item = { bid = backend_id; health = true; weight = 1L; inflight = 0L } in
    sim.backends := !(sim.backends) @ [ item ];
    Hashtbl.add sim.by_id backend_id item;
    "true")

let reset_cycle sim =
  sim.cursor <- 0L;
  sim.use_least <- false;
  List.iter (fun item -> item.inflight <- 0L) !(sim.backends)

let set_health sim backend_id flag =
  match Hashtbl.find_opt sim.by_id backend_id with
  | None -> "invalid_request"
  | Some _ when flag <> 0L && flag <> 1L -> "invalid_request"
  | Some item ->
      item.health <- flag = 1L;
      reset_cycle sim;
      "true"

let set_weight sim backend_id weight =
  match Hashtbl.find_opt sim.by_id backend_id with
  | None -> "invalid_request"
  | Some _ when weight <= 0L -> "invalid_request"
  | Some item ->
      item.weight <- weight;
      reset_cycle sim;
      "true"

let tickets items =
  List.concat_map
    (fun item -> List.init (Int64.to_int item.weight) (fun _ -> item))
    items

let pick sim =
  let healthy = List.filter (fun item -> item.health) !(sim.backends) in
  match healthy with
  | [] -> None
  | _ ->
      let pool =
        if sim.use_least then
          let least =
            List.fold_left
              (fun acc item -> if item.inflight < acc then item.inflight else acc)
              (List.hd healthy).inflight healthy
          in
          List.filter (fun item -> item.inflight = least) healthy
        else healthy
      in
      let ticket_list = tickets pool in
      if ticket_list = [] then None
      else
        let idx = Int64.to_int (Int64.rem sim.cursor (Int64.of_int (List.length ticket_list))) in
        let chosen = List.nth ticket_list idx in
        sim.cursor <- Int64.add sim.cursor 1L;
        Some chosen

let take sim =
  match pick sim with
  | None -> ""
  | Some item ->
      item.inflight <- Int64.add item.inflight 1L;
      item.bid

let route sim = take sim

let sticky sim client_id =
  match Hashtbl.find_opt sim.sticky client_id with
  | Some bound -> (
      match Hashtbl.find_opt sim.by_id bound with
      | Some item when item.health ->
          item.inflight <- Int64.add item.inflight 1L;
          item.bid
      | _ ->
          let chosen = take sim in
          if chosen <> "" then Hashtbl.replace sim.sticky client_id chosen;
          chosen)
  | None ->
      let chosen = take sim in
      if chosen <> "" then Hashtbl.replace sim.sticky client_id chosen;
      chosen

let done_backend sim backend_id =
  match Hashtbl.find_opt sim.by_id backend_id with
  | Some item when item.inflight > 0L ->
      item.inflight <- Int64.sub item.inflight 1L;
      sim.use_least <- true;
      "true"
  | _ -> "invalid_request"

let call t meth args =
  match meth with
  | "add_backend" -> JStr (add_backend t (arg_str args 0))
  | "route" -> JStr (route t)
  | "set_health" -> JStr (set_health t (arg_str args 0) (arg_int args 1))
  | "set_weight" -> JStr (set_weight t (arg_str args 0) (arg_int args 1))
  | "sticky" -> JStr (sticky t (arg_str args 0))
  | "done" -> JStr (done_backend t (arg_str args 0))
  | _ -> failwith ("missing method " ^ meth)
