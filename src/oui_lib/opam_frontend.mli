(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val with_install_bundle :
  ?conf_file: OpamFilename.t ->
  OpamCLIVersion.Sourced.t ->
  OpamArg.global_options ->
  OpamTypes.name ->
  (Installer_config.internal ->
   bundle_dir:OpamFilename.Dir.t ->
   tmp_dir:OpamFilename.Dir.t -> unit) ->
  unit
