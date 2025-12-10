(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Compat

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
[@@deriving yojson {meta = true}]

type expanded_manpages = (string * string list) list

type plugin =
  { name : string
  ; app_name : string
  ; plugin_dir : string
  ; lib_dir : string
  ; dyn_deps : string list [@default []]
  }
[@@deriving yojson {meta = true}]

type plugin_dirs =
  { plugins_dir : string
  ; lib_dir : string
  }
[@@deriving yojson {meta = true}]

type vars = { install_path : string }

type ('manpages, 'env_val) t = {
    name : string;
    fullname : string ;
    version : string;
    exec_files : string list; [@default []]
    manpages : 'manpages option; [@default None]
    environment : (string * 'env_val) list; [@default []]
    unique_id : string;
    plugins : plugin list; [@default []]
    plugin_dirs : plugin_dirs option; [@default None]
    wix_manufacturer : string;
    wix_description : string option; [@default None]
    wix_tags : string list; [@default []]
    wix_icon_file : string option; [@default None]
    wix_dlg_bmp_file : string option; [@default None]
    wix_banner_bmp_file : string option; [@default None]
    wix_license_file : string option; [@default None]
    macos_symlink_dirs : string list; [@default []]
  }
[@@deriving yojson {meta = true}]

type user = (manpages, String_with_vars.t) t
[@@deriving yojson]

type internal = (expanded_manpages, string) t

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

let dir_in ~bundle_dir path =
  OpamFilename.Op.(bundle_dir / path)

let file_in ~bundle_dir path =
  OpamFilename.Op.(bundle_dir // path)

let can_exec perm =
  Int.equal (perm land 0o001) 0o001
  && Int.equal (perm land 0o010) 0o010
  && Int.equal (perm land 0o100) 0o100

let errors_list l =
  List.filter_map (function Ok _ -> None | Error msg -> Some msg) l

let collect_errors ~f l =
  List.map f l |> errors_list

let collect_error_opt ~f x =
  match x with
  | None -> []
  | Some x ->
    match f x with
    | Ok () -> []
    | Error e -> [e]

let guard cond fmt =
  if cond then Printf.ksprintf (fun _ -> Ok ()) fmt
  else errorf fmt

let check_dir ~field dir =
  guard (OpamFilename.exists_dir dir)
    "%s: directory %s does not exist"
    field (OpamFilename.Dir.to_string dir)

let check_file ~field file =
  guard (OpamFilename.exists file)
    "%s: file %s does not exist"
    field (OpamFilename.to_string file)

let check_exec ~bundle_dir rel_path =
  let open Letop.Result in
  let field = "exec_files" in
  let path = file_in ~bundle_dir rel_path in
  let path_str = OpamFilename.to_string path in
  let* () = check_file ~field:"exec_files" path in
  let stats = Unix.stat path_str in
  let perm = stats.st_perm in
  guard (can_exec perm)
    "%s: file %s does not have exec permissions"
    field path_str

let check_man_section ~bundle_dir (name, man_section) =
  let field = "manpages." ^ name in
  match man_section with
  | Man_dir d ->
    check_dir ~field (dir_in ~bundle_dir d)
    |> Result.map_error (fun msg -> [msg])
  | Man_files l ->
    let errs =
      collect_errors l ~f:(fun f -> check_file ~field (file_in ~bundle_dir f))
    in
    match errs with
    | [] -> Ok ()
    | _ -> Error errs

let check_plugin_dirs ~bundle_dir plugin_dirs =
  match plugin_dirs with
  | None -> []
  | Some {plugins_dir; lib_dir} ->
    errors_list
      [ check_dir ~field:"plugin_dirs.plugins_dir"
          (dir_in ~bundle_dir plugins_dir)
      ; check_dir ~field:"plugin_dirs.lib_dir" (dir_in ~bundle_dir lib_dir)
      ]

let check_plugin ~bundle_dir
    {app_name = _; name = _; plugin_dir; lib_dir; dyn_deps} =
  errors_list
    [ check_dir ~field:"plugins.plugin_dir" (dir_in ~bundle_dir plugin_dir)
    ; check_dir ~field:"plugins.lib_dir" (dir_in ~bundle_dir lib_dir)
    ]
  @ collect_errors dyn_deps
    ~f:(fun d -> check_dir ~field:"plugin.dyn_deps" (dir_in ~bundle_dir d))

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

let expand_environment ~vars env =
  let { install_path } = vars in
  let expanded, warnings =
    List.fold_left
      (fun (expanded, warnings) (var, value) ->
         let res = String_with_vars.subst ~install_path value in
         let e = (var, res.subst_string) in
         let w =
           List.map
             (Printf.sprintf "environment.%s: unknown var %s" var)
             res.unknown_vars
         in
         e::expanded, List.rev_append w warnings)
      ([], [])
      env
  in
  List.rev expanded, List.rev warnings

let check_and_expand ~bundle_dir ~vars user =
  let exec_errors =
    collect_errors ~f:(check_exec ~bundle_dir) user.exec_files
  in
  let manpages = manpages_to_list user.manpages in
  let manpages_errors =
    collect_errors ~f:(check_man_section ~bundle_dir) manpages
    |> List.concat
  in
  let wix_icon_error =
    collect_error_opt ~f:(check_file ~field:"wix_icon_file")
      (Option.map OpamFilename.of_string user.wix_icon_file)
  in
  let wix_dlg_bmp_error =
    collect_error_opt ~f:(check_file ~field:"wix_dlg_bmp_file")
      (Option.map OpamFilename.of_string user.wix_dlg_bmp_file)
  in
  let wix_banner_bmp_error =
    collect_error_opt ~f:(check_file ~field:"wix_banner_bmp_file")
      (Option.map OpamFilename.of_string user.wix_banner_bmp_file)
  in
  let wix_license_error =
    collect_error_opt ~f:(check_file ~field:"wix_license_file")
      (Option.map OpamFilename.of_string user.wix_license_file)
  in
  let macos_symlink_dirs_errors =
    collect_errors ~f:(check_dir ~field:"macos_symlink_dirs")
      (List.map
         (fun d -> OpamFilename.Op.(bundle_dir / d)) user.macos_symlink_dirs)
  in
  let plugin_errors = List.concat_map (check_plugin ~bundle_dir) user.plugins in
  let plugin_dirs_errors = check_plugin_dirs ~bundle_dir user.plugin_dirs in
  let all_errors =
    exec_errors @ manpages_errors @ wix_icon_error @ wix_dlg_bmp_error
    @ wix_banner_bmp_error @ wix_license_error @ macos_symlink_dirs_errors
    @ plugin_dirs_errors @ plugin_errors
  in
  let environment, warnings = expand_environment ~vars user.environment in
  let res =
    match all_errors with
    | [] ->
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
      Ok {user with manpages; environment}
    | _ ->
      Error (`Inconsistent_config all_errors)
  in
  res, warnings

let invalid_config ~file fmt =
  Printf.ksprintf (fun s -> `Invalid_config s)
    ("Could not parse installer config %s: " ^^ fmt)
    file

module String_set = Set.Make(String)

let keys = String_set.of_list Yojson_meta.keys
let manpages_keys = String_set.of_list Yojson_meta_manpages.keys
let plugin_keys = String_set.of_list Yojson_meta_plugin.keys
let plugin_dirs_keys = String_set.of_list Yojson_meta_plugin_dirs.keys

let first_invalid_key ~keys assoc_list =
  List.find_map
    (fun (key, _val) ->
       if String_set.mem key keys then None else Some key)
    assoc_list

let pretty_object_error ~file ~keys ?field json =
  match json with
  | `Assoc l ->
    (match first_invalid_key ~keys l with
     | None -> invalid_config ~file "please report upstream"
     | Some key ->
       let key = match field with None -> key | Some f -> f ^ "." ^ key in
       invalid_config ~file "invalid key %S" key)
  | _ ->
    let prefix =
      match field with
      | None -> ""
      | Some f -> f ^ " "
    in
    invalid_config ~file "%sshould be a JSON object" prefix

let pretty_plugin_error ~file json =
  match json with
  | `List l ->
    List.find_mapi
      (fun i elm ->
         match elm with
         | `Assoc l ->
           Option.map
             (fun key -> invalid_config ~file "invalid key plugins.[%d].%s" i key)
             (first_invalid_key ~keys:plugin_keys l)
         | _ ->
           Some (invalid_config ~file "plugins.[%d] should be a JSON object" i))
      l
  | _ ->
    Some (invalid_config ~file "plugins should be a JSON array")

(* Turn a derived of_yojson error message into a user friendly one when
   possible. *)
let pretty_error ~file ~msg json =
  match msg, json with
  | "Installer_config.t", _ -> pretty_object_error ~file ~keys json
  | "Installer_config.manpages", `Assoc l ->
    pretty_object_error ~file ~keys:manpages_keys ~field:"manpages"
      (List.assoc "manpages" l)
  | "Installer_config.plugin_dirs", `Assoc l ->
    pretty_object_error ~file ~keys:plugin_dirs_keys ~field:"plugin_dirs"
      (List.assoc "plugin_dirs" l)
  | "Installer_config.plugin", `Assoc l ->
    (match pretty_plugin_error ~file (List.assoc "plugins" l) with
     | None -> invalid_config ~file "please report upstream"
     | Some err -> err)
  | msg, _ ->
    let field_name =
      match String.split_on_char '.' msg with
      | ["Installer_config"; "t"; field_name] -> field_name
      | ["Installer_config"; subtype; field_name] -> subtype ^ "." ^ field_name
      | _ -> msg
    in
    invalid_config ~file "missing or invalid field %S" field_name

let load filename =
  let file = (OpamFilename.to_string filename) in
  let json = Yojson.Safe.from_file file in
  match user_of_yojson json with
  | Ok user_config -> Ok user_config
  | Error msg ->
    Error (pretty_error ~file ~msg json)

let save t filename =
  Yojson.Safe.to_file (OpamFilename.to_string filename) (user_to_yojson t)
