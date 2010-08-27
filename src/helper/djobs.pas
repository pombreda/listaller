{ Copyright (C) 2009-2010 Matthias Klumpp

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
//** Contains threads which process software management jobs
unit djobs;

//////////////////////////////
//IMPORTANT: The actions should be separate threads. Cause of some bugs, listallerd
//           does not use threads at time.
//           Please leave the (uncommented) parts which are used for multithreading.
//           They may be used some time later.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DBus, PolKit, GLib2, gExt, LiInstaller, LiAppMgr,
  LiUtils, LiTypes, SimDBus, Contnrs, LiAppUpdate, SyncObjs;

type
  TAccessType = (AC_UNKNOWN, AC_AUTHORIZED, AC_NOT_AUTHORIZED);

  //** Base class for all jobs
  TJob = class//(TThread)
  protected
    allowed: TAccessType;
    ident: string;
    loop: PGMainLoop;

    authority: PPolkitAuthority;
    origMsg: PDBusMessage;
    bs: TDBusServer;
    jobID: string;
    remove: boolean;
  private
    function RandomCode: string;
    procedure SendReply(stat: boolean; jID: string); virtual; abstract;
  public
    constructor Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
    destructor Destroy; override;

    //!
    procedure Execute; virtual; abstract;

    property Authorization: TAccessType read allowed write allowed;
    property Identifier: string read ident write ident;
    property MainLoop: PGMainLoop read loop write loop;
    property DId: string read jobID write jobID;
  end;

  //** Job which can install software packages
  TDoAppInstall = class(TJob)
  private
    FileName: string;
    actUSource: boolean;
    overrides: string;
    //** Send reply to client
    procedure SendReply(stat: boolean; jID: string); override;
    //** Emit a progress changed signal
    procedure SendProgressSignal(xn: string; sigvalue: integer);
    //** Emit a message signal with the current message
    procedure SendMessageSignal(xn: string; sigvalue: string);
  public
    constructor Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
    destructor Destroy; override;

    procedure Execute; override;
  end;

  //** Job which removes applications
  TDoAppRemove = class(TJob)
  private
    appinfo: AppInfo;
    //** Pointer to management object
    mgr: Pointer;
    //** Send reply to client
    procedure SendReply(stat: boolean; jID: string); override;
    //** Emit a global string signal
    procedure EmitMessage(id: string; param: string);
  public
    constructor Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
    destructor Destroy; override;

    procedure Execute; override;
  end;

  //** Job which updates an application
  TDoAppUpdate = class(TJob)
  private
    //** Pointer updater object
    upd: Pointer;
    //* Receive update ID nr
    updID: integer;
    //** Send reply to client
    procedure SendReply(stat: boolean; jID: string); override;
    //** Emit a global string signal
    procedure EmitMessage(id: string; param: string);
  public
    constructor Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
    destructor Destroy; override;

    procedure Execute; override;
  end;

const
  CALL_RUNSETUP = 'ExecuteSetup';
  CALL_APPREMOVE = 'RemoveApp';
  CALL_UPDATEAPP = 'UpdateApp';

var
  InstallWorkers: integer;
  ManagerWorkers: integer;
  critsec: TRTLCriticalSection;

implementation

{ TJob }

constructor TJob.Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
begin
  inherited Create;//(true);

  origMsg := aMsg;
  remove := false;
  bs := TDBusServer.Create(dbusConn);

  authority := polkit_authority_get();
  loop := g_main_loop_new(nil, false);
  allowed := AC_UNKNOWN;
  jobID := RandomCode;
  //FreeOnTerminate:=true;
end;

destructor TJob.Destroy;
begin
  bs.Free;
  g_object_unref(authority);
  g_main_loop_unref(loop);
 {if Assigned(FatalException) then
  raise FatalException;}
  inherited;
end;

function TJob.RandomCode: string;
begin
  randomize;
  Result := IntToStr(random(9)) + IntToStr(random(9)) + IntToStr(random(9)) +
    IntToStr(random(9));
end;

procedure check_authorization_cb(authority: PPolkitAuthority;
  res: PGAsyncResult; j: Pointer);cdecl;
var
  error: PGError;
  Result: PPolkitAuthorizationResult;
  result_str: PGChar;
  job: TJob;
begin
  if not (TObject(j) is TJob) then
  begin
    perror('Invalid Job received! This is a critical bug, listallerd will terminate.');
    perror('Please report this issue.');
    halt(500);
    exit;
  end;

  job := TJob(j);
  error := nil;
  result_str := '';

  Result := polkit_authority_check_authorization_finish(authority, res, @error);
  if (error <> nil) then
  begin
    perror('Error checking authorization: '#10 + error^.message);
    g_error_free(error);
    job.Authorization := AC_NOT_AUTHORIZED;
    g_main_loop_quit(job.MainLoop);
    exit;
  end
  else
  begin
    if (polkit_authorization_result_get_is_authorized(Result)) then
      result_str := 'authorized'
    else if (polkit_authorization_result_get_is_challenge(Result)) then
        result_str := 'challenge'
      else
        result_str := 'not authorized';

    pinfo('Authorization result for ' + job.Identifier + ': ' + result_str);
  end;
  if result_str = 'authorized' then
    job.Authorization := AC_AUTHORIZED
  else
    job.Authorization := AC_NOT_AUTHORIZED;
  g_main_loop_quit(job.MainLoop);
end;

{ TDoAppInstall }

constructor TDoAppInstall.Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
var
  action_id: PGChar;
  subject: PPolkitSubject;
  target: string;

  procedure Error_Terminate;
  begin
    SendReply(false, '');
 {Terminate;
 Resume();}
  end;

begin
  inherited Create(aMsg, dbusConn);
  overrides := '';
  ident := 'DoAppInstall~' + dbus_message_get_sender(aMsg);
  jobId := 'installer' + jobId;


  if not bs.InitMessageIter(aMsg) then
  begin
    Error_Terminate;
    exit;
  end;

  FileName := bs.ReadMessageParamStr;
  bs.MessageIterNext;
  overrides := bs.ReadMessageParamStr;
  bs.MessageIterNext;
  actUSource := bs.ReadMessageParamBool;


  pinfo('RunSetup called with ' + FileName);

  action_id := 'org.nlinux.listaller.execute-installation';
  target := dbus_message_get_sender(origMsg);

  subject := polkit_system_bus_name_new(PGChar(target));

  polkit_authority_check_authorization(authority, subject, action_id,
    nil,
    POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
    nil,
    @check_authorization_cb,
    self);


  g_object_unref(subject);
  g_main_loop_run(loop);

  //If not authorized, quit the job
  if allowed = AC_NOT_AUTHORIZED then
  begin
    perror('Not authorized to call this action.');
    SendReply(false, '');
    remove := true;
    //Resume();
    exit;
  end;

  pinfo('New app install job for ' + bs.getMessageSender(aMsg) + ' started.');

  if not FileExists(FileName) then
  begin
    perror('Installation package not found!');
    pdebug(FileName);
    Error_Terminate;
    exit;
  end;

  //We got authorization!
  SendReply(true, PChar(jobID));

  //Start work
  //Resume();
  Execute();
end;

destructor TDoAppInstall.Destroy;
begin
  Dec(InstallWorkers);
  inherited;
end;

procedure TDoAppInstall.SendProgressSignal(xn: string; sigvalue: integer);
var
  msg: PDBusMessage;
begin
    // create a signal & check for errors
    msg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
      // object name of the signal
      'org.nlinux.Listaller.Install', // interface name of the signal
      xn);

    bs.AppendUInt(sigvalue);
    bs.SendMessage(msg);
end;

procedure TDoAppInstall.SendMessageSignal(xn: string; sigvalue: string);
var
  msg: PDBusMessage;
begin
    // create a signal & check for errors
    msg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
      // object name of the signal
      'org.nlinux.Listaller.Install', // interface name of the signal
      xn); // name of the signal

    bs.AppendStr(sigvalue);
    bs.SendMessage(msg);
end;

procedure TDoAppInstall.SendReply(stat: boolean; jID: string);
var
  reply: PDBusMessage;
  auth: PChar = '';
begin
  pinfo('Send reply called');

  //Create a reply from the message
  reply := bs.CreateReturnMessage(origMsg);

  bs.AppendBool(stat);
  auth := '';
  if allowed = AC_AUTHORIZED then
    auth := 'authorized'
  else if allowed = AC_NOT_AUTHORIZED then
      auth := 'blocked';
  bs.AppendStr(auth);
  bs.AppendStr(jID);

  bs.SendMessage(reply);

  //Free the message
  bs.FreeMessage(origMsg);
end;

function InstallUserRequest(mtype: TRqType; info: PChar; job: Pointer): TRqResult; cdecl;
begin
  Result := rqsOK;
  //The daemon should not ask questions while doing a transaction.
  //All questions which need a reply should be done before or after the daemon call
  if mtype = rqError then
  begin
    //Emit error message and quit job
    TDoAppInstall(job).SendMessageSignal('Error', info);
  end
  else
  begin
    perror('Received invalid user request! (Daemon should _never_ ask questions which need a reply.)');
    Result := rqsNO;
    pdebug(info);
  end;
end;

procedure OnInstallStatus(change: LiStatusChange; Data: TLiStatusData;
  job: Pointer); cdecl;
begin
  case change of
    scMessage: TDoAppInstall(job).SendMessageSignal('Message', Data.msg);
    scStepMessage: TDoAppInstall(job).SendMessageSignal('StepMessage', Data.msg);
    scMnProgress: TDoAppInstall(job).SendProgressSignal(
        'MainProgressChange', Data.mnprogress);
    scExProgress: TDoAppInstall(job).SendProgressSignal(
        'ExtraProgressChange', Data.exprogress);
  end;
end;

procedure TDoAppInstall.Execute;
var
  setup: TInstallPack;
  msg: PDBusMessage;
  success: boolean;
begin

  //if Terminated then exit;

  try
    //try
    success := false;
    { This is a fast install. Should never be called directly! }
    setup := TInstallPack.Create;

    li_setup_exec_by_daemon(@setup.RemoteObject, true);
    setup.SetStatusChangeEvent(@OnInstallStatus, self);
    setup.SetUserRequestCall(@InstallUserRequest, self);
    setup.Forced := setup.Forced + overrides + ';norequest';
    //Prevent asking questions: Skip requests and continue (should only be used in this daemon!)

    setup.Initialize(FileName);
    setup.EnableUSource(actUSource);
    setup.StartInstallation;

    setup.Free;

    pinfo('AppInstall job ' + jobID + ' completed.');
    success := true; //Finished without problems
 {except
  on E: Exception do
  begin
   p_error(E.Message);
   success:=false;
  end;
 end;}
  finally
    //Now emit action finished signal:

    // create a signal & check for errors
    msg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
      // object name of the signal
      'org.nlinux.Listaller.Install', // interface name of the signal
      'Finished'); // name of the signal
    bs.AppendBool(success);
    bs.SendMessage(msg);
  end;
  //Terminate;
end;

///////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

{ TDoAppRemove }

function OnMgrUserRequest(mtype: TRqType; msg: PChar; job: Pointer): TRqResult; cdecl;
begin
  Result := rqsOK;
  //The daemon should not ask questions while doing a transaction.
  //All questions which need a reply should be done before or after the daemon call
  if mtype = rqError then
  begin
    //Emit error message and quit job
    TDoAppRemove(job).EmitMessage('Error', msg);
  end
  else
  begin
    perror('Received invalid user request! (Daemon should _never_ ask questions which need a reply.');
    Result := rqsNO;
    pdebug(msg);
  end;
end;

procedure OnMgrStatus(change: LiStatusChange; Data: TLiStatusData; job: Pointer); cdecl;

  procedure sub_sendProgress;
  var
    msg: PDBusMessage;
    sigvalue: integer;
  begin
      sigvalue := Data.mnprogress;
      pdebug(TDoAppRemove(job).DId + '->ProgressChange::' + IntToStr(sigvalue));
      // create a signal & check for errors
      msg := TDoAppRemove(job).bs.CreateNewSignal('/org/nlinux/Listaller/' +
        TDoAppRemove(job).DId, // object name of the signal
        'org.nlinux.Listaller.Manage', // interface name of the signal
        'ProgressChange'); // name of the signal


      TDoAppRemove(job).bs.AppendUInt(sigvalue);
      TDoAppRemove(job).bs.SendMessage(msg);
  end;

begin
  case change of
    scMessage: TDoAppRemove(job).EmitMessage('Message', Data.msg);
    scMnprogress: sub_sendProgress;
  end;
end;

constructor TDoAppRemove.Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
var
  action_id: PGChar;
  subject: PPolkitSubject;
  target: string;

  procedure Error_Terminate;
  begin
    SendReply(false, '');
    remove := true;
 {Terminate;
 Resume();}
  end;

begin
  inherited Create(aMsg, dbusConn);
  jobID := 'manager' + jobID;

  //Read the arguments
  if not bs.InitMessageIter(origMsg) then
  begin
    Error_Terminate;
    exit;
  end;

  appinfo.Name := PChar(bs.ReadMessageParamStr);
  bs.MessageIterNext;
  appinfo.UId := PChar(bs.ReadMessageParamStr);

  pinfo('Removing application called "' + appinfo.Name + '" Job:' + jobID);

  action_id := 'org.nlinux.listaller.remove-application';
  target := bs.GetMessageSender(origMsg);

  subject := polkit_system_bus_name_new(PGChar(target));
  polkit_authority_check_authorization(authority, subject, action_id,
    nil,
    POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
    nil,
    @check_authorization_cb,
    self);



  g_object_unref(subject);
  g_main_loop_run(loop);

  //If not authorized, quit the job
  if allowed = AC_NOT_AUTHORIZED then
  begin
    perror('Not authorized to call this action.');
    SendReply(false, '');
    remove := true;
    //Resume();
    exit;
  end;

  pinfo('New app uninstallation job for ' + bs.GetMessageSender(origMsg) + ' started.');
  try
    mgr := li_mgr_new;
    li_mgr_set_sumode(@mgr, true);
    li_mgr_register_status_call(@mgr, @OnMgrStatus, self);
    li_mgr_register_request_call(@mgr, @OnMgrUserRequest, self);
  except
    Error_Terminate;
    pwarning('Manage job failed.');
    exit;
  end;

  SendReply(true, PChar(jobID));


  //Start work
  //Resume();
  Execute();
end;

destructor TDoAppRemove.Destroy;
begin
  Dec(ManagerWorkers);
 {if Assigned(FatalException) then
  raise FatalException; }

  pdebug('App remove job deleted.');
  inherited;
end;

procedure TDoAppRemove.SendReply(stat: boolean; jID: string);
var
  reply: PDBusMessage;
  auth: PChar = '';
begin
  pinfo('Send reply called');
    //Create a reply from the message
    reply := bs.CreateReturnMessage(origMsg);

    bs.AppendBool(stat);
    auth := '';
    if allowed = AC_AUTHORIZED then
      auth := 'authorized'
    else if allowed = AC_NOT_AUTHORIZED then
        auth := 'blocked';
    bs.AppendStr(auth);
    bs.AppendStr(jID);

    bs.SendMessage(reply);
    bs.FreeMessage(origMsg);
end;

procedure TDoAppRemove.EmitMessage(id: string; param: string);
var
  dmsg: PDBusMessage;
begin
  pdebug(jobID + '->' + id + ':: ' + param);
    // create a signal & check for errors
    dmsg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
      // object name of the signal
      'org.nlinux.Listaller.Manage', // interface name of the signal
      id); // name of the signal
    bs.AppendStr(param);
    bs.SendMessage(dmsg);
end;

procedure TDoAppRemove.Execute;
var
  success: boolean;
  msg: PDBusMessage;
begin
  if remove then
  begin
    //Terminate;
    exit;
  end;

  try
    try
      li_mgr_remove_app(@mgr, appinfo);
      li_mgr_free(@mgr);
      success := true;
    except
      success := false;
    end;


  finally
    //Now emit action finished signal:
    // create a signal & check for errors
    msg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
      // object name of the signal
      'org.nlinux.Listaller.Manage', // interface name of the signal
      'Finished'); // name of the signal
    bs.AppendBool(success);
    bs.SendMessage(msg);

    pinfo('App uninstallation job "' + jobID + '" finished.');
    //Terminate;
  end;
end;

///////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

{ TDoAppUpdate }

function OnUpdaterUserRequest(mtype: TRqType; msg: PChar;
  job: Pointer): TRqResult; cdecl;
begin
  Result := rqsOK;
  //The daemon should not ask questions while doing a transaction.
  //All questions which need a reply should be done before or after the daemon call
  if mtype = rqError then
  begin
    //Emit error message and quit job
    TDoAppUpdate(job).EmitMessage('Error', msg);
  end
  else
  begin
    perror('Received invalid user request! (Daemon should _never_ ask questions which need a reply.');
    Result := rqsNO;
    pdebug(msg);
  end;
end;

procedure OnUpdaterStatus(change: LiStatusChange; Data: TLiStatusData;
  job: Pointer); cdecl;

  procedure sub_sendProgress;
  var
    msg: PDBusMessage;
    sigvalue: integer;
  begin
    sigvalue := Data.mnprogress;
      pdebug(TDoAppUpdate(job).DId + '->ProgressChange::' + IntToStr(sigvalue));
      // create a signal & check for errors
      msg := TDoAppUpdate(job).bs.CreateNewSignal('/org/nlinux/Listaller/' +
        TDoAppUpdate(job).DId, // object name of the signal
        'org.nlinux.Listaller.Manage', // interface name of the signal
        'ProgressChange'); // name of the signal


      TDoAppUpdate(job).bs.AppendUInt(sigvalue);
      TDoAppUpdate(job).bs.SendMessage(msg);
  end;

begin
  case change of
    scMessage: TDoAppUpdate(job).EmitMessage('Message', Data.msg);
    scMnprogress: sub_sendProgress;
  end;
end;

constructor TDoAppUpdate.Create(aMsg: PDBusMessage; dbusConn: PDBusConnection);
var
  action_id: PGChar;
  subject: PPolkitSubject;
  target: string;

  procedure Error_Terminate;
  begin
    SendReply(false, '');
    remove := true;
 {Terminate;
 Resume();}
  end;

begin
  inherited Create(aMsg, dbusConn);
  jobID := 'updater' + jobID;

  //Read the arguments
  if not bs.InitMessageIter(origMsg) then
  begin
    Error_Terminate;
    exit;
  end;

  updID := -1;
  updID := bs.ReadMessageParamInt;
 {bs.MessageIterNext;
 updName:=PChar(bs.ReadMessageParamStr);}

  pinfo('Update su application called (Job:' + jobID + ')');

  action_id := 'org.nlinux.listaller.make-su-update';
  target := bs.GetMessageSender(origMsg);

  subject := polkit_system_bus_name_new(PGChar(target));
  polkit_authority_check_authorization(authority, subject, action_id,
    nil,
    POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
    nil,
    @check_authorization_cb,
    self);



  g_object_unref(subject);
  g_main_loop_run(loop);

  //If not authorized, quit the job
  if allowed = AC_NOT_AUTHORIZED then
  begin
    perror('Not authorized to call this action.');
    SendReply(false, '');
    remove := true;
    //Resume();
    exit;
  end;

  pinfo('New app update job for ' + bs.GetMessageSender(origMsg) + ' started.');
  try
    upd := li_updater_new;
    li_updater_set_sumode(@upd, true);
    li_updater_register_status_call(@upd, @OnUpdaterStatus, self);
    li_updater_register_request_call(@upd, @OnUpdaterUserRequest, self);
  except
    Error_Terminate;
    pwarning('Update job failed.');
    exit;
  end;

  SendReply(true, PChar(jobID));


  //Start work
  //Resume();
  Execute();
end;

destructor TDoAppUpdate.Destroy;
begin
  Dec(ManagerWorkers);
 {if Assigned(FatalException) then
  raise FatalException;}

  pdebug('App update job deleted.');
  inherited;
end;

procedure TDoAppUpdate.SendReply(stat: boolean; jID: string);
var
  reply: PDBusMessage;
  auth: PChar = '';
begin
  pinfo('Send reply called');

  //Create a reply from the message
  reply := bs.CreateReturnMessage(origMsg);

  bs.AppendBool(stat);
  auth := '';
  if allowed = AC_AUTHORIZED then
    auth := 'authorized'
  else if allowed = AC_NOT_AUTHORIZED then
      auth := 'blocked';
  bs.AppendStr(auth);
  bs.AppendStr(jID);

  bs.SendMessage(reply);
  bs.FreeMessage(origMsg);
end;

procedure TDoAppUpdate.EmitMessage(id: string; param: string);
var
  dmsg: PDBusMessage;
begin
  pdebug(jobID + '->' + id + ':: ' + param);
  // create a signal & check for errors
  dmsg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
    // object name of the signal
    'org.nlinux.Listaller.Manage', // interface name of the signal
    id); // name of the signal
  bs.AppendStr(param);
  bs.SendMessage(dmsg);
end;

procedure TDoAppUpdate.Execute;
var
  success: boolean;
  msg: PDBusMessage;
begin
  if remove then
  begin
    //Terminate;
    exit;
  end;

  try
    try
      li_updater_search_updates(@upd);
      li_updater_execute_update(@upd, updID);
      li_updater_free(@upd);
      success := true;
    except
      success := false;
    end;

  finally
    //Now emit action finished signal:
    // create a signal & check for errors
    msg := bs.CreateNewSignal('/org/nlinux/Listaller/' + jobID,
      // object name of the signal
      'org.nlinux.Listaller.Manage', // interface name of the signal
      'Finished'); // name of the signal
    bs.AppendBool(success);
    bs.SendMessage(msg);

    pinfo('App update job "' + jobID + '" finished.');
    //Terminate;
  end;
end;

end.

