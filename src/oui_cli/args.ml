(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Cmdliner
open Cmdliner.Arg
open Oui

type 'a arg_kind =
  | Flag : bool arg_kind
  | String_opt : string option -> string option arg_kind

type 'a abstract =
  { names : string list
  ; docv : string
  ; doc : string
  ; kind : 'a arg_kind
  }
(** Type describing individual elements of a CLI argument. Used to share
    args between the main binary and the opam plugin which uses OpamCmdliner
    and not Cmdliner itself. *)

let arg_from_abstract : type a. a abstract -> a Cmdliner.Arg.t =
  fun {names; docv; doc; kind} ->
  let info = info ~doc ~docv names in
  match kind with
  | Flag -> flag info
  | String_opt default -> opt (some string) default info

let opam_filename =
  let conv, pp = OpamArg.filename in
  let parse filename_arg =
    match conv (System.normalize_path filename_arg) with
    | `Ok x -> Ok x
    | `Error e -> Error e
  in
  Arg.conv' (parse, pp)

let opam_dirname =
  let conv, pp = OpamArg.dirname in
  let parse dirname_arg =
    match conv (System.normalize_path dirname_arg) with
    | `Ok x -> Ok x
    | `Error e -> Error e
  in
  Arg.conv' (parse, pp)

let wix_keep_wxs_abstract =
  { kind = Flag
  ; docv = ""
  ; doc = "Keep Wix source files."
  ; names = [ "keep-wxs" ]
  }

let wix_keep_wxs = value & arg_from_abstract wix_keep_wxs_abstract

type backend = Wix | Makeself | Pkgbuild

let pp_backend fmt t =
  match t with
  | Wix -> Fmt.pf fmt "wix"
  | Makeself -> Fmt.pf fmt "makeself"
  | Pkgbuild -> Fmt.pf fmt "pkgbuild"

let vars_of_backend = function
  | Makeself -> Makeself_backend.vars
  | Wix -> Wix_backend.vars
  | Pkgbuild -> Pkgbuild_backend.vars

type 'a choice = Autodetect | Forced of 'a

let autodetect_backend ?(log=true) () =
  match OpamStd.Sys.os () with
  | OpamStd.Sys.Darwin ->
    if log then
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
    if log then
      OpamConsole.formatted_msg
        "Detected UNIX system: using makeself backend.\n";
    Makeself
  | OpamStd.Sys.Win32
  | OpamStd.Sys.Cygwin ->
    if log then
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

let output_abstract =
  { kind = String_opt None
  ; docv = "OUTPUT"
  ; doc =
      "$(docv) installer or bundle name. Defaults to \
       $(b,package-name.version.ext), in the current directory, where $(b,ext) \
       is $(b,.msi) for Windows installers and $(b,.run) for Linux installers."
  ; names = [ "o"; "output" ]
  }

let output =
  let open Arg in
  value & arg_from_abstract output_abstract

let output_name ~output ~backend (ic : _ Installer_config.t) =
  match output with
  | Some o -> o
  | None ->
    let base = Printf.sprintf "%s-%s" ic.name ic.version in
    let ext =
      match backend with
      | None -> ""
      | Some Wix -> ".msi"
      | Some Makeself -> ".run"
      | Some Pkgbuild -> ".pkg"
    in
    base ^ ext

let override_config
    ~macos_application_signing_id
    (ic : Installer_config.internal) =
  let override ~default cli_opt =
    match cli_opt with None -> default | Some _ -> cli_opt
  in
  let macos_application_signing_id =
    override ~default:ic.macos_application_signing_id
      macos_application_signing_id
  in
  {ic with macos_application_signing_id}

let installer_config =
  let open Cmdliner.Arg in
  let docv = "CONFIG" in
  let doc = "Path to the oui.json installer config." in
  required & pos 0 (some opam_filename) None & info [] ~docv ~doc

let bundle_dir =
  let open Cmdliner.Arg in
  let docv = "BUNDLE_DIR" in
  let doc = "Path to the directory containing the dirs and files to install." in
  required & pos 1 (some opam_dirname) None & info [] ~docv ~doc

let verbose =
  let docv = "LEVEL" in
  let doc = "Verbose output level ('OPAMVERBOSE' level)" in
  value & opt int 0 & info [ "v"; "verbose" ] ~doc ~docv

let debug =
  let docv = "LEVEL" in
  let doc = "Debug output level ('OPAMDEBUG' level)" in
  value & opt int 0 & info [ "d"; "debug" ] ~doc ~docv

let mtime =
  let open Cmdliner.Arg in
  let docv = "MTIME" in
  let doc =
    "Set MTIME on to be installed files when creating the installer. \
     The format is [[CC]YY]MMDDhhmm[.SS], see {i touch -t} argument for more \
     information."
  in
  value & opt (some string) None & info ["mtime"] ~docv ~doc

let tar_extra =
  let none = "--numeric-owner,--owner=0,--group=0" in
  let doc =
    "Comma seperated list of command line options to forward to tar when \
     creating makeself installer."
  in
  value & opt (some ~none (list string)) None & info ["tar-extra"] ~doc

let macos_application_signing_id_abstract =
  { kind = String_opt None
  ; docv = "DEVELOPER_ID_APPLICATION"
  ; doc =
      "Developer ID application certificate name to use with codesign. \
       This option has higher priority than the \
       $(b,macos_application_signing_id) JSON config field."
  ; names = ["macos-binary-signing-id"]
  }

let macos_application_signing_id =
  value & arg_from_abstract macos_application_signing_id_abstract
