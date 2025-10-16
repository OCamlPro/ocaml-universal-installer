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

let create_bundle ~tmp_dir ~bundle_dir conf (desc : Installer_config.t) dst =
  let wix_path = System.normalize_path conf.conf_wix_path in
  System.check_available_commands wix_path;
  OpamConsole.header_msg "WiX setup";
  let component_group basename =
    String.capitalize_ascii basename ^ "CG"
  in
  let dir_ref basename = basename ^ "_REF" in
  (* add .exe suffix if needed *)
  let exec_file =
    match desc.exec_files with
    | [exec] -> exec
    | _ ->
      OpamConsole.error_and_exit `False
        "WiX backend only supports installing a single binary"
  in
  let wix_exec_file =
    match Filename.extension exec_file with
    | ".exe" -> exec_file
    | _ ->
      let dst = exec_file ^ ".exe" in
      OpamFilename.move
        ~src:OpamFilename.Op.(bundle_dir // exec_file)
        ~dst:OpamFilename.Op.(bundle_dir // dst);
      dst
  in
  let wix_dlls =
    let dlls = Cygcheck.get_dlls OpamFilename.Op.(bundle_dir // wix_exec_file) in
    OpamConsole.formatted_msg "Getting dlls/so:\n%s"
      (OpamStd.Format.itemize OpamFilename.to_string dlls);
    List.iter (fun dll -> OpamFilename.copy_in dll bundle_dir) dlls;
    List.map (fun dll -> OpamFilename.(basename dll |> Base.to_string)) dlls
  in
  let image_file ~default:(name, content) data_path =
    match data_path with
    | Some path -> path
    | None ->
      let dst = OpamFilename.Op.(tmp_dir // name) in
      OpamFilename.write dst content;
      OpamFilename.to_string dst
  in
  let wix_icon_file = image_file ~default:Data.IMAGES.logo desc.wix_icon_file in
  let wix_dlg_bmp_file =
    image_file ~default:Data.IMAGES.dlgbmp desc.wix_dlg_bmp_file
  in
  let wix_banner_bmp_file =
    image_file ~default:Data.IMAGES.banbmp desc.wix_banner_bmp_file
  in
  let info = Wix.{
      wix_path = (*Filename.basename @@*) OpamFilename.Dir.to_string bundle_dir;
      wix_name = desc.name;
      wix_version = desc.version;
      wix_description = desc.description;
      wix_manufacturer = desc.manufacturer;
      wix_guid = conf.conf_package_guid;
      wix_tags = desc.wix_tags;
      wix_exec_file;
      wix_dlls;
      wix_icon_file;
      wix_dlg_bmp_file;
      wix_banner_bmp_file;
      wix_environment = desc.wix_environment;
      wix_embedded_dirs =
        List.map (fun (base, dir) ->
            (* FIXME: do we need absolute dir ? *)
            let base = OpamFilename.Base.to_string base in
            base, component_group base, dir_ref base, OpamFilename.Dir.to_string dir)
          (desc.wix_embedded_dirs @
           List.map2 (fun base dir -> OpamFilename.Base.of_string base, dir)
             desc.wix_additional_embedded_name
             desc.wix_additional_embedded_dir);
      wix_embedded_files =
        List.map (fun (base, _) ->
            OpamFilename.Base.to_string base)
          desc.wix_embedded_files;
    }
  in
  let wxs = Wix.main_wxs info in
  let name = Filename.chop_extension exec_file in
  let (addwxs1, content1) = Data.WIX.custom_install_dir in
  OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs1) content1;
  let (addwxs2, content2) = Data.WIX.custom_install_dir_dlg in
  OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs2) content2;
  let additional_wxs =
    List.map (fun d ->
        OpamFilename.to_string d |> System.cyg_win_path `WinAbs)
      OpamFilename.Op.[ tmp_dir//addwxs1; tmp_dir//addwxs2 ]
  in
  let main_path = OpamFilename.Op.(tmp_dir // (name ^ ".wxs")) in
  OpamConsole.formatted_msg "Preparing main WiX file...\n";
  Wix.write_wxs (OpamFilename.to_string main_path) wxs;
  let wxs_files =
    (OpamFilename.to_string main_path |> System.cyg_win_path `WinAbs)
    :: additional_wxs
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
