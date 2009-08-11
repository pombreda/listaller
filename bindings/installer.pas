{ installer.pas
  Copyright (C) Listaller Project 2009

  installer.pas is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  installer.pas is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.}
//** This unit contains functions to access libinstaller.so
unit installer;
 
{$MODE objfpc}{$H+}
 
interface
 
uses
  Classes, SysUtils;

type

 PStringList = ^TStringList;

 TListallerPackageType = (lptLinstall, lptDLink, lptContainer);

 TRqType   = (rqError,rqWarning,rqQuestion,rqInfo);
 TRqResult = (rsYes,rsNo,rsOK);

 TRequestEvent = function(mtype: TRqType;msg: PChar): TRqResult; cdecl;
 TMessageEvent = function(msg: String): Boolean; cdecl;

 TProgressChange = function(max: Longint;pos: Longint): Boolean; cdecl;

 TInstallPack = class
 private
  ins: Pointer;
 public
  constructor Create;
  destructor  Destroy;
  procedure Initialize(pkname: String);
  procedure SetMainChangeCall(call: TProgressChange);
  procedure SetExtraChangeCall(call: TProgressChange);
  procedure SetUserRequestCall(call: TRequestEvent);
  procedure SetMessageCall(call: TMessageEvent);
  procedure SetStepMessageCall(call: TMessageEvent);
  function  PkType: TListallerPackageType;
  procedure SetTestmode(b: Boolean);
  function  GetDisallows: String;
  function  GetSupDistris: String;
  function  GetAppName: String;
  function  GetAppVersion: String;
  function  GetAppID: String;
  procedure ReadLongDescription(lst: TStringList);
  function  GetWizardImagePath: String;
  procedure ReadLicense(lst: TStringList);
  procedure ReadProfiles(lst:TStringList);
  procedure ReadDeps(lst:TStringList);
  function  GetAppIcon: String;
  function  GetDesktopFiles: String;
  function  ResolveDependencies: Boolean;
  function  GetAppCMD: String;
  function  GetCurProfileName: String;
  function  GetFileList: String;
 end;

 const libinst = 'libinstaller.so';

 function IsIPKAppInstalled(appname: String;appid: String): Boolean;

implementation

//Import library functions
function remove_ipk_installed_app(appname, appid: PChar;msgcall: TMessageEvent;poschange: TProgressChange;fastmode: Boolean): Boolean; cdecl; external libinst name 'remove_ipk_installed_app';
function new_installation: Pointer; cdecl; external libinst name 'new_installation';
function free_installation(setup: Pointer): Boolean; external libinst name 'free_installation';
function init_installation(setup: Pointer;pkname: PChar): PChar; cdecl; external libinst name 'init_installation';
function ins_register_main_prog_change_call(setup: Pointer;call: TProgressChange): Boolean; cdecl; external libinst name 'ins_register_main_prog_change_call';
function ins_register_extra_prog_change_call(setup: Pointer;call: TProgressChange): Boolean; cdecl; external libinst name 'ins_register_extra_prog_change_call';
function ins_pkgtype(setup: Pointer): TListallerPackageType; cdecl; external libinst name 'ins_pkgtype';
function set_testmode(st: Boolean): Boolean; cdecl; external libinst name 'set_testmode';
function ins_disallows(setup: Pointer): PChar; cdecl; external libinst name 'ins_disallows';
function ins_supported_distributions(setup: Pointer): PChar; cdecl; external libinst name 'ins_supported_distributions';
function is_ipk_app_installed(appname: PChar;appid: PChar): Boolean; cdecl; external libinst name 'is_ipk_app_installed';
function ins_appname(setup: Pointer): PChar; cdecl; external libinst name 'ins_appname';
function ins_appversion(setup: Pointer): PChar; cdecl; external libinst name 'ins_appversion';
function ins_appid(setup: Pointer): PChar; cdecl; external libinst name 'ins_appid';
function ins_long_description(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'ins_long_description';
function ins_wizard_image_path(setup: Pointer): PChar; cdecl; external libinst name 'ins_wizard_image_path';
function ins_license(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'ins_license';
function ins_profiles_list(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'ins_profiles_list';
function ins_appicon(setup: Pointer): PChar; cdecl; external libinst name 'ins_appicon';
function ins_desktopfiles(setup: Pointer): PChar; cdecl; external libinst name 'ins_desktopfiles';
function ins_resolve_dependencies(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'ins_dependencies_list';
function ins_app_exec_command(setup: Pointer): PChar; cdecl; external libinst name 'ins_app_exec_command';
function ins_profile_current_filelist(setup: Pointer): PChar; cdecl; external libinst name 'ins_profile_current_filelist';
function ins_profile_current_name(setup: Pointer): PChar; cdecl; external libinst name 'ins_current_name';
function ins_register_message_call(setup: Pointer;call: TMessageEvent): Boolean; cdecl; external libinst name 'ins_register_message_call';
function ins_register_step_message_call(setup: Pointer;call: TMessageEvent): Boolean; cdecl; external libinst name 'ins_register_step_message_call';
function ins_register_user_request_call(setup: Pointer;call: TRequestEvent): Boolean; cdecl; external libinst name 'ins_register_user_request_call';
function ins_start_installation(setup: Pointer): Boolean; cdecl; external libinst name 'ins_start_installation';
function ins_dependencies(setup: Pointer; list: PStringList): Boolean; cdecl; external libinst name 'ins_dependencies';

{ TInstallPack }

constructor TInstallPack.Create;
begin
 inherited Create;
 ins := new_installation;
end;

destructor TInstallPack.Destroy;
begin
 free_installation(@ins);
 inherited Destroy;
end;

procedure TInstallPack.Initialize(pkname: String);
begin
 init_installation(@ins,PChar(pkname))
end;

procedure TInstallPack.SetMainChangeCall(call: TprogressChange);
begin
 ins_register_main_prog_change_call(@ins,call)
end;

procedure TInstallPack.SetExtraChangeCall(call: TprogressChange);
begin
 ins_register_extra_prog_change_call(@ins,call)
end;

function TInstallPack.PkType: TListallerPackageType;
begin
 Result:=ins_pkgtype(@ins);
end;

procedure TInstallPack.SetTestmode(b: Boolean);
begin
 set_testmode(b);
end;

function TInstallPack.GetDisallows: String;
begin
 Result:=ins_disallows(@ins);
end;

function TInstallPack.GetSupDistris: String;
begin
 Result:=ins_supported_distributions(@ins);
end;

function TInstallPack.GetAppName: String;
begin
 Result:=ins_appname(@ins);
end;

function TInstallPack.GetAppVersion: String;
begin
 Result:=ins_appversion(@ins);
end;

function TInstallPack.GetAppID: String;
begin
 Result:=ins_appid(@ins);
end;

procedure TInstallPack.ReadLongDescription(lst: TStringList);
begin
 ins_long_description(@ins,@lst)
end;

function TInstallPack.GetWizardImagePath: String;
begin
 Result:=ins_wizard_image_path(@ins);
end;

procedure TInstallPack.ReadLicense(lst: TStringList);
begin
 ins_license(@ins,@lst)
end;

procedure TInstallPack.ReadProfiles(lst: TStringList);
begin
 ins_profiles_list(@ins,@lst);
end;

function TInstallPack.GetAppIcon: String;
begin
 Result:=ins_appicon(@ins);
end;

function TInstallPack.GetDesktopFiles: String;
begin
 Result:=ins_desktopfiles(@ins);
end;

function TInstallPack.ResolveDependencies: Boolean;
var tmp: TStringList;
begin
 tmp:=TstringList.Create;
 ReadDeps(tmp);
 Result:=ins_resolve_dependencies(@ins,@tmp);
 tmp.Free;
end;

function TInstallPack.GetAppCMD: String;
begin
 Result:=ins_app_exec_command(@ins);
end;

function TInstallPack.GetCurProfileName: String;
begin
 Result:=ins_profile_current_name(@ins);
end;

function TInstallPack.GetFileList: String;
begin
 Result:=ins_profile_current_filelist(@ins);
end;

procedure TInstallPack.SetUserRequestCall(call: TRequestEvent);
begin
 ins_register_user_request_call(@ins,call)
end;

procedure TInstallPack.SetMessageCall(call: TMessageEvent);
begin
 ins_register_message_call(@ins,call)
end;

procedure TInstallPack.SetStepMessageCall(call: TMessageEvent);
begin
 ins_register_step_message_call(@ins,call)
end;

procedure TInstallPack.ReadDeps(lst: TStringList);
begin
 ins_dependencies(@ins,@lst);
end;

function IsIPKAppInstalled(appname: String;appid: String): Boolean;
begin
 Result:=is_ipk_app_installed(PChar(appname), PChar(appid));
end;

end.
