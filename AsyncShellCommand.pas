unit AsyncShellCommand;

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, Winapi.ShellAPI, Vcl.StdCtrls;

type
  TCommandCompletedEvent = reference to procedure(const Msg: string; ExitCode: Cardinal);

procedure ArchiveWith7ZipAsync(const SourcePath: string; const ArchiveName: string; OnCompleted: TCommandCompletedEvent);

implementation

type
  TAsyncCommandRunner = class(TThread)
  private
    FCommand: string;
    FParameters: string;
    FOnCompleted: TCommandCompletedEvent;
    FExitCode: Cardinal;
    FOutputMsg: string;
    procedure DoCompleted;
  protected
    procedure Execute; override;
  public
    constructor Create(const Command, Parameters: string);
    property OnCompleted: TCommandCompletedEvent read FOnCompleted write FOnCompleted;
  end;

{ TAsyncCommandRunner }
constructor TAsyncCommandRunner.Create(const Command, Parameters: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FCommand := Command;
  FParameters := Parameters;
end;

procedure TAsyncCommandRunner.Execute;
var
  SEInfo: TShellExecuteInfo;
begin
  FillChar(SEInfo, SizeOf(SEInfo), 0);
  SEInfo.cbSize := SizeOf(TShellExecuteInfo);
  SEInfo.fMask := SEE_MASK_NOCLOSEPROCESS;
  SEInfo.lpFile := PChar(FCommand);
  SEInfo.lpParameters := PChar(FParameters);
  SEInfo.nShow := SW_HIDE;
  if ShellExecuteEx(@SEInfo) then
  begin
    WaitForSingleObject(SEInfo.hProcess, INFINITE);
    GetExitCodeProcess(SEInfo.hProcess, FExitCode);
    CloseHandle(SEInfo.hProcess);
    FOutputMsg := 'Архивация завершена. Код выхода: ' + IntToStr(FExitCode);
  end
  else
  begin
    FExitCode := GetLastError;
    FOutputMsg := 'Ошибка запуска 7-Zip. Код: ' + IntToStr(FExitCode);
  end;
  Synchronize(DoCompleted);
end;

procedure TAsyncCommandRunner.DoCompleted;
begin
  if Assigned(FOnCompleted) then
    FOnCompleted(FOutputMsg, FExitCode);
end;

procedure ArchiveWith7ZipAsync(const SourcePath: string; const ArchiveName: string; OnCompleted: TCommandCompletedEvent);
var
  Runner: TAsyncCommandRunner;
  Params: string;
begin
  Params := Format('a -t7z "%s" "%s" -mx9 -ssw -mmt=on', [ArchiveName, IncludeTrailingPathDelimiter(SourcePath) + '*']);
//  'a -tzip "D:\archive.zip" "C:\temp\*" -mx9 -ssw -mmt=on'
(*  a - add files
  -tzip - zip aрхив
  -mx9 - уровень сжатия
  -ssw - compress shared files
  -mmt - set number of CPU threads
*)
  Runner := TAsyncCommandRunner.Create('C:\Program Files\7-Zip\7z.exe', Params);
  Runner.OnCompleted := OnCompleted;
  Runner.Start;
end;

end.
