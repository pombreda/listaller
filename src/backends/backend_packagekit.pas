(* Copyright (C) 2010-2011 Matthias Klumpp
 *
 * Licensed under the GNU General Public License Version 3
 *
 * This unit is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, version 3.
 *
 * This unit is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License v3
 * along with this unit. If not, see <http://www.gnu.org/licenses/>.
 *)
//** PackageKit appremove backend
unit backend_packagekit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LiBackend, LiTypes, LiUtils, IniFiles, StrLocale, Process,
  PackageKit, LiApp;

type
  TPackageKitBackend = class(TLiBackend)
  private
    dskFileName: String;
    pkg: String;
    pkit: TPackageKit;
    appId: String;
  public
    constructor Create;
    destructor Destroy; override;

    function Initialize(app: TLiAppItem): Boolean; override;
    function CanBeUsed: Boolean; override;
    function Run: Boolean; override;
  end;

implementation

{ TPackageKitBackend }

constructor TPackageKitBackend.Create;
begin
  inherited;
  pkit := TPackageKit.Create;
  // Connect PK object to inherited callback methods
  pkit.RegisterOnStatus(FStatus, status_udata);
  pkit.RegisterOnMessage(FMessage, message_udata);
end;

destructor TPackageKitBackend.Destroy;
begin
  pkit.Free;
  inherited;
end;

function TPackageKitBackend.Initialize(app: TLiAppItem): Boolean;
begin
  dskFileName := app.DesktopFile;
  appId := app.AId;
  Result := true;
end;

function TPackageKitBackend.CanBeUsed: Boolean;
var
  tmp: TStringList;
  f, g: Widestring;
  i: Integer;
begin
  Result := true;
  EmitInfoMsg(rsCallingPackageKitPKMonExecActions);
  EmitInfoMsg(rsDetectingPackage);

  pkit.PkgNameFromFile(dskFileName, true);
  EmitProgress(20);

  // Now wait...
  while not pkit.Finished do ;

  if pkit.PkExitStatus <> PK_EXIT_ENUM_SUCCESS then
  begin
    EmitError(PAnsiChar(rsPKitProbPkMon + #10 + rsEMsg + #10 +
      pkit.LastErrorMessage));
    Result := false;
    exit;
  end;

  tmp := TStringList.Create;
  for i := 0 to pkit.RList.Count - 1 do
    tmp.Add(pkit.RList[i].PackageId);

  if (tmp.Count > 0) then
  begin
    f := tmp[0];

    EmitInfoMsg(StrSubst(rsPackageDetected, '%s', f));
    EmitInfoMsg(rsLookingForRevDeps);

    tmp.Clear;

    EmitProgress(18);
    pdebug('GetRequires()');
    pkit.GetRequires(f);

    EmitProgress(25);
    g := '';

    for i := 0 to tmp.Count - 1 do
    begin
      pdebug(tmp[i]);
      g := g + #10 + tmp[i];
    end;

    pdebug('Asking dependency question...');
    pkit.Free;
    if (StringReplace(g, ' ', '', [rfReplaceAll]) = '') or
      (EmitUserRequestAbortContinue(StringReplace(StringReplace(
      StringReplace(rsRMPkg, '%p', f, [rfReplaceAll]), '%a', appId,
      [rfReplaceAll]), '%pl', PChar(g), [rfReplaceAll])) = LIRQS_Yes) then
      Result := true
    else
      Result := false;
  end;
  tmp.Free;
end;

function TPackageKitBackend.Run: Boolean;
begin
  EmitProgress(50);
  EmitInfoMsg(StrSubst(rsRMAppC, '%a', appId) + ' ...');
  pkit.RemovePkg(pkg);

  if pkit.PkExitStatus <> PK_EXIT_ENUM_SUCCESS then
  begin
    EmitError(rsRmError + #10 + rsEMsg + #10 + pkit.LastErrorMessage);
    Result := false;
    exit;
  end;

  EmitProgress(100);
  EmitInfoMsg(rsDone);
end;

end.

