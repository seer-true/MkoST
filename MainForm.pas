/// <remarks>
/// �������� ������ <see href="https://stackoverflow.com/questions/14033894/how-do-i-stop-a-thread-before-its-finished-running" /><br />
/// ������ <see href="https://www.kansoftware.ru/?tid=13951" />
/// </remarks>
unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.ExtDlgs,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.IOUtils,
  CommonMkos,
  TasksFunc;

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
    edtStartFolder: TEdit;
    btnSearchFiles: TButton;
    eMasks: TEdit;
    eSearchPatterns: TEdit;
    FileOpenDialog: TOpenTextFileDialog;
    btnArchive: TButton;
    pTasks: TPanel;
    lvTasks: TListView;
    b1: TButton;
    b2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnSelectFolderClick(Sender: TObject);
    procedure btnSearchFilesClick(Sender: TObject);
    procedure btnCancelTaskClick(Sender: TObject);
    procedure btnViewResultsClick(Sender: TObject);
    procedure btnSelectFileClick(Sender: TObject);
    procedure btnSearchInFileClick(Sender: TObject);
    procedure btnArchiveClick(Sender: TObject);
    procedure b1Click(Sender: TObject);
    procedure b2Click(Sender: TObject);
  private
    FNextTaskID: Integer;
    // FTasks: TArray<TTaskInfo>;
    // FCancelled: Boolean;

    ThFindFiles: TThFindFiles;

    procedure LoadSevenZipDLL;
    procedure UnloadSevenZipDLL;
    procedure LoadSearchDLL;
    procedure UnloadSearchDLL;

  public
    /// <summary>
    /// �������
    /// </summary>
    (* FSearchDLL: THandle;
      FSevenZipDLL: THandle; *)
    destructor Destroy; override;

    procedure StartArchiveTask;
    procedure UpdateTasksList;
    procedure AddResult(const Text: string);
  end;

var
  frmMain: TfrmMain;

implementation

uses
  System.Threading, System.SyncObjs;

{$R *.dfm}

procedure FileProgressCallback(Msg: PChar); stdcall;
begin
  TThread.Queue(nil,
    procedure
    begin
      frmMain.mResults.Lines.Add(string(Msg)); // ��� ������� � ����. ����
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
  FNextTaskID := 1;
  LoadSearchDLL;
  LoadSevenZipDLL;
  ListTasks := TStringList.Create;
  try
    ShowDllExports(FSearchDLL, ListTasks);
    for var i := Low(RealTasks) to High(RealTasks) do
    begin
      if ListTasks.IndexOf(RealTasks[i]) >= 0 then begin
        // ������
        TaskInfo.ID := FNextTaskID;
        Inc(FNextTaskID);
        TaskInfo.Name := RealTasks[i];
        TaskInfo.Status := tsWaiting;
        TaskInfo.StartTime := 0;
        TaskInfo.EndTime := 0;

        SetLength(FTasks, Length(FTasks) + 1);
        FTasks[High(FTasks)] := TaskInfo;
      end;
    end;
    UpdateTasksList;
  finally
    ListTasks.Free;
  end;
end;

destructor TfrmMain.Destroy;
begin
  UnloadSearchDLL;
  UnloadSevenZipDLL;
  inherited;
end;

procedure TfrmMain.LoadSearchDLL;
begin
  FSearchDLL := LoadLibrary('SearchFile.dll');
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
    edtStartFolder.Text := FileOpenDialog.FileName;
end;

procedure TfrmMain.btnSelectFolderClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    edtStartFolder.Text := OpenDialog.FileName;
end;

procedure TfrmMain.btnSearchFilesClick(Sender: TObject);
var
  TaskInfo: TTaskInfo;
  Thread: TThread;
begin
  if Trim(edtStartFolder.Text) = '' then
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
  AddResult(Format('�����: %s', [edtStartFolder.Text]));
  AddResult(Format('�����: %s', [eMasks.Text]));
  AddResult('---------------------');

  // ������
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := '����� ������';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;

  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;
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
  // exit;
  // ������
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      FileList: WideString;
      FileCount: Integer;
      SearchFunc: TSearchFilesFunc;
      TaskIdx: Integer;
      Res: Boolean;
      // Files: TStringList;
      MaskArray: TArray<string>;
      Mask: string;
      // i: Integer;
    begin
      TaskIdx := High(FTasks);
      FTasks[TaskIdx].Status := tsRunning;
      TThread.Synchronize(nil,
        procedure
        begin
          UpdateTasksList;
        end);

      try
        // ���� ������� �� DLL
        SearchFunc := GetProcAddress(FSearchDLL, 'SearchFiles');
        if not Assigned(SearchFunc) then
          raise Exception.Create('������� SearchFiles �� ������� � DLL');

        // �����
        FileList := '';
        MaskArray := string(eMasks.Text).Split([';'],
          TStringSplitOptions.ExcludeEmpty);

        for Mask in MaskArray do
        begin // ��� ������ �����
          Res := SearchFunc(PChar(Mask), PChar(edtStartFolder.Text), FileCount,
            FileList);

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
          UpdateTasksList;
        end);
    end);

  Thread.Start;
end;

procedure TfrmMain.btnSearchInFileClick(Sender: TObject);
var
  TaskInfo: TTaskInfo;
  Thread: TThread;
begin
  if Trim(edtStartFolder.Text) = '' then
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
  AddResult(Format('����: %s', [edtStartFolder.Text]));
  AddResult(Format('������������������: %s', [eSearchPatterns.Text]));
  AddResult('----------------------------');
  // ������� ������
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := '����� � �����';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;
  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;
  // ��������� � ��������� ������
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      FileName, Patterns, Results: PChar;
      TotalMatches: Integer;
      SearchFunc: TSearchInFileFunc;
      TaskIdx: Integer;
      Res: Boolean;
    begin
      TaskIdx := High(FTasks);
      FTasks[TaskIdx].Status := tsRunning;
      TThread.Synchronize(nil,
        procedure
        begin
          UpdateTasksList;
        end);
      try
        // �������� ������� �� DLL
        SearchFunc := GetProcAddress(FSearchDLL, 'SearchInFile');
        if not Assigned(SearchFunc) then
          raise Exception.Create('������� SearchInFile �� ������� � DLL');
        // �������������� ���������
        FileName := StrAlloc(Length(edtStartFolder.Text) + 1);
        Patterns := StrAlloc(Length(eSearchPatterns.Text) + 1);
        try
          StrPCopy(FileName, edtStartFolder.Text);
          StrPCopy(Patterns, eSearchPatterns.Text);
          // �������� ������� ������
          Res := SearchFunc(FileName, Patterns, Results, TotalMatches);
          // ������������ ���������
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
          UpdateTasksList;
        end);
    end);
  Thread.Start;
end;

procedure TfrmMain.UpdateTasksList;
var
  i: Integer;
  Item: TListItem;
  StatusText: string;
begin
  lvTasks.Items.BeginUpdate;
  try
    lvTasks.Items.Clear;

    for i := 0 to High(FTasks) do
    begin
      Item := lvTasks.Items.Add;
      Item.Caption := IntToStr(FTasks[i].ID);
      Item.SubItems.Add(FTasks[i].Name);

      case FTasks[i].Status of
        tsWaiting:
          StatusText := '��������';
        tsRunning:
          StatusText := '�����������';
        tsCompleted:
          StatusText := '���������';
        tsError:
          StatusText := '������';
        tsCancelled:
          StatusText := '��������';
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
    lvTasks.ItemIndex := lvTasks.Items.Count - 1;
    lvTasks.Items.EndUpdate;
  end;
end;

procedure TfrmMain.b1Click(Sender: TObject);
var
  TaskInfo: TTaskInfo;
begin
  // ������� �����
  ThFindFiles := TThFindFiles.Create(True);

  ThFindFiles.StartFolder := edtStartFolder.Text;
  ThFindFiles.Masks := eMasks.Text;
  ThFindFiles.FreeOnTerminate := True;

  // ������
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := '����� ������';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;

  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;

  TaskInfo.FThread := ThFindFiles;
  ThFindFiles.TaskIdx := High(FTasks);

  Application.ProcessMessages;

  // ��������� �����
  ThFindFiles.Resume;
end;

procedure TfrmMain.b2Click(Sender: TObject);
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
      // (FTasks[lvTasks.Selected.Index].FThread as TThFindFiles).Stop;
      ThFindFiles.Stop;
    UpdateTasksList;
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
  FSevenZipDLL := LoadLibrary('Arch7zip.dll');
  if FSevenZipDLL = 0 then
    raise Exception.Create('�� ������� ��������� Arch7zip.dll');
end;

procedure TfrmMain.UnloadSevenZipDLL;
begin
  if FSevenZipDLL <> 0 then
  begin
    FreeLibrary(FSevenZipDLL);
    FSevenZipDLL := 0;
  end;
end;

procedure TfrmMain.StartArchiveTask;
var
  TaskInfo: TTaskInfo;
  Thread: TThread;
  ArchiveName: string;
begin
  if Trim(edtStartFolder.Text) = '' then
  begin
    ShowMessage('������� ����� ��� �������������');
    Exit;
  end;

  ArchiveName := IncludeTrailingPathDelimiter(edtStartFolder.Text) + 'archive_'
    + FormatDateTime('yyyymmdd_hhnnss', Now) + '.zip';

  FCancelled := False;
  mResults.Clear;
  AddResult('=== ������ ������������� ===');
  AddResult('�����: ' + edtStartFolder.Text);
  AddResult('�����: ' + ArchiveName);
  AddResult('----------------------------');

  // ������� ������
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := '������������� 7-Zip';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;

  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;

  // ��������� � ��������� ������
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
          UpdateTasksList;
        end);
      try
        // �������� ������� �� DLL
        ArchiveFunc := GetProcAddress(FSevenZipDLL, 'ArchiveFolder');
        if not Assigned(ArchiveFunc) then
          raise Exception.Create('������� ArchiveFolder �� ������� � DLL');

        // �������������� ���������
        FolderPath := StrAlloc(Length(edtStartFolder.Text) + 1);
        ArchivePath := StrAlloc(Length(ArchiveName) + 1);
        try
          StrPCopy(FolderPath, edtStartFolder.Text);
          StrPCopy(ArchivePath, ArchiveName);

          // �������� ������� ��������� � callback'��
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
          UpdateTasksList;
        end);
    end);

  Thread.Start;
end;

end.
