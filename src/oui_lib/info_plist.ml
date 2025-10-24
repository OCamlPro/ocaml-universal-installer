(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type value =
  | String of string
  | Bool of bool
  | Dict of (string * value) list
  | Array of value list

type t = (string * value) list

let escape_xml s =
  let buffer = Buffer.create (String.length s) in
  String.iter (function
      | '&' -> Buffer.add_string buffer "&amp;"
      | '<' -> Buffer.add_string buffer "&lt;"
      | '>' -> Buffer.add_string buffer "&gt;"
      | '"' -> Buffer.add_string buffer "&quot;"
      | '\'' -> Buffer.add_string buffer "&apos;"
      | c -> Buffer.add_char buffer c
    ) s;
  Buffer.contents buffer

let rec value_to_xml_element indent = function
  | String s ->
    Printf.sprintf "%s<string>%s</string>" indent (escape_xml s)
  | Bool true ->
    Printf.sprintf "%s<true/>" indent
  | Bool false ->
    Printf.sprintf "%s<false/>" indent
  | Dict entries ->
    let next_indent = indent ^ "    " in
    let dict_content =
      entries
      |> List.map (fun (key, value) ->
          Printf.sprintf "%s<key>%s</key>\n%s"
            next_indent
            (escape_xml key)
            (value_to_xml_element next_indent value)
        )
      |> String.concat "\n"
    in
    if entries = [] then
      Printf.sprintf "%s<dict/>" indent
    else
      Printf.sprintf "%s<dict>\n%s\n%s</dict>"
        indent
        dict_content
        indent
  | Array items ->
    let next_indent = indent ^ "    " in
    let array_content =
      items
      |> List.map (value_to_xml_element next_indent)
      |> String.concat "\n"
    in
    if items = [] then
      Printf.sprintf "%s<array/>" indent
    else
      Printf.sprintf "%s<array>\n%s\n%s</array>"
        indent
        array_content
        indent

let to_xml (plist : t) =
  let header =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ^
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" " ^
    "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" ^
    "<plist version=\"1.0\">"
  in
  let content = value_to_xml_element "" (Dict plist) in
  let footer = "</plist>" in
  String.concat "\n" [header; content; footer]

let make entries = entries

let add_entry key value plist =
  let rec replace acc = function
    | [] -> List.rev ((key, value) :: acc)
    | (k, _) :: rest when String.equal k key ->
      List.rev_append acc ((key, value) :: rest)
    | entry :: rest ->
      replace (entry :: acc) rest
  in
  replace [] plist

let make_info_plist ~bundle_id ~executable ~name ~display_name ~version =
  [ ("CFBundleExecutable", String executable)
  ; ("CFBundleIdentifier", String bundle_id)
  ; ("CFBundleName", String name)
  ; ("CFBundleDisplayName", String display_name)
  ; ("CFBundleVersion", String version)
  ; ("CFBundleShortVersionString", String version)
  ; ("CFBundlePackageType", String "APPL")
  ; ("NSHighResolutionCapable", Bool true)
  ]

let save plist file =
  let xml = to_xml plist in
  OpamSystem.write (OpamFilename.to_string file) xml
