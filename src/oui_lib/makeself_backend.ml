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
let (!$) v = "$" ^ v

let install_script_name = "install.sh"
let uninstall_script_name = "uninstall.sh"

let install_path_nv = "INSTALL_PATH"
let install_path_v = !$ install_path_nv

let is_user_install_nv = "IS_USER_INSTALL"
let is_user_install_v = !$ is_user_install_nv

(* In this module [prefix] refers to the folder where we will create
   the [install_dir] and [install_dir] to the folder that will contain
   the installed files. E.g. [/opt] is the default [prefix] and
   [/opt/package_name] the default [install_dir] for a global install. *)
let prefix_nv = "PREFIX"
let prefix_v = !$ prefix_nv
let mandir_nv = "MANDIR"
let mandir_v = !$ mandir_nv
let bindir_nv = "BINDIR"
let bindir_v = !$ bindir_nv

let opt = "/opt"

module Global = struct
  let pre = "/usr/local"
  let bin = pre / "bin"
  let shareman = pre / "share/man"
  let man = pre / "man"
end

module User = struct
  let pre = "$HOME/.local"
  let bin = pre / "bin"
  let man = pre / "man"
end

let install_conf = "install.conf"
let load_conf = "load_conf"
let conf_version = "version"
let conf_plugins = "plugins"
let conf_lib = "lib"

let check_available = "check_available"
let check_lib = "check_lib"

let vars : Installer_config.vars = { install_path = install_path_v }

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

let call_load_conf ?var_prefix file =
  let var_prefix_arg = Option.to_list var_prefix in
  Sh_script.call_fun load_conf (file::var_prefix_arg)

let app_install_path ~app_name = prefix_v / app_name

let app_var ~var_prefix var = var_prefix ^ var
let plugins_var ~var_prefix = app_var ~var_prefix conf_plugins
let lib_var ~var_prefix = app_var ~var_prefix conf_lib

let find_and_load_conf app_name =
  let open Sh_script in
  let app_dir = app_install_path ~app_name in
  let var_prefix = app_var_prefix app_name in
  let conf = app_dir / install_conf in
  if_ ((Dir_exists app_dir) && (File_exists conf))
    [call_load_conf ~var_prefix conf]
    ~else_:
      [ print_errf "Could not locate %s install path" app_name
      ; exit 1
      ]
    ()

let list_all_files ~install_dir ~bindir ~mandir
    (ic : Installer_config.internal) =
  install_dir ::
  List.map
    (fun (x : Installer_config.exec_file) ->
       bindir / (Filename.basename x.path))
    ic.exec_files
  @ List.concat_map
    (fun (section, files) ->
       let dir = mandir / section in
       List.map (fun x -> dir / (Filename.basename x)) files)
    (Option.value ic.manpages ~default:[])

let check_makeself_installed () =
  match Sys.command "command -v makeself >/dev/null 2>&1" with
  | 0 -> ()
  | _ ->
    failwith
      "Could not find makeself, \
       Please install makeself and run this command again."

let set_user_prefixes =
  let open Sh_script in
  [ assign ~var:bindir_nv ~value:User.bin
  ; assign ~var:mandir_nv ~value:User.man
  ]

(* checks whether this is a user or global install based on the
   current user and install path and sets variables accordingly.
   Abort if they are inconsistent e.g. the install path is
   /opt/pkg-name but we're not running as root. *)
let setup_install_kind ~installer_name ~prefix =
  let open Sh_script in
  let dirname_nv = "dir_name" in
  let dirname_v = !$ dirname_nv in
  let abort path =
    [
      echof "Not running as root. Aborting.";
      echof "Need root permission for %s" path;
      echof "Please run again as root or use the install script --prefix \
             option to set a custom install path";
      echof "You can pass options to the install script by running \
             ./%s -- <install-script-options>" installer_name;
      exit 1;
    ]
  in
  [
    if_ (Dir_exists prefix)
      [ assign ~var:dirname_nv ~value:prefix ]
      ~else_:[assign_eval dirname_nv (dirname prefix)]
      ();
    if_ (Dir_exists dirname_v) [
      if_ Is_not_root
        [ if_ (Writable_as_user dirname_v)
            (assign ~var:is_user_install_nv ~value:"true"::set_user_prefixes)
            ~else_:(abort dirname_v)
            ()
        ]
        ()
    ]
      ~else_:[
        echof "Parent directory not found: %s" dirname_v;
        echof "Aborting.";
        exit 1;
      ] ();
  ]

let set_default_mandir =
  let open Sh_script in
  [ if_ (Dir_exists Global.shareman)
      [assign ~var:mandir_nv ~value:Global.shareman]
      ~else_:[assign ~var:mandir_nv ~value:Global.man]
      ()
  ]

let set_root_prefixes =
  let open Sh_script in
  assign ~var:bindir_nv ~value:Global.bin :: set_default_mandir

let add_symlink ~install_dir ~in_ bundle_path =
  let open Sh_script in
  let base = Filename.basename bundle_path in
  symlink ~target:(install_dir / bundle_path) ~link:(in_ / base)

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
let set_install_vars ~install_dir =
  let open Sh_script in
  [ assign ~var:install_path_nv ~value:install_dir ]

let create_if_not_found dir =
  let open Sh_script in
  if_ (Not (Dir_exists dir)) [mkdir ~permissions:755 [dir]] ()

let true_install_binary ~install_dir ~env ~in_
    (binary : Installer_config.exec_file) =
  let open Sh_script in
  let bundle_path = binary.path in
  let base = Filename.basename bundle_path in
  let true_binary = install_dir / bundle_path in
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

let install_binary ~install_dir ~env ~in_ (binary : Installer_config.exec_file) =
  if binary.symlink then
    true_install_binary ~install_dir ~env ~in_ binary
  else
    []

let install_manpages ~install_dir ~in_ manpages =
  let open Sh_script in
  let install_page ~section page = add_symlink ~install_dir ~in_:section page in
  match manpages with
  | [] -> []
  | _ ->
    let install_manpages =
      List.concat_map
        (fun (section, pages) ->
           let section = in_ / section in
           mkdir ~permissions:755 [section]
           :: (List.map (install_page ~section) pages))
        manpages
    in
    echof "Installing manpages to %s..." in_
    :: install_manpages

let install_plugin ~install_dir (plugin : Installer_config.plugin) =
  let open Sh_script in
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = !$ (lib_var ~var_prefix) in
  let plugins_dir = !$ (plugins_var ~var_prefix) in
  let add_symlink_if_missing ~install_dir ~in_ path =
    let dst = in_ / (Filename.basename path) in
    if_ ((Not (Link_exists dst)) && (Not (Dir_exists dst)))
      [ add_symlink ~install_dir ~in_ path ]
      ()
  in
  [ echof "Installing plugin %s to %s..." plugin.name plugin.app_name
  ; add_symlink ~install_dir plugin.plugin_dir ~in_:plugins_dir
  ; add_symlink_if_missing ~install_dir plugin.lib_dir ~in_:lib_dir
  ]
  @ (List.map
       (fun dyn_dep -> add_symlink_if_missing ~install_dir dyn_dep ~in_:lib_dir)
       plugin.dyn_deps)

let def_check_available prefix =
  let open Sh_script in
  def_fun check_available
    [ if_ (Exists "$1")
        [
          print_errf "$1 already exists on the system! Aborting";
          print_errf "Use %s/%s to uninstall it"
            prefix uninstall_script_name;
          exit 1
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

let call_check_available path =
  Sh_script.call_fun check_available [Printf.sprintf "%S" path]

let call_check_lib path =
  Sh_script.call_fun check_lib [Printf.sprintf "%S" path]

let check_plugin_available (plugin : Installer_config.plugin) =
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = !$ (lib_var ~var_prefix) in
  let plugins_dir = !$ (plugins_var ~var_prefix) in
  let paths =
    [ lib_dir / (Filename.basename plugin.lib_dir)
    ; plugins_dir / (Filename.basename plugin.plugin_dir)
    ]
  in
  List.map call_check_available paths
  @ List.map
    (fun x -> call_check_lib (lib_dir / (Filename.basename x)))
    plugin.dyn_deps

let prompt_for_confirmation =
  let open Sh_script in
  [ prompt ~question:"Proceed? [y/N]" ~varname:"ans"
  ; case "ans"
      [ {pattern  = "[Yy]*"; commands = []}
      ; {pattern = "*"; commands = [echof "Aborted."; exit 1]}
      ]
  ]

let read_arguments =
  let open Sh_script in
  let check_arg =
    if_ (Num_op ("#",Lt,2)) [echof "Option $1 requires an argument"; exit 2] ()
  in
  while_ (Num_op ("#",Gt,0)) [
    case "1" [
      { pattern = "--prefix";
        commands = [
          check_arg;
          shift;
          assign ~var:prefix_nv ~value:"$1";
        ]};
      { pattern = "--help";
        commands = [
          call_fun "usage" [];
          exit 0
        ]};
      { pattern = "*";
        commands = [
          call_fun "usage" [];
          exit 3
        ]};
    ];
    shift;
  ]

let install_script ~installer_name (ic : Installer_config.internal) =
  let open Sh_script in
  let package = ic.name in
  let version = ic.version in
  let def_usage =
    let open Sh_script in
    [
      Printf.sprintf "Ocaml Universal Installer for %s.%s"
        package version;
      "";
      "Options:";
      Printf.sprintf
        "    --prefix PREFIX        Install bundle in PREFIX (default is %s)"
        opt;
      Printf.sprintf
        "                           If PREFIX points to a user owned directory \
         symlinks and manpage will be put in %s, otherwise (root directory) \
         in %s" User.pre Global.pre;
    ]
    |> List.map (echof "%s")
    |> def_fun "usage"
  in
  let install_dir = prefix_v / package in
  let set_prefixes =
    (* Sets the prefix variables PREFIX, BINPREFIX, MANPREFIX based
       on the CLI options and type of install (global vs user). *)
    let set_defaults =
      (* By default they are set for a global install *)
      [ assign ~var:prefix_nv ~value:opt
      ; assign ~var:is_user_install_nv ~value:"false"
      ] @ set_root_prefixes
    in
    set_defaults
    @ [read_arguments] (* PREFIX can be overwritten via --prefix *)
    @ setup_install_kind ~installer_name ~prefix:prefix_v
  in
  let plugin_apps =
    List.map (fun (p : Installer_config.plugin) -> p.app_name) ic.plugins
    |> List.sort_uniq String.compare
  in
  let all_files =
    list_all_files ~install_dir ~bindir:bindir_v ~mandir:mandir_v ic
  in
  let def_load_conf =
    match ic.plugins with
    | [] -> []
    | _ -> [def_load_conf]
  in
  let display_install_info =
    [ echof "Installing %s.%s to %s" package version install_dir
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
    List.map call_check_available all_files
    @ List.concat_map check_plugin_available ic.plugins
  in
  let create_install_dir =
    [
      create_if_not_found prefix_v;
      mkdir ~permissions:755 [install_dir];
    ]
  in
  let deffuns = [
    def_usage;
    def_check_available install_dir;
    def_check_lib;
  ] @
    def_load_conf
  in
  let setup =
    deffuns
    @ set_prefixes
    @ set_install_vars ~install_dir
    @ display_install_info
    @ display_plugin_install_info
    @ load_plugin_app_vars
    @ check_all_available
    @ prompt_for_confirmation
    @ create_install_dir
  in
  let install_bundle =
    Sh_script.copy_all_in ~src:"." ~dst:install_dir ~except:install_script_name
  in
  let env = ic.environment in
  let binaries = ic.exec_files in
  let install_binaries =
    match binaries with
    | [] -> []
    | _ ->
      create_if_not_found bindir_v ::
      List.concat_map (install_binary ~install_dir ~env ~in_:bindir_v) binaries
  in
  let manpages = Option.value ic.manpages ~default:[] in
  let install_manpages = install_manpages ~install_dir ~in_:mandir_v manpages in
  let notify_install_complete =
    [ echof "Installation complete!"
    ; echof
        "If you want to safely uninstall %s, please run %s/%s."
        package install_dir uninstall_script_name
    ]
  in
  let install_plugins = List.concat_map (install_plugin ~install_dir) ic.plugins in
  let dump_install_conf =
    let lines =
      List.filter_map (fun x -> x)
        [ Some (Printf.sprintf "%s=%s" conf_version ic.version)
        ; Some (Printf.sprintf "%s=%s" is_user_install_nv is_user_install_v)
        ; Option.map
            (fun (plgdr : Installer_config.plugin_dirs) ->
               Printf.sprintf "%s=%s" conf_plugins (install_dir / plgdr.plugins_dir))
            ic.plugin_dirs
        ; Option.map
            (fun (plgdr : Installer_config.plugin_dirs) ->
               Printf.sprintf "%s=%s" conf_lib (install_dir / plgdr.lib_dir))
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
    let install_conf = install_dir / install_conf in
    [
      Sh_script.write_file install_conf (lines @ plugin_app_lines);
      Sh_script.chmod 644 [install_conf];
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
  let lib_dir = !$ (lib_var ~var_prefix) in
  let plugins_dir = !$ (plugins_var ~var_prefix) in
  [ echof "- %s/%s" plugins_dir (b plugin.plugin_dir)
  ; echof "- %s/%s" lib_dir (b plugin.lib_dir)
  ]
  @ List.map (fun x -> echof "- %s/%s" lib_dir (b x)) plugin.dyn_deps

let uninstall_plugin (plugin : Installer_config.plugin) =
  let var_prefix = app_var_prefix plugin.app_name in
  let lib_dir = !$ (lib_var ~var_prefix) in
  let plugins_dir = !$ (plugins_var ~var_prefix) in
  [ remove_symlink ~in_:lib_dir plugin.lib_dir
  ; remove_symlink ~in_:plugins_dir plugin.plugin_dir
  ]
  @ List.map (remove_symlink ~in_:lib_dir) plugin.dyn_deps

let uninstall_script (ic : Installer_config.internal) =
  let open Sh_script in
  let (/) = Filename.concat in
  let package = ic.name in
  let install_dir_nv = "INSTALL_DIR" in
  let install_dir = !$ install_dir_nv in
  let binaries = ic.exec_files in
  let load_install_conf ~install_dir =
    [ def_load_conf
    ; call_load_conf (install_dir / install_conf)
    ]
  in
  let display_symlinks =
    List.filter_map
      (fun (binary : Installer_config.exec_file) ->
         if binary.symlink then
           Some (echof "- %s/%s" bindir_v (Filename.basename binary.path))
         else
           None
      )
      binaries
  in
  let manpages = Option.value ic.manpages ~default:[] in
  let display_manpages =
    List.concat_map
      (fun (section, pages) ->
         List.map
           (fun page ->
              echof "- %s/%s/%s" mandir_v section (Filename.basename page))
           pages)
      manpages
  in
  let display_plugins = List.concat_map display_plugin ic.plugins in
  let set_prefix_and_install_dir =
    [
      assign_eval install_dir_nv (dirname "$0");
      assign_eval prefix_nv (dirname (!$ install_dir));
    ]
  in
  let set_man_and_bin_prefixes =
    [ if_ (Str_op (Equal (is_user_install_v, "true")))
        set_user_prefixes
        ~else_:set_root_prefixes
        ()
    ]
  in
  let setup =
    set_prefix_and_install_dir
    @ load_install_conf ~install_dir
    @ set_man_and_bin_prefixes
    @ [ echof "About to uninstall %s." package
      ; echof "The following files and folders will be removed from the system:"
      ; echof "- %s" install_dir
      ]
    @ display_symlinks
    @ display_manpages
    @ display_plugins
  in
  let check_permissions =
    [ if_ Is_not_root
        [ if_ (Not (Writable_as_user install_dir))
            [ echof "Need root permission for %s" install_dir
            ; echof "Not running as root. Aborting"
            ; exit 1
            ]
            ()
        ]
        ()
    ]
  in
  let remove_install_folder =
    [ if_ (Dir_exists install_dir)
        [ echof "Removing %s..." install_dir
        ; rm_rf [install_dir]
        ]
        ()
    ]
  in
  let remove_symlinks =
    List.filter_map (fun (x : Installer_config.exec_file) ->
        if x.symlink then
          Some (remove_symlink ~in_:bindir_v x.path)
        else
          None
      ) binaries
  in
  let remove_manpages =
    List.concat_map
      (fun (section, pages) ->
         List.map
           (remove_symlink ~name:"manpage" ~in_:(mandir_v / section))
           pages)
      manpages
  in
  let remove_plugins = List.concat_map uninstall_plugin ic.plugins in
  let notify_uninstall_complete = [echof "Uninstallation complete!"] in
  setup
  @ prompt_for_confirmation
  @ check_permissions
  @ remove_install_folder
  @ remove_symlinks
  @ remove_manpages
  @ remove_plugins
  @ notify_uninstall_complete

let add_sos_to_bundle ~bundle_dir (binary : Installer_config.exec_file) =
  let binary = OpamFilename.Op.(bundle_dir // binary.path) in
  let sos = Ldd.get_sos binary in
  match sos with
  | [] -> ()
  | _ ->
    let dst_dir = OpamFilename.dirname binary in
    List.iter (fun so -> OpamFilename.copy_in so dst_dir) sos;
    System.call_unit Patchelf (Set_rpath {rpath = "$ORIGIN"; binary})

let add_sos_to_bundle ~bundle_dir (binary : Installer_config.exec_file) =
  if binary.deps then
    add_sos_to_bundle ~bundle_dir binary

let update_mtime mtime bundle_dir =
  let files =
    OpamFilename.rec_files bundle_dir
    |> List.map OpamFilename.to_string
  in
  let dirs =
    OpamFilename.rec_dirs bundle_dir
    |> List.map OpamFilename.Dir.to_string
  in
  System.call_list
    (List.map (fun file -> System.Touch, {System.mtime; file})
       (dirs @ files))

let create_installer ?mtime ?tar_extra
    ~(installer_config : Installer_config.internal) ~bundle_dir installer =
  check_makeself_installed ();
  OpamConsole.formatted_msg "Preparing makeself archive... \n";
  List.iter (add_sos_to_bundle ~bundle_dir) installer_config.exec_files;
  let installer_name = OpamFilename.(basename installer |> Base.to_string) in
  let install_script = install_script ~installer_name installer_config in
  let uninstall_script = uninstall_script installer_config in
  let install_sh = OpamFilename.Op.(bundle_dir // install_script_name) in
  let uninstall_sh = OpamFilename.Op.(bundle_dir // uninstall_script_name) in
  Sh_script.save install_script install_sh;
  Sh_script.save uninstall_script uninstall_sh;
  System.call_unit Chmod (755, install_sh);
  System.call_unit Chmod (755, uninstall_sh);
  Option.iter (fun mtime -> update_mtime mtime bundle_dir) mtime;
  let tar_extra =
    match tar_extra with
    | None ->
      [
        "--numeric-owner";
        "--owner=0";
        "--group=0";
        (* "--sort=name"; *)
        (* --sort is not defined for bsdtar, which can be used by makeself
           tar selection:
           > TAR=`exec <&- 2>&-; which gtar || command -v gtar || type gtar`
           > test -x "$TAR" || TAR=`exec <&- 2>&-; which bsdtar || command -v bsdtar || type bsdtar`
           > test -x "$TAR" || TAR=tar
        *)
      ]
    | Some l -> l
  in
  let args : System.makeself =
    { archive_dir = bundle_dir
    ; installer
    ; description = installer_config.name
    ; startup_script = Format.sprintf "./%s" install_script_name
    ; tar_extra
    }
  in
  OpamConsole.formatted_msg
    "Generating standalone installer %s...\n"
    (OpamFilename.to_string installer);
  System.call_unit Makeself args;
  OpamConsole.formatted_msg "Done.\n"
