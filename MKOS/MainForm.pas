unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, TaskInterface;

type
  TTaskInfo = record
    Task: ITask;
    StartTime: TDateTime;
    EndTime: TDateTime;
  end;

  TMainFrm = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    FileOpenDialog1: TFileOpenDialog;
    lbTasks: TListBox;
    lvTasks: TListView;
    ProgressBar: TProgressBar;
    lblProgress: TLabel;
    Timer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FDLLHandles: TList;
    FActiveTasks: array of TTaskInfo;
  public
    { Public declarations }
  end;

var
  MainFrm: TMainFrm;

implementation

{$R *.dfm}

procedure TMainFrm.FormCreate(Sender: TObject);
begin
  FDLLHandles := TList.Create;
  SetLength(FActiveTasks, 0);
end;

procedure TMainFrm.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  // ����������� ��� DLL
  for I := 0 to FDLLHandles.Count - 1 do
    FreeLibrary(THandle(FDLLHandles[I]));
  FDLLHandles.Free;
end;


end.
