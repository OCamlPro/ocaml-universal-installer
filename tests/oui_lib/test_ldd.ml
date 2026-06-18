(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui

(* [parse_true_so_line] *)

let pp_result fmt x =
  match x with
  | None -> Format.fprintf fmt "None"
  | Some (name, path) ->
    Format.fprintf fmt "Some (%S, %S)" name (OpamFilename.to_string path)

[@@@yalo.warning "YALO-3"] (* Disable tab character warning *)

let%expect_test "parse_true_so_line: special .so" =
  let line = "	linux-vdso.so.1 (0x00007ffdf7bb4000)" in
  let result = Ldd.parse_true_so_line line in
  Format.printf "%a" pp_result result;
  [%expect {| None |}]

[@@@yalo.warning "YALO+3"]

let%expect_test "parse_true_so_line: regular .so" =
  let line =
    "libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007ff78b95d000)"
  in
  let result = Ldd.parse_true_so_line line in
  Format.printf "%a" pp_result result;
  [%expect {| Some ("libm.so.6", "/usr/lib/x86_64-linux-gnu/libm.so.6") |}]

(* [should_embed] *)

let test_should_embed lib file =
  let lib = (lib, OpamFilename.of_string file) in
  let result = Ldd.should_embed lib in
  Format.printf "%b" result

let%expect_test "should_embed: libc" =
  test_should_embed "libc.so.6" "/lib/x86_64-linux-gnu/libc.so.6";
  [%expect {| false |}]

let%expect_test "should_embed: libm" =
  test_should_embed "libm.so.6" "/lib/x86_64-linux-gnu/libm.so.6";
  [%expect {| false |}]

let%expect_test "should_embed: libdl" =
  test_should_embed "libdl.so.2" "/lib/x86_64-linux-gnu/libdl.so.2";
  [%expect {| false |}]

let%expect_test "should_embed: libpthread" =
  test_should_embed "libpthread.so.0" "/lib/x86_64-linux-gnu/libpthread.so.0";
  [%expect {| false |}]

let%expect_test "should_embed: somelib" =
  test_should_embed "somelib.so.1" "/lib/x86_64-linux-gnu/somelib.so.1";
  [%expect {| true |}]
