program mkos;

uses
  Vcl.Forms,
  MainFrm in 'MainFrm.pas' {frmMain},
  DllExportsViewer in 'DllExportsViewer.pas',
  FileSearchUtils in 'FileSearchUtils.pas',
  AsyncShellCommand in 'AsyncShellCommand.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
