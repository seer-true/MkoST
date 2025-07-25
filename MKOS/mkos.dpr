program mkos;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {MainFrm},
  TaskInterface in 'TaskInterface.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainFrm, MainFrm);
  Application.Run;
end.
