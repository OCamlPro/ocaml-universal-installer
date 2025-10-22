
(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let create_installer
    ~(installer_config : Installer_config.t) ~bundle_dir installer =
  (* TODO *)
  ignore installer_config;
  ignore bundle_dir;
  ignore installer;
  OpamConsole.formatted_msg "Done.\n"
