(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let handle ~config_path res =
  match res with
  | Ok () -> 0
  | Error `Invalid_config msg ->
    Printf.eprintf "%s\n" msg;
    1
  | Error `Inconsistent_config msgs ->
    Printf.eprintf "oui configuration %s contain inconsistencies:\n"
      config_path;
    ListLabels.iter msgs ~f:(Printf.eprintf "- %s\n");
    1
