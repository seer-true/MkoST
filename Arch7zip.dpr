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

//��� callback-�������
type
  TLogCallback = procedure(Msg: PChar); stdcall;

const
  SevenZipPath = 'C:\Program Files\7-Zip\7z.exe'; //����������� ����, ����� ��������

var
  ArchStopEvent: THandle = 0;

procedure StopArchiving; stdcall;
begin
  if ArchStopEvent <> 0 then
    SetEvent(ArchStopEvent); // ������������� � ������������� ���������
end;

function InitArchiving: Boolean; stdcall;
begin
  // ������� ����������� ������� ��� ���������
  ArchStopEvent := CreateEvent(
    nil,               // �������� ������������ (�� ���������)
    True,              // ������ ����� (Manual Reset)
    False,             // ��������� ��������� (�� ���������������)
    'Global\7zArchiverStopEvent' // ��� ������� (Global - ��� ���� ������)
  );
  Result := (ArchStopEvent <> 0);
end;


//�������� ������� ���������
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
    Callback(PChar('������: 7-Zip �� ������ �� ���� ' + SevenZipPath));
    Exit;
  end;

  //������� ����� ��� ������ ������
  SecAttr.nLength := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := nil;
  SecAttr.bInheritHandle := True;

  if not CreatePipe(hReadPipe, hWritePipe, @SecAttr, 0) then begin
    Callback(PChar('������ �������� ������'));
    Exit;
  end;

  try
    //bsp1 ��� ??? -bb3 ��� ������ ���������� � ���������
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
        Callback(PChar('������ �������������: ' + string(FolderPath)));
// ������� ���������
        while True do begin
          if WaitForSingleObject(ArchStopEvent, 100) = WAIT_OBJECT_0 then
          begin
            Callback('������� ������ ���������...');
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

//�������� ����
          if Pos('+ ', Output) = 1 then begin //������ ���������� � "+ " - ��� ���������� � �����???
            LastFile := Trim(Copy(Output, 3, MaxInt));
            Callback(PChar('��������� �����: ' + LastFile));
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
          Callback(PChar('������������� ��������'));
        end
        else begin
          Callback(PChar('������������� ���������: ' + string(ArchiveName)));
          Result := True;
        end;
      finally
        CloseHandle(ProcessInfo.hThread);
        CloseHandle(ProcessInfo.hProcess);
      end;
    end
    else
    begin
      Callback(PChar('������ ������� 7-Zip: ' + SysErrorMessage(GetLastError)));
    end;
  finally
    CloseHandle(hReadPipe);
  end;
end;

exports
  ArchiveFolder;

begin

end.
