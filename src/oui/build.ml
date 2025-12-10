(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui

let run keep_wxs backend installer_config bundle_dir output
  verbose_level debug_level =
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
           Wix_backend.create_bundle ~keep_wxs ~tmp_dir ~bundle_dir installer_config dst
         | Makeself ->
           Makeself_backend.create_installer ~installer_config ~bundle_dir dst
         | Pkgbuild ->
           Pkgbuild_backend.create_installer ~installer_config ~bundle_dir dst)
  in
  let config_path = OpamFilename.to_string installer_config in
  Oui_cli.Errors.handle ~config_path res

let term =
  let open Cmdliner.Term in
  const run
  $ Oui_cli.Args.wix_keep_wxs
  $ Oui_cli.Args.backend
  $ Oui_cli.Args.installer_config
  $ Oui_cli.Args.bundle_dir
  $ Oui_cli.Args.output
  $ Oui_cli.Args.verbose
  $ Oui_cli.Args.debug

let cmd =
  let info =
    let doc = "Build your binary installer. Default command." in
    Cmdliner.Cmd.info ~doc "build"
  in
  Cmdliner.Cmd.v info term
