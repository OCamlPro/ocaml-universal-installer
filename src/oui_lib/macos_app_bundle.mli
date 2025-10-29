(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Type representing a macOS .app bundle structure with all its directories *)
type t = {
  app_bundle_dir : OpamFilename.Dir.t;  (** MyApp.app *)
  contents : OpamFilename.Dir.t;        (** MyApp.app/Contents *)
  macos : OpamFilename.Dir.t;           (** MyApp.app/Contents/MacOS - executables go here *)
  frameworks : OpamFilename.Dir.t;      (** MyApp.app/Contents/Frameworks - dylibs go here *)
  resources : OpamFilename.Dir.t;       (** MyApp.app/Contents/Resources - everything else *)
  app_name : string;                    (** Capitalized app name  *)
  binary_name : string;                 (** Main binary name *)
  bundle_id : string;                   (** Bundle identifier *)
}

(** [create ~installer_config ~work_dir] creates the .app bundle directory
    structure and returns a bundle [t].

    Creates the following directory structure:
    - work_dir/AppName.app/Contents/MacOS/
    - work_dir/AppName.app/Contents/Frameworks/
    - work_dir/AppName.app/Contents/Resources/
*)
val create :
  installer_config:Installer_config.t ->
  work_dir:OpamFilename.Dir.t ->
  t

(** [add_subdir bundle ~relative_path] creates a subdirectory under Resources.
    Example: add_subdir bundle ~relative_path:"lib/myapp" creates
    Resources/lib/myapp/ *)
val add_subdir : t -> relative_path:string -> OpamFilename.Dir.t

(** {2 File Operations} *)

(** [copy_bundle_contents bundle ~bundle_dir] copies all contents from
    bundle_dir to the Resources directory. *)
val copy_bundle_contents : t -> bundle_dir:OpamFilename.Dir.t -> unit

(** [install_binary bundle ~binary_path] copies the binary to the MacOS
    directory and makes it executable (chmod 755).
    The binary is copied as bundle.binary_name. *)
val install_binary : t -> binary_path:OpamFilename.t -> OpamFilename.t

(** [copy_dylib bundle ~dylib] copies a dylib to the Frameworks directory *)
val copy_dylib : t -> dylib:OpamFilename.t -> OpamFilename.t

(** [copy_to_resources bundle ~src ~relative_path] copies a file to
    Resources/relative_path/basename(src).
    Creates the relative_path subdirectory if it doesn't exist  *)
val copy_to_resources : t -> src:OpamFilename.t -> relative_path:string ->
  OpamFilename.t
