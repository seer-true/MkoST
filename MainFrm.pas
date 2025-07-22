unit MainFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TfrmMain = class(TForm)
    OpenDialog1: TOpenDialog;
    Memo1: TMemo;
    Panel1: TPanel;
    btnDll: TButton;
    btnSearch: TButton;
    btnBinSearch: TButton;
    btnShellCommand: TButton;
    procedure btnDllClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnBinSearchClick(Sender: TObject);
    procedure btnShellCommandClick(Sender: TObject);
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

procedure TfrmMain.btnBinSearchClick(Sender: TObject);
var
  Results: TBinarySearchResults;
  i, j: Integer;
  Output: TStringList;
begin
  Output := TStringList.Create;
  try
// поиск последовательностей в DLL
    Results := FindBinaryPatternsInFile('D:\DevelopXE\Declen\OUT\Win32\Debug\PadegUC.dll', ['GetIFPadeg', 'GetIFPadegFS'], 100
      // макс. к-о результатов
      );
// вывод результатов
    for i := 0 to High(Results) do
    begin
      Output.Add(Format('Шаблон "%s" найден %d раз:', [Results[i].Pattern, Results[i].Count]));
      for j := 0 to High(Results[i].Positions) do
        Output.Add(Format('  Позиция: 0x%x', [Results[i].Positions[j]]));
    end;
    Memo1.Lines.Text := Output.Text;
  finally
    Output.Free;
  end;
end;

procedure TfrmMain.btnDllClick(Sender: TObject);
var
  DllFileName: string;
begin
  if OpenDialog1.Execute then
  begin
    DllFileName := OpenDialog1.FileName;
    Memo1.Clear;
    Memo1.Lines.Add('Поиск функций...');
    try
      ShowDllExports(DllFileName, TStringList(Memo1.Lines));
      Memo1.Lines.Add(Format('Готово. Найдено %d экспортов', [Memo1.Lines.Count]))
    except
      on E: Exception do
      begin
        Memo1.Lines.Add('Ошибка: ' + E.Message);
      end;
    end;
  end;
end;

procedure TfrmMain.btnSearchClick(Sender: TObject);
var
  FileList: TStringList;
  FileCount: Integer;
  i: Integer;
begin
  try
// поиск всех txt и doc файлов в Documents и подпапках
    FileCount := FindFilesByMask(['*.txt', '*.doc'], 'C:\Users\plahovsv\Documents\', FileList, [fsRecursive] // Искать в подпапках
      );

    Memo1.Lines.Add(Format('Найдено файлов: %d', [FileCount]));
    for i := 0 to FileList.Count - 1 do
      Memo1.Lines.Add(FileList[i]);
  finally
    FileList.Free;
  end;
end;

procedure TfrmMain.btnShellCommandClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Add('Запуск архивации...');

  ArchiveWith7ZipAsync('C:\temp', 'D:\archive.7z',
    procedure(const Msg: string; ExitCode: Cardinal)
    begin
// обновление Memo1
      TThread.Queue(nil,
        procedure
        begin
          Memo1.Lines.Add(Msg);
          if ExitCode = 0 then
            Memo1.Lines.Add('Готово! Архив создан успешно.')
          else
            Memo1.Lines.Add('Ошибка! Проверьте исходные данные.');
          Memo1.Lines.Add('----------------------------------');
        end);
    end);
end;

end.
