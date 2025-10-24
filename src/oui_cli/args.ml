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
open Oui.Types

let wix_version_conv =
  let parse str =
    try `Ok (Wix.Version.of_string str) with Failure s -> `Error s
  in
  let print ppf wxv = Format.pp_print_string ppf (Wix.Version.to_string wxv) in
  (parse, print)

let opam_filename =
  let conv, pp = OpamArg.filename in
  ((fun filename_arg -> System.normalize_path filename_arg |> conv), pp)

let opam_dirname =
  let conv, pp = OpamArg.dirname in
  ((fun dirname_arg -> System.normalize_path dirname_arg |> conv), pp)

let conffile =
  value
  & opt (some opam_filename) None
  & info [ "conf"; "c" ] ~docv:"PATH" ~docs:Man.Section.bin_args
      ~doc:
        "Configuration file for the binary to install. See $(i,Configuration) \
         section"

let wix_version =
  value
  & opt (some wix_version_conv) None
  & info [ "with-version" ] ~docv:"VERSION"
      ~doc:
        "The version to use for the installer, in an msi format, i.e. numbers \
         and dots, [0-9.]+"

let wix_path =
  (* FIXME: that won't work when using a MinGW ocaml compiler under a Cygwin env... *)
  (* NOTE1: we could retrieve this using the WIX6 environment variable *)
  (* NOTE2: or we could rely in wix.exe to be in the PATH (the installer sets it) *)
  let prefix = if Sys.cygwin || true then "/cygdrive" else "" in
  value
  & opt string (prefix ^ "/c/Program Files/WiX Toolset v6.0/bin")
  & info [ "wix-path" ] ~docv:"DIR"
      ~doc:
        "The path where WIX tools are stored. The path should be full and \
         should use linux format path (with $(i,/) as delimiter) since \
         presence of such binaries are checked with $(b,which) tool that \
         accepts only this type of path."

let package_guid =
  value
  & opt (some string) None
  & info [ "pkg-guid" ] ~docv:"UID"
      ~doc:
        "The package GUID that will be used to update the same package with \
         different version without processing throught Windows Apps & features \
         panel."

let icon_file =
  value
  & opt (some OpamArg.filename) None
  & info [ "ico" ] ~docv:"FILE"
      ~doc:"Logo icon that will be used for application."

let dlg_bmp =
  value
  & opt (some OpamArg.filename) None
  & info [ "dlg-bmp" ] ~docv:"FILE"
      ~doc:
        "BMP file that is used as background for dialog window for installer."

let ban_bmp =
  value
  & opt (some OpamArg.filename) None
  & info [ "ban-bmp" ] ~docv:"FILE"
      ~doc:"BMP file that is used as background for banner for installer."

let keep_wxs = value & flag & info [ "keep-wxs" ] ~doc:"Keep Wix source files."

let config =
  let apply conf_file conf_wix_version
      conf_wix_path conf_package_guid conf_icon_file
      conf_dlg_bmp conf_ban_bmp conf_keep_wxs =
    {
      conf_file;
      conf_wix_version;
      conf_wix_path;
      conf_package_guid;
      conf_icon_file;
      conf_dlg_bmp;
      conf_ban_bmp;
      conf_keep_wxs;
    }
  in
  Term.(
    const apply $ conffile $ wix_version
    $ wix_path $ package_guid $ icon_file $ dlg_bmp $ ban_bmp $ keep_wxs)

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
