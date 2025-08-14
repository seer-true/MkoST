///<remarks>
///�������� ������ <see href="https://stackoverflow.com/questions/14033894/how-do-i-stop-a-thread-before-its-finished-running" /><br />
///������ <see href="https://www.kansoftware.ru/?tid=13951" />
///</remarks>
unit MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.ExtDlgs,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.IOUtils,
  System.StrUtils,
  CommonMkos,
  TasksFunc, Vcl.Grids;

type
  TfrmMain = class(TForm)
    mResults: TMemo;
    OpenDialog: TFileOpenDialog;
    pLower: TPanel;
    btnCancelTask: TButton;
    btnViewResults: TButton;
    pSearchFiles: TPanel;
    lblMasks: TLabel;
    btnSelectFolder: TButton;
    eFile_s: TEdit;
    btnSearchFiles: TButton;
    eMasks: TEdit;
    eSearchPatterns: TEdit;
    FileOpenDialog: TOpenTextFileDialog;
    btnArchive: TButton;
    pTasks: TPanel;
    lvTasks: TListView;
    bStartTask: TButton;
    bStopTask: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnSelectFolderClick(Sender: TObject);
    procedure btnSearchFilesClick(Sender: TObject);
    procedure btnCancelTaskClick(Sender: TObject);
    procedure btnViewResultsClick(Sender: TObject);
    procedure btnSelectFileClick(Sender: TObject);
    procedure btnSearchInFileClick(Sender: TObject);
    procedure btnArchiveClick(Sender: TObject);
    procedure bStartTaskClick(Sender: TObject);
    procedure bStopTaskClick(Sender: TObject);
    procedure lvTasksDblClick(Sender: TObject);
  private
//    FNextTaskID: Integer;
    //FTasks: TArray<TTaskInfo>;
    //FCancelled: Boolean;
    ThFindFiles: TThFindFiles;
    ThSearchPattern: TThSearchPattern;
//    ThFindInFile: TThFindInFile;

    procedure StringReceived(const S: string);
    procedure StatusTask(const TaskIdx: Integer = -1);

    procedure LoadSevenZipDLL;
    procedure UnloadSevenZipDLL;
    procedure LoadSearchDLL;
    procedure UnloadSearchDLL;
  public
    (* FSearchDLL: THandle;
      F7ZipDLL: THandle; *)
    destructor Destroy; override;
    procedure StartArchiveTask;
    procedure AddResult(const Text: string);
  end;

var
  frmMain: TfrmMain;

implementation

uses
  System.Threading,
  System.SyncObjs;
{$R *.dfm}

procedure FileProgressCallback(Msg: PChar); stdcall;
begin
  TThread.Queue(nil,
    procedure
    begin
      frmMain.mResults.Lines.Add(string(Msg)); //��� ������� � ����. ����
    end);
end;

procedure ArchiveLogCallback(Msg: PChar); stdcall;
begin
  TThread.Queue(nil,
    procedure
    begin
      frmMain.AddResult(string(Msg));
    end);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  ListTasks: TStringList;
  TaskInfo: TTaskInfo;
begin
  LoadSearchDLL;
  LoadSevenZipDLL;
  ListTasks := TStringList.Create;
  try
  // ���������� DLL
    ShowDllExports(FSearchDLL, ListTasks);
    for var i := 0 to Length(RealTasks) - 1 do begin
      if ListTasks.IndexOf(RealTasks[i]) >= 0 then begin
        //������
        TaskInfo.ID := i;
        TaskInfo.Name := RealTasks[i];
        TaskInfo.Status := tsWaiting;
        TaskInfo.StartTime := 0;
        TaskInfo.EndTime := 0;
        SetLength(FTasks, Length(FTasks) + 1);
        FTasks[High(FTasks)] := TaskInfo;
      end;
    end;
    ListTasks.Clear;
// ������������ DLL
    ShowDllExports(F7ZipDLL, ListTasks);
    for var i := Low(RealTasks) to High(RealTasks) do begin
      if ListTasks.IndexOf(RealTasks[i]) >= 0 then begin
        //������
        TaskInfo.ID := i;
        TaskInfo.Name := RealTasks[i];
        TaskInfo.Status := tsWaiting;
        TaskInfo.StartTime := 0;
        TaskInfo.EndTime := 0;
        SetLength(FTasks, Length(FTasks) + 1);
        FTasks[High(FTasks)] := TaskInfo;
      end;
    end;
  StatusTask;
//      UpdateTasksList;
  finally
    ListTasks.Free;
  end;
end;

destructor TfrmMain.Destroy;
begin
  UnloadSearchDLL;
  UnloadSevenZipDLL;
end;

procedure TfrmMain.LoadSearchDLL;
begin
  FSearchDLL := SafeLoadLibrary('SearchFile.dll');
  if FSearchDLL = 0 then
    raise Exception.Create('�� ������� ��������� SearchFile.dll');
end;

procedure TfrmMain.UnloadSearchDLL;
begin
  if FSearchDLL <> 0 then
  begin
    FreeLibrary(FSearchDLL);
    FSearchDLL := 0;
  end;
end;

procedure TfrmMain.AddResult(const Text: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      mResults.Lines.Add(Text);
      mResults.Perform(EM_LINESCROLL, 0, mResults.Lines.Count);
    end);
end;

procedure TfrmMain.btnSelectFileClick(Sender: TObject);
begin
  if FileOpenDialog.Execute then
    eFile_s.Text := FileOpenDialog.FileName;
end;

procedure TfrmMain.btnSelectFolderClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    eFile_s.Text := OpenDialog.FileName;
end;

procedure TfrmMain.btnSearchFilesClick(Sender: TObject);
var
  TaskInfo: TTaskInfo;
  Thread: TThread;
begin
  if Trim(eFile_s.Text) = '' then
  begin
    ShowMessage('������� ��������� �����');
    Exit;
  end;
  if eMasks.Text = '' then
  begin
    ShowMessage('������� ����� ������');
    Exit;
  end;
  FCancelled := False;
  mResults.Clear;
  AddResult('=== ������ ������ ===');
  AddResult(Format('�����: %s', [eFile_s.Text]));
  AddResult(Format('�����: %s', [eMasks.Text]));
  AddResult('---------------------');
  //������

  TaskInfo.Name := '����� ������';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;
  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
     StatusTask;
//UpdateTasksList;
  ///
  (* TTask.Run(procedure
    // var
    begin
    TThread.Synchronize(nil, procedure
    begin;
    memResults.Lines.Add('�����');
    end);
    ///???
    TThread.Synchronize(nil, procedure
    begin;
    memResults.Lines.Add('��������');
    end);
    end); *)
  ///
  //exit;
  //������
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      FileList: WideString;
      FileCount: Integer;
      SearchFunc: TSearchFilesFunc;
      TaskIdx: Integer;
      Res: Boolean;
      //Files: TStringList;
      MaskArray: TArray<string>;
      Mask: string;
      //i: Integer;
    begin
      TaskIdx := High(FTasks);
      FTasks[TaskIdx].Status := tsRunning;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
//UpdateTasksList;
        end);
      try
        //���� ������� �� DLL
        SearchFunc := GetProcAddress(FSearchDLL, 'SearchFiles');
        if not Assigned(SearchFunc) then
          raise Exception.Create('������� SearchFiles �� ������� � DLL');
        //�����
        FileList := '';
        MaskArray := string(eMasks.Text).Split([';'], TStringSplitOptions.ExcludeEmpty);
        for Mask in MaskArray do
        begin //��� ������ �����
          Res := SearchFunc(PChar(Mask), PChar(eFile_s.Text), FileCount, FileList);
          if Res then
          begin
            AddResult(Format('������� ������: %d', [FileCount]));
            AddResult(FileList);
            if FCancelled then
            begin
              Thread.Terminate;
              AddResult('=== ����� ������� ������������� ===');
              FTasks[TaskIdx].Status := tsCancelled;
            end
            else
            begin
              AddResult('=== ����� �������� ===');
              FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else
          begin
            AddResult('������ ������: ' + string(FileList));
            FTasks[TaskIdx].Status := tsError;
          end;
        end;
      except
        on E: Exception do
        begin
          AddResult('������: ' + E.Message);
          FTasks[TaskIdx].Status := tsError;
        end;
      end;
      FTasks[TaskIdx].EndTime := Now;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
//UpdateTasksList;
        end);
    end);
  Thread.Start;
end;

procedure TfrmMain.btnSearchInFileClick(Sender: TObject);
var
  TaskInfo: TTaskInfo;
  Thread: TThread;
begin
  if Trim(eFile_s.Text) = '' then
  begin
    ShowMessage('������� ���� ��� ������');
    Exit;
  end;
  if Trim(eSearchPatterns.Text) = '' then
  begin
    ShowMessage('������� ������������������ ��� ������');
    Exit;
  end;
  FCancelled := False;
  mResults.Clear;
  AddResult('=== ������ ������ � ����� ===');
  AddResult(Format('����: %s', [eFile_s.Text]));
  AddResult(Format('������������������: %s', [eSearchPatterns.Text]));
  AddResult('----------------------------');
  //������� ������
  TaskInfo.Name := '����� � �����';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;
  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  StatusTask;
//UpdateTasksList;
  //��������� � ��������� ������
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      FileName, Patterns, Results: PChar;
      TotalMatches: Int64;
      SearchFunc: TSearchInFileFunc;
      TaskIdx: Integer;
      Res: Boolean;
    begin
      TaskIdx := High(FTasks);
      FTasks[TaskIdx].Status := tsRunning;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
//UpdateTasksList;
        end);
      try
        //�������� ������� �� DLL
        SearchFunc := GetProcAddress(FSearchDLL, 'SearchInFile');
        if not Assigned(SearchFunc) then
          raise Exception.Create('������� SearchInFile �� ������� � DLL');
        //�������������� ���������
        FileName := StrAlloc(Length(eFile_s.Text) + 1);
        Patterns := StrAlloc(Length(eSearchPatterns.Text) + 1);
        try
          StrPCopy(FileName, eFile_s.Text);
          StrPCopy(Patterns, eSearchPatterns.Text);
          //�������� ������� ������
          Res := SearchFunc(FileName, Patterns, Results, TotalMatches);
          //������������ ���������
          if Res then
          begin
            AddResult('=== ���������� ������ ===');
            AddResult(Format('����� ������� ���������: %d', [TotalMatches]));
            AddResult(string(Results));
            if FCancelled then
            begin
              AddResult('=== ����� ������� ������������� ===');
              FTasks[TaskIdx].Status := tsCancelled;
            end
            else
            begin
              AddResult('=== ����� �������� ===');
              FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else
          begin
            AddResult('������ ������: ' + string(Results));
            FTasks[TaskIdx].Status := tsError;
          end;
        finally
          StrDispose(FileName);
          StrDispose(Patterns);
          (* if Results <> nil then
            StrDispose(Results); *)
        end;
      except
        on E: Exception do
        begin
          AddResult('������: ' + E.Message);
          FTasks[TaskIdx].Status := tsError;
        end;
      end;
      FTasks[TaskIdx].EndTime := Now;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
//UpdateTasksList;
        end);
    end);
  Thread.Start;
end;

procedure TfrmMain.StatusTask(const TaskIdx: Integer = -1);
var
  i: Integer;
  Item: TListItem;
  StatusText: string;
begin
  lvTasks.ItemIndex := TaskIdx;

  lvTasks.Items.BeginUpdate;
  try
    lvTasks.Items.Clear;
    for i := 0 to High(FTasks) do begin
      Item := lvTasks.Items.Add;
      Item.Caption := IntToStr(FTasks[i].ID);

      Item.SubItems.Add(FTasks[i].Name);
      case FTasks[i].Status of
        tsWaiting:
          StatusText := '��������';
        tsRunning: begin
            StatusText := '�����������';
            if FTasks[i].StartTime = 0 then
              FTasks[i].StartTime := Now();
          end;
        tsCompleted: begin
            StatusText := '���������';
            if FTasks[i].EndTime = 0 then
              FTasks[i].EndTime := Now();
          end;
        tsError: begin
            StatusText := '������';
            if FTasks[i].EndTime = 0 then
              FTasks[i].EndTime := Now();
          end;
        tsCancelled: begin
            StatusText := '��������';
            if FTasks[i].EndTime = 0 then
              FTasks[i].EndTime := Now();
          end;
      end;

      Item.SubItems.Add(StatusText);
      if FTasks[i].StartTime > 0 then
        Item.SubItems.Add(DateTimeToStr(FTasks[i].StartTime))
      else
        Item.SubItems.Add('');
      if FTasks[i].EndTime > 0 then
        Item.SubItems.Add(DateTimeToStr(FTasks[i].EndTime))
      else
        Item.SubItems.Add('');
    end;
  finally
//    lvTasks.ItemIndex := lvTasks.Items.Count - 1;
    lvTasks.Items.EndUpdate;
  end;
end;

procedure TfrmMain.bStartTaskClick(Sender: TObject);
var
  TaskInfo: TTaskInfo;
begin
  TaskInfo := FTasks[lvTasks.ItemIndex];
//('SearchFiles', 'SearchPattern', 'SearchInFile', 'ArchiveFolder');
  case IndexStr(TaskInfo.Name, RealTasks) of
    0: begin //����� ������
        ThFindFiles := TThFindFiles.Create(True); //������� �����
        TaskInfo.FThread := ThFindFiles;

        eFile_s.Text := 'D:\Insures\insures5ase\bin\'; // ��� ������

        with ThFindFiles do begin
          OnStringReceived := StringReceived;

          StartFolder := eFile_s.Text;
          Masks := eMasks.Text;

          FreeOnTerminate := True;

          TaskIdx := lvTasks.ItemIndex;

          LoadFunc(FSearchDLL, TaskInfo.Name);

          Application.ProcessMessages;
          Start; //��������� �����
        end;
      end;
    1: begin //����� � �����
        ThSearchPattern := TThSearchPattern.Create(True); //������� �����
        TaskInfo.FThread := ThSearchPattern;

        eFile_s.Text := 'D:\Insures\insures5ase\bin\iRefBooks.rsm'; // ��� ������

        with ThSearchPattern do begin
          OnStringReceived := StringReceived;

          TargetFile := eFile_s.Text;
          Patterns := eSearchPatterns.Text;

          FreeOnTerminate := True;

          TaskIdx := lvTasks.ItemIndex;

          LoadFunc(FSearchDLL, TaskInfo.Name);

          Application.ProcessMessages;
          Start; //��������� �����
        end;
      end;
(*    2: begin
        TTask.Create(
          procedure()
          begin

          end
        );
      end;*)
  else
    ShowMessage('����������� ��������� �������: "' + TaskInfo.Name + '"');
  end;
end;

procedure TfrmMain.bStopTaskClick(Sender: TObject);
begin
  ThFindFiles.Stop;
end;

procedure TfrmMain.btnArchiveClick(Sender: TObject);
begin
  StartArchiveTask;
end;

procedure TfrmMain.btnCancelTaskClick(Sender: TObject);
begin
  if (lvTasks.Selected <> nil)
  (* and (FTasks[lvTasks.Selected.Index].Status = tsRunning) *) then
  begin
    FCancelled := True;
    FTasks[lvTasks.Selected.Index].Status := tsCancelled;
    FTasks[lvTasks.Selected.Index].EndTime := Now;
    if FTasks[lvTasks.Selected.Index].FThread <> nil then
      //(FTasks[lvTasks.Selected.Index].FThread as TThFindFiles).Stop;
      ThFindFiles.Stop;
    StatusTask;
//UpdateTasksList;
    AddResult('������� �������� ���������� ������...');
  end
  else
    ShowMessage('���������� ������� ������.');
end;

procedure TfrmMain.btnViewResultsClick(Sender: TObject);
begin
  mResults.Clear;
end;

procedure TfrmMain.LoadSevenZipDLL;
begin
  F7ZipDLL := SafeLoadLibrary('Arch7zip.dll');
  if F7ZipDLL = 0 then
    raise Exception.Create('�� ������� ��������� Arch7zip.dll');
end;

procedure TfrmMain.lvTasksDblClick(Sender: TObject);
var
  TaskInfo: TTaskInfo;
begin
  bStartTaskClick(Sender);
(*  TaskInfo := FTasks[lvTasks.ItemIndex];
  ShowMessage(Format('%d: %s (%d)', [lvTasks.ItemIndex, TaskInfo.Name, TaskInfo.ID]));*)
end;

procedure TfrmMain.UnloadSevenZipDLL;
begin
  if F7ZipDLL <> 0 then
  begin
    FreeLibrary(F7ZipDLL);
    F7ZipDLL := 0;
  end;
end;

procedure TfrmMain.StartArchiveTask;
var
  TaskInfo: TTaskInfo;
  Thread: TThread;
  ArchiveName: string;
begin
  if Trim(eFile_s.Text) = '' then begin
    ShowMessage('������� ����� ��� �������������');
    Exit;
  end;
  ArchiveName := IncludeTrailingPathDelimiter(eFile_s.Text) + 'archive_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.zip';
  FCancelled := False;
  mResults.Clear;
  AddResult('=== ������ ������������� ===');
  AddResult('�����: ' + eFile_s.Text);
  AddResult('�����: ' + ArchiveName);
  AddResult('----------------------------');

  //������� ������
  TaskInfo.Name := '������������� 7-Zip';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;
  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  StatusTask;
//UpdateTasksList;

  //��������� � ��������� ������
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      ArchiveFunc: TArchiveFolderFunc;
      TaskIdx: Integer;
      Res: Boolean;
      FolderPath, ArchivePath: PChar;
      FTerminateEvent: TEvent;
    begin
      FTerminateEvent := TEvent.Create(nil, True, False, 'FTerminateEvent');
      FTerminateEvent.WaitFor(100);
      TaskIdx := High(FTasks);
      FTasks[TaskIdx].Status := tsRunning;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
//UpdateTasksList;
        end);
      try
        //�������� ������� �� DLL
        ArchiveFunc := GetProcAddress(F7ZipDLL, 'ArchiveFolder');
        if not Assigned(ArchiveFunc) then
          raise Exception.Create('������� ArchiveFolder �� ������� � DLL');
        //�������������� ���������
        FolderPath := StrAlloc(Length(eFile_s.Text) + 1);
        ArchivePath := StrAlloc(Length(ArchiveName) + 1);
        try
          StrPCopy(FolderPath, eFile_s.Text);
          StrPCopy(ArchivePath, ArchiveName);
          //�������� ������� ��������� � callback'��
          Res := ArchiveFunc(FolderPath, ArchivePath, @ArchiveLogCallback);
          if Res then
          begin
            if FCancelled then
            begin
              TThread.Synchronize(nil,
                procedure
                begin
                  AddResult('=== ������������� �������� ������������� ===');
                end);
              FTasks[TaskIdx].Status := tsCancelled;
            end
            else
            begin
              TThread.Synchronize(nil,
                procedure
                begin
                  AddResult('=== ������������� ������� ��������� ===');
                end);
              FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else
          begin
            TThread.Synchronize(nil,
              procedure
              begin
                AddResult('=== ������ ������������� ===');
              end);
            FTasks[TaskIdx].Status := tsError;
          end;
        finally
          StrDispose(FolderPath);
          StrDispose(ArchivePath);
        end;
      except
        on E: Exception do
        begin
          TThread.Synchronize(nil,
            procedure
            begin
              AddResult('������: ' + E.Message);
            end);
          FTasks[TaskIdx].Status := tsError;
        end;
      end;
      FTasks[TaskIdx].EndTime := Now;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
//UpdateTasksList;
        end);
    end);
  Thread.Start;
end;

procedure TfrmMain.StringReceived(const S: string);
begin
  mResults.Lines.Add(S);
end;

end.
