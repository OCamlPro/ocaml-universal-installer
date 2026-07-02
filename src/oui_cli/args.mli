(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)


type 'a arg_kind =
  | Flag : bool arg_kind
  | String_opt : string option -> string option arg_kind

type 'a abstract =
  { names : string list
  ; docv : string
  ; doc : string
  ; kind : 'a arg_kind
  }
(** Type describing individual elements of a CLI argument. Used to share
    args between the main binary and the opam plugin which uses OpamCmdliner
    and not Cmdliner itself. *)

val opam_filename : OpamFilename.t Cmdliner.Arg.conv
val opam_dirname : OpamFilename.Dir.t Cmdliner.Arg.conv

val wix_keep_wxs : bool Cmdliner.Term.t
(** --keep-wxs flag to disable WiX files clean up. *)

val wix_keep_wxs_abstract : bool abstract

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

val output_abstract : string option abstract

val output_name :
  output: string option ->
  backend: backend option ->
  _ Oui.Installer_config.t ->
  string
(** Returns the approriate output name based on the value of the
    -o and --backend options. *)

(** Overrides some config fields with higher priority CLI options *)
val override_config :
  macos_application_signing_id: string option ->
  Oui.Installer_config.internal -> 
  Oui.Installer_config.internal

(** JSON oui config file positional argument, sits as first positional arg. *)
val installer_config : OpamFilename.t Cmdliner.Term.t

(** Installation bundle positional argument, sits as second positional arg. *)
val bundle_dir : OpamFilename.Dir.t Cmdliner.Term.t

(** Verbose level for opam lib *)
val verbose : int Cmdliner.Term.t

(** Debug level for opam lib *)
val debug : int Cmdliner.Term.t

(** Files timestamps to use for installed files *)
val mtime : string option Cmdliner.Term.t

(** Extra tar option for makeself archives *)
val tar_extra : string list option Cmdliner.Term.t

(** --macos-application-signing-id option to pass Developer ID Application
    certificate name to codesign for binary signature. Overrides the JSON
    config field. *)
val macos_application_signing_id : string option Cmdliner.Term.t

val macos_application_signing_id_abstract : string option abstract
