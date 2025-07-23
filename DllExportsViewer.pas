unit DllExportsViewer;

interface

uses
  Windows, SysUtils, Classes;

  /// <summary>
  /// ����� �������������� ������� �� DLL
  /// </summary>
procedure ShowDllExports(const DllFileName: string; OutputList: TStringList);

implementation

procedure ShowDllExports(const DllFileName: string; OutputList: TStringList);
var
  hDll: HMODULE;
  pExportDir: PImageExportDirectory;
  pNameRVAs: PDWORD;
  pName: PAnsiChar;
  i: Cardinal; // Integer;
  ExportName: string;
  ExportOrdinal: Word;
  DllBase: Pointer;
  DosHeader: PImageDosHeader;
  NTHeader: PImageNtHeaders;
begin
  if not Assigned(OutputList) then
    raise Exception.Create('�������� OutputList �� ����� ���� nil');
  OutputList.Clear;
  if not FileExists(DllFileName) then
    raise Exception.Create('���� �� ������: ' + DllFileName);
  hDll := LoadLibraryEx(PChar(DllFileName), 0, DONT_RESOLVE_DLL_REFERENCES);
  if hDll = 0 then
    raise Exception.Create('�� ������� ��������� DLL: ' + SysErrorMessage(GetLastError));
  try
    DllBase := Pointer(hDll);
    DosHeader := DllBase;
    if DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
      raise Exception.Create('�������� ������ PE-�����');
    NTHeader := PImageNtHeaders(PByte(DllBase) + DosHeader^._lfanew);
    if NTHeader^.Signature <> IMAGE_NT_SIGNATURE then
      raise Exception.Create('�������� ��������� PE-�����');
    pExportDir := PImageExportDirectory(PByte(DllBase) + NTHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    if not Assigned(pExportDir) then
      Exit; // ��� �������
    pNameRVAs := PDWORD(PByte(DllBase) + pExportDir^.AddressOfNames);
    for i := 0 to pExportDir^.NumberOfNames - 1 do
    begin
      pName := PAnsiChar(PByte(DllBase) + pNameRVAs^);
      ExportName := string(pName);
      ExportOrdinal := pExportDir^.Base + i;
      OutputList.Add(Format('%-40s', [ExportName]));
      Inc(pNameRVAs);
    end;
  finally
    FreeLibrary(hDll);
  end;
end;

end.
