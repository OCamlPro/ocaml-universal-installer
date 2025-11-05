(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let parse_true_so_line l =
  match String.trim l |> String.split_on_char ' ' with
  | lib_name :: "=>" :: lib_path :: _ ->
    Some (lib_name, OpamFilename.of_string lib_path)
  | _ -> None

let should_embed (name, _) =
  (* Those are hardcoded for now but we should ultimately make this
     configurable by the user. *)
  match String.split_on_char '.' name with
  | "libc"::_
  | "libm"::_ -> false
  | _ -> true

let elf_magic_number = "\x7FELF"

let is_elf file =
  let ic = open_in_bin file in
  let is_elf =
    try
      let header = really_input_string ic 4 in
      String.equal header elf_magic_number
    with End_of_file ->
      false
  in
  close_in ic;
  is_elf

let get_sos binary =
  let path = OpamFilename.to_string binary in
  if is_elf path then
    let output = System.call Ldd path in
    let shared_libs = List.filter_map parse_true_so_line output in
    let to_embed = List.filter should_embed shared_libs in
    List.map snd to_embed
  else []
