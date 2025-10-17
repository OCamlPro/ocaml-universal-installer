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

let make_manpages
    ?(man1=[])
    ?(man2=[])
    ?(man3=[])
    ?(man4=[])
    ?(man5=[])
    ?(man6=[])
    ?(man7=[])
    ?(man8=[])
    () : Installer_config.manpages
  =
  {man1; man2; man3; man4; man5; man6; man7; man8}

let make_config
    ?(name="")
    ?(version="")
    ?(exec_files=[])
    ?makeself_manpages
    () : Installer_config.t
  =
  { name
  ; version
  ; exec_files
  ; fullname = ""
  ; description = ""
  ; manufacturer = ""
  ; makeself_manpages
  ; wix_guid = None
  ; wix_tags = []
  ; wix_icon_file = None
  ; wix_dlg_bmp_file = None
  ; wix_banner_bmp_file = None
  ; wix_license_file = None
  ; wix_embedded_dirs = []
  ; wix_additional_embedded_name = []
  ; wix_additional_embedded_dir = []
  ; wix_embedded_files = []
  ; wix_environment = []
  }

let%expect_test "install_script: one binary" =
  let makeself_manpages =
    make_manpages
      ~man1:["man/man1/aaa-command.1"; "man/man1/aaa-utility.1"]
      ~man5:["man/man5/aaa-file.1"]
      ()
  in
  let config =
    make_config ~name:"aaa" ~version:"x.y.z"
      ~exec_files:["aaa-command"; "aaa-utility"]
      ~makeself_manpages
      ()
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
    mkdir -p -m 755 /opt/aaa
    find . -mindepth 1 -maxdepth 1 ! -name 'install.sh' -exec cp -rp {} /opt/aaa \;
    echo "Adding aaa-command to /usr/local/bin"
    ln -s /opt/aaa/aaa-command /usr/local/bin/aaa-command
    echo "Adding aaa-utility to /usr/local/bin"
    ln -s /opt/aaa/aaa-utility /usr/local/bin/aaa-utility
    if [ -d "/usr/local/share/man" ]; then
      MAN_DEST="/usr/local/share/man"
    else
      MAN_DEST="usr/local/man"
    fi
    mkdir -p -m 755 $MAN_DEST/man1
    ln -s /opt/aaa/man/man1/aaa-command.1 $MAN_DEST/man1/aaa-command.1
    ln -s /opt/aaa/man/man1/aaa-utility.1 $MAN_DEST/man1/aaa-utility.1
    mkdir -p -m 755 $MAN_DEST/man5
    ln -s /opt/aaa/man/man5/aaa-file.1 $MAN_DEST/man5/aaa-file.1
    echo "Installation complete!"
    echo "If you want to safely uninstall aaa, please run /opt/aaa/uninstall.sh."
    |}]

let%expect_test "uninstall_script: one binary" =
  let makeself_manpages =
    make_manpages
      ~man1:["man/man1/aaa-command.1"; "man/man1/aaa-utility.1"]
      ~man5:["man/man5/aaa-file.1"]
      ()
  in
  let config =
    make_config ~name:"aaa"
      ~exec_files:["aaa-command"; "aaa-utility"]
      ~makeself_manpages
      ()
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
      rm -rf /opt/aaa
    fi
    if [ -L "/usr/local/bin/aaa-command" ]; then
      echo "Removing symlink /usr/local/bin/aaa-command..."
      rm -f /usr/local/bin/aaa-command
    fi
    if [ -L "/usr/local/bin/aaa-utility" ]; then
      echo "Removing symlink /usr/local/bin/aaa-utility..."
      rm -f /usr/local/bin/aaa-utility
    fi
    if [ -L "$MAN_DEST/man1/aaa-command.1" ]; then
      echo "Removing manpage $MAN_DEST/man1/aaa-command.1..."
      rm -f $MAN_DEST/man1/aaa-command.1
    fi
    if [ -L "$MAN_DEST/man1/aaa-utility.1" ]; then
      echo "Removing manpage $MAN_DEST/man1/aaa-utility.1..."
      rm -f $MAN_DEST/man1/aaa-utility.1
    fi
    if [ -L "$MAN_DEST/man5/aaa-file.1" ]; then
      echo "Removing manpage $MAN_DEST/man5/aaa-file.1..."
      rm -f $MAN_DEST/man5/aaa-file.1
    fi
    echo "Uninstallation complete!"
    |}]

