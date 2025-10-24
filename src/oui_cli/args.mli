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

val config : Oui.Types.config Cmdliner.Term.t
(** Cmdliner term evaluating to the config compiled from relevant CLI args and
    options. Note that this consumes the first positional argument. *)

type backend = Wix | Makeself | Pkgbuild

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
  Oui.Installer_config.t ->
  string
(** Returns the approriate output name based on the value of the
    -o and --backend options. *)
