(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui

let%expect_test "make_info_plist: basic" =
  let plist = Info_plist.make_info_plist
      ~bundle_id:"com.example.testapp"
      ~executable:"testapp"
      ~name:"TestApp"
      ~display_name:"Test Application"
      ~version:"1.0.0"
  in
  let xml = Info_plist.to_xml plist in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleExecutable</key>
        <string>testapp</string>
        <key>CFBundleIdentifier</key>
        <string>com.example.testapp</string>
        <key>CFBundleName</key>
        <string>TestApp</string>
        <key>CFBundleDisplayName</key>
        <string>Test Application</string>
        <key>CFBundleVersion</key>
        <string>1.0.0</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>NSHighResolutionCapable</key>
        <true/>
    </dict>
    </plist>
    |}]

let%expect_test "make_info_plist: alt-ergo example" =
  let plist = Info_plist.make_info_plist
      ~bundle_id:"com.ocamlpro.alt-ergo"
      ~executable:"alt-ergo"
      ~name:"Alt-Ergo"
      ~display_name:"Alt-Ergo SMT Solver"
      ~version:"2.6.0"
  in
  let xml = Info_plist.to_xml plist in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleExecutable</key>
        <string>alt-ergo</string>
        <key>CFBundleIdentifier</key>
        <string>com.ocamlpro.alt-ergo</string>
        <key>CFBundleName</key>
        <string>Alt-Ergo</string>
        <key>CFBundleDisplayName</key>
        <string>Alt-Ergo SMT Solver</string>
        <key>CFBundleVersion</key>
        <string>2.6.0</string>
        <key>CFBundleShortVersionString</key>
        <string>2.6.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>NSHighResolutionCapable</key>
        <true/>
    </dict>
    </plist>
    |}]

let%expect_test "make_info_plist: xml escaping" =
  let plist = Info_plist.make_info_plist
      ~bundle_id:"com.test.app&co"
      ~executable:"test<>app"
      ~name:"Test & \"App\""
      ~display_name:"Test & 'App' <Demo>"
      ~version:"1.0.0"
  in
  let xml = Info_plist.to_xml plist in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleExecutable</key>
        <string>test&lt;&gt;app</string>
        <key>CFBundleIdentifier</key>
        <string>com.test.app&amp;co</string>
        <key>CFBundleName</key>
        <string>Test &amp; &quot;App&quot;</string>
        <key>CFBundleDisplayName</key>
        <string>Test &amp; &apos;App&apos; &lt;Demo&gt;</string>
        <key>CFBundleVersion</key>
        <string>1.0.0</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>NSHighResolutionCapable</key>
        <true/>
    </dict>
    </plist>
    |}]

let%expect_test "generic plist: minimal value types" =
  let plist = Info_plist.make [
      ("StringKey", Info_plist.String "foo");
      ("BoolTrueKey", Info_plist.Bool true);
      ("BoolFalseKey", Info_plist.Bool false);
      ("ArrayKey", Info_plist.Array [
          Info_plist.String "first";
          Info_plist.String "second";
          Info_plist.String "third";
        ]);
      ("DictKey", Info_plist.Dict [
          ("nested", Info_plist.String "value");
          ("enabled", Info_plist.Bool true);
        ]);
    ] in
  let xml = Info_plist.to_xml plist in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>StringKey</key>
        <string>foo</string>
        <key>BoolTrueKey</key>
        <true/>
        <key>BoolFalseKey</key>
        <false/>
        <key>ArrayKey</key>
        <array>
            <string>first</string>
            <string>second</string>
            <string>third</string>
        </array>
        <key>DictKey</key>
        <dict>
            <key>nested</key>
            <string>value</string>
            <key>enabled</key>
            <true/>
        </dict>
    </dict>
    </plist>
    |}]

let%expect_test "generic plist: empty collections" =
  let plist = Info_plist.make [
      ("EmptyArray", Info_plist.Array []);
      ("EmptyDict", Info_plist.Dict []);
      ("NonEmpty", Info_plist.String "test");
    ] in
  let xml = Info_plist.to_xml plist in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>EmptyArray</key>
        <array/>
        <key>EmptyDict</key>
        <dict/>
        <key>NonEmpty</key>
        <string>test</string>
    </dict>
    </plist>
    |}]

let%expect_test "add_entry: basic addition" =
  let plist = Info_plist.make [
      ("Key1", Info_plist.String "Value1");
      ("Key2", Info_plist.String "Value2");
    ] in
  let plist' = Info_plist.add_entry "Key3" (Info_plist.Bool true) plist in
  let xml = Info_plist.to_xml plist' in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Key1</key>
        <string>Value1</string>
        <key>Key2</key>
        <string>Value2</string>
        <key>Key3</key>
        <true/>
    </dict>
    </plist>
    |}]

let%expect_test "add_entry: update existing" =
  let plist = Info_plist.make [
      ("Key1", Info_plist.String "Original");
      ("Key2", Info_plist.String "OldValue");
      ("Key3", Info_plist.Bool true);
    ] in
  let plist' = Info_plist.add_entry "Key2" (Info_plist.String "NewValue") plist in
  let xml = Info_plist.to_xml plist' in
  Format.printf "%s\n" xml;
  [%expect {|
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Key1</key>
        <string>Original</string>
        <key>Key2</key>
        <string>NewValue</string>
        <key>Key3</key>
        <true/>
    </dict>
    </plist>
    |}]
