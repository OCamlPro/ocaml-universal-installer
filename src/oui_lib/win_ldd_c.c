
#include <stdlib.h>
#include <wchar.h>

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>

#if defined(_WIN32) || defined(_WIN64)

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

value ml_wchar_to_value(const WCHAR *string, UINT codepage)
{
  CAMLparam0();
  CAMLlocal1(mlResult);
  int w_len = wcslen(string);
  int len = WideCharToMultiByte(CP_UTF8, 0, string, w_len, NULL, 0, NULL, NULL);
  if (len == 0) {
    mlResult = caml_copy_string("");
  } else {
    mlResult = caml_alloc_string(len);
    WideCharToMultiByte(CP_UTF8, 0, string, w_len, (char *)Bytes_val(mlResult), len, NULL, NULL);
  }
  CAMLreturn(mlResult);
}

WCHAR * ml_value_to_wchar(value mlString, UINT codepage)
{
  CAMLparam1(mlString);
  WCHAR *result = NULL;
  int w_len = MultiByteToWideChar(codepage, 0, String_val(mlString), -1, NULL, 0);
  if (w_len == 0) {
    result = NULL;
  } else {
    result = (WCHAR *)malloc(w_len * sizeof(WCHAR));
    if (result != NULL) {
      MultiByteToWideChar(codepage, 0, String_val(mlString), -1, result, w_len);
    }
  }
  CAMLreturnT(WCHAR *, result);
}

CAMLprim value ml_resolve_dll(value mlDllName)
{
  CAMLparam1(mlDllName);
  CAMLlocal2(mlResult, mlTmp);
  WCHAR *dllname = ml_value_to_wchar(mlDllName, CP_ACP);
  WCHAR filename[MAX_PATH];
  DWORD len = SearchPathW(NULL, dllname, NULL, MAX_PATH, filename, NULL);
  if (len > 0 && len < MAX_PATH) {
    mlTmp = ml_wchar_to_value(filename, CP_UTF8);
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
  mlResult = ml_wchar_to_value(path, CP_UTF8);
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
  CAMLreturn(caml_copy_string(""));
}

#endif
