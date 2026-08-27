(* Reference cloud file storage. Traces follow the public LibreSignal storage specs. *)

open Minijson

type stored_file = { name : string; size : int64; mutable owner : string }

type t = {
  files : (string, stored_file) Hashtbl.t;
  capacity : (string, int64 option) Hashtbl.t;
  backups : (string, (string * int64) list) Hashtbl.t;
}

let new_target () =
  let capacity = Hashtbl.create 8 in
  Hashtbl.add capacity "admin" None;
  { files = Hashtbl.create 16; capacity; backups = Hashtbl.create 8 }

let rec take n xs =
  match (n, xs) with
  | n, _ when n <= 0 -> []
  | _, [] -> []
  | n, x :: rest -> x :: take (n - 1) rest

let used sim user_id =
  Hashtbl.fold
    (fun _ item acc ->
      if item.owner = user_id then Int64.add acc item.size else acc)
    sim.files 0L

let remaining sim user_id =
  match Hashtbl.find_opt sim.capacity user_id with
  | None | Some None -> None
  | Some (Some cap) -> Some (Int64.sub cap (used sim user_id))

let add_file sim name size =
  if Hashtbl.mem sim.files name then "false"
  else (
    Hashtbl.add sim.files name { name; size; owner = "admin" };
    "true")

let get_file_size sim name =
  match Hashtbl.find_opt sim.files name with
  | None -> ""
  | Some item -> Int64.to_string item.size

let delete_file sim name =
  match Hashtbl.find_opt sim.files name with
  | None -> ""
  | Some item ->
      Hashtbl.remove sim.files name;
      Int64.to_string item.size

let copy_file sim source dest =
  match Hashtbl.find_opt sim.files source with
  | None -> ""
  | Some src ->
      if source = dest then Int64.to_string src.size
      else
        let dest_item = Hashtbl.find_opt sim.files dest in
        let owner =
          match dest_item with None -> src.owner | Some item -> item.owner
        in
        let extra =
          match dest_item with
          | None -> src.size
          | Some item -> Int64.sub src.size item.size
        in
        match remaining sim owner with
        | Some left when extra > left -> ""
        | _ ->
            (match dest_item with
            | None ->
                Hashtbl.add sim.files dest { name = dest; size = src.size; owner }
            | Some item ->
                Hashtbl.replace sim.files dest { item with size = src.size });
            Int64.to_string src.size

let get_n_largest sim prefix n =
  let matched =
    Hashtbl.fold
      (fun _ item acc ->
        if String.starts_with ~prefix item.name then item :: acc else acc)
      sim.files []
  in
  let ordered =
    List.sort
      (fun a b ->
        let c = Int64.compare b.size a.size in
        if c <> 0 then c else String.compare a.name b.name)
      matched
  in
  let top = take (Int64.to_int n) ordered in
  String.concat ", "
    (List.map (fun item -> Printf.sprintf "%s(%Ld)" item.name item.size) top)

let add_user sim user_id capacity =
  if Hashtbl.mem sim.capacity user_id then "false"
  else (
    Hashtbl.add sim.capacity user_id (Some capacity);
    "true")

let add_file_by sim user_id name size =
  if (not (Hashtbl.mem sim.capacity user_id)) || Hashtbl.mem sim.files name then
    ""
  else
    match remaining sim user_id with
    | Some left when size > left -> ""
    | _ ->
        Hashtbl.add sim.files name { name; size; owner = user_id };
        (match remaining sim user_id with None -> "" | Some left -> Int64.to_string left)

let merge_user sim user_id1 user_id2 =
  if user_id1 = user_id2 then ""
  else
    match
      ( Hashtbl.find_opt sim.capacity user_id1,
        Hashtbl.find_opt sim.capacity user_id2 )
    with
    | Some (Some cap1), Some (Some cap2) ->
        Hashtbl.replace sim.capacity user_id1 (Some (Int64.add cap1 cap2));
        Hashtbl.iter
          (fun _ item -> if item.owner = user_id2 then item.owner <- user_id1)
          sim.files;
        Hashtbl.remove sim.capacity user_id2;
        Hashtbl.remove sim.backups user_id2;
        (match remaining sim user_id1 with
        | None -> ""
        | Some left -> Int64.to_string left)
    | _ -> ""

let backup_user sim user_id =
  if not (Hashtbl.mem sim.capacity user_id) then ""
  else
    let snapshot =
      Hashtbl.fold
        (fun _ item acc ->
          if item.owner = user_id then (item.name, item.size) :: acc else acc)
        sim.files []
    in
    let snapshot = List.sort (fun (a, _) (b, _) -> String.compare a b) snapshot in
    Hashtbl.replace sim.backups user_id snapshot;
    string_of_int (List.length snapshot)

let restore_user sim user_id =
  if not (Hashtbl.mem sim.capacity user_id) then ""
  else (
    Hashtbl.filter_map_inplace
      (fun _ item -> if item.owner = user_id then None else Some item)
      sim.files;
    match Hashtbl.find_opt sim.backups user_id with
    | None -> "0"
    | Some snapshot ->
        let restored =
          List.fold_left
            (fun acc (name, size) ->
              if Hashtbl.mem sim.files name then acc
              else
                match remaining sim user_id with
                | Some left when size > left -> acc
                | _ ->
                    Hashtbl.add sim.files name { name; size; owner = user_id };
                    acc + 1)
            0 snapshot
        in
        string_of_int restored)

let call t meth args =
  match meth with
  | "add_file" -> JStr (add_file t (arg_str args 0) (arg_int args 1))
  | "copy_file" -> JStr (copy_file t (arg_str args 0) (arg_str args 1))
  | "get_file_size" -> JStr (get_file_size t (arg_str args 0))
  | "delete_file" -> JStr (delete_file t (arg_str args 0))
  | "get_n_largest" -> JStr (get_n_largest t (arg_str args 0) (arg_int args 1))
  | "add_user" -> JStr (add_user t (arg_str args 0) (arg_int args 1))
  | "add_file_by" ->
      JStr (add_file_by t (arg_str args 0) (arg_str args 1) (arg_int args 2))
  | "merge_user" -> JStr (merge_user t (arg_str args 0) (arg_str args 1))
  | "backup_user" -> JStr (backup_user t (arg_str args 0))
  | "restore_user" -> JStr (restore_user t (arg_str args 0))
  | _ -> failwith ("missing method " ^ meth)
