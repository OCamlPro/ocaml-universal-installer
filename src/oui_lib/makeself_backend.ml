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

let install_path = "INSTALL_PATH"
let install_path_var = "$" ^ install_path

let man_dst = "MAN_DEST"
let man_dst_var = "$" ^ man_dst

let usrbin = "/usr/local/bin"
let usrshareman = "/usr/local/share/man"
let usrman = "usr/local/man"

let install_conf = "install.conf"
let load_conf = "load_conf"
let conf_version = "version"
let conf_plugins = "plugins"
let conf_lib = "lib"

let check_available = "check_available"
let check_lib = "check_lib"

let vars : Installer_config.vars = { install_path = install_path_var }

(* Do a basic validation of an install.conf file and load the variables
   defined in it in an APPNAME_varname variable so it can be used in the rest
   of the install script.
   Note that it loads only the variables that we are actually going to use.
*)
let def_load_conf =
  let open Sh_script in
  def_fun load_conf
    [ assign ~var:"var_prefix" ~value:"$2"
    ; assign ~var:"conf" ~value:"$1"
    ; read_file ~line_var:"line" "$conf"
        [ case "line" (* Skip blank lines and comments *)
            [{pattern = {|""|\#*|}; commands = [continue]}]
        ; case "line" (* Validate lines *)
            [ {pattern = "*=*"; commands = []}
            ; { pattern = "*";
                commands =
                  [ print_errf "Invalid line in $conf: $line"
                  ; return 1
                  ]
}
            ]
        ; assign ~var:"key" ~value:"${line%%=*}"
        ; assign ~var:"val" ~value:"${line#*=}"
        ; case "key" (* Validate key *)
            [ { pattern = Printf.sprintf "*[!a-zA-Z0-9_]*"
              ; commands =
                  [ print_errf "Invalid configuration key in $conf: $key"
                  ; return 1
                  ]
              }
            ; { pattern = "*"
              ; commands = [eval "$var_prefix$key=\\$val"] }
            ]
        ]
    ; return 0
    ]

let app_var_prefix = Plugin_utils.app_var_prefix

let load_conf ?var_prefix file =
  let var_prefix_arg = Option.to_list var_prefix in
  Sh_script.call_fun load_conf (file::var_prefix_arg)

let app_install_path ~app_name = "/opt" / app_name

let app_var ~var_prefix var = var_prefix ^ var
let plugins_var ~var_prefix = app_var ~var_prefix conf_plugins
let lib_var ~var_prefix = app_var ~var_prefix conf_lib

let find_and_load_conf app_name =
  let open Sh_script in
  let app_dir = app_install_path ~app_name in
  let var_prefix = app_var_prefix app_name in
  let conf = app_dir / install_conf in
  if_ ((Dir_exists app_dir) && (File_exists conf))
    [load_conf ~var_prefix conf]
    ~else_:
      [ print_errf "Could not locate %s install path" app_name
      ; exit 1
      ]
    ()

let list_all_files ~prefix (ic : Installer_config.internal) =
  prefix ::
  List.map (fun x -> usrbin / (Filename.basename x)) ic.exec_files
  @ List.concat_map
    (fun (section, files) ->
       let dir = man_dst_var / section in
       List.map (fun x -> dir / (Filename.basename x)) files)
    (Option.value ic.manpages ~default:[])

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

(* Sets documented variables that users can rely upon when setting
   env or for post-install commands *)
let set_install_vars ~prefix =
  let open Sh_script in
  [ assign ~var:install_path ~value:prefix ]

let install_binary ~prefix ~env ~in_ bundle_path =
  let open Sh_script in
  let base = Filename.basename bundle_path in
  let true_binary = prefix / bundle_path in
  let installed_binary = in_ / base in
  let install_cmds =
    match env with
    | [] -> [symlink ~target:true_binary ~link:installed_binary]
    | _ ->
      let set_vars =
        List.map
          (fun (var, value) ->
             (* VAR="VALUE" \ *)
             Printf.sprintf "%s=\\\"%s\\\" \\" var value)
          env
      in
      let wrapper_script_lines =
        "#!/usr/bin/env sh" ::
        set_vars
        @ [ Printf.sprintf "exec %s \\\"\\$@\\\"" true_binary ]
      in
      [ write_file installed_binary wrapper_script_lines
      ; chmod 755 [installed_binary]
      ]
  in
  echof "Adding %s to %s" base in_ :: install_cmds

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
    echof "Installing manpages to %s..." man_dst_var
    :: install_manpages

let install_plugin ~prefix (plugin : Installer_config.plugin) =
  let open Sh_script in
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = "$" ^ lib_var ~var_prefix in
  let plugins_dir = "$" ^ plugins_var ~var_prefix in
  let add_symlink_if_missing ~prefix ~in_ path =
    let dst = in_ / (Filename.basename path) in
    if_ ((Not (Link_exists dst)) && (Not (Dir_exists dst)))
      [ add_symlink ~prefix ~in_ path ]
      ()
  in
  [ echof "Installing plugin %s to %s..." plugin.name plugin.app_name
  ; add_symlink ~prefix plugin.plugin_dir ~in_:plugins_dir
  ; add_symlink_if_missing ~prefix plugin.lib_dir ~in_:lib_dir
  ]
  @ (List.map
       (fun dyn_dep -> add_symlink_if_missing ~prefix dyn_dep ~in_:lib_dir)
       plugin.dyn_deps)

let def_check_available =
  let open Sh_script in
  def_fun check_available
    [ if_ (Exists "$1")
        [ print_errf "$1 already exists on the system! Aborting"
        ; exit 1
        ]
        ()
    ]

let def_check_lib =
  let open Sh_script in
  def_fun check_lib
    [ if_ ((Exists "$1") && (Not (Dir_exists "$1")) && (Not (Link_exists "$1")))
        [ print_errf
            "$1 already exists and does not appear to be a library! Aborting"
        ; exit 1
        ]
        ()
    ]

let check_available path = Sh_script.call_fun check_available [path]

let check_lib path = Sh_script.call_fun check_lib [path]

let check_plugin_available (plugin : Installer_config.plugin) =
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = "$" ^ lib_var ~var_prefix in
  let plugins_dir = "$" ^ plugins_var ~var_prefix in
  let paths =
    [ lib_dir / (Filename.basename plugin.lib_dir)
    ; plugins_dir / (Filename.basename plugin.plugin_dir)
    ]
  in
  List.map check_available paths
  @ List.map
    (fun x -> check_lib (lib_dir / (Filename.basename x)))
    plugin.dyn_deps

let prompt_for_confirmation =
  let open Sh_script in
  [ prompt ~question:"Proceed? [y/N]" ~varname:"ans"
  ; case "ans"
      [ {pattern  = "[Yy]*"; commands = []}
      ; {pattern = "*"; commands = [echof "Aborted."; exit 1]}
      ]
  ]

let install_script (ic : Installer_config.internal) =
  let open Sh_script in
  let package = ic.name in
  let version = ic.version in
  let prefix = "/opt" / package in
  let plugin_apps =
    List.map (fun (p : Installer_config.plugin) -> p.app_name) ic.plugins
    |> List.sort_uniq String.compare
  in
  let all_files = list_all_files ~prefix ic in
  let def_load_conf =
    match ic.plugins with
    | [] -> []
    | _ -> [def_load_conf]
  in
  let display_install_info =
    [ echof "Installing %s.%s to %s" package version prefix
    ; echof "The following files and directories will be written to the system:"
    ]
    @ (List.map (echof "- %s") all_files)
  in
  let display_plugin_install_info =
    match (ic.plugins : Installer_config.plugin list) with
    | [] -> []
    | plugins ->
      echof "The following plugins will be installed:" ::
      (List.map
         (fun (p : Installer_config.plugin) ->
            echof "- %s for %s" p.name p.app_name)
         plugins)
  in
  let load_plugin_app_vars = List.map find_and_load_conf plugin_apps in
  let check_all_available =
    List.map check_available all_files
    @ List.concat_map check_plugin_available ic.plugins
  in
  let check_permissions =
    [ check_run_as_root
    ; mkdir ~permissions:755 [prefix]
    ]
  in
  let setup =
    def_check_available ::
    def_check_lib ::
    def_load_conf
    @ set_install_vars ~prefix
    @ [ set_man_dest ]
    @ display_install_info
    @ display_plugin_install_info
    @ load_plugin_app_vars
    @ check_all_available
    @ prompt_for_confirmation
    @ check_permissions
  in
  let install_bundle =
    Sh_script.copy_all_in ~src:"." ~dst:prefix ~except:install_script_name
  in
  let env = ic.environment in
  let binaries = ic.exec_files in
  let install_binaries =
    List.concat_map (install_binary ~prefix ~env ~in_:usrbin) binaries
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
  let install_plugins = List.concat_map (install_plugin ~prefix) ic.plugins in
  let dump_install_conf =
    let lines =
      List.filter_map (fun x -> x)
        [ Some (Printf.sprintf "%s=%s" conf_version ic.version)
        ; Option.map
            (fun (plgdr : Installer_config.plugin_dirs) ->
               Printf.sprintf "%s=%s" conf_plugins (prefix / plgdr.plugins_dir))
            ic.plugin_dirs
        ; Option.map
            (fun (plgdr : Installer_config.plugin_dirs) ->
               Printf.sprintf "%s=%s" conf_lib (prefix / plgdr.lib_dir))
            ic.plugin_dirs
        ]
    in
    let plugin_app_lines =
      ListLabels.concat_map plugin_apps
        ~f:(fun app_name ->
            let var_prefix = app_var_prefix app_name in
            let lib_var = lib_var ~var_prefix in
            let plugins_var = plugins_var ~var_prefix in
            [ Printf.sprintf "%s=$%s" lib_var lib_var
            ; Printf.sprintf "%s=$%s" plugins_var plugins_var
            ])
    in
    let install_conf = prefix / install_conf in
    [ Sh_script.write_file install_conf (lines @ plugin_app_lines)
    ; Sh_script.chmod 644 [install_conf]
    ]
  in
  setup
  @ [install_bundle]
  @ install_binaries
  @ install_manpages
  @ install_plugins
  @ dump_install_conf
  @ notify_install_complete

let display_plugin (plugin : Installer_config.plugin) =
  let open Sh_script in
  let b = Filename.basename in
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = "$" ^ lib_var ~var_prefix in
  let plugins_dir = "$" ^ plugins_var ~var_prefix in
  [ echof "- %s/%s" plugins_dir (b plugin.plugin_dir)
  ; echof "- %s/%s" lib_dir (b plugin.lib_dir)
  ]
  @ List.map (fun x -> echof "- %s/%s" lib_dir (b x)) plugin.dyn_deps

let uninstall_plugin (plugin : Installer_config.plugin) =
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = "$" ^ lib_var ~var_prefix in
  let plugins_dir = "$" ^ plugins_var ~var_prefix in
  [ remove_symlink ~in_:lib_dir plugin.lib_dir
  ; remove_symlink ~in_:plugins_dir plugin.plugin_dir
  ]
  @ List.map (remove_symlink ~in_:lib_dir) plugin.dyn_deps

let uninstall_script (ic : Installer_config.internal) =
  let open Sh_script in
  let (/) = Filename.concat in
  let package = ic.name in
  let prefix = "/opt" / package in
  let usrbin = "/usr/local/bin" in
  let binaries = ic.exec_files in
  let load_install_conf =
    match ic.plugins with
    | [] -> []
    | _ ->
      [ def_load_conf
      ; load_conf (prefix / install_conf)
      ]
  in
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
  let display_plugins = List.concat_map display_plugin ic.plugins in
  let setup =
    [ check_run_as_root
    ; set_man_dest
    ]
    @ load_install_conf @
    [ echof "About to uninstall %s." package
    ; echof "The following files and folders will be removed from the system:"
    ; echof "- %s" prefix
    ]
    @ display_symlinks
    @ display_manpages
    @ display_plugins
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
  let remove_plugins = List.concat_map uninstall_plugin ic.plugins in
  let notify_uninstall_complete = [echof "Uninstallation complete!"] in
  setup
  @ prompt_for_confirmation
  @ remove_install_folder
  @ remove_symlinks
  @ remove_manpages
  @ remove_plugins
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
