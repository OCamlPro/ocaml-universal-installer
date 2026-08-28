(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type program_headers = string list

let program_headers binary = System.call Readelf {binary}

let blanks = Re.(compile (rep1 (alt [char ' '; char '\t'])))

let split_words s = Re.split blanks s

let is_static program_headers =
  let rec contains_INTERP l =
    match l with
    | [] -> false
    | hd::tl ->
      match split_words hd with
      | "INTERP"::_ -> true
      | "Section"::"to"::"Segment"::"mapping:"::_ ->
        (* End of Program headers section *)
        false
      | _ ->
        contains_INTERP tl
  in
  not (contains_INTERP program_headers)

let program_headers_from_lines l = l
