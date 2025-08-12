unit TasksFunc;

interface

uses
  System.Classes, System.SyncObjs, System.SysUtils,
  Winapi.Windows, Winapi.Messages;

type
  TBaseThread = class(TThread)
  private
    FTerminateEvent: TEvent;
    FAddMess: string;

    FAddrFunc: Pointer;
  protected
    procedure TerminatedSet; override;
    procedure AddResult();
    procedure UpdateTasksList();
  public
    TaskIdx: Integer;  // индекс задачи в FTasks

    constructor Create(ACreateSuspended: Boolean);
    destructor Destroy; override;
    procedure LoadFunc(hDll: THandle; NameFunc: string);
    procedure Stop;
  end;

  TThFindFiles = class(TBaseThread)  // поиск файлов
  protected
    procedure Execute; override;
  public
    StartFolder, Masks: String;
  end;

  TThFindInFile = class(TBaseThread) // поиск в файле
  protected
    procedure Execute; override;
  public
    TargetFile, Masks: String;
  end;

implementation

uses
  MainForm, CommonMkos;

{ TBaseThread }

constructor TBaseThread.Create(ACreateSuspended: Boolean);
begin
  inherited Create(ACreateSuspended);
  FTerminateEvent := TEvent.Create(nil, True, False, '');
end;

destructor TBaseThread.Destroy;
begin
  FTerminateEvent.Free;
  inherited;
end;

procedure TBaseThread.LoadFunc(hDll: THandle; NameFunc: string);
begin
//ищем функцию из DLL
  if hDll = 0 then
    raise Exception.Create('Для функции "' + NameFunc + '" Dll не загружена.');
  if NameFunc.IsEmpty then
    raise Exception.Create('Имя функции не определено (пусто)');

  FAddrFunc := GetProcAddress(hDLL, PChar(NameFunc));
  if not Assigned(FAddrFunc) then
    raise Exception.Create('Функция "' + NameFunc + '" не найдена в DLL');
end;

procedure TBaseThread.AddResult;
begin
  frmMain.mResults.Lines.Add(FAddMess);
  frmMain.mResults.Perform(EM_LINESCROLL, 0, frmMain.mResults.Lines.Count);
  frmMain.UpdateTasksList;
end;

procedure TBaseThread.UpdateTasksList();
begin
  Synchronize(nil,
    procedure
    begin
      frmMain.UpdateTasksList;
    end);
end;

procedure TBaseThread.Stop;
begin
  if not Terminated then begin
    FAddMess := 'Попытка остановить задачу..';
    Synchronize(AddResult);
    Terminate;
    FTerminateEvent.SetEvent;
  end;
end;

procedure TBaseThread.TerminatedSet;
begin
  inherited;
  FTerminateEvent.SetEvent;
end;

{ TThFindFiles }

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

  SearchFunc := FAddrFunc;

  FileList := '';
  MaskArray := string(Masks).Split([';'], TStringSplitOptions.ExcludeEmpty);

  for Mask in MaskArray do begin //для каждой маски
    if not Terminated then begin
      Res := SearchFunc(PChar(Mask), PChar(StartFolder), FileCount, FileList); //вызов
      if Res then begin
        FAddMess := Format('Найдено %d файлов %s:%s%s%s', [FileCount, Mask, sLineBreak, FileList, sLineBreak]);
        Synchronize(AddResult);
      end;
//      FTerminateEvent.WaitFor(5000);
    end
    else begin
      FAddMess := 'Задача остановлена пользователем.';
      Synchronize(AddResult);
      FTasks[TaskIdx].Status := tsCancelled;
      break;
    end;
  end;
  if not Terminated then
    FTasks[TaskIdx].Status := tsCompleted;

  Terminate;
  UpdateTasksList;
end;

{ TThFindInFile }

procedure TThFindInFile.Execute;
begin
  inherited;

end;

end.
