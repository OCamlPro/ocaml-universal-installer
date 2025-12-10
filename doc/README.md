# OCaml Universal Installer

OCaml Universal Installer or oui, is a tool that produces standalone installers
for your OCaml applications, be it for Linux, Windows or macOS.

## How it works

`oui` needs two things to generate an installer:
1. an installation bundle. It's simply a directory containing all the files you
   want to install: binaries, compiled artifacts such as `.cmxs` for dynamic
   linking, documentation, data files.
2. a `oui.json` configuration file. It contains information that `oui` needs
   to properly generate the installer. Some fields are shared across all
   backends and some are specific to one. Among other things, it contains
   paths, relative to the installation bundle's root, to files or folders
   that require special treatment during the install such as binaries or
   manpages. The full file format is described in the
   [`oui.json` file format](#ouijson-file-format) section.

Unless you are relying on one of `oui`'s frontend to build them, you will
need to provide both those things. The
[Generating a binary installer for your dune
project](#generating-a-binary-installer-for-your-dune-project) section
provides a good example on how to build them.

Given that the information in the `oui.json` file is closely tighted to your
project, we recommend committing it to the root of your repo.

## `oui.json` file format

The `oui.json` config file is composed of a main JSON object. The fields
are:

- `name`, **string**, **required**: the name of the app. This will define the
  install folder name on the target system and where plugins will look for your
  app when installing themselves. *Example:* `"oui"`.
- `fullname`, **string**, **required**: *TODO* (remove or make WiX specific?)
- `version`, **string**, **required**: the version of the app. *Example:*
  `"1.0.0"`. WiX backend requires that in `major.minor.patch`, `major`, `minor` and `patch` are strictly numerical.
- `exec_files`, **string array**, **optional**: The list of executables to
  install from the bundle. Should be a list of paths, relative to the bundle
  root, pointing to executable files that should be installed and made available
  to the user. *Example:* `["bin/oui", "bin/opam-oui"]`.
- `manpages`, **object**, **optional**: A JSON object describing where manpages
  are located within the bundle so they can be properly installed on the target
  system. See the [manpages object section](#manpages-object) for the object
  format.
- `environement`, **string array array**, **optional**: A list of environment
  variables and associated values to set when running the application on the
  target system. You can refer to the application's install directory absolute
  path using the `<install_path>` variable.
  *Example:*
  `[["VAR1", "value1"], ["VAR2", "<install_path>/lib"]]`.
- `unique_id`, **string**, **required**: A unique identifier for the app in
  reverse DNS format. Must remain the same for all subsequent versions for updates
  to work correctly on Windows.
  *Example*: `"com.MyCompany.MyApp"`.
- `plugins`, **object array**, **optional**: A list of objects describing plugins
  for external applications contained in the bundle. See the
  [plugin object section](#plugin-object) for the object format.
- `plugin_dirs`, **object**, **optional**: A JSON object describind where
  plugins for the described application should install themselves. See the
  [plugin_dirs object section](#plugin_dirs-object) for the object format.
- `wix_manufacturer`, **string**, **required**: The application developer/editor
- `wix_description`, **string**, **optional**: A short description of the application,
  shown in the installer properties
- `wix_tags`, **string array**, **optional**: List of package tags, used by WiX
  backend only. *Example*: `["tag1", "tag2"]`.
- `wix_icon_file`, **string**, **optional**: Path to the app icon file relative to
  the `oui.json` file, used by WiX backend only. *Example*:
  `"data/images/logo.ico"`.
- `wix_dlg_bmp_file`, **string**, **optional**: Path to the installer dialog
  image file, relative to the `oui.json` file, used by WiX backend only.
  *Example*: `"data/images/dlg.bmp"`.
- `wix_banner_bmp_file`, **string**, **optional**: Path to the app banner file
  relative to the `oui.json` file, used by WiX backend only. *Example*:
  `"data/images/banner.bmp"`.
- `wix_license_file`, **string**, **optional**: Path to the license in RTF
  format relative to the `oui.json` file, used by WiX backend only. *Example:*
  `"data/licenses/gpl-3.0.rtf"`
- `macos_symlink_dirs`: **string array**, **optional**: List of directories
  within the bundle that are installed in `Resources/` but must be symlinked
  in `Contents/`. Used by macOS backend only. See
  [macOS / Application Bundle section](#macos--application-bundle) for details.
  *Example:* `["lib", "share"]`.

### manpages object

The manpages object describes where in the installation bundle are manpages
located and which man section they belong to.

It's a JSON object with the following fields:
- `man1`, **string** or **string array**, **optional**
- `man2`, **string** or **string array**, **optional**
- `man3`, **string** or **string array**, **optional**
- `man4`, **string** or **string array**, **optional**
- `man5`, **string** or **string array**, **optional**
- `man6`, **string** or **string array**, **optional**
- `man7`, **string** or **string array**, **optional**
- `man8`, **string** or **string array**, **optional**

Each field's value is interpreted as follows:
- If the field is a JSON string, it is interpreted as a path, relative to the
  bundle's root, pointing to a directory containing all manpages that should be
  installed in this man section.
- If the field is an array of JSON strings, each string is interpreted as a
  path, relative to the bundle's root, pointing to a manpage file that should be
  installe din this man section.

*Example:*
```json
{
  "man1": "doc/man/man1",
  "man5": [ "config/spec/oui.json.1", "lib/save/oui.save.1" ]
}
```

means that all files in `bundle/doc/man/man1` will be installed as manpages in
man section `man1` and that `bundle/config/spec/oui.json.1` and
`bundle/lib/save/oui.save.1` will be installed as manpages in the man section
`man5` on the target system.

### plugin object

This simply describes the configuration format, for more detailed information on
how plugins are installed, please read the [Installing plugins
section](#installing-plugins).

A plugin object describes one plugin contained within the bundle.

It's a JSON object with the following fields:
- `name`, **string**, **required**: The name of the plugin, this is mostly
  informational.
- `app_name`, **string**, **required**: The name of the application this plugin
  is meant for. It must match the exact name of the application as described in
  the app's `oui.json` as it will be used to look it up on the target system.
- `plugin_dir`, **string**, **required**: The path, relative to the bundle's
  root, to the directory that should be installed in the app's plugin directory.
- `lib_dir`, **string**, **required**: The path, relative to the bundle's root,
  to the directory that should be installed in the app's lib directory.
- `dyn_deps`, **string array**, **optional**: A list of paths, relative to the
  bundle's root, to dynamic dependencies directories that should be installed
  along with the plugin itself in the app's lib directory.

*Example:*
```json
{
  "name": "frama-c-metacsl",
  "app_name": "frama-c",
  "plugin_dir": "lib/frama-c/plugins/metacsl",
  "lib_dir": "lib/frama-c-metacsl",
  "dyn_deps": ["lib/findlib"]
}
```

### plugin_dirs object

A plugin_dirs object describes where plugins of the described application should
install themselves.

It's a JSON object with the following fields:
- `plugins_dir`, **string**, **required**: The path, relative to the bundle's
  root, to the directory where plugins should be installed.
- `lib_dir`, **string**, **required**: The path, relative to the bundle's root,
  to the directory where ocaml libraries should be installed.

*Example:*
```json
{
  "plugins_dir": "lib/frama-c/plugins",
  "lib_dir": "lib"
}
```

## Generating a binary installer for your dune project

If you're developing an application in OCaml you are most likely to use
`dune` as your main build system so here's how you can produce a binary
installer with `oui` from your `dune` project.

In the future we will likely provide a `dune` fronted to `oui` so that you
don't have to go through the following steps yourself for regular `dune`
projects but in the meantime you can follow the instructions below.

### Generating the installation bundle

In the vast majority of cases you can rely on `dune install` to generate
the installation bundle for you. From the root of your project run:

```
dune build @install
dune install --relocatable --prefix <install-bundle-dir>
```

This will generate a good starting point for an installation bundle in
`<install-bundle-dir>`.

Note that this will install all packages in your project. If you define
more than one but don't want to bundle them all together in a single installer
you can add the `-p <package-name>` option to the `dune build` command.

The `--relocatable` flag is particularly important if you are using
`dune-site` as it would otherwise insert hardcoded absolute paths in your
binaries.

This installation bundle is likely to contain files that don't necessarily
matter to your non OCaml end users and that you might want to strip from
the bundle such as source files or intermediate compiled artifacts.

Here's a simple script you can run to filter out any such files from the `dune`
generated bundle:

```sh
#!/usr/bin/env bash
set -euo pipefail

# Clean up an OCaml installation directory after `dune install`
# Removes development artifacts and keeps only what’s needed
# for a binary distribution (executables, .cmxs, docs, etc.)

QUIET=""

# Parse options
if [ "${1:-}" = "--quiet" ]; then
  QUIET=true
  shift
fi

if [ -n "$QUIET" ]; then
  FIND_DELETE=(-delete)
else
  FIND_DELETE=(-print -delete)
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 [--quiet] <install-dir>" >&2
  exit 1
fi

INSTALL_DIR=$1

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Error: directory '$INSTALL_DIR' does not exist" >&2
  exit 1
fi

if [ -n "$QUIET" ]; then
  echo "Cleaning up install directory: $INSTALL_DIR"
fi

# Patterns of files to remove
TO_REMOVE=(
  "*.ml"
  "*.mli"
  "*.cmi"
  "*.cmo"
  "*.cmx"
  "*.cmxa"
  "*.cma"
  "*.a"
  "*.cmt"
  "*.cmti"
  "dune-package"
  "opam"
  "*.opam"
  "*.mld"
)

# --- Remove Unwanted files ---
for pattern in "${TO_REMOVE[@]}"; do
  find "$INSTALL_DIR" -type f -name "$pattern" "${FIND_DELETE[@]}"
done

# --- Remove empty directories (after cleanup) ---
find "$INSTALL_DIR" -type d -empty "${FIND_DELETE[@]}"

if [ -n "$QUIET" ]; then
  echo "Cleanup complete!"
fi
```

After running this script on your installation bundle it should be ready
for `oui`!

Note that if you are using `dune-site` for plugins support, you will need
to install `META` files as its plugin loading mechanism relies on them.
That's the main reason why the above script does not remove `META` files.

### Writing the `oui.json` config file

Here we are going to use [alt-ergo](https://github.com/OCamlPro/alt-ergo) as an
example.

Generating the installation bundle, following the steps from the previous
section yields the following:
```
alt-ergo.dev
├── bin
│   └── alt-ergo
├── doc
│   └── alt-ergo
│       ├── CHANGES.md
│       ├── LICENSE.md
│       └── README.md
├── lib
│   └── alt-ergo
│       ├── plugins
│       │   └── fm-simplex
│       │       └── FmSimplexPlugin.cmxs
│       └── __private__
│           └── alt_ergo_common
│               └── alt_ergo_common.cmxs
└── man
    └── man1
        └── alt-ergo.1
```

The important parts here are the main binary in `bin/` and the manpage
in `man/man1/alt-ergo.1`.

Here is the `oui.json` file we'd use to generate `alt-ergo`'s installer:
```json
{
  "name": "alt-ergo",
  "fullname": "alt-ergo.dev",
  "version": "dev",
  "wix_description": "Alt-Ergo is an automatic theorem prover of mathematical formulas. It was developed at LRI, and is now maintained at OCamlPro.",
  "wix_manufacturer": "alt-ergo@ocamlpro.com",
  "exec_files": ["bin/alt-ergo"],
  "manpages": {
    "man1": [
      "man/man1/alt-ergo.1"
    ]
  }
}
```

The content of `oui.json` isn't likely to change much and is closely tied
to your dune project's structure itself so we recommend committing it to your
repo and updating it as needed through your project's development.
For convenience, it should be written to the root of the repo alongside your
`dune-project`.



### Generating the installer

Now you can generate the installer by running:
```
oui oui.json <installation-bundle-dir>
```

## Installing plugins

`oui` can handle installation of plugins for apps that have been instaled by a
`oui` generated installer separately.

Plugins are just treated as a part of a bundle and can be installed alongside a
regular application or all by themselves.

You will note that we currently support the plugin layout required by
`dune-sites` plugins. If this does not fit the way your application handles
plugins, please reach out!

`dune-sites` plugins are installed by adding a "main" directory in the `lib/`
folder that contain the actual plugin binaries and a "redirect" directory within
the app's `lib/` directory where it looks up all of its plugins. This "redirect"
directory contains a `META` file used by `dune-sites` to locate the actual
plugin.

You need to make sure both those are present in the installation bundle and
add the right [`plugin`](#plugin-object) description to your `oui.json` file.

In a typical dune project, using dune-sites to define plugins, these should be
present in the bundle generated by `dune install --relocatable --prefix bundle`.
For a plugin `a-b` meant for app `a`, the main directory will be found in
`lib/a-b` and the redirect one in `lib/a/plugins/b`.

Some plugins depend on libraries that are not linked in the main application
and that need to be dynamically linked before loading the plugin itself. These
libraries should be included in the bundle and listed in the plugin's `dyn_deps`
field so that they can be correctly installed and found by `dune-sites` at
loading time.

### Building compatible plugin binaries

Note that you need to be careful with how you build the plugin binaries (`.cmxs`
files) as if they haven't been compiled in the same environment as the main
application binary they likey won't be compatible.

## Installation layout

oui aims at producing the most consistent installs across platforms but each
as its own specificities.

The following sections describes how an application is installed on the three
main platform it supports.

### Linux

Executing a `.run` produced by oui will install the application in
`/opt/<appname>`. The installation folder structure will be the same
as the install bundle you fed to `oui`.

The installer will add a symlink to all your application binaries
in `/usr/local/bin`.

It will also add symlinks to all your application manpages. It will
install them in the relevant section of the following folders, by order
of priority:
1. `/usr/local/share/man`
2. `/usr/local/man` if **1.** does not exist

If plugins need to be installed, the installer will locate the plugin's main
application and add symlinks to the plugins directory in the app's install path,
as described by the plugin and the app respective `oui.json` configuration.

An `uninstall.sh` script is also installed alongside the application
that can be run to cleanly remove it from the system. It will remove
the installation folder and all symlinks created during the installation.

### Windows / WiX

A WiX-generated MSI installer can be installed either per-user, or per-machine,
which requires admin rights. This will install the application in different locations.

For a per-user installation:

- application in `C:\Users\<username>\AppData\Local\Programs\<appname>`
- shortcuts in `C:\Users\<username>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\<appname>`
- registry entries in `HKEY_CURENT_USER\SOFTWARE\<appname>`

For a per-machine installation:

- application in `C:\Program Files\<appname>`
- shortcuts in `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\<appname>`
- registry entries in `HKEY_LOCAL_MACHINE\SOFTWARE\<appname>`

The exact location and name of the application folder may actually be
customized by the user through the installer UI.

Note: it is not clear whether all three folders should be named `<appname>`.
Typically the shortcut folder has a more descriptive / longer name.

##### Package metadata

In order to create an MSI installer, a few metadata must be provided, some required, some optional.

###### Required metadata

- Package unique ID (e.g.: 'OCamlPro.Oui'), necessary for upgrades to work properly
- Package name (e.g.: 'Oui 1.4'), shown in installer UI and Windows Application manager
- Package manufacturer (e.g.: 'OCamlPro'), only shown in MSI properties
- Package version (e.g.: '1.4.2.0'), note the last number is usually not significant and ignored during upgrades

###### Optional metadata

- Package description/comment, shown in MSI properties
- Package keywords, shown in MSI properties
- Package icon (in ICO format), shown in Windows Application manager
- License text (in RTF format) ; we may provide a few standard licenses ; this is displayed by the installer (skipped if no license)
- Banner and background images (BMP/PNG format), displayed on each windows of the installer ; we may provide overridable defaults

##### Shortcut specification

A shortcut requires the following information:

- Name
- Target (relative to the application folder)
- Description (only shown in the shortcut properties/tooltip, might not be useful)

##### Internet shortcut specification

An internet shortcut requires the following information:

- Name
- Target (URL)

##### Environment variable specification

An environment variable requires the following information:

- Name
- Part: all, prepend, append (those two use the ';' separator, useful for PATHS)
- Value

##### Registry entry specification (not sure if useful to expose)

A registry entry requires the following information:

- Name (relative to registry key)
- Type: string, int, ...
- Value


#### Typical install UI

<img src="img/wix/1.png" alt="Welcome" width="450" />
<img src="img/wix/2.png" alt="License" width="450" />
<img src="img/wix/3.png" alt="Scope" width="450" />
<img src="img/wix/4.png" alt="Location" width="450" />
<img src="img/wix/5.png" alt="Ready" width="450" />
<img src="img/wix/6.png" alt="Progress" width="450" />
<img src="img/wix/7.png" alt="Complete" width="450" />



### macOS / Application Bundle

Executing a `.pkg` produced by oui will install the application as a standard
macOS application bundle in `/Applications/<AppName>.app`.

The application bundle follows the standard macOS structure:

```
/Applications/<AppName>.app/
├── Contents/
│   ├── Info.plist              # Application metadata (bundle ID, version, etc.)
│   ├── MacOS/
│   │   └── <binary>            # Main executable
│   ├── Frameworks/
│   │   └── *.dylib             # Dynamic libraries
│   └── Resources/
│       └── ...                 # Everything else that is needed for the application.
```

#### Post-installation setup

The installer runs a post-install script that performs the following:

1. **Binary wrapper**: Creates a wrapper script in `/usr/local/bin/<binary-name>`
   that executes the actual binary from the .app bundle.

2. **Man pages**: If man pages are present in `Contents/Resources/man/`, creates
   symlinks in `/usr/local/share/man/<section>/` for each man page, making them
   accessible via the `man` command.

#### Dynamic library handling

All external dynamic libraries (`.dylib` files) detected by the installer are:
- Copied to the `Contents/Frameworks/` directory
- Relocated using `install_name_tool` to use `@executable_path/../Frameworks/`
  relative paths, ensuring the application bundle is self-contained.

#### dune-site support

For applications using `dune-site`, you can specify
directories to symlink from `Contents/` to `Contents/Resources/` via the
`macos_symlink_dirs` configuration option. For example, specifying
`["lib", "share"]` will create:
- `Contents/lib -> Resources/lib`
- `Contents/share -> Resources/share`

This ensures dune-site's plugin discovery mechanism works correctly within the .app bundle structure.


