program litray;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, linotify, LResources
  { you can add units after this };

{$IFDEF WINDOWS}{$R litray.rc}{$ENDIF}

begin
  Application.Title:='Listaller Notify';
  {$I litray.lrs}
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

