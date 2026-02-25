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

let pp_sh = Sh_script.pp_sh ~version:false

let%expect_test "install_script: simple" =
  let manpages =
    make_expanded_manpages
      ~man1:["man/man1/aaa-command.1"; "man/man1/aaa-utility.1"]
      ~man5:["man/man5/aaa-file.1"]
      ()
  in
  let config =
    make_config ~name:"aaa" ~version:"x.y.z"
      ~exec_files:[{ path = "aaa-command"; symlink = true; deps = true };
                   { path = "aaa-utility"; symlink = true; deps = true } ]
      ~manpages
      ()
  in
  let installer_name = "aaa-x-y-z.run" in
  let install_script = Makeself_backend.install_script ~installer_name config in
  Format.printf "%a" pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    usage() {
      echo "Ocaml Universal Installer for aaa.x.y.z"
      echo ""
      echo "Options:"
      echo "    --prefix PREFIX        Install bundle in PREFIX (default is /opt)"
      echo "                           If PREFIX points to a user owned directory symlinks and manpage will be put in $HOME/.local, otherwise (root directory) in /usr/local"
    }
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        printf '%s\n' "Use $PREFIX/aaa/uninstall.sh to uninstall it" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    PREFIX="/opt"
    IS_USER_INSTALL="false"
    BINDIR="/usr/local/bin"
    if [ -d "/usr/local/share/man" ]; then
      MANDIR="/usr/local/share/man"
    else
      MANDIR="/usr/local/man"
    fi
    while [ $# -gt 0 ]; do
      case "$1" in
        --prefix)
          if [ $# -lt 2 ]; then
            echo "Option $1 requires an argument"
            exit 2
          fi
          shift
          PREFIX="$1"
        ;;
        --help)
          usage
          exit 0
        ;;
        *)
          usage
          exit 3
        ;;
      esac
      shift
    done
    if [ -d "$PREFIX" ]; then
      dir_name="$PREFIX"
    else
      dir_name="$(dirname "$PREFIX")"
    fi
    if [ -d "$dir_name" ]; then
      if [ "$(id -u)" -ne 0 ]; then
        if [ -w "$dir_name" ]; then
          IS_USER_INSTALL="true"
          BINDIR="$HOME/.local/bin"
          MANDIR="$HOME/.local/man"
        else
          echo "Not running as root. Aborting."
          echo "Need root permission for $dir_name"
          echo "Please run again as root or use the install script --prefix option to set a custom install path"
          echo "You can pass options to the install script by running ./aaa-x-y-z.run -- <install-script-options>"
          exit 1
        fi
      fi
    else
      echo "Parent directory not found: $dir_name"
      echo "Aborting."
      exit 1
    fi
    INSTALL_PATH="$PREFIX/aaa"
    echo "Installing aaa.x.y.z to $PREFIX/aaa"
    echo "The following files and directories will be written to the system:"
    echo "- $PREFIX/aaa"
    echo "- $BINDIR/aaa-command"
    echo "- $BINDIR/aaa-utility"
    echo "- $MANDIR/man1/aaa-command.1"
    echo "- $MANDIR/man1/aaa-utility.1"
    echo "- $MANDIR/man5/aaa-file.1"
    check_available "$PREFIX/aaa"
    check_available "$BINDIR/aaa-command"
    check_available "$BINDIR/aaa-utility"
    check_available "$MANDIR/man1/aaa-command.1"
    check_available "$MANDIR/man1/aaa-utility.1"
    check_available "$MANDIR/man5/aaa-file.1"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if ! [ -d "$PREFIX" ]; then
      mkdir -p -m 755 "$PREFIX"
    fi
    mkdir -p -m 755 "$PREFIX/aaa"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} "$PREFIX/aaa" \;
    if ! [ -d "$BINDIR" ]; then
      mkdir -p -m 755 "$BINDIR"
    fi
    echo "Adding aaa-command to $BINDIR"
    ln -s "$PREFIX/aaa/aaa-command" "$BINDIR/aaa-command"
    echo "Adding aaa-utility to $BINDIR"
    ln -s "$PREFIX/aaa/aaa-utility" "$BINDIR/aaa-utility"
    echo "Installing manpages to $MANDIR..."
    mkdir -p -m 755 "$MANDIR/man1"
    ln -s "$PREFIX/aaa/man/man1/aaa-command.1" "$MANDIR/man1/aaa-command.1"
    ln -s "$PREFIX/aaa/man/man1/aaa-utility.1" "$MANDIR/man1/aaa-utility.1"
    mkdir -p -m 755 "$MANDIR/man5"
    ln -s "$PREFIX/aaa/man/man5/aaa-file.1" "$MANDIR/man5/aaa-file.1"
    {
      printf '%s\n' "version=x.y.z"
      printf '%s\n' "IS_USER_INSTALL=$IS_USER_INSTALL"
    } > "$PREFIX/aaa/install.conf"
    chmod 644 "$PREFIX/aaa/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall aaa, please run $PREFIX/aaa/uninstall.sh."
    |}]

let%expect_test "install_script: plugin_dirs dumped in install.conf" =
  let plugin_dirs : Installer_config.plugin_dirs =
    {plugins_dir = "path/to/plugins"; lib_dir = "path/to/lib"}
  in
  let config = make_config ~name:"t-name" ~version:"t.version" ~plugin_dirs () in
  let installer_name = "t-name-t-version.run" in
  let install_script = Makeself_backend.install_script ~installer_name config in
  Format.printf "%a" pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    usage() {
      echo "Ocaml Universal Installer for t-name.t.version"
      echo ""
      echo "Options:"
      echo "    --prefix PREFIX        Install bundle in PREFIX (default is /opt)"
      echo "                           If PREFIX points to a user owned directory symlinks and manpage will be put in $HOME/.local, otherwise (root directory) in /usr/local"
    }
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        printf '%s\n' "Use $PREFIX/t-name/uninstall.sh to uninstall it" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    PREFIX="/opt"
    IS_USER_INSTALL="false"
    BINDIR="/usr/local/bin"
    if [ -d "/usr/local/share/man" ]; then
      MANDIR="/usr/local/share/man"
    else
      MANDIR="/usr/local/man"
    fi
    while [ $# -gt 0 ]; do
      case "$1" in
        --prefix)
          if [ $# -lt 2 ]; then
            echo "Option $1 requires an argument"
            exit 2
          fi
          shift
          PREFIX="$1"
        ;;
        --help)
          usage
          exit 0
        ;;
        *)
          usage
          exit 3
        ;;
      esac
      shift
    done
    if [ -d "$PREFIX" ]; then
      dir_name="$PREFIX"
    else
      dir_name="$(dirname "$PREFIX")"
    fi
    if [ -d "$dir_name" ]; then
      if [ "$(id -u)" -ne 0 ]; then
        if [ -w "$dir_name" ]; then
          IS_USER_INSTALL="true"
          BINDIR="$HOME/.local/bin"
          MANDIR="$HOME/.local/man"
        else
          echo "Not running as root. Aborting."
          echo "Need root permission for $dir_name"
          echo "Please run again as root or use the install script --prefix option to set a custom install path"
          echo "You can pass options to the install script by running ./t-name-t-version.run -- <install-script-options>"
          exit 1
        fi
      fi
    else
      echo "Parent directory not found: $dir_name"
      echo "Aborting."
      exit 1
    fi
    INSTALL_PATH="$PREFIX/t-name"
    echo "Installing t-name.t.version to $PREFIX/t-name"
    echo "The following files and directories will be written to the system:"
    echo "- $PREFIX/t-name"
    check_available "$PREFIX/t-name"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if ! [ -d "$PREFIX" ]; then
      mkdir -p -m 755 "$PREFIX"
    fi
    mkdir -p -m 755 "$PREFIX/t-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} "$PREFIX/t-name" \;
    {
      printf '%s\n' "version=t.version"
      printf '%s\n' "IS_USER_INSTALL=$IS_USER_INSTALL"
      printf '%s\n' "plugins=$PREFIX/t-name/path/to/plugins"
      printf '%s\n' "lib=$PREFIX/t-name/path/to/lib"
    } > "$PREFIX/t-name/install.conf"
    chmod 644 "$PREFIX/t-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall t-name, please run $PREFIX/t-name/uninstall.sh."
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
  let installer_name = "t-name-t-version.run" in
  let install_script = Makeself_backend.install_script ~installer_name config in
  Format.printf "%a" pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    usage() {
      echo "Ocaml Universal Installer for t-name.t.version"
      echo ""
      echo "Options:"
      echo "    --prefix PREFIX        Install bundle in PREFIX (default is /opt)"
      echo "                           If PREFIX points to a user owned directory symlinks and manpage will be put in $HOME/.local, otherwise (root directory) in /usr/local"
    }
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        printf '%s\n' "Use $PREFIX/t-name/uninstall.sh to uninstall it" >&2
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
    PREFIX="/opt"
    IS_USER_INSTALL="false"
    BINDIR="/usr/local/bin"
    if [ -d "/usr/local/share/man" ]; then
      MANDIR="/usr/local/share/man"
    else
      MANDIR="/usr/local/man"
    fi
    while [ $# -gt 0 ]; do
      case "$1" in
        --prefix)
          if [ $# -lt 2 ]; then
            echo "Option $1 requires an argument"
            exit 2
          fi
          shift
          PREFIX="$1"
        ;;
        --help)
          usage
          exit 0
        ;;
        *)
          usage
          exit 3
        ;;
      esac
      shift
    done
    if [ -d "$PREFIX" ]; then
      dir_name="$PREFIX"
    else
      dir_name="$(dirname "$PREFIX")"
    fi
    if [ -d "$dir_name" ]; then
      if [ "$(id -u)" -ne 0 ]; then
        if [ -w "$dir_name" ]; then
          IS_USER_INSTALL="true"
          BINDIR="$HOME/.local/bin"
          MANDIR="$HOME/.local/man"
        else
          echo "Not running as root. Aborting."
          echo "Need root permission for $dir_name"
          echo "Please run again as root or use the install script --prefix option to set a custom install path"
          echo "You can pass options to the install script by running ./t-name-t-version.run -- <install-script-options>"
          exit 1
        fi
      fi
    else
      echo "Parent directory not found: $dir_name"
      echo "Aborting."
      exit 1
    fi
    INSTALL_PATH="$PREFIX/t-name"
    echo "Installing t-name.t.version to $PREFIX/t-name"
    echo "The following files and directories will be written to the system:"
    echo "- $PREFIX/t-name"
    echo "The following plugins will be installed:"
    echo "- app-a-name for app-a"
    echo "- app-b-name for app-b"
    if [ -d "$PREFIX/app-a" ] && [ -f "$PREFIX/app-a/install.conf" ]; then
      load_conf $PREFIX/app-a/install.conf app_a_
    else
      printf '%s\n' "Could not locate app-a install path" >&2
      exit 1
    fi
    if [ -d "$PREFIX/app-b" ] && [ -f "$PREFIX/app-b/install.conf" ]; then
      load_conf $PREFIX/app-b/install.conf app_b_
    else
      printf '%s\n' "Could not locate app-b install path" >&2
      exit 1
    fi
    check_available "$PREFIX/t-name"
    check_available "$app_a_lib/app-a-name"
    check_available "$app_a_plugins/name"
    check_available "$app_b_lib/app-b-name"
    check_available "$app_b_plugins/name"
    check_lib "$app_b_lib/dep-a"
    check_lib "$app_b_lib/dep-b"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if ! [ -d "$PREFIX" ]; then
      mkdir -p -m 755 "$PREFIX"
    fi
    mkdir -p -m 755 "$PREFIX/t-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} "$PREFIX/t-name" \;
    echo "Installing plugin app-a-name to app-a..."
    ln -s "$PREFIX/t-name/lib/app-a/plugins/name" "$app_a_plugins/name"
    if ! [ -L "$app_a_lib/app-a-name" ] && ! [ -d "$app_a_lib/app-a-name" ]; then
      ln -s "$PREFIX/t-name/lib/app-a-name" "$app_a_lib/app-a-name"
    fi
    echo "Installing plugin app-b-name to app-b..."
    ln -s "$PREFIX/t-name/lib/app-b/plugins/name" "$app_b_plugins/name"
    if ! [ -L "$app_b_lib/app-b-name" ] && ! [ -d "$app_b_lib/app-b-name" ]; then
      ln -s "$PREFIX/t-name/lib/app-b-name" "$app_b_lib/app-b-name"
    fi
    if ! [ -L "$app_b_lib/dep-a" ] && ! [ -d "$app_b_lib/dep-a" ]; then
      ln -s "$PREFIX/t-name/lib/dep-a" "$app_b_lib/dep-a"
    fi
    if ! [ -L "$app_b_lib/dep-b" ] && ! [ -d "$app_b_lib/dep-b" ]; then
      ln -s "$PREFIX/t-name/lib/dep-b" "$app_b_lib/dep-b"
    fi
    {
      printf '%s\n' "version=t.version"
      printf '%s\n' "IS_USER_INSTALL=$IS_USER_INSTALL"
      printf '%s\n' "app_a_lib=$app_a_lib"
      printf '%s\n' "app_a_plugins=$app_a_plugins"
      printf '%s\n' "app_b_lib=$app_b_lib"
      printf '%s\n' "app_b_plugins=$app_b_plugins"
    } > "$PREFIX/t-name/install.conf"
    chmod 644 "$PREFIX/t-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall t-name, please run $PREFIX/t-name/uninstall.sh."
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
  Format.printf "%a" pp_sh uninstall_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    INSTALL_DIR="$(dirname "$0")"
    PREFIX="$(dirname "$$INSTALL_DIR")"
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
    load_conf $INSTALL_DIR/install.conf
    if [ "$IS_USER_INSTALL" = "true" ]; then
      BINDIR="$HOME/.local/bin"
      MANDIR="$HOME/.local/man"
    else
      BINDIR="/usr/local/bin"
      if [ -d "/usr/local/share/man" ]; then
        MANDIR="/usr/local/share/man"
      else
        MANDIR="/usr/local/man"
      fi
    fi
    echo "About to uninstall t-name."
    echo "The following files and folders will be removed from the system:"
    echo "- $INSTALL_DIR"
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
    if [ "$(id -u)" -ne 0 ]; then
      if ! [ -w "$INSTALL_DIR" ]; then
        echo "Need root permission for $INSTALL_DIR"
        echo "Not running as root. Aborting"
        exit 1
      fi
    fi
    if [ -d "$INSTALL_DIR" ]; then
      echo "Removing $INSTALL_DIR..."
      rm -rf "$INSTALL_DIR"
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
      ~exec_files:[{ path = "aaa-command"; symlink = true; deps = true };
                   { path = "aaa-utility"; symlink = true; deps = true } ]
      ~manpages
      ()
  in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" pp_sh uninstall_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    INSTALL_DIR="$(dirname "$0")"
    PREFIX="$(dirname "$$INSTALL_DIR")"
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
    load_conf $INSTALL_DIR/install.conf
    if [ "$IS_USER_INSTALL" = "true" ]; then
      BINDIR="$HOME/.local/bin"
      MANDIR="$HOME/.local/man"
    else
      BINDIR="/usr/local/bin"
      if [ -d "/usr/local/share/man" ]; then
        MANDIR="/usr/local/share/man"
      else
        MANDIR="/usr/local/man"
      fi
    fi
    echo "About to uninstall aaa."
    echo "The following files and folders will be removed from the system:"
    echo "- $INSTALL_DIR"
    echo "- $BINDIR/aaa-command"
    echo "- $BINDIR/aaa-utility"
    echo "- $MANDIR/man1/aaa-command.1"
    echo "- $MANDIR/man1/aaa-utility.1"
    echo "- $MANDIR/man5/aaa-file.1"
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
      if ! [ -w "$INSTALL_DIR" ]; then
        echo "Need root permission for $INSTALL_DIR"
        echo "Not running as root. Aborting"
        exit 1
      fi
    fi
    if [ -d "$INSTALL_DIR" ]; then
      echo "Removing $INSTALL_DIR..."
      rm -rf "$INSTALL_DIR"
    fi
    if [ -L "$BINDIR/aaa-command" ]; then
      echo "Removing symlink $BINDIR/aaa-command..."
      rm -f "$BINDIR/aaa-command"
    fi
    if [ -L "$BINDIR/aaa-utility" ]; then
      echo "Removing symlink $BINDIR/aaa-utility..."
      rm -f "$BINDIR/aaa-utility"
    fi
    if [ -L "$MANDIR/man1/aaa-command.1" ]; then
      echo "Removing manpage $MANDIR/man1/aaa-command.1..."
      rm -f "$MANDIR/man1/aaa-command.1"
    fi
    if [ -L "$MANDIR/man1/aaa-utility.1" ]; then
      echo "Removing manpage $MANDIR/man1/aaa-utility.1..."
      rm -f "$MANDIR/man1/aaa-utility.1"
    fi
    if [ -L "$MANDIR/man5/aaa-file.1" ]; then
      echo "Removing manpage $MANDIR/man5/aaa-file.1..."
      rm -f "$MANDIR/man5/aaa-file.1"
    fi
    echo "Uninstallation complete!"
    |}]

(* Regression test that ensures that if the binaries are not at the bundle's
   root, the symlink are still installed correctly. *)
let%expect_test "install_script: binary in sub folder" =
  let config = make_config ~exec_files:[{ path = "bin/do"; symlink = true; deps = true }] () in
  let installer_name = "installer.run" in
  let install_script = Makeself_backend.install_script ~installer_name config in
  Format.printf "%a" pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    usage() {
      echo "Ocaml Universal Installer for test-name.test.version"
      echo ""
      echo "Options:"
      echo "    --prefix PREFIX        Install bundle in PREFIX (default is /opt)"
      echo "                           If PREFIX points to a user owned directory symlinks and manpage will be put in $HOME/.local, otherwise (root directory) in /usr/local"
    }
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        printf '%s\n' "Use $PREFIX/test-name/uninstall.sh to uninstall it" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    PREFIX="/opt"
    IS_USER_INSTALL="false"
    BINDIR="/usr/local/bin"
    if [ -d "/usr/local/share/man" ]; then
      MANDIR="/usr/local/share/man"
    else
      MANDIR="/usr/local/man"
    fi
    while [ $# -gt 0 ]; do
      case "$1" in
        --prefix)
          if [ $# -lt 2 ]; then
            echo "Option $1 requires an argument"
            exit 2
          fi
          shift
          PREFIX="$1"
        ;;
        --help)
          usage
          exit 0
        ;;
        *)
          usage
          exit 3
        ;;
      esac
      shift
    done
    if [ -d "$PREFIX" ]; then
      dir_name="$PREFIX"
    else
      dir_name="$(dirname "$PREFIX")"
    fi
    if [ -d "$dir_name" ]; then
      if [ "$(id -u)" -ne 0 ]; then
        if [ -w "$dir_name" ]; then
          IS_USER_INSTALL="true"
          BINDIR="$HOME/.local/bin"
          MANDIR="$HOME/.local/man"
        else
          echo "Not running as root. Aborting."
          echo "Need root permission for $dir_name"
          echo "Please run again as root or use the install script --prefix option to set a custom install path"
          echo "You can pass options to the install script by running ./installer.run -- <install-script-options>"
          exit 1
        fi
      fi
    else
      echo "Parent directory not found: $dir_name"
      echo "Aborting."
      exit 1
    fi
    INSTALL_PATH="$PREFIX/test-name"
    echo "Installing test-name.test.version to $PREFIX/test-name"
    echo "The following files and directories will be written to the system:"
    echo "- $PREFIX/test-name"
    echo "- $BINDIR/do"
    check_available "$PREFIX/test-name"
    check_available "$BINDIR/do"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if ! [ -d "$PREFIX" ]; then
      mkdir -p -m 755 "$PREFIX"
    fi
    mkdir -p -m 755 "$PREFIX/test-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} "$PREFIX/test-name" \;
    if ! [ -d "$BINDIR" ]; then
      mkdir -p -m 755 "$BINDIR"
    fi
    echo "Adding do to $BINDIR"
    ln -s "$PREFIX/test-name/bin/do" "$BINDIR/do"
    {
      printf '%s\n' "version=test.version"
      printf '%s\n' "IS_USER_INSTALL=$IS_USER_INSTALL"
    } > "$PREFIX/test-name/install.conf"
    chmod 644 "$PREFIX/test-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall test-name, please run $PREFIX/test-name/uninstall.sh."
    |}]

(* Regression test that ensures that if the binaries are not at the bundle's
   root, the symlinks are correctly removed by the uninstall script. *)
let%expect_test "uninstall_script: binary in sub folder" =
  let config = make_config ~exec_files:[{ path = "bin/do"; symlink = true; deps = true }] () in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" pp_sh uninstall_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    INSTALL_DIR="$(dirname "$0")"
    PREFIX="$(dirname "$$INSTALL_DIR")"
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
    load_conf $INSTALL_DIR/install.conf
    if [ "$IS_USER_INSTALL" = "true" ]; then
      BINDIR="$HOME/.local/bin"
      MANDIR="$HOME/.local/man"
    else
      BINDIR="/usr/local/bin"
      if [ -d "/usr/local/share/man" ]; then
        MANDIR="/usr/local/share/man"
      else
        MANDIR="/usr/local/man"
      fi
    fi
    echo "About to uninstall test-name."
    echo "The following files and folders will be removed from the system:"
    echo "- $INSTALL_DIR"
    echo "- $BINDIR/do"
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
      if ! [ -w "$INSTALL_DIR" ]; then
        echo "Need root permission for $INSTALL_DIR"
        echo "Not running as root. Aborting"
        exit 1
      fi
    fi
    if [ -d "$INSTALL_DIR" ]; then
      echo "Removing $INSTALL_DIR..."
      rm -rf "$INSTALL_DIR"
    fi
    if [ -L "$BINDIR/do" ]; then
      echo "Removing symlink $BINDIR/do..."
      rm -f "$BINDIR/do"
    fi
    echo "Uninstallation complete!"
    |}]

let%expect_test "install_script: set environment for binaries" =
  let config =
    make_config
      ~exec_files:[{ path = "bin/app"; symlink = true; deps = true }]
      ~environment:[("VAR1", "value1"); ("VAR2", "$INSTALL_PATH/lib")]
      ()
  in
  let installer_name = "installer.run" in
  let install_script = Makeself_backend.install_script ~installer_name config in
  Format.printf "%a" pp_sh install_script;
  [%expect {|
    #!/usr/bin/env sh
    set -e

    usage() {
      echo "Ocaml Universal Installer for test-name.test.version"
      echo ""
      echo "Options:"
      echo "    --prefix PREFIX        Install bundle in PREFIX (default is /opt)"
      echo "                           If PREFIX points to a user owned directory symlinks and manpage will be put in $HOME/.local, otherwise (root directory) in /usr/local"
    }
    check_available() {
      if [ -e "$1" ]; then
        printf '%s\n' "$1 already exists on the system! Aborting" >&2
        printf '%s\n' "Use $PREFIX/test-name/uninstall.sh to uninstall it" >&2
        exit 1
      fi
    }
    check_lib() {
      if [ -e "$1" ] && ! [ -d "$1" ] && ! [ -L "$1" ]; then
        printf '%s\n' "$1 already exists and does not appear to be a library! Aborting" >&2
        exit 1
      fi
    }
    PREFIX="/opt"
    IS_USER_INSTALL="false"
    BINDIR="/usr/local/bin"
    if [ -d "/usr/local/share/man" ]; then
      MANDIR="/usr/local/share/man"
    else
      MANDIR="/usr/local/man"
    fi
    while [ $# -gt 0 ]; do
      case "$1" in
        --prefix)
          if [ $# -lt 2 ]; then
            echo "Option $1 requires an argument"
            exit 2
          fi
          shift
          PREFIX="$1"
        ;;
        --help)
          usage
          exit 0
        ;;
        *)
          usage
          exit 3
        ;;
      esac
      shift
    done
    if [ -d "$PREFIX" ]; then
      dir_name="$PREFIX"
    else
      dir_name="$(dirname "$PREFIX")"
    fi
    if [ -d "$dir_name" ]; then
      if [ "$(id -u)" -ne 0 ]; then
        if [ -w "$dir_name" ]; then
          IS_USER_INSTALL="true"
          BINDIR="$HOME/.local/bin"
          MANDIR="$HOME/.local/man"
        else
          echo "Not running as root. Aborting."
          echo "Need root permission for $dir_name"
          echo "Please run again as root or use the install script --prefix option to set a custom install path"
          echo "You can pass options to the install script by running ./installer.run -- <install-script-options>"
          exit 1
        fi
      fi
    else
      echo "Parent directory not found: $dir_name"
      echo "Aborting."
      exit 1
    fi
    INSTALL_PATH="$PREFIX/test-name"
    echo "Installing test-name.test.version to $PREFIX/test-name"
    echo "The following files and directories will be written to the system:"
    echo "- $PREFIX/test-name"
    echo "- $BINDIR/app"
    check_available "$PREFIX/test-name"
    check_available "$BINDIR/app"
    printf "Proceed? [y/N] "
    read ans
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if ! [ -d "$PREFIX" ]; then
      mkdir -p -m 755 "$PREFIX"
    fi
    mkdir -p -m 755 "$PREFIX/test-name"
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} "$PREFIX/test-name" \;
    if ! [ -d "$BINDIR" ]; then
      mkdir -p -m 755 "$BINDIR"
    fi
    echo "Adding app to $BINDIR"
    {
      printf '%s\n' "#!/usr/bin/env sh"
      printf '%s\n' "VAR1=\"value1\" \"
      printf '%s\n' "VAR2=\"$INSTALL_PATH/lib\" \"
      printf '%s\n' "exec $PREFIX/test-name/bin/app \"\$@\""
    } > "$BINDIR/app"
    chmod 755 "$BINDIR/app"
    {
      printf '%s\n' "version=test.version"
      printf '%s\n' "IS_USER_INSTALL=$IS_USER_INSTALL"
    } > "$PREFIX/test-name/install.conf"
    chmod 644 "$PREFIX/test-name/install.conf"
    echo "Installation complete!"
    echo "If you want to safely uninstall test-name, please run $PREFIX/test-name/uninstall.sh."
    |}]
