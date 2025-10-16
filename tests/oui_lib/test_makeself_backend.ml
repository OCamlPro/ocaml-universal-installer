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

let make_config
    ?(name="")
    ?(version="")
    ?(exec_files=[])
    () : Installer_config.t
  =
  { name
  ; version
  ; exec_files
  ; fullname = ""
  ; description = ""
  ; manufacturer = ""
  ; wix_guid = None
  ; wix_tags = []
  ; wix_icon_file = None
  ; wix_dlg_bmp_file = None
  ; wix_banner_bmp_file = None
  ; wix_embedded_dirs = []
  ; wix_additional_embedded_name = []
  ; wix_additional_embedded_dir = []
  ; wix_embedded_files = []
  ; wix_environment = []
  }

let%expect_test "install_script: one binary" =
  let config =
    make_config ~name:"aaa" ~version:"x.y.z"
      ~exec_files:["aaa-command"; "aaa-utility"] ()
  in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/bin/sh
    set -e
    echo "Installing aaa.x.y.z to /opt/aaa"
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p /opt/aaa /opt/aaa/bin
    cp aaa-command /opt/aaa/bin
    cp aaa-utility /opt/aaa/bin
    find /opt/aaa -type d -exec chmod 755 {} +
    find /opt/aaa -type f -exec chmod 644 {} +
    find /opt/aaa/bin -type f -exec chmod 755 {} +
    echo "Adding aaa-command to /usr/local/bin"
    ln -s /opt/aaa/bin/aaa-command /usr/local/bin/aaa-command
    echo "Adding aaa-utility to /usr/local/bin"
    ln -s /opt/aaa/bin/aaa-utility /usr/local/bin/aaa-utility
    cp uninstall.sh /opt/aaa
    chmod 755 /opt/aaa/uninstall.sh
    echo "Installation complete!"
    echo "If you want to safely uninstall aaa, please run /opt/aaa/uninstall.sh."
    |}]

let%expect_test "uninstall_script: one binary" =
  let config =
    make_config ~name:"aaa" ~exec_files:["aaa-command"; "aaa-utility"] ()
  in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" Sh_script.pp_sh uninstall_script;
  [%expect {|
    #!/bin/sh
    set -e
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    echo "About to uninstall aaa."
    echo "The following files and folders will be removed from the system:"
    echo "- /opt/aaa"
    echo "- /usr/local/bin/aaa-command"
    echo "- /usr/local/bin/aaa-utility"
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
      rm -rf /opt/aaa
    fi
    if [ -L "/usr/local/bin/aaa-command" ]; then
      echo "Removink symlink /usr/local/bin/aaa-command..."
      rm -f /usr/local/bin/aaa-command
    fi
    if [ -L "/usr/local/bin/aaa-utility" ]; then
      echo "Removink symlink /usr/local/bin/aaa-utility..."
      rm -f /usr/local/bin/aaa-utility
    fi
    echo "Uninstallation complete!"
    |}]

