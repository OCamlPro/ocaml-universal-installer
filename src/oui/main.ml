(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let info =
  let doc = "Create binary installers for your application and plugins" in
  Cmdliner.Cmd.info ~doc "oui"

let cmd =
  Cmdliner.Cmd.group
    ~default:Build.term
    info
    [ Build.cmd; Lint.cmd ]

let () =
  let status = Cmdliner.Cmd.eval' cmd in
  exit status
