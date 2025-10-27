(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type wix = {
  wix_files : string list;
  wix_exts : string list;
  wix_out : string
}

type makeself = {
  archive_dir : OpamFilename.Dir.t;
  installer : OpamFilename.t;
  description : string;
  startup_script : string
}

type cygpath_out = [ `Win | `WinAbs | `Cyg | `CygAbs ]

type install_name_tool_args = {
  change_from : string;
  change_to : string;
  binary : OpamFilename.t;
}

type codesign_args = {
  binary : OpamFilename.t;
  identity : string; (* "-" for ad-hoc, or certificate name *)
  force : bool;
  timestamp : bool;
  entitlements : string option;
}

type codesign_verify_args = {
  binary : OpamFilename.t;
  verbose : bool;
}

type _ command =
  | Which : string command
  | Cygcheck : string command
  | Ldd : string command
  | Otool : string command
  | Cygpath : (cygpath_out * string) command
  | Wix : wix command
  | Makeself : makeself command
  | Chmod : (int * OpamFilename.t) command
  | InstallNameTool : install_name_tool_args command
  | Codesign : codesign_args command
  | CodesignVerify : codesign_verify_args command

exception System_error of string

let call_inner : type a. a command -> a -> string * string list =
  fun command args -> match command, args with
  | Which, (path : string) ->
    "which", [ path ]
  | Cygcheck, path ->
    "cygcheck", [ path ]
  | Ldd, path ->
    "ldd", [ path ]
  | Otool, path ->
    "otool", [ "-L"; path ]
  | Chmod, (perm, file) ->
    "chmod", [ string_of_int perm; OpamFilename.to_string file ]
  | Cygpath, (out, path) ->
    let opts = match out with
      | `Win -> "-w"
      | `WinAbs -> "-wa"
      | `Cyg -> "-u"
      | `CygAbs -> "-ua"
    in
    "cygpath", [ opts; path ]
  | Wix, { wix_files; wix_exts; wix_out } ->
    let wix = "wix.exe" in
    let args = "build" ::
      List.flatten (List.map (fun e -> ["-ext"; e]) wix_exts)
      @ wix_files @ ["-o"; wix_out]
    in
    wix, args
  | Makeself, { archive_dir; installer; description; startup_script } ->
    let makeself = "makeself.sh" in
    let args =
      [ OpamFilename.Dir.to_string archive_dir
      ; OpamFilename.to_string installer
      ; Printf.sprintf "%S" description
      ; startup_script
      ]
    in
    makeself, args
  | InstallNameTool, { change_from; change_to; binary } ->
    let path = OpamFilename.to_string binary in
    "install_name_tool", [ "-change"; change_from; change_to; path ]
  | Codesign, { binary; identity; force; timestamp; entitlements } ->
    let path = OpamFilename.to_string binary in
    let args = [ "-s"; identity ] in
    let args = if force then args @ [ "-f" ] else args in
    let args = if timestamp then args @ [ "--timestamp" ] else args in
    let args = match entitlements with
      | Some ent_path -> args @ [ "--entitlements"; ent_path ]
      | None -> args
    in
    "codesign", args @ [ path ]
  | CodesignVerify, { binary; verbose } ->
    let path = OpamFilename.to_string binary in
    let args = [ "--verify" ] @ (if verbose then [ "--verbose" ] else []) @ [ path ] in
    "codesign", args

let gen_command_tmp_dir cmd =
  Printf.sprintf "%s-%06x" (Filename.basename cmd) (Random.int 0xFFFFFF)

let call : type a. a command -> a -> string list =
  fun command arguments ->
    let cmd, args = call_inner command arguments in
    let name = gen_command_tmp_dir cmd in
    let result = OpamProcess.run @@ OpamSystem.make_command ~name cmd args in
    let out = if OpamProcess.is_failure result then
        raise @@ System_error (Format.sprintf "%s" (OpamProcess.string_of_result result))
      else
        result.OpamProcess.r_stdout
    in
    OpamProcess.cleanup result;
    out

let call_unit : type a. a command -> a -> unit =
  fun command arguments ->
    let cmd, args = call_inner command arguments in
    let name = gen_command_tmp_dir cmd in
    let result = OpamProcess.run @@ OpamSystem.make_command ~name cmd args in
    (if OpamProcess.is_failure result then
      raise @@ System_error (Format.sprintf "%s" (OpamProcess.string_of_result result)));
    OpamProcess.cleanup result

let call_list : type a. (a command * a) list -> unit =
  fun commands ->
    let cmds = List.map (fun (cmd,args) ->
      let cmd, args = call_inner cmd args in
      let name = gen_command_tmp_dir cmd in
      OpamSystem.make_command ~name cmd args) commands
    in
    match OpamProcess.Job.(run @@ of_list cmds) with
    | Some (_,result) -> raise @@ System_error
      (Format.sprintf "%s" (OpamProcess.string_of_result result))
    | _ -> ()

let cyg_win_path out path =
  match call Cygpath (out,path) with
  | line :: _ -> String.trim line
  | _ -> raise @@ System_error "cygpath raised an error. \
    You probably chose a file with invalid format as your binary."

let normalize_path path =
  match Sys.os_type with
  | "Unix" -> path
  | "Win32" -> cyg_win_path `WinAbs path
  | "Cygwin" -> cyg_win_path `CygAbs path
  | _ ->
    let msg = Printf.sprintf "Unsupported os type %s" Sys.os_type in
    raise (System_error msg)

(* NOTE: under mingw OpamFilename.to_string returns false path "C:\home\..". For instant, try to use hackish method to fix this *)
let path_dir_str path =
  if Sys.cygwin
  then OpamFilename.Dir.to_string path
  else
    let path = OpamFilename.Dir.to_string path in
    String.split_on_char ':' path
    |> List.tl |> String.concat ":" |> String.split_on_char '\\'
    |> String.concat "/"

let path_str path =
  if Sys.win32 then
    let path = OpamFilename.to_string path in
    String.split_on_char ':' path
    |> List.tl |> String.concat ":" |> String.split_on_char '\\'
    |> String.concat "/"
  else
    OpamFilename.to_string path

open OpamTypes

module type FILE_INTF = sig
  type t
  val name : string
  val to_string : t -> string
  val of_string : string -> t
  val (/) : dirname -> string -> t
  val copy : src:t -> dst:t -> unit
  val exists : t -> bool
  val basename : t -> basename
end

module DIR_IMPL : FILE_INTF
  with type t = OpamFilename.Dir.t = struct
  include OpamFilename.Dir
  let name = "directory"
  let (/) = OpamFilename.Op.(/)
  let copy = OpamFilename.copy_dir
  let exists = OpamFilename.exists_dir
  let basename = OpamFilename.basename_dir
end

module FILE_IMPL : FILE_INTF
  with type t = OpamFilename.t = struct
  include OpamFilename
  let name = "file"
  let (/) = OpamFilename.Op.(//)
  let copy = OpamFilename.copy
  let exists = OpamFilename.exists
  let basename = OpamFilename.basename
end

let resolve_path_aux env path =
  let expanded_path = OpamFilter.expand_string env path in
  if not @@ Filename.is_relative expanded_path
  then expanded_path
  else begin
    OpamConsole.warning
      "Specified in config path %s is relative. Searching in current directory..."
        (OpamConsole.colorise `bold path);
    Filename.concat (Sys.getcwd ()) expanded_path
  end

let resolve_path (type a) env
  (module F : FILE_INTF with type t = a) path =
  F.of_string @@ resolve_path_aux env path

let resolve_file_path env path =
  resolve_path env (module FILE_IMPL) path
