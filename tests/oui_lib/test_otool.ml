(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui

(* [parse_dylib_line] *)

let pp_result fmt x =
  match x with
  | None -> Format.fprintf fmt "None"
  | Some (name, path) ->
    Format.fprintf fmt "Some (%S, %S)" name path

let%expect_test "parse_dylib_line: homebrew lib" =
  let line =
    "\t/opt/homebrew/lib/libgmp.10.dylib (compatibility version 15.0.0, \
     current version 15.0.0)"
  in
  let result = Otool.parse_dylib_line line in
  Format.printf "%a" pp_result result;
  [%expect {| Some ("libgmp.10.dylib", "/opt/homebrew/lib/libgmp.10.dylib") |}]

let%expect_test "parse_dylib_line: system lib" =
  let line =
    "\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.100.3)"
  in
  let result = Otool.parse_dylib_line line in
  Format.printf "%a" pp_result result;
  [%expect {| Some ("libSystem.B.dylib", "/usr/lib/libSystem.B.dylib") |}]

let%expect_test "parse_dylib_line: rpath lib" =
  let line =
    "\t@rpath/libfoo.dylib (compatibility version 1.0.0, current version 1.0.0)"
  in
  let result = Otool.parse_dylib_line line in
  Format.printf "%a" pp_result result;
  [%expect {| Some ("libfoo.dylib", "@rpath/libfoo.dylib") |}]

let%expect_test "parse_dylib_line: empty line" =
  let line = "" in
  let result = Otool.parse_dylib_line line in
  Format.printf "%a" pp_result result;
  [%expect {| None |}]

let%expect_test "parse_dylib_line: malformed line" =
  let line = "    " in
  let result = Otool.parse_dylib_line line in
  Format.printf "%a" pp_result result;
  [%expect {| None |}]

(* [should_embed] *)

let%expect_test "should_embed: libSystem" =
  let lib = ("libSystem.B.dylib", "/usr/lib/libSystem.B.dylib") in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: libSystem non standard path" =
  let lib = ("libSystem.B.dylib", "/other/libSystem.B.dylib") in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: system framework path" =
  let lib =
    ("CoreFoundation",
     "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
  in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: rpath library" =
  let lib = ("libfoo.dylib", "@rpath/libfoo.dylib") in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: executable_path library" =
  let lib = ("libfoo.dylib", "@executable_path/../lib/libfoo.dylib") in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: homebrew library" =
  let lib = ("libgmp.10.dylib", "/opt/homebrew/lib/libgmp.10.dylib") in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| true |}]

let%expect_test "should_embed: local library" =
  let lib = ("libfoo.dylib", "/usr/local/lib/libfoo.dylib") in
  let result = Otool.should_embed lib in
  Format.printf "%b" result;
  [%expect {| true |}]
