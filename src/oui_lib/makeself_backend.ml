(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(* This reverts some module shadowing due to opam indirect dependency on
   extlib. *)
open Stdlib

let (/) = Filename.concat
let install_script_name = "install.sh"
let uninstall_script_name = "uninstall.sh"
let man_dst = "MAN_DEST"
let man_dst_var = "$" ^ man_dst
let usrbin = "/usr/local/bin"
let usrshareman = "/usr/local/share/man"
let usrman = "usr/local/man"

let check_makeself_installed () =
  match Sys.command "command -v makeself >/dev/null 2>&1" with
  | 0 -> ()
  | _ ->
    failwith
      "Could not find makeself, \
       Please install makeself and run this command again."

let check_run_as_root =
  let open Sh_script in
  if_ Is_not_root
    [ echof "Not running as root. Aborting."
    ; echof "Please run again as root."
    ; exit 1
    ]
    ()

let set_man_dest =
  let open Sh_script in
  if_ (Dir_exists usrshareman)
    [assign ~var:man_dst ~value:usrshareman]
    ~else_:[assign ~var:man_dst ~value:usrman]
    ()

let add_symlink ~prefix ~in_ bundle_path =
  let open Sh_script in
  let base = Filename.basename bundle_path in
  symlink ~target:(prefix / bundle_path) ~link:(in_ / base)

let remove_symlink ?(name="symlink") ~in_ bundle_path =
  let open Sh_script in
  let link = in_ / (Filename.basename bundle_path) in
  if_ (Link_exists link)
    [ echof "Removing %s %s..." name link
    ; rm [link]
    ]
    ()

let install_manpages ~prefix manpages =
  let open Sh_script in
  let install_page ~section page = add_symlink ~prefix ~in_:section page in
  match manpages with
  | [] -> []
  | _ ->
    let install_manpages =
      List.concat_map
        (fun (section, pages) ->
           let section = man_dst_var / section in
           mkdir ~permissions:755 [section]
           :: (List.map (install_page ~section) pages))
        manpages
    in
    set_man_dest
    :: echof "Installing manpages to %s..." man_dst_var
    :: install_manpages

let install_script (ic : Installer_config.internal) =
  let open Sh_script in
  let package = ic.name in
  let version = ic.version in
  let prefix = "/opt" / package in
  let setup =
    [ echof "Installing %s.%s to %s" package version prefix
    ; check_run_as_root
    ; mkdir ~permissions:755 [prefix]
    ]
  in
  let install_bundle =
    Sh_script.copy_all_in ~src:"." ~dst:prefix ~except:install_script_name
  in
  let binaries = ic.exec_files in
  let add_symlinks_to_usrbin =
    List.concat_map
      (fun binary ->
         [ echof "Adding %s to %s" binary usrbin
         ; add_symlink ~prefix ~in_:usrbin binary
         ]
      )
      binaries
  in
  let manpages = Option.value ic.manpages ~default:[] in
  let install_manpages = install_manpages ~prefix manpages in
  let notify_install_complete =
    [ echof "Installation complete!"
    ; echof
        "If you want to safely uninstall %s, please run %s/%s."
        package prefix uninstall_script_name
    ]
  in
  setup
  @ [install_bundle]
  @ add_symlinks_to_usrbin
  @ install_manpages
  @ notify_install_complete

let uninstall_script (ic : Installer_config.internal) =
  let open Sh_script in
  let (/) = Filename.concat in
  let package = ic.name in
  let prefix = "/opt" / package in
  let usrbin = "/usr/local/bin" in
  let binaries = ic.exec_files in
  let display_symlinks =
    List.map
      (fun binary -> echof "- %s/%s" usrbin binary)
      binaries
  in
  let manpages = Option.value ic.manpages ~default:[] in
  let display_manpages =
    List.concat_map
      (fun (section, pages) ->
         List.map
           (fun page ->
              echof "- %s/%s/%s" man_dst_var section (Filename.basename page))
           pages)
      manpages
  in
  let setup =
    [ check_run_as_root
    ; set_man_dest
    ; echof "About to uninstall %s." package
    ; echof "The following files and folders will be removed from the system:"
    ; echof "- %s" prefix
    ]
    @ display_symlinks
    @ display_manpages
  in
  let confirm_uninstall =
    [ prompt ~question:"Proceed? [y/N]" ~varname:"ans"
    ; case "ans"
        [ {pattern  = "[Yy]*"; commands = []}
        ; {pattern = "*"; commands = [echof "Aborted."; exit 1]}
        ]
    ]
  in
  let remove_install_folder =
    [ if_ (Dir_exists prefix)
        [ echof "Removing %s..." prefix
        ; rm_rf [prefix]
        ]
        ()
    ]
  in
  let remove_symlinks = List.map (remove_symlink ~in_:usrbin) binaries in
  let remove_manpages =
    List.concat_map
      (fun (section, pages) ->
         List.map
           (remove_symlink ~name:"manpage" ~in_:(man_dst_var / section))
           pages)
      manpages
  in
  let notify_uninstall_complete = [echof "Uninstallation complete!"] in
  setup
  @ confirm_uninstall
  @ remove_install_folder
  @ remove_symlinks
  @ remove_manpages
  @ notify_uninstall_complete

let add_sos_to_bundle ~bundle_dir binary =
  let binary = OpamFilename.Op.(bundle_dir // binary) in
  let sos = Ldd.get_sos binary in
  match sos with
  | [] -> ()
  | _ ->
    let dst_dir = OpamFilename.dirname binary in
    List.iter (fun so -> OpamFilename.copy_in so dst_dir) sos;
    System.call_unit Patchelf (Set_rpath {rpath = "$ORIGIN"; binary})

let create_installer
    ~(installer_config : Installer_config.internal) ~bundle_dir installer =
  check_makeself_installed ();
  OpamConsole.formatted_msg "Preparing makeself archive... \n";
  List.iter (add_sos_to_bundle ~bundle_dir) installer_config.exec_files;
  let install_script = install_script installer_config in
  let uninstall_script = uninstall_script installer_config in
  let install_sh = OpamFilename.Op.(bundle_dir // install_script_name) in
  let uninstall_sh = OpamFilename.Op.(bundle_dir // uninstall_script_name) in
  Sh_script.save install_script install_sh;
  Sh_script.save uninstall_script uninstall_sh;
  System.call_unit Chmod (755, install_sh);
  System.call_unit Chmod (755, uninstall_sh);
  let args : System.makeself =
    { archive_dir = bundle_dir
    ; installer
    ; description = installer_config.name
    ; startup_script = Format.sprintf "./%s" install_script_name
    }
  in
  OpamConsole.formatted_msg
    "Generating standalone installer %s...\n"
    (OpamFilename.to_string installer);
  System.call_unit Makeself args;
  OpamConsole.formatted_msg "Done.\n"
