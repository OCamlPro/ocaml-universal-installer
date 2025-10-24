(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type manpages =
  { man1 : string list
  ; man2 : string list
  ; man3 : string list
  ; man4 : string list
  ; man5 : string list
  ; man6 : string list
  ; man7 : string list
  ; man8 : string list
  }

(** Information module used to generated main wxs document. *)
type t = {
    name : string;
    (** Package name used as product name. Deduced from opam file *)
    fullname : string ;
    version : string;
    (** Package version used as part of product name. Deduced from opam file *)
    description : string;
    (** Package description. Deduced from opam file *)
    manufacturer : string;
    (** Product manufacturer. Deduced from field {i maintainer} in opam file *)
    exec_files : string list; (** Filenames of bundled .exe binary. *)
    makeself_manpages : manpages option; (** Paths to manpages, split by sections. *)
    wix_guid : string option;
    (** Package UID, used by WiX backend. Should be equal for every version of
        given package. If not specified, generated new UID *)
    wix_tags : string list; (** Package tags, used by WiX. *)
    wix_icon_file : string option;
    (** Icon filename, used by WiX. Defaults to our data/images/logo.ico file. *)
    wix_dlg_bmp_file : string option;
    (** Dialog bmp filename, used by WiX. Default to our data/images/dlgbmp.bmp *)
    wix_banner_bmp_file : string option;
    (* Banner bmp filename, used by WiX. Defaults to our
       data/images/bannrbmp.bmp *)
    wix_license_file : string option;
    wix_embedded_dirs : (OpamFilename.Base.t * OpamFilename.Dir.t) list;
    (** Embedded directories information (reference another wxs file) *)
    wix_additional_embedded_name : string list ;
    wix_additional_embedded_dir : OpamFilename.Dir.t list;
    wix_embedded_files : (OpamFilename.Base.t * OpamTypes.filename) list;
    (** Embedded files *)
    wix_environment : (string * string) list;
    (** Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
    macos_bundle_id : string option;
    (** macOS bundle identifier (reverse DNS format). *)
    macos_manpages : manpages option;
    (** Man pages to install on macOS. Same structure as makeself_manpages. *)
  }
[@@deriving yojson]

(** Converts the manpages record to an association list for ease of use. *)
val manpages_to_list : manpages -> (string * (string list)) list

(** Converts an association list to a manpage record, do not use on user
    provided data, only on trusted sources.
    @return [None] on empty lists, [Some manpages] otherwise.
    @raise [Invalid_argument msg] on invalid or duplicate keys. *)
val manpages_of_list : (string * (string list)) list -> manpages option

val load : OpamFilename.t -> t
val save : t -> OpamFilename.t -> unit

