(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamCmdliner
open Oui

let package =
  let open Arg in
  required
  & pos 0 (some OpamArg.package_name) None
  & info [] ~docv:"PACKAGE" ~docs:Oui_cli.Man.Section.package_arg
      ~doc:"The package to create an installer for"

let opam_filename =
  let conv, pp = OpamArg.filename in
  ((fun filename_arg -> System.normalize_path filename_arg |> conv), pp)

let output =
  let open Arg in
  let doc =
    "$(docv) installer or bundle name. Defaults to \
     $(b,package-name.version.ext), in the current directory, where $(b,ext) \
     is $(b,.msi) for Windows installers and $(b,.run) for Linux installers."
  in
  value
  & opt (some string) None
  & info ~docv:"OUTPUT" ~doc [ "o"; "output" ]

let opam_conf_file =
  let open Arg in
  value
  & opt (some opam_filename) None
  & info [ "conf"; "c" ] ~docv:"PATH" ~docs:Oui_cli.Man.Section.bin_args
      ~doc:
        "Configuration file for opam-oui, defaults to opam-oui.conf. \
         See $(i,Configuration) section"

let wix_keep_wxs =
  let open Arg in
  value & flag & info [ "keep-wxs" ] ~doc:"Keep Wix source files."

let no_backend =
  let open Arg in
  value & flag & info [ "no-backend" ]
    ~doc:"Do not create an actual installer, just the install bundle and \
          oui.json file"

let save_bundle_and_conf ~(installer_config : Installer_config.user) ~bundle_dir
    dst =
  OpamFilename.move_dir ~src:bundle_dir ~dst;
  let conf_path = OpamFilename.Op.(dst // "oui.json") in
  Installer_config.save installer_config conf_path

let create_bundle cli =
  let doc = "Extract package installer bundle" in
  let create_bundle global_options conf_file keep_wxs no_backend output
      package () =
    Opam_frontend.with_install_bundle ?conf_file cli global_options package
      (fun installer_config ~bundle_dir ~tmp_dir ->
         let backend =
           if no_backend then
             None
           else
             Some (Oui_cli.Args.autodetect_backend ())
         in
         let output =
           Oui_cli.Args.output_name ~output ~backend installer_config
         in
         match backend with
         | None ->
           let dst = OpamFilename.Dir.of_string output in
           let manpages =
             Option.map Installer_config.manpages_of_expanded
               installer_config.manpages
           in
           let environment =
             List.map
               (fun (var, value) -> var, String_with_vars.of_string value)
               installer_config.environment
           in
           let installer_config =
             {installer_config with manpages; environment}
           in
           save_bundle_and_conf ~installer_config ~bundle_dir dst
         | Some Wix ->
           let dst = OpamFilename.of_string output in
           Wix_backend.create_bundle ~keep_wxs ~tmp_dir ~bundle_dir
             installer_config dst
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
          $ opam_conf_file
          $ wix_keep_wxs
          $ no_backend
          $ output
          $ package)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
