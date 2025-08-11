/// <remarks>
/// Убийство потока <see href="https://stackoverflow.com/questions/14033894/how-do-i-stop-a-thread-before-its-finished-running" /><br />
/// Пример <see href="https://www.kansoftware.ru/?tid=13951" />
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
    /// ыфвмвам
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
      frmMain.mResults.Lines.Add(string(Msg)); // Или выводим в спец. поле
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
        // задача
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
    raise Exception.Create('Не удалось загрузить SearchFile.dll');
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
    ShowMessage('Укажите стартовую папку');
    Exit;
  end;

  if eMasks.Text = '' then
  begin
    ShowMessage('Укажите маски файлов');
    Exit;
  end;

  FCancelled := False;
  mResults.Clear;
  AddResult('=== Начало поиска ===');
  AddResult(Format('Папка: %s', [edtStartFolder.Text]));
  AddResult(Format('Маски: %s', [eMasks.Text]));
  AddResult('---------------------');

  // задача
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := 'Поиск файлов';
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
    memResults.Lines.Add('начат');
    end);
    ///???
    TThread.Synchronize(nil, procedure
    begin;
    memResults.Lines.Add('завершен');
    end);
    end); *)
  ///
  // exit;
  // запуск
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
        // ищем функцию из DLL
        SearchFunc := GetProcAddress(FSearchDLL, 'SearchFiles');
        if not Assigned(SearchFunc) then
          raise Exception.Create('Функция SearchFiles не найдена в DLL');

        // вызов
        FileList := '';
        MaskArray := string(eMasks.Text).Split([';'],
          TStringSplitOptions.ExcludeEmpty);

        for Mask in MaskArray do
        begin // для каждой маски
          Res := SearchFunc(PChar(Mask), PChar(edtStartFolder.Text), FileCount,
            FileList);

          if Res then
          begin
            AddResult(Format('Найдено файлов: %d', [FileCount]));
            AddResult(FileList);

            if FCancelled then
            begin
              Thread.Terminate;
              AddResult('=== Поиск прерван пользователем ===');
              FTasks[TaskIdx].Status := tsCancelled;

            end
            else
            begin
              AddResult('=== Поиск завершен ===');
              FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else
          begin
            AddResult('Ошибка поиска: ' + string(FileList));
            FTasks[TaskIdx].Status := tsError;
          end;
        end;

      except
        on E: Exception do
        begin
          AddResult('Ошибка: ' + E.Message);
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
    ShowMessage('Укажите файл для поиска');
    Exit;
  end;
  if Trim(eSearchPatterns.Text) = '' then
  begin
    ShowMessage('Укажите последовательности для поиска');
    Exit;
  end;
  FCancelled := False;
  mResults.Clear;
  AddResult('=== Начало поиска в файле ===');
  AddResult(Format('Файл: %s', [edtStartFolder.Text]));
  AddResult(Format('Последовательности: %s', [eSearchPatterns.Text]));
  AddResult('----------------------------');
  // Создаем задачу
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := 'Поиск в файле';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;
  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;
  // Запускаем в отдельном потоке
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
        // Получаем функцию из DLL
        SearchFunc := GetProcAddress(FSearchDLL, 'SearchInFile');
        if not Assigned(SearchFunc) then
          raise Exception.Create('Функция SearchInFile не найдена в DLL');
        // Подготавливаем параметры
        FileName := StrAlloc(Length(edtStartFolder.Text) + 1);
        Patterns := StrAlloc(Length(eSearchPatterns.Text) + 1);
        try
          StrPCopy(FileName, edtStartFolder.Text);
          StrPCopy(Patterns, eSearchPatterns.Text);
          // Вызываем функцию поиска
          Res := SearchFunc(FileName, Patterns, Results, TotalMatches);
          // Обрабатываем результат
          if Res then
          begin
            AddResult('=== Результаты поиска ===');
            AddResult(Format('Всего найдено вхождений: %d', [TotalMatches]));
            AddResult(string(Results));
            if FCancelled then
            begin
              AddResult('=== Поиск прерван пользователем ===');
              FTasks[TaskIdx].Status := tsCancelled;
            end
            else
            begin
              AddResult('=== Поиск завершен ===');
              FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else
          begin
            AddResult('Ошибка поиска: ' + string(Results));
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
          AddResult('Ошибка: ' + E.Message);
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
          StatusText := 'Ожидание';
        tsRunning:
          StatusText := 'Выполняется';
        tsCompleted:
          StatusText := 'Завершено';
        tsError:
          StatusText := 'Ошибка';
        tsCancelled:
          StatusText := 'Отменено';
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
  // создаем поток
  ThFindFiles := TThFindFiles.Create(True);

  ThFindFiles.StartFolder := edtStartFolder.Text;
  ThFindFiles.Masks := eMasks.Text;
  ThFindFiles.FreeOnTerminate := True;

  // задача
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := 'Поиск файлов';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;

  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;

  TaskInfo.FThread := ThFindFiles;
  ThFindFiles.TaskIdx := High(FTasks);

  Application.ProcessMessages;

  // запускаем поток
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
    AddResult('Попытка прервать выполнение задачи...');
  end
  else
    ShowMessage('Необходимо выбрать задачу.');
end;

procedure TfrmMain.btnViewResultsClick(Sender: TObject);
begin
  mResults.Clear;
end;

procedure TfrmMain.LoadSevenZipDLL;
begin
  FSevenZipDLL := LoadLibrary('Arch7zip.dll');
  if FSevenZipDLL = 0 then
    raise Exception.Create('Не удалось загрузить Arch7zip.dll');
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
    ShowMessage('Укажите папку для архивирования');
    Exit;
  end;

  ArchiveName := IncludeTrailingPathDelimiter(edtStartFolder.Text) + 'archive_'
    + FormatDateTime('yyyymmdd_hhnnss', Now) + '.zip';

  FCancelled := False;
  mResults.Clear;
  AddResult('=== Начало архивирования ===');
  AddResult('Папка: ' + edtStartFolder.Text);
  AddResult('Архив: ' + ArchiveName);
  AddResult('----------------------------');

  // Создаем задачу
  TaskInfo.ID := FNextTaskID;
  Inc(FNextTaskID);
  TaskInfo.Name := 'Архивирование 7-Zip';
  TaskInfo.Status := tsWaiting;
  TaskInfo.StartTime := Now;
  TaskInfo.EndTime := 0;

  SetLength(FTasks, Length(FTasks) + 1);
  FTasks[High(FTasks)] := TaskInfo;
  UpdateTasksList;

  // Запускаем в отдельном потоке
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
        // Получаем функцию из DLL
        ArchiveFunc := GetProcAddress(FSevenZipDLL, 'ArchiveFolder');
        if not Assigned(ArchiveFunc) then
          raise Exception.Create('Функция ArchiveFolder не найдена в DLL');

        // Подготавливаем параметры
        FolderPath := StrAlloc(Length(edtStartFolder.Text) + 1);
        ArchivePath := StrAlloc(Length(ArchiveName) + 1);
        try
          StrPCopy(FolderPath, edtStartFolder.Text);
          StrPCopy(ArchivePath, ArchiveName);

          // Вызываем функцию архивации с callback'ом
          Res := ArchiveFunc(FolderPath, ArchivePath, @ArchiveLogCallback);

          if Res then
          begin
            if FCancelled then
            begin
              TThread.Synchronize(nil,
                procedure
                begin
                  AddResult('=== Архивирование прервано пользователем ===');
                end);
              FTasks[TaskIdx].Status := tsCancelled;
            end
            else
            begin
              TThread.Synchronize(nil,
                procedure
                begin
                  AddResult('=== Архивирование успешно завершено ===');
                end);
              FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else
          begin
            TThread.Synchronize(nil,
              procedure
              begin
                AddResult('=== Ошибка архивирования ===');
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
              AddResult('Ошибка: ' + E.Message);
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
