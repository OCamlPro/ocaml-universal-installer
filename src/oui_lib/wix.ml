(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module Version = struct
  type t = string
  let to_string s = s
  let of_string s =
    String.iter (function
        | '0'..'9' | '.' -> ()
        | c ->
            failwith
              (Printf.sprintf "Invalid character '%c' in WIX version '%S'" c s))
      s;
    s
end

type info = {
  is_plugin: bool;
  unique_id: string;
  manufacturer: string;
  short_name: string;
  long_name: string;
  version: string;
  description: string option;
  keywords: string list;
  directory: string;
  shortcuts: shortcut list;
  environment: var list;
  registry: key list;
  icon: string;
  banner: string;
  background: string;
  license: string;
}

and shortcut =
  | File of { name: string; description: string; target: string }
  | URL of { name: string; target: string }

and var = {
  var_name: string;
  var_value: string;
  var_part: part;
}

and key = {
  key_name: string;
  key_type: string;
  key_value: string;
}

and part =
  | All
  | First
  | Last

let print_header fmt _info =
  Format.fprintf fmt {|<?xml version="1.0" encoding="UTF-8"?>

<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"
     xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui"
     xmlns:util="http://wixtoolset.org/schemas/v4/wxs/util">
|}

let print_package fmt info =
  Format.fprintf fmt {|
  <Package Id="%s" Scope="perUserOrMachine"
    Manufacturer="%s" Name="%s" Version="%s" Language="0"
    InstallerVersion="500" Compressed="yes" UpgradeStrategy="majorUpgrade">

    <SummaryInformation
      Manufacturer="%s" %s
      Comments="%s" %s />

    <MajorUpgrade Schedule="afterInstallInitialize" MigrateFeatures="yes"
      DowngradeErrorMessage="A newer version of this product is already installed"
      AllowSameVersionUpgrades="no" AllowDowngrades="no" />

    <MediaTemplate EmbedCab="yes" CompressionLevel="high" MaximumUncompressedMediaSize="64" />
|} info.unique_id info.manufacturer info.long_name info.version
   info.manufacturer
   (match info.description with
    | None -> ""
    | Some d -> Printf.sprintf {|Description="%s"|} d)
   info.long_name
   (match info.keywords with
    | [] -> ""
    | kw -> Printf.sprintf {|Keywords="%s"|} (String.concat "; " kw))

let print_plugin_specifics fmt info =
  if info.is_plugin then
    Format.fprintf fmt {|
    <Property Id="WIXPERUSERAPPFOLDER">
      <RegistrySearch Root="HKCU" Key="SOFTWARE\%s" Type="raw" />
    </Property>
    <Property Id="WIXPERMACHINEAPPFOLDER">
      <RegistrySearch Root="HKLM" Key="SOFTWARE\%s" Type="raw" />
    </Property>
    <Launch Message="This plugin requires %s"
            Condition="Installed OR NOT WIXPERUSERAPPFOLDER = &quot;&quot; OR NOT WIXPERMACHINEAPPFOLDER = &quot;&quot;" />
|} info.short_name info.short_name info.short_name

let print_application fmt info =
  Format.fprintf fmt {|
    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="APPLICATIONFOLDER" Name="%s" />
    </StandardDirectory>

    <ComponentGroup Id="APPLICATION" Directory="APPLICATIONFOLDER">
      <Files Include="%s\**" />
    </ComponentGroup>
|} info.short_name info.directory

let print_shortcut fmt _info shortcut =
  match shortcut with
  | File { name; description; target } ->
      Format.fprintf fmt {|
        <Shortcut Name="%s" Description="%s"
                  Target="%s" WorkingDirectory="APPLICATIONFOLDER" />
|} name description target
  | URL { name; target } ->
      Format.fprintf fmt {|
        <util:InternetShortcut Name="%s"
                               Target="%s"
                               IconFile="[System32Folder]SHELL32.dll" IconIndex="221" />
|} name target

let print_shortcuts fmt info =
  match info.shortcuts with
  | [] ->
      ()
  | shortcuts ->
      Format.fprintf fmt {|
    <StandardDirectory Id="ProgramMenuFolder">
      <Directory Id="ShortcutsFolder" Name="%s" />
    </StandardDirectory>

    <ComponentGroup Id="SHORTCUTS" Directory="ShortcutsFolder">
      <Component>
        <RegistryValue Root="HKMU" Key="SOFTWARE\%s\Components" Name="SHORTCUTS" Type="integer" Value="1" KeyPath="yes" />
|} info.long_name info.short_name;
      List.iter (print_shortcut fmt info) shortcuts;
      Format.fprintf fmt {|
        <RemoveFile Name="*.*" On="uninstall" />
        <RemoveFolder On="uninstall" />
      </Component>
    </ComponentGroup>
|}

let print_var fmt info (var : var) =
  let part =
    match var.var_part with
    | All -> "all"
    | First -> "first"
    | Last -> "last"
  in
  Format.fprintf fmt
{|
      <Component Condition="NOT ALLUSERS = 1">
        <RegistryValue Root="HKMU" Key="SOFTWARE\%s\Components" Name="%s_USER" Type="integer" Value="1" KeyPath="yes" />
        <Environment Action="set" Part="%s" Name="%s" Value="%s" />
      </Component>
      <Component Condition="ALLUSERS = 1">
        <RegistryValue Root="HKMU" Key="SOFTWARE\%s\Components" Name="%s_SYS" Type="integer" Value="1" KeyPath="yes" />
        <Environment System="yes" Action="set" Part="%s" Name="%s" Value="%s" />
      </Component>
|} info.short_name var.var_name part var.var_name var.var_value
   info.short_name var.var_name part var.var_name var.var_value

let print_environment fmt info =
  match info.environment with
  | [] ->
      ()
  | vars ->
      Format.fprintf fmt {|
    <ComponentGroup Id="ENVIRONMENT">
|};
      List.iter (print_var fmt info) vars;
      Format.fprintf fmt {|
    </ComponentGroup>
|}

let print_key fmt info (key : key) =
  Format.fprintf fmt
{|
      <Component>
        <RegistryValue Root="HKMU" Key="SOFTWARE\%s" Name="%s" Type="%s" Value="%s" KeyPath="yes" />
      </Component>
|} info.short_name key.key_name key.key_type key.key_value

let print_registry fmt info =
  let regkeys =
    { key_name = "(default)"; key_type = "string"; key_value = "[APPLICATIONFOLDER]" } :: info.registry
  in
  Format.fprintf fmt {|
    <ComponentGroup Id="REGISTRY">
|};
  List.iter (print_key fmt info) regkeys;
  Format.fprintf fmt {|
    </ComponentGroup>
|}

let print_features fmt info =
  Format.fprintf fmt {|
    <Feature Id="ALLFEAT" Title="Full install" Description="Install the whole application" AllowAbsent="no" Level="1">
      <ComponentGroupRef Id="APPLICATION" />|};
  if info.shortcuts <> [] then
    Format.fprintf fmt {|
      <ComponentGroupRef Id="SHORTCUTS" />|};
  if info.environment <> [] then
    Format.fprintf fmt {|
      <ComponentGroupRef Id="ENVIRONMENT" />|};
  if info.registry <> [] then
    Format.fprintf fmt {|
      <ComponentGroupRef Id="REGISTRY" />|};
  Format.fprintf fmt {|
    </Feature>
|}

let print_assets fmt info =
  Format.fprintf fmt {|
    <Property Id="ARPPRODUCTICON" Value="ICON" />
    <Icon Id="ICON" SourceFile="%s" />
    <WixVariable Id="WixUILicenseRtf" Value="%s" />
    <WixVariable Id="WixUIBannerBmp" Value="%s" />
    <WixVariable Id="WixUIDialogBmp" Value="%s" />
|} info.icon info.license info.banner info.background

let print_ui fmt info =
  Format.fprintf fmt {|
    <Property Id="WIXUI_INSTALLDIR" Value="APPLICATIONFOLDER" />
    <Property Id="WIXUI_EXITDIALOGOPTIONALTEXT" Value="%s has been installed" />
    <Property Id="ApplicationFolderName" Value="%s" />
    <ui:WixUI Id="WixUI_Custom%s" />
|} info.short_name info.short_name
    (if info.is_plugin then "Plugin" else "App")

let print_footer fmt =
  Format.fprintf fmt {|
  </Package>

</Wix>
|}

let print_wix fmt info =
  print_header fmt info;
  print_package fmt info;
  print_plugin_specifics fmt info;
  print_application fmt info;
  print_shortcuts fmt info;
  print_environment fmt info;
  print_registry fmt info;
  print_features fmt info;
  print_assets fmt info;
  print_ui fmt info;
  print_footer fmt;
  ()
