
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <caml/mlvalues.h>
#include "caml/memory.h"
#include "caml/alloc.h"
#include "caml/fail.h"

/* Header signatures */
#define MZ_MAGIC                          "MZ"
#define PE_MAGIC                          "PE\0\0"
#define PE32_MAGIC                        "\x0b\x01"
#define PE32_PLUS_MAGIC                   "\x0b\x02"

/* Header signatures sizes */
#define MAX_MAGIC_SIZE                     4
#define MZ_MAGIC_SIZE                      2
#define PE_MAGIC_SIZE                      4
#define PE32_MAGIC_SIZE                    2

/* MZ Header field offsets */
#define MZ_LFANEW                          0x3C

/* PE Header field offsets */
#define PE_NUMBER_OF_SECTIONS              0x06
#define PE_SIZE_OF_OPTIONAL_HEADER         0x14

/* PE32(+) Optional Header field offsets */
#define PE32_NUMBER_OF_RVA_AND_SIZES       0x5C
#define PE32_PLUS_NUMBER_OF_RVA_AND_SIZES  0x6C

/* Data Directory field offsets */
#define DD_IMPORTS_RVA                     0x08

/* Import Descriptor field offsets */
#define ID_NAME                            0x0C

/* Sizes of various structures */
#define PE_HEADER_SIZE                     0x18
#define PE32_HEADER_SIZE                   0x60
#define PE32_PLUS_HEADER_SIZE              0x70
#define IMPORT_DESCRIPTOR_SIZE             0x14

typedef struct section_header_t {
  char  name[8];
  uint32_t virtual_size;
  uint32_t virtual_address;
  uint32_t raw_data_size;
  uint32_t raw_data_address;
  uint32_t reloc_address;
  uint32_t linenum_address;
  uint16_t nb_reloc;
  uint16_t nb_linenum;
  uint32_t characteristics;
} section_header_t;

static uint32_t rva_to_address(const section_header_t *sect_hdr, int nb_sect, uint32_t rva)
{
  uint32_t address = 0;
  for (int i = 0; i < nb_sect; ++i) {
    if (rva >= sect_hdr[i].virtual_address &&
        rva < sect_hdr[i].virtual_address + sect_hdr[i].virtual_size) {
      address = sect_hdr[i].raw_data_address +
        (rva - sect_hdr[i].virtual_address);
      break;
    }
  }
  return address;
}

static int32_t read_string(char *string, FILE *f)
{
  int c, i = 0;
  do {
    c = fgetc(f);
    if (c == EOF) {
      return -1;
    }
    string[i++] = (char)c;
  } while (c != 0);
  return (i-1);
}

CAMLprim value ml_get_dlls(value mlFilename)
{
  CAMLparam1(mlFilename);
  CAMLlocal2(mlResult, mlTmp);

  const char *err = NULL;
  mlResult = Val_emptylist;

  section_header_t *sect_hdr = NULL;

  FILE *f = fopen(String_val(mlFilename), "rb");
  if (f == NULL) {
    err = "Can't open file";
    goto end;
  }

  char magic[MAX_MAGIC_SIZE];
  size_t n = fread(magic, MZ_MAGIC_SIZE, 1, f);
  if (n != 1) {
    err = "Can't read MZ header";
    goto end;
  }
  if (memcmp(magic, MZ_MAGIC, MZ_MAGIC_SIZE) != 0) {
    err = "Invalid MZ signature";
    goto end;
  }

  uint32_t pe_address;
  n = fseek(f, MZ_LFANEW, SEEK_SET);
  n = fread(&pe_address, sizeof(pe_address), 1, f);
  if (n != 1) {
    err = "Can't read PE address";
    goto end;
  }

  fseek(f, pe_address, SEEK_SET);
  n = fread(magic, PE_MAGIC_SIZE, 1, f);
  if (n != 1) {
    err = "Can't read PE signature";
    goto end;
  }
  if (memcmp(magic, PE_MAGIC, PE_MAGIC_SIZE) != 0) {
    err = "Invalid ME signature";
    goto end;
  }

  uint16_t nb_sections;
  fseek(f, pe_address + PE_NUMBER_OF_SECTIONS, SEEK_SET);
  n = fread(&nb_sections, sizeof(nb_sections), 1, f);
  if (n != 1) {
    err = "Can't read number of sections";
    goto end;
  }

  uint16_t size_opt_hdr;
  fseek(f, pe_address + PE_SIZE_OF_OPTIONAL_HEADER, SEEK_SET);
  n = fread(&size_opt_hdr, sizeof(size_opt_hdr), 1, f);
  if (n != 1) {
    err = "Can't read size of optional header";
    goto end;
  }

  if (size_opt_hdr == 0) {
    /* Optional header is empty: no imports */
    goto end;
  }

  fseek(f, pe_address + PE_HEADER_SIZE, SEEK_SET);
  n = fread(magic, PE32_MAGIC_SIZE, 1, f);
  if (n != 1) {
    err = "Can't read optional header signature";
    goto end;
  }
  uint32_t nb_rva_sizes_address = pe_address + PE_HEADER_SIZE;
  uint32_t data_dir_address = pe_address + PE_HEADER_SIZE;
  if (memcmp(magic, PE32_MAGIC, PE32_MAGIC_SIZE) == 0) {
    nb_rva_sizes_address += PE32_NUMBER_OF_RVA_AND_SIZES;
    data_dir_address += PE32_HEADER_SIZE;
  } else if (memcmp(magic, PE32_PLUS_MAGIC, PE32_MAGIC_SIZE) == 0) {
    nb_rva_sizes_address += PE32_PLUS_NUMBER_OF_RVA_AND_SIZES;
    data_dir_address += PE32_PLUS_HEADER_SIZE;
  } else {
    err = "Invalid optional header signature";
    goto end;
  }

  uint32_t nb_rva_sizes;
  fseek(f, nb_rva_sizes_address, SEEK_SET);
  n = fread(&nb_rva_sizes, sizeof(nb_rva_sizes), 1, f);
  if (n != 1) {
    err = "Can't read number of RVA and sizes";
    goto end;
  }

  if (nb_rva_sizes < 2) {
    /* No import table: skip */
    goto end;
  }

  sect_hdr = malloc(nb_sections * sizeof(section_header_t));
  if (sect_hdr == NULL) {
    err = "Can't allocate memory";
    goto end;
  }
  fseek(f, pe_address + PE_HEADER_SIZE + size_opt_hdr, SEEK_SET);
  for (int i = 0; i < nb_sections; ++i) {
    n = fread(&sect_hdr[i], sizeof(sect_hdr[i]), 1, f);
    if (n != 1) {
      err = "Can't read PE section header";
      goto end;
    }
  }

  uint32_t imports_rva;
  fseek(f, data_dir_address + DD_IMPORTS_RVA, SEEK_SET);
  n = fread(&imports_rva, sizeof(imports_rva), 1, f);
  if (n != 1) {
    err = "Can't read import table RVA";
    goto end;
  }

  uint32_t imports_address = rva_to_address(sect_hdr, nb_sections, imports_rva);
  for (int nb_imports = 0; ; ++nb_imports) {
    uint32_t name_rva;
    fseek(f, imports_address + nb_imports * IMPORT_DESCRIPTOR_SIZE + ID_NAME, SEEK_SET);
    n = fread(&name_rva, sizeof(name_rva), 1, f);
    if (n != 1) {
      err = "Can't read import descriptor";
      goto end;
    }
    if (name_rva == 0) {
      break;
    }
    uint32_t name_address = rva_to_address(sect_hdr, nb_sections, name_rva);
    char name[1024];
    fseek(f, name_address, SEEK_SET);
    int32_t len = read_string(name, f);
    if (len < 0) {
      err = "Can't read import name";
      goto end;
    }
    mlTmp = mlResult;
    mlResult = caml_alloc(2, 0);
    Store_field(mlResult, 1, mlTmp);
    mlTmp = caml_copy_string(name);
    Store_field(mlResult, 0, mlTmp);
  }

end:
  if (sect_hdr != NULL) {
    free(sect_hdr);
  }
  if (f != NULL) {
    fclose(f);
  }
  if (err != NULL) {
    caml_failwith(err);
  }
  CAMLreturn(mlResult);
}

#if defined(_WIN32) || defined(_WIN64)

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wchar.h>

CAMLprim value ml_wchar_to_value(const WCHAR *string)
{
  CAMLparam0();
  CAMLlocal1(mlResult);
  int w_len = wcslen(string);
  int len = WideCharToMultiByte(CP_UTF8, 0, string, w_len, NULL, 0, NULL, NULL);
  if (len == 0) {
    CAMLreturn(Val_unit);
  }
  mlResult = caml_alloc_string(len);
  WideCharToMultiByte(CP_UTF8, 0, string, w_len, (char *)Bytes_val(mlResult), len, NULL, NULL);
  CAMLreturn(mlResult);
}

CAMLprim WCHAR * ml_value_to_wchar(value mlString)
{
  CAMLparam1(mlString);
  int w_len = MultiByteToWideChar(CP_UTF8, 0, String_val(mlString), -1, NULL, 0);
  if (w_len == 0) {
    CAMLreturnT(WCHAR *, NULL);
  }
  WCHAR *result = (WCHAR *)malloc(w_len * sizeof(WCHAR));
  if (result != NULL) {
    int res = MultiByteToWideChar(CP_UTF8, 0, String_val(mlString), -1, result, w_len);
    if (res == 0) {
      free(result);
      CAMLreturnT(WCHAR *, NULL);
    }
  }
  CAMLreturnT(WCHAR *, result);
}

CAMLprim value ml_resolve_dll(value mlDllName)
{
  CAMLparam1(mlDllName);
  CAMLlocal2(mlResult, mlTmp);
  WCHAR *dllname = ml_value_to_wchar(mlDllName);
  WCHAR filename[MAX_PATH];
  DWORD len = SearchPathW(NULL, dllname, NULL, MAX_PATH, filename, NULL);
  if (len > 0 && len < MAX_PATH) {
    mlTmp = ml_wchar_to_value(filename);
    mlResult = caml_alloc_some(mlTmp);
  } else {
    mlResult = Val_none;
  }
  free(dllname);
  CAMLreturn(mlResult);
}

CAMLprim value ml_get_windows_directory(value mlUnit)
{
  CAMLparam1(mlUnit);
  CAMLlocal1(mlResult);
  WCHAR path[MAX_PATH+1];
  UINT len = GetWindowsDirectoryW(path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    caml_failwith("GetWindowsDirectoryW failed");
  }
  if (path[len - 1] != L'\\') {
    path[len++] = L'\\';
    path[len] = L'\0';
  }
  mlResult = ml_wchar_to_value(path);
  CAMLreturn(mlResult);
}

#else

CAMLprim value ml_resolve_dll(value mlDllName)
{
  CAMLparam1(mlDllName);
  CAMLreturn(Val_none);
}

CAMLprim value ml_get_windows_directory(value mlUnit)
{
  CAMLparam1(mlUnit);
  CAMLreturn(Val_unit);
}

#endif
