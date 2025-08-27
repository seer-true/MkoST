library Arch7zip;

uses
{$IFDEF DEBUG}
  //FastMM4 in '..\FastMM4\FastMM4.pas'
{$ENDIF }
//System.SysUtils,
  System.Classes,
  System.StrUtils,
  Winapi.Windows,
  System.SysUtils, //DirectoryExists, FileExists, DeleteFile, строковых операций
//System.Classes,       // Пригодится, если будешь расширять (например, TFileStream)
  System.Variants, //Обязательно! Для работы с OleVariant и COM-объектами
//Winapi.Windows,       // Для GetFileAttributesEx, TWin32FileAttributeData, HANDLE и др.
//Winapi.ShlObj, //Опционально: для констант Shell, но не обязателен здесь
  Winapi.ActiveX, //Обязательно! Для CoInitialize, CoUninitialize, IEnumVariant
//System.Win.ComObj,
  Vcl.OleAuto,
  CommonMkos in 'CommonMkos.pas';
{$R *.res}

//тип callback-функции
type
  TLogCallback = procedure(Msg: PChar); stdcall;

(* const
  SevenZipPath = 'C:\Program Files\7-Zip\7z.exe'; //Стандартный путь, можно изменить *)

var
  ArchStopEvent: THandle = 0;

function InitArchiving: Boolean; stdcall;
begin
  ArchStopEvent := CreateEvent(//именованное событие для остановки
    nil, //атрибуты безопасности (по умолчанию)
    True, //ручной сброс (Manual Reset)
    False, //начальное состояние (не сигнализировано)
    'Global\7zArchiverStopEvent'//имя Global - для всех сессий)
    );
  Result := (ArchStopEvent <> 0);
end;

//Основная функция архивации
function ArchiveFolder(FolderPath, ArchiveName: PChar; Callback: TLogCallback): Boolean; stdcall;
var
  CmdLine: string;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  SecAttr: TSecurityAttributes;
  hReadPipe, hWritePipe: THandle;
  Buffer: array [0 .. 255] of AnsiChar;
  BytesRead: DWORD;
  Output: string;
  LastFile: string;
  ProcStop: Boolean;
begin
  Result := False;
  ProcStop := False;
  if not Assigned(Callback) then
    Exit;
  if not FileExists(SevenZipPath) then
  begin
    Callback(PChar('Ошибка: 7-Zip не найден по пути ' + SevenZipPath));
    Exit;
  end;

  if ArchStopEvent <> 0 then //сброс или создание события остановки
    ResetEvent(ArchStopEvent)
  else
  begin
    if not InitArchiving then begin
      Callback('Ошибка: Не удалось создать событие остановки');
      Exit;
    end;
  end;

  //канал для чтения вывода
  SecAttr.nLength := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := nil;
  SecAttr.bInheritHandle := True;
  if not CreatePipe(hReadPipe, hWritePipe, @SecAttr, 0) then
  begin
    Callback(PChar('Ошибка создания канала'));
    Exit;
  end;
  try
//-bsp1 для вывода информации о прогрессе
    CmdLine := Format('"%s" a -tzip -bb3 "%s" "%s\*"', [SevenZipPath, string(ArchiveName), string(FolderPath)]);
//CmdLine := Format('a -tzip -bb3 "%s" "%s\*"', [string(ArchiveName), string(FolderPath)]);
    FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
    StartupInfo.cb := SizeOf(TStartupInfo);
    StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartupInfo.wShowWindow := SW_HIDE;
    StartupInfo.hStdOutput := hWritePipe;
    StartupInfo.hStdError := hWritePipe;
    if CreateProcess(PChar(SevenZipPath), //имя исполняемого модуля
      PChar(CmdLine), //командная строка
      nil, //защита процесса
      nil, //защита потока
      True, //признак наследования дескриптора
      CREATE_NO_WINDOW, //флаги создания процесса
      nil, //блок новой среды окружения
      nil, //текущий каталог const
      StartupInfo, //вид главного окна
      ProcessInfo//информация о процессе
      ) then
    begin
      try
        CloseHandle(hWritePipe);
        while True do begin
          if WaitForSingleObject(ArchStopEvent, 100) = WAIT_OBJECT_0 then begin //проверяем событие остановки
            Callback('Получен сигнал остановки...');
            if not TerminateProcess(ProcessInfo.hProcess, 0) then
              Callback(PChar('Ошибка завершения процесса: ' + SysErrorMessage(GetLastError)))
            else begin
              ProcStop := True;
              Callback('Процесс принудительно завершён');
            end;
            Break;
          end;

          if not ReadFile(hReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) or (BytesRead = 0) then
          begin
            if WaitForSingleObject(ProcessInfo.hProcess, 100) <> WAIT_TIMEOUT then
              Break;
            Continue;
          end;

       //анализируем вывод для определения текущего файла
          Buffer[BytesRead] := #0;
          Output := string(AnsiString(Buffer));
          if Pos('+', Output) = 1 then //Строка начинается с "+ " - это информация о файле
          begin //как показала практика 7z просает свой вывод пачками и это не работает
            LastFile := Trim(Copy(Output, 3, MaxInt));
            Callback(PChar('Обработка файла: ' + LastFile));
          end
          else
            if Trim(Output) <> '' then
            begin
              Callback(PChar(Output));
            end;
        end;

        if FileExists(ArchiveName) then begin
          if ProcStop then
            Callback('Процесс прерван принудительно. Вероятно архив поврежден.');
          Callback(PChar(Format('Процесс завершен. Файл "%s" создан.', [string(ArchiveName)])));
        end
        else
          Callback(PChar(Format('Процесс завершен. Файл "%s" не создан.', [string(ArchiveName)])));

        Result := True;
      finally
        CloseHandle(ProcessInfo.hThread);
        CloseHandle(ProcessInfo.hProcess);
      end;
    end
    else
    begin
      Callback(PChar('Ошибка запуска 7-Zip: ' + SysErrorMessage(GetLastError)));
    end;
  finally
    CloseHandle(hReadPipe);
  end;
end;

procedure StopArchiving; stdcall;
begin
  if ArchStopEvent <> 0 then
    SetEvent(ArchStopEvent); //Сигнализируем о необходимости остановки
end;

//=========================================================================
function GetFileSize(const FileName: string): Int64;
var
  Info: TWin32FileAttributeData;
begin
  if GetFileAttributesEx(PChar(FileName), GetFileExInfoStandard, @Info) then
  begin
    Result := Int64(Info.nFileSizeHigh) shl 32 + Info.nFileSizeLow;
  end
  else
    Result := 0;
end;

function ArchiveFolderAPI(FolderPath, ArchiveName: PChar; Callback: TLogCallback): Boolean; stdcall;
var
  Shell: OleVariant;
  SourceFolder, DestZip: OleVariant;
  NameSpace: OleVariant;
  Items: OleVariant;
  Item: OleVariant;
  Enum: IEnumVariant;
  Fetched: Cardinal;
  FileName: string;

  ZipHeader: array [0 .. 21] of Byte;
  FileStream: TFileStream;
begin
  Result := False;

  //Проверка аргументов
  if not Assigned(Callback) then
  begin
    Exit;
  end;

  try
    //Инициализация COM для текущего потока (важно для потокобезопасности)
    CoInitialize(nil);

    try
      //Проверка существования папки
      if not DirectoryExists(FolderPath) then
      begin
        Callback(PChar('Ошибка: исходная папка не найдена — ' + string(FolderPath)));
        Exit;
      end;

      //Проверка пути архива
      if string(ArchiveName) = '' then
      begin
        Callback('Ошибка: имя архива не указано');
        Exit;
      end;

      //Удаляем старый ZIP, если существует
      if FileExists(ArchiveName) then
      begin
        if not DeleteFile(ArchiveName) then
        begin
          Callback(PChar('Ошибка: не удалось удалить существующий архив — ' + string(ArchiveName)));
          Exit;
        end;
      end;

      //Создаём пустой ZIP-файл
      ZeroMemory(@ZipHeader, SizeOf(ZipHeader));
  //Сигнатура EOCD: $06054b50 ('PK\005\006')
      ZipHeader[0] := $50;
      ZipHeader[1] := $4B;
      ZipHeader[2] := $05;
      ZipHeader[3] := $06;

      FileStream := TFileStream.Create(string(ArchiveName), fmCreate);
      try
        FileStream.WriteBuffer(ZipHeader, SizeOf(ZipHeader)); //Теперь OK: ZipHeader — переменная
      finally
        FileStream.Free;
      end;

      //Создание объекта Shell
      Shell := CreateOleObject('Shell.Application');

      //Получаем namespace для ZIP-файла (архив воспринимается как папка)
      DestZip := Shell.NameSpace(string(ArchiveName));
      SourceFolder := Shell.NameSpace(string(FolderPath));

      //Получаем список элементов (файлы и папки)
      Items := SourceFolder.Items;

      //Передаём в архив все элементы
      Enum := IEnumVariant(IUnknown(Items._NewEnum));
      if Enum <> nil then
      begin
        while Enum.Next(1, Item, Fetched) = S_OK do
        begin
          //Получаем имя файла/папки
          FileName := Item.Name;
          Callback(PChar('Добавление: ' + FileName));

          try
            //Копируем элемент в ZIP (по умолчанию — сжатие)
            DestZip.CopyHere(Item, 20); //20 = не показывать диалоги, не спрашивать подтверждение
          except
            on E: Exception do
            begin
              Callback(PChar('Ошибка при добавлении "' + FileName + '": ' + E.Message));
            end;
          end;

          Sleep(1000); //Делаем паузу, чтобы Shell успел обработать

        end;
      end;

//Проверка результата
      if FileExists(ArchiveName) and (GetFileSize(string(ArchiveName)) > 4) then
      begin
        Callback(PChar(Format('ZIP-архив успешно создан: %s', [string(ArchiveName)])));
        Result := True;
      end
      else
      begin
        Callback(PChar('Ошибка: ZIP-файл пуст или не создан'));
      end;

    finally
      CoUninitialize;
    end;

  except
    on E: Exception do
    begin
      if Assigned(Callback) then
        Callback(PChar('Исключение: ' + E.Message));
    end;
  end;
end;

//=========================================================================
exports
//InitArchiving,
  ArchiveFolder,
  StopArchiving, ArchiveFolderAPI;

begin
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True; //отслеживание утечек памяти
{$ENDIF}

end.
