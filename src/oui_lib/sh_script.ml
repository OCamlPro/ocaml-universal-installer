(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type find_type =
  | Files
  | Dirs

type condition =
  | Exists of string
  | Dir_exists of string
  | Link_exists of string
  | File_exists of string
  | Is_not_root
  | And of condition * condition
  | Not of condition

let (&&) c1 c2 = And (c1, c2)

type command =
  | Continue
  | Return of int
  | Exit of int
  | Echo of string
  | Print_err of string
  | Eval of string
  | Assign of {var: string; value: string}
  | Mkdir of {permissions: int option; dirs: string list}
  | Chmod of {permissions: int; files: string list}
  | Cp of {src: string; dst: string}
  | Rm of {rec_: bool; files : string list}
  | Symlink of {target: string; link: string}
  | Set_permissions_in of
      {on: find_type; permissions: int; starting_point: string}
  | Copy_all_in of {src: string; dst: string; except: string}
  | If of {condition : condition; then_ : command list; else_: command list}
  | Prompt of {question: string; varname: string}
  | Case of {varname: string; cases: case list}
  | Write_file of {file: string; lines : string list}
  | Read_file of {file: string; line_var: string; process_line: command list}
  | Def_fun of {name: string; body : command list}
  | Call_fun of {name: string; args: string list}
and case =
  { pattern : string
  ; commands : command list
  }

type t = command list

let continue = Continue
let return i = Return i
let exit i = Exit i
let echof fmt = Format.kasprintf (fun s -> Echo s) fmt
let print_errf fmt = Format.kasprintf (fun s -> Print_err s) fmt
let eval s = Eval s
let assign ~var ~value = Assign {var; value}
let mkdir ?permissions dirs = Mkdir {permissions; dirs}
let chmod permissions files = Chmod {permissions; files}
let cp ~src ~dst = Cp {src; dst}
let rm files = Rm {rec_ = false; files}
let rm_rf files = Rm {rec_ = true; files}
let symlink ~target ~link = Symlink {target; link}
let if_ condition then_ ?(else_=[]) () = If {condition; then_; else_}
let prompt ~question ~varname = Prompt {question; varname}
let case varname cases = Case {varname; cases}
let write_file file lines = Write_file {file; lines}
let def_fun name body = Def_fun {name; body}
let call_fun name args = Call_fun {name; args}

let read_file ~line_var file process_line =
  Read_file {file; line_var; process_line}

let set_permissions_in ~on ~permissions starting_point =
  Set_permissions_in {on; permissions; starting_point}

let copy_all_in ~src ~dst ~except = Copy_all_in {src; dst; except}

let pp_sh_find_type fmtr ft =
  match ft with
  | Files -> Format.fprintf fmtr "f"
  | Dirs -> Format.fprintf fmtr "d"

let rec pp_sh_condition fmtr condition =
  match condition with
  | Exists s -> Format.fprintf fmtr "[ -e %S ]" s
  | Dir_exists s -> Format.fprintf fmtr "[ -d %S ]" s
  | Link_exists s -> Format.fprintf fmtr "[ -L %S ]" s
  | File_exists s -> Format.fprintf fmtr "[ -f %S ]" s
  | Is_not_root -> Format.fprintf fmtr {|[ "$(id -u)" -ne 0 ]|}
  | And (c1, c2) ->
    Format.fprintf fmtr "%a && %a"
      pp_sh_condition c1
      pp_sh_condition c2
  | Not (And _ as c) -> Format.fprintf fmtr "! (%a)" pp_sh_condition c
  | Not c -> Format.fprintf fmtr "! %a" pp_sh_condition c

let rec pp_sh_command ~indent fmtr command =
  let indent_str = String.make indent ' ' in
  let fpf fmt = Format.fprintf fmtr ("%s" ^^ fmt ^^ "\n") indent_str in
  let pp_files = Fmt.(list ~sep:(const string " ") (using (fun x -> "\""^x^"\"") string)) in
  match command with
  | Continue -> fpf "continue"
  | Return i -> fpf "return %d" i
  | Exit i -> fpf "exit %d" i
  | Echo s -> fpf "echo %S" s
  | Print_err s -> fpf "printf '%%s\\n' %S >&2" s
  | Eval s -> fpf "eval \"%s\"" s
  | Assign {var; value} -> fpf "%s=%S" var value
  | Mkdir {permissions = None; dirs} -> fpf "mkdir -p %a" pp_files dirs
  | Mkdir {permissions = Some perm; dirs} ->
    fpf "mkdir -p -m %i %a" perm pp_files dirs
  | Chmod {permissions; files} -> fpf "chmod %i %a" permissions pp_files files
  | Cp {src; dst} -> fpf "cp %s %s" src dst
  | Rm {rec_ = true; files} -> fpf "rm -rf %a" pp_files files
  | Rm {rec_ = false; files} -> fpf "rm -f %a" pp_files files
  | Symlink {target; link} -> fpf "ln -s %s %s" target link
  | Set_permissions_in {on; permissions; starting_point} ->
    fpf "find %s -type %a -exec chmod %i {} +"
      starting_point
      pp_sh_find_type on
      permissions
  | Copy_all_in {src; dst; except} ->
    fpf
      "find %s -mindepth 1 -maxdepth 1 ! -name '%s' -exec cp -rp {} %s \\;"
      src except dst
  | If {condition; then_; else_} ->
    fpf "if %a; then" pp_sh_condition condition;
    List.iter (pp_sh_command ~indent:(indent + 2) fmtr) then_;
    (match else_ with
     | [] -> ()
     | _ ->
       fpf "else";
       List.iter (pp_sh_command ~indent:(indent + 2) fmtr) else_);
    fpf "fi"
  | Prompt {question; varname} ->
    fpf {|printf "%s "|} question;
    fpf {|read %s|} varname
  | Case {varname; cases} ->
    fpf {|case "$%s" in|} varname;
    List.iter (pp_sh_case ~indent:(indent + 2) fmtr) cases;
    fpf "esac"
  | Write_file {file; lines} ->
    fpf "{";
    List.iter (fpf "  printf '%%s\\n' \"%s\"") lines;
    fpf "} > \"%s\"" file
  | Read_file {file; line_var; process_line} ->
    fpf "while IFS= read -r %s || [ -n \"$%s\" ]; do" line_var line_var;
    List.iter (pp_sh_command ~indent:(indent + 2) fmtr) process_line;
    fpf "done < \"%s\"" file
  | Def_fun {name; body} ->
    fpf "%s() {" name;
    List.iter (pp_sh_command ~indent:(indent + 2) fmtr) body;
    fpf "}"
  | Call_fun {name; args = []} ->
    fpf "%s" name
  | Call_fun {name; args} ->
    fpf "%s %s" name (String.concat " " args)

and pp_sh_case ~indent fmtr {pattern; commands} =
  let indent_str = String.make indent ' ' in
  let fpf fmt = Format.fprintf fmtr ("%s" ^^ fmt ^^ "\n") indent_str in
  match commands with
  | [] -> fpf "%s) ;;" pattern
  | _ ->
    fpf "%s)" pattern;
    List.iter (pp_sh_command ~indent:(indent + 2) fmtr) commands;
    fpf ";;"


let pp_sh fmtr t =
  Format.fprintf fmtr "#!/usr/bin/env sh\n";
  Format.fprintf fmtr "set -e\n";
  List.iter (pp_sh_command ~indent:0 fmtr) t

let save t file =
  let file = OpamFilename.to_string file in
  let out_ch = open_out file in
  let formatter = Format.formatter_of_out_channel out_ch in
  pp_sh formatter t;
  close_out out_ch
