unit TasksFunc;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  System.StrUtils,
  Winapi.Windows,
  Winapi.Messages;

type
  TStringEvent = procedure(const S: string) of object;
  TStatusTask = procedure(const TaskIdx: Integer = -1) of object;

  ///<summary>
  ///������� ����� ��� ������ �������
  ///</summary>
  TBaseThread = class(TThread)
  private
    FTerminateEvent: TEvent;
    FNameFunc: string;
    FAddMess: string;

    FAddrFunc: Pointer;
  protected
    procedure TerminatedSet; override;
    procedure AddResult();
//    procedure UpdateTasksList();

  public
    OnStringReceived: TStringEvent;
    OnStatusTask: TStatusTask;

    TaskIdx: Integer; //������ ������ � FTasks

    constructor Create(ACreateSuspended: Boolean);
    destructor Destroy; override;
    procedure LoadFunc(hDll: THandle; NameFunc: string);
    procedure Stop;
  end;

  TThFindFiles = class(TBaseThread)//����� ������
  protected
    procedure Execute; override;
  public
    StartFolder, Masks: String;
  end;

  TThSearchPattern = class(TBaseThread)//����� � ����� ����������
  protected
    procedure Execute; override;
  public
    TargetFile, Patterns: String;
  end;

  TThFindInFile = class(TBaseThread)//����� � �����
  protected
    procedure Execute; override;
  public
    TargetFile, Patterns: String;
  end;

implementation

uses
  CommonMkos;

{ TBaseThread }

constructor TBaseThread.Create(ACreateSuspended: Boolean);
begin
  inherited Create(ACreateSuspended);
  FTerminateEvent := TEvent.Create(nil, True, False, '');
  FNameFunc := '';
  FAddMess := '';
  FAddrFunc := nil;
end;

destructor TBaseThread.Destroy;
begin
  FTerminateEvent.Free;
  inherited;
end;

procedure TBaseThread.LoadFunc(hDll: THandle; NameFunc: string);
begin
  //���� ������� �� DLL
  if hDll = 0 then
    raise Exception.Create('��� ������� "' + NameFunc + '" Dll �� ���������.');
  if NameFunc.IsEmpty then
    raise Exception.Create('��� ������� �� ���������� (�����)');

  FAddrFunc := GetProcAddress(hDll, PChar(NameFunc));
  if Assigned(FAddrFunc) then
    FNameFunc := NameFunc
  else
    raise Exception.Create('������� "' + NameFunc + '" �� ������� � DLL');
end;

procedure TBaseThread.AddResult;
begin
  Synchronize(
    procedure
    var
      str: string;
    begin
      str := FAddMess;
//frmMain.mResults.Lines.Add(FAddMess);
//frmMain.mResults.Perform(EM_LINESCROLL, 0, frmMain.mResults.Lines.Count);
//frmMain.UpdateTasksList;
    end);
end;

procedure TBaseThread.Stop;
begin
  if not Terminated then
  begin
    FAddMess := '������� ���������� ������..';
    AddResult;
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
  MaskArray := Masks.Split([';'], TStringSplitOptions.ExcludeEmpty);

  for Mask in MaskArray do
  begin //��� ������ �����
    if not Terminated then
    begin
      Res := SearchFunc(PChar(Mask), PChar(StartFolder), FileCount, FileList);
      //�����
      if Res then
      begin

        FAddMess := Format('������� %d ������ %s:%s%s%s', [FileCount, Mask, sLineBreak, FileList, sLineBreak]);
        if Assigned(OnStringReceived) then
          Synchronize(
            procedure
            begin
              OnStringReceived(FAddMess);
            end);

//AddResult;
      end;
      //FTerminateEvent.WaitFor(5000);
    end
    else
    begin
      FTasks[TaskIdx].Status := tsCancelled;
      FAddMess := '������ ����������� �������������.';
      if Assigned(OnStringReceived) then
        Synchronize(
          procedure
          begin
            OnStringReceived(FAddMess);
          end);
//      AddResult;

      break;
    end;
  end;
  if not Terminated then
    FTasks[TaskIdx].Status := tsCompleted;

  Terminate;
  OnStatusTask(TaskIdx);
//  UpdateTasksList;
end;

{ TThSearchPattern }

procedure TThSearchPattern.Execute;
var
  SearchPattern: TSearchPattern;
  PatternsArray: TArray<string>;
  Res: Boolean;
  Results: TArray<Int64>;
  TotalMatches: Int64;
  Pattern: string;
begin
  inherited;
  FTasks[TaskIdx].Status := tsRunning;

  SearchPattern := FAddrFunc;
  try
    PatternsArray := Patterns.Split([';'], TStringSplitOptions.ExcludeEmpty);
    for Pattern in PatternsArray do begin
      TotalMatches := 10;
      if not Terminated then begin
        Res := SearchPattern(PChar(TargetFile), PChar(Pattern), Results, TotalMatches);
        if Res then begin
          FAddMess := Format('������� %s%d ��������� %s' + sLineBreak, [IfThen(TotalMatches < Length(Results), '����� ', ''), Length(Results),
            Pattern]);
          Synchronize(AddResult);
          FAddMess := '';
          for var j := 0 to Length(Results) - 1 do
            FAddMess := FAddMess + IntToStr(Results[j]) + sLineBreak;
          Synchronize(AddResult);
        end;
      end
      else
      begin
        FAddMess := '������ ����������� �������������.';
        Synchronize(AddResult);
        FTasks[TaskIdx].Status := tsCancelled;
        break;
      end;

    end;
  finally
    SetLength(Results, 0);
  end;

  if not Terminated then
    FTasks[TaskIdx].Status := tsCompleted;

  Terminate;
  OnStatusTask(TaskIdx);
//  UpdateTasksList;
end;

{ TThFindInFile }

procedure TThFindInFile.Execute;
var
  SearchFunc: TSearchInFileFunc;
  PatternsArray: TArray<string>;
  Pattern: String;
  Res: Boolean;
  Results: PChar;
  TotalMatches: Int64;
begin
  inherited;
  FTasks[TaskIdx].Status := tsRunning;

  SearchFunc := FAddrFunc;
  PatternsArray := Patterns.Split([';'], TStringSplitOptions.ExcludeEmpty);
  for Pattern in PatternsArray do
  begin
    if not Terminated then
    begin
      Res := SearchFunc(PChar(TargetFile), PChar(Pattern), Results, TotalMatches); //�����
      if Res then begin
        FAddMess := '111111'; (* Format('������� %d ��������� %s:%s%s%s',
          [TotalMatches, Mask, sLineBreak, FileList, sLineBreak]); *)
        Synchronize(AddResult);
      end;
    end;
  end;
end;

end.
