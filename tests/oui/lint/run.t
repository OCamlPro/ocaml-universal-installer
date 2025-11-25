`oui lint` should properly report oui.json parsing errors:

  $ cat > oui.json << EOF
  > {"non_exising_field": 0}
  > EOF
  $ mkdir bundle
  $ oui lint oui.json bundle
  Could not parse installer config $TESTCASE_ROOT/oui.json: Installer_config.t
  [1]

Lets consider the following, valid oui.json:

  $ cat > oui.json << EOF
  > {
  >   "name": "app",
  >   "fullname": "App",
  >   "version": "ver",
  >   "exec_files": ["bin/app"],
  >   "manpages": {
  >     "man1": "man/man1",
  >     "man5": ["doc/file-format.1"]
  >   },
  >   "wix_unique_id": "home.org.App",
  >   "wix_manufacturer": "me@home.org",
  >   "wix_description": "A fake test app",
  >   "wix_icon_file": "icon.jpg",
  >   "wix_dlg_bmp_file": "dlg.bmp",
  >   "wix_banner_bmp_file": "banner.bmp",
  >   "wix_license_file": "license.rtf",
  >   "macos_symlink_dirs": ["lib"]
  > }
  > EOF

Now lets run `oui lint` with the empty bundle dir created above, it should
report all errors:

  $ oui lint oui.json bundle
  oui configuration $TESTCASE_ROOT/oui.json contain inconsistencies:
  - exec_files: file $TESTCASE_ROOT/bundle/bin/app does not exist
  - manpages.man1: directory $TESTCASE_ROOT/bundle/man/man1 does not exist
  - manpages.man5: file $TESTCASE_ROOT/bundle/doc/file-format.1 does not exist
  - wix_icon_file: file $TESTCASE_ROOT/icon.jpg does not exist
  - wix_dlg_bmp_file: file $TESTCASE_ROOT/dlg.bmp does not exist
  - wix_banner_bmp_file: file $TESTCASE_ROOT/banner.bmp does not exist
  - wix_license_file: file $TESTCASE_ROOT/license.rtf does not exist
  - macos_symlink_dirs: directory $TESTCASE_ROOT/bundle/lib does not exist
  [1]

We had the right files and directories:

  $ mkdir -p bundle/bin bundle/man/man1 bundle/doc bundle/lib
  $ touch bundle/bin/app
  $ touch bundle/doc/file-format.1
  $ touch icon.jpg
  $ touch dlg.bmp
  $ touch banner.bmp
  $ touch license.rtf

If we run `oui lint` it should still complain about the executabe's permissions:

  $ oui lint oui.json bundle
  oui configuration $TESTCASE_ROOT/oui.json contain inconsistencies:
  - exec_files: file $TESTCASE_ROOT/bundle/bin/app does not have exec permissions
  [1]

Fixing this, it should now run smoothly:

  $ chmod +x bundle/bin/app
  $ oui lint oui.json bundle
