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

let help = Cmdliner.Term.(ret (const (`Help (`Auto, None))))

let cmd =
  Cmdliner.Cmd.group
    ~default:help
    info
    [ Build.cmd; Lint.cmd ]

let () =
  let status = Cmdliner.Cmd.eval' cmd in
  exit status
