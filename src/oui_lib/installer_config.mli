(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type man_section =
  | Man_dir of string
  | Man_files of string list

type manpages =
  { man1 : man_section
  ; man2 : man_section
  ; man3 : man_section
  ; man4 : man_section
  ; man5 : man_section
  ; man6 : man_section
  ; man7 : man_section
  ; man8 : man_section
  }

type plugin =
  { name : string
  ; app_name : string
  ; plugin_dir : string
  ; lib_dir : string
  ; dyn_deps : string list [@default []]
  }

type plugin_dirs =
  { plugins_dir : string
  ; lib_dir : string
  }

type vars = { install_path : string }

(** Manpages as association list from man section name to list of manpages *)
type expanded_manpages = (string * string list) list

(** User provided installer configuration.
    Describes the package, the content of the bundle and the paths to some
    external files such as wix icons.
    First parameter describes the type of manpages to allow both a JSON friendly
    format and one easy to work with internally.
    Second parameter allows the user representation to contain non expanded
    variables and the internal one to contain expanded strings. *)
type ('manpages, 'string_with_vars) t = {
    name : string;
    (** Package name used as product name. Deduced from opam file *)
    fullname : string ;
    version : string;
    (** Package version used as part of product name. Deduced from opam file *)
    exec_files : string list; (** Filenames of bundled .exe binary. *)
    manpages : 'manpages option; (** Paths to manpages, split by sections. *)
    environment : (string * 'string_with_vars) list;
    (** Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
    unique_id : string;
    (** Unique ID in reverse DNS format. Used by macOS and Wix backends.
        Deduced from fields {i maintainer} and {i name} in opam. *)
    plugins: plugin list;
    (** List of plugins for external applications within the bundle. *)
    plugin_dirs: plugin_dirs option;
    (** Paths to directories in the bundle where external plugin should be
        installed. *)
    wix_manufacturer : string;
    (** Product manufacturer. Deduced from field {i maintainer} in opam file *)
    wix_description : string option;
    (** Package description. Deduced from opam file *)
    wix_tags : string list; (** Package tags, used by WiX. *)
    wix_icon_file : string option;
    (** Icon filename, used by WiX. Defaults to our data/images/logo.ico file. *)
    wix_dlg_bmp_file : string option;
    (** Dialog bmp filename, used by WiX. Default to our data/images/dlgbmp.bmp *)
    wix_banner_bmp_file : string option;
    (** Banner bmp filename, used by WiX. Defaults to our data/images/bannrbmp.bmp *)
    wix_license_file : string option;
    macos_symlink_dirs : string list;
    (** Directories to symlink from Contents/ to Resources/ for dune-site relocatable support.
        Example: ["lib"; "share"] creates Contents/lib -> Resources/lib and Contents/share -> Resources/share *)
  }

type user = (manpages, String_with_vars.t) t

type internal = (expanded_manpages, string) t

(** Checks that directories and files specified in the given config exist
    with the right permissions.
    Returns a pair made of the expanded config or the list of errors and a list
    of warnings.
    In the expanded config, variables are substituted and manpages expanded into
    a list of man section names paired with the list of files for each of them
    by expanding [Man_dir "dir"] into the list of files within ["dir"]. *)
val check_and_expand :
  bundle_dir: OpamFilename.Dir.t ->
  vars: vars ->
  user ->
  (internal, [> `Inconsistent_config of string list]) result * string list

(** Converts an association list to a manpage record, do not use on user
    provided data, only on trusted sources.
    @raise [Invalid_argument msg] on invalid or duplicate keys. *)
val manpages_of_expanded : expanded_manpages -> manpages

val load : OpamFilename.t -> (user, [> `Invalid_config of string]) result
val save : user -> OpamFilename.t -> unit

