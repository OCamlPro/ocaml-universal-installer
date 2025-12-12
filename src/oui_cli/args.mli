(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val opam_filename : OpamFilename.t Cmdliner.Arg.conv
val opam_dirname : OpamFilename.Dir.t Cmdliner.Arg.conv

val wix_keep_wxs : bool Cmdliner.Term.t
(** --keep-wxs flag to disable WiX files clean up. *)

type backend = Wix | Makeself | Pkgbuild

val pp_backend : Format.formatter -> backend -> unit

val vars_of_backend : backend -> Oui.Installer_config.vars

(** Select backend based on current system. If [log], inform the user
    of which backend was selected, defaults to true. *)
val autodetect_backend : ?log: bool -> unit -> backend

val backend : backend Cmdliner.Term.t
(** --backend option to overwrite the default backend detection mechanism,
    based on the local system. *)

val backend_opt : backend option Cmdliner.Term.t
(** --backend option to overwrite the default backend detection mechanism,
    based on the local system. Allow selecting no backend. *)

val output : string option Cmdliner.Term.t
(** -o/--output option to overwrite the default output file/dir. *)

val output_name :
  output: string option ->
  backend: backend option ->
  _ Oui.Installer_config.t ->
  string
(** Returns the approriate output name based on the value of the
    -o and --backend options. *)

(** JSON oui config file positional argument, sits as first positional arg. *)
val installer_config : OpamFilename.t Cmdliner.Term.t

(** Installation bundle positional argument, sits as second positional arg. *)
val bundle_dir : OpamFilename.Dir.t Cmdliner.Term.t
