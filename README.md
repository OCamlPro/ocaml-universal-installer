# OCaml Universal Installer

OCaml Universal Installer or `oui` is a command-line tool that produces
standalone installers for your OCaml applications.

It can produce installers for Linux, Windows and macOS, installing pre-compiled
binaries directly, no need to build anything on the target machine.

You won't need to teach your users how to install OCaml, Opam or any other
tools that they don't need. Just download and run the installer and you're good
to go.

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

To produce linux installer, the `makeself.sh` script must be in the `PATH`.
You can dowload the latest official release from the
[official makeself website](https://makeself.io/).

#### Windows

Windows MSI are built using the [Wix6 toolkit](https://wixtoolset.org/).

## Documentation

Detailed documentation can be found [here](doc/README.md).

This project is built on top of `opam-wix`. The project's original documentation
is still available [here](doc/opam-wix.md).
