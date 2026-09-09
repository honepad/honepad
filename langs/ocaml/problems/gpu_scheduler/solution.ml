(* Reference GPU scheduler. *)

open Minijson

type gpu = {
  gid : string;
  gmem : int64;
  mutable assigned : string option;
}

type job = {
  jid : string;
  jmem : int64;
  seq : int64;
  mutable priority : int64;
  mutable state : string;
  mutable on_gpu : string option;
}

type t = {
  gpus : (string, gpu) Hashtbl.t;
  mutable gpu_order : string list;
  jobs : (string, job) Hashtbl.t;
  mutable next_seq : int64;
}

let new_target () =
  { gpus = Hashtbl.create 16; gpu_order = []; jobs = Hashtbl.create 16; next_seq = 0L }

let add_gpu sim gpu_id mem =
  if mem <= 0L then "invalid_request"
  else if Hashtbl.mem sim.gpus gpu_id then "false"
  else (
    Hashtbl.add sim.gpus gpu_id { gid = gpu_id; gmem = mem; assigned = None };
    sim.gpu_order <- sim.gpu_order @ [ gpu_id ];
    "true")

let submit_job sim job_id mem =
  if mem <= 0L then "invalid_request"
  else if Hashtbl.mem sim.jobs job_id then "false"
  else (
    Hashtbl.add sim.jobs job_id
      {
        jid = job_id;
        jmem = mem;
        seq = sim.next_seq;
        priority = 0L;
        state = "queued";
        on_gpu = None;
      };
    sim.next_seq <- Int64.add sim.next_seq 1L;
    "true")

let status sim job_id =
  match Hashtbl.find_opt sim.jobs job_id with
  | None -> ""
  | Some job -> job.state

let place job gpu =
  job.state <- "running";
  job.on_gpu <- Some gpu.gid;
  gpu.assigned <- Some job.jid

let assign sim =
  let queued =
    Hashtbl.fold
      (fun _ job acc -> if job.state = "queued" then job :: acc else acc)
      sim.jobs []
  in
  let queued =
    List.sort
      (fun a b ->
        let c = compare b.priority a.priority in
        if c <> 0 then c else compare a.seq b.seq)
      queued
  in
  let rec try_gpus job = function
    | [] -> None
    | gpu_id :: rest -> (
        match Hashtbl.find_opt sim.gpus gpu_id with
        | Some gpu when gpu.assigned = None && gpu.gmem >= job.jmem -> Some gpu
        | _ -> try_gpus job rest)
  in
  let rec try_jobs = function
    | [] -> ""
    | job :: rest -> (
        match try_gpus job sim.gpu_order with
        | Some gpu ->
            place job gpu;
            job.jid
        | None -> try_jobs rest)
  in
  try_jobs queued

let complete sim job_id =
  match Hashtbl.find_opt sim.jobs job_id with
  | Some job when job.state = "running" -> (
      match job.on_gpu with
      | None -> "invalid_request"
      | Some gpu_id ->
          (match Hashtbl.find_opt sim.gpus gpu_id with
          | Some gpu -> gpu.assigned <- None
          | None -> ());
          job.on_gpu <- None;
          job.state <- "done";
          "true")
  | _ -> "invalid_request"

let cancel sim job_id =
  match Hashtbl.find_opt sim.jobs job_id with
  | None -> "invalid_request"
  | Some job when job.state = "done" -> "invalid_request"
  | Some job ->
      let running = job.state = "running" in
      if running then (
        match job.on_gpu with
        | Some gpu_id -> (
            match Hashtbl.find_opt sim.gpus gpu_id with
            | Some gpu -> gpu.assigned <- None
            | None -> ())
        | None -> ());
      Hashtbl.remove sim.jobs job_id;
      if running then ignore (assign sim);
      "true"

let set_priority sim job_id priority =
  match Hashtbl.find_opt sim.jobs job_id with
  | Some job when job.state = "queued" ->
      job.priority <- priority;
      "true"
  | _ -> "invalid_request"

let call t meth args =
  match meth with
  | "add_gpu" -> JStr (add_gpu t (arg_str args 0) (arg_int args 1))
  | "submit_job" -> JStr (submit_job t (arg_str args 0) (arg_int args 1))
  | "status" -> JStr (status t (arg_str args 0))
  | "assign" -> JStr (assign t)
  | "complete" -> JStr (complete t (arg_str args 0))
  | "cancel" -> JStr (cancel t (arg_str args 0))
  | "set_priority" -> JStr (set_priority t (arg_str args 0) (arg_int args 1))
  | _ -> failwith ("missing method " ^ meth)
