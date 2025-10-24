(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type value =
  | String of string
  | Bool of bool
  | Dict of (string * value) list
  | Array of value list
  (* TODO: Add missing plist types to match Apple's spec:
     - Int of int        for <integer>
     - Float of float    for <real>
     - Date of string    for <date> (ISO 8601)
     - Data of string    for <data> (Base64) *)

type t = (string * value) list

(** Create a generic plist from key-value pairs. *)
val make : (string * value) list -> t

(** Add or update an entry in the plist. *)
val add_entry : string -> value -> t -> t

(** Create a standard Info.plist for a macOS app bundle.
    Use [add_entry] to add custom keys like CFBundleIconFile. *)
val make_info_plist :
  bundle_id:string ->
  executable:string ->
  name:string ->
  display_name:string ->
  version:string ->
  t

(** Serialize plist to XML format. *)
val to_xml : t -> string

(** Write plist to file. *)
val save : t -> OpamFilename.t -> unit
