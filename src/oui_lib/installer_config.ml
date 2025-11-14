(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type man_section =
  | Man_dir of string
  | Man_files of string list

let man_section_to_yojson = function
  | Man_dir s -> `String s
  | Man_files l ->
    `List (List.map (fun s -> `String s) l)

let man_section_of_yojson : Yojson.Safe.t -> (man_section, string) result =
  function
  | `String s -> Ok (Man_dir s)
  | `List (_::_) as json ->
    let open Letop.Result in
    let* files = [%of_yojson: string list] json in
    Ok (Man_files files)
  | _ ->
    Error
      "Invalid man_section, should be a JSON string or a non empty array of \
       strings."

type manpages =
  { man1 : man_section [@default Man_files []]
  ; man2 : man_section [@default Man_files []]
  ; man3 : man_section [@default Man_files []]
  ; man4 : man_section [@default Man_files []]
  ; man5 : man_section [@default Man_files []]
  ; man6 : man_section [@default Man_files []]
  ; man7 : man_section [@default Man_files []]
  ; man8 : man_section [@default Man_files []]
  }
[@@deriving yojson]

type expanded_manpages = (string * string list) list

type 'manpages t = {
    name : string;
    fullname : string ;
    version : string;
    description : string;
    manufacturer : string;
    exec_files : string list;
    manpages : 'manpages option; [@default None]
    environment : (string * string) list; [@default []]
    wix_tags : string list; [@default []]
    wix_icon_file : string option; [@default None]
    wix_dlg_bmp_file : string option; [@default None]
    wix_banner_bmp_file : string option; [@default None]
    wix_license_file : string option; [@default None]
    macos_bundle_id : string option; [@default None]
    macos_symlink_dirs : string list; [@default []]
  }
[@@deriving yojson]

type user = manpages t
[@@deriving yojson]

type internal = expanded_manpages t

let manpages_to_list mnpgs_opt =
  match mnpgs_opt with
  | None -> []
  | Some mnpgs ->
    [ ("man1", mnpgs.man1)
    ; ("man2", mnpgs.man2)
    ; ("man3", mnpgs.man3)
    ; ("man4", mnpgs.man4)
    ; ("man5", mnpgs.man5)
    ; ("man6", mnpgs.man6)
    ; ("man7", mnpgs.man7)
    ; ("man8", mnpgs.man8)
    ]
    |> List.filter (function (_, Man_files []) -> false | _ -> true)

let manpages_of_expanded l =
  let nil = Man_files [] in
  let init =
    { man1 = nil; man2 = nil; man3 = nil; man4 = nil; man5 = nil; man6 = nil
    ; man7 = nil; man8 = nil }
  in
  List.fold_left
    (fun acc (section, pages) ->
       match acc, section with
       | {man1 = Man_files []; _}, "man1" -> {acc with man1 = Man_files pages}
       | {man2 = Man_files []; _}, "man2" -> {acc with man2 = Man_files pages}
       | {man3 = Man_files []; _}, "man3" -> {acc with man3 = Man_files pages}
       | {man4 = Man_files []; _}, "man4" -> {acc with man4 = Man_files pages}
       | {man5 = Man_files []; _}, "man5" -> {acc with man5 = Man_files pages}
       | {man6 = Man_files []; _}, "man6" -> {acc with man6 = Man_files pages}
       | {man7 = Man_files []; _}, "man7" -> {acc with man7 = Man_files pages}
       | {man8 = Man_files []; _}, "man8" -> {acc with man8 = Man_files pages}
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

let errorf fmt =
  Printf.ksprintf (fun s -> Error s) fmt

let can_exec perm =
  Int.equal (perm land 0o001) 0o001
  && Int.equal (perm land 0o010) 0o010
  && Int.equal (perm land 0o100) 0o100

let collect_errors ~f l =
  List.map f l
  |> List.filter_map (function Ok _ -> None | Error msg -> Some msg)

let guard cond fmt =
  if cond then Printf.ksprintf (fun _ -> Ok ()) fmt
  else errorf fmt

let check_exec ~bundle_dir rel_path =
  let open Letop.Result in
  let path = OpamFilename.Op.(bundle_dir // rel_path) in
  let path_str = OpamFilename.to_string path in
  let* () =
    guard (OpamFilename.exists path)
      "listed executable %s does not exist"
      path_str
  in
  let stats = Unix.stat path_str in
  let perm = stats.st_perm in
  guard (can_exec perm)
    "listed executable %s does not have exec permissions"
    path_str

let check_man_section ~bundle_dir man_section =
  match man_section with
  | name, Man_dir d ->
    let dir = OpamFilename.Op.(bundle_dir / d) in
    guard (OpamFilename.exists_dir dir)
      "listed %s directory %s does not exist"
      name (OpamFilename.Dir.to_string dir)
    |> Result.map_error (fun msg -> [msg])
  | name, Man_files l ->
    let errs =
      collect_errors l
        ~f:(fun f ->
            let page = OpamFilename.Op.(bundle_dir // f) in
            guard (OpamFilename.exists page)
              "listed %s manpage %s does not exist"
              name (OpamFilename.to_string page))
    in
    match errs with
    | [] -> Ok ()
    | _ -> Error errs

let expand_man_section ~bundle_dir man_section =
  match man_section with
  | Man_files l -> l
  | Man_dir d ->
    let dir = OpamFilename.Op.(bundle_dir / d) in
    let files = OpamFilename.files dir in
    ListLabels.map files
      ~f:(fun file ->
          let base = OpamFilename.(Base.to_string (basename file)) in
          Filename.concat d base)

let check_and_expand ~bundle_dir user =
  let exec_errors =
    collect_errors ~f:(check_exec ~bundle_dir) user.exec_files
  in
  let manpages = manpages_to_list user.manpages in
  let manpages_errors =
    collect_errors ~f:(check_man_section ~bundle_dir) manpages
    |> List.concat
  in
  match exec_errors, manpages_errors with
  | [], [] ->
    let manpages =
      ListLabels.filter_map manpages
        ~f:(fun (section_name, man_section) ->
            let expanded = expand_man_section ~bundle_dir man_section in
            match expanded with
            | [] -> None
            | _ -> Some (section_name, expanded))
      |> function
      | [] -> None
      | l -> Some l
    in
    Ok {user with manpages}
  | _ ->
    Error (`Inconsistent_config (exec_errors @ manpages_errors))

let invalid_config fmt =
  Printf.ksprintf (fun s -> `Invalid_config s) fmt

let load filename =
  let file = (OpamFilename.to_string filename) in
  let json = Yojson.Safe.from_file file in
  Result.map_error
    (fun msg ->
       invalid_config "Could not parse installer config %s: %s" file msg)
    (user_of_yojson json)

let save t filename =
  Yojson.Safe.to_file (OpamFilename.to_string filename) (user_to_yojson t)
