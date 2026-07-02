(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui

let run (`Keep_wxs keep_wxs) (`Backend backend) (`Mtime mtime)
    (`Tar_extra tar_extra) (`App_signing_id macos_application_signing_id)
    (`Installer_config installer_config) (`Bundle_dir bundle_dir)
    (`Output output) (`Verbose verbose_level) (`Debug debug_level) =
  OpamCoreConfig.init ~verbose_level ~debug_level ();
  let res =
    let open Letop.Result in
    let* user_config = Installer_config.load installer_config in
    let vars = Oui_cli.Args.vars_of_backend backend in
    let res, warnings =
      Installer_config.check_and_expand ~vars ~bundle_dir user_config
    in
    Oui_cli.Warnings.handle warnings;
    let+ installer_config = res in
    let installer_config =
      Oui_cli.Args.override_config
        ~macos_application_signing_id
        installer_config
    in
    let output =
      Oui_cli.Args.output_name ~output ~backend:(Some backend) installer_config
    in
    let dst = OpamFilename.of_string output in
    OpamFilename.with_tmp_dir
      (fun tmp_dir ->
         let src = bundle_dir in
         let bundle_dir = OpamFilename.Op.(tmp_dir / "bundle") in
         OpamFilename.copy_dir ~src ~dst:bundle_dir;
         match backend with
         | Wix ->
           Wix_backend.create_installer ~keep_wxs ~tmp_dir ~installer_config ~bundle_dir dst
         | Makeself ->
           Makeself_backend.create_installer ?mtime ?tar_extra ~installer_config
             ~bundle_dir dst
         | Pkgbuild ->
           Pkgbuild_backend.create_installer ~installer_config ~bundle_dir dst)
  in
  let config_path = OpamFilename.to_string installer_config in
  Oui_cli.Errors.handle ~config_path res

let term =
  let open Cmdliner.Term in
  const run
  $ map (fun x -> `Keep_wxs x) Oui_cli.Args.wix_keep_wxs
  $ map (fun x -> `Backend x) Oui_cli.Args.backend
  $ map (fun x -> `Mtime x) Oui_cli.Args.mtime
  $ map (fun x -> `Tar_extra x) Oui_cli.Args.tar_extra
  $ map (fun x -> `App_signing_id x) Oui_cli.Args.macos_application_signing_id
  $ map (fun x -> `Installer_config x) Oui_cli.Args.installer_config
  $ map (fun x -> `Bundle_dir x) Oui_cli.Args.bundle_dir
  $ map (fun x -> `Output x) Oui_cli.Args.output
  $ map (fun x -> `Verbose x) Oui_cli.Args.verbose
  $ map (fun x -> `Debug x) Oui_cli.Args.debug

let cmd =
  let info =
    let doc = "Build your binary installer. Default command." in
    Cmdliner.Cmd.info ~doc "build"
  in
  Cmdliner.Cmd.v info term
