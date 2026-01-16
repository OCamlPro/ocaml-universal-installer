(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val vars : Installer_config.vars

(** [create_installer ~installer_config ~bundle_dir installer] creates
    a standalone .pkg installer [installer] based on the given
    bundle and installer configuration. *)
val create_installer :
  installer_config: Installer_config.internal ->
  bundle_dir: OpamFilename.Dir.t ->
  OpamFilename.t ->
  unit
