{ libuild.lpr
  Copyright (C) Listaller Project 2008-2009

  libuild.lpr is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  libuild.lpr is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.}
//** Command-line application for IPK-package building
program libuild;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, //We need an widgetset (NoGUI) for graphic handling
  Classes, SysUtils, CustApp,
  LiCommon, Process, ipkbuild,
  TrStrings, LiTranslator;

type

  { TLiBuild }

  TLiBuild = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
     //** Exception handler
    procedure OnExeception(Sender : TObject;E : Exception);
  end;

{ TLiBuild }

procedure TLiBuild.DoRun;
var
  ErrorMsg,a,b: String;
  t: TProcess;
  i: Integer;
  x: Boolean;
begin
  // quick check parameters

  ErrorMsg:=CheckOptions('h','help');
  ErrorMsg:=CheckOptions('?','help');
  //
  ErrorMsg:=CheckOptions('b','build');
  ErrorMsg:=CheckOptions('u','gen-update');
  ErrorMsg:=CheckOptions('v','version');
 { if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Halt;
  end;  }

  //Parse parameters
  i:=1;
  a:='';
  b:='';

  if HasOption('h','help') then
  begin
    WriteHelp;
    Halt(0);
  end;

  if HasOption('?','help') then
  begin
    WriteHelp;
    Halt(0);
  end;

  if HasOption('v','version') then
  begin
    writeLn('Version: '+LiVersion);
    Halt(0);
  end;

  if paramstr(1)='' then
  begin
   writeln('Usage: ',ExeName,' <option> [file] ...');
   Terminate;
  end;

 while paramstr(i)<>'' do
 begin
   if paramstr(i)[1]='/' then
    if a = '' then a := paramstr(i)
    else b:=paramstr(i);
    Inc(i);
  end;

  a:=ExpandFileName(a);
  b:=ExpandFileName(b);

  if HasOption('b','build') then
  begin
  if HasOption('deb')or HasOption('rpm')or HasOption('dpack') then
  begin
    if FileExists(ExtractFilePath(ExeName)+'unibuild') then
    begin
      t:=tprocess.create(nil);
      t.Options:=[poUsePipes];
      t.CommandLine:=ExtractFilePath(ExeName)+'unibuild '+paramstr(3);
      sleep(10);
      t.Free;
     end else
     begin
      writeLn('Cannot execute this action.');
      writeLn('The unibuild function was not found.');
      writeLn('Is Listaller UniBuild installed?');
      halt(1);
     end;
  end;

  if HasOption('generate-button') then x:=true else x:=false;
   if (FileExists(a))
   then
   begin
   if b<>'' then
   begin
   if (not FileExists(b))
   and (LowerCase(ExtractFileExt(b))='.ipk')
   and (DirectoryExists(ExtractFilePath(b))) then
   begin
   BuildPackage(a,b,x);
   end else
   begin
   writeln('Can''t build file.');
   writeLn('- Does the input-file exist?');
   writeLn('- Has the output-file parameter the extension .IPK?');
   writeln('- Does the IPK-File already exists?');
   halt(10);
   end;
   end else
   begin
   if not FileExists(ChangeFileExt(a,'.ipk')) then
   BuildPackage(a,ChangeFileExt(a,'.ipk'),x)else
   begin
   writeLn('The package "'+ChangeFileExt(a,'.ipk')+'" already exists!');
   halt(10);
   end;
   end;
   end;
   halt;
  end;

  if HasOption('u','gen-update') and(FileExists(paramstr(2)))and(DirectoryExists(paramstr(3)))
  then CreateUpdateSource(paramstr(2),paramstr(3)+'/');

  //Stop program loop
  Terminate;
end;

constructor TLiBuild.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TLiBuild.Destroy;
begin
  inherited Destroy;
end;

procedure TLiBuild.OnExeception(Sender : TObject;E : Exception);
begin
writeLn(rsInternalError);
writeLn('[Message]: '+E.Message);
writeLn('(Aborted)');
halt(8);
end;

procedure TLiBuild.WriteHelp;
begin
writeLn('Listaller''s package builder');
writeln('Usage: ',ExeName,' <option> [file] ...');
writeLn('Commands:');
writeln('-?, --help                                 Show this help');
writeln('-v, --version                              Show Listaller version');
writeLn(rsLiBuildInfoA);
writeLn('-u, --gen-update [IPS-File] [Repo-Path]    Create/Update update-repository');
writeLn('-b, --build [IPS-File]                     Create DEB and RPM file from IPS');
writeLn('  Options:');
writeLn('    --generate-button                      Generates the "Linux-compatible" PNG button for this package');
if FileExists(ExtractFilePath(ExeName)+'unibuild') then
writeLn('  Enables these options:')
else
writeLn('  Enables these options: (! "unibuild" needed)');
writeLn('    --dpack                                Generates DEB/RPM package from IPS file');
writeLn('    --deb                                  Create DEB package');
writeLn('    --rpm                                  Create RPM package');
writeLn('');
end;

var
  Application: TLiBuild;

{$IFDEF WINDOWS}{$R libuild.rc}{$ENDIF}

begin
  Application:=TLiBuild.Create(nil);
  Application.OnException:=@Application.OnExeception;
  Application.Run;
  Application.Free;
end.
