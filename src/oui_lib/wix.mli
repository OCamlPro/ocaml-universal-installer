(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Version in the form [0-9.]+, i.e dot separated numbers *)
module Version: sig
  type t = string
  val to_string : t -> string
  val of_string : string -> t
end

(** Information module used to generated main wxs document. *)
type info = {

  (* Indicates this is a plugin for the given application *)
  plugin_for: string option;

  (* Package unique ID (replaces GUID) *)
  unique_id: string;

  (* Product manufacturer *)
  manufacturer: string;

  (* Package name used as product name *)
  name: string;

  (* Package version *)
  version: string;

  (* Package subject/description (name & revision) *)
  subject: string option;

  (* Package comments *)
  comments: string option;

  (* Package keywords *)
  keywords: string list;

  (* Absolute path to the bundle containing all required files *)
  directory: string;

  (* Shorcuts to install *)
  shortcuts: shortcut list;

  (* Environment variables to set up *)
  environment: var list;

  (* Registry keys to create *)
  registry: key list;

  (* Icon filename (absolute) *)
  icon: string;

  (* Banner bmp filename (absolute) *)
  banner: string;

  (* Background bmp filename (absolute) *)
  background: string;

  (* License filename (absolute) *)
  license: string option;
}

and shortcut =
  | File of { name: string; description: string; target: string } (* target may contain vars *)
  | URL of { name: string; target: string } (* optionally icon *)

and var = {
  var_name: string; (* no space *)
  var_value: string; (* allow specifying info from the package, such as installation dir *)
  var_part: part;
}

and key = {
  key_name: string option;
  key_type: string;
  key_value: string;
}

and part = (* or Set, Prepend, Append *)
  | All
  | First
  | Last

(** [print_wix fmt info] outputs the main WiX source file *)
val print_wix : Format.formatter -> info -> unit
