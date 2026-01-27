(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Exception that is launched by command when proccess terminates with non-zero exit code status.
    Contains command's output. *)
exception System_error of string

(** Configuration options for {i wix} command as a part of WiX tools.
    Consists of input files, extensions to be used and output file path. *)
type wix = {
  wix_files : string list;
  wix_exts : string list;
  wix_out : string
}

(** makeself script arguments *)
type makeself = {
  tar_extra : string list;
  archive_dir : OpamFilename.Dir.t;
  installer : OpamFilename.t;
  description : string;
  startup_script : string;
}

(** Expected output path type *)
type cygpath_out = [
  | `Win (** Path Windows *)
  | `WinAbs (** Absolute Path Windows *)
  | `Cyg (** Path Cygwin *)
  | `CygAbs (** Absolute Path Cygwin *)
  ]

(** Arguments for install_name_tool command *)
type install_name_tool_args = {
  change_from : string; (** Original dylib path to replace *)
  change_to : string; (** New dylib path *)
  binary : OpamFilename.t; (** Binary to modify *)
}

(** Arguments for codesign command *)
type codesign_args = {
  binary : OpamFilename.t; (** Binary to sign *)
  identity : string; (** Signing identity: "-" for ad-hoc, or certificate name *)
  force : bool;
  timestamp : bool; (** Add timestamp *)
  entitlements : string option; (** Optional path to entitlements file *)
}

(** Arguments for codesign verify command *)
type codesign_verify_args = {
  binary : OpamFilename.t; (** Binary to verify *)
  verbose : bool;
}

(** Arguments for pkgbuild command *)
type pkgbuild_args = {
  root : OpamFilename.Dir.t; (** Root directory to package *)
  identifier : string; (** Package identifier (reverse-DNS format) *)
  version : string; (** Package version *)
  install_location : string; (** Installation path *)
  scripts : OpamFilename.Dir.t option; (** Optional scripts directory *)
  output : OpamFilename.t; (** Output .pkg file *)
}

(** Arguments for productbuild command *)
type productbuild_args = {
  package : OpamFilename.t; (** Component package to wrap *)
  output : OpamFilename.t; (** Output .pkg file *)
}

(** Arguments for patchelf command *)
type patchelf_args =
  | Set_rpath of {rpath: string; binary: OpamFilename.t}

(* touch command arguments *)
type touch_args = {
  mtime : string;
  file  : string;
}

(** External commands that could be called and handled by {b oui}. *)
type _ command =
  | Which : string command  (** {b which} command, to check programs availability *)
  | Ldd : string command (** {b ldd} command to get binaries .so paths *)
  | Otool : string command (** {b otool} command to get binaries dylib paths on macOS *)
  | Cygpath : (cygpath_out * string) command (** {b cygpath} command to translate path between cygwin and windows and vice-versa *)
  | Wix : wix command
  | Makeself : makeself command (** {b makeself} command to generate linux installer. *)
  | Chmod : (int * OpamFilename.t) command
  | InstallNameTool : install_name_tool_args command (** {b install_name_tool} command to modify dylib paths in macOS binaries *)
  | Codesign : codesign_args command (** {b codesign} command to sign macOS binaries and app bundles *)
  | CodesignVerify : codesign_verify_args command (** {b codesign --verify} command to verify code signatures *)
  | Pkgbuild : pkgbuild_args command (** {b pkgbuild} command to create macOS component packages *)
  | Productbuild : productbuild_args command (** {b productbuild} command to create macOS installer packages *)
  | Patchelf : patchelf_args command
  | Touch : touch_args command (** {b touch} command to change files timestamps *)

(** Calls given command with its arguments and parses output, line by line. Raises [System_error]
    with command's output when command exits with non-zero exit status. *)
val call : 'a command -> 'a -> string list

(** Same as [call] but ignores output. *)
val call_unit : 'a command -> 'a -> unit

(** Same as [call_unit], but calls commands simultaneously. *)
val call_list : ('a command * 'a) list -> unit

(** Performs path translations between Windows and Cygwin. See [System.cygpath_out] for more details. *)
val cyg_win_path : cygpath_out -> string -> string

(** Resolve absolute path in the current system's format (Cygwin or Win32). *)
val normalize_path : string -> string

(** Convert safely path from [OpamFilename.t] *)
val path_str : OpamFilename.t -> string

(** Convert safely path from [OpamFilename.Dir.t] *)
val path_dir_str : OpamFilename.Dir.t -> string

module type FILE_INTF = sig
  type t
  val name : string
  val to_string : t -> string
  val of_string : string -> t
  val (/) : OpamTypes.dirname -> string -> t
  val copy : src:t -> dst:t -> unit
  val exists : t -> bool
  val basename : t -> OpamTypes.basename
end

module DIR_IMPL : FILE_INTF with type t = OpamFilename.Dir.t
module FILE_IMPL : FILE_INTF with type t = OpamFilename.t

val resolve_path : OpamFilter.env ->
                   (module FILE_INTF with type t = 'a) -> string -> 'a
val resolve_file_path : OpamFilter.env -> string -> OpamFilename.t

(** On Windows, returns path.exe if dir:path.exe exists.
    Otherwise return path. *)
val maybe_exe : dir:OpamFilename.Dir.t -> path:string -> string
