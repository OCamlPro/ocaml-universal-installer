(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let to_rpath dylib_path =
  Printf.sprintf "@rpath/%s" (Filename.basename dylib_path)

let to_executable_path_frameworks dylib_path =
  (* Standard .app bundle: MyApp.app/Contents/MacOS/binary
     and MyApp.app/Contents/Frameworks/lib.dylib
     So from binary: @executable_path/../Frameworks/lib.dylib *)
  Printf.sprintf "@executable_path/../Frameworks/%s" (Filename.basename dylib_path)

let validate_subdir subdir =
  if subdir = "" then
    invalid_arg "subdir cannot be empty";
  if OpamStd.String.starts_with ~prefix:"/" subdir then
    invalid_arg "subdir cannot start with '/'";
  if OpamStd.String.ends_with ~suffix:"/" subdir then
    invalid_arg "subdir cannot end with '/'"

let to_executable_path dylib_path ~subdir =
  validate_subdir subdir;
  Printf.sprintf "@executable_path/%s/%s" subdir (Filename.basename dylib_path)

let change_dylib_path ~binary ~old_path ~new_path =
  try
    let args : System.install_name_tool_args = {
      change_from = old_path;
      change_to = new_path;
      binary;
    } in
    System.call_unit System.InstallNameTool args
  with System.System_error e ->
    OpamConsole.warning "install_name_tool failed: %s" e

let relocate_dylibs binary ~transform_path =
  let dylib_paths = Otool.get_dylib_paths binary in
  List.iter (fun old_path ->
      let new_path = transform_path old_path in
      change_dylib_path ~binary ~old_path ~new_path
    ) dylib_paths

let relocate_to_rpath binary =
  relocate_dylibs binary ~transform_path:to_rpath

let relocate_to_executable_path binary =
  relocate_dylibs binary ~transform_path:to_executable_path_frameworks

let relocate_to_executable_path_custom binary ~subdir =
  relocate_dylibs binary ~transform_path:(fun path -> to_executable_path path ~subdir)
