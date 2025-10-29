(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let parse_dylib_line line =
  match String.trim line |> String.split_on_char ' ' with
  | dylib_path :: _ when dylib_path <> "" ->
    let name = Filename.basename dylib_path in
    Some (name, dylib_path)
  | _ -> None

let filter_system_libs path =
  not (String.starts_with ~prefix:"/usr/lib/" path)
  && not (String.starts_with ~prefix:"/System/" path)
  && not (String.starts_with ~prefix:"@" path)

let should_embed (name, path) =
  (* Those are hardcoded for now but we should ultimately make this
     configurable by the user. *)
  filter_system_libs path &&
  match String.split_on_char '.' name with
  | "libSystem"::_ -> false
  | _ -> true

let get_dylib_paths binary =
  let path = OpamFilename.to_string binary in
  let output = System.call Otool path in
  (* Validate output format: first line should be the binary path with colon *)
  let dylib_lines = match output with
    | first_line :: rest
      when OpamStd.String.contains ~sub:path first_line ->
      rest
    | [line] when OpamStd.String.contains ~sub:path line ->
      []
    | _ ->
      raise @@ System.System_error
        "otool raised an error. You probably chose a file with \
         invalid format as your binary."
  in
  let dylibs = List.filter_map parse_dylib_line dylib_lines in
  let to_embed = List.filter should_embed dylibs in
  List.map snd to_embed

let get_dylibs binary =
  let paths = get_dylib_paths binary in
  List.filter_map (fun dylib_path ->
      if Sys.file_exists dylib_path
      then Some (OpamFilename.of_string dylib_path)
      else None
    ) paths
