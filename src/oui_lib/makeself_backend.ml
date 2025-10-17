(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let install_script_name = "install.sh"
let uninstall_script_name = "uninstall.sh"
let man_dst = "MAN_DEST"
let man_dst_var = "$" ^ man_dst
let usrbin = "/usr/local/bin"
let usrshareman = "/usr/local/share/man"
let usrman = "usr/local/man"

let check_makeself_installed () =
  match Sys.command "command -v makeself.sh >/dev/null 2>&1" with
  | 0 -> ()
  | _ ->
    failwith
      "Could not find makeself.sh, \
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

let manpages_to_list (mnpgs : Installer_config.manpages option) =
  match mnpgs with
  | None -> []
  | Some mnpgs ->
    [ ("man1", mnpgs.man1)
    ; ("man2", mnpgs.man2)
    ; ("man3", mnpgs.man3)
    ; ("man4", mnpgs.man4)
    ; ("man5", mnpgs.man5)
    ; ("man6", mnpgs.man6)
    ; ("man7", mnpgs.man7)
    ; ("man8", mnpgs.man8)
    ]
    |> List.filter (function (_, []) -> false | _ -> true)

let install_manpages ~prefix manpages =
  let open Sh_script in
  let (/) = Filename.concat in
  let install_page ~section page =
    let name = Filename.basename page in
    symlink ~target:(prefix / page) ~link:(section / name)
  in
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
    set_man_dest::install_manpages

let install_script (ic : Installer_config.t) =
  let open Sh_script in
  let (/) = Filename.concat in
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
         ; symlink ~target:(prefix / binary) ~link:(usrbin / binary)
         ]
      )
      binaries
  in
  let manpages = manpages_to_list ic.makeself_manpages in
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

let uninstall_script (ic : Installer_config.t) =
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
  let setup =
    [ check_run_as_root
    ; echof "About to uninstall %s." package
    ; echof "The following files and folders will be removed from the system:"
    ; echof "- %s" prefix
    ]
    @ display_symlinks
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
  let manpages = manpages_to_list ic.makeself_manpages in
  let remove_symlinks =
    List.map
      (fun binary ->
         let link = usrbin / binary in
         if_ (Link_exists link)
           [ echof "Removing symlink %s..." link
           ; rm [link]
           ]
           ()
      )
      binaries
  in
  let remove_manpages =
    set_man_dest
    ::
    List.concat_map
      (fun (section, pages) ->
         List.map
           (fun page ->
              let path = man_dst_var / section / (Filename.basename page) in
              if_ (Link_exists path)
                [ echof "Removing manpage %s..." path
                ; rm [path]
                ]
                ())
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
  let sos = Ldd.get_sos OpamFilename.Op.(bundle_dir // binary) in
  match sos with
  | [] -> ()
  | _ ->
    let lib_dir = OpamFilename.Op.(bundle_dir / "lib") in
    OpamFilename.mkdir lib_dir;
    List.iter (fun so -> OpamFilename.copy_in so lib_dir) sos

let create_installer
    ~(installer_config : Installer_config.t) ~bundle_dir installer =
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
