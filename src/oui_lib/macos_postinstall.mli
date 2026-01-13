(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Generate postinstall script content for macOS .pkg installers.

    The postinstall script:
    - Creates wrapper scripts from /usr/local/bin to the .app bundle binaries
    - Installs manpages from the .app bundle to /usr/local/share/man
    - For plugin packages: creates symlinks into target app's bundle
*)
val generate_postinstall_script :
  env:(string * string) list ->
  app_name:string ->
  binary_name:string ->
  has_binary:bool ->
  ?plugins:Installer_config.plugin list ->
  unit ->
  string

(** Generate uninstall script content for macOS .pkg installers.

    The uninstall script:
    - Removes the wrapper from /usr/local/bin
    - Removes manpage symlinks
    - For plugin packages: removes symlinks from target app's bundle
    - Removes the .app bundle
*)
val generate_uninstall_script :
  app_name:string ->
  binary_name:string ->
  has_binary:bool ->
  plugins:Installer_config.plugin list ->
  string

(** Save postinstall script to the scripts directory with executable permissions. *)
val save_postinstall_script :
  content:string ->
  scripts_dir:OpamFilename.Dir.t ->
  OpamFilename.t

(** Save uninstall script to the resources directory with executable permissions. *)
val save_uninstall_script :
  content:string ->
  resources_dir:OpamFilename.Dir.t ->
  OpamFilename.t
