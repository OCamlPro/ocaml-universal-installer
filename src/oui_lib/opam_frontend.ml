(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamTypes
open OpamStateTypes
open Types

let normalize_conf env conf file =
  let open File.Conf in
  (* argument has precedence over config *)
  let merge_opt first second =
    match first with
    | None -> second
    | _ -> first
  in
  {
    conf with
    conf_wix_version = merge_opt conf.conf_wix_version file.c_wix_version;
    conf_icon_file = merge_opt conf.conf_icon_file
        (Option.map (System.resolve_file_path env) file.c_images.ico);
    conf_dlg_bmp = merge_opt conf.conf_dlg_bmp
        (Option.map (System.resolve_file_path env) file.c_images.dlg);
    conf_ban_bmp = merge_opt conf.conf_ban_bmp
        (Option.map (System.resolve_file_path env) file.c_images.ban);
  }

let wix_version ~conf package =
  match conf.conf_wix_version with
  | Some v -> v
  | None ->
    let pkg_version =
      OpamPackage.Version.to_string (OpamPackage.version package)
    in
    try Wix.Version.of_string pkg_version
    with Failure _ ->
      (OpamConsole.warning
         "Package version %s contains characters not accepted by MSI."
         (OpamConsole.colorise `underline pkg_version);
       let use = "use config file to set it or option --with-version" in
       let version =
         let n =
           OpamStd.String.find_from (function '0'..'9' | '.' -> false | _ -> true)
             pkg_version 0
         in
         if n = 0 then
           OpamConsole.error_and_exit `Not_found
             "No version can be retrieved from '%s', %s."
             pkg_version use
         else
           String.sub pkg_version 0 n
       in
       OpamConsole.msg
         "It must be only dot separated numbers. You can %s.\n" use;
       if
         OpamConsole.confirm "Do you want to use simplified version %s?"
           (OpamConsole.colorise `underline version)
       then version
       else OpamStd.Sys.exit_because `Aborted)

let binaries changes =
  List.filter_map
    (fun name ->
      let prefix, suffix =
        if Sys.win32
        then "bin\\",".exe"
        else "bin/",""
      in
      let bin =
        OpamStd.String.remove_prefix ~prefix name
        |> OpamStd.String.remove_suffix ~suffix
      in
      if String.equal bin name then None
      else Some bin)
    changes

let binaries_path ~opam_bin_folder ~binaries package =
    match binaries with
    | [] ->
      OpamConsole.error_and_exit `Not_found
        "No binary file found at package installation %s"
        (OpamConsole.colorise `bold (OpamPackage.to_string package))
    | bins ->
      List.map
        (fun bin ->
           let bin = if Sys.win32 then bin ^ ".exe" else bin in
           OpamFilename.Op.(opam_bin_folder // bin))
        bins

let package_description ~opam package =
  let synopsis =
    match OpamFile.OPAM.synopsis opam with None -> "" | Some s -> s
  in
  let descr =
    match OpamFile.OPAM.descr_body opam with None -> "" | Some s -> s
  in
  let summary = Printf.sprintf "Package %s" (OpamPackage.to_string package) in
  synopsis ^ descr ^ summary

let package_environment ~conffile ~embedded_dirs ~embedded_files =
  let all_paths =
    let paths =
      List.fold_left (fun paths (base, _dirname) ->
          let base = OpamFilename.Base.to_string base in
          OpamStd.String.Map.add base ("[INSTALLDIR]"^base)
            paths)
        OpamStd.String.Map.empty embedded_dirs
    in
    List.fold_left (fun paths (base, _filename) ->
        let base = OpamFilename.Base.to_string base in
        OpamStd.String.Map.add base ("[INSTALLDIR]"^base)
          paths)
      paths embedded_files
  in
  let env var =
    assert (OpamVariable.Full.scope var = OpamVariable.Full.Global);
    let svar = OpamVariable.Full.to_string var in
    match OpamStd.String.Map.find_opt svar all_paths with
    | None -> None
    | Some path -> Some (OpamVariable.string path)
  in
  List.map (fun (var,content) ->
      let content =
        OpamFilter.expand_string ~partial:false ~default:(fun x -> x)
          env content
      in
      var, content)
    conffile.File.Conf.c_envvar

(* search and copy embedded elements *)
let copy_embedded
    (type a)
    (module F : System.FILE_INTF with type t = a)
    ~env
    ~bundle_dir
    path dst_base =
  let src = System.resolve_path env (module F) path in
  if not @@ F.exists src
  then
    OpamConsole.error_and_exit
      `Not_found
      "Couldn't find %s %s."
      (OpamConsole.colorise `bold (F.to_string src))
      F.name;
  let dst = F.(bundle_dir / dst_base) in
  F.copy ~src ~dst;
  F.basename dst, dst

let copy_include path src_dir dst_dir =
  let sep = if Sys.cygwin then '/' else '\\' in
  let dirs = OpamStd.String.split path sep in (* this is wrong, should support both / and \ *)
  let rec aux src dst files =
    match files with
    | [] -> ()
    | [ file ] when Sys.is_directory @@
        Filename.concat (OpamFilename.Dir.to_string src) file ->
      let src = OpamFilename.Op.(src/file) in
      let dst = OpamFilename.Op.(dst/file) in
      OpamFilename.copy_dir ~src ~dst;
    | [ file ] ->
      let src' = OpamFilename.Op.(src//file) in
      OpamFilename.copy_in src' dst;
    | file :: files ->
      let src =  OpamFilename.Op.(src/file) in
      let dst = OpamFilename.Op.(dst/file) in
      if not @@ OpamFilename.exists_dir dst then OpamFilename.mkdir dst;
      aux src dst files
  in
  aux src_dir dst_dir dirs

(* Extract and specifies extra files to embed in the install archive as
   described by the configuration file. *)
let conf_embedded ~global_state ~switch_state ~env conffile =
  List.filter_map (fun (path,alias) ->
      let path = OpamFilter.expand_string env path in
      let prefix =
        OpamPath.Switch.root global_state.root switch_state.switch
        |> OpamFilename.Dir.to_string
      in
      match alias with
      | Some alias -> Some (Copy_alias (path, alias))
      | _ when OpamStd.String.starts_with ~prefix path ->
        if not @@ Sys.file_exists path then
          OpamConsole.error_and_exit
            `Not_found
            "Couldn't find embedded %s in switch prefix."
            (OpamConsole.colorise `bold path);
        let path =
          OpamStd.String.remove_prefix
            ~prefix:Filename.dir_sep @@
          OpamStd.String.remove_prefix ~prefix path
        in
        begin
          match String.trim path with
          | "" ->
            OpamConsole.warning
              "Specify a subdirectory of opam-prefix to \
               include in your installtion. Skipping...";
            None
          | _ -> Some (Copy_opam path)
        end
      | _ when not (Filename.is_relative path && Filename.is_implicit path) ->
        OpamConsole.warning
          "Path %s is absolute or starts with \"..\" or \".\". You should specify \
           alias with absolute path. Skipping..."
          path;
        None
      | _ ->
        if not @@ Sys.file_exists path
        then
          OpamConsole.error_and_exit `Not_found
            "Couldn't find relative path to embed: %s."
            (OpamConsole.colorise `bold path);
        Some (Copy_external path))
    conffile.File.Conf.c_embedded

let manpages changes =
  let manpages =
    List.filter_map
      (fun path ->
         let prefix = if Sys.win32 then "man\\" else "man/" in
         let page = OpamStd.String.remove_prefix ~prefix path in
         if String.equal path page then None else Some page)
      changes
  in
  List.fold_left
    (fun map page ->
       let section =
         match Filename.dirname page with
         | "man1M" -> "man8"
         | s -> s
       in
       let page = Filename.basename page in
       OpamStd.String.Map.update section (fun l -> page::l) [page] map)
    OpamStd.String.Map.empty
    manpages
  |> OpamStd.String.Map.bindings

let copy_manpages_to_bundle ~opam_man_dir ~bundle_dir manpages =
  match manpages with
  | [] -> ()
  | _ ->
    let man_dir = OpamFilename.Op.(bundle_dir / "man") in
    OpamFilename.mkdir man_dir;
    List.iter
      (fun (section, pages) ->
         let section_dir = OpamFilename.Op.(man_dir / section) in
         OpamFilename.mkdir section_dir;
         List.iter
           (fun page ->
              let src = OpamFilename.Op.(opam_man_dir / section // page) in
              let dst = OpamFilename.Op.(section_dir // page) in
              OpamFilename.copy ~src ~dst)
           pages)
      manpages

let manpages_paths manpages =
  let (/) = Filename.concat in
  List.map
    (fun (section, pages) ->
       let pages_paths = List.map (fun page -> "man" / section / page) pages in
       section, pages_paths)
    manpages

let create_bundle ~global_state ~switch_state ~env ~tmp_dir conf conffile
    package_name =
  let package =
    try
      OpamSwitchState.find_installed_package_by_name switch_state package_name
    with Not_found ->
      OpamConsole.error_and_exit `Not_found
        "Package %s isn't found in your current switch. Please, run %s and retry."
        (OpamConsole.colorise `bold (OpamPackage.Name.to_string package_name))
        (OpamConsole.colorise `bold ("opam install " ^ (OpamPackage.Name.to_string package_name)))
  in
  let version = wix_version ~conf package in
  let opam = OpamSwitchState.opam switch_state package in
  let changes : string list =
    OpamPath.Switch.changes global_state.root switch_state.switch package_name
    |> OpamFile.Changes.safe_read
    |> OpamStd.String.Map.keys
  in
  let binaries = binaries changes in
  OpamConsole.formatted_msg "Package %s found with binaries:\n%s"
    (OpamConsole.colorise `bold (OpamPackage.to_string package))
    (OpamStd.Format.itemize (fun x -> x) binaries);
  let opam_bin_folder =
    OpamPath.Switch.bin
      global_state.root switch_state.switch switch_state.switch_config
  in
  let binaries_path = binaries_path ~opam_bin_folder ~binaries package in
  OpamConsole.header_msg "Creating installation bundle";
  let bundle_dir = OpamFilename.Op.(tmp_dir / OpamPackage.to_string package) in
  OpamFilename.mkdir bundle_dir;
  let opam_dir = OpamFilename.Op.(bundle_dir / "opam") in
  let external_dir = OpamFilename.Op.(bundle_dir / "external") in
  OpamFilename.mkdir opam_dir;
  OpamFilename.mkdir external_dir;
  let exe_bases = List.map OpamFilename.basename binaries_path in
  List.iter2
    (fun binary_path exe_base ->
       OpamFilename.copy ~src:binary_path
         ~dst:(OpamFilename.create bundle_dir exe_base))
    binaries_path
    exe_bases;
  let manpages = manpages changes in
  let opam_man_dir =
    OpamPath.Switch.man_dir global_state.root switch_state.switch
      switch_state.switch_config
  in
  copy_manpages_to_bundle ~opam_man_dir ~bundle_dir manpages;
  let manpages_paths = manpages_paths manpages in
  let emb_modes = conf_embedded ~global_state ~switch_state ~env conffile in
  let (embedded_dirs : (basename * dirname) list),
      (embedded_files : (basename * filename) list) =
    List.fold_left
      (fun (dirs, files) -> function
         | Copy_alias (dirname, alias) when Sys.is_directory dirname ->
           let dir =
             copy_embedded (module System.DIR_IMPL) ~env ~bundle_dir dirname alias
           in
           (dir::dirs, files)
         | Copy_alias (filename, alias) ->
           let file =
             copy_embedded (module System.FILE_IMPL) ~env ~bundle_dir filename alias
           in
           (dirs, file::files)
         | Copy_opam path ->
           let prefix =
             OpamPath.Switch.root global_state.root switch_state.switch
           in
           copy_include path prefix opam_dir;
           (dirs, files)
         | Copy_external path ->
           copy_include path (OpamFilename.Dir.of_string ".") external_dir;
           (dirs, files))
      ([],[])
      emb_modes
  in
  let additional_embedded_name, additional_embedded_dir =
    let opam_base, opam_dir =
      match OpamFilename.dir_is_empty opam_dir with
      | None | Some (true) -> [], []
      | Some (false) -> ["opam"], [ opam_dir ]
    and external_base, external_dir =
      match OpamFilename.dir_is_empty external_dir with
      | None | Some (true) -> [], []
      | Some (false) -> ["external"], [ external_dir ]
    in (opam_base @ external_base), (opam_dir @ external_dir)
  in
  OpamConsole.formatted_msg "Bundle created.\n";
  let open Installer_config in
  (bundle_dir,
   {
     name = OpamPackage.Name.to_string (OpamPackage.name package);
     fullname = OpamPackage.to_string package;
     version;
     description = package_description ~opam package;
     manufacturer = String.concat ", " (OpamFile.OPAM.maintainer opam);
     wix_guid = conf.conf_package_guid;
     wix_tags = (match OpamFile.OPAM.tags opam with [] -> ["ocaml"] | ts -> ts );
     exec_files = List.map OpamFilename.Base.to_string exe_bases;
     wix_icon_file = Option.map OpamFilename.to_string conf.conf_icon_file;
     wix_dlg_bmp_file = Option.map OpamFilename.to_string conf.conf_dlg_bmp;
     wix_banner_bmp_file = Option.map OpamFilename.to_string conf.conf_ban_bmp;
     wix_license_file = None; (* TODO *)
     wix_environment =
       package_environment ~conffile ~embedded_dirs ~embedded_files;
     wix_embedded_dirs = embedded_dirs ;
     wix_additional_embedded_name = additional_embedded_name ;
     wix_embedded_files = embedded_files ;
     wix_additional_embedded_dir = additional_embedded_dir;
     makeself_manpages = Installer_config.manpages_of_list manpages_paths;
     macos_bundle_id = None; (* TODO *)
     macos_manpages = None; (* TODO *)
   })

let with_opam_and_conf cli global_options conf f =
  let conffile =
    let file = OpamStd.Option.default File.conf_default conf.conf_file in
    File.Conf.safe_read (OpamFile.make file)
  in
  OpamConsole.header_msg "Initialising opam";
  OpamArg.apply_global_options cli global_options;
  OpamGlobalState.with_ `Lock_read
  @@ fun global_state ->
  OpamSwitchState.with_ `Lock_read global_state
  @@ fun switch_state ->
  let env = OpamPackageVar.resolve ?opam:None ?local:None switch_state in
  let conf = normalize_conf env conf conffile in
  OpamFilename.with_tmp_dir @@
  fun tmp_dir ->
  f ~global_state ~switch_state ~env ~tmp_dir conf conffile;
  OpamSwitchState.drop switch_state;
  OpamGlobalState.drop global_state

let with_install_bundle cli global_options conf package f =
  with_opam_and_conf cli global_options conf
    (fun ~global_state ~switch_state ~env ~tmp_dir conf conffile ->
       let bundle_dir, desc =
         create_bundle ~global_state ~switch_state ~env ~tmp_dir conf conffile
           package
       in
       f conf desc ~bundle_dir ~tmp_dir)
