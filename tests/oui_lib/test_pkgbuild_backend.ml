(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui
open Installer_config

(* FIXME: copy-past of the same function from `test_makeself_backend`. *)
let pp_sh = Sh_script.pp_sh ~version:false

(* FIXME: copy-past of the same function from `test_makeself_backend`. *)
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

(* FIXME: copy-past of the same function from `test_makeself_backend`. *)
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
  ; macos_application_signing_id = None
  }

let%expect_test "postinstall_script" =
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
  let app_name = "aaa" in
  let env = [] in
  let s =
    Macos_postinstall.generate_postinstall_script ~env ~app_name
      ~binaries:config.exec_files ()
  in
  Format.printf "%s" s;
  [%expect {|
    #!/bin/bash
    set -e

    INSTALL_PATH=/Applications/aaa.app/Contents/Resources
    mkdir -p /usr/local/bin

    cat > "/usr/local/bin/aaa-command" << 'WRAPPER_EOF'
    #!/bin/bash
    exec "/Applications/aaa.app/Contents/Resources/aaa-command" "$@"
    WRAPPER_EOF
    chmod +x "/usr/local/bin/aaa-command"
    mkdir -p /usr/local/bin

    cat > "/usr/local/bin/aaa-utility" << 'WRAPPER_EOF'
    #!/bin/bash
    exec "/Applications/aaa.app/Contents/Resources/aaa-utility" "$@"
    WRAPPER_EOF
    chmod +x "/usr/local/bin/aaa-utility"


    if [ -d "/Applications/aaa.app/Contents/Resources/man" ]; then
      mkdir -p /usr/local/share/man
      for section_dir in /Applications/aaa.app/Contents/Resources/man/*; do
        if [ -d "$section_dir" ]; then
          section=$(basename "$section_dir")
          mkdir -p /usr/local/share/man/${section}
          for manpage in "$section_dir"/*; do
            [ -f "$manpage" ] && ln -sf "$manpage" "/usr/local/share/man/${section}/$(basename "$manpage")"
          done
        fi
      done
    fi
    exit 0
    |}]

let%expect_test "uninstall_script" =
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
  let app_name = "aaa" in
  let app_uid = "aaa-uid" in
  let plugins = [] in
  let s =
    Macos_postinstall.generate_uninstall_script ~app_name
      ~binaries:config.exec_files ~plugins ~app_uid
  in
  Format.printf "%s" s;
  [%expect {|
    #!/bin/bash
    set -e

    echo "Uninstalling aaa..."

    # Remove wrapper from /usr/local/bin
    if [ -L "/usr/local/bin/aaa-command" ] || [ -f "/usr/local/bin/aaa-command" ]; then
      echo "Removing /usr/local/bin/aaa-command"
      rm -f "/usr/local/bin/aaa-command"
    fi
    # Remove wrapper from /usr/local/bin
    if [ -L "/usr/local/bin/aaa-utility" ] || [ -f "/usr/local/bin/aaa-utility" ]; then
      echo "Removing /usr/local/bin/aaa-utility"
      rm -f "/usr/local/bin/aaa-utility"
    fi

    # Remove manpage symlinks
    find /usr/local/share/man -type l -lname "/Applications/aaa.app/Contents/Resources/*" -delete 2>/dev/null || true

    # Remove the app bundle
    if [ -d "/Applications/aaa.app" ]; then
      echo "Removing /Applications/aaa.app"
      rm -rf "/Applications/aaa.app"
    fi

    # Remove MacOs package receipt
    pkgutil --forget "aaa-uid"

    echo "Uninstallation complete!"
    |}]
