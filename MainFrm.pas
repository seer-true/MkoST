unit MainFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TfrmMain = class(TForm)
    mRes: TMemo;
    Panel1: TPanel;
    btnDll: TButton;
    btnSearch: TButton;
    btnBinSearch: TButton;
    btnShellCommand: TButton;
    FileOpenDialog1: TFileOpenDialog;
    chkAbort: TCheckBox;
    pSett: TPanel;
    grpAtrFiles: TGroupBox;
    mMaskFiles: TMemo;
    chHiddenSys: TCheckBox;
    grpPatterns: TGroupBox;
    mPatterns: TMemo;
    procedure btnDllClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnBinSearchClick(Sender: TObject);
    procedure btnShellCommandClick(Sender: TObject);
    procedure chkAbortClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  DllExportsViewer, FileSearchUtils, AsyncShellCommand;

{$R *.dfm}

var
  AbortSearch: Boolean;

procedure TfrmMain.btnBinSearchClick(Sender: TObject);
var
  Results: TBinarySearchResults;
  i, j: Integer;
  Output: TStringList;
  Patterns: array of AnsiString;
begin
  Output := TStringList.Create;
  try
    chkAbort.Visible := True;
    FileOpenDialog1.Options := [];
    if FileOpenDialog1.Execute then begin

    SetLength(Patterns, mPatterns.Lines.Count);
    for i := 0 to mPatterns.Lines.Count - 1 do
      Patterns[i] := mPatterns.Lines[i];

      // поиск последовательностей в DLL
      Results := FindBinaryPatternsInFile(FileOpenDialog1.FileName (*'D:\DevelopXE\Declen\OUT\Win32\Debug\PadegUC.dll'*),
        Patterns(*['GetIFPadeg', 'GetIFPadegFS']*), 100000,
// макс. к-о результатов
        AbortSearch);
// вывод результатов
      for i := 0 to High(Results) do
      begin
        Output.Add(Format('Шаблон "%s" найден %d раз:', [Results[i].Pattern, Results[i].Count]));
        for j := 0 to High(Results[i].Positions) do
          Output.Add(Format('  Позиция: 0x%x', [Results[i].Positions[j]]));
      end;
      mRes.Lines.Text := Output.Text;
    end;
  finally
    Output.Free;
    chkAbort.Visible := False;
  end;
end;

procedure TfrmMain.btnDllClick(Sender: TObject);
var
  DllFileName: string;
begin
  FileOpenDialog1.Options := [];
  if FileOpenDialog1.Execute then begin
    DllFileName := FileOpenDialog1.FileName;
    mRes.Clear;
    mRes.Lines.Add('Поиск функций...');
    try
      ShowDllExports(DllFileName, TStringList(mRes.Lines));
      mRes.Lines.Add(Format('Готово. Найдено %d ф-ций', [mRes.Lines.Count]))
    except
      on E: Exception do
        mRes.Lines.Add('Ошибка: ' + E.Message);
    end;
  end;
end;

procedure TfrmMain.btnSearchClick(Sender: TObject);
var
  FileList: TStringList;
  FileCount: Integer;
  i: Integer;
  MaskFiles: array of string;
  AtrFiles: TFileSearchOptions;
begin
  FileOpenDialog1.Options := [fdoPickFolders (* , fdoPathMustExist, fdoForceFileSystem *) ];
  if FileOpenDialog1.Execute then begin

    try
// маски
      SetLength(MaskFiles, mMaskFiles.Lines.Count);
      for i := 0 to mMaskFiles.Lines.Count - 1 do
        MaskFiles[i] := mMaskFiles.Lines[i];
// атрибуты
      if chHiddenSys.Checked then
        AtrFiles := [fsRecursive, fsHiddenFiles, fsSystemFiles]
      else
        AtrFiles := [fsRecursive];

      FileCount := FindFilesByMask(MaskFiles, IncludeTrailingPathDelimiter(FileOpenDialog1.FileName), FileList, AtrFiles);

      for i := 0 to FileList.Count - 1 do
        mRes.Lines.Add(FileList[i]);
      mRes.Lines.Add(Format('Найдено файлов: %d', [FileCount]));

    finally
      FileList.Free;
    end;
  end;
end;

procedure TfrmMain.btnShellCommandClick(Sender: TObject);
begin
  mRes.Lines.Clear;
  mRes.Lines.Add('Запуск архивации...');

  ArchiveWith7ZipAsync('C:\temp', 'D:\archive.7z',
    procedure(const Msg: string; ExitCode: Cardinal)
    begin
// обновление mRes
      TThread.Queue(nil,
        procedure
        begin
          mRes.Lines.Add(Msg);
          if ExitCode = 0 then
            mRes.Lines.Add('Готово! Архив создан успешно.')
          else
            mRes.Lines.Add('Ошибка! Проверьте исходные данные.');
          mRes.Lines.Add('----------------------------------');
        end);
    end);
end;

procedure TfrmMain.chkAbortClick(Sender: TObject);
begin
  AbortSearch := chkAbort.Checked;
end;

end.
