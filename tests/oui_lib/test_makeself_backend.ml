(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui
open Installer_config

let make_expanded_manpages
    ?(man1=[])
    ?(man2=[])
    ?(man3=[])
    ?(man4=[])
    ?(man5=[])
    ?(man6=[])
    ?(man7=[])
    ?(man8=[])
    ()
  =
  [ ("man1", man1)
  ; ("man2", man2)
  ; ("man3", man3)
  ; ("man4", man4)
  ; ("man5", man5)
  ; ("man6", man6)
  ; ("man7", man7)
  ; ("man8", man8)
  ]
  |> List.filter_map (function _, [] -> None | x -> Some x)

let make_config
    ?(name="test-name")
    ?(version="test.version")
    ?(exec_files=[])
    ?(plugins=[])
    ?plugin_dirs
    ?manpages
    ?(environment=[])
    () : Installer_config.internal
  =
  { name
  ; version
  ; exec_files
  ; fullname = ""
  ; manpages
  ; environment
  ; unique_id = ""
  ; plugins
  ; plugin_dirs
  ; wix_manufacturer = ""
  ; wix_description = None
  ; wix_tags = []
  ; wix_icon_file = None
  ; wix_dlg_bmp_file = None
  ; wix_banner_bmp_file = None
  ; wix_license_file = None
  ; macos_symlink_dirs = []
  }

let%expect_test "install_script: simple" =
  let manpages =
    make_expanded_manpages
      ~man1:["man/man1/aaa-command.1"; "man/man1/aaa-utility.1"]
      ~man5:["man/man5/aaa-file.1"]
      ()
  in
  let config =
    make_config ~name:"aaa" ~version:"x.y.z"
      ~exec_files:["aaa-command"; "aaa-utility"]
      ~manpages
      ()
  in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    INSTALL_PATH="/opt/aaa"
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "Installing aaa.x.y.z to /opt/aaa"
    echo "The following files and directories will be written to the system:"
    echo "- /opt/aaa"
    echo "- /usr/local/bin/aaa-command"
    echo "- /usr/local/bin/aaa-utility"
    echo "- $MAN_DEST/man1/aaa-command.1"
    echo "- $MAN_DEST/man1/aaa-utility.1"
    echo "- $MAN_DEST/man5/aaa-file.1"
    check_available /opt/aaa
    check_available /usr/local/bin/aaa-command
    check_available /usr/local/bin/aaa-utility
    check_available $MAN_DEST/man1/aaa-command.1
    check_available $MAN_DEST/man1/aaa-utility.1
    check_available $MAN_DEST/man5/aaa-file.1
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p -m 755 "/opt/aaa"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} /opt/aaa \;
    echo "Adding aaa-command to /usr/local/bin"
    ln -s /opt/aaa/aaa-command /usr/local/bin/aaa-command
    echo "Adding aaa-utility to /usr/local/bin"
    ln -s /opt/aaa/aaa-utility /usr/local/bin/aaa-utility
    echo "Installing manpages to $MAN_DEST..."
    mkdir -p -m 755 "$MAN_DEST/man1"
    ln -s /opt/aaa/man/man1/aaa-command.1 $MAN_DEST/man1/aaa-command.1
    ln -s /opt/aaa/man/man1/aaa-utility.1 $MAN_DEST/man1/aaa-utility.1
    mkdir -p -m 755 "$MAN_DEST/man5"
    ln -s /opt/aaa/man/man5/aaa-file.1 $MAN_DEST/man5/aaa-file.1
    {
      printf '%s\n' "version=x.y.z"
    } > "/opt/aaa/install.conf"
    chmod 644 "/opt/aaa/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall aaa, please run /opt/aaa/uninstall.sh."
    |}]

let%expect_test "install_script: plugin_dirs dumped in install.conf" =
  let plugin_dirs : Installer_config.plugin_dirs =
    {plugins_dir = "path/to/plugins"; lib_dir = "path/to/lib"}
  in
  let config = make_config ~name:"t-name" ~version:"t.version" ~plugin_dirs () in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    INSTALL_PATH="/opt/t-name"
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "Installing t-name.t.version to /opt/t-name"
    echo "The following files and directories will be written to the system:"
    echo "- /opt/t-name"
    check_available /opt/t-name
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p -m 755 "/opt/t-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} /opt/t-name \;
    {
      printf '%s\n' "version=t.version"
      printf '%s\n' "plugins=/opt/t-name/path/to/plugins"
      printf '%s\n' "lib=/opt/t-name/path/to/lib"
    } > "/opt/t-name/install.conf"
    chmod 644 "/opt/t-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall t-name, please run /opt/t-name/uninstall.sh."
    |}]

let%expect_test "install_script: install plugins" =
  let open Installer_config in
  let app_a_plugin =
    { name = "app-a-name"
    ; app_name = "app-a"
    ; plugin_dir = "lib/app-a/plugins/name"
    ; lib_dir = "lib/app-a-name"
    ; dyn_deps = []
    }
  in
  let app_b_plugin =
    { name = "app-b-name"
    ; app_name = "app-b"
    ; plugin_dir = "lib/app-b/plugins/name"
    ; lib_dir = "lib/app-b-name"
    ; dyn_deps = ["lib/dep-a"; "lib/dep-b"]
    }
  in
  let config =
    make_config ~name:"t-name" ~version:"t.version"
      ~plugins:[app_a_plugin; app_b_plugin] ()
  in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    load_conf() {
      var_prefix="$2"
      conf="$1"
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ""|\#*)
            continue
          ;;
        esac
        case "$line" in
          *=*) ;;
          *)
            printf '%s\n' "Invalid line in $conf: $line" >&2
            return 1
          ;;
        esac
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
          *[!a-zA-Z0-9_]*)
            printf '%s\n' "Invalid configuration key in $conf: $key" >&2
            return 1
          ;;
          *)
            eval "$var_prefix$key=\$val"
          ;;
        esac
      done < "$conf"
      return 0
    }
    INSTALL_PATH="/opt/t-name"
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "Installing t-name.t.version to /opt/t-name"
    echo "The following files and directories will be written to the system:"
    echo "- /opt/t-name"
    echo "The following plugins will be installed:"
    echo "- app-a-name for app-a"
    echo "- app-b-name for app-b"
    if [ -d "/opt/app-a" ] && [ -f "/opt/app-a/install.conf" ]; then
      load_conf /opt/app-a/install.conf app_a_
    else
      printf '%s\n' "Could not locate app-a install path" >&2
      exit 1
    fi
    if [ -d "/opt/app-b" ] && [ -f "/opt/app-b/install.conf" ]; then
      load_conf /opt/app-b/install.conf app_b_
    else
      printf '%s\n' "Could not locate app-b install path" >&2
      exit 1
    fi
    check_available /opt/t-name
    check_available $app_a_lib/app-a-name
    check_available $app_a_plugins/name
    check_available $app_b_lib/app-b-name
    check_available $app_b_plugins/name
    check_lib $app_b_lib/dep-a
    check_lib $app_b_lib/dep-b
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p -m 755 "/opt/t-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} /opt/t-name \;
    echo "Installing plugin app-a-name to app-a..."
    ln -s /opt/t-name/lib/app-a/plugins/name $app_a_plugins/name
    if ! [ -L "$app_a_lib/app-a-name" ] && ! [ -d "$app_a_lib/app-a-name" ]; then
      ln -s /opt/t-name/lib/app-a-name $app_a_lib/app-a-name
    fi
    echo "Installing plugin app-b-name to app-b..."
    ln -s /opt/t-name/lib/app-b/plugins/name $app_b_plugins/name
    if ! [ -L "$app_b_lib/app-b-name" ] && ! [ -d "$app_b_lib/app-b-name" ]; then
      ln -s /opt/t-name/lib/app-b-name $app_b_lib/app-b-name
    fi
    if ! [ -L "$app_b_lib/dep-a" ] && ! [ -d "$app_b_lib/dep-a" ]; then
      ln -s /opt/t-name/lib/dep-a $app_b_lib/dep-a
    fi
    if ! [ -L "$app_b_lib/dep-b" ] && ! [ -d "$app_b_lib/dep-b" ]; then
      ln -s /opt/t-name/lib/dep-b $app_b_lib/dep-b
    fi
    {
      printf '%s\n' "version=t.version"
      printf '%s\n' "app_a_lib=$app_a_lib"
      printf '%s\n' "app_a_plugins=$app_a_plugins"
      printf '%s\n' "app_b_lib=$app_b_lib"
      printf '%s\n' "app_b_plugins=$app_b_plugins"
    } > "/opt/t-name/install.conf"
    chmod 644 "/opt/t-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall t-name, please run /opt/t-name/uninstall.sh."
    |}]

let%expect_test "uninstall_script: uninstall plugins" =
  let open Installer_config in
  let app_a_plugin =
    { name = "app-a-name"
    ; app_name = "app-a"
    ; plugin_dir = "lib/app-a/plugins/name"
    ; lib_dir = "lib/app-a-name"
    ; dyn_deps = []
    }
  in
  let app_b_plugin =
    { name = "app-b-name"
    ; app_name = "app-b"
    ; plugin_dir = "lib/app-b/plugins/name"
    ; lib_dir = "lib/app-b-name"
    ; dyn_deps = ["lib/dep-a"; "lib/dep-b"]
    }
  in
  let config =
    make_config ~name:"t-name" ~version:"t.version"
      ~plugins:[app_a_plugin; app_b_plugin] ()
  in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" Sh_script.pp_sh uninstall_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    load_conf() {
      var_prefix="$2"
      conf="$1"
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ""|\#*)
            continue
          ;;
        esac
        case "$line" in
          *=*) ;;
          *)
            printf '%s\n' "Invalid line in $conf: $line" >&2
            return 1
          ;;
        esac
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
          *[!a-zA-Z0-9_]*)
            printf '%s\n' "Invalid configuration key in $conf: $key" >&2
            return 1
          ;;
          *)
            eval "$var_prefix$key=\$val"
          ;;
        esac
      done < "$conf"
      return 0
    }
    load_conf /opt/t-name/install.conf
    echo "About to uninstall t-name."
    echo "The following files and folders will be removed from the system:"
    echo "- /opt/t-name"
    echo "- $app_a_plugins/name"
    echo "- $app_a_lib/app-a-name"
    echo "- $app_b_plugins/name"
    echo "- $app_b_lib/app-b-name"
    echo "- $app_b_lib/dep-a"
    echo "- $app_b_lib/dep-b"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ -d "/opt/t-name" ]; then
      echo "Removing /opt/t-name..."
      rm -rf "/opt/t-name"
    fi
    if [ -L "$app_a_lib/app-a-name" ]; then
      echo "Removing symlink $app_a_lib/app-a-name..."
      rm -f "$app_a_lib/app-a-name"
    fi
    if [ -L "$app_a_plugins/name" ]; then
      echo "Removing symlink $app_a_plugins/name..."
      rm -f "$app_a_plugins/name"
    fi
    if [ -L "$app_b_lib/app-b-name" ]; then
      echo "Removing symlink $app_b_lib/app-b-name..."
      rm -f "$app_b_lib/app-b-name"
    fi
    if [ -L "$app_b_plugins/name" ]; then
      echo "Removing symlink $app_b_plugins/name..."
      rm -f "$app_b_plugins/name"
    fi
    if [ -L "$app_b_lib/dep-a" ]; then
      echo "Removing symlink $app_b_lib/dep-a..."
      rm -f "$app_b_lib/dep-a"
    fi
    if [ -L "$app_b_lib/dep-b" ]; then
      echo "Removing symlink $app_b_lib/dep-b..."
      rm -f "$app_b_lib/dep-b"
    fi
    echo "Uninstallation complete!"
    |}]

let%expect_test "uninstall_script: simple" =
  let manpages =
    make_expanded_manpages
      ~man1:["man/man1/aaa-command.1"; "man/man1/aaa-utility.1"]
      ~man5:["man/man5/aaa-file.1"]
      ()
  in
  let config =
    make_config ~name:"aaa"
      ~exec_files:["aaa-command"; "aaa-utility"]
      ~manpages
      ()
  in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" Sh_script.pp_sh uninstall_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "About to uninstall aaa."
    echo "The following files and folders will be removed from the system:"
    echo "- /opt/aaa"
    echo "- /usr/local/bin/aaa-command"
    echo "- /usr/local/bin/aaa-utility"
    echo "- $MAN_DEST/man1/aaa-command.1"
    echo "- $MAN_DEST/man1/aaa-utility.1"
    echo "- $MAN_DEST/man5/aaa-file.1"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ -d "/opt/aaa" ]; then
      echo "Removing /opt/aaa..."
      rm -rf "/opt/aaa"
    fi
    if [ -L "/usr/local/bin/aaa-command" ]; then
      echo "Removing symlink /usr/local/bin/aaa-command..."
      rm -f "/usr/local/bin/aaa-command"
    fi
    if [ -L "/usr/local/bin/aaa-utility" ]; then
      echo "Removing symlink /usr/local/bin/aaa-utility..."
      rm -f "/usr/local/bin/aaa-utility"
    fi
    if [ -L "$MAN_DEST/man1/aaa-command.1" ]; then
      echo "Removing manpage $MAN_DEST/man1/aaa-command.1..."
      rm -f "$MAN_DEST/man1/aaa-command.1"
    fi
    if [ -L "$MAN_DEST/man1/aaa-utility.1" ]; then
      echo "Removing manpage $MAN_DEST/man1/aaa-utility.1..."
      rm -f "$MAN_DEST/man1/aaa-utility.1"
    fi
    if [ -L "$MAN_DEST/man5/aaa-file.1" ]; then
      echo "Removing manpage $MAN_DEST/man5/aaa-file.1..."
      rm -f "$MAN_DEST/man5/aaa-file.1"
    fi
    echo "Uninstallation complete!"
    |}]

(* Regression test that ensures that if the binaries are not at the bundle's
   root, the symlink are still installed correctly. *)
let%expect_test "install_script: binary in sub folder" =
  let config = make_config ~exec_files:["bin/do"] () in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    INSTALL_PATH="/opt/test-name"
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "Installing test-name.test.version to /opt/test-name"
    echo "The following files and directories will be written to the system:"
    echo "- /opt/test-name"
    echo "- /usr/local/bin/do"
    check_available /opt/test-name
    check_available /usr/local/bin/do
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p -m 755 "/opt/test-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} /opt/test-name \;
    echo "Adding do to /usr/local/bin"
    ln -s /opt/test-name/bin/do /usr/local/bin/do
    {
      printf '%s\n' "version=test.version"
    } > "/opt/test-name/install.conf"
    chmod 644 "/opt/test-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall test-name, please run /opt/test-name/uninstall.sh."
    |}]

(* Regression test that ensures that if the binaries are not at the bundle's
   root, the symlinks are correctly removed by the uninstall script. *)
let%expect_test "uninstall_script: binary in sub folder" =
  let config = make_config ~exec_files:["bin/do"] () in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" Sh_script.pp_sh uninstall_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "About to uninstall test-name."
    echo "The following files and folders will be removed from the system:"
    echo "- /opt/test-name"
    echo "- /usr/local/bin/bin/do"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ -d "/opt/test-name" ]; then
      echo "Removing /opt/test-name..."
      rm -rf "/opt/test-name"
    fi
    if [ -L "/usr/local/bin/do" ]; then
      echo "Removing symlink /usr/local/bin/do..."
      rm -f "/usr/local/bin/do"
    fi
    echo "Uninstallation complete!"
    |}]

let%expect_test "install_script: set environment for binaries" =
  let config =
    make_config
      ~exec_files:["bin/app"]
      ~environment:[("VAR1", "value1"); ("VAR2", "$INSTALL_PATH/lib")]
      ()
  in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    INSTALL_PATH="/opt/test-name"
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    echo "Installing test-name.test.version to /opt/test-name"
    echo "The following files and directories will be written to the system:"
    echo "- /opt/test-name"
    echo "- /usr/local/bin/app"
    check_available /opt/test-name
    check_available /usr/local/bin/app
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p -m 755 "/opt/test-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} /opt/test-name \;
    echo "Adding app to /usr/local/bin"
    {
      printf '%s\n' "#!/usr/bin/env sh"
      printf '%s\n' "VAR1=\"value1\" \"
      printf '%s\n' "VAR2=\"$INSTALL_PATH/lib\" \"
      printf '%s\n' "exec /opt/test-name/bin/app \"\$@\""
    } > "/usr/local/bin/app"
    chmod 755 "/usr/local/bin/app"
    {
      printf '%s\n' "version=test.version"
    } > "/opt/test-name/install.conf"
    chmod 644 "/opt/test-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall test-name, please run /opt/test-name/uninstall.sh."
    |}]
