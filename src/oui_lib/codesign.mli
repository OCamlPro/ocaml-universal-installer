(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Code signing utilities for macOS binaries. *)

type signing_identity =
  | AdHoc  (** Ad-hoc signature (no developer certificate) *)
  | DeveloperID of string  (** Developer ID Application certificate *)

type sign_options = {
  force : bool;
  timestamp : bool; (** required for Developer ID distribution *)
  entitlements : string option; (** path to entitlements plist file *)
}

val default_sign_options : sign_options

(** [sign_binary ~identity binary] signs a binary with the specified
    identity and options. *)
val sign_binary : ?options:sign_options -> identity:signing_identity ->
  OpamFilename.t -> unit

(** [sign_binary_adhoc binary] signs a binary with ad-hoc signature. *)
val sign_binary_adhoc : ?force:bool -> OpamFilename.t -> unit

(** [sign_binary_with_dev_id ~cert_name binary] signs a binary with
    Developer ID certificate *)
val sign_binary_with_dev_id : ?force:bool -> ?timestamp:bool ->
  cert_name:string -> OpamFilename.t -> unit

(** [verify_signature binary] returns true if the binary has
    a valid signature. *)
val verify_signature : OpamFilename.t -> bool
