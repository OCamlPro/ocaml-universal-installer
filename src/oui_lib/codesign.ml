(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type signing_identity =
  | AdHoc
  | DeveloperID of string

type sign_options = {
  force : bool;
  timestamp : bool;
  entitlements : string option;
}

let default_sign_options = {
  force = false;
  timestamp = false;
  entitlements = None;
}

let sign_binary ?(options=default_sign_options) ~identity binary =
  try
    let identity_str = match identity with
      | AdHoc -> "-"
      | DeveloperID cert_name -> cert_name
    in
    let args : System.codesign_args = {
      binary;
      identity = identity_str;
      force = options.force;
      timestamp = options.timestamp;
      entitlements = options.entitlements;
    } in
    System.call_unit System.Codesign args
  with System.System_error e ->
    OpamConsole.warning "codesign failed: %s" e

let sign_binary_adhoc ?(force=true) binary =
  let options = { default_sign_options with force } in
  sign_binary ~options ~identity:AdHoc binary

let sign_binary_with_dev_id ?(force=true) ?(timestamp=true) ~cert_name binary =
  let options = { default_sign_options with force; timestamp } in
  sign_binary ~options ~identity:(DeveloperID cert_name) binary

let verify_signature binary =
  try
    let args : System.codesign_verify_args = {
      binary;
      verbose = false;
    } in
    System.call_unit System.CodesignVerify args;
    true
  with System.System_error _ ->
    false
