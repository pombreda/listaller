{ packagekit.pas
  Copyright (C) Listaller Project 2009

  packagekit.pas is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  packagekit.pas is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.}
//** Contains Listaller's PackageKit-GLib2 implementation
unit packagekit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, glib2, distri, Dialogs;


//** PackageKit wrapper
type

PK_PROGRESS_TYPE =
(PK_PROGRESS_TYPE_PACKAGE_ID,
 PK_PROGRESS_TYPE_PERCENTAGE,
 PK_PROGRESS_TYPE_SUBPERCENTAGE,
 PK_PROGRESS_TYPE_ALLOW_CANCEL,
 PK_PROGRESS_TYPE_STATUS,
 PK_PROGRESS_TYPE_ROLE,
 PK_PROGRESS_TYPE_CALLER_ACTIVE,
 PK_PROGRESS_TYPE_INVALID);


TPkProgressCallback = procedure(progress: PGObject;ptype: PK_PROGRESS_TYPE;user_data: GPointer);
TGAsyncReadyCallback = procedure(source_object: PGObject;res: Pointer;user_data: GPointer);

PPackageKit = ^TPackageKit;
TPackageKit = class
private
 //PkClient connection
 pkclient: Pointer;
 //Resulting list
 result: TStringList;
 //True if transaction finished
 done: Boolean;
 //True if output should be assigned to list
 asstolist: Boolean;
 //Catch the exitcode
 exitcode: Integer;
 //Current progress
 prog: Integer;
 //Last error message
 ErrorMsg: String;
 //Function to get PackageKit version from pkcon
 function GetPkVersion: String;
 //Signals
 procedure OnMessage(client: Pointer;message: Guint;details: PChar;user_data: Pointer);cdecl;
 procedure OnProgChange(client: Pointer;percentage: guint;subpercentage: guint;elapsed: guint;remaining: guint;user_data: gpointer);cdecl;
 procedure OnPackage(client: Pointer;obj: GPointer;user_data: Pointer);cdecl;
// procedure OnFinish(client: Pointer;exit: guint;runtime:guint;user_data: Pointer);cdecl;
public
 constructor Create;
 destructor Destroy; override;
 {** Check if package is installed @param pkg Name of the package
     @returns True if the daemon queued the transaction}
 function Resolve(pkg: String): Boolean;
 {Returns the reverse dependencies of a package
 @param pkg Name of the package}
 function GetRequires(pkg: String): Boolean;
 {** Removes a package @param pkg Name of the package
    @returns True if the daemon queued the transaction}
 function RemovePkg(pkg: String): Boolean;
 {** Installs a package from repo @param pkg Name of the package
    @returns True if the daemon queued the transaction}
 function InstallPkg(pkg: String): Boolean;
 {** Get the name of the package, the file belongs to (!for installed pkgs only!) @param fname Name of the file
    @returns True if the daemon queued the transaction}
 function PkgNameFromFile(fname: String): Boolean;
 {** Installs a package from file @param fname Name of the package file
      @returns True if the daemon queued the transaction}
 function InstallLocalPkg(fname: String): Boolean;
 {** Get the name of the package, the file belongs to (!for not installed pkgs too!) @param fname Name of the file
      @returns True if the daemon queued the transaction}
 function FindPkgForFile(fname: String): Boolean;
 //** Grab the resulting package list
 property RsList: TStringList read result write result;
 //** Check if the last transaction was finished
 property PkFinished: Boolean read done;
 //** Read finish code
 property PkFinishCode: Integer read exitcode;
 //** Reads the current Packagekit version as string
 property Version: String read GetPkVersion;
 //** Internal: True if a list is recieved
 property AssignToList: Boolean read asstolist;
 //** Current progress of the operation (in %)
 property Progress: Integer read prog;
 //** Read the last error message
 property LastErrorMessage: String read ErrorMsg;
end;

PPkDetailsObj = ^PkDetailsObj;
PkDetailsObj = record
 id: PChar;
 license: PChar;
 //group: PPkGroupEnum;
 description: PChar;
 url: PChar;
 size: Guint64;
end;

PPkPackageId = ^PkPackageID;
PkPackageId = record
 name: PChar;
 version: PChar;
 arch: PChar;
 data: PChar;
end;

//** Needed for use with Qt4, initializes the GType
procedure InitializeGType;

const pklib = 'libpackagekit-glib.so';
const pklib2 = 'libpackagekit-glib2.so';
var loop: PGMainLoop; //GLib main loop to catch signals on idle

//GLib
function g_cancellable_new: Pointer;cdecl;external gliblib name 'g_cancellable_new';

//Bitfield
function pk_filter_bitfield_from_text(filters: PChar): guint64; cdecl; external pklib2 name 'pk_filter_bitfield_from_text';
//Package obj conversion
function pk_package_obj_to_string(obj: GPointer): PChar;cdecl; external pklib name 'pk_package_obj_to_string';
function pk_package_obj_get_id(obj: GPointer): PPkPackageID;cdecl; external pklib name 'pk_package_obj_get_id';
//Actions
function pk_client_reset(client: Pointer;error: PPGError): GBoolean;cdecl;external pklib2 name 'pk_client_reset';
function pk_client_install_packages(client: Pointer;package_ids: PPChar;error: PPGError): GBoolean;cdecl;external pklib name 'pk_client_install_packages';
function pk_client_new:Pointer;cdecl;external pklib2 name 'pk_client_new';

function pk_client_resolve_async(client: Pointer;filters: GuInt64;packages: PPChar;cancellable: PGObject;progress_callback: TPkProgressCallback;progress_user_data: GPointer;callback_ready: TGAsyncReadyCallback;user_data: GPointer): GBoolean;cdecl;external pklib2 name 'pk_client_resolve_async';
function pk_client_get_requires(client: Pointer;filters: Guint64;package_ids: PPChar;recursive: GBoolean;error: PPGerror): GBoolean;cdecl;external pklib name 'pk_client_get_requires';
function pk_client_remove_packages(client: Pointer;package_ids: PPChar;allow_deps: GBoolean;autoremove: GBoolean;error: PPGerror): GBoolean;cdecl;external pklib name 'pk_client_remove_packages';
function pk_client_search_file(client: Pointer;filters: Guint64;search: PChar;error: PPGError): GBoolean;cdecl;external pklib name 'pk_client_search_file';
function pk_client_install_files(client: Pointer;trusted: GBoolean;files_rel:PPChar;error: PPGerror): GBoolean;cdecl;external pklib name 'pk_client_install_files';

implementation

procedure InitializeGType;
begin
 //Needed for use with Qt4
 {$IFNDEF LCLGTK2}
  g_type_init();
 {$ENDIF}
end;

procedure TPackageKit.OnProgChange(client: Pointer;percentage: guint;subpercentage: guint;elapsed: guint;remaining: guint;user_data: Pointer);cdecl;
begin
 if percentage = 101 then
  prog:=0
 else
  prog:=percentage;
end;

procedure TPackageKit.OnPackage(client: Pointer;obj: GPointer;user_data: Pointer);cdecl;
var s: String;pk: PPkPackageID;
begin
if Assigned(RsList) then
begin
 if (obj<>nil)and(AssignToList) then
 begin
 pk:=pk_package_obj_get_id(obj);
 s:=pk^.name;
 RsList.Add(s);
 pk:=nil;
 end;
end;
end;

// This has to be global - PK throws an AV if it is assigned to TPackageKit
procedure OnFinish(client: Pointer;exit: guint;runtime:guint;user_data: Pointer);cdecl;
begin
 TPackageKit(user_data).done:=true;
 TPackageKit(user_data).exitcode:=exit;
end;

procedure TPackageKit.OnMessage(client: Pointer;message: Guint;details: PChar;user_data: Pointer);cdecl;
begin
 writeLn('Details: ');
 writeLn(details);
end;

procedure Testproc(progress: PGObject;ptype: PK_PROGRESS_TYPE;user_data: GPointer);
begin
 ShowMessage('Hi!');
end;

procedure EndProc(source_object: PGObject;res: Pointer;user_data: GPointer);
begin
 ShowMessage('Ende!');
end;

{ TPackageKit }
constructor TPackageKit.Create;
begin
  inherited Create;
  //Create new PackageKit client
  pkclient := pk_client_new;

  //Assign signals
 { g_signal_connect(pkclient,'progress-changed',TGCallback(TMethod(@OnProgChange).Code),self);
  g_signal_connect(pkclient,'package',TGCallback(TMethod(@OnPackage).Code),self);
  g_signal_connect(pkclient,'finished',TGCallback(@OnFinish),self);
  g_signal_connect(pkclient,'message',TGCallback(TMethod(@OnMessage).Code),self); }

  asstolist:=false;
end;

destructor TPackageKit.Destroy;
begin
  pkclient:=nil;
  inherited Destroy;
end;

function TPackageKit.GetPkVersion: String;
var s: TStringList;t: TProcess;
begin
 s:=TStringList.Create;
 t:=TProcess.create(nil);
 t.Options:=[poUsePipes];
 t.CommandLine:='pkcon --version';
 try
  t.Execute;
  while t.Running do begin end;
  s.LoadFromStream(t.Output);
 finally
 t.Free;
 end;
if s.Count>=0 then
Result:=s[0]
else Result:='?';
s.Free;
end;

function TPackageKit.Resolve(pkg: String): Boolean;
var filter: guint64;
    arg: PPChar;
    error: PGError=nil;
    gcl: Pointer;
begin

  Result:=true;
  done:=false;
  filter:=pk_filter_bitfield_from_text('installed');
  arg := StringToPPchar(pkg, 0);

  gcl:=g_cancellable_new;

  //(client: Pointer;filters: GuInt64;packages: PPChar;cancellable: PGObject;progress_callback: TPkProgressCallback;progress_user_data: GPointer;callback_ready: TGAsyncReadyCallback;user_data: GPointer)
  Result:=pk_client_resolve_async(pkclient,filter,arg,gcl,@Testproc,nil,@EndProc,nil);
  if error<>nil then
  begin
    Result:=false;
    g_warning('failed: %s', [error^.message]);
    g_error_free(error);
  end;
end;

function TPackageKit.GetRequires(pkg: String): Boolean;
var filter: guint64;
    ast: String;
    arg: PPChar;
    error: PGError=nil;
begin
  pk_client_reset(pkclient,nil);
  done:=false;
  asstolist:=true;
  filter:=pk_filter_bitfield_from_text('installed');
  ast := pkg+';;;';
  arg := StringToPPchar(ast, 0);

  Result:=pk_client_get_requires(pkclient,filter,arg,true,@error);
  if error<>nil then
  begin
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;
end;

function TPackageKit.RemovePkg(pkg: String): Boolean;
var ast: String;
    arg: PPChar;
    error: PGError=nil;
begin
  pk_client_reset(pkclient,nil);
  done:=false;
  asstolist:=false;
  ast := pkg+';;;';
  arg := StringToPPchar(ast, 0);

  Result:=pk_client_remove_packages(pkclient,arg,true,true,@error);
  if error<>nil then
  begin
    Result:=false;
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;
end;

function TPackageKit.InstallPkg(pkg: String): Boolean;
var ast: String;
    arg: PPChar;
    error: PGError=nil;
begin
  pk_client_reset(pkclient,@error);

  if error<>nil then
  begin
    Result:=false;
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;

  done:=false;
  asstolist:=false;
  ast := pkg+';;;';
  arg := StringToPPchar(ast, 0);

  Result:=pk_client_install_packages(pkclient,arg,@error);

  if error<>nil then
  begin
    Result:=false;
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;
end;

function TPackageKit.PkgNameFromFile(fname: String): Boolean;
var filter: guint64;
    error: PGError=nil;
begin
  pk_client_reset(pkclient,nil);
  done:=false;
  asstolist:=true;
  filter:=pk_filter_bitfield_from_text('installed');

  Result:=pk_client_search_file(pkclient,filter,PChar(fname),@error);
  if error<>nil then
  begin
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;
end;

function TPackageKit.InstallLocalPkg(fname: String): Boolean;
var arg: PPChar;
    error: PGError=nil;
begin
  pk_client_reset(pkclient,nil);
  done:=false;
  asstolist:=false;
  arg:=StringToPPchar(fname, 0);

  Result:=pk_client_install_files(pkclient,true,arg,@error);
  if error<>nil then
  begin
    Result:=false;
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;
end;

function TPackageKit.FindPkgForFile(fname: String): Boolean;
var filter: guint64;
    error: PGError=nil;
    DInfo: TDistroInfo;
    p: TProcess;
    s: TStringList;
begin
DInfo:=GetDistro;
if DInfo.PackageSystem<>'DEB' then
begin
  writeLn('DEBUG: Using native pkit backend.');
  pk_client_reset(pkclient,nil);
  done:=false;
  asstolist:=true;
  filter:=pk_filter_bitfield_from_text('none');

  Result:=pk_client_search_file(pkclient,filter,PChar(fname),@error);
  if error<>nil then
  begin
    g_warning('failed: %s', [error^.message]);
    ErrorMsg:=error^.message;
    g_error_free(error);
  end;
end else
begin
 // We need to use apt-file, because the PackageKit
 // APT backend does not support searching for not-installed packages
  done:=false;
  s:=TStringList.Create;
  p:=TProcess.Create(nil);
  p.Options:=[poUsePipes];
  p.CommandLine:='apt-file -l -N search '+fname;
 try
  p.Execute;
  while p.Running do begin end;
   s.LoadFromStream(p.Output);
 finally
 p.Free;
 end;
 RsList.Assign(s);
 if s.Count>=0 then
  Result:=true
 else Result:=false;
 s.Free;
 done:=true;
end;

end;

initialization
 InitializeGType;

end.

