(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamFilename.Op

let vars : Installer_config.vars = { install_path = "[APPLICATIONFOLDER]" }

let check_wix_installed () =
  let wix_bin_exists () =
    match Sys.command "wix.exe --version" with
    | 0 -> true
    | _ -> false
  in
  if wix_bin_exists ()
  then System.call_list [ Which, "cygpath" ]
  else
    raise @@ System.System_error
      (Format.sprintf "Wix binaries couldn't be found.")

let add_dlls_to_bundle ~bundle_dir (binary : Installer_config.exec_file) =
  let binary = System.maybe_exe ~dir:bundle_dir ~path:binary.path in
  let dlls = Win_ldd.get_dlls (bundle_dir // binary) in
  match dlls with
  | [] -> ()
  | _ ->
      OpamConsole.formatted_msg "Getting dlls for %s:\n%s" binary
        (OpamStd.Format.itemize OpamFilename.to_string dlls);
      let bin_dir = OpamFilename.Op.(bundle_dir / "bin") in
      OpamFilename.mkdir bin_dir;
      List.iter (fun dll -> OpamFilename.copy_in dll bin_dir) dlls

let add_dlls_to_bundle ~bundle_dir (binary : Installer_config.exec_file) =
  if binary.deps then
    add_dlls_to_bundle ~bundle_dir binary

let data_file ~tmp_dir ~default:(name, content) data_path =
  match data_path with
  | Some path -> path
  | None ->
      let dst = tmp_dir // name in
      OpamFilename.write dst content;
      OpamFilename.to_string dst

let create_installer ?(keep_wxs=false) ~tmp_dir
    ~(installer_config : Installer_config.internal) ~bundle_dir installer =
  check_wix_installed ();
  OpamConsole.header_msg "Preparing MSI installer using WiX";
  List.iter (fun binary ->
      add_dlls_to_bundle ~bundle_dir binary
    ) installer_config.exec_files;
  (* TODO: for now we consider this is an installer plugin
     if the configuration contains at least one plugin... *)
  let plugin_for =
    match installer_config.plugins with
    | [] -> None
    | p :: _ -> Some (p.app_name)
  in
  let icon = data_file ~tmp_dir ~default:Data.IMAGES.logo installer_config.wix_icon_file in
  let banner = data_file ~tmp_dir ~default:Data.IMAGES.banbmp installer_config.wix_banner_bmp_file in
  let background = data_file ~tmp_dir ~default:Data.IMAGES.dlgbmp installer_config.wix_dlg_bmp_file in
  let license =
    match installer_config.wix_license_file with
      | None -> None
      | lic -> Some (data_file ~tmp_dir ~default:Data.LICENSES.gpl3 lic)
  in
  let subject =
    Some (
      Printf.sprintf "%s, packed with Oui %s, commit %s, date %s"
        installer_config.name
        Version.version
        (match Version.commit_hash with None -> "-" | Some c -> c)
        (match Version.commit_date with None -> "-" | Some d -> d))
  in
  let info = Wix.{
      plugin_for;
      unique_id = installer_config.unique_id;
      manufacturer = installer_config.wix_manufacturer;
      name = installer_config.name;
      version = installer_config.version;
      subject;
      comments = installer_config.wix_description;
      keywords = installer_config.wix_tags;
      directory = OpamFilename.Dir.to_string bundle_dir;
      shortcuts = [];
      environment =
        List.map (fun (var_name, var_value) ->
            { var_name; var_value; var_part = All }
          ) installer_config.environment;
      registry = [];
      icon;
      banner;
      background;
      license;
    }
  in
  let (ui_wxs_filename, ui_wxs_content) =
    match info.plugin_for with
    | None -> Data.WIX.custom_app
    | Some (_) -> Data.WIX.custom_plugin
  in
  let ui_wxs_filepath = tmp_dir // ui_wxs_filename in
  OpamFilename.write ui_wxs_filepath ui_wxs_content;
  let main_wxs_filepath = tmp_dir // "main.wxs" in
  OpamConsole.formatted_msg "Preparing main WiX file...\n";
  let oc = open_out (OpamFilename.to_string main_wxs_filepath) in
  let fmt = Format.formatter_of_out_channel oc in
  Wix.print_wix fmt info;
  close_out oc;
  let wxs_files =
    (OpamFilename.to_string main_wxs_filepath |> System.cyg_win_path `WinAbs) ::
    (OpamFilename.to_string ui_wxs_filepath |> System.cyg_win_path `WinAbs) :: []
  in
  if keep_wxs then
    List.iter (fun file ->
        OpamFilename.copy_in (OpamFilename.of_string file)
        @@ OpamFilename.cwd ()) (* we are altering current dir !! *)
      wxs_files;
  let wix = System.{
      wix_files = wxs_files;
      wix_exts = ["WixToolset.UI.wixext"; "WixToolset.Util.wixext"];
      wix_out = OpamFilename.to_string installer;
    }
  in
  OpamConsole.formatted_msg "Producing final msi...\n";
  System.call_unit System.Wix wix;
  OpamConsole.formatted_msg "Done.\n"
