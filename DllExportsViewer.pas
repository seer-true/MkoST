unit DllExportsViewer;

interface

uses
  Windows, SysUtils, Classes, Generics.Collections;

type
  TExportInfo = record
    Name: string;
    Ordinal: Word;
  end;

// Результат поиска последовательности
  TBinarySearchResult = record
    Pattern: AnsiString;
    Positions: TArray<Int64>;
    function Count: Integer;
  end;

  TBinarySearchResults = TArray<TBinarySearchResult>;
// procedure ShowDllExports(const DllFileName: string);
procedure ShowDllExports(const DllFileName: string; OutputList: TStringList);
function FindBinaryPatternsInFile(const FileName: string; const Patterns: array of AnsiString; MaxResults: Integer = 0): TBinarySearchResults;

implementation

{ TBinarySearchResult }
function TBinarySearchResult.Count: Integer;
begin
  Result := Length(Positions);
end;

{ Основные функции }
(* procedure ShowDllExports(const DllFileName: string);
var
  hDll: HMODULE;
  pExportDir: PImageExportDirectory;
  pNameRVAs: PDWORD;
  pName: PAnsiChar;
  i: Integer;
  ExportList: TStringList;
  ExportInfo: TExportInfo;
  DllBase: Pointer;
  DosHeader: PImageDosHeader;
  NTHeader: PImageNtHeaders;
begin
  if not FileExists(DllFileName) then
  begin
    ShowMessage('Файл не найден: ' + DllFileName);
    Exit;
  end;

  hDll := LoadLibraryEx(PChar(DllFileName), 0, DONT_RESOLVE_DLL_REFERENCES);
  if hDll = 0 then
  begin
    ShowMessage('Не удалось загрузить DLL: ' + SysErrorMessage(GetLastError));
    Exit;
  end;

  try
    DllBase := Pointer(hDll);
    DosHeader := DllBase;

    if DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
    begin
      ShowMessage('Неверный формат PE-файла');
      Exit;
    end;

    NTHeader := PImageNtHeaders(PByte(DllBase) + DosHeader^._lfanew);
    if NTHeader^.Signature <> IMAGE_NT_SIGNATURE then
    begin
      ShowMessage('Неверная сигнатура PE-файла');
      Exit;
    end;

    pExportDir := PImageExportDirectory(PByte(DllBase) +
                NTHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);

    if not Assigned(pExportDir) then
    begin
      ShowMessage('DLL не содержит экспортируемых функций');
      Exit;
    end;

    ExportList := TStringList.Create;
    try
      pNameRVAs := PDWORD(PByte(DllBase) + pExportDir^.AddressOfNames);

      for i := 0 to pExportDir^.NumberOfNames - 1 do
      begin
        pName := PAnsiChar(PByte(DllBase) + pNameRVAs^);
        ExportInfo.Name := string(pName);
        ExportInfo.Ordinal := pExportDir^.Base + i;
        ExportList.Add(Format('Имя: %-40s  Ordinal: %d', [ExportInfo.Name, ExportInfo.Ordinal]));
        Inc(pNameRVAs);
      end;

      ExportList.Sort;

      if ExportList.Count > 0 then
        ShowMessage('Экспортируемые функции:' + #13#10 + ExportList.Text)
      else
        ShowMessage('Не найдено экспортируемых функций');
    finally
      ExportList.Free;
    end;
  finally
    FreeLibrary(hDll);
  end;
end; *)
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
    raise Exception.Create('Параметр OutputList не может быть nil');
  OutputList.Clear;
  if not FileExists(DllFileName) then
    raise Exception.Create('Файл не найден: ' + DllFileName);
  hDll := LoadLibraryEx(PChar(DllFileName), 0, DONT_RESOLVE_DLL_REFERENCES);
  if hDll = 0 then
    raise Exception.Create('Не удалось загрузить DLL: ' + SysErrorMessage(GetLastError));
  try
    DllBase := Pointer(hDll);
    DosHeader := DllBase;
    if DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
      raise Exception.Create('Неверный формат PE-файла');
    NTHeader := PImageNtHeaders(PByte(DllBase) + DosHeader^._lfanew);
    if NTHeader^.Signature <> IMAGE_NT_SIGNATURE then
      raise Exception.Create('Неверная сигнатура PE-файла');
    pExportDir := PImageExportDirectory(PByte(DllBase) + NTHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    if not Assigned(pExportDir) then
      Exit; // Нет экспортируемых функций
    pNameRVAs := PDWORD(PByte(DllBase) + pExportDir^.AddressOfNames);
    for i := 0 to pExportDir^.NumberOfNames - 1 do
    begin
      pName := PAnsiChar(PByte(DllBase) + pNameRVAs^);
      ExportName := string(pName);
      ExportOrdinal := pExportDir^.Base + i;
      OutputList.Add(Format('%-40s : Ordinal %d', [ExportName, ExportOrdinal]));
      Inc(pNameRVAs);
    end;
// OutputList.Sort;
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
    raise Exception.Create('Файл не найден: ' + FileName);
  if Length(Patterns) = 0 then
    raise Exception.Create('Не заданы шаблоны для поиска');
  // Инициализация результатов
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
    MaxBufferSize := 1024 * 1024; // 1MB буфер
    // Определяем минимальный размер буфера (макс. длина шаблона + перекрытие)
    for i := 0 to High(Patterns) do
      if Length(Patterns[i]) > MaxBufferSize then
        MaxBufferSize := Length(Patterns[i]) * 2;
    SetLength(Buffer, MaxBufferSize);
    // Читаем файл блоками
    while TotalRead < FileSize do
    begin
      BytesRead := FileStream.Read(Buffer[0], MaxBufferSize);
      if BytesRead = 0 then
        Break;
      // Поиск каждого шаблона в текущем буфере
      for i := 0 to High(Patterns) do
      begin
        // Пропускаем если уже нашли максимальное количество результатов
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
            // Добавляем позицию (с учетом ранее прочитанных данных)
            SetLength(Result[i].Positions, Length(Result[i].Positions) + 1);
            Result[i].Positions[High(Result[i].Positions)] := TotalRead + j;
            // Прекращаем поиск если достигли MaxResults
            if (MaxResults > 0) and (Result[i].Count >= MaxResults) then
              Break;
          end;
        end;
      end;
      Inc(TotalRead, BytesRead);
      // Возвращаемся назад для перекрытия (чтобы не пропустить шаблоны на границе блоков)
      if TotalRead < FileSize then
        FileStream.Position := FileStream.Position - Length(Patterns[High(Patterns)]) + 1;
    end;
  finally
    FileStream.Free;
  end;
end;

end.
