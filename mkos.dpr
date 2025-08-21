program mkos;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  CommonMkos in 'CommonMkos.pas',
  TasksFunc in 'TasksFunc.pas';

{$R *.res}

begin
{$IFDEF DEBUG}
//  ReportMemoryLeaksOnShutdown := true; // отслеживание утечек памяти
{$ENDIF}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
