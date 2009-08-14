{ uninstall.pas
  Copyright (C) Listaller Project 2008-2009

  uninstall.pas is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  uninstall.pas is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.}
//** Window that shows the progress while uninstalling applications
unit uninstall;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, ComCtrls,
  StdCtrls, IniFiles, LCLType, LiCommon, Buttons, ExtCtrls, process,
  trstrings, FileUtil, distri, appman, globdef, PackageKit, LEntries;

type

  { TRMForm }
  TRMForm = class(TForm)
    BitBtn1: TBitBtn;
    DetailsBtn: TBitBtn;
    GetOutPutTimer: TIdleTimer;
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
    procedure GetOutPutTimerTimer(Sender: TObject);
  private
    { private declarations }
    FActiv: Boolean;
  public
    { public declarations }
  end; 

var
 //** Window that shows the progress of the uninstallation
  RMForm: TRMForm;

implementation

uses manager;

{ TRMForm }

procedure TRMForm.FormShow(Sender: TObject);
begin
 Label1.Caption:=rsWaiting;
 Caption:=StringReplace(rsRMAppC,'%a','...',[rfReplaceAll])
end;

procedure TRMForm.GetOutPutTimerTimer(Sender: TObject);
  var
  NoMoreOutput: boolean;

  procedure DoStuffForProcess(Process: TProcess;
    OutputMemo: TMemo);
  var
    Buffer: string;
    BytesAvailable: DWord;
    BytesRead:LongInt;
  begin

    if Process.Running then
    begin

      BytesAvailable := Process.Output.NumBytesAvailable;
      BytesRead := 0;
      while BytesAvailable>0 do
       begin
        SetLength(Buffer, BytesAvailable);
        BytesRead := Process.OutPut.Read(Buffer[1], BytesAvailable);
        OutputMemo.Text := OutputMemo.Text + copy(Buffer,1, BytesRead);
        Application.ProcessMessages;
        BytesAvailable := Process.OutPut.NumBytesAvailable;
        NoMoreOutput := false;
      end;
      if BytesRead>0 then
        OutputMemo.SelStart := Length(OutputMemo.Text);
    end;

  end;
begin
  repeat
    NoMoreOutput := true;
    Application.ProcessMessages;

    DoStuffForProcess(Process1, Memo1);
  until noMoreOutput;
if Process1.ExitStatus>0 then begin
    GetOutputTimer.Enabled:=false;
    ShowMessage(rsRMError);
    Memo1.Lines.SaveTofile(ConfigDir+'uninstall.log');
    halt;
    exit;
  end;
end;

function UProgressChange(pos: LongInt): Boolean;cdecl;
begin
 RMForm.UProgress.Position:=pos;
 Application.ProcessMessages;
end;

procedure LogAdd(s: String);
begin
writeLn(s);
RMForm.Memo1.Lines.add(s);
end;

function OnRmMessage(msg: String;imp: TMType): Boolean;cdecl;
begin
 if imp=mtInfo then LogAdd(msg);
 if imp=mtWarning then ShowMessage(msg);
 Application.ProcessMessages;
end;

procedure TRMForm.FormActivate(Sender: TObject);
begin
if FActiv then
begin
FActiv:=false;
if MnFrm.uApp.uID<>'' then
begin
if Application.MessageBox(PChar(StringReplace(rsRealUninstQ,'%a',MnFrm.uApp.Name,[rfReplaceAll])),'Uninstall?',MB_YESNO)=IDYES then
begin
 register_message_call(@OnRmMessage);
 register_progress_call(@UProgressChange);
  remove_application(MnFrm.uApp);
 register_message_call(@manager.OnMessage);
end;
end else
begin
 ShowMessage('Error in selection.');
 close;
 exit;
end;
 load_applications(gtALL);
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
   Memo1.Visible:=false;
   Width:=456;
   Height:=134;
   DetailsBtn.Caption:=rsDetails+' -> ';
  end else
  begin
   Memo1.Visible:=true;
   Width:=456;
   Height:=294;
   DetailsBtn.Caption:=rsDetails+' <- ';
  end;
end;

procedure TRMForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FActiv:=true;
end;

procedure TRMForm.FormCreate(Sender: TObject);
begin
  FActiv:=true;
  DetailsBtnClick(Sender);
end;

initialization
  {$I uninstall.lrs}

end.

