(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val create_bundle :
  tmp_dir:OpamFilename.Dir.t ->
  bundle_dir:OpamFilename.Dir.t ->
  Config.config ->
  Installer_config.t ->
  OpamFilename.t ->
  unit
