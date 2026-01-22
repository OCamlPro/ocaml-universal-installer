(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module StrSet = Set.Make (String)

type reason = MZSize | MZSig | PESize | PESig | PEOptSize | PEOptSig

exception Exit
exception InvalidHeader of reason

(* Size of various structures *)
let mz_header_size = 0x40
let pe_header_size = 0x18
let pe32_header_size = 0x60
let pe32_plus_header_size = 0x70
let section_header_size = 0x28
let import_descriptor_size = 0x14

(* Header signatures *)
let mz_magic = 0x4D5A (* "MZ" *)
let pe_magic = 0x50450000l (* "PE\0\0" *)
let pe32_magic = 0x0B01
let pe32_plus_magic = 0x0B02

(* MZ Header field offsets *)
let mz_lfanew = 0x3C

(* PE Header field offsets *)
let pe_number_of_sections = 0x06
let pe_size_of_optional_header = 0x14

(* PE32(+) Optional Header field offsets *)
let pe32_number_of_rva_and_sizes = 0x5C
let pe32_plus_number_of_rva_and_sizes = 0x6C

(* Data Directory field offsets *)
let dd_imports_rva = 0x08

(* Import Descriptor field offsets *)
let id_name = 0x0C

let read_string =
  let buf = Buffer.create 64 in
  fun ic ->
  let rec aux () =
    match input_char ic with
    | '\000' -> Buffer.contents buf
    | c ->
        Buffer.add_char buf c;
        aux ()
  in
  Buffer.reset buf;
  aux ()

let rva_to_address sect_hdr rva =
  let sh_opt =
    List.find_opt (fun (vs, va, _ds, _da) ->
        rva >= va && rva < va + vs
      ) sect_hdr
  in
  match sh_opt with
  | Some (_vs, va, _ds, da) ->
      da + (rva - va)
  | None ->
      0

let get_dlls_ic ic =

  let mz_header = Bytes.create mz_header_size in
  begin
    try really_input ic mz_header 0 mz_header_size
    with End_of_file -> raise (InvalidHeader MZSize)
  end;

  let mz_sig = Bytes.get_uint16_be mz_header 0 in
  if mz_sig <> mz_magic then
    raise (InvalidHeader MZSig);

  let pe_address = Bytes.get_int32_le mz_header mz_lfanew |> Int32.to_int in

  seek_in ic pe_address;
  let pe_header = Bytes.create pe_header_size in
  begin
    try really_input ic pe_header 0 pe_header_size
    with End_of_file -> raise (InvalidHeader PESize)
  end;

  let pe_sig = Bytes.get_int32_be pe_header 0 in
  if pe_sig <> pe_magic then
    raise (InvalidHeader PESig);

  let nb_sections = Bytes.get_uint16_le pe_header pe_number_of_sections in
  let size_opt_hdr = Bytes.get_uint16_le pe_header pe_size_of_optional_header in

  if size_opt_hdr = 0 then
    raise Exit;

  seek_in ic (pe_address + pe_header_size);
  let pe_opt_header = Bytes.create size_opt_hdr in
  begin
    try really_input ic pe_opt_header 0 size_opt_hdr
    with End_of_file -> raise (InvalidHeader PEOptSize)
  end;

  let pe32_sig = Bytes.get_uint16_be pe_opt_header 0 in
  let nb_rva_sizes_offset, data_dir_offset =
    if pe32_sig = pe32_magic then
      pe32_number_of_rva_and_sizes, pe32_header_size
    else if pe32_sig = pe32_plus_magic then
      pe32_plus_number_of_rva_and_sizes, pe32_plus_header_size
    else
      raise (InvalidHeader PEOptSig);
  in

  let nb_rva_sizes =
    Bytes.get_int32_le pe_opt_header nb_rva_sizes_offset |> Int32.to_int in

  if nb_rva_sizes < 2 then
    raise Exit;

  let imports_rva =
    Bytes.get_int32_le pe_opt_header (data_dir_offset + dd_imports_rva)
    |> Int32.to_int in

  seek_in ic (pe_address + pe_header_size + size_opt_hdr);
  let sh = Bytes.create section_header_size in
  let rec aux i sect_hdrs =
    if i >= nb_sections then
      List.rev sect_hdrs
    else
      begin
        really_input ic sh 0 section_header_size;
        let virt_size = Bytes.get_int32_le sh 8 |> Int32.to_int in
        let virt_address = Bytes.get_int32_le sh 12 |> Int32.to_int in
        let data_size = Bytes.get_int32_le sh 16 |> Int32.to_int in
        let data_address = Bytes.get_int32_le sh 20 |> Int32.to_int in
        let sect_hdrs =
          (virt_size, virt_address, data_size, data_address) :: sect_hdrs in
        aux (i + 1) sect_hdrs
      end
  in
  let sect_hdrs = aux 0 [] in

  let imports_address = rva_to_address sect_hdrs imports_rva in
  let id = Bytes.create import_descriptor_size in
  let rec aux i names =
    seek_in ic (imports_address + i * import_descriptor_size);
    really_input ic id 0 import_descriptor_size;
    let name_rva = Bytes.get_int32_le id id_name |> Int32.to_int in
    if name_rva = 0 then
      names
    else
      let name_address = rva_to_address sect_hdrs name_rva in
      seek_in ic name_address;
      (* Note: the name is encoded using the current
         Windows ANSI encoding, not UTF-8 *)
      let name = read_string ic in
      aux (i + 1) (name :: names)
  in
  let names = aux 0 [] in
  names

let get_dlls_t binary =
  let ic = open_in_bin binary in
  let dlls =
    try get_dlls_ic ic
    with
    | Exit | InvalidHeader _ -> []
    | e -> close_in ic; raise e
  in
  close_in ic;
  dlls

external get_windows_directory : unit -> string = "ml_get_windows_directory"

let is_system32 =
  (* Note: guaranteed to end with '\' *)
  let win_dir = get_windows_directory () in
  fun path ->
    let prefix =
      try String.sub path 0 (String.length win_dir)
      with _ -> ""
    in
    if prefix <> win_dir then false
    else
      let suffix =
        try String.sub path (String.length win_dir)
              (String.length path - String.length win_dir)
        with _ -> ""
      in
      match String.split_on_char '\\' suffix with
      | directory :: _ ->
          String.lowercase_ascii directory = "system32"
          || String.lowercase_ascii directory = "syswow64"
      | _ -> false

(* Note: string is encoded using the current Windows ANSI encoding, not UTF-8 *)
external resolve_dll : string -> string option = "ml_resolve_dll"

let get_dlls binary =
  let rec aux dlls binary =
    let binary_dlls = get_dlls_t binary in
    let new_dlls =
      List.filter_map (fun dll ->
          match resolve_dll dll with
          | None -> None (* Maybe should warn ? *)
          | Some (dll) ->
              if is_system32 dll then None
              else if StrSet.mem dll dlls then None
              else Some (dll)
        ) binary_dlls
    in
    let dlls =
      List.fold_left (fun dlls dll ->
          StrSet.add dll dlls
        ) dlls new_dlls
    in
    List.fold_left aux dlls new_dlls
  in
  let dlls = aux StrSet.empty (OpamFilename.to_string binary) in
  StrSet.fold (fun dll dlls ->
      OpamFilename.of_string (System.normalize_path dll) :: dlls
    ) dlls [] |> List.rev
