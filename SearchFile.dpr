//https://www.gunsmoker.ru/2009/01/blog-post.html
//https://www.gunsmoker.ru/2019/06/developing-DLL-API.html
library SearchFile;

uses
  {$IFDEF DEBUG}
//    FastMM4 in '..\FastMM4\FastMM4.pas'
  {$ENDIF }
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Types,
  CommonMkos in 'CommonMkos.pas';

{$R *.res}

///<summary>
///Функция для рекурсивного поиска файлов
///</summary>
function SearchFiles(Masks: PChar; StartDir: PChar; var FileCount: Integer; var FileArr: WideString (* PStringArray *) ): Boolean; stdcall;
var
  MaskArray: TArray<string>;
  Mask: string;
  FoundFiles: TStringDynArray;
begin
  Result := False;
  FileCount := 0;
  FileArr := '';

    //Разделяем маски по точкам с запятой
  MaskArray := string(Masks).Split([';'], TStringSplitOptions.ExcludeEmpty);

  try
    for Mask in MaskArray do begin //для каждой маски
      FoundFiles := TDirectory.GetFiles(string(StartDir), Mask.Trim, TSearchOption.soAllDirectories);
//результаты
      for var I := 0 to High(FoundFiles) do  // AV
        FileArr := FileArr + sLineBreak + FoundFiles[I];
      FileCount := FileCount + High(FoundFiles) + 1;
    end;

    Result := True;
  except
    on E: Exception do begin
      FileCount := -1;
    end;
  end;
end;

function SearchInFile(FileName: PChar; Patterns: PChar; out Results: PChar; out TotalMatches: Integer): Boolean; stdcall;
var
  PatternsArray: TArray<string>;
  FileStream: TFileStream;
  Buffer: TBytes;
  FileSize, BytesRead, PatternLength: Int64;
  i, j, k: Integer;
  Matches: array of TSearchResult;
  PatternBytesArray: array of TBytes;
  FilePos: Int64;
  ResultStr: string;
  TempStr: string;
begin
  Result := False;
  TotalMatches := 0;
  Results := nil;

  try
//Разделяем шаблоны по ';'
    PatternsArray := string(Patterns).Split([';'], TStringSplitOptions.ExcludeEmpty);

//Инициализация структур результатов и подготовка байтовых представлений шаблонов
    SetLength(Matches, Length(PatternsArray));
    SetLength(PatternBytesArray, Length(PatternsArray));

    for i := 0 to High(PatternsArray) do
    begin
      PatternsArray[i] := PatternsArray[i].Trim;
      Matches[i].Pattern := PatternsArray[i];
      PatternBytesArray[i] := TEncoding.UTF8.GetBytes(PatternsArray[i]);
      SetLength(Matches[i].Positions, 0);
    end;

//Открываем файл для чтения
    FileStream := TFileStream.Create(string(FileName), fmOpenRead or fmShareDenyWrite);
    try
      FileSize := FileStream.Size;
      SetLength(Buffer, 1024 * 1024); //Буфер 1MB
      FilePos := 0;
//Читаем файл блоками
      while FilePos < FileSize do
      begin
        BytesRead := FileStream.Read(Buffer[0], Length(Buffer));
        if BytesRead = 0 then
          Break;
//Поиск для каждого шаблона
        for i := 0 to High(PatternsArray) do
        begin
          PatternLength := Length(PatternBytesArray[i]);
          if PatternLength = 0 then
            Continue;
          if BytesRead < PatternLength then
            Continue;
          j := 0;
          while j <= BytesRead - PatternLength do begin
//Быстрая проверка первого байта
            if Buffer[j] = PatternBytesArray[i][0] then
            begin
              //Проверка остальных байтов
              k := 1;
              while (k < PatternLength) and (Buffer[j + k] = PatternBytesArray[i][k]) do
                Inc(k);
              if k = PatternLength then begin
//Найдено совпадение
                SetLength(Matches[i].Positions, Length(Matches[i].Positions) + 1);
                Matches[i].Positions[High(Matches[i].Positions)] := FilePos + j;
                Inc(TotalMatches);
//Пропускаем длину шаблона для неперекрывающихся совпадений
                Inc(j, PatternLength);
                Continue;
              end;
            end;
            Inc(j);
          end;
        end;
        Inc(FilePos, BytesRead);
      end;
    finally
      FileStream.Free;
    end;
//Формируем результаты в виде строки
    ResultStr := '';
    for i := 0 to High(Matches) do
    begin
//Добавляем информацию о шаблоне и количестве совпадений
      ResultStr := ResultStr + Matches[i].Pattern + ' : найдено ' + IntToStr(Length(Matches[i].Positions)) + ' вхождений' + #13#10;
//Добавляем позиции совпадений
      for j := 0 to High(Matches[i].Positions) do begin
        TempStr := ' Позиция: ' + IntToStr(Matches[i].Positions[j]) + #13#10;
        ResultStr := ResultStr + TempStr;
      end;
    end;

//копируем результат
    GetMem(Results, Length(ResultStr) + 10);
    StrMove(Results, PChar(ResultStr), Length(ResultStr) + 10);

    Result := True;
  except
    on E: Exception do
    begin
      if Results <> nil then
        StrDispose(Results);
      Results := StrAlloc(Length(E.Message) + 1);
      StrPCopy(Results, E.Message);
    end;
  end;
end;

function SearchPattern(FileName: PChar; Pattern: PChar; var Results: TArray<Int64>; var TotalMatches: Int64): Boolean; stdcall;
const
  BufferSize = 1024 * 1024; // 1MB буфер для чтения файла
var
  FS: TFileStream;
  PatternLen, BytesRead, I, J: Integer;
  Buffer, PrevBuffer: TBytes;
  PatternBytes: TBytes;
  MaxMatches: Int64;
  Found: Boolean;
  CurrentPos: Int64;
begin
  Result := False;
  try
    // Проверка входных параметров
    if (FileName = nil) or (Pattern = nil) then Exit;

    // Получаем длину шаблона
    PatternLen := Length(Pattern);
    if PatternLen = 0 then Exit;

    // Преобразуем шаблон в массив байт
    SetLength(PatternBytes, PatternLen * SizeOf(Char));
    Move(Pattern^, PatternBytes[0], Length(PatternBytes));

    // Инициализация
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Buffer, BufferSize + PatternLen - 1);
      SetLength(PrevBuffer, PatternLen - 1);
      MaxMatches := TotalMatches;
      TotalMatches := 0;
      SetLength(Results, 0); // Явно инициализируем массив результатов

      CurrentPos := 0;
      // Чтение файла блоками
      while True do
      begin
        // Читаем новый блок
        BytesRead := FS.Read(Buffer[0], BufferSize);

        // Если это не первый блок, добавляем конец предыдущего блока
        if BytesRead < BufferSize then
        begin
          // Последний блок - сокращаем буфер
          SetLength(Buffer, BytesRead + Length(PrevBuffer));
          Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
        end
        else if Length(PrevBuffer) > 0 then
        begin
          // Добавляем конец предыдущего блока к началу текущего
          Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
        end;

        // Поиск шаблона в текущем буфере
        for I := 0 to Length(Buffer) - PatternLen do
        begin
          Found := True;
          for J := 0 to PatternLen - 1 do
          begin
            if Buffer[I + J] <> PatternBytes[J] then
            begin
              Found := False;
              Break;
            end;
          end;

          if Found then
          begin
            // Найдено совпадение
            SetLength(Results, Length(Results) + 1);
            Results[High(Results)] := CurrentPos + I;
            Inc(TotalMatches);

            // Проверяем, не достигли ли максимального количества совпадений
            if (MaxMatches > 0) and (TotalMatches >= MaxMatches) then
            begin
              TotalMatches := TotalMatches - 1;
              Result := True;
              Exit;
            end;
          end;
        end;

        // Обновляем текущую позицию в файле
        CurrentPos := CurrentPos + BytesRead;

        // Сохраняем конец текущего блока для следующей итерации
        if BytesRead > 0 then
        begin
          SetLength(PrevBuffer, PatternLen - 1);
          if BytesRead >= PatternLen - 1 then
            Move(Buffer[BytesRead - (PatternLen - 1)], PrevBuffer[0], Length(PrevBuffer))
          else
          begin
            // Переносим остаток из предыдущего PrevBuffer
            if Length(PrevBuffer) > BytesRead then
              Move(PrevBuffer[BytesRead], PrevBuffer[0], Length(PrevBuffer) - BytesRead);
            Move(Buffer[0], PrevBuffer[Length(PrevBuffer) - BytesRead], BytesRead);
          end;
        end;

        // Проверяем конец файла
        if BytesRead < BufferSize then Break;
      end;

      Result := True;
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;

//Экспортируемые функции
exports
  SearchFiles,
  SearchInFile,
  SearchPattern;

begin
{$IFDEF DEBUG}
//  ReportMemoryLeaksOnShutdown := true; // отслеживание утечек памяти
{$ENDIF}

end.
