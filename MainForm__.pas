unit MainForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Forms, Vcl.StdCtrls;

type
  TLogCallback = procedure(Msg: PChar); stdcall;
  TArchiveFolderFunc = function(FolderPath, ArchiveName: PChar; Callback: TLogCallback): Boolean; stdcall;
  TStopArchivingProc = procedure; stdcall;

  TForm1 = class(TForm)
    btnStart: TButton;
    btnStop: TButton;
    Memo1: TMemo;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    DllHandle: THandle;
    ArchiveFolder: TArchiveFolderFunc;
    StopArchiving: TStopArchivingProc;
    procedure Log(const Msg: string);
  public
    procedure Callback(Msg: PChar); stdcall;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Callback(Msg: PChar); stdcall;
begin
  Memo1.Lines.Add(Msg);
  Application.ProcessMessages;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  DllHandle := LoadLibrary('ArchiveLib.dll');
  if DllHandle = 0 then
    raise Exception.Create('Не удалось загрузить DLL');

  @ArchiveFolder := GetProcAddress(DllHandle, 'ArchiveFolder');
  @StopArchiving := GetProcAddress(DllHandle, 'StopArchiving');

  if not Assigned(ArchiveFolder) or not Assigned(StopArchiving) then
    raise Exception.Create('Не удалось найти функции в DLL');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if DllHandle <> 0 then
    FreeLibrary(DllHandle);
end;

procedure TForm1.btnStartClick(Sender: TObject);
begin
  // Запуск архивации (пример путей)
  ArchiveFolder(
    'C:\Temp\SourceFolder',
    'C:\Temp\archive.zip',
    Callback
  );
end;

procedure TForm1.btnStopClick(Sender: TObject);
begin
  // Остановка архивации
  StopArchiving;
end;

procedure TForm1.Log(const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

end.