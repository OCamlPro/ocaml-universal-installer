(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type t
[@@deriving yojson]

(** Builds a string with variables from the raw string *)
val of_string : string -> t

(** Returns the raw string with variables unexpanded *)
val to_string : t -> string

type subst_result =
  { subst_string : string
  ; unknown_vars : string list
  }
[@@deriving show]

(** Return the input strings with known variables substituted by the provided
    values and the list of unknown variables that were found in the input.
    E.g. [subst ~install_path:"XX" "<install_path>/lib/<unknown>"] will return
    [{subst_string = "XX/lib/<unknown>"; unknown_vars = ["<unknown>"]}]. *)
val subst : install_path: string -> t -> subst_result
