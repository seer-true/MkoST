/// <summary>
/// Функционал поиска списка файлов по маске и стартовой папке поиска. Ожидаемый результат - количество найденных
/// файлов, например, входные параметры: (“*.txt”, “P:\Documents\”). Дополнительно: o возврат списка полных путей
/// найденных файлов. <br />o возможность запустить одну задачу поиска передавая несколько масок или возможность
/// добавить дополнительные параметры поиска на усмотрение исполнителя. <br />
/// </summary>
unit FileSearchUtils;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.IOUtils, System.Generics.Collections;

type
  TExportInfo = record
    Name: string;
    Ordinal: Word;
  end;

  /// <summary>
  /// Результат поиска последовательности символов
  /// </summary>
  TBinarySearchResult = record
    Pattern: AnsiString;
    Positions: TArray<Int64>;
    function Count: Integer;
  end;

  TBinarySearchResults = TArray<TBinarySearchResult>;
  /// <summary>
  ///   опции поиска
  /// </summary>
  TFileSearchOptions = set of (fsRecursive, // в подпапках
    fsCaseSensitive, // учитывать регистр
    fsHiddenFiles, // скрытые файлы
    fsSystemFiles // системные файлы
    );
/// <summary>
///   Поиск по маске
/// </summary>
function FindFilesByMask(const Masks: array of string; // Маски файлов (например, ['*.txt', '*.doc'])
  const StartDir: string; // Стартовая папка
  out FileList: TStringList; // Список найденных файлов (полные пути)
  Options: TFileSearchOptions = [fsRecursive] // Доп. параметры поиска
  ): Integer; // Возвращает количество найденных файлов
/// <summary>
/// поиск вхождений последовательности символов в файле DLL
/// </summary>
function FindBinaryPatternsInFile(const FileName: string; const Patterns: array of AnsiString; MaxResults: Integer = 0): TBinarySearchResults;

implementation

{ TBinarySearchResult }
function TBinarySearchResult.Count: Integer;
begin
  Result := Length(Positions);
end;

function FindFilesByMask(const Masks: array of string; const StartDir: string; out FileList: TStringList; Options: TFileSearchOptions = [fsRecursive]
  ): Integer;
var
  SearchOption: TSearchOption;
  Mask: string;
  Files: TStringDynArray;
  FileAttrs: Integer;
begin
  Result := 0;
  FileList := TStringList.Create;
// глубина поиска
  if fsRecursive in Options then
    SearchOption := TSearchOption.soAllDirectories
  else
    SearchOption := TSearchOption.soTopDirectoryOnly;

// атрибуты файлов
  FileAttrs := faAnyFile;
  if not(fsHiddenFiles in Options) then
    FileAttrs := FileAttrs and not faHidden;
  if not(fsSystemFiles in Options) then
    FileAttrs := FileAttrs and not faSysFile;

  try // поиск по каждой маске
    for Mask in Masks do begin
      Files := TDirectory.GetFiles(StartDir, Mask, SearchOption,
        function(const Path: string; const SearchRec: TSearchRec): Boolean
        begin
          // Фильтр по атрибутам
          Result := (SearchRec.Attr and FileAttrs) = SearchRec.Attr;
          // Проверка регистра (если требуется)
          if fsCaseSensitive in Options then
            Result := Result and (ExtractFileName(Path) = SearchRec.Name);
        end);
      FileList.AddStrings(Files);
    end;
    // количество найденных файлов
    Result := FileList.Count;
  except
    on E: Exception do
    begin
      FileList.Free;
      raise Exception.Create('Ошибка поиска файлов: ' + E.Message);
    end;
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
    // минимальный размер буфера (макс. длина шаблона + перекрытие)
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
      // поиск каждого шаблона в текущем буфере
      for i := 0 to High(Patterns) do
      begin
        // пропускаем если уже нашли максимальное количество результатов
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
            // добавляем позицию (с учетом ранее прочитанных данных)
            SetLength(Result[i].Positions, Length(Result[i].Positions) + 1);
            Result[i].Positions[High(Result[i].Positions)] := TotalRead + j;
            // конец поиска если достигли MaxResults
            if (MaxResults > 0) and (Result[i].Count >= MaxResults) then
              Break;
          end;
        end;
      end;
      Inc(TotalRead, BytesRead);
      // назад для перекрытия (чтобы не пропустить шаблоны на границе блоков)
      if TotalRead < FileSize then
        FileStream.Position := FileStream.Position - Length(Patterns[High(Patterns)]) + 1;
    end;
  finally
    FileStream.Free;
  end;
end;

end.
