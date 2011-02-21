{ Copyright (C) 2008-2010 Matthias Klumpp

  Authors:
   Matthias Klumpp

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, version 3.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License v3
  along with this program. If not, see <http://www.gnu.org/licenses/>.}
//** Command-line application for IPK-package handling
program lipa;

{$mode objfpc}{$H+}

//NOTE: We do not use a translatable GUI, so please use the -dNoGUI switch

uses {$IFDEF UNIX}
  cthreads, {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  Process,
  LiUtils,
  LiInstaller,
  StrLocale,
  IniFiles,
  Distri,
  LiTranslator,
  IPKCDef10,
  GExt,
  LiAppMgr,
  LiTypes;

type

  { TLipa }

  TLipa = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    xs: Integer;
    //** Exception handler
    procedure OnExeception(Sender: TObject; E: Exception);
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  private
  end;

  { TLipa }

var
  Application: TLipa;

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////This will be done if "lipa" is started

  procedure OnSetupStatusChange(status: LI_STATUS; details: LiStatusData;
    user_data: Pointer); cdecl;
  begin
    case status of
      LIS_Progress: with Application do
        begin
          if not HasOption('verbose') then
          begin
            //Simple, stupid progress animation
            if xs = 0 then
            begin
              xs := 1;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 1 then
            begin
              xs := 2;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 2 then
            begin
              xs := 3;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 3 then
            begin
              xs := 4;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 4 then
            begin
              xs := 5;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 5 then
            begin
              xs := 6;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 6 then
            begin
              xs := 7;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end
            else
            if xs = 7 then
            begin
              xs := 0;
              Write(#13' ' + IntToStr(details.mnprogress) + '%    ');
            end;
          end;
        end;
      LIS_Stage: if not Application.HasOption('verbose') then
          writeLn(' ' + rsState + ': ' + details.text);
      LIS_Failed:
      begin
        writeLn(' ' + details.text);
        readln;
        halt(5);
      end;
    end;
  end;

  function OnSetupMessage(mtype: LI_MESSAGE; const text: PChar;
    user_data: Pointer): LI_REQUEST_RES; cdecl;
  var
    s: String;

    function AskQuestion: LI_REQUEST_RES;
    begin
      writeLn(' ' + text);
      writeLn('');
      Write(rsYesNo1);
      readln(s);
      s := LowerCase(s);
      if (s = LowerCase(rsYes)) or (s = LowerCase(rsY)) then
        Result := LIRQS_Yes
      else
      begin
        Result := LIRQS_No;
        writeLn(rsInstAborted);
        halt(6);
      end;
    end;

  begin
    case mtype of
      LIM_Info: if not Application.HasOption('verbose') then
          writeLn(' ' + text);
      LIM_Question_YesNo:
      begin
        writeLn(rsQuestion);
        Result := AskQuestion;
      end;
      LIM_Question_AbortContinue:
      begin
        writeLn(rsWarning);
        Result := AskQuestion;
      end;
    end;
  end;

  ////////////////////////////////////////////////////////////////////////////////

  procedure TLipa.DoRun;
  var
    ErrorMsg, a, c: String;
    t: TProcess;
    i: Integer;
    x: Boolean;
    setup: TInstallPack;
    lst: TStringList;
    proc: TProcess;
    cnf: TIniFile;
  begin
    // quick check parameters
    ErrorMsg := CheckOptions('h?b:uvs:i:', ['help', 'build:', 'gen-update',
      'version', 'noquietcrash', 'deb', 'rpm', 'dpack', 'generate-button',
      'sign', 'solve', 'testmode', 'install:', 'verbose', 'checkapps']);
    if ErrorMsg <> '' then
    begin
      writeLn(ErrorMsg);
      Terminate;
      Exit;
    end;

    if ParamStr(1) = '' then
    begin
      writeln('Usage: ', ExeName, ' <command> [file} (options)');
      Terminate;
    end;

    if HasOption('h', 'help') then
    begin
      WriteHelp;
      Halt(0);
    end;

    if HasOption('?', 'help') then
    begin
      WriteHelp;
      Halt(0);
    end;

    if HasOption('v', 'version') then
    begin
      writeLn('Version: ' + LiVersion);
      Halt(0);
    end;

    if (HasOption('b', 'build')) or (HasOption('u', 'gen-update')) then
    begin
      if (FileExists('/usr/bin/libuild')) or
        (FileExists('/usr/lib/listaller/libuild')) then
      begin
        proc := TProcess.Create(nil);
        proc.Options := [];
        c := '';
        for i := 1 to paramcount - 1 do
          c := c + ' ' + ParamStr(i);
        if FileExists('/usr/bin/libuild') then
          proc.CommandLine := 'libuild' + c
        else
          proc.CommandLine := '/usr/lib/listaller/libuild' + c;

        proc.Execute;
        proc.Free;
        Terminate;
      end
      else
        writeLn(rsInstallLiBuild);
    end;

    if HasOption('s', 'solve') then
    begin
      writeLn(SyblToPath('$' + ParamStr(2)));
      halt(0);
    end;

    for i := 1 to paramcount do
      if FileExists(ParamStr(i)) then
        a := ParamStr(i);

    if HasOption('i', 'install') then
    begin
      if not FileExists(a) then
      begin
        writeLn(StringReplace(rsFileNotExists, '%f', a, [rfReplaceAll]));
        halt(1);
        exit;
      end;

      setup := TInstallPack.Create;
      //Assign callbacks
      setup.SetStatusEvent(@OnSetupStatusChange);
      setup.SetMessageEvent(@OnSetupMessage);

      //Check Testmode
      if HasOption('testmode') then
        setup.Testmode := true
      else
        setup.Testmode := false;

      setup.Initialize(a);
      writeLn('== ' + StringReplace(rsInstOf, '%a', setup.GetAppName +
        ' ' + setup.GetAppVersion, [rfReplaceAll]) + ' ==');

      lst := TStringList.Create;
      setup.ReadLongDescription(lst);
      if lst.Count > 0 then
      begin
        writeLn(rsProgDesc);
        for i := 0 to lst.Count - 1 do
          writeLn(lst[i]);
      end;

      setup.ReadLicense(lst);
      if lst.Count > 0 then
      begin
        writeLn(rsLicense);
        for i := 0 to lst.Count - 1 do
        begin
          writeLn(lst[i]);
          readLn;
        end;
        c := '';
        repeat
          writeLn('');
          Write(rsDoYouAcceptLicenseCMD + ' ');
          readLn(c);
          c := LowerCase(c);
          if (c = LowerCase(rsN)) or (c = LowerCase(rsNo)) then
          begin
            setup.Free;
            writeLn(rsInstAborted);
            halt(6);
            exit;
          end;
        until (c = LowerCase(rsY)) or (c = LowerCase(rsYes));
      end;

      //Clear temporary list
      lst.Clear;

      // Check for active profiles
      setup.ReadProfiles(lst);

      if lst.Count = 1 then
        writeLn('Using profile: ' + lst[0])
      else
      begin
        writeLn(rsSelectIModeA);
        for i := 0 to lst.Count - 1 do
          writeLn(' ' + IntToStr(i + 1) + ') ' + lst[i]);
        repeat
          Write(rsModeNumber + ' ');
          readLn(c);
          try
            if (StrToInt(c) - 1 >= lst.Count) or (StrToInt(c) - 1 < 0) then
              writeLn(rsSelectListNumber);
          except
            writeLn(rsEnterNumber);
            c := IntToStr(lst.Count + 2);
          end;
        until (StrToInt(c) - 1 <= lst.Count) and (StrToInt(c) - 1 > -1);
        i := StrToInt(c) - 1;
        setup.SetProfileID(i);
      end;
      //Free tmp list
      lst.Free;

      writeLn('- ' + rsOkay);
      writeLn('-> ' + rsPreparingInstall);

 { cnf:=TInifile.Create(ConfigDir+'config.cnf');
  //Create HTTP object
   HTTP := THTTPSend.Create;
   //HTTP.Sock.OnStatus:=@HookSock;
   HTTP.UserAgent:='Listaller-GET';
  //Create FTP object
   FTP := TFTPSend.Create;
   //FTP.DSock.Onstatus:=@HookSock;
  if cnf.ReadBool('Proxy','UseProxy',false) then
  begin
   //Set HTTP
    HTTP.ProxyPort:=cnf.ReadString('Proxy','hPort','');
    HTTP.ProxyHost:=cnf.ReadString('Proxy','hServer','');
    HTTP.ProxyUser:=cnf.ReadString('Proxy','Username','');
    HTTP.ProxyPass:=cnf.ReadString('Proxy','Password',''); //The PW is visible in the file! It should be crypted
  end;
   cnf.Free;
 //Assign HTTP/FTP objects to Installation service object
  setup.HTTPSend:=HTTP;
  setup.FTPSend:=FTP;
  }

      writeLn('-> ' + rsRunning);
      if not HasOption('verbose') then
        writeLn(' ' + rsState + ': ' + rsStep1);

      //Do the installation
      setup.StartInstallation;

      if HasOption('verbose') then
        for i := 0 to lst.Count - 1 do
          writeLn(lst[i]);

      if not setup.Testmode then
      begin
        writeLn(StringReplace(rsWasInstalled, '%a', setup.GetAppName, [rfReplaceAll]));
        writeLn('Finished.');
      end
      else
      begin
        writeLn(rsExecAppTesting);
        proc.CommandLine := setup.GetAppCMD;
        Proc.Options := [poWaitOnExit];
        Proc.Execute;
        writeLn(rsTestFinished);
        writeLn(rsCleaningUp);
        Proc.CommandLine := 'rm -rf /tmp/litest';
        Proc.Execute;
      end;
      proc.Free;

      halt(0);
    end;

    //???
{
 if HasOption('checkapps') then
 begin
  lst:=TStringList.Create;
  if not CheckApps(lst) then
  begin
   write(rsShowDetailedInfoCMD+' ');
   readLn(c);
   if (c=LowerCase(rsY))or(c=LowerCase(rsYes)) then
    for i:=0 to lst.Count-1 do
     writeLn(lst[i]);
   write(rsLipaAutoFixQ+' ');
   readln(c);
   if (c=LowerCase(rsY))or(c=LowerCase(rsYes)) then
    CheckApps(lst,true)
   else
    writeLn(rsAborted);
  end else
  begin
   write(rsShowDetailedInfoCMD+' ');
   readLn(c);
   if (c=LowerCase(rsY))or(c=LowerCase(rsYes)) then
    for i:=0 to lst.Count-1 do
     writeLn(lst[i]);
  end;
 end; }

    // stop program loop
    Terminate;
  end;

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////Help & Main functions////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  constructor TLipa.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := true;
    //Needed for e.g. the checkapps-parameter
    if IsRoot then
      PkgRegDir := LI_CONFIG_DIR + LI_APPDB_PREF
    else
      PkgRegDir := SyblToPath('$INST') + '/' + LI_APPDB_PREF;
  end;

  destructor TLipa.Destroy;
  begin
    inherited Destroy;
  end;

  procedure TLipa.WriteHelp;
  begin
    writeln('Usage: ', ExeName, ' <command> [file] (options)');

    writeLn(rsLipaInfo1);
    writeLn(rsCommands);
    writeLn('-s, --solve [variable]                     ' + rsLipaInfo2);
    writeLn('-i, --install [IPK-Package]                ' + rsLipaInfo3);
    writeLn('  ' + rsOptions);
    writeLn('    --testmode                             ' + rsLipaInfo4);
    writeLn('    --verbose                              ' + rsLipaInfo5);
    writeLn('--checkapps                                ' + rsLipaInfo6);
    if FileExists('/usr/bin/libuild') or (FileExists('/usr/lib/listaller/libuild')) then
    begin
      writeLn(rsCMDInfoPkgBuild);
      writeLn('-b, --build [IPS-File] [Output-IPK]        ' + rsLiBuildInfoA);
      writeLn('-u, --gen-update [IPS-File] [Repo-Path]    ' + rsLiBuildInfoB);
      writeLn('-b, --build [IPS-File]                     ' + rsLiBuildInfoC);
    end;
  end;

  procedure TLipa.OnExeception(Sender: TObject; E: Exception);
  begin
    writeLn(rsInternalError);
    writeLn('[Message]: ' + E.Message);
    writeLn('(' + rsAborted + ')');
    halt(8);
  end;

{$R *.res}

begin
  Application := TLipa.Create(nil);
  Application.OnException := @Application.OnExeception;
  //Make GType work for us
  InitializeGType();
  Application.Run;
  Application.Free;
end.
