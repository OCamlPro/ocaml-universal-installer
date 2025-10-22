(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module Yojsonable = struct
  type dirname = OpamFilename.Dir.t

  let dirname_to_yojson dir = `String (OpamFilename.Dir.to_string dir)
  let dirname_of_yojson = function
    | `String dir -> Ok (OpamFilename.Dir.of_string dir)
    | _ -> Error "Invalid OpamFilename.Dir.t JSON encoding"

  type filename = OpamFilename.t

  let filename_to_yojson fn = `String (OpamFilename.to_string fn)
  let filename_of_yojson = function
    | `String fn -> Ok (OpamFilename.of_string fn)
    | _ -> Error "Invalid OpamFilename.t JSON encoding"

  type basename = OpamFilename.Base.t

  let basename_to_yojson bn = `String (OpamFilename.Base.to_string bn)
  let basename_of_yojson = function
    | `String bn -> Ok (OpamFilename.Base.of_string bn)
    | _ -> Error "Invalid OpamFilename.Base.t JSON encoding"
end

type manpages =
  { man1 : string list [@default []]
  ; man2 : string list [@default []]
  ; man3 : string list [@default []]
  ; man4 : string list [@default []]
  ; man5 : string list [@default []]
  ; man6 : string list [@default []]
  ; man7 : string list [@default []]
  ; man8 : string list [@default []]
  }
[@@deriving yojson]

type t = {
    name : string;
    fullname : string ;
    version : string;
    description : string;
    manufacturer : string;
    exec_files : string list;
    makeself_manpages : manpages option; [@default None]
    wix_guid : string option; [@default None]
    wix_tags : string list; [@default []]
    wix_icon_file : string option; [@default None]
    wix_dlg_bmp_file : string option; [@default None]
    wix_banner_bmp_file : string option; [@default None]
    wix_license_file : string option; [@default None]
    wix_embedded_dirs : (Yojsonable.basename * Yojsonable.dirname) list; [@default []]
    wix_additional_embedded_name : string list; [@default []]
    wix_additional_embedded_dir : Yojsonable.dirname list; [@default []]
    wix_embedded_files : (Yojsonable.basename * Yojsonable.filename) list; [@default []]
    wix_environment : (string * string) list; [@default []]
    macos_bundle_id : string option; [@default None]
    macos_manpages : manpages option; [@default None]
  }
[@@deriving yojson]

let manpages_to_list mnpgs =
  [ ("man1", mnpgs.man1)
  ; ("man2", mnpgs.man2)
  ; ("man3", mnpgs.man3)
  ; ("man4", mnpgs.man4)
  ; ("man5", mnpgs.man5)
  ; ("man6", mnpgs.man6)
  ; ("man7", mnpgs.man7)
  ; ("man8", mnpgs.man8)
  ]
  |> List.filter (function (_, []) -> false | _ -> true)

let manpages_of_list = function
  | [] -> None
  | l ->
    let init =
      { man1 = []; man2 = []; man3 = []; man4 = []; man5 = []; man6 = []
      ; man7 = []; man8 = [] }
    in
    let mnpgs =
      List.fold_left
        (fun acc (section, pages) ->
           match acc, section with
           | {man1 = []; _}, "man1" -> {acc with man1 = pages}
           | {man2 = []; _}, "man2" -> {acc with man2 = pages}
           | {man3 = []; _}, "man3" -> {acc with man3 = pages}
           | {man4 = []; _}, "man4" -> {acc with man4 = pages}
           | {man5 = []; _}, "man5" -> {acc with man5 = pages}
           | {man6 = []; _}, "man6" -> {acc with man6 = pages}
           | {man7 = []; _}, "man7" -> {acc with man7 = pages}
           | {man8 = []; _}, "man8" -> {acc with man8 = pages}
           | _, ("man1"|"man2"|"man3"|"man4"|"man5"|"man6"|"man7"|"man8") ->
             invalid_arg @@
             Printf.sprintf
               "%s: multiple occurences of the same section."
               __FUNCTION__
           | _, _ ->
             invalid_arg @@
             Printf.sprintf
               "%s: Invalid manpage section %S."
               __FUNCTION__
               section)
        init
        l
    in
    Some mnpgs

exception Invalid_file of string

let invalid_file fmt =
  Printf.ksprintf (fun s -> raise (Invalid_file s)) fmt

let load filename =
  let file = (OpamFilename.to_string filename) in
  let json = Yojson.Safe.from_file file in
  match of_yojson json with
  | Ok t -> t
  | Error msg ->
    invalid_file "Could not parse installer config %s: %s" file msg

let save t filename =
  Yojson.Safe.to_file (OpamFilename.to_string filename) (to_yojson t)
