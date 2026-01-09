(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val vars : Installer_config.vars

val create_bundle :
  ?keep_wxs: bool ->
  tmp_dir:OpamFilename.Dir.t ->
  bundle_dir:OpamFilename.Dir.t ->
  Installer_config.internal ->
  OpamFilename.t ->
  unit
