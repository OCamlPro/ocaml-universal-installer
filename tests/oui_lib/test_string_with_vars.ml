(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui.String_with_vars

let%expect_test "subst: no vars" =
  let t = of_string "test" in
  let res = subst ~install_path:"XX" t in
  Format.printf "%a" pp_subst_result res;
  [%expect {| { String_with_vars.subst_string = "test"; unknown_vars = [] } |}]

let%expect_test "subst: one known var" =
  let t = of_string "<install_path>/lib" in
  let res = subst ~install_path:"XX" t in
  Format.printf "%a" pp_subst_result res;
  [%expect {| { String_with_vars.subst_string = "XX/lib"; unknown_vars = [] } |}]

let%expect_test "subst: multiple known vars" =
  let t = of_string "foo/<install_path>/bar/<install_path>" in
  let res = subst ~install_path:"XX" t in
  Format.printf "%a" pp_subst_result res;
  [%expect {| { String_with_vars.subst_string = "foo/XX/bar/XX"; unknown_vars = [] } |}]

let%expect_test "subst: unknown vars" =
  let t = of_string "<x>.<y>" in
  let res = subst ~install_path:"XX" t in
  Format.printf "%a" pp_subst_result res;
  [%expect {| { String_with_vars.subst_string = "<x>.<y>"; unknown_vars = ["<x>"; "<y>"] } |}]

let%expect_test "subst: unknown var reported once" =
  let t = of_string "<x>.<x>" in
  let res = subst ~install_path:"XX" t in
  Format.printf "%a" pp_subst_result res;
  [%expect {| { String_with_vars.subst_string = "<x>.<x>"; unknown_vars = ["<x>"] } |}]

let%expect_test "subst: mixed" =
  let t = of_string "<install_path>/lib/<unknown>" in
  let res = subst ~install_path:"XX" t in
  Format.printf "%a" pp_subst_result res;
  [%expect {|
    { String_with_vars.subst_string = "XX/lib/<unknown>";
      unknown_vars = ["<unknown>"] }
    |}]
