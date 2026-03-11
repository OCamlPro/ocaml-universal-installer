# Contributing to `oui`

## Setting up your dev environment

You can quickly setup your `oui` dev environment by running:
```
git clone git@github.com:OCamlPro/ocaml-universal-installer.git
cd ocaml-universal-installer
opam switch create ./ --deps-only -t
```

This will clone the project and create a local opam switch with all of the
project's dependencies required to build it and run the tests.

## Building `oui`

The project uses dune so you can build it using the usual:
```
dune build
```

## Project layout

All of our source code is located in the `src` folder:
- `src/oui_lib` this is the core internal `oui` library where the installer
  generation logic is found.
- `src/oui_cli` is a library that contains shared code for our command line
  interface such as `Cmdliner` arguments or global error handling and reporting.
- `src/oui` contains the code for the main `oui` tool. It uses `Cmdliner` to
  define commands, we have one file per subcommand and one `main.ml` to tie them
  all together. It's mostly a CLI wrapper around `oui_lib` and contains little
  to no logic.
- `src/opam-oui` contains the code for our legacy opam plugin.

## Tests

You can run the full test suite with:
```
dune runtest
```

The tests are split between cram tests and unit tests.

### Unit tests

Unit tests are located in `tests/<lib-name>` folders, where `<lib-name>` is the
dune library being tested, e.g. `tests/oui_lib` contains the tests for `oui_lib`.
In those, we have one test file for each of the library modules being tested,
e.g. `Oui_lib.Ldd`'s tests are located in `tests/oui_lib/test_ldd.ml`. We use
those to test individual functions from our libraries.

Our unit tests use [ppx_expect](https://github.com/janestreet/ppx_expect).

### Cram tests

Cram tests are located in `tests/oui/<subcommand-name>` folders where
`<subcommand-name>` is the command being tested, `oui lint` is tested in
`tests/oui/lint`.
These are used for higher level tests that run whole commands and are written as
[dune's cram tests](https://dune.readthedocs.io/en/latest/reference/cram.html).

## Formatting

We don't enforce any formatting on our OCaml source code, though we expect it is
correctly indented using ocp-indent.

Our dune files formatting is checked by our CI so remember to run:
```
dune build @fmt
```
when you edit or write new ones.

## Submitting contributions

We expect the usual github workflow for external contributions.

Feel free to open a PR directly for simple bug fixes, typos and other consensual
changes.

When submitting a bug fix, please try to add a regression tests alongside it if
it's reasonably easy to write.

For more involved changes/features, we suggest that you start by opening an
issue so you can discuss with the maintainers team the best way to proceed.
