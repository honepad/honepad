(* Reference text buffer. *)

open Minijson

type snap = { buf : string; pos : int }

type t = {
  mutable buf : string;
  mutable pos : int;
  undo : snap Stack.t;
  redo : snap Stack.t;
  mutable sel : (int * int) option;
  mutable clip : string;
}

let new_target () =
  {
    buf = "";
    pos = 0;
    undo = Stack.create ();
    redo = Stack.create ();
    sel = None;
    clip = "";
  }

let push sim =
  Stack.push { buf = sim.buf; pos = sim.pos } sim.undo;
  Stack.clear sim.redo;
  sim.sel <- None

let insert sim at text =
  let at = Int64.to_int at in
  if at < 0 || at > String.length sim.buf then "invalid_request"
  else (
    push sim;
    sim.buf <- String.sub sim.buf 0 at ^ text ^ String.sub sim.buf at (String.length sim.buf - at);
    string_of_int (String.length sim.buf))

let erase sim at n =
  let at = Int64.to_int at in
  let n = Int64.to_int n in
  if n <= 0 || at < 0 || at + n > String.length sim.buf then "invalid_request"
  else (
    push sim;
    let deleted = String.sub sim.buf at n in
    sim.buf <- String.sub sim.buf 0 at ^ String.sub sim.buf (at + n) (String.length sim.buf - at - n);
    if sim.pos > String.length sim.buf then sim.pos <- String.length sim.buf;
    deleted)

let get_text sim = sim.buf

let length sim = string_of_int (String.length sim.buf)

let move sim at =
  let at = Int64.to_int at in
  if at < 0 || at > String.length sim.buf then "invalid_request"
  else (
    sim.pos <- at;
    "true")

let type_text sim text =
  push sim;
  let at = sim.pos in
  sim.buf <- String.sub sim.buf 0 at ^ text ^ String.sub sim.buf at (String.length sim.buf - at);
  sim.pos <- at + String.length text;
  string_of_int (String.length sim.buf)

let cursor sim = string_of_int sim.pos

let undo sim =
  if Stack.is_empty sim.undo then "false"
  else (
    Stack.push { buf = sim.buf; pos = sim.pos } sim.redo;
    let snap = Stack.pop sim.undo in
    sim.buf <- snap.buf;
    sim.pos <- snap.pos;
    sim.sel <- None;
    "true")

let redo sim =
  if Stack.is_empty sim.redo then "false"
  else (
    Stack.push { buf = sim.buf; pos = sim.pos } sim.undo;
    let snap = Stack.pop sim.redo in
    sim.buf <- snap.buf;
    sim.pos <- snap.pos;
    sim.sel <- None;
    "true")

let select sim start end_pos =
  let start = Int64.to_int start in
  let end_pos = Int64.to_int end_pos in
  if start < 0 || end_pos < 0 || start > end_pos || end_pos > String.length sim.buf then
    "invalid_request"
  else (
    sim.sel <- Some (start, end_pos);
    "true")

let cut sim =
  match sim.sel with
  | None -> "invalid_request"
  | Some (start, end_pos) when start = end_pos -> "invalid_request"
  | Some (start, end_pos) ->
      let text = String.sub sim.buf start (end_pos - start) in
      sim.buf <-
        String.sub sim.buf 0 start ^ String.sub sim.buf end_pos (String.length sim.buf - end_pos);
      sim.clip <- text;
      sim.pos <- start;
      sim.sel <- None;
      text

let copy_sel sim =
  match sim.sel with
  | None -> "invalid_request"
  | Some (start, end_pos) when start = end_pos -> "invalid_request"
  | Some (start, end_pos) ->
      sim.clip <- String.sub sim.buf start (end_pos - start);
      sim.clip

let paste sim =
  if sim.clip = "" then "invalid_request"
  else
    let at = sim.pos in
    sim.buf <-
      String.sub sim.buf 0 at ^ sim.clip ^ String.sub sim.buf at (String.length sim.buf - at);
    sim.pos <- at + String.length sim.clip;
    string_of_int (String.length sim.buf)

let call t meth args =
  match meth with
  | "insert" -> JStr (insert t (arg_int args 0) (arg_str args 1))
  | "erase" -> JStr (erase t (arg_int args 0) (arg_int args 1))
  | "get_text" -> JStr (get_text t)
  | "length" -> JStr (length t)
  | "move" -> JStr (move t (arg_int args 0))
  | "type_text" -> JStr (type_text t (arg_str args 0))
  | "cursor" -> JStr (cursor t)
  | "undo" -> JStr (undo t)
  | "redo" -> JStr (redo t)
  | "select" -> JStr (select t (arg_int args 0) (arg_int args 1))
  | "cut" -> JStr (cut t)
  | "copy_sel" -> JStr (copy_sel t)
  | "paste" -> JStr (paste t)
  | _ -> failwith ("missing method " ^ meth)
