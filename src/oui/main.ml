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

let installer_config =
  let open Cmdliner.Arg in
  let docv = "CONFIG" in
  let doc = "Path to the oui.json installer config." in
  required & pos 0 (some Oui_cli.Args.opam_filename) None & info [] ~docv ~doc

let bundle_dir =
  let open Cmdliner.Arg in
  let docv = "BUNDLE_DIR" in
  let doc = "Path to the directory containing the dirs and files to install." in
  required & pos 1 (some Oui_cli.Args.opam_dirname) None & info [] ~docv ~doc

let run conf backend installer_config bundle_dir output =
  let installer_config = Installer_config.load installer_config in
  let output =
    Oui_cli.Args.output_name ~output ~backend:(Some backend) installer_config
  in
  let dst = OpamFilename.of_string output in
  match backend with
  | Wix ->
      OpamFilename.with_tmp_dir (fun tmp_dir ->
          Wix_backend.create_bundle ~tmp_dir ~bundle_dir conf installer_config
            dst)
  | Makeself ->
      Makeself_backend.create_installer ~installer_config ~bundle_dir dst
  | Pkgbuild ->
      Pkgbuild_backend.create_installer ~installer_config ~bundle_dir dst

let cmd =
  let term =
    let open Cmdliner.Term in
    const run $ Oui_cli.Args.config $ Oui_cli.Args.backend $ installer_config
    $ bundle_dir $ Oui_cli.Args.output
  in
  let info =
    let doc = "Create binary installers for your application" in
    Cmdliner.Cmd.info ~doc "oui"
  in
  Cmdliner.Cmd.v info term

let () =
  let status = Cmdliner.Cmd.eval cmd in
  exit status
