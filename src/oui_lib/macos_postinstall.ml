(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(* Shell function to parse install.conf files *)
let load_conf_function = {|
load_conf() {
  local conf="$1" var_prefix="$2"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ""|\#*) continue ;; esac
    case "$line" in
      *=*) ;;
      *) printf '%s\n' "Invalid line in $conf: $line" >&2; return 1 ;;
    esac
    local key="${line%%=*}"
    local val="${line#*=}"
    case "$key" in
      *[!a-zA-Z0-9_]*)
        printf '%s\n' "Invalid key in $conf: $key" >&2; return 1 ;;
      *)
        eval "${var_prefix}${key}=\$val" ;;
    esac
  done < "$conf"
  return 0
}
|}

let generate_wrapper_section ~app_path ~binary_name ~has_binary ~env =
  if not has_binary then
    "# Plugin-only package - no wrapper script"
  else
    let wrapper_content =
      let env_exports =
        List.map
          (fun (var, value) -> Printf.sprintf "export %s=\"%s\"" var value)
          env
      in
      String.concat "\n"
        ( "#!/bin/bash"
          :: env_exports
          @ [ Printf.sprintf {|exec "%s/Contents/MacOS/%s" "\$@"|}
                app_path binary_name ] )
    in
    (* Use unquoted heredoc to allow $INSTALL_PATH expansion *)
    let wrapper_creation =
      Printf.sprintf {|cat > "/usr/local/bin/%s" << WRAPPER_EOF
%s
WRAPPER_EOF|}
        binary_name wrapper_content
    in
    let wrapper_chmod =
      Printf.sprintf "chmod +x \"/usr/local/bin/%s\"" binary_name
    in
    Printf.sprintf "mkdir -p /usr/local/bin\n\n%s\n%s"
      wrapper_creation wrapper_chmod

let generate_app_support_section ~app_name ~resources ~plugin_dirs =
  match plugin_dirs with
  | None -> ""
  | Some pd ->
    let app_support =
      Printf.sprintf "/Library/Application Support/%s" app_name
    in
    Printf.sprintf {|
# Create Application Support directories for external plugins
APP_SUPPORT="%s"
mkdir -p "$APP_SUPPORT/plugins"
mkdir -p "$APP_SUPPORT/lib"

# Bundle plugins directory - external plugins will be symlinked here
BUNDLE_PLUGINS_DIR="%s/%s"
BUNDLE_LIB_DIR="%s/%s"

# Function to sync external plugins into bundle
sync_external_plugins() {
  # Symlink each plugin from Application Support into the bundle
  for plugin in "$APP_SUPPORT/plugins"/*; do
    if [ -e "$plugin" ]; then
      plugin_name=$(basename "$plugin")
      target="$BUNDLE_PLUGINS_DIR/$plugin_name"
      if [ ! -e "$target" ]; then
        ln -sf "$plugin" "$target"
      fi
    fi
  done
  # Symlink each lib from Application Support into bundle lib
  for lib in "$APP_SUPPORT/lib"/*; do
    if [ -e "$lib" ]; then
      lib_name=$(basename "$lib")
      target="$BUNDLE_LIB_DIR/$lib_name"
      if [ ! -e "$target" ]; then
        ln -sf "$lib" "$target"
      fi
    fi
  done
}

sync_external_plugins
|}
      app_support
      resources pd.Installer_config.plugins_dir
      resources pd.lib_dir

let generate_load_app_conf ~target_app =
  let capitalized = String.capitalize_ascii target_app in
  let var_prefix = Plugin_utils.app_var_prefix target_app in
  Printf.sprintf
    {|# Find and load %s's install.conf
TARGET_CONF="/Applications/%s.app/Contents/Resources/install.conf"
if [ -f "$TARGET_CONF" ]; then
  load_conf "$TARGET_CONF" "%s"
else
  echo "Error: %s is not installed. Cannot install plugin." >&2
  exit 1
fi|}
    target_app capitalized var_prefix target_app

let generate_plugin_symlinks ~resources ~(plugin : Installer_config.plugin) =
  let var_prefix = Plugin_utils.app_var_prefix plugin.app_name in
  let capitalized_app = String.capitalize_ascii plugin.app_name in
  let plugin_basename = Filename.basename plugin.plugin_dir in
  let lib_basename = Filename.basename plugin.lib_dir in
  let plugin_parent_dir = Filename.dirname plugin.plugin_dir in
  let lib_parent_dir = Filename.dirname plugin.lib_dir in
  let dyn_deps_symlinks =
    plugin.dyn_deps
    |> List.map (fun dep ->
        let dep_basename = Filename.basename dep in
        Printf.sprintf {|ln -sf "%s/%s" "${%slib}/%s"
ln -sf "%s/%s" "/Applications/%s.app/Contents/Resources/lib/%s"|}
          resources dep var_prefix dep_basename
          resources dep capitalized_app dep_basename)
    |> String.concat "\n"
  in
  let app_support_symlinks = Printf.sprintf
      {|ln -sf "%s/%s" "${%splugins}/%s"
ln -sf "%s/%s" "${%slib}/%s"|}
      resources plugin.plugin_dir var_prefix plugin_basename
      resources plugin.lib_dir var_prefix lib_basename
  in
  let bundle_symlinks = Printf.sprintf
      {|TARGET_BUNDLE_PLUGINS="/Applications/%s.app/Contents/Resources/%s"
TARGET_BUNDLE_LIB="/Applications/%s.app/Contents/Resources/%s"
if [ -d "$TARGET_BUNDLE_PLUGINS" ]; then
  ln -sf "%s/%s" "$TARGET_BUNDLE_PLUGINS/%s"
fi
if [ -d "$TARGET_BUNDLE_LIB" ]; then
  ln -sf "%s/%s" "$TARGET_BUNDLE_LIB/%s"
fi|}
      capitalized_app plugin_parent_dir
      capitalized_app lib_parent_dir
      resources plugin.plugin_dir plugin_basename
      resources plugin.lib_dir lib_basename
  in
  Printf.sprintf
    {|echo "Installing plugin %s for %s..."
%s
%s
%s|}
    plugin.name plugin.app_name
    app_support_symlinks dyn_deps_symlinks bundle_symlinks

let generate_plugin_install_section ~resources ~plugins =
  match plugins with
  | [] -> ""
  | _ ->
    let unique_apps =
      plugins
      |> List.map (fun (p : Installer_config.plugin) -> p.app_name)
      |> List.sort_uniq String.compare
    in
    let load_apps =
      unique_apps
      |> List.map (fun app -> generate_load_app_conf ~target_app:app)
      |> String.concat "\n\n"
    in
    let symlinks =
      plugins
      |> List.map (fun p -> generate_plugin_symlinks ~resources ~plugin:p)
      |> String.concat "\n\n"
    in
    Printf.sprintf "%s\n%s\n\n%s" load_conf_function load_apps symlinks

let generate_manpages_section ~resources =
  let app_man_dir = Printf.sprintf "%s/man" resources in
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

let generate_postinstall_script
    ~env
    ~app_name
    ~binary_name
    ~has_binary
    ?(plugin_dirs : Installer_config.plugin_dirs option)
    ?(plugins : Installer_config.plugin list = [])
    () =
  let app_path = Printf.sprintf "/Applications/%s.app" app_name in
  let resources = Printf.sprintf "%s/Contents/Resources" app_path in

  let def_install_path = Printf.sprintf "INSTALL_PATH=%s" resources in
  let wrapper_section =
    generate_wrapper_section ~app_path ~binary_name ~has_binary ~env
  in
  let app_support_section =
    generate_app_support_section ~app_name ~resources ~plugin_dirs
  in
  let plugin_install_section =
    generate_plugin_install_section ~resources ~plugins
  in
  let manpages_section = generate_manpages_section ~resources in

  Printf.sprintf {|#!/bin/bash
set -e

%s
%s

%s
%s
%s
exit 0|}
    def_install_path
    wrapper_section
    app_support_section
    plugin_install_section
    manpages_section


let generate_uninstall_script ~app_name ~binary_name ~has_binary ~plugins =
  let app_path = Printf.sprintf "/Applications/%s.app" app_name in
  let resources = Printf.sprintf "%s/Contents/Resources" app_path in
  let app_support = Printf.sprintf "/Library/Application Support/%s" app_name in

  (* Plugin symlink removal *)
  let plugin_removal = match plugins with
    | [] -> ""
    | _ ->
      let load_and_remove =
        Printf.sprintf {|%s

# Load our own install.conf to get target app paths
if [ -f "%s/install.conf" ]; then
  load_conf "%s/install.conf" ""
fi
|}
          load_conf_function resources resources
      in
      let remove_symlinks =
        List.map (fun (p : Installer_config.plugin) ->
            let var_prefix = Plugin_utils.app_var_prefix p.app_name in
            let capitalized_app = String.capitalize_ascii p.app_name in
            let plugin_basename = Filename.basename p.plugin_dir in
            let lib_basename = Filename.basename p.lib_dir in
            let plugin_parent_dir = Filename.dirname p.plugin_dir in
            let lib_parent_dir = Filename.dirname p.lib_dir in
            let dyn_deps_removal =
              List.map (fun dep ->
                  Printf.sprintf {|rm -f "${%slib}/%s" 2>/dev/null || true|}
                    var_prefix (Filename.basename dep))
                p.dyn_deps
              |> String.concat "\n"
            in
            Printf.sprintf {|
echo "Removing plugin %s from %s..."
# Remove from Application Support
rm -f "${%splugins}/%s" 2>/dev/null || true
rm -f "${%slib}/%s" 2>/dev/null || true
%s
# Remove from target app's bundle
rm -f "/Applications/%s.app/Contents/Resources/%s/%s" 2>/dev/null || true
rm -f "/Applications/%s.app/Contents/Resources/%s/%s" 2>/dev/null || true|}
              p.name p.app_name
              var_prefix plugin_basename
              var_prefix lib_basename
              dyn_deps_removal
              capitalized_app plugin_parent_dir plugin_basename
              capitalized_app lib_parent_dir lib_basename)
          plugins
        |> String.concat "\n"
      in
      load_and_remove ^ remove_symlinks
  in

  let wrapper_removal =
    if has_binary then
      Printf.sprintf {|# Remove wrapper from /usr/local/bin
if [ -L "/usr/local/bin/%s" ] || [ -f "/usr/local/bin/%s" ]; then
  echo "Removing /usr/local/bin/%s"
  rm -f "/usr/local/bin/%s"
fi|}
        binary_name binary_name binary_name binary_name
    else
      "# Plugin-only package - no wrapper to remove"
  in

  Printf.sprintf {|#!/bin/bash
set -e

echo "Uninstalling %s..."
%s
%s

# Remove manpage symlinks
find /usr/local/share/man -type l -lname "%s/*" -delete 2>/dev/null || true

# Remove Application Support directory (if exists)
if [ -d "%s" ]; then
  echo "Removing %s"
  rm -rf "%s"
fi

# Remove the app bundle
if [ -d "%s" ]; then
  echo "Removing %s"
  rm -rf "%s"
fi

echo "Uninstallation complete!"
|}
    app_name
    plugin_removal
    wrapper_removal
    resources
    app_support app_support app_support
    app_path app_path app_path


let save_postinstall_script ~content ~scripts_dir =
  OpamFilename.mkdir scripts_dir;
  let script_path = OpamFilename.Op.(scripts_dir // "postinstall") in
  OpamFilename.write script_path content;
  System.call_unit System.Chmod (755, script_path);
  OpamConsole.msg "Created postinstall script: %s\n"
    (OpamFilename.to_string script_path);
  script_path

let save_uninstall_script ~content ~resources_dir =
  let script_path = OpamFilename.Op.(resources_dir // "uninstall.sh") in
  OpamFilename.write script_path content;
  System.call_unit System.Chmod (755, script_path);
  OpamConsole.msg "Created uninstall script: %s\n"
    (OpamFilename.to_string script_path);
  script_path
