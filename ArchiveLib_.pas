unit ArchiveLib;

interface

uses
  Windows, SysUtils, Classes;

type
  TLogCallback = procedure(Msg: PChar); stdcall;

var
  ArchStopEvent: THandle = 0;

function ArchiveFolder(FolderPath, ArchiveName: PChar; Callback: TLogCallback): Boolean; stdcall;
procedure StopArchiving; stdcall;
function InitArchiving: Boolean; stdcall;

implementation

const
  SevenZipPath = 'C:\Program Files\7-Zip\7z.exe'; // Укажите правильный путь

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

procedure StopArchiving; stdcall;
begin
  if ArchStopEvent <> 0 then
    SetEvent(ArchStopEvent); // Сигнализируем о необходимости остановки
end;

function ArchiveFolder(FolderPath, ArchiveName: PChar; Callback: TLogCallback): Boolean; stdcall;
var
  CmdLine: string;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  SecAttr: TSecurityAttributes;
  hReadPipe, hWritePipe: THandle;
  Buffer: array [0..255] of AnsiChar;
  BytesRead: DWORD;
  Output: string;
begin
  Result := False;
  if not Assigned(Callback) then Exit;

  if not InitArchiving then
  begin
    Callback('Ошибка: Не удалось создать событие остановки');
    Exit;
  end;

  // Создаем анонимный канал для чтения вывода 7z
  SecAttr.nLength := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := nil;
  SecAttr.bInheritHandle := True;
  if not CreatePipe(hReadPipe, hWritePipe, @SecAttr, 0) then
  begin
    Callback('Ошибка создания канала');
    Exit;
  end;

  try
    // Формируем командную строку для 7z
    CmdLine := Format('"%s" a -tzip -bb3 "%s" "%s\*"', 
      [SevenZipPath, string(ArchiveName), string(FolderPath)]);

    FillChar(StartupInfo, SizeOf(StartupInfo), 0);
    StartupInfo.cb := SizeOf(StartupInfo);
    StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartupInfo.wShowWindow := SW_HIDE;
    StartupInfo.hStdOutput := hWritePipe;
    StartupInfo.hStdError := hWritePipe;

    if CreateProcess(
      nil, 
      PChar(CmdLine), 
      nil, 
      nil, 
      True, 
      CREATE_NO_WINDOW, 
      nil, 
      nil, 
      StartupInfo, 
      ProcessInfo
    ) then
    begin
      try
        CloseHandle(hWritePipe);
        Callback(PChar('Архивация начата: ' + string(FolderPath)));

        // Основной цикл обработки вывода
        while True do
        begin
          // Проверяем событие остановки каждые 100 мс
          if WaitForSingleObject(ArchStopEvent, 100) = WAIT_OBJECT_0 then
          begin
            Callback('Получен сигнал остановки...');
            TerminateProcess(ProcessInfo.hProcess, 0);
            Break;
          end;

          // Читаем вывод 7z
          if not ReadFile(hReadPipe, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) then
          begin
            if WaitForSingleObject(ProcessInfo.hProcess, 0) <> WAIT_TIMEOUT then
              Break;
            Continue;
          end;

          // Обрабатываем вывод
          Buffer[BytesRead] := #0;
          Output := string(AnsiString(Buffer));
          if Trim(Output) <> '' then
            Callback(PChar(Output));
        end;

        Callback(PChar('Архивация завершена: ' + string(ArchiveName)));
        Result := True;
      finally
        CloseHandle(ProcessInfo.hThread);
        CloseHandle(ProcessInfo.hProcess);
      end;
    end
    else
      Callback(PChar('Ошибка запуска 7-Zip: ' + SysErrorMessage(GetLastError)));
  finally
    CloseHandle(hReadPipe);
    if ArchStopEvent <> 0 then
    begin
      CloseHandle(ArchStopEvent);
      ArchStopEvent := 0;
    end;
  end;
end;

exports
  ArchiveFolder,
  StopArchiving,
  InitArchiving;

end.