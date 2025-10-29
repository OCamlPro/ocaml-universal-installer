(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Helpers for modifying dynamic library paths in macOS binaries using install_name_tool. *)

(** [relocate_to_rpath binary] converts dylib paths to @rpath. WARNING: only uses basename! *)
val relocate_to_rpath : OpamFilename.t -> unit

(** [relocate_to_executable_path binary] converts embeddable dylib paths to
    @executable_path/../Frameworks/dylibname (standard .app bundle structure).
    Only the basename of each dylib is preserved. *)
val relocate_to_executable_path : OpamFilename.t -> unit

(** [relocate_to_executable_path_custom binary ~subdir] converts embeddable dylib paths to
    @executable_path/subdir/dylibname. Only the basename of each dylib is preserved.

    @raise Invalid_argument if [subdir] is empty, starts with '/', or ends with '/'. *)
val relocate_to_executable_path_custom : OpamFilename.t -> subdir:string -> unit
