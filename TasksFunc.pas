unit TasksFunc;

interface

uses
  System.Classes, System.SyncObjs, System.SysUtils,
  Winapi.Windows, Winapi.Messages;

type
  TBaseThread  = class(TThread)
  private
    FTerminateEvent: TEvent;
    AddMess: string;
  protected
    procedure TerminatedSet; override;
  public
    TaskIdx: Integer;
  end;

  TThFindFiles = class(TBaseThread)
  protected
    procedure Execute; override;

    procedure AddResult();
  public
    StartFolder, Masks: String;

    constructor Create(ACreateSuspended: Boolean);
    destructor Destroy; override;

    procedure Stop;
  end;

implementation

uses
  MainForm, CommonMkos;

{ TFindFilesThread }

procedure TThFindFiles.AddResult;
begin
  frmMain.mResults.Lines.Add(AddMess);
  frmMain.mResults.Perform(EM_LINESCROLL, 0, frmMain.mResults.Lines.Count);
  frmMain.UpdateTasksList;
end;

constructor TThFindFiles.Create(ACreateSuspended: Boolean);
begin
  inherited Create(ACreateSuspended);
  FTerminateEvent := TEvent.Create(nil, True, False, '');
end;

destructor TThFindFiles.Destroy;
begin
  FTerminateEvent.Free;
  inherited;
end;

procedure TThFindFiles.Execute;
var
  SearchFunc: TSearchFilesFunc;
  FileList: WideString;
  MaskArray: TArray<string>;
  Mask: string;
  Res: Boolean;
  FileCount: Integer;
begin
  inherited;
  FTasks[TaskIdx].Status := tsRunning;
//ищем функцию из DLL
  SearchFunc := GetProcAddress(FSearchDLL, 'SearchFiles');
  if not Assigned(SearchFunc) then

    raise Exception.Create('Функция SearchFiles не найдена в DLL');

           //вызов
  FileList := '';
  MaskArray := string(Masks).Split([';'], TStringSplitOptions.ExcludeEmpty);

  for Mask in MaskArray do begin //для каждой маски
    if not Terminated then begin
      Res := SearchFunc(PChar(Mask), PChar(StartFolder), FileCount, FileList);
      if Res then begin
        AddMess := FileList;
        Synchronize(AddResult);
      end;
//      FTerminateEvent.WaitFor(5000);
    end
    else begin
      AddMess := 'Задача остановлена пользователем.';
      Synchronize(AddResult);
      break;
    end;
  end;
  Terminate;
end;

procedure TThFindFiles.Stop;
begin
  AddMess := 'Попытка остановить задачу..';
  Synchronize(AddResult);
  Terminate;
  FTerminateEvent.SetEvent;
end;


{ TBaseThread }
procedure TBaseThread.TerminatedSet;
begin
  inherited;
  FTerminateEvent.SetEvent;
end;

end.
