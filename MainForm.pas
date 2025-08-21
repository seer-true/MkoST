/// <remarks>
/// Убийство потока <see href="https://stackoverflow.com/questions/14033894/how-do-i-stop-a-thread-before-its-finished-running" /><br />
/// Пример <see href="https://www.kansoftware.ru/?tid=13951" />
/// </remarks>
unit MainForm;

interface

uses Winapi.Windows, Winapi.Messages, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.ExtDlgs,
  System.SysUtils, System.Classes, System.Types, System.IOUtils,
  System.StrUtils, System.Variants, CommonMkos, TasksFunc, Data.DB, Vcl.Grids,
  Vcl.DBGrids, Datasnap.DBClient, Vcl.Buttons;

type
  TfrmMain = class(TForm)
    mResults: TMemo;
    OpenDialog: TFileOpenDialog;
    pLower: TPanel;
    btnViewResults: TButton;
    pSearchFiles: TPanel;
    lblMasks: TLabel;
    eFolder: TEdit;
    eMasks: TEdit;
    eSearchPatterns: TEdit;
    FileOpenDialog: TOpenTextFileDialog;
    pTasks: TPanel;
    bStartTask: TButton;
    bStopTask: TButton;
    cdsTasks: TClientDataSet;
    cdsTasksID: TIntegerField;
    cdsTasksTask: TStringField;
    cdsTasksStatus: TSmallintField;
    cdsTasksTimeStart: TDateTimeField;
    cdsTasksTimeEnd: TDateTimeField;
    dsTask: TDataSource;
    dbgTasks: TDBGrid;
    cdsTasksSStatus: TStringField;
    cdsTasksFThread: TLargeintField;
    cbMatches: TComboBox;
    bSelectFolder: TSpeedButton;
    btnArchive: TButton;
    eFile: TEdit;
    bSelectFile: TSpeedButton;

    procedure FormCreate(Sender: TObject);
    procedure btnViewResultsClick(Sender: TObject);
    procedure btnArchiveClick(Sender: TObject);
    procedure bStartTaskClick(Sender: TObject);
    procedure bStopTaskClick(Sender: TObject);
    procedure lvTasksDblClick(Sender: TObject);
    procedure cdsTasksCalcFields(DataSet: TDataSet);
    procedure cbMatchesKeyPress(Sender: TObject; var Key: Char);
    procedure bSelectFolderClick(Sender: TObject);
    procedure bSelectFileClick(Sender: TObject);
  private
    FPosPatt: TArray<Int64>;
    ThFindFiles: TThFindFiles;
    // ThFindInFile: TThFindInFile;
    ThSearchPattern: TThSearchPattern;
    ThSearchPattern2: TThSearchPattern2;

    procedure StringReceived(const S: string);
    procedure StatusTask(const TaskIdx: Integer = -1; const Status: Integer = 0);
    procedure GetPosition(const PosPatt: Int64);

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

uses System.Threading, System.SyncObjs;

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
  // TaskInfo: TTaskInfo;
begin
  LoadSearchDLL;
  LoadSevenZipDLL;
  ListTasks := TStringList.Create;
  cdsTasks.CreateDataSet;
  cdsTasks.Open;
  try
    // поисковая DLL
    ShowDllExports(FSearchDLL, ListTasks);
    for var i := 0 to Length(RealTasks) - 1 do begin
      if ListTasks.IndexOf(RealTasks[i]) >= 0 then begin
        cdsTasks.InsertRecord([i, RealTasks[i], 0, null, null]);
      end;
    end;
    ListTasks.Clear;
    // архивирующая DLL
    ShowDllExports(F7ZipDLL, ListTasks);
    for var i := Low(RealTasks) to High(RealTasks) do begin
      if ListTasks.IndexOf(RealTasks[i]) >= 0 then begin
        cdsTasks.InsertRecord([i, RealTasks[i], 0, null, null]);
      end;
    end;
    StatusTask(-1);
  finally
    ListTasks.Free;
  end;
  cdsTasks.First;
  SetLength(FPosPatt, 0);
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
    raise Exception.Create('Не удалось загрузить SearchFile.dll');
end;

procedure TfrmMain.UnloadSearchDLL;
begin
  if FSearchDLL <> 0 then begin
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

procedure TfrmMain.StatusTask(const TaskIdx: Integer = -1; const Status: Integer = 0);
begin
  try
    if cdsTasks.Locate('ID', TaskIdx, []) then begin
      cdsTasks.Edit;
      cdsTasksStatus.Value := Status;
      cdsTasks.Post;
    end
  except
    on E: Exception do begin;
    end;
  end;
end;

procedure TfrmMain.GetPosition(const PosPatt: Int64);
begin
  SetLength(FPosPatt, Length(FPosPatt) + 1);
  FPosPatt[Length(FPosPatt)] := PosPatt;
end;

procedure TfrmMain.bSelectFileClick(Sender: TObject);
begin
  if FileOpenDialog.Execute then
    eFile.Text := FileOpenDialog.FileName;
end;

procedure TfrmMain.bSelectFolderClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    eFolder.Text := OpenDialog.FileName;
end;

procedure TfrmMain.bStartTaskClick(Sender: TObject);
(* var
  TaskInfo: TTaskInfo;
  P: Pointer; *)
begin
  case IndexStr(cdsTasksTask.AsString, RealTasks) of
    0: begin // поиск файлов
        ThFindFiles := TThFindFiles.Create(True); // создаем поток

        cdsTasks.Edit;
        ThFindFiles.TaskID := cdsTasksID.AsInteger;
        cdsTasksFThread.AsLargeInt := Integer(ThFindFiles);
        cdsTasks.Post;

        ThFindFiles.TaskID := cdsTasksID.AsInteger;

//        eFolder.Text := 'D:\Insures\insures5ase\bin\'; // для тестов
//        eFile_s.Text := 'C:\DataBase\';

        with ThFindFiles do begin
          OnStringReceived := StringReceived;
          OnStatusTask := StatusTask;

          StartFolder := eFolder.Text;
          Masks := eMasks.Text;

          FreeOnTerminate := True;

          LoadFunc(FSearchDLL, cdsTasksTask.AsString);

          Start; // запускаем поток
        end;
      end;
    1: begin // поиск в файле
        ThSearchPattern := TThSearchPattern.Create(True); // создаем поток

        cdsTasks.Edit;
        ThSearchPattern.TaskID := cdsTasksID.AsInteger;
        cdsTasksFThread.AsLargeInt := Integer(ThSearchPattern);
        cdsTasks.Post;

  //      eFile.Text := 'D:\tmp\35645\load_wds_contract.sql';//'D:\Insures\insures5ase\bin\iRefBooks.rsm'; // для тестов\
//        eFile_s.Text := 'C:\DevelopXE\Declension.7z';

        with ThSearchPattern do begin
          OnStringReceived := StringReceived;
          OnStatusTask := StatusTask;

          SetLength(FPosPatt, 0);
          TargetFile := eFile.Text;
          Patterns := eSearchPatterns.Text;
          Matches := StrToUInt(cbMatches.Text);

          FreeOnTerminate := True;

          LoadFunc(FSearchDLL, cdsTasksTask.AsString);

          Start; // запускаем поток
        end;
      end;
    2: begin // поиск в файле2
        ThSearchPattern := TThSearchPattern.Create(True); // создаем поток

        cdsTasks.Edit;
        ThSearchPattern.TaskID := cdsTasksID.AsInteger;
        cdsTasksFThread.AsLargeInt := Integer(ThSearchPattern);
        cdsTasks.Post;

        eFile.Text := 'D:\Insures\insures5ase\bin\iRefBooks.rsm'; //для тестов\
//        eFile_s.Text := 'C:\DevelopXE\Declension.7z';

        with ThSearchPattern do begin
          OnStringReceived := StringReceived;
          OnStatusTask := StatusTask;

          SetLength(FPosPatt, 0);
          // OnGetPosition := GetPosition;

          TargetFile := eFile.Text;
          Patterns := eSearchPatterns.Text;

          FreeOnTerminate := True;

          LoadFunc(FSearchDLL, cdsTasksTask.AsString);

          // Application.ProcessMessages;
          Start; // запускаем поток
        end;
      end;

    3: begin
        StartArchiveTask;
        (* TTask.Create(
          procedure()
          begin

          end); *)
      end
  else
    ShowMessage('Отсутствует обработка функции: "' + cdsTasksTask.AsString + '"');
  end
end;

procedure TfrmMain.bStopTaskClick(Sender: TObject);
begin
  case IndexStr(cdsTasksTask.AsString, RealTasks) of
    0:
      if Assigned(ThFindFiles) then
        ThFindFiles.Stop;
    1:
      if Assigned(ThSearchPattern) then
        ThSearchPattern.Stop;
  end;
end;

procedure TfrmMain.btnArchiveClick(Sender: TObject);
begin
  StartArchiveTask;
end;

procedure TfrmMain.btnViewResultsClick(Sender: TObject);
begin
  mResults.Clear;
end;

procedure TfrmMain.cbMatchesKeyPress(Sender: TObject; var Key: Char);
begin
  if not(Key in ['1' .. '9', #8]) then
    Key := #0;
end;

procedure TfrmMain.cdsTasksCalcFields(DataSet: TDataSet);
begin
  case cdsTasksStatus.AsInteger of
    0: cdsTasksSStatus.Value := 'Ожидание';
    1: begin
        cdsTasksSStatus.Value := 'Выполняется';
        if cdsTasksTimeStart.Value = null then
          cdsTasksTimeStart.Value := now();
      end;
    2: begin
        cdsTasksSStatus.Value := 'Завершено';
        if cdsTasksTimeEnd.Value = null then
          cdsTasksTimeEnd.Value := now();
      end;
    3: begin
        cdsTasksSStatus.Value := 'Ошибка';
      end;
    4: begin
        cdsTasksSStatus.Value := 'Отменено';
      end;
  end;
end;

procedure TfrmMain.LoadSevenZipDLL;
begin
  F7ZipDLL := SafeLoadLibrary('Arch7zip.dll');
  if F7ZipDLL = 0 then
    raise Exception.Create('Не удалось загрузить Arch7zip.dll');
end;

procedure TfrmMain.lvTasksDblClick(Sender: TObject);
begin
  bStartTaskClick(Sender);
end;

procedure TfrmMain.UnloadSevenZipDLL;
begin
  if F7ZipDLL <> 0 then begin
    FreeLibrary(F7ZipDLL);
    F7ZipDLL := 0;
  end;
end;

procedure TfrmMain.StartArchiveTask;
var
  // TaskInfo: TTaskInfo;
  Thread: TThread;
  ArchiveName: string;
begin
  if Trim(eFolder.Text) = '' then begin
    ShowMessage('Укажите папку для архивирования');
    Exit;
  end;
  ArchiveName := IncludeTrailingPathDelimiter(eFolder.Text) + 'archive_' + FormatDateTime('yyyymmdd_hhnnss', now) + '.zip';
  FCancelled := False;
  mResults.Clear;
  AddResult('=== Начало архивирования ===');
  AddResult('Папка: ' + eFolder.Text);
  AddResult('Архив: ' + ArchiveName);
  AddResult('----------------------------');

  StatusTask;
  // Запускаем в отдельном потоке
  Thread := TThread.CreateAnonymousThread(
    procedure
    var
      ArchiveFunc: TArchiveFolderFunc;
      Res: Boolean;
      FolderPath, ArchivePath: PChar;
      FTerminateEvent: TEvent;
    begin
      FTerminateEvent := TEvent.Create(nil, True, False, 'FTerminateEvent');
      FTerminateEvent.WaitFor(100);

      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
        end);
      try
        // Получаем функцию из DLL
        ArchiveFunc := GetProcAddress(F7ZipDLL, 'ArchiveFolder');
        if not Assigned(ArchiveFunc) then
          raise Exception.Create('Функция ArchiveFolder не найдена в DLL');
        // Подготавливаем параметры
        FolderPath := StrAlloc(Length(eFolder.Text) + 1);
        ArchivePath := StrAlloc(Length(ArchiveName) + 1);
        try
          StrPCopy(FolderPath, eFolder.Text);
          StrPCopy(ArchivePath, ArchiveName);
          // Вызываем функцию архивации с callback'ом
          Res := ArchiveFunc(FolderPath, ArchivePath, @ArchiveLogCallback);
          if Res then begin
            if FCancelled then begin
              TThread.Synchronize(nil,
                procedure
                begin
                  AddResult('=== Архивирование прервано пользователем ===');
                end);
              // FTasks[TaskIdx].Status := tsCancelled;
            end
            else begin
              TThread.Synchronize(nil,
                procedure
                begin
                  AddResult('=== Архивирование успешно завершено ===');
                end);
              // FTasks[TaskIdx].Status := tsCompleted;
            end;
          end
          else begin
            TThread.Synchronize(nil,
              procedure
              begin
                AddResult('=== Ошибка архивирования ===');
              end);
            // FTasks[TaskIdx].Status := tsError;
          end;
        finally
          StrDispose(FolderPath);
          StrDispose(ArchivePath);
        end;
      except
        on E: Exception do begin
          TThread.Synchronize(nil,
            procedure
            begin
              AddResult('Ошибка: ' + E.Message);
            end);
          // FTasks[TaskIdx].Status := tsError;
        end;
      end;
      // FTasks[TaskIdx].EndTime := Now;
      TThread.Synchronize(nil,
        procedure
        begin
          StatusTask;
          // UpdateTasksList;
        end);
    end);
  Thread.Start;
end;

procedure TfrmMain.StringReceived(const S: string);
begin
  mResults.Lines.Add(S);
end;

end.
