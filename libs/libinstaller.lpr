{ Copyright (C) 2008-2009 Matthias Klumpp

  Authors:
   Matthias Klumpp

  This library is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, version 3.

  This library is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License v3
  along with this library. If not, see <http://www.gnu.org/licenses/>.}
//** Listaller library for all IPK installation related processes
library libinstaller;

{$mode objfpc}{$H+}

uses
  Classes, ipkhandle, SysUtils, Controls, licommon, liTypes,
  management;


//////////////////////////////////////////////////////////////////////////////////////
//Exported helper functions

function li_new_stringlist: Pointer; cdecl;
begin
 Result:=TStringList.Create;
end;

function li_free_stringlist(lst: PStringList): Boolean; cdecl;
begin
Result:=true;
try
 lst^.Free;
except
 Result:=false;
end;
end;

function li_stringlist_read_line(lst: PStringList;ln: Integer): PChar; cdecl;
begin
 if (ln < lst^.Count)and(ln > -1) then
 begin
  Result:=PChar(lst^[ln]);
 end else Result:='List index out of bounds.';
end;

function li_stringlist_write_line(lst: PStringList;ln: Integer;val: PChar): Boolean; cdecl;
begin
 if (ln < lst^.Count)and(ln > -1) then
 begin
  Result:=true;
  lst^[ln]:=val;
 end else Result:=false;
end;

/////////////////////////////////////////////////////////////////////////////////////
//Installer part

//** Removes an application that was installed with an IPK package
function li_remove_ipk_installed_app(appname, appid: PChar;msgcall: TMessageCall;poschange: TProgressCall;fastmode: Boolean): Boolean; cdecl;
begin
Result:=true;
try
 UninstallIPKApp(appname, appid,msgcall,poschange, fastmode, true)
except
 Result:=false;
end;
end;

//** Creates a new installation object
function li_setup_new: Pointer; cdecl;
begin
 Result:=TInstallation.Create;
end;

//** Removes an TInstallation object
function li_setup_free(setup: PInstallation): Boolean;
begin
try
 Result:=true;
 setup^.Free;
except
 Result:=false;
end;
end;

//** Initializes the setup
function li_setup_init(setup: PInstallation;pkname: PChar): PChar; cdecl;
begin
 Result:='';
 if not Assigned(setup^.OnUserRequest) then
 begin
  writeLn('[WARNING] No user request callback is registered!');
 end;

 try
  setup^.Initialize(pkname);
 except
  Result:=PChar('Failed to initialize setup package '+ExtractFileName(pkname)+' !');
 end;
end;

//** Register progress changes (main)
function li_setup_register_main_progress_call(setup: PInstallation;call: TProgressCall): Boolean; cdecl;
begin
 Result:=true;
 try
   setup^.OnProgressMainChange:=call;
 except
  Result:=false;
 end;
end;

//** Register progress changes (extra)
function li_setup_register_extra_progress_call(setup: PInstallation;call: TProgressCall): Boolean; cdecl;
begin
 Result:=true;
 try
  setup^.OnProgressExtraChange:=call;
 except
  Result:=false;
 end;
end;

//** Message call
function li_setup_register_message_call(setup: PInstallation;call: TMessageCall): Boolean; cdecl;
begin
 Result:=true;
 try
  setup^.OnMessage:=call;
 except
  Result:=false;
 end;
end;

//** Step message call
function li_setup_register_step_message_call(setup: PInstallation;call: TMessageCall): Boolean; cdecl;
begin
 Result:=true;
 try
  setup^.OnStepMessage:=call;
 except
  Result:=false;
 end;
end;

//** User request message call
function li_setup_register_user_request_call(setup: PInstallation;call: TRequestCall): Boolean; cdecl;
begin
 Result:=true;
 try
  setup^.OnUserRequest:=call;
 except
  Result:=false;
 end;
end;

//** Installation type
function li_setup_pkgtype(setup: PInstallation): TPkgType; cdecl;
begin
  Result:=setup^.pType;
end;

//** Set installation testmode
function li_testmode(st: Boolean): Boolean; cdecl;
begin
  Testmode:=st;
  Result:=true;
end;

//** Set to superuser mode
function li_set_su_mode(b: Boolean): Boolean; cdecl;
begin
  Root:=b;
  Result:=true;
  if Root then
  RegDir:='/etc/lipa/app-reg/'
  else
  RegDir:=SyblToPath('$INST')+'/app-reg/';
end;

//** Read disallows property
function li_setup_disallows(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.Disallows);
end;

//** Read supported Linux distributions
function li_setup_supported_distributions(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.Distris);
end;

//** Check if application is installed
function li_is_ipk_app_installed(appname: PChar;appid: PChar): Boolean; cdecl;
begin
  Result:=IsPackageInstalled(appname,appid);
end;

//** Resolve all dependencies
function li_setup_resolve_dependencies(setup: PInstallation): Boolean; cdecl;
begin
 Result:=setup^.ResolveDependencies;
end;

//** Readout application name
function li_setup_appname(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.AppName);
end;

//** Read appversion
function li_setup_appversion(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.AppVersion);
end;

//** Get package ID
function li_setup_pkgid(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.ID);
end;

//** Get description
function li_setup_long_description(setup: PInstallation; list: PStringList): Boolean; cdecl;
begin
try
 Result:=true;
 setup^.ReadDescription(list^);
except
 Result:=false;
end;
end;

//** Get wizard image patch
function li_setup_wizard_image_path(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.WizImage);
end;

//** Get license
function li_setup_license(setup: PInstallation; list: PStringList): Boolean; cdecl;
begin
try
 Result:=true;
 setup^.ReadLicense(list^);
except
 Result:=false;
end;
end;

//** Get profiles list
function li_setup_profiles_list(setup: PInstallation; list: PStringList): Boolean; cdecl;
begin
try
 Result:=true;
 setup^.ReadProfiles(list^);
except
 Result:=false;
end;
end;

//** Set current profile id
procedure li_setup_set_profileid(setup: PInstallation;id: ShortInt);cdecl;
begin
 setup^.SetCurProfile(id);
end;

//** Read appversion
function li_setup_appicon(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.AppIcon);
end;

//** Read desktopfiles
function li_setup_desktopfiles(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.DesktopFiles);
end;

//** Read appcmd
function li_setup_app_exec_command(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.CMDLn);
end;

//** Read path to file list
function li_setup_profile_current_filelist(setup: PInstallation): PChar; cdecl;
begin
  Result:=PChar(setup^.IFileInfo);
end;

//** Starts the installation
function li_setup_start(setup: PInstallation): Boolean; cdecl;
begin
  Result:=setup^.DoInstallation;
end;

//** Get dependencies
function li_setup_dependencies(setup: PInstallation; list: PStringList): Boolean; cdecl;
begin
try
 Result:=true;
 list^.Assign(setup^.ADeps);
except
 Result:=false;
end;
end;

////////////////////////////////////////////////////////////////////
//Manager part

//** Start loading list of applications
function li_mgr_load_apps: Boolean;cdecl;
begin
Result:=false;
if not Assigned(FReq) then begin writeLn('[ERROR] No user request callback was registered');exit;end;
try
 Result:=true;
 LoadEntries;
except
 Result:=false;
end;
end;

//** Register message call
function li_mgr_register_msg_call(call: TMessageCall): Boolean; cdecl;
begin
 Result:=true;
 try
  management.FMsg:=call;
 except
  Result:=false;
 end;
end;

//** Register application event to catch found apps
function li_mgr_register_app_call(call: TAppEvent): Boolean;cdecl;
begin
 Result:=true;
 try
  management.FApp:=call;
 except
  Result:=false;
 end;
end;

//** Register event to recieve current progress
function li_mgr_register_progress_call(call: TProgressCall): Boolean;cdecl;
begin
 Result:=true;
 try
  management.FProg:=call;;
 except
  Result:=false;
 end;
end;

//** Register event to recieve user requests
function li_mgr_register_request_call(call: TRequestCall): Boolean;cdecl;
begin
 Result:=true;
 try
  management.FReq:=call;;
 except
  Result:=false;
 end;
end;

//** Sets if aplications should work in root mode
function li_mgr_set_su_mode(md: Boolean): Boolean;cdecl;
begin
 Root:=md;
 Result:=true;
end;

//** Removes the application
function li_mgr_remove_app(obj: TAppInfo): Boolean;cdecl;
begin
 Result:=false;
if not Assigned(FProg) then begin writeLn('[ERROR] You need to register a progress callback!');exit;end;
if not Assigned(FReq) then begin writeLn('[ERROR] You need to register a user request callback!');exit;end;

 Result:=true;
 try
  UninstallApp(obj);
 except
  Result:=false;
 end;
end;

//** Check application dependencies
function li_check_apps(log: PStringList;root: Boolean): Boolean;cdecl;
procedure PerformCheck;
begin
 if not CheckApps(log^,false,root) then
 begin
  Result:=false;
 end else Result:=true;
end;
begin
if log<> nil then
  PerformCheck
else writeLn('[ERROR]: Check log != nil failed.');
end;

//** Fix application dependencies
function li_fix_apps(log: PStringList;root: Boolean): Boolean;cdecl;
procedure PerformCheck;
begin
 if not CheckApps(log^,true,root) then
 begin
  Result:=false;
 end else Result:=true;
end;
begin
if log<> nil then
  PerformCheck
else writeLn('[ERROR]: Check log != nil failed.');
end;

///////////////////////
exports
 //Stringlist functions
 li_new_stringlist,
 li_free_stringlist,
 li_stringlist_read_line,
 li_stringlist_write_line,

 //TInstallation related functions
 li_setup_new,
 li_setup_free,
 li_setup_init,
 li_setup_register_main_progress_call,
 li_setup_register_extra_progress_call,
 li_setup_pkgtype,
 li_setup_disallows,
 li_setup_supported_distributions,
 li_setup_resolve_dependencies,
 li_setup_appname,
 li_setup_appversion,
 li_setup_pkgid,
 li_setup_long_description,
 li_setup_wizard_image_path,
 li_setup_license,
 li_setup_profiles_list,
 li_setup_appicon,
 li_setup_desktopfiles,
 li_setup_app_exec_command,
 li_setup_profile_current_filelist,
 li_setup_register_message_call,
 li_setup_register_step_message_call,
 li_setup_register_user_request_call,
 li_setup_start,
 li_setup_dependencies,
 li_setup_set_profileid,

 //Management functions
 li_mgr_load_apps,
 li_mgr_register_msg_call,
 li_mgr_register_app_call,
 li_mgr_register_progress_call,
 li_mgr_register_request_call,
 li_mgr_set_su_mode,
 li_mgr_remove_app,
 li_check_apps,
 li_fix_apps,

 //Other functions
 li_remove_ipk_installed_app,
 li_testmode,
 li_set_su_mode,
 li_is_ipk_app_installed;

begin
end.

