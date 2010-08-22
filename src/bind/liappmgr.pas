{ Copyright (C) 2008-2010 Matthias Klumpp

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
//** LibInstaller functions to manage applications
unit liappmgr;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LiTypes;

 function  li_mgr_new: Pointer;cdecl;external libinst;
 procedure li_mgr_free(mgr: Pointer);cdecl;external libinst;
 function  li_mgr_load_apps(mgr: Pointer): Boolean;cdecl;external libinst;
 function  li_mgr_register_status_call(mgr: Pointer;call: TLiStatusChangeCall; user_data: Pointer): Boolean;cdecl;external libinst;
 function  li_mgr_register_request_call(mgr: Pointer;call: TRequestCall;user_data: Pointer): TRqResult;cdecl;external libinst;
 function  li_mgr_register_app_call(mgr: Pointer;call: TAppEvent): Boolean;cdecl;external libinst;
 procedure li_mgr_set_sumode(mgr: Pointer;md: Boolean);cdecl;external libinst;
 function  li_mgr_remove_app(mgr: Pointer;obj: AppInfo): Boolean;cdecl;external libinst;
 function  li_remove_ipk_installed_app(appname, appid: PChar;scall: TLiStatusChangeCall;fastmode: Boolean): Boolean; cdecl; external libinst;
 function  li_mgr_check_apps(mgr: Pointer;log: PStringList;root: Boolean): Boolean;cdecl;external libinst;
 function  li_mgr_fix_apps(mgr: Pointer;log: PStringList;root: Boolean): Boolean;cdecl;external libinst;

implementation

end.

