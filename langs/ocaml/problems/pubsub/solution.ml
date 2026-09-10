(* Reference topic inbox. *)

open Minijson

type t = {
  subs : (string, string list) Hashtbl.t;
  inbox : (string, string list) Hashtbl.t;
  retained : (string, string) Hashtbl.t;
}

let new_target () =
  {
    subs = Hashtbl.create 16;
    inbox = Hashtbl.create 16;
    retained = Hashtbl.create 16;
  }

let subscribe sim topic client =
  let clients = try Hashtbl.find sim.subs topic with Not_found -> [] in
  if List.exists (( = ) client) clients then "false"
  else (
    Hashtbl.replace sim.subs topic (clients @ [ client ]);
    (match Hashtbl.find_opt sim.retained topic with
    | Some message ->
        let items = try Hashtbl.find sim.inbox client with Not_found -> [] in
        Hashtbl.replace sim.inbox client (items @ [ topic ^ ":" ^ message ])
    | None -> ());
    "true")

let unsubscribe sim topic client =
  match Hashtbl.find_opt sim.subs topic with
  | None -> "false"
  | Some clients ->
      if not (List.exists (( = ) client) clients) then "false"
      else
        let rest = List.filter (( <> ) client) clients in
        if rest = [] then Hashtbl.remove sim.subs topic
        else Hashtbl.replace sim.subs topic rest;
        "true"

let publish sim topic message =
  let clients = try Hashtbl.find sim.subs topic with Not_found -> [] in
  let payload = topic ^ ":" ^ message in
  List.iter
    (fun client ->
      let items = try Hashtbl.find sim.inbox client with Not_found -> [] in
      Hashtbl.replace sim.inbox client (items @ [ payload ]))
    clients;
  Int64.to_string (Int64.of_int (List.length clients))

let inbox sim client =
  match Hashtbl.find_opt sim.inbox client with
  | None -> ""
  | Some items -> String.concat ", " items

let list_topics sim =
  let topics = Hashtbl.fold (fun topic _ acc -> topic :: acc) sim.subs [] in
  String.concat ", " (List.sort compare topics)

let subscribers sim topic =
  match Hashtbl.find_opt sim.subs topic with
  | None -> ""
  | Some clients -> String.concat ", " (List.sort compare clients)

let peek sim client =
  match Hashtbl.find_opt sim.inbox client with
  | Some (head :: _) -> head
  | _ -> ""

let ack sim client n =
  match Hashtbl.find_opt sim.inbox client with
  | None -> "invalid_request"
  | _ when n <= 0L -> "invalid_request"
  | Some items ->
      let count = List.length items in
      if n > Int64.of_int count then "invalid_request"
      else
        let rec drop k xs =
          if k = 0L then xs else match xs with [] -> [] | _ :: rest -> drop (Int64.sub k 1L) rest
        in
        let rest = drop n items in
        Hashtbl.replace sim.inbox client rest;
        Int64.to_string (Int64.of_int (List.length rest))

let retain sim topic message =
  Hashtbl.replace sim.retained topic message;
  ""

let call t meth args =
  match meth with
  | "subscribe" -> JStr (subscribe t (arg_str args 0) (arg_str args 1))
  | "unsubscribe" -> JStr (unsubscribe t (arg_str args 0) (arg_str args 1))
  | "publish" -> JStr (publish t (arg_str args 0) (arg_str args 1))
  | "inbox" -> JStr (inbox t (arg_str args 0))
  | "list_topics" -> JStr (list_topics t)
  | "subscribers" -> JStr (subscribers t (arg_str args 0))
  | "peek" -> JStr (peek t (arg_str args 0))
  | "ack" -> JStr (ack t (arg_str args 0) (arg_int args 1))
  | "retain" -> JStr (retain t (arg_str args 0) (arg_str args 1))
  | _ -> failwith ("missing method " ^ meth)
