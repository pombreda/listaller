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
  IniFiles, SysUtils, StrLocale, LiDBusProc, LiFileUtil,
  PackageKit, SoftwareDB, LiStatusObj,
  // Backends
  LiBackend,
  Backend_IPK,
  Backend_Loki,
  Backend_Autopackage,
  Backend_PackageKit;

type
  TDesktopData = record
    Name: String;
    Categories: String;
    IconName: String;
    SDesc: String;
    Author: String;
    Version: String;
    FName: String;
  end;

  TLiAppManager = class(TLiStatusObject)
  private
    SUMode: Boolean;
    FApp: LiAppEvent;

    procedure EmitNewApp(oj: LiAppInfo);

    function IsInList(nm: String; list: TStringList): Boolean;
    //** Catch status messages from DBus action
    procedure DBusStatusChange(ty: LI_STATUS; Data: TLiProcData);
    //** Run a backend
    function RunBackend(backend: TLiBackend; ai: LiAppInfo): Boolean;
  protected
    //Some user data for callbacks
    newapp_udata: Pointer;
    //** ReadIn .desktop files
    function ReadDesktopFile(fname: String): TDesktopData;
  public
    constructor Create;
    destructor Destroy; override;
    //** Rescann all apps installed on the system
    //procedure RescanEntries;
    //** Update AppInstall database
    procedure UpdateAppDB;
    //** Load apps which match filter
    procedure FetchAppList(filter: LiFilter; text: String);
    //** Removes an application
    procedure UninstallApp(obj: LiAppInfo);
 {** Checks dependencies of all installed apps
    @param report Report of the executed actions
    @param fix True if all found issues should be fixed right now
    @returns True if everything is okay, False if dependencies are missing}
    function CheckApps(report: TStringList; const fix: Boolean = false;
      const forceroot: Boolean = false): Boolean;
    procedure RegOnNewApp(call: LiAppEvent; udata: Pointer);
    property SuperuserMode: Boolean read SUMode write SUMode;
  end;

//** Checks if package is installed
function IsPackageInstalled(aName: String = ''; aID: String = '';
  sumode: Boolean = false): Boolean;

implementation

{ TLiAppManager }

constructor TLiAppManager.Create;
begin
  inherited Create;
  FApp := nil;
end;

destructor TLiAppManager.Destroy;
begin
  inherited;
end;

procedure TLiAppManager.RegOnNewApp(call: LiAppEvent; udata: Pointer);
begin
  if CheckPtr(call, 'AppEvent') then
  begin
    FApp := call;
    newapp_udata := udata;
  end;
end;

procedure TLiAppManager.EmitNewApp(oj: LiAppInfo);
begin
  if Assigned(FApp) then
    FApp(@oj, newapp_udata);
end;

function TLiAppManager.IsInList(nm: String; list: TStringList): Boolean;
begin
  Result := list.IndexOf(nm) > -1;
end;


procedure liappmgr_database_new_app(item: PLiAppInfo; limgr: TLiAppManager); cdecl;
begin
  if not (limgr is TLiAppManager) then
  begin
    perror('Assertion data is TLiManager failed');
  end
  else
  if trim(item^.Name) <> '*' then
    limgr.EmitNewApp(item^);
end;

{procedure TLiAppManager.RescanEntries;
var
  ini: TIniFile;
  tmp, xtmp: TStringList;
  db: TSoftwareDB;
  i: Integer;
  blst: TStringList;

  //Internal function to process desktop files
  procedure ProcessDesktopFile(fname: String);
  var
    d: TIniFile;
    entry: LiAppInfo;
    dt: TMOFile;
    lp: String;
    translate: Boolean; //Used, because Assigned(dt) throws an AV
    //Translate string if possible
    function ldt(s: String): String;
    var
      h: String;
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
    translate := false;

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
      EmitInfoMsg(rsLoading + '  ' + ExtractFileName(fname));

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
            translate := true;
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
          EmitInfoMsg(StrSubst(rsCannotLoadIcon, '%a', Name));
        end;
      end;
      EmitNewApp(fname, entry);
      //  if Assigned(dt) then dt.Free;
      if translate then
        dt.Free;

    end
    else
      EmitInfoMsg(StrSubst(rsSkippedX, '%a', ExtractFileName(fname)));
    d.Free;
  end;

begin
  EmitInfoMsg(rsLoading);
  blst := TStringList.Create; //Create Blacklist

  if sumode then
    pdebug('SUMode: Enabled')
  else
    pdebug('SUMode: Disabled');

  db := TSoftwareDB.Create;
  DB.Load(sumode);
  DB.OnNewApp := @liappmgr_database_new_app;

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
    tmp := FindAllFiles('/usr/share/applications/', '*.desktop', true);
    xtmp := FindAllFiles('/usr/local/share/applications/', '*.desktop', true);
    for i := 0 to xtmp.Count - 1 do
      tmp.Add(xtmp[i]);
    xtmp.Free;
  end
  else
    tmp := FindAllFiles(GetEnvironmentVariable('HOME') +
      '/.local/share/applications', '*.desktop', false);

  for i := 0 to tmp.Count - 1 do
  begin
    ProcessDesktopFile(tmp[i]);
  end;

  tmp.Free;
  ini.Free;

  EmitInfoMsg(rsReady); //Loading list finished!

  DB.Free;
  blst.Free; //Free blacklist
end;}

//Read information about an app from .desktop file
function TLiAppManager.ReadDesktopFile(fname: String): TDesktopData;
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
  i: Integer;
  ddata: TDesktopData;
  Data: LiAppInfo;
  appID: String;
  appRmID: String;
  sdb: TSoftwareDB;
begin
  if (sumode) and (not IsRoot) then
  begin
    pwarning('Cannot update AppDB without beeing root!');
    exit;
  end;
  // Search for .desktop files
  tmp := FindAllFiles('/usr/share/applications/', '*.desktop', true);
  xtmp := FindAllFiles('/usr/local/share/applications/', '*.desktop', true);
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
      Data.Id := PChar(appRmId);
      Data.PkType := ptExtern;
      Data.Categories := PChar(ddata.Categories);
      Data.IconName := PChar(ddata.IconName);
      Data.Summary := PChar(ddata.SDesc);
      // Avoid empty summary
      if trim(Data.summary) = '' then
        Data.Summary := Data.Name;
      sdb.AppAddNew(Data);
    end;
  end;
  tmp.Free;
  sdb.Finalize; //Write to disk
  sdb.Free;
end;

// Load the applications
procedure TLiAppManager.FetchAppList(filter: LiFilter; text: String);
var
  sdb: TSoftwareDB;
begin
  sdb := TSoftwareDB.Create;
  sdb.Load(SUMode);
  sdb.RegOnNewApp(LiAppEvent(@liappmgr_database_new_app), self);
  sdb.GetApplicationList(filter, text, nil);
  sdb.Free;
end;

procedure TLiAppManager.DBusStatusChange(ty: LI_STATUS; Data: TLiProcData);
begin
  case Data.changed of
    pdMainProgress: EmitProgress(Data.mnprogress);
    pdInfo: EmitInfoMsg(Data.msg);
    pdError: EmitError(Data.msg);
    pdStatus:
    begin
      if Assigned(FStatus) then
        FStatus(ty, sdata, status_udata);
    end;
  end;
end;

function TLiAppManager.RunBackend(backend: TLiBackend; ai: LiAppInfo): Boolean;
begin
  Result := false;
  // Attach status handler
  backend.RegisterOnStatus(FStatus, status_udata);
  backend.RegisterOnMessage(FMessage, message_udata);
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
  id: String;
  buscmd: ListallerBusCommand;
begin
  id := obj.ID;
  if id = '' then
  begin
    perror('Invalid application info passed: No ID found.');
    exit;
  end;
  EmitStatusChange(LIS_Started);

  pdebug('Application UId is: ' + obj.Id);
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
    end;
    exit;
  end;

  // Run the backends. PackageKit always goes last, it is the slowest one
  if not RunBackend(TIPKBackend.Create, obj) then
    if not RunBackend(TLokiBackend.Create, obj) then
      if not RunBackend(TAutopackageBackend.Create, obj) then
        RunBackend(TPackageKitBackend.Create, obj);

  EmitStatusChange(LIS_Finished);
end;

function TLiAppManager.CheckApps(report: TStringList; const fix: Boolean = false;
  const forceroot: Boolean = false): Boolean;
var
  db: TSoftwareDB;
  app: LiAppInfo;
  deps: TStringList;
  i: Integer;
  pkit: TPackageKit;
begin
  Result := true;
  EmitInfoMsg(rsCheckDepsRegisteredApps);
  if forceroot then
    EmitInfoMsg(rsYouScanOnlyRootInstalledApps)
  else
    EmitInfoMsg(rsYouScanOnlyLocalInstalledApps);

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
            Result := false;
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
          EmitError(rsPkQueryFailed + #10 + rsEMsg + #10 +
            pkit.LastErrorMessage);
          Result := false;
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

function IsPackageInstalled(aname: String; aid: String; sumode: Boolean): Boolean;
var
  db: TSoftwareDB;
begin
  if (aname = '') and (aid = '') then
  begin
    pwarning('Empty strings received for IsPackageInstalled() query.');
    Result := false;
    exit;
  end;
  db := TSoftwareDB.Create;
  if DB.Load(sumode) then
    Result := DB.AppExists(aId)
  else
    Result := false; //No database => no application installed
  DB.Free;
end;

end.

