(* Tiny JSON encoder/decoder. No opam packages. *)

type value =
  | JNull
  | JBool of bool
  | JInt of int64
  | JStr of string
  | JArr of value list
  | JObj of (string * value) list

let arg_int args i =
  match List.nth args i with
  | JInt n -> n
  | JStr s -> Int64.of_string s
  | _ -> failwith "expected int arg"

let arg_str args i =
  match List.nth args i with
  | JStr s -> s
  | _ -> failwith "expected string arg"

let obj_val row key =
  match row with
  | JObj pairs ->
      let rec go = function
        | [] -> JNull
        | (k, v) :: rest -> if k = key then v else go rest
      in
      go pairs
  | _ -> JNull

let obj_str row key =
  match obj_val row key with
  | JStr s -> s
  | _ -> ""

let maybe_int = function
  | None -> JNull
  | Some n -> JInt n

let maybe_str = function
  | None -> JNull
  | Some s -> JStr s

let hex_digit c =
  match c with
  | '0' .. '9' -> Char.code c - Char.code '0'
  | 'a' .. 'f' -> 10 + Char.code c - Char.code 'a'
  | 'A' .. 'F' -> 10 + Char.code c - Char.code 'A'
  | _ -> failwith "bad hex"

let read_hex4 a b c d =
  ((hex_digit a * 16 + hex_digit b) * 16 + hex_digit c) * 16 + hex_digit d

let unescape = function
  | '"' -> '"'
  | '\\' -> '\\'
  | '/' -> '/'
  | 'b' -> '\b'
  | 'f' -> '\012'
  | 'n' -> '\n'
  | 'r' -> '\r'
  | 't' -> '\t'
  | c -> c

let rec skip s i =
  if i >= String.length s then i
  else
    match s.[i] with
    | ' ' | '\t' | '\n' | '\r' -> skip s (i + 1)
    | _ -> i

let rec parse_string s i acc =
  if i >= String.length s then failwith "unterminated string"
  else
    match s.[i] with
    | '"' -> (Buffer.contents acc, i + 1)
    | '\\' when i + 1 < String.length s ->
        if s.[i + 1] = 'u' && i + 5 < String.length s then (
          let code = read_hex4 s.[i + 2] s.[i + 3] s.[i + 4] s.[i + 5] in
          Buffer.add_utf_8_uchar acc (Uchar.of_int code);
          parse_string s (i + 6) acc)
        else (
          Buffer.add_char acc (unescape s.[i + 1]);
          parse_string s (i + 2) acc)
    | c ->
        Buffer.add_char acc c;
        parse_string s (i + 1) acc

let rec skip_digits s i =
  if i < String.length s && s.[i] >= '0' && s.[i] <= '9' then skip_digits s (i + 1)
  else i

let skip_exp s i =
  if i < String.length s && (s.[i] = 'e' || s.[i] = 'E') then
    let i = i + 1 in
    let i =
      if i < String.length s && (s.[i] = '+' || s.[i] = '-') then i + 1 else i
    in
    skip_digits s i
  else if i < String.length s && s.[i] = '.' then skip_digits s (i + 1)
  else i

let parse_unsigned s i =
  let n = String.length s in
  if i >= n || s.[i] < '0' || s.[i] > '9' then failwith "bad json number"
  else
    let rec go i acc =
      if i < n && s.[i] >= '0' && s.[i] <= '9' then
        let d = Int64.of_int (Char.code s.[i] - Char.code '0') in
        go (i + 1) (Int64.add (Int64.mul acc 10L) d)
      else (acc, skip_exp s i)
    in
    go i 0L

let parse_number s i =
  if i < String.length s && s.[i] = '-' then
    let n, rest = parse_unsigned s (i + 1) in
    (JInt (Int64.neg n), rest)
  else
    let n, rest = parse_unsigned s i in
    (JInt n, rest)

let rec parse_value s i =
  let i = skip s i in
  if i >= String.length s then failwith "bad json"
  else
    match s.[i] with
    | 'n'
      when i + 3 < String.length s
           && s.[i + 1] = 'u'
           && s.[i + 2] = 'l'
           && s.[i + 3] = 'l' ->
        (JNull, i + 4)
    | 't'
      when i + 3 < String.length s
           && s.[i + 1] = 'r'
           && s.[i + 2] = 'u'
           && s.[i + 3] = 'e' ->
        (JBool true, i + 4)
    | 'f'
      when i + 4 < String.length s
           && s.[i + 1] = 'a'
           && s.[i + 2] = 'l'
           && s.[i + 3] = 's'
           && s.[i + 4] = 'e' ->
        (JBool false, i + 5)
    | '[' -> parse_array s (skip s (i + 1)) []
    | '{' -> parse_object s (skip s (i + 1)) []
    | '"' ->
        let str, rest = parse_string s (i + 1) (Buffer.create 16) in
        (JStr str, rest)
    | c when c = '-' || (c >= '0' && c <= '9') -> parse_number s i
    | _ -> failwith "bad json"

and parse_array s i acc =
  let i = skip s i in
  if i < String.length s && s.[i] = ']' then (JArr (List.rev acc), i + 1)
  else
    let v, rest0 = parse_value s i in
    let rest = skip s rest0 in
    if rest < String.length s && s.[rest] = ',' then
      parse_array s (skip s (rest + 1)) (v :: acc)
    else if rest < String.length s && s.[rest] = ']' then
      (JArr (List.rev (v :: acc)), rest + 1)
    else failwith "bad json array"

and parse_object s i acc =
  let i = skip s i in
  if i < String.length s && s.[i] = '}' then (JObj (List.rev acc), i + 1)
  else if i < String.length s && s.[i] = '"' then
    let key, rest1 = parse_string s (i + 1) (Buffer.create 16) in
    let rest2 = skip s rest1 in
    if rest2 >= String.length s || s.[rest2] <> ':' then failwith "bad json object"
    else
      let v, rest4 = parse_value s (skip s (rest2 + 1)) in
      let rest5 = skip s rest4 in
      if rest5 < String.length s && s.[rest5] = ',' then
        parse_object s (skip s (rest5 + 1)) ((key, v) :: acc)
      else if rest5 < String.length s && s.[rest5] = '}' then
        (JObj (List.rev ((key, v) :: acc)), rest5 + 1)
      else failwith "bad json object"
  else failwith "bad json object"

let decode input =
  let v, rest = parse_value input 0 in
  if skip input rest <> String.length input then failwith "trailing json" else v

let rec encode = function
  | JNull -> "null"
  | JBool true -> "true"
  | JBool false -> "false"
  | JInt n -> Int64.to_string n
  | JStr s ->
      let buf = Buffer.create (String.length s + 2) in
      Buffer.add_char buf '"';
      String.iter
        (fun c ->
          match c with
          | '"' -> Buffer.add_string buf "\\\""
          | '\\' -> Buffer.add_string buf "\\\\"
          | '\b' -> Buffer.add_string buf "\\b"
          | '\012' -> Buffer.add_string buf "\\f"
          | '\n' -> Buffer.add_string buf "\\n"
          | '\r' -> Buffer.add_string buf "\\r"
          | '\t' -> Buffer.add_string buf "\\t"
          | _ when Char.code c < 32 ->
              Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
          | _ -> Buffer.add_char buf c)
        s;
      Buffer.add_char buf '"';
      Buffer.contents buf
  | JArr xs -> "[" ^ String.concat "," (List.map encode xs) ^ "]"
  | JObj pairs ->
      "{"
      ^ String.concat ","
          (List.map (fun (k, v) -> encode (JStr k) ^ ":" ^ encode v) pairs)
      ^ "}"
