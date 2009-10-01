{ Copyright (C) 2008-2009 Matthias Klumpp

  Authors:
   Matthias Klumpp

  This unit is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, version 3.

  This unit is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License v3
  along with this unit. If not, see <http://www.gnu.org/licenses/>.}
//** This unit contains functions to use the installer part of libInstaller
unit installer;
 
{$MODE objfpc}{$H+}
 
interface
 
uses
  Classes, SysUtils, liTypes;

type

 TInstallPack = class
 private
  ins: Pointer;
 public
  constructor Create;
  destructor  Destroy;override;

  procedure Initialize(pkname: String);
  procedure SetMainChangeCall(call: TProgressCall);
  procedure SetExtraChangeCall(call: TProgressCall);
  procedure SetUserRequestCall(call: TRequestEvent);
  procedure SetMessageCall(call: TMessageEvent);
  procedure SetStepMessageCall(call: TMessageEvent);
  function  PkType: TPkgType;
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
  function  GetFileList: String;
  function  StartInstallation: Boolean;
  procedure SetProfileID(i: Integer);
 end;

 const libinst = 'libinstaller.so';

 function IsIPKAppInstalled(appname: String;appid: String): Boolean;

implementation

//Import library functions
function li_setup_new: Pointer; cdecl; external libinst name 'li_setup_new';
function li_setup_free(setup: Pointer): Boolean; external libinst name 'li_setup_free';
function li_setup_init(setup: Pointer;pkname: PChar): PChar; cdecl; external libinst name 'li_setup_init';
function li_setup_register_main_progress_call(setup: Pointer;call: TProgressCall): Boolean; cdecl; external libinst name 'li_setup_register_main_progress_call';
function li_setup_register_extra_progress_call(setup: Pointer;call: TProgressCall): Boolean; cdecl; external libinst name 'li_setup_register_extra_progress_call';
function li_setup_pkgtype(setup: Pointer): TPkgType; cdecl; external libinst name 'li_setup_pkgtype';
function li_setup_disallows(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_disallows';
function li_setup_supported_distributions(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_supported_distributions';
function li_setup_appname(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_appname';
function li_setup_appversion(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_appversion';
function li_setup_pkgid(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_pkgid';
function li_setup_long_description(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'li_setup_long_description';
function li_setup_wizard_image_path(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_wizard_image_path';
function li_setup_license(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'li_setup_license';
function li_setup_profiles_list(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'li_setup_profiles_list';
function li_setup_appicon(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_appicon';
function li_setup_desktopfiles(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_desktopfiles';
function li_setup_resolve_dependencies(setup: Pointer; list: Pointer): Boolean; cdecl; external libinst name 'li_setup_resolve_dependencies';
function li_setup_app_exec_command(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_app_exec_command';
function li_setup_profile_current_filelist(setup: Pointer): PChar; cdecl; external libinst name 'li_setup_profile_current_filelist';
function li_setup_register_message_call(setup: Pointer;call: TMessageEvent): Boolean; cdecl; external libinst name 'li_setup_register_message_call';
function li_setup_register_step_message_call(setup: Pointer;call: TMessageEvent): Boolean; cdecl; external libinst name 'li_setup_register_step_message_call';
function li_setup_register_user_request_call(setup: Pointer;call: TRequestEvent): Boolean; cdecl; external libinst name 'li_setup_register_user_request_call';
function li_setup_start(setup: Pointer): Boolean; cdecl; external libinst name 'li_setup_start';
function li_setup_dependencies(setup: Pointer; list: PStringList): Boolean; cdecl; external libinst name 'li_setup_dependencies';
function li_setup_set_profileid(setup: Pointer;id: ShortInt): Boolean; cdecl;  external libinst name 'li_setup_set_profileid';
function li_is_ipk_app_installed(appname: PChar;appid: PChar): Boolean; cdecl; external libinst name 'li_is_ipk_app_installed';
function li_set_su_mode(b: Boolean): Boolean; cdecl; external libinst name 'li_set_su_mode';
function li_testmode(st: Boolean): Boolean; cdecl; external libinst name 'li_testmode';

{ TInstallPack }

constructor TInstallPack.Create;
begin
 inherited Create;
 ins := li_setup_new;
end;

destructor TInstallPack.Destroy;
begin
 li_setup_free(@ins);
 inherited Destroy;
end;

procedure TInstallPack.Initialize(pkname: String);
begin
 li_setup_init(@ins,PChar(pkname))
end;

procedure TInstallPack.SetMainChangeCall(call: TProgressCall);
begin
 li_setup_register_main_progress_call(@ins,call)
end;

procedure TInstallPack.SetExtraChangeCall(call: TProgressCall);
begin
 li_setup_register_extra_progress_call(@ins,call)
end;

function TInstallPack.PkType: TPkgType;
begin
 Result:=li_setup_pkgtype(@ins);
end;

procedure TInstallPack.SetTestmode(b: Boolean);
begin
 li_testmode(b);
end;

function TInstallPack.GetDisallows: String;
begin
 Result:=li_setup_disallows(@ins);
end;

function TInstallPack.GetSupDistris: String;
begin
 Result:=li_setup_supported_distributions(@ins);
end;

function TInstallPack.GetAppName: String;
begin
 Result:=li_setup_appname(@ins);
end;

function TInstallPack.GetAppVersion: String;
begin
 Result:=li_setup_appversion(@ins);
end;

function TInstallPack.GetAppID: String;
begin
 Result:=li_setup_pkgid(@ins);
end;

procedure TInstallPack.ReadLongDescription(lst: TStringList);
begin
 li_setup_long_description(@ins,@lst)
end;

function TInstallPack.GetWizardImagePath: String;
begin
 Result:=li_setup_wizard_image_path(@ins);
end;

procedure TInstallPack.ReadLicense(lst: TStringList);
begin
 li_setup_license(@ins,@lst)
end;

procedure TInstallPack.ReadProfiles(lst: TStringList);
begin
 li_setup_profiles_list(@ins,@lst);
end;

function TInstallPack.GetAppIcon: String;
begin
 Result:=li_setup_appicon(@ins);
end;

function TInstallPack.GetDesktopFiles: String;
begin
 Result:=li_setup_desktopfiles(@ins);
end;

function TInstallPack.ResolveDependencies: Boolean;
var tmp: TStringList;
begin
 tmp:=TstringList.Create;
 ReadDeps(tmp);
 Result:=li_setup_resolve_dependencies(@ins,@tmp);
 tmp.Free;
end;

function TInstallPack.GetAppCMD: String;
begin
 Result:=li_setup_app_exec_command(@ins);
end;

function TInstallPack.GetFileList: String;
begin
 Result:=li_setup_profile_current_filelist(@ins);
end;

procedure TInstallPack.SetUserRequestCall(call: TRequestEvent);
begin
 li_setup_register_user_request_call(@ins,call)
end;

procedure TInstallPack.SetMessageCall(call: TMessageEvent);
begin
 li_setup_register_message_call(@ins,call)
end;

procedure TInstallPack.SetStepMessageCall(call: TMessageEvent);
begin
 li_setup_register_step_message_call(@ins,call)
end;

procedure TInstallPack.ReadDeps(lst: TStringList);
begin
 li_setup_dependencies(@ins,@lst);
end;

function TInstallPack.StartInstallation: Boolean;
begin
 Result:=li_setup_start(@ins);
end;

procedure TInstallPAck.SetProfileID(i: Integer);
begin
 li_setup_set_profileid(@ins,i);
end;

function IsIPKAppInstalled(appname: String;appid: String): Boolean;
begin
 Result:=li_is_ipk_app_installed(PChar(appname), PChar(appid));
end;

end.
