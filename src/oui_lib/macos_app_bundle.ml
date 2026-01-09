(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)


open OpamFilename.Op


type t = {
  app_bundle_dir : OpamFilename.Dir.t;
  contents : OpamFilename.Dir.t;
  macos : OpamFilename.Dir.t;
  frameworks : OpamFilename.Dir.t;
  resources : OpamFilename.Dir.t;
  app_name : string;
  binary_name : string;
  bundle_id : string;
}

let create ~installer_config ~work_dir =
  let app_name = installer_config.Installer_config.name in
  let app_name_cap = String.capitalize_ascii app_name in
  let bundle_id = installer_config.unique_id in
  let binary_name = match installer_config.exec_files with
    | [] -> app_name  (* Plugin-only bundle uses app name as placeholder *)
    | binary :: _ -> Filename.basename binary
  in
  let app_bundle_dir = work_dir / (app_name_cap ^ ".app") in
  let contents = app_bundle_dir / "Contents" in
  let macos = contents / "MacOS" in
  let frameworks = contents / "Frameworks" in
  let resources = contents / "Resources" in

  OpamFilename.mkdir macos;
  OpamFilename.mkdir frameworks;
  OpamFilename.mkdir resources;

  OpamConsole.msg "Created .app bundle structure: %s\n"
    (OpamFilename.Dir.to_string app_bundle_dir);

  {
    app_bundle_dir;
    contents;
    macos;
    frameworks;
    resources;
    app_name = app_name_cap;
    binary_name;
    bundle_id;
  }

let add_subdir bundle ~relative_path =
  let subdir = bundle.resources / relative_path in
  OpamFilename.mkdir subdir;
  subdir

(* File Operations *)

let copy_bundle_contents bundle ~bundle_dir =
  OpamConsole.msg "Copying bundle contents to Resources...\n";
  OpamFilename.copy_dir ~src:bundle_dir ~dst:bundle.resources

let install_binary bundle ~binary_path =
  OpamConsole.msg "Installing binary: %s\n" bundle.binary_name;
  let binary_dst = bundle.macos // bundle.binary_name in
  OpamFilename.copy ~src:binary_path ~dst:binary_dst;
  System.call_unit System.Chmod (755, binary_dst);
  binary_dst

let copy_dylib bundle ~dylib =
  let dylib_name = Filename.basename (OpamFilename.to_string dylib) in
  let dylib_dst = bundle.frameworks // dylib_name in
  OpamConsole.msg "  Copying dylib: %s\n" dylib_name;
  OpamFilename.copy ~src:dylib ~dst:dylib_dst;
  dylib_dst

let copy_to_resources bundle ~src ~relative_path =
  let basename = Filename.basename (OpamFilename.to_string src) in
  let subdir = add_subdir bundle ~relative_path in
  let dst = subdir // basename in
  OpamFilename.copy ~src ~dst;
  dst
