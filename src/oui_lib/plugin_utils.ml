(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Returns a valid prefix for app specific variables. E.g. for ["frama-c"],
    returns ["frama_c_"]. This should be passed to load_conf. *)
let app_var_prefix app_name =
  (String.map
     (fun c ->
        match c with
        | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' -> c
        | _ -> '_')
     app_name) ^ "_"
