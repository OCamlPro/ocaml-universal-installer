(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** [get_dylib_paths binary] returns the exact dylib paths as they appear in
    the binary (unresolved symlinks), filtered for embeddable libraries.*)
val get_dylib_paths : OpamFilename.t -> string list

(** [get_dylibs binary] returns the path to dylib files that [binary] depends
    on, as resolved by [otool -L] on the host system.
    Filters out system libraries from /usr/lib and /System, as well as
    already relocated paths (starting with @).
    Also filters out libSystem and other core system libraries.
    Note: This checks file existence and may resolve symlinks. *)
val get_dylibs : OpamFilename.t -> OpamFilename.t list

(**/**)
(* Undocumented Section. Exposed for test purposes only *)

(* Parse an otool -L output line, returning a pair of the dylib name
   and path string.
   Returns [None] on malformed lines. *)
val parse_dylib_line : string -> (string * string) option

(* Whether the given dylib should be embedded by the installer. *)
val should_embed : (string * string) -> bool
