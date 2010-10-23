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
//** Functions to manage applications (install/uninstall, dependency-check)
unit limanageapp;

{$mode objfpc}{$H+}

interface

uses
  Classes, GetText, LiTypes, LiUtils, MTProcs, PkTypes, Process,
  IniFiles, SysUtils, IPKCDef10, StrLocale, LiDBusProc, LiFileUtil,
  PackageKit, SoftwareDB, AppInstallDB,
  // Backends
  LiBackend,
  Backend_IPK,
  Backend_Loki,
  Backend_Autopackage;

type
  TDesktopData = record
    Name: string;
    Categories: string;
    IconName: string;
    SDesc: string;
    Author: string;
    Version: string;
    FName: string;
  end;

  TLiAppManager = class
  private
    SUMode: boolean;
    FReq: UserRequestCall;
    FApp: NewAppEvent;
    FStatus: StatusChangeEvent;

    //State data
    sdata: LiStatusData; //Contains the current progress

    procedure msg(s: string);
    function EmitRequest(s: string; ty: LiRqType): LiRqResult;
    procedure EmitNewApp(s: string; oj: LiAppInfo);
    procedure EmitStateChange(state: LiProcStatus);
    procedure EmitPosChange(i: integer);

    function IsInList(nm: string; list: TStringList): boolean;
    //** Catch the PackageKit progress
    procedure PkitProgress(pos: integer; xd: Pointer);
    //** Catch status messages from DBus action
    procedure DBusStatusChange(ty: LiProcStatus; Data: TLiProcData);
    //** Run a backend
    function RunBackend(backend: TLiBackend; ai: LiAppInfo): Boolean;
    procedure InternalRemoveApp(obj: LiAppInfo);
  protected
    //Some user data for callbacks
    statechange_udata: Pointer;
    request_udata: Pointer;
    newapp_udata: Pointer;
    //** ReadIn .desktop files
    function ReadDesktopFile(fname: string): TDesktopData;
  public
    constructor Create;
    destructor Destroy; override;
    //** Rescann all apps installed on the system
    procedure RescanEntries;
    //** Update AppInstall database
    procedure UpdateAppDB;
    //** Removes an application
    procedure UninstallApp(obj: LiAppInfo);
 {** Checks dependencies of all installed apps
    @param report Report of the executed actions
    @param fix True if all found issues should be fixed right now
    @returns True if everything is okay, False if dependencies are missing}
    function CheckApps(report: TStringList; const fix: boolean = False;
      const forceroot: boolean = False): boolean;
    procedure RegOnStatusChange(call: StatusChangeEvent; Data: Pointer);
    procedure RegOnRequest(call: UserRequestCall; Data: Pointer);
    procedure RegOnNewApp(call: NewAppEvent; Data: Pointer);
    property SuperuserMode: boolean read SUMode write SUMode;
    function UserRequestRegistered: boolean;
  end;

//** Checks if package is installed
function IsPackageInstalled(aName: string = ''; aID: string = '';
  sumode: boolean = False): boolean;

implementation

{ TLiAppManager }

constructor TLiAppManager.Create;
begin
  inherited Create;
  FApp := nil;
  FStatus := nil;
  FReq := nil;
end;

destructor TLiAppManager.Destroy;
begin
  inherited;
end;

function TLiAppManager.UserRequestRegistered: boolean;
begin
  if Assigned(FReq) then
    Result := True
  else
    Result := False;
end;

procedure TLiAppManager.RegOnStatusChange(call: StatusChangeEvent; Data: Pointer);
begin
  if CheckPtr(call, 'StatusChangeEvent') then
  begin
    FStatus := call;
    statechange_udata := Data;
  end;
end;

procedure TLiAppManager.RegOnRequest(call: UserRequestCall; Data: Pointer);
begin
  if CheckPtr(call, 'UserRequestCall') then
  begin
    FReq := call;
    request_udata := Data;
  end;
end;

procedure TLiAppManager.RegOnNewApp(call: NewAppEvent; Data: Pointer);
begin
  if CheckPtr(call, 'StatusChangeEvent') then
  begin
    FApp := call;
    newapp_udata := Data;
  end;
end;

procedure TLiAppManager.Msg(s: string);
begin
  sdata.msg := PChar(s);
  if Assigned(FStatus) then
    FStatus(scMessage, sdata, statechange_udata);
end;

function TLiAppManager.EmitRequest(s: string; ty: LiRqType): LiRqResult;
begin
  if Assigned(FReq) then
    Result := FReq(ty, PChar(s), request_udata);
end;

procedure TLiAppManager.EmitNewApp(s: string; oj: LiAppInfo);
begin
  if Assigned(FApp) then
    FApp(PChar(s), @oj, newapp_udata);
end;

procedure TLiAppManager.EmitPosChange(i: integer);
begin
  sdata.mnprogress := i;
  if Assigned(FStatus) then
    FStatus(scMnProgress, sdata, statechange_udata);
end;

procedure TLiAppManager.EmitStateChange(state: LiProcStatus);
begin
  sdata.lastresult := state;
  if Assigned(FStatus) then
    FStatus(scStatus, sdata, statechange_udata);
end;

function TLiAppManager.IsInList(nm: string; list: TStringList): boolean;
begin
  Result := list.IndexOf(nm) > -1;
end;

procedure TLiAppManager.PkitProgress(pos: integer; xd: Pointer);
begin
  //User defindes pointer xd is always nil here
  EmitPosChange(pos);
end;

procedure TLiAppManager.RescanEntries;
var
  ini: TIniFile;
  tmp, xtmp: TStringList;
  i, j: integer;
  db: TSoftwareDB;
  blst: TStringList;

  //Internal function to process desktop files
  procedure ProcessDesktopFile(fname: string);
  var
    d: TIniFile;
    entry: LiAppInfo;
    dt: TMOFile;
    lp: string;
    translate: boolean; //Used, because Assigned(dt) throws an AV
    //Translate string if possible
    function ldt(s: string): string;
    var
      h: string;
    begin
      h := s;
      try
        if translate then
        begin
          h := dt.Translate(s);
          if h = '' then
            h := s;
        end;
      except
        Result := h;
      end;
      Result := s;
    end;

  begin
    d := TIniFile.Create(fname);
    translate := False;

    if (not SUMode) and (d.ReadString('Desktop Entry', 'Exec', '')[1] <> '/') then
    else
    if (LowerCase(d.ReadString('Desktop Entry', 'NoDisplay', 'false')) <>
      'true') and (pos('yast', LowerCase(fname)) <= 0) and
      (LowerCase(d.ReadString('Desktop Entry', 'Hidden', 'false')) <> 'true') and
      (not IsInList(d.ReadString('Desktop Entry', 'Name', ''), blst))
      // and(pos('system',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
      and (pos('core', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <=
      0) and (pos('.hidden', LowerCase(d.ReadString('Desktop Entry',
      'Categories', ''))) <= 0)
      // and(pos('base',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
      and (pos('wine', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <=
      0) and (pos('wine', LowerCase(d.ReadString('Desktop Entry',
      'Categories', ''))) <= 0) and
      (d.ReadString('Desktop Entry', 'X-KDE-ParentApp', '#') = '#') and
      (pos('screensaver', LowerCase(d.ReadString('Desktop Entry',
      'Categories', ''))) <= 0) and
      (pos('setting', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <= 0)
      // and(pos('utility',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
      and (d.ReadString('Desktop Entry', 'OnlyShowIn', '') = '') and
      (d.ReadString('Desktop Entry', 'X-AllowRemove', 'true') = 'true') then
    begin
      msg(rsLoading + '  ' + ExtractFileName(fname));

      if d.ReadString('Desktop Entry', 'X-Ubuntu-Gettext-Domain', '') <> '' then
      begin
        try
          lp := '/usr/share/locale-langpack/' + GetLangID +
            '/LC_MESSAGES/' + d.ReadString('Desktop Entry',
            'X-Ubuntu-Gettext-Domain', 'app-install-data') + '.mo';
          if not FileExists(lp) then
            lp := '/usr/share/locale/de/' + GetLangID +
              '/LC_MESSAGES/' + d.ReadString('Desktop Entry',
              'X-Ubuntu-Gettext-Domain', 'app-install-data') + '.mo';
          if FileExists(lp) then
          begin
            dt := TMOFile.Create(lp);
            translate := True;
          end;
        finally
        end;

      end;

      with entry do
      begin
        removeId := PChar(GenerateAppId(fname));

        if d.ValueExists('Desktop Entry', 'Name[' + GetLangID + ']') then
          Name := PChar(d.ReadString('Desktop Entry', 'Name[' +
            GetLangID + ']', '<error>'))
        else
          Name := PChar(ldt(d.ReadString('Desktop Entry', 'Name', '<error>')));

        Name := PChar(StringReplace(Name, '&', '&&', [rfReplaceAll]));

        Categories := PChar(d.ReadString('Desktop Entry', 'Categories', ''));

        // instLst.Add(Lowercase(d.ReadString('Desktop Entry','Name','<error>')));

        if d.ValueExists('Desktop Entry', 'Comment[' + GetLangID + ']') then
          Summary := PChar(d.ReadString('Desktop Entry', 'Comment[' +
            GetLangID + ']', ''))
        else
          Summary := PChar(ldt(d.ReadString('Desktop Entry', 'Comment', '')));

        Author := PChar(rsAuthor + ': ' + d.ReadString(
          'Desktop Entry', 'X-Publisher', '<error>'));
        if Author = rsAuthor + ': ' + '<error>' then
          Author := '';
        Version := '';
        if d.ReadString('Desktop Entry', 'X-AppVersion', '') <> '' then
          Version := PChar(rsVersion + ': ' +
            d.ReadString('Desktop Entry', 'X-AppVersion', ''));

        entry.IconName := PChar(
          GetAppIconPath(d.ReadString('Desktop Entry', 'Icon', '')));

        if not FileExists(entry.IconName) then
        begin
          entry.IconName := '';
          msg(StrSubst(rsCannotLoadIcon, '%a', Name));
        end;
      end;
      EmitNewApp(fname, entry);
      //  if Assigned(dt) then dt.Free;
      if translate then
        dt.Free;

    end
    else
      msg(StrSubst(rsSkippedX, '%a', ExtractFileName(fname)));
    d.Free;
  end;

begin
  msg(rsLoading);
  blst := TStringList.Create; //Create Blacklist

  if sumode then
    pdebug('SUMode: Enabled')
  else
    pdebug('SUMode: Disabled');

  db := TSoftwareDB.Create;
  DB.Load(sumode);
  DB.OnNewApp := FApp;

  if blst.Count < 4 then
  begin
    blst.Clear;
    blst.LoadFromFile(LI_CONFIG_DIR + 'blacklist');
    blst.Delete(0);
  end;

  DB.GetApplicationList(fAllApps, blst);


  ini := TIniFile.Create(ConfigDir + 'config.cnf');

  //Search for other applications that are installed on this system...
  if SUMode then //Only if user wants to see shared apps
  begin
    tmp := FindAllFiles('/usr/share/applications/', '*.desktop', True);
    xtmp := FindAllFiles('/usr/local/share/applications/', '*.desktop', True);
    for i := 0 to xtmp.Count - 1 do
      tmp.Add(xtmp[i]);
    xtmp.Free;
  end
  else
    tmp := FindAllFiles(GetEnvironmentVariable('HOME') +
      '/.local/share/applications', '*.desktop', False);

  for i := 0 to tmp.Count - 1 do
  begin
    ProcessDesktopFile(tmp[i]);
  end;

  tmp.Free;
  ini.Free;

  msg(rsReady); //Loading list finished!

  DB.Free;
  blst.Free; //Free blacklist
end;

//Read information about an app from .desktop file
function TLiAppManager.ReadDesktopFile(fname: string): TDesktopData;
var
  d: TIniFile;
  Data: TDesktopData;
begin
  d := TIniFile.Create(fname);
  Result.Name := '';
  Data.Name := '';

  //Check for apps which should not be displayed
  if (LowerCase(d.ReadString('Desktop Entry', 'NoDisplay', '')) <> 'true') and
    (pos('yast', LowerCase(fname)) <= 0) and
    (LowerCase(d.ReadString('Desktop Entry', 'Hidden', 'false')) <> 'true')
    // and(pos('system',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
    and (pos('core', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <=
    0) and (pos('.hidden', LowerCase(d.ReadString('Desktop Entry',
    'Categories', ''))) <= 0)
    // and(pos('base',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
    and (pos('wine', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <=
    0) and (pos('wine', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <=
    0) and (d.ReadString('Desktop Entry', 'X-KDE-ParentApp', '#') = '#') and
    (pos('screensaver', LowerCase(d.ReadString('Desktop Entry', 'Categories', ''))) <=
    0) and (pos('setting', LowerCase(d.ReadString('Desktop Entry',
    'Categories', ''))) <= 0)
    // and(pos('utility',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
    and (d.ReadString('Desktop Entry', 'OnlyShowIn', '') = '') and
    (d.ReadString('Desktop Entry', 'X-AllowRemove', 'true') = 'true') then
  begin

    //NOTE: We skip Ubuntu-specific GetText stuff at time
        { if d.ReadString('Desktop Entry', 'X-Ubuntu-Gettext-Domain', '') <> '' then
        begin
          try
            lp := '/usr/share/locale-langpack/' + GetLangID +
              '/LC_MESSAGES/' + d.ReadString('Desktop Entry',
              'X-Ubuntu-Gettext-Domain', 'app-install-data') + '.mo';
            if not FileExists(lp) then
              lp := '/usr/share/locale/de/' + GetLangID +
                '/LC_MESSAGES/' + d.ReadString('Desktop Entry',
                'X-Ubuntu-Gettext-Domain', 'app-install-data') + '.mo';
            if FileExists(lp) then
            begin
              dt := TMOFile.Create(lp);
              translate := true;
            end;
          finally
          end;
        end; }

    Data.Categories := d.ReadString('Desktop Entry', 'Categories', '');

    Data.Name := d.ReadString('Desktop Entry', 'Name', '<error>');
    Data.SDesc := d.ReadString('Desktop Entry', 'Comment', '');
    //Listaller-specific extra data
    Data.Author := d.ReadString('Desktop Entry', 'X-Publisher', '');
    Data.Version := d.ReadString('Desktop Entry', 'X-AppVersion', '');

    Data.IconName := d.ReadString('Desktop Entry', 'Icon', '');
  end;

  d.Free;
  Result := Data;
end;

//Update AppInstall database
procedure TLiAppManager.UpdateAppDB;
var
  tmp, xtmp: TStringList;
  i: integer;
  ddata: TDesktopData;
  Data: LiAppInfo;
  appID: string;
  appRmID: string;
  sdb: TSoftwareDB;
begin
  if (sumode) and (not IsRoot) then
  begin
    pwarning('Cannot update AppDB without beeing root!');
    exit;
  end;
  // Search for .desktop files
  tmp := FindAllFiles('/usr/share/applications/', '*.desktop', True);
  xtmp := FindAllFiles('/usr/local/share/applications/', '*.desktop', True);
  for i := 0 to xtmp.Count - 1 do
    tmp.Add(xtmp[i]);
  xtmp.Free;

  sdb := TSoftwareDB.Create;
  //Open the appinstall databases
  sdb.Load(SUMode);
  // Update the database
  for i := 0 to tmp.Count - 1 do
  begin
    ddata := ReadDesktopFile(tmp[i]);
    appID := StrSubst(ExtractFileName(tmp[i]), '.desktop', '');
    if ddata.Name = '' then
      Continue;
    //If not already in list, add it
    if sdb.AppExists(appID) then
      Continue
    else
    begin
      pdebug('AppID: ' + appID);
      appRmId := GenerateAppID(tmp[i]);
      //Build a new AppInfo record
      Data.Name := PChar(ddata.Name);
      Data.RemoveId := PChar(appRmId);
      Data.PkName := PChar(appID);
      Data.PkType := ptExtern;
      Data.Categories := PChar(ddata.Categories);
      Data.IconName := PChar(ddata.IconName);
      Data.Summary := PChar(ddata.SDesc);
      sdb.AppAddNew(Data);
    end;
  end;
  tmp.Free;
  sdb.Finalize; //Write to disk
  sdb.Free;
end;

procedure TLiAppManager.DBusStatusChange(ty: LiProcStatus; Data: TLiProcData);
begin
  case Data.changed of
    pdMainProgress: EmitPosChange(Data.mnprogress);
    pdInfo: msg(Data.msg);
    pdError: EmitRequest(Data.msg, rqError);
    pdStatus:
    begin
      sdata.lastresult := ty;
      if Assigned(FStatus) then
        FStatus(scStatus, sdata, statechange_udata);
    end;
  end;
end;

//Can remove Autopackage.org or native package.
// Only for interal use, called by UninstallApp.
// This function exists to speed up the removal process.
procedure TLiAppManager.InternalRemoveApp(obj: LiAppInfo);
var
  t: TProcess;
  pkit: TPackageKit;
  Name, id: string;
begin
  EmitPosChange(0);

  //Needed
  Name := obj.Name;
  id := obj.RemoveId;

    EmitPosChange(50);
    pkit := TPackageKit.Create;
    pkit.OnProgress := @PkitProgress;
    Name := copy(id, 5, length(id));
    msg(StrSubst(rsRMAppC, '%a', Name) + ' ...');
    pkit.RemovePkg(Name);

    if pkit.PkExitStatus <> PK_EXIT_ENUM_SUCCESS then
    begin
      EmitRequest(rsRmError + #10 + rsEMsg + #10 + pkit.LastErrorMessage, rqError);
      pkit.Free;
      exit;
    end;

    EmitPosChange(100);
    msg(rsDone);
    pkit.Free;
    exit;

end;

function TLiAppManager.RunBackend(backend: TLiBackend; ai: LiAppInfo): Boolean;
begin
  Result := false;
  // Attach status handler
  backend.SetMessageHandler(FStatus, statechange_udata);
  backend.RootMode := SUMode;
  backend.Initialize(ai);
  if backend.CanBeUsed then
  begin
    // Use it!
    Result := backend.Run;
  end;
  backend.Free;
end;

//Initialize appremove: Detect rdepends if package is native, if package is native, add "pkg:" to
// identification string - if not, pkg has to be Loki/Mojo, so intitiate Mojo-Removal. After rdepends and pkg resolve is done,
// run uninstall as root if necessary. At the end, RemoveAppInternal() is called (if LOKI-Remove was not run) to uninstall
// native or autopackage setup.
procedure TLiAppManager.UninstallApp(obj: LiAppInfo);
var
  id: string;
  i: integer;
  pkit: TPackageKit;
  tmp: TStringList;
  f, g: string;
  buscmd: ListallerBusCommand;
begin
  id := obj.RemoveId;
  if id = '' then
  begin
    perror('Invalid application info passed: No ID found.');
    exit;
  end;
  EmitStateChange(prStarted);
  if (FileExists(id)) and (id[1] = '/') and (copy(id, 1, 4) <> 'pkg:') then
  begin
    ShowPKMon();

    msg(rsCallingPackageKitPKMonExecActions);
    msg(rsDetectingPackage);

    pkit := TPackageKit.Create;
    pkit.OnProgress := @PkitProgress;

    pkit.PkgNameFromFile(id, False); //!!! ,false for debugging
    EmitPosChange(20);

    while not pkit.Finished do ;

    if pkit.PkExitStatus <> PK_EXIT_ENUM_SUCCESS then
    begin
      EmitRequest(PAnsiChar(rsPKitProbPkMon + #10 + rsEMsg + #10 +
        pkit.LastErrorMessage),
        rqError);
      pkit.Free;
      exit;
    end;

    tmp := TStringList.Create;
    for i := 0 to pkit.RList.Count - 1 do
      tmp.Add(pkit.RList[i].PackageId);

    if (tmp.Count > 0) then
    begin
      f := tmp[0];

      msg(StrSubst(rsPackageDetected, '%s', f));
      msg(rsLookingForRevDeps);

      tmp.Clear;

      EmitPosChange(18);
      pdebug('GetRequires()');
      pkit.GetRequires(f);

      EmitPosChange(25);
      g := '';

      for i := 0 to tmp.Count - 1 do
      begin
        pdebug(tmp[i]);
        g := g + #10 + tmp[i];
      end;

      pdebug('Asking dependency question...');
      pkit.Free;
      if (StringReplace(g, ' ', '', [rfReplaceAll]) = '') or
        (EmitRequest(StringReplace(StringReplace(
        StringReplace(rsRMPkg, '%p', f, [rfReplaceAll]), '%a', obj.Name, [rfReplaceAll]),
        '%pl', PChar(g), [rfReplaceAll]), rqWarning) = rqsYes) then
        obj.RemoveId := PChar('pkg:' + f)
      else
        exit;
    end;
    tmp.Free;
    pdebug('Done. ID is set.');

    //Important: ID needs to be the same as AppInfo.RemoveId
    id := obj.RemoveId;
  end;


  pdebug('Application UId is: ' + obj.RemoveId);
  if (SUMode) and (not IsRoot) then
  begin
    //Create worker thread for this action
    buscmd.cmdtype := lbaUninstallApp;
    buscmd.appinfo := obj;
    with TLiDBusAction.Create(buscmd) do
    begin
      pdebug('DbusAction::run!');
      OnStatus := @DBusStatusChange;
      ExecuteAction;
      Free;
      EmitStateChange(prFinished);
    end;
    exit;
  end;

  // Run the backends. PackageKit always goes last, it is the slowest one
  if not RunBackend(TIPKBackend.Create, obj) then
  if not RunBackend(TLokiBackend.Create, obj) then
  if not RunBackend(TAutopackageBackend.Create, obj) then
    InternalRemoveApp(obj);

  EmitStateChange(prFinished);
end;

function TLiAppManager.CheckApps(report: TStringList; const fix: boolean = False;
  const forceroot: boolean = False): boolean;
var
  db: TSoftwareDB;
  app: LiAppInfo;
  deps: TStringList;
  i: integer;
  pkit: TPackageKit;
begin
  Result := True;
  msg(rsCheckDepsRegisteredApps);
  if forceroot then
    msg(rsYouScanOnlyRootInstalledApps)
  else
    msg(rsYouScanOnlyLocalInstalledApps);

  db := TSoftwareDB.Create;
  if DB.Load(forceroot) then
  begin
    deps := TStringList.Create;
    pkit := TPackageKit.Create;

    while not DB.EndReached do
    begin
      app := DB.CurrentDataField.App;
      writeLn(' Checking ' + app.Name);
      deps.Text := app.Dependencies;
      for i := 0 to deps.Count - 1 do
      begin
        pkit.ResolveInstalled(deps[i]);
        if pkit.PkExitStatus = PK_EXIT_ENUM_SUCCESS then
        begin
          if pkit.RList.Count > 0 then
            report.Add(deps[i] + ' found.')
          else
          begin
            report.Add(StrSubst(rsDepXIsNotInstall, '%s', deps[i]));
            Result := False;
            if fix then
            begin
              Write('  Repairing dependency ' + deps[i] + '  ');
              pkit.InstallPkg(deps[i]);
              writeLn(' [OK]');
              report.Add(StrSubst(rsInstalledDepX, '%s', deps[i]));
            end;
          end;
        end
        else
        begin
          EmitRequest(rsPkQueryFailed + #10 + rsEMsg + #10 +
            pkit.LastErrorMessage, rqError);
          Result := False;
          exit;
        end;
      end;
      DB.NextField;
    end;
    deps.Free;
    pkit.Free;
    DB.CloseFilter;
  end
  else
    pdebug('No database found!');
  DB.Free;
  writeLn('Check finished.');
  if not Result then
    writeLn('You have broken dependencies.');
end;

/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

function IsPackageInstalled(aname: string; aid: string; sumode: boolean): boolean;
var
  db: TSoftwareDB;
begin
  if (aname = '') and (aid = '') then
  begin
    pwarning('Empty strings received for IsPackageInstalled() query.');
    Result := False;
    exit;
  end;
  db := TSoftwareDB.Create;
  if DB.Load(sumode) then
    Result := DB.AppExists(aId)
  else
    Result := False; //No database => no application installed
  DB.Free;
end;

end.

