# OCaml Universal Installer

OCaml Universal Installer or `oui` is a command-line tool that produces
standalone installers for your OCaml applications.

It can produce installers for Linux, Windows and macOS, installing pre-compiled
binaries directly, no need to build anything on the target machine.

You won't need to teach your users how to install OCaml, Opam or any other
tools that they don't need. Just download and run the installer and you're good
to go.

Detailed documentation can be found [here](doc/README.md).

This project is built on top of `opam-wix`. The project's original documentation
is still available [here](doc/opam-wix.md).

## Installation

`oui` is still in development but if you wish to try the latest dev version, you
can install it via opam:
```
opam pin oui.0.0.0 https://github.com/OCamlPro/ocaml-universal-installer.git#master
```

`oui` does require some opam libraries so you will need `opam.2.4.0` or higher.

### Platform specific dependencies

Producing installers for different platforms requires different extra tools.
They do not need to be installed before `oui` but need to be available on the
system when running it.

#### Linux

Our linux installers are built using [makeself](https://makeself.io/).

The result is a `.run` self-extracting archive that will decompress itself
and execute an installation script before cleaning up.

To produce linux installer, the `makeself` script must be in the `PATH`.
You can dowload the latest official release from the
[official makeself website](https://makeself.io/).

#### Windows

Windows MSI are built using the [Wix6 toolkit](https://wixtoolset.org/).

You can install Wix 6 from the [GitHub releases
page](https://github.com/wixtoolset/wix/releases/tag/v6.0.2).

## Usage

To assemble an installer for your current platform you need to provide:
- an installation bundle (a directory containing all binaries and files to
  install), usually produced by running `dune build @install` and
  `dune install --relocatable --prefix <install-bundle-dir>`.
- a JSON configuration file for `oui`, describing the important parts of the
  bundle and some project metadata. The format is fully documented
  [here](doc/README.md#ouijson-file-format).

You can then run `oui lint` to check that the configuration and bundle are
consistent.

Once this is good, you can run `oui build oui.json <install-bundle-dir>` to
generate an installer.
