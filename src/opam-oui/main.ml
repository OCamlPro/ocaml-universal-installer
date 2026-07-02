(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamCmdliner
open Oui

let arg_from_abstract : type a. a Oui_cli.Args.abstract -> a Arg.t =
  fun {names; docv; doc; kind} ->
  let open Arg in
  let info = info ~doc ~docv names in
  match kind with
  | Flag -> flag info
  | String_opt default -> opt (some string) default info

let package =
  let open Arg in
  required
  & pos 0 (some OpamArg.package_name) None
  & info [] ~docv:"PACKAGE" ~docs:Oui_cli.Man.Section.package_arg
      ~doc:"The package to create an installer for"

let macos_application_signing_id =
  let open Arg in
  value & arg_from_abstract Oui_cli.Args.macos_application_signing_id_abstract

let opam_filename =
  let conv, pp = OpamArg.filename in
  ((fun filename_arg -> System.normalize_path filename_arg |> conv), pp)

let output =
  let open Arg in
  value & arg_from_abstract Oui_cli.Args.output_abstract

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
  value & arg_from_abstract Oui_cli.Args.wix_keep_wxs_abstract

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
  let create_bundle global_options conf_file
      (`App_signing_id macos_application_signing_id)
      (`Keep_wxs keep_wxs) (`No_backend no_backend) (`Output output) package ()
    =
    Opam_frontend.with_install_bundle ?conf_file cli global_options package
      (fun installer_config ~bundle_dir ~tmp_dir ->
         let installer_config =
           Oui_cli.Args.override_config
             ~macos_application_signing_id
             installer_config
         in
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
           Wix_backend.create_installer ~keep_wxs ~tmp_dir ~installer_config
             ~bundle_dir dst
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
          $ map (fun x -> `App_signing_id x) macos_application_signing_id
          $ map (fun x -> `Keep_wxs x) wix_keep_wxs
          $ map (fun x -> `No_backend x) no_backend
          $ map (fun x -> `Output x) output
          $ package)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
