(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types

let sanitize_id id =
  String.map (fun c ->
      if c >= 'A' && c <= 'Z'
      || c >= 'a' && c <= 'z'
      || c >= '0' && c <= '9'
      || c = '_' || c = '.'
      then c
      else '_'
    ) id

let add_dlls_to_bundle ~bundle_dir binary =
  let dlls = Cygcheck.get_dlls OpamFilename.Op.(bundle_dir // binary) in
  match dlls with
  | [] -> ()
  | _ ->
      OpamConsole.formatted_msg "Getting dlls:\n%s"
        (OpamStd.Format.itemize OpamFilename.to_string dlls);
      let bin_dir = bundle_dir in
      (* TODO *) (* let bin_dir = OpamFilename.Op.(bundle_dir / "bin") in *)
      OpamFilename.mkdir bin_dir;
      List.iter (fun dll -> OpamFilename.copy_in dll bin_dir) dlls

let data_file ~tmp_dir ~default:(name, content) data_path =
  match data_path with
  | Some path -> path
  | None ->
      let dst = OpamFilename.Op.(tmp_dir // name) in
      OpamFilename.write dst content;
      OpamFilename.to_string dst

let create_bundle ~tmp_dir ~bundle_dir conf (desc : Installer_config.t) dst =
  let wix_path = System.normalize_path conf.conf_wix_path in
  System.check_available_commands wix_path;
  OpamConsole.header_msg "Preparing MSI installer using WiX";
  let exec_file =
    match desc.exec_files with
    | [exec] -> exec
    | _ ->
      OpamConsole.error_and_exit `False
        "WiX backend only supports installing a single binary"
  in
  add_dlls_to_bundle ~bundle_dir exec_file;
  let icon = data_file ~tmp_dir ~default:Data.IMAGES.logo desc.wix_icon_file in
  let banner = data_file ~tmp_dir ~default:Data.IMAGES.banbmp desc.wix_banner_bmp_file in
  let background = data_file ~tmp_dir ~default:Data.IMAGES.dlgbmp desc.wix_dlg_bmp_file in
  let license = data_file ~tmp_dir ~default:Data.LICENSES.gpl3 desc.wix_license_file in
  let info = Wix.{
      (* wix_guid = conf.conf_package_guid; *)
      unique_id = sanitize_id (String.concat "." [desc.manufacturer; desc.name]);
      organization = desc.manufacturer;
      short_name = desc.name;
      long_name = desc.name;
      version = desc.version;
      description = desc.description;
      keywords = String.concat " " desc.wix_tags;
      directory = OpamFilename.Dir.to_string bundle_dir;
      (* wix_exec_file; wix_dlls; wix_embedded_dirs = []; wix_embedded_files = []; *)
      shortcuts = [];
      environment =
        List.map (fun (var_name, var_value) ->
            { var_name; var_value; var_part = All }
          ) desc.wix_environment;
      registry = [];
      icon;
      banner;
      background;
      license;
    }
  in
  let (extra, content) = Data.WIX.custom_app in
  let extra_path = OpamFilename.Op.(tmp_dir // extra) in
  OpamFilename.write extra_path content;
  let name = Filename.chop_extension exec_file in
  let main_path = OpamFilename.Op.(tmp_dir // (name ^ ".wxs")) in
  OpamConsole.formatted_msg "Preparing main WiX file...\n";
  let oc = open_out (OpamFilename.to_string main_path) in
  let fmt = Format.formatter_of_out_channel oc in
  Wix.print_wix fmt info;
  close_out oc;
  let wxs_files =
    (OpamFilename.to_string main_path |> System.cyg_win_path `WinAbs) ::
    (OpamFilename.to_string extra_path |> System.cyg_win_path `WinAbs) :: []
  in
  if conf.conf_keep_wxs then
    List.iter (fun file ->
        OpamFilename.copy_in (OpamFilename.of_string file)
        @@ OpamFilename.cwd ()) (* we are altering current dir !! *)
      wxs_files;
  let wix = System.{
      wix_wix_path = wix_path;
      wix_files = wxs_files;
      wix_exts = ["WixToolset.UI.wixext"; "WixToolset.Util.wixext"];
      wix_out = (name ^ ".msi")
    }
  in
  OpamConsole.formatted_msg "Producing final msi...\n";
  System.call_unit System.Wix wix;
  OpamFilename.remove (OpamFilename.of_string (name ^ ".wixpdb"));
  OpamFilename.move
    ~src:(OpamFilename.of_string (name ^ ".msi"))
    ~dst;
  OpamConsole.formatted_msg "Done.\n"
