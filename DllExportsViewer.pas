unit DllExportsViewer;

interface

uses
  Windows, SysUtils, Classes, Generics.Collections;

type
  TExportInfo = record
    Name: string;
    Ordinal: Word;
  end;

  /// <summary>
  /// ��������� ������ ������������������ ��������
  /// </summary>
  TBinarySearchResult = record
    Pattern: AnsiString;
    Positions: TArray<Int64>;
    function Count: Integer;
  end;

  TBinarySearchResults = TArray<TBinarySearchResult>;

  /// <summary>
  /// ����� �������������� ������� �� DLL
  /// </summary>
procedure ShowDllExports(const DllFileName: string; OutputList: TStringList);
/// <summary>
/// ����� ��������� ������������������ �������� � ����� DLL
/// </summary>
function FindBinaryPatternsInFile(const FileName: string; const Patterns: array of AnsiString; MaxResults: Integer = 0): TBinarySearchResults;

implementation

{ TBinarySearchResult }
function TBinarySearchResult.Count: Integer;
begin
  Result := Length(Positions);
end;

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

function FindBinaryPatternsInFile(const FileName: string; const Patterns: array of AnsiString; MaxResults: Integer = 0): TBinarySearchResults;
var
  FileStream: TFileStream;
  Buffer: array of Byte;
  BytesRead: Integer;
  i, j, k: Integer;
  PatternFound: Boolean;
  FileSize, TotalRead: Int64;
  MaxBufferSize: Integer;
begin
  if not FileExists(FileName) then
    raise Exception.Create('���� �� ������: ' + FileName);
  if Length(Patterns) = 0 then
    raise Exception.Create('�� ������ ������� ��� ������');

  SetLength(Result, Length(Patterns));
  for i := 0 to High(Result) do
  begin
    Result[i].Pattern := Patterns[i];
    SetLength(Result[i].Positions, 0);
  end;
  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    FileSize := FileStream.Size;
    TotalRead := 0;
    MaxBufferSize := 1024 * 1024; // 1MB �����
    // ����������� ������ ������ (����. ����� ������� + ����������)
    for i := 0 to High(Patterns) do
      if Length(Patterns[i]) > MaxBufferSize then
        MaxBufferSize := Length(Patterns[i]) * 2;
    SetLength(Buffer, MaxBufferSize);
    // ������ ���� �������
    while TotalRead < FileSize do
    begin
      BytesRead := FileStream.Read(Buffer[0], MaxBufferSize);
      if BytesRead = 0 then
        Break;
      // ����� ������� ������� � ������� ������
      for i := 0 to High(Patterns) do
      begin
        // ���������� ���� ��� ����� ������������ ���������� �����������
        if (MaxResults > 0) and (Result[i].Count >= MaxResults) then
          Continue;
        for j := 0 to BytesRead - Length(Patterns[i]) do
        begin
          PatternFound := True;
          for k := 1 to Length(Patterns[i]) do
          begin
            if Buffer[j + k - 1] <> Ord(Patterns[i][k]) then
            begin
              PatternFound := False;
              Break;
            end;
          end;
          if PatternFound then
          begin
            // ��������� ������� (� ������ ����� ����������� ������)
            SetLength(Result[i].Positions, Length(Result[i].Positions) + 1);
            Result[i].Positions[High(Result[i].Positions)] := TotalRead + j;
            // ����� ������ ���� �������� MaxResults
            if (MaxResults > 0) and (Result[i].Count >= MaxResults) then
              Break;
          end;
        end;
      end;
      Inc(TotalRead, BytesRead);
      // ����� ��� ���������� (����� �� ���������� ������� �� ������� ������)
      if TotalRead < FileSize then
        FileStream.Position := FileStream.Position - Length(Patterns[High(Patterns)]) + 1;
    end;
  finally
    FileStream.Free;
  end;
end;

end.
