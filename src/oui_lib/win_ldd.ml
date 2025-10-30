(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module StrSet = Set.Make (String)

external get_dlls : string -> string list = "ml_get_dlls"

external resolve_dll : string -> string option = "ml_resolve_dll"

external get_windows_directory : unit -> string = "ml_get_windows_directory"

let is_system32 =
  (* Note: guaranteed to end with '\' *)
  let win_dir = get_windows_directory () in
  fun path ->
    let prefix =
      try String.sub path 0 (String.length win_dir)
      with _ -> ""
    in
    if prefix <> win_dir then false
    else
      let suffix =
        try String.sub path (String.length win_dir)
              (String.length path - String.length win_dir)
        with _ -> ""
      in
      match String.split_on_char '\\' suffix with
      | directory :: _ ->
          String.lowercase_ascii directory = "system32"
          || String.lowercase_ascii directory = "syswow64"
      | _ -> false

let get_dlls binary =
  let rec aux dlls binary =
    let binary_dlls = get_dlls binary in
    let new_dlls =
      List.filter_map (fun dll ->
          match resolve_dll dll with
          | None -> None (* Maybe should warn ? *)
          | Some (dll) ->
              if is_system32 dll && false then None
              else if StrSet.mem dll dlls then None
              else Some (dll)
        ) binary_dlls
    in
    let dlls =
      List.fold_left (fun dlls dll ->
          StrSet.add dll dlls
        ) dlls new_dlls
    in
    List.fold_left aux dlls new_dlls
  in
  let dlls = aux StrSet.empty (OpamFilename.to_string binary) in
  StrSet.fold (fun dll dlls ->
      OpamFilename.of_string (System.normalize_path dll) :: dlls
    ) dlls [] |> List.rev
