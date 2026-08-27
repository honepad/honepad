(* argv: ./run cases.json
   Compile with solution or stub as solution.ml. Compare JSON encodings. *)

open Minijson

let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let fail_row case_id idx method_name expected actual =
  JObj
    [
      ("case", JStr case_id);
      ("index", JInt (Int64.of_int idx));
      ("method", JStr method_name);
      ("expected", expected);
      ("actual", actual);
    ]

let rec replay_calls obj case_id calls idx =
  match calls with
  | [] -> None
  | call :: rest ->
      let method_name = obj_str call "m" in
      let expected = obj_val call "e" in
      let args = match obj_val call "a" with JArr xs -> xs | _ -> [] in
      match
        try
          let actual = Solution.call obj method_name args in
          Ok actual
        with exn -> Error ("exc:" ^ Printexc.to_string exn)
      with
      | Error msg -> Some (fail_row case_id idx method_name expected (JStr msg))
      | Ok actual ->
          if encode actual = encode expected then
            replay_calls obj case_id rest (idx + 1)
          else Some (fail_row case_id idx method_name expected actual)

let replay_case row =
  let obj = Solution.new_target () in
  let case_id = obj_str row "id" in
  let calls = match obj_val row "calls" with JArr xs -> xs | _ -> [] in
  replay_calls obj case_id calls 0

let rec replay_rows passed failed = function
  | [] -> (passed, List.rev failed)
  | row :: rest -> (
      match replay_case row with
      | None -> replay_rows (passed + 1) failed rest
      | Some row_fail -> replay_rows passed (row_fail :: failed) rest)

let run_cases path =
  let raw = read_file path in
  match decode raw with
  | JArr rows ->
      let passed, failed = replay_rows 0 [] rows in
      print_endline
        (encode
           (JObj [ ("passed", JInt (Int64.of_int passed)); ("failed", JArr failed) ]));
      if failed = [] then exit 0 else exit 1
  | _ ->
      prerr_endline "cases.json must be a JSON list";
      exit 2

let () =
  match Array.to_list Sys.argv with
  | [ _; cases_path ] -> run_cases cases_path
  | _ ->
      prerr_endline "usage: adapter cases.json";
      exit 2
