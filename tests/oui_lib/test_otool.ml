(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let pp_result fmt x =
  match x with
  | None -> Format.fprintf fmt "None"
  | Some (path) ->
    Format.fprintf fmt "Some %S" (OpamFilename.to_string path)

let%expect_test "parse_otool_line: homebrew lib" =
  (* TODO : implement otool parsing *)
  let _line = "\t/opt/homebrew/lib/libgmp.10.dylib (compatibility version 15.0.0, current version 15.0.0)" in
  let result = Some (OpamFilename.of_string "/opt/homebrew/lib/libgmp.10.dylib") in
  Format.printf "%a" pp_result result;
  [%expect {| Some "/opt/homebrew/lib/libgmp.10.dylib" |}]
