library Arch7zip;

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Dialogs,
  System.IOUtils,
  CommonMkos in 'CommonMkos.pas';

{$R *.res}

//тип callback-функции
type
  TLogCallback = procedure(Msg: PChar); stdcall;

const
  SevenZipPath = 'C:\Program Files\7-Zip\7z.exe'; //Стандартный путь, можно изменить

var
  ArchStopEvent: THandle = 0;

procedure StopArchiving; stdcall;
begin
  if ArchStopEvent <> 0 then
    SetEvent(ArchStopEvent); // Сигнализируем о необходимости остановки
end;

function InitArchiving: Boolean; stdcall;
begin
  // Создаем именованное событие для остановки
  ArchStopEvent := CreateEvent(
    nil,               // Атрибуты безопасности (по умолчанию)
    True,              // Ручной сброс (Manual Reset)
    False,             // Начальное состояние (не сигнализировано)
    'Global\7zArchiverStopEvent' // Имя события (Global - для всех сессий)
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
begin
  Result := False;
  if not Assigned(Callback) then
    Exit;

  if not FileExists(SevenZipPath) then begin
    Callback(PChar('Ошибка: 7-Zip не найден по пути ' + SevenZipPath));
    Exit;
  end;

  //Создаем канал для чтения вывода
  SecAttr.nLength := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := nil;
  SecAttr.bInheritHandle := True;

  if not CreatePipe(hReadPipe, hWritePipe, @SecAttr, 0) then begin
    Callback(PChar('Ошибка создания канала'));
    Exit;
  end;

  try
    //bsp1 или ??? -bb3 для вывода информации о прогрессе
    CmdLine := Format('"%s" a -tzip -bb3 "%s" "%s\*"', [SevenZipPath, string(ArchiveName), string(FolderPath)]);

    FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
//StartupInfo := Default(TStartupInfo);
    StartupInfo.cb := SizeOf(TStartupInfo);
    StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartupInfo.wShowWindow := SW_HIDE;
    StartupInfo.hStdOutput := hWritePipe;
    StartupInfo.hStdError := hWritePipe;

    if CreateProcess(PChar(SevenZipPath), PChar(CmdLine), nil, nil, True, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then begin
      try
        CloseHandle(hWritePipe);
        Callback(PChar('Начато архивирование: ' + string(FolderPath)));
// событие остановки
        while True do begin
          if WaitForSingleObject(ArchStopEvent, 100) = WAIT_OBJECT_0 then
          begin
            Callback('Получен сигнал остановки...');
            TerminateProcess(ProcessInfo.hProcess, 0);
            Break;
          end;

          if not ReadFile(hReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) or (BytesRead = 0) then begin
            if WaitForSingleObject(ProcessInfo.hProcess, 100) <> WAIT_TIMEOUT then
              Break;
            Continue;
          end;

          Buffer[BytesRead] := #0;
          Output := string(AnsiString(Buffer));

//текущеий файл
          if Pos('+ ', Output) = 1 then begin //Строка начинается с "+ " - это информация о файле???
            LastFile := Trim(Copy(Output, 3, MaxInt));
            Callback(PChar('Обработка файла: ' + LastFile));
          end
          else
            if Trim(Output) <> '' then begin
              Callback(PChar(Output));
            end;

//ArchStop := True;
          if ArchStop then
          begin
            TerminateProcess(ProcessInfo.hProcess, 0);
            Break;
          end

        end; //while

        if ArchStop then begin
          Callback(PChar('Архивирование прервано'));
        end
        else begin
          Callback(PChar('Архивирование завершено: ' + string(ArchiveName)));
          Result := True;
        end;
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

exports
  ArchiveFolder;

begin

end.
