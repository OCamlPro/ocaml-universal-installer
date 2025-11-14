# alt-ergo-mac-builds branch

Built from alt-ergo's `22f29edc24de72124b162186d314b6370d1dc573` revision.

This branch hosts a few files used by the MacOS CI builds:
- a precompiled `alt-ergo` installation bundle in `alt-ergo-bundle`, generated
  following the suggested approach for a dune project
  [here](https://github.com/OCamlPro/ocaml-universal-installer/tree/5d7275ba92d7ecdfd5ef9cae0cc10a61180cff6c/doc#generating-a-binary-installer-for-your-dune-project)
- the corresponding `alt-ergo-oui.json` file
- the `semantic_trigger.ae` alt-ergo input file used as input when running the
  installed alt-ergo in our CI, copied from upstream alt-ergo's
  `tests/cram.t/semantic_triggers.ae`.

If those files need to be regenerated, please follow the steps in the
documentation section linked above and update the commit revision in this
README.
