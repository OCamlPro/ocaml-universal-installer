(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type t = string
[@@deriving yojson]

type subst_result =
  { subst_string : string
  ; unknown_vars : string list
  }
[@@deriving show]

let of_string x = x

let to_string x = x

module String_set = Set.Make(String)

let var_regexp = Re.compile (Re.Posix.re "<[A-Za-z_]+>")

let subst ~install_path t =
  let unknown_vars = ref String_set.empty in
  let subst_string =
    Re.replace ~all:true var_regexp
      ~f:(fun group ->
          match Re.Group.get group 0 with
          | "<install_path>" -> install_path
          | s ->
            unknown_vars := String_set.add s !unknown_vars;
            s)
      t
  in
  { subst_string; unknown_vars = String_set.elements !unknown_vars }
