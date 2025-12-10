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

let run installer_config bundle_dir =
  let res =
    let open Letop.Result in
    let backend = Oui_cli.Args.autodetect_backend ~log:false () in
    let vars = Oui_cli.Args.vars_of_backend backend in
    let* user_config = Installer_config.load installer_config in
    let res, warnings = 
      Installer_config.check_and_expand ~bundle_dir ~vars user_config
    in
    Oui_cli.Warnings.handle warnings;
    let+ _installer_config = res in
    ()
  in
  let config_path = OpamFilename.to_string installer_config in
  Oui_cli.Errors.handle ~config_path res

let term =
  let open Cmdliner.Term in
  const run
  $ Oui_cli.Args.installer_config
  $ Oui_cli.Args.bundle_dir

let cmd =
  let info =
    let doc =
      "Check the consistency of the oui configuration and install bundle"
    in
    Cmdliner.Cmd.info ~doc "lint"
  in
  Cmdliner.Cmd.v info term
