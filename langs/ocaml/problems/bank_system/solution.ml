(* Reference bank system. Traces ported from public LibreSignal tests (MIT). *)

open Minijson

let cashback_delay = 86_400_000L

type account = {
  acc_id : string;
  mutable balance : int64;
  mutable outgoing : int64;
  payments : (string, string) Hashtbl.t;
  mutable created_at : int64;
  mutable history : (int64 * int64) list;
}

type t = {
  accounts : (string, account) Hashtbl.t;
  mutable pay_count : int;
  mutable pending : (int64 * string * int64 * string) list;
}

let new_target () =
  { accounts = Hashtbl.create 16; pay_count = 0; pending = [] }

let new_account account_id created_at =
  {
    acc_id = account_id;
    balance = 0L;
    outgoing = 0L;
    payments = Hashtbl.create 8;
    created_at;
    history = [ (created_at, 0L) ];
  }

let record_balance acc ts = acc.history <- acc.history @ [ (ts, acc.balance) ]

let rec process_cashbacks sim timestamp =
  match sim.pending with
  | (cb_ts, account_id, amount, payment_id) :: rest when cb_ts <= timestamp ->
      sim.pending <- rest;
      (match Hashtbl.find_opt sim.accounts account_id with
      | None -> ()
      | Some acc ->
          acc.balance <- Int64.add acc.balance amount;
          Hashtbl.replace acc.payments payment_id "CASHBACK_RECEIVED";
          record_balance acc cb_ts);
      process_cashbacks sim timestamp
  | _ -> ()

let rec take n xs =
  match (n, xs) with
  | n, _ when n <= 0 -> []
  | _, [] -> []
  | n, x :: rest -> x :: take (n - 1) rest

let balance_at acc time_at =
  if time_at < acc.created_at then None
  else
    let rec go found = function
      | [] -> found
      | (ts, bal) :: rest ->
          if ts <= time_at then go (Some bal) rest else found
    in
    go None acc.history

let create_account sim timestamp account_id =
  process_cashbacks sim timestamp;
  if Hashtbl.mem sim.accounts account_id then false
  else (
    Hashtbl.add sim.accounts account_id (new_account account_id timestamp);
    true)

let deposit sim timestamp account_id amount =
  process_cashbacks sim timestamp;
  match Hashtbl.find_opt sim.accounts account_id with
  | None -> None
  | Some acc ->
      acc.balance <- Int64.add acc.balance amount;
      record_balance acc timestamp;
      Some acc.balance

let transfer sim timestamp source_id target_id amount =
  process_cashbacks sim timestamp;
  match
    ( Hashtbl.find_opt sim.accounts source_id,
      Hashtbl.find_opt sim.accounts target_id )
  with
  | Some src, Some tgt when source_id <> target_id ->
      if src.balance < amount then None
      else (
        src.balance <- Int64.sub src.balance amount;
        src.outgoing <- Int64.add src.outgoing amount;
        tgt.balance <- Int64.add tgt.balance amount;
        record_balance src timestamp;
        record_balance tgt timestamp;
        Some src.balance)
  | _ -> None

let top_spenders sim timestamp n =
  process_cashbacks sim timestamp;
  let ids = Hashtbl.fold (fun k _ acc -> k :: acc) sim.accounts [] in
  let ordered =
    List.sort
      (fun a b ->
        let oa = (Hashtbl.find sim.accounts a).outgoing in
        let ob = (Hashtbl.find sim.accounts b).outgoing in
        let c = Int64.compare ob oa in
        if c <> 0 then c else String.compare a b)
      ids
  in
  List.map
    (fun id ->
      let acc = Hashtbl.find sim.accounts id in
      Printf.sprintf "%s(%Ld)" acc.acc_id acc.outgoing)
    (take (Int64.to_int n) ordered)

let pay sim timestamp account_id amount =
  process_cashbacks sim timestamp;
  match Hashtbl.find_opt sim.accounts account_id with
  | None -> None
  | Some acc ->
      if acc.balance < amount then None
      else (
        acc.balance <- Int64.sub acc.balance amount;
        acc.outgoing <- Int64.add acc.outgoing amount;
        sim.pay_count <- sim.pay_count + 1;
        let payment_id = "payment" ^ string_of_int sim.pay_count in
        Hashtbl.replace acc.payments payment_id "IN_PROGRESS";
        record_balance acc timestamp;
        let cashback = Int64.div (Int64.mul amount 2L) 100L in
        sim.pending <-
          sim.pending
          @ [ (Int64.add timestamp cashback_delay, account_id, cashback, payment_id) ];
        Some payment_id)

let get_payment_status sim timestamp account_id payment =
  process_cashbacks sim timestamp;
  match Hashtbl.find_opt sim.accounts account_id with
  | None -> None
  | Some acc -> Hashtbl.find_opt acc.payments payment

let merge_accounts sim timestamp account_id_1 account_id_2 =
  process_cashbacks sim timestamp;
  if account_id_1 = account_id_2 then false
  else
    match
      ( Hashtbl.find_opt sim.accounts account_id_1,
        Hashtbl.find_opt sim.accounts account_id_2 )
    with
    | Some acc1, Some acc2 ->
        acc1.balance <- Int64.add acc1.balance acc2.balance;
        acc1.outgoing <- Int64.add acc1.outgoing acc2.outgoing;
        Hashtbl.iter (fun k v -> Hashtbl.replace acc1.payments k v) acc2.payments;
        acc1.history <-
          List.sort
            (fun (a, _) (b, _) -> Int64.compare a b)
            (acc1.history @ acc2.history);
        acc1.created_at <- min acc1.created_at acc2.created_at;
        record_balance acc1 timestamp;
        sim.pending <-
          List.map
            (fun (cb_ts, acc_id, amount, payment_id) ->
              let acc_id =
                if acc_id = account_id_2 then account_id_1 else acc_id
              in
              (cb_ts, acc_id, amount, payment_id))
            sim.pending;
        Hashtbl.remove sim.accounts account_id_2;
        true
    | _ -> false

let get_balance sim timestamp account_id time_at =
  process_cashbacks sim timestamp;
  match Hashtbl.find_opt sim.accounts account_id with
  | None -> None
  | Some acc -> balance_at acc time_at

let call t meth args =
  match meth with
  | "create_account" -> JBool (create_account t (arg_int args 0) (arg_str args 1))
  | "deposit" ->
      maybe_int (deposit t (arg_int args 0) (arg_str args 1) (arg_int args 2))
  | "transfer" ->
      maybe_int
        (transfer t (arg_int args 0) (arg_str args 1) (arg_str args 2)
           (arg_int args 3))
  | "top_spenders" ->
      JArr (List.map (fun s -> JStr s) (top_spenders t (arg_int args 0) (arg_int args 1)))
  | "pay" -> maybe_str (pay t (arg_int args 0) (arg_str args 1) (arg_int args 2))
  | "get_payment_status" ->
      maybe_str
        (get_payment_status t (arg_int args 0) (arg_str args 1) (arg_str args 2))
  | "merge_accounts" ->
      JBool (merge_accounts t (arg_int args 0) (arg_str args 1) (arg_str args 2))
  | "get_balance" ->
      maybe_int (get_balance t (arg_int args 0) (arg_str args 1) (arg_int args 2))
  | _ -> failwith ("missing method " ^ meth)
