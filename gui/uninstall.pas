{ Copyright (C) 2008-2010 Matthias Klumpp

  Authors:
   Matthias Klumpp

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; version 3.
  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.
  You should have received a copy of the GNU General Public License v3
  along with this program.  If not, see <http://www.gnu.org/licenses/>.}
//** Window that shows the progress while uninstalling applications
unit uninstall;

{$mode objfpc}{$H+}

interface

uses
  Forms, LiAppMgr, Buttons, Classes, Dialogs, LCLType, LiUtils, liTypes,
  Process, ComCtrls,
  Controls, ExtCtrls, FileUtil, Graphics, StdCtrls, SysUtils, StrLocale, LResources;

type

  { TRMForm }
  TRMForm = class(TForm)
    BitBtn1: TBitBtn;
    DetailsBtn: TBitBtn;
    Label1: TLabel;
    Memo1: TMemo;
    Process1: TProcess;
    UProgress: TProgressBar;
    procedure BitBtn1Click(Sender: TObject);
    procedure DetailsBtnClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { private declarations }
    FActiv: Boolean;
    astatus: LI_STATUS;
  public
    { public declarations }
    property RmProcStatus: LI_STATUS read astatus write astatus;
  end;

var
  //** Window that shows the progress of the uninstallation
  RMForm: TRMForm;

implementation

{$R uninstall.lfm}

uses manager;

{ TRMForm }

procedure TRMForm.FormShow(Sender: TObject);
begin
  Label1.Caption := rsWaiting;
  self.Caption := StringReplace(rsRMAppC, '%a', '...', [rfReplaceAll]);
end;

procedure LogAdd(s: String);
begin
  writeLn(s);
  RMForm.Memo1.Lines.add(s);
end;

procedure OnRmStatus(status: LI_STATUS; data: LiStatusData;
  user_data: Pointer); cdecl;
begin
  case status of
    LIS_Progress: RMForm.UProgress.Position := data.mnprogress;
  end;
  RMForm.astatus := status;
  Application.ProcessMessages;
end;

function OnRmMessage(mtype: LI_MESSAGE; const text: PChar;
                            user_data: Pointer): LI_REQUEST_RES; cdecl;
begin
  Result := LIRQS_OK;
  if mtype = LIM_Info then
  LogAdd(text);
end;

procedure TRMForm.FormActivate(Sender: TObject);
begin
  if FActiv then
  begin
    FActiv := false;
    if MnFrm.uApp.AppId <> '' then
    begin
      Label1.Caption := StrSubst(rsRMAppC, '%a', MnFrm.uApp.Name);
      Caption := StrSubst(rsRMAppC, '%a', '...');

      if Application.MessageBox(PChar(
        StringReplace(rsRealUninstQ, '%a', MnFrm.uApp.Name, [rfReplaceAll])),
        'Uninstall?', MB_YESNO) = idYes then
      begin
        UProgress.Position := 0;
        li_mgr_register_status_call(@MnFrm.amgr, @OnRmStatus, nil);
        astatus := LIS_None;
        BitBtn1.Enabled := false;
        Application.ProcessMessages;
        li_mgr_remove_app(@MnFrm.amgr, MnFrm.uApp);
        while (astatus <> LIS_Finished) and (astatus <> LIS_Failed) and (astatus <> LIS_None) do
        begin
          sleep(1);
          Application.ProcessMessages;
        end;
        li_mgr_register_message_call(@MnFrm.amgr, @manager.OnMgrMessage, nil);

        //!!!: Misterious crash appears when executing this code.
        //MnFrm.ReloadAppList(true);
        BitBtn1.Enabled := true;
      end
      else
        Close;

    end
    else
    begin
      ShowMessage('Error in selection.');
      Close;
      exit;
    end;
  end;
end;

procedure TRMForm.BitBtn1Click(Sender: TObject);
begin
  Close;
end;

procedure TRMForm.DetailsBtnClick(Sender: TObject);
begin
  if Memo1.Visible then
  begin
    Memo1.Visible := false;
    Width := 456;
    Height := 134;
    DetailsBtn.Caption := rsDetails + ' >> ';
  end
  else
  begin
    Memo1.Visible := true;
    Width := 456;
    Height := 294;
    DetailsBtn.Caption := rsDetails + ' << ';
  end;
end;

procedure TRMForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FActiv := true;
end;

procedure TRMForm.FormCreate(Sender: TObject);
begin
  FActiv := true;
  DetailsBtnClick(Sender);
end;

end.

