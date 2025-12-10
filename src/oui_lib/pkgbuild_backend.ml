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

let vars : Installer_config.vars = { install_path =  (*TODO*) Obj.magic () }

let create_work_dir () =
  let tmp_dir = Filename.get_temp_dir_name () in
  let work_dir_name = Printf.sprintf "oui-macos-%d" (Random.int 1000000) in
  let work_dir_path = Filename.concat tmp_dir work_dir_name in
  let work_dir = OpamFilename.Dir.of_string work_dir_path in
  OpamFilename.mkdir work_dir;
  work_dir

let copy_manpages bundle ~bundle_dir ~manpages =
  match manpages with
  | None -> ()
  | Some man_sections ->
    List.iter (fun (section, files) ->
        let relative_path = Filename.concat "man" section in
        let section_dir = Macos_app_bundle.add_subdir bundle ~relative_path in
        List.iter (fun file_path ->
            let src = bundle_dir // file_path in
            if OpamFilename.exists src then
              let basename = OpamFilename.basename src in
              let dst = section_dir // OpamFilename.Base.to_string basename in
              OpamFilename.copy ~src ~dst
            else
              OpamConsole.warning "Manpage not found: %s" file_path
          ) files
      ) man_sections

let create_info_plist bundle ~installer_config =
  let plist = Info_plist.make_info_plist
      ~bundle_id:bundle.Macos_app_bundle.bundle_id
      ~executable:bundle.binary_name
      ~name:bundle.app_name
      ~display_name:installer_config.Installer_config.fullname
      ~version:installer_config.version
  in
  let plist_path = bundle.contents // "Info.plist" in
  Info_plist.save plist plist_path;
  OpamConsole.msg "Created Info.plist: %s\n"
    (OpamFilename.to_string plist_path)

let handle_dylibs bundle ~binary_dst =
  OpamConsole.msg "Processing dylib dependencies...\n";
  let dylibs = Otool.get_dylibs binary_dst in
  if List.length dylibs = 0 then
    OpamConsole.msg "  No external dylibs found\n"
  else
    List.iter
      (fun dylib ->
         ignore (Macos_app_bundle.copy_dylib bundle ~dylib))
      dylibs;
    Install_name_tool.relocate_to_executable_path binary_dst

(** Create the .pkg installer from the bundle *)
let create_installer
    ~(installer_config : Installer_config.internal) ~bundle_dir installer =
  Random.self_init ();

  let work_dir = create_work_dir () in
  OpamConsole.msg "Working directory: %s\n"
    (OpamFilename.Dir.to_string work_dir);

  (* Create .app bundle structure *)
  let bundle = Macos_app_bundle.create ~installer_config ~work_dir in

  (* Copy all bundle contents to Resources *)
  Macos_app_bundle.copy_bundle_contents bundle ~bundle_dir;

  (* Install main binary to MacOS directory *)
  let binary_src = match installer_config.exec_files with
    | [] -> OpamConsole.error_and_exit `Bad_arguments
              "No exec_files specified in config"
    | binary :: _ -> bundle_dir // binary
  in
  let binary_dst = Macos_app_bundle.install_binary bundle ~binary_path:binary_src in

  handle_dylibs bundle ~binary_dst;

  (* Sign the binary with ad-hoc signature *)
  OpamConsole.msg "Signing binary...\n";
  Codesign.sign_binary_adhoc binary_dst;

  create_info_plist bundle ~installer_config;

  copy_manpages bundle ~bundle_dir ~manpages:installer_config.manpages;

  (* Create symlinks for dune-site relocatable support *)
  List.iter (fun dir_name ->
      let src_dir = bundle.resources / dir_name in
      let link_path =
        OpamFilename.Dir.to_string bundle.contents ^ "/" ^ dir_name
      in
      if OpamFilename.exists_dir src_dir then
        (OpamConsole.msg "Creating symlink: Contents/%s -> Resources/%s\n"
           dir_name dir_name;
         Unix.symlink ("Resources/" ^ dir_name) link_path)
      else
        OpamConsole.warning
          "Directory %s not found in Resources, skipping symlink"
          dir_name
    ) installer_config.macos_symlink_dirs;

  (* Create postinstall script *)
  let scripts_dir = work_dir / "scripts" in
  let postinstall_content = Macos_postinstall.generate_postinstall_script
      ~app_name:bundle.app_name
      ~binary_name:bundle.binary_name
  in
  let _postinstall_path = Macos_postinstall.save_postinstall_script
      ~content:postinstall_content
      ~scripts_dir
  in

  let component_pkg_path =
    let base = OpamFilename.chop_extension installer in
    OpamFilename.add_extension base "-component.pkg" in

  let install_location =
    Printf.sprintf "/Applications/%s.app" bundle.app_name in

  OpamConsole.msg "Creating component package...\n";
  let pkgbuild_args : System.pkgbuild_args = {
    root = bundle.app_bundle_dir;
    identifier = bundle.bundle_id;
    version = installer_config.version;
    install_location;
    scripts = Some scripts_dir;
    output = component_pkg_path;
  } in
  System.call_unit System.Pkgbuild pkgbuild_args;

  OpamConsole.msg "Creating final installer package...\n";
  let productbuild_args : System.productbuild_args = {
    package = component_pkg_path;
    output = installer;
  } in
  System.call_unit System.Productbuild productbuild_args;

  OpamFilename.remove component_pkg_path;

  OpamFilename.rmdir work_dir;

  OpamConsole.formatted_msg "Created: %s\n"
    (OpamConsole.colorise `green (OpamFilename.to_string installer))
