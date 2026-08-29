(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type program_headers

(* [program_headers binary] returns the result of [readelf -l --wide binary]. *)
val program_headers : OpamFilename.t -> program_headers

(* Interpret program headers to determine whether the binary is fully static
   or requires dynamic linking.
   Assumes a dynamic binary will have an [INTERP] header. *)
val is_static : program_headers -> bool

(**/**)
(* Undocumented Section. Exposed for test purposes only *)

val program_headers_from_lines : string list -> program_headers
