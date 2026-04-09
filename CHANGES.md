## unreleased

### Added

### Changed

- On linux, write `install.conf` earlier during install to allow recovering
  from partial install using uninstall script. (#128, @NathanReb)
- Warn end user about pre-existing files and overwrite them upon confirmation.
  (#128, @NathanReb)

### Deprecated

### Fixed

- Fix a bug in makeself installation script which caused the `--prefix`
  option not to work when using the `--prefix=dir` form. (#126, @NathanReb)
- Fix a bug where makeself install script would ungracely fail if
  `--prefix` was given a relative path. It now rejects such paths and exits
  early. (#127, @NathanReb)
- Fix detection of pre-existing files on Linux. (#128, @NathanReb)
- Fix a bug where passing a directory with a trailing `/` would cause the
  install to fail. (#128, @NathanReb)

### Removed

### Security

## 0.1.0

*2026/03/02*

Initial release
