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

type numerical_op =
  | Gt
  | Lt
  | Eq

type string_op =
 | Not_empty of string
 | Equal of string * string

type condition =
  | Exists of string
  | Dir_exists of string
  | Link_exists of string
  | File_exists of string
  | Is_not_root
  | Writable_as_user of string
  | And of condition * condition
  | Not of condition
  | Num_op of string * numerical_op * int
  | Str_op of string_op

val (&&) : condition -> condition -> condition

type command =
  | Continue
  | Return of int
  | Exit of int
  | Echo of string
  | Print_err of string
  | Eval of string
  | Eval_inplace of command
  | Shift
  | Assign of {var: string; value: string}
  | Assign_eval of {var: string; command: command}
  | Dirname of string
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
  | While of {condition: condition; while_: command list}
  | Write_file of {file: string; lines : string list; append:bool}
  | Read_file of {file: string; line_var: string; process_line: command list}
  | Def_fun of {name: string; body : command list}
  | Call_fun of {name: string; args: string list}
and case =
  { pattern : string
  ; commands : command list
  }

type t = command list

(** Prints the given script using shell syntax to the given formatter.
  If [version] is set to true, a comment containing oui version and commit hash
  is printed as a comment in scripts. *)
val pp_sh : version:bool -> Format.formatter -> t -> unit

val continue : command

(** [return i] is ["return i"] *)
val return : int -> command

(** [exit i] is ["exit i"] *)
val exit : int -> command

(** [eval s] is ["eval \"s\""] *)
val eval : string -> command

(** [shift] is [shift] *)
val shift : command

(** [assign ~var:"VAR" ~value:"value"] is ["VAR=\"value\""] *)
val assign : var: string -> value: string -> command

(** [assign_eval var command] is ["VAR=\"$(command)\""] *)
val assign_eval : string -> command -> command

(** [dirname path] is ["dirname \"path\""] *)
val dirname : string -> command

(** [echo fmt args] is ["echo \"s\""] where [s] is the expanded format
    string. *)
val echof : ('a, Format.formatter, unit, command) format4 -> 'a

(** [print_errf fmt args] is ["printf '%%s\\n' \"s\" >&2"] where
    [s] is the expanded format string. *)
val print_errf : ('a, Format.formatter, unit, command) format4 -> 'a

(** [mkdir f1::f2::_] is ["mkdir -p f1 f2 ..."] *)
val mkdir : ?permissions: int -> string list -> command

(** [chmod i f1::f2::_] is ["chmod i f1 f2 ..."] *)
val chmod : int -> string list -> command

(** [cp ~src ~dst] is ["cp src dst"] *)
val cp : src: string -> dst: string -> command

(** [rm f1::f2::_] is ["rm -f f1 f2 ..."] *)
val rm : string list -> command

(** [rm_rf f1::f2::_] is ["rm -rf f1 f2 ..."] *)
val rm_rf : string list -> command

(** [symlink ~target ~link] is ["ln -s target link"] *)
val symlink : target: string -> link: string -> command

(** [if_ condition commands] is
    ["if [ condition ]; then
      commands
    fi"] *)
val if_ :
  condition ->
  command list ->
  ?else_: command list ->
  unit ->
  command

(** [set_permissions_in starting_point ~on ~permissions] is
    ["find starting_point -type find_type -exec chmod permissions {} +"] *)
val set_permissions_in : on: find_type -> permissions: int -> string -> command

val copy_all_in : src: string -> dst: string -> except: string -> command

(** [promt ~question ~varname] is ["printf \"question \""] followed by
    [read varname]. *)
val prompt : question: string -> varname: string -> command

val case : string -> case list -> command

(** [while condition commands] is
    ["while [ condition ]; do
      commands
    done"] *)
val while_ : condition -> command list -> command

(** [write_file file lines] is
    ["{ printf \"line1\n\"; printf \"line2\n\"; ... } > file"].
    If append is set to true (default is false), append to file
    using ">>".*)
val write_file : ?append:bool -> string -> string list -> command

(** [read_file ~line_var file process_line] is
    ["while IFS= read -r line_var || [ -n $line_var]; do \
      process_line \
      done < file"]
*)
val read_file : line_var: string -> string -> command list -> command

(** [def_fun name body] is ["name() { body }"] *)
val def_fun : string -> command list -> command

(** [call_fun name [arg1; arg2] is ["name arg1 arg2"] *)
val call_fun : string -> string list -> command

val save : t -> OpamFilename.t -> unit
