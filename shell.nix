{ pkgs ? import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  }) {}
}:

pkgs.mkShell {
  dontDetectOcamlConflicts = true;
  nativeBuildInputs = with pkgs.ocamlPackages; [
    crunch
    dune_3
    findlib
    ocaml
    odoc
    ppx_deriving_yojson
    ppx_expect
  ];
  propagatedBuildInputs = with pkgs.ocamlPackages; [
    cmdliner
    fmt
    opam-client
    opam-core
    opam-format
    opam-state
  ];
}
