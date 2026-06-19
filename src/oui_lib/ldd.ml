(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
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
     configurable by the user.
     We exclude the dynamic linker (all ld* names) and the glibc along
     with libs that are co-developed with it and rely on GLIBC_PRIVATE symbols.
  *)
  match String.split_on_char '.' name with
  | "ld-linux"::_
  | "ld-linux-x86-64"::_
  | "ld-linux-aarch64"::_
  | "ld-linux-armhf"::_
  | "ld-linux-arm"::_
  | "ld64"::_
  | "ld-linux-riscv64-lp64d"::_
  | "ld-musl-x86_64"::_
  | "ld-musl-aarch64"::_
  | "libc"::_
  | "libm"::_
  | "librt"::_
  | "libresolv"::_
  | "libutil"::_
  | "libpthread"::_
  | "libdl"::_ -> false
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
