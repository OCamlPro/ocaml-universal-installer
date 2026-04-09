## unreleased

### Added

### Changed

### Deprecated

### Fixed

- Fix a bug in makeself installation script which caused the `--prefix`
  option not to work when using the `--prefix=dir` form. (#126, @NathanReb)
- Fix a bug where makeself install script would ungracely fail if
  `--prefix` was given a relative path. It now rejects such paths and exits
  early. (#127, @NathanReb)

### Removed

### Security

## 0.1.0

*2026/03/02*

Initial release
