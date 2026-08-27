(* Reference workers register. Traces follow the public LibreSignal workers specs. *)

open Minijson

type worker = {
  worker_id : string;
  mutable position : string;
  mutable compensation : int64;
  mutable in_office : bool;
  mutable entered_at : int64 option;
  mutable finished : (int64 * int64 * int64 * string) list;
  mutable pending : (string * int64 * int64) option;
}

type t = { workers : (string, worker) Hashtbl.t }

let new_target () = { workers = Hashtbl.create 16 }

let rec take n xs =
  match (n, xs) with
  | n, _ when n <= 0 -> []
  | _, [] -> []
  | n, x :: rest -> x :: take (n - 1) rest

let total_time worker =
  List.fold_left
    (fun acc (start_ts, end_ts, _, _) -> Int64.add acc (Int64.sub end_ts start_ts))
    0L worker.finished

let position_time worker position =
  List.fold_left
    (fun acc (start_ts, end_ts, _, pos) ->
      if pos = position then Int64.add acc (Int64.sub end_ts start_ts) else acc)
    0L worker.finished

let apply_promo worker timestamp =
  match worker.pending with
  | Some (new_pos, new_comp, start_ts) when timestamp >= start_ts ->
      worker.position <- new_pos;
      worker.compensation <- new_comp;
      worker.pending <- None
  | _ -> ()

let add_worker sim worker_id position compensation =
  if Hashtbl.mem sim.workers worker_id then "false"
  else (
    Hashtbl.add sim.workers worker_id
      {
        worker_id;
        position;
        compensation;
        in_office = false;
        entered_at = None;
        finished = [];
        pending = None;
      };
    "true")

let register sim worker_id timestamp =
  match Hashtbl.find_opt sim.workers worker_id with
  | None -> "invalid_request"
  | Some worker when worker.in_office ->
      let entered =
        match worker.entered_at with Some ts -> ts | None -> timestamp
      in
      worker.finished <-
        worker.finished @ [ (entered, timestamp, worker.compensation, worker.position) ];
      worker.in_office <- false;
      worker.entered_at <- None;
      "registered"
  | Some worker ->
      apply_promo worker timestamp;
      worker.in_office <- true;
      worker.entered_at <- Some timestamp;
      "registered"

let get sim worker_id =
  match Hashtbl.find_opt sim.workers worker_id with
  | None -> ""
  | Some worker -> Int64.to_string (total_time worker)

let top_n_workers sim n position =
  let matched =
    Hashtbl.fold
      (fun _ w acc -> if w.position = position then w :: acc else acc)
      sim.workers []
  in
  let ordered =
    List.sort
      (fun a b ->
        let c = Int64.compare (position_time b position) (position_time a position) in
        if c <> 0 then c else String.compare a.worker_id b.worker_id)
      matched
  in
  let top = take (Int64.to_int n) ordered in
  String.concat ", "
    (List.map
       (fun w -> Printf.sprintf "%s(%Ld)" w.worker_id (position_time w position))
       top)

let promote sim worker_id new_position new_compensation start_timestamp =
  match Hashtbl.find_opt sim.workers worker_id with
  | None -> "invalid_request"
  | Some worker when worker.pending <> None -> "invalid_request"
  | Some worker ->
      worker.pending <- Some (new_position, new_compensation, start_timestamp);
      "success"

let calc_salary sim worker_id start_timestamp end_timestamp =
  match Hashtbl.find_opt sim.workers worker_id with
  | None -> ""
  | Some worker ->
      let total =
        List.fold_left
          (fun acc (session_start, session_end, rate, _) ->
            let lo = max session_start start_timestamp in
            let hi = min session_end end_timestamp in
            if hi > lo then Int64.add acc (Int64.mul (Int64.sub hi lo) rate)
            else acc)
          0L worker.finished
      in
      Int64.to_string total

let call t meth args =
  match meth with
  | "add_worker" ->
      JStr (add_worker t (arg_str args 0) (arg_str args 1) (arg_int args 2))
  | "register" -> JStr (register t (arg_str args 0) (arg_int args 1))
  | "get" -> JStr (get t (arg_str args 0))
  | "top_n_workers" -> JStr (top_n_workers t (arg_int args 0) (arg_str args 1))
  | "promote" ->
      JStr
        (promote t (arg_str args 0) (arg_str args 1) (arg_int args 2) (arg_int args 3))
  | "calc_salary" ->
      JStr (calc_salary t (arg_str args 0) (arg_int args 1) (arg_int args 2))
  | _ -> failwith ("missing method " ^ meth)
