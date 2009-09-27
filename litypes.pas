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
//** This unit contains some basic types (especially for use with libs)
unit litypes;
 
{$MODE objfpc}{$H+}
 
interface
 
uses
  Classes, SysUtils;

type

 //** Pointer to TStringList
 PStringList = ^TStringList;

 //** Request types
 TRqType   = (rqError,rqWarning,rqQuestion,rqInfo);
 //** Request result types
 TRqResult = (rqsYes,rqsNo,rqsOK);
 //** Message types
 TMType    = (mtInfo,mtWarning);

 //** Callback for user request
 TRequestEvent = function(mtype: TRqType;msg: PChar): TRqResult;cdecl;
 //** Callback that submits a notification
 TMessageEvent = function(msg: String;imp: TMType): Boolean;cdecl;
 //** Called if a progress was changed
 TProgressCall = function(pos: Integer): Boolean;cdecl;
 //** Called if progress was changed; only for internal use
 TProgressEvent = procedure(pos: Integer) of Object;

 //** Container for information about apps
 TAppInfo = record
  Name: PChar;
  ShortDesc: PChar;
  Version: PChar;
  Author: PChar;
  Icon: PChar;
  UId: PChar;
 end;

 //** Application groups
 GroupType = (gtALL,
              gtEDUCATION,
              gtOFFICE,
              gtDEVELOPMENT,
              gtGRAPHIC,
              gtNETWORK,
              gtGAMES,
              gtSYSTEM,
              gtMULTIMEDIA,
              gtADDITIONAL,
              gtOTHER,
              gtUNKNOWN);

 //** Event to catch thrown application records
 TAppEvent = function(name: PChar;obj: TAppInfo): Boolean;cdecl;

 //** Listaller package types
 TPkgType = (ptLinstall, ptDLink, ptContainer, ptUnknown);

implementation

end.
