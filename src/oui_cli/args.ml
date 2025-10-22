(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Cmdliner
open Cmdliner.Arg
open Oui

let opam_filename =
  let conv, pp = OpamArg.filename in
  ((fun filename_arg -> System.normalize_path filename_arg |> conv), pp)

let opam_dirname =
  let conv, pp = OpamArg.dirname in
  ((fun dirname_arg -> System.normalize_path dirname_arg |> conv), pp)

let conf_file =
  value
  & opt (some opam_filename) None
  & info [ "conf"; "c" ] ~docv:"PATH" ~docs:Man.Section.bin_args
      ~doc:
        "Configuration file for the binary to install. See $(i,Configuration) \
         section"

let wix_keep_wxs = value & flag & info [ "keep-wxs" ] ~doc:"Keep Wix source files."

let config =
  let apply conf_file conf_wix_keep_wxs =
    Config.{
      conf_file;
      conf_wix_keep_wxs;
    }
  in
  Term.(const apply $ conf_file $ wix_keep_wxs)

type backend = Wix | Makeself | Pkgbuild

let pp_backend fmt t =
  match t with
  | Wix -> Fmt.pf fmt "wix"
  | Makeself -> Fmt.pf fmt "makeself"
  | Pkgbuild -> Fmt.pf fmt "pkgbuild"

type 'a choice = Autodetect | Forced of 'a

let autodetect_backend () =
  match OpamStd.Sys.os () with
  | OpamStd.Sys.Darwin ->
    OpamConsole.formatted_msg
      "Detected macOS system: using pkgbuild backend.\n";
    Pkgbuild
  | OpamStd.Sys.Linux
  | OpamStd.Sys.FreeBSD
  | OpamStd.Sys.OpenBSD
  | OpamStd.Sys.NetBSD
  | OpamStd.Sys.DragonFly
  | OpamStd.Sys.Unix
  | OpamStd.Sys.Other _ ->
    OpamConsole.formatted_msg
      "Detected UNIX system: using makeself.sh backend.\n";
    Makeself
  | OpamStd.Sys.Win32
  | OpamStd.Sys.Cygwin ->
    OpamConsole.formatted_msg "Detected Windows system: using WiX backend.\n";
    Wix

let backend_conv ~make ~print =
  let parse s =
    match String.lowercase_ascii s with
    | "wix" -> make (Some Wix)
    | "makeself" -> make (Some Makeself)
    | "pkgbuild" -> make (Some Pkgbuild)
    | "none" -> make None
    | _ -> Error (Format.sprintf "Unsupported backend %S" s)
  in
  let print fmt t =
    match t with
    | Autodetect -> Fmt.pf fmt "autodetect"
    | Forced x -> print fmt x
  in
  let docv = "BACKEND" in
  Cmdliner.Arg.conv' ~docv (parse, print)

let backend_doc ~choices =
  let choices = List.map (Printf.sprintf "$(b,%s)") choices in
  let choices_str = String.concat "|" choices in
  Printf.sprintf
    "(%s). Overwrites the default $(docv). \
     Without this option, it is determined from the system: WiX to produce msi \
     installers on Windows, makeself to produce self extracting/installing \
     .run archives on Unix."
    choices_str

let backend =
  let docv = "BACKEND" in
  let conv =
    backend_conv
      ~print:pp_backend
      ~make:(function
          | None -> Error "Unsupported backend \"none\""
          | Some b -> Ok (Forced b))
  in
  let doc = backend_doc ~choices:["wix"; "makeself"; "pkgbuild"] in
  let arg = opt conv Autodetect & info [ "backend" ] ~doc ~docv in
  let choose = function Autodetect -> autodetect_backend () | Forced x -> x in
  Cmdliner.Term.(const choose $ value arg)

let backend_opt =
  let docv = "BACKEND" in
  let print fmt t =
    match t with
    | None -> Fmt.pf fmt "none"
    | Some b -> pp_backend fmt b
  in
  let conv = backend_conv ~make:(fun opt -> Ok (Forced opt)) ~print in
  let doc =
    backend_doc ~choices:["wix"; "makeself"; "pkgbuild"; "none"]
    ^
    "When $(b,none), disables backend, making the command generate a bundle \
     with an installer config that can later be fed into any of the existing \
     backends."
  in
  let arg = opt conv Autodetect & info [ "backend" ] ~doc ~docv in
  let choose = function
    | Autodetect -> Some (autodetect_backend ())
    | Forced opt -> opt
  in
  Cmdliner.Term.(const choose $ value arg)

let output =
  let open Arg in
  let doc =
    "$(docv) installer or bundle name. Defaults to \
     $(b,package-name.version.ext), in the current directory, where $(b,ext) \
     is $(b,.msi) for Windows installers and $(b,.run) for Linux installers."
  in
  value
  & opt (some string) None
  & info ~docv:"OUTPUT" ~doc [ "o"; "output" ]

let output_name ~output ~backend (ic : Installer_config.t) =
  match output with
  | Some o -> o
  | None ->
    let base = Printf.sprintf "%s.%s" ic.name ic.version in
    let ext =
      match backend with
      | None -> ""
      | Some Wix -> ".msi"
      | Some Makeself -> ".run"
      | Some Pkgbuild -> ".pkg"
    in
    base ^ ext
