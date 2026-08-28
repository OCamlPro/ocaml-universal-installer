(**************************************************************************)
(*                                                                        *)
(*    Copyright 2026 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Oui

(* [is_static] *)

let%expect_test "is_static: yes" =
  let lines =
    [ ""
    ; "Elf file type is EXEC (Executable file)"
    ; "Entry point 0x401163"
    ; "There are 10 program headers, starting at offset 64"
    ; ""
    ; "Program Headers:"
    ; "  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align"
    ; "  LOAD           0x000000 0x0000000000400000 0x0000000000400000 0x0002c4 0x0002c4 R   0x1000"
    ; "  LOAD           0x001000 0x0000000000401000 0x0000000000401000 0x64b481 0x64b481 R E 0x1000"
    ; "  LOAD           0x64d000 0x0000000000a4d000 0x0000000000a4d000 0x10f804 0x10f804 R   0x1000"
    ; "  LOAD           0x75cb70 0x0000000000b5db70 0x0000000000b5db70 0x684fd8 0x687150 RW  0x1000"
    ; "  NOTE           0x000270 0x0000000000400270 0x0000000000400270 0x000030 0x000030 R   0x8"
    ; "  NOTE           0x0002a0 0x00000000004002a0 0x00000000004002a0 0x000024 0x000024 R   0x4"
    ; "  TLS            0x75cb70 0x0000000000b5db70 0x0000000000b5db70 0x000000 0x000020 R   0x8"
    ; "  GNU_PROPERTY   0x000270 0x0000000000400270 0x0000000000400270 0x000030 0x000030 R   0x8"
    ; "  GNU_STACK      0x000000 0x0000000000000000 0x0000000000000000 0x000000 0x000000 RW  0x10"
    ; "  GNU_RELRO      0x75cb70 0x0000000000b5db70 0x0000000000b5db70 0x000490 0x000490 R   0x1"
    ; ""
    ; " Section to Segment mapping:"
    ; "  Segment Sections..."
    ; "   00     .note.gnu.property .note.gnu.build-id "
    ; "   01     .init .text .fini "
    ; "   02     .rodata .eh_frame "
    ; "   03     .init_array .fini_array .data.rel.ro .got .data .bss "
    ; "   04     .note.gnu.property "
    ; "   05     .note.gnu.build-id "
    ; "   06     .tbss "
    ; "   07     .note.gnu.property "
    ; "   08     "
    ; "   09     .init_array .fini_array .data.rel.ro .got "
    ; ""
    ]
  in
  let result = Readelf.(is_static (program_headers_from_lines lines)) in
  Format.printf "%b" result;
  [%expect {| true |}]

let%expect_test "is_static: no" =
  let lines =
    [ ""
    ; "Elf file type is DYN (Position-Independent Executable file)"
    ; "Entry point 0x6795d0"
    ; "There are 16 program headers, starting at offset 64"
    ; ""
    ; "Program Headers:"
    ; "  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align"
    ; "  PHDR           0x000040 0x0000000000000040 0x0000000000000040 0x000380 0x000380 R   0x8"
    ; "  LOAD           0x000000 0x0000000000000000 0x0000000000000000 0x677718 0x677718 R   0x1000"
    ; "  GNU_STACK      0x000000 0x0000000000000000 0x0000000000000000 0x000000 0x000000 RW  0x10"
    ; "  GNU_PROPERTY   0x000370 0x0000000000000370 0x0000000000000370 0x000020 0x000020 R   0x8"
    ; "  LOAD           0x678000 0x0000000000678000 0x0000000000678000 0x897651 0x897651 R E 0x1000"
    ; "  LOAD           0xf10000 0x0000000000f10000 0x0000000000f10000 0x209318 0x209318 R   0x1000"
    ; "  GNU_EH_FRAME   0xf924b4 0x0000000000f924b4 0x0000000000f924b4 0x03c33c 0x03c33c R   0x4"
    ; "  LOAD           0x1119b10 0x000000000111ab10 0x000000000111ab10 0x701740 0x702500 RW  0x1000"
    ; "  TLS            0x1119b10 0x000000000111ab10 0x000000000111ab10 0x000000 0x00001c R   0x8"
    ; "  GNU_RELRO      0x1119b10 0x000000000111ab10 0x000000000111ab10 0x0004f0 0x0004f0 R   0x1"
    ; "  DYNAMIC        0x2212000 0x0000000002212000 0x0000000002212000 0x000230 0x000230 RW  0x8"
    ; "  LOAD           0x2212000 0x0000000002212000 0x0000000002212000 0x192cc0 0x192cc0 RW  0x1000"
    ; "  INTERP         0x23a4c38 0x00000000023a4c38 0x00000000023a4c38 0x00001c 0x00001c R   0x1"
    ; "      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]"
    ; "  NOTE           0x23a4c58 0x00000000023a4c58 0x00000000023a4c58 0x000020 0x000020 R   0x4"
    ; "  NOTE           0x23a4c78 0x00000000023a4c78 0x00000000023a4c78 0x000024 0x000024 R   0x4"
    ; "  NOTE           0x23a4ca0 0x00000000023a4ca0 0x00000000023a4ca0 0x000020 0x000020 R   0x8"
    ; ""
    ; " Section to Segment mapping:"
    ; "  Segment Sections..."
    ; "   00"
    ; "   01     .dynsym .gnu.version .gnu.version_r .rela.dyn .rela.plt"
    ; "   02"
    ; "   03"
    ; "   04     .init .plt .plt.got .text .fini"
    ; "   05     .rodata .eh_frame_hdr .eh_frame"
    ; "   06     .eh_frame_hdr"
    ; "   07     .init_array .fini_array .data.rel.ro .got .got.plt .data .bss"
    ; "   08     .tbss"
    ; "   09     .init_array .fini_array .data.rel.ro .got"
    ; "   10     .dynamic"
    ; "   11     .dynamic .dynstr .gnu.hash .interp .note.ABI-tag .note.gnu.build-id .note.gnu.property"
    ; "   12     .interp"
    ; "   13     .note.ABI-tag"
    ; "   14     .note.gnu.build-id"
    ; "   15     .note.gnu.property"
    ; "   "
    ]
  in
  let result = Readelf.(is_static (program_headers_from_lines lines)) in
  Format.printf "%b" result;
  [%expect {| false |}]
