(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Cmdliner
open Oui

let package =
  let open Arg in
  required
  & pos 0 (some OpamArg.package_name) None
  & info [] ~docv:"PACKAGE" ~docs:Oui_cli.Man.Section.package_arg
      ~doc:"The package to create an installer for"

let save_bundle_and_conf ~(installer_config : Installer_config.t) ~bundle_dir
    dst =
  OpamFilename.move_dir ~src:bundle_dir ~dst;
  let conf_path = OpamFilename.Op.(dst // "oui.json") in
  Installer_config.save installer_config conf_path

let create_bundle cli =
  let doc = "Extract package installer bundle" in
  let create_bundle global_options conf backend output package () =
    Opam_frontend.with_install_bundle cli global_options conf package
      (fun conf installer_config ~bundle_dir ~tmp_dir ->
         let output =
           Oui_cli.Args.output_name ~output ~backend installer_config
         in
         match backend with
         | None ->
           let dst = OpamFilename.Dir.of_string output in
           save_bundle_and_conf ~installer_config ~bundle_dir dst
         | Some Wix ->
           let dst = OpamFilename.of_string output in
           Wix_backend.create_bundle ~tmp_dir ~bundle_dir conf installer_config dst
         | Some Makeself ->
           let dst = OpamFilename.of_string output in
           Makeself_backend.create_installer ~installer_config ~bundle_dir dst
         | Some Pkgbuild ->
           let dst = OpamFilename.of_string output in
           Pkgbuild_backend.create_installer ~installer_config ~bundle_dir dst)
  in
  OpamArg.mk_command ~cli OpamArg.cli_original "opam-oui"
    ~doc ~man:[]
    Term.(const create_bundle
          $ OpamArg.global_options cli
          $ Oui_cli.Args.config
          $ Oui_cli.Args.backend_opt
          $ Oui_cli.Args.output
          $ package)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
