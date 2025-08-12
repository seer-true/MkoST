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

type
  TSearchResult = record
    Pattern: string;
    Positions: TArray<Int64>;
  end;

  PSearchResults = ^TSearchResults;
  TSearchResults = array of TSearchResult;

///<summary>
///Функция для рекурсивного поиска файлов
///</summary>
function SearchFiles(Masks: PChar; StartDir: PChar; out FileCount: Integer; var FileArr: WideString (* PStringArray *) ): Boolean; stdcall;
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
      for var I := 0 to High(FoundFiles) do
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

(* function SearchInFile(FileName: PChar; Patterns: PChar; var Results: PChar; var TotalMatches: Integer): Boolean; stdcall;
var
  PatternsArray: TArray<string>;
  FileStream: TFileStream;
  Buffer: TBytes;
  FileSize, BytesRead, PatternLength: Integer;
  i, j, k: Integer;
  Matches: array of TSearchResult;
  Output: TStringBuilder;
  PatternBytesArray: array of TBytes;
  FilePos: Int64;
begin
  Result := False;
  TotalMatches := 0;
  Results := nil;

  try
    //Разделяем шаблоны по '|'
    SafeSplit(Patterns, '|', PatternsArray);

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
          while j <= BytesRead - PatternLength do
          begin
            //Быстрая проверка первого байта
            if Buffer[j] = PatternBytesArray[i][0] then
            begin
              //Проверка остальных байтов
              k := 1;
              while (k < PatternLength) and (Buffer[j + k] = PatternBytesArray[i][k]) do
                Inc(k);

              if k = PatternLength then
              begin
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
    Output := TStringBuilder.Create;
    try
      for i := 0 to High(Matches) do
      begin
        Output.Append(Matches[i].Pattern).Append(': найдено ').Append(Length(Matches[i].Positions)).AppendLine(' вхождений'); //AV

        for j := 0 to High(Matches[i].Positions) do
          Output.Append(' Позиция: ').Append(Matches[i].Positions[j]).AppendLine;
      end;

      Results := StrAlloc(Output.Length + 1);
      StrPCopy(Results, Output.ToString);
    finally
      Output.Free;
    end;

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
end; *)
(* function SearchInFile(FileName: PChar; Patterns: PChar; var Results: PChar; var TotalMatches: Integer): Boolean; stdcall;
var
  PatternsArray: TArray<string>;
  FileStream: TFileStream;
  Buffer: array of Byte;
  BytesRead: Integer;
  i, j, k: Integer;
  Matches: array of TSearchResult;
  Found: Boolean;
  Output: TStringBuilder;
begin
  Result := False;
  TotalMatches := 0;
  Results := nil;

  try
    //Разделяем шаблоны по '|'

//PatternsArray := string(Patterns).Split(['|'], TStringSplitOptions.ExcludeEmpty);

    SafeSplit(Patterns, '|', PatternsArray);
    SetLength(Matches, Length(PatternsArray)); //AV

    //Инициализируем структуры результатов
    for i := 0 to High(PatternsArray) do begin
      Matches[i].Pattern := PatternsArray[i].Trim;
      SetLength(Matches[i].Positions, 0);
    end;

    //Открываем файл для чтения
    FileStream := TFileStream.Create(string(FileName), fmOpenRead or fmShareDenyNone);
    try
      SetLength(Buffer, 1024 * 1024); //Буфер 1MB

      //Читаем файл блоками
      while FileStream.Position < FileStream.Size do begin
        BytesRead := FileStream.Read(Buffer[0], Length(Buffer));

        //Поиск для каждого шаблона
        for i := 0 to High(PatternsArray) do begin
          for j := 0 to BytesRead - Length(PatternsArray[i]) do begin
            Found := True;
            for k := 1 to Length(PatternsArray[i]) do begin
              if Buffer[j + k - 1] <> Ord(PatternsArray[i][k]) then begin
                Found := False;
                Break;
              end;
//Sleep(100);
            end;

            if Found then begin
              try
                var
                  ll: Integer;
                ll := Length(Matches[i].Positions) + 1;
                SetLength(Matches[i].Positions, ll); //AV
              except
                on E: Exception do
                  ; //E.Message , E.HelpContext);
              end;

              Matches[i].Positions[High(Matches[i].Positions)] := FileStream.Position - BytesRead + j;
              Inc(TotalMatches);
            end;
          end;
        end;
      end;
    finally
      FileStream.Free;
    end;

    //Формируем результаты в виде строки
    Output := TStringBuilder.Create;
    try
      for i := 0 to High(Matches) do begin
        Output.AppendLine(Format('%s: найдено %d вхождений', [Matches[i].Pattern, Length(Matches[i].Positions)]));
        for j := 0 to High(Matches[i].Positions) do
          Output.AppendLine(Format('  Позиция: %d', [Matches[i].Positions[j]]));
      end;

      Results := StrAlloc(Output.Length + 1);
      StrPCopy(Results, Output.ToString);
    finally
      Output.Free;
    end;

    Result := True;
  except
    on E: Exception do begin
      Results := StrAlloc(Length(E.Message) + 1);
      StrPCopy(Results, E.Message);
    end;
  end;
end; *)

//Экспортируемые функции
exports
  SearchFiles,
  SearchInFile;

begin
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := true; // отслеживание утечек памяти
{$ENDIF}

end.
