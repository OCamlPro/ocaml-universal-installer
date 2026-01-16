(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let generate_postinstall_script ~env ~app_name ~binary_name =
  let def_install_path =
    Printf.sprintf
      "INSTALL_PATH=/Applications/%s.app/Contents/Resources"
      app_name
  in
  let wrapper_content =
    let env_lines =
      List.map
        (fun (var, value) ->
           (* VAR="VALUE" \ *)
           Printf.sprintf "%s=\"%s\" \\\\" var value)
        env
    in
    let lines =
    "#!/bin/bash"
    :: env_lines
    @ [ Printf.sprintf
          {|exec "/Applications/%s.app/Contents/MacOS/%s" "$@"|}
          app_name binary_name ]
    in
    String.concat "\n" lines
  in
  let wrapper_creation =
    Printf.sprintf {|cat > "/usr/local/bin/%s" << 'WRAPPER_EOF'
%s
WRAPPER_EOF|}
      binary_name wrapper_content
  in
  let wrapper_chmod =
    Printf.sprintf "chmod +x \"/usr/local/bin/%s\"" binary_name
  in
  let app_man_dir =
    Printf.sprintf "/Applications/%s.app/Contents/Resources/man" app_name
  in
  let man_pages_section =
    Printf.sprintf {|if [ -d "%s" ]; then
  mkdir -p /usr/local/share/man
  for section_dir in %s/*; do
    if [ -d "$section_dir" ]; then
      section=$(basename "$section_dir")
      mkdir -p /usr/local/share/man/${section}
      for manpage in "$section_dir"/*; do
        [ -f "$manpage" ] && ln -sf "$manpage" "/usr/local/share/man/${section}/$(basename "$manpage")"
      done
    fi
  done
fi|}
      app_man_dir app_man_dir
  in
  Printf.sprintf {|#!/bin/bash
mkdir -p /usr/local/bin

%s

%s
%s

%s
exit 0|}
    def_install_path wrapper_creation wrapper_chmod man_pages_section

let save_postinstall_script ~content ~scripts_dir =
  OpamFilename.mkdir scripts_dir;
  let script_path = OpamFilename.Op.(scripts_dir // "postinstall") in
  OpamFilename.write script_path content;
  System.call_unit System.Chmod (755, script_path);
  OpamConsole.msg "Created postinstall script: %s\n"
    (OpamFilename.to_string script_path);
  script_path
