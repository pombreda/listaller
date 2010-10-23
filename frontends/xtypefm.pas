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
//** This unit provides an form to choose between program runlevels (root / not as root / in app-testmode)
unit xtypefm;

{$mode objfpc}{$H+}

interface

uses
  Forms, Buttons, Classes, Dialogs, LCLType, LiTypes, Process, ComCtrls,
  Controls, ExtCtrls, Graphics, StdCtrls, SysUtils, StrLocale, IconLoader, LResources,
  LiBasic, Distri;

type

  { TIMdFrm }

  TIMdFrm = class(TForm)
    btnTest: TBitBtn;
    btnHome: TBitBtn;
    btnInstallAll: TBitBtn;
    PkWarnImg: TImage;
    Image2: TImage;
    Label1: TLabel;
    Label2: TLabel;
    PkILabel: TLabel;
    LoadProgress: TProgressBar;
    procedure btnHomeClick(Sender: TObject);
    procedure btnInstallAllClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { private declarations }
    FShow: boolean;
    FTestMode: boolean;
    sig: PkgSignatureState;
  public
    { public declarations }
    procedure EnterLoadingState;
    procedure LeaveLoadingState;

    procedure SetSigState(sigstate: PkgSignatureState);
    property IsTestMode: boolean read FTestMode;
  end;

// Publish procedure so it can be used by igobase
//** Receive progress change signal on package initialization
procedure PkgInitProgressChange(change: LiStatusChange; Data: LiStatusData;
  user_data: Pointer); cdecl;

var
  //** True if superuser mode is enabled
  Superuser: boolean = False;

implementation

{$R xtypefm.lfm}

uses SigInfoDisp;

{ TIMdFrm }

procedure TIMdFrm.FormCreate(Sender: TObject);
begin
  FShow := False;
  FTestMode := False;
  //Set translation strings
  Caption := rsSelInstMode;
  PkILabel.Caption := rsSpkWarning;
  btnInstallAll.Caption := rsInstallEveryone;
  btnTest.Caption := rsTestApp;
  btnHome.Caption := rsInstallHome;
  Label1.Caption := rsWantToDoQ;
  PkILabel.Caption := rsSpkWarning;
  LoadProgress.Visible := False;

  //Show development version warning
  if (pos('exp', li_version) > 0) or (pos('dev', li_version) > 0) then
  begin
    Label2.Caption := rsDevVersion;
    Label2.Visible := True;
    Image2.Visible := True;
    LoadStockPixmap(STOCK_DIALOG_WARNING, ICON_SIZE_BUTTON, Image2.Picture.Bitmap);
  end
  else
  begin
    Constraints.MinHeight := Constraints.MinHeight - Image2.Height;
    Height := Height - Image2.Height;
  end;
end;

procedure TIMdFrm.FormShow(Sender: TObject);
begin
  if PkWarnImg.Visible then
  begin
    LoadStockPixmap(STOCK_DIALOG_WARNING, ICON_SIZE_MENU,
      PkWarnImg.Picture.Bitmap);
    PkiLabel.Visible := True;
  end;
  //Gap between buttons: 150
  self.ClientWidth := ClientWidth +
    (btnInstallAll.Width - btnInstallAll.Constraints.MinWidth) +
    (btnTest.Width - btnTest.Constraints.MinWidth) +
    (btnHome.Width - btnHome.Constraints.MinWidth) - 150;
  Application.ProcessMessages;
end;

procedure PkgInitProgressChange(change: LiStatusChange; Data: LiStatusData;
  user_data: Pointer); cdecl;
begin
  if change = scExProgress then
  begin
    TIMdFrm(user_data).LoadProgress.Position := Data.exprogress;
  end;
  Application.ProcessMessages;
end;

procedure TIMdFrm.btnInstallAllClick(Sender: TObject);
var
  DInfo: TDistroInfo;
begin
  Superuser := True;
  btnHome.Tag := 2;
  Close;

{DInfo:=GetDistro;
if not IsRoot then begin
if FileExists(paramstr(1)) then
 ExecuteAsRoot(Application.ExeName+' '+paramstr(1), rsRootPassQAppEveryone,
   GetDataFile('graphics/mime-ipk.png'))
 else
 ExecuteAsRoot(Application.ExeName, rsRootPassAdvancedPriv, '/usr/share/'
   +'pixmaps/listaller.png');

 self.Free;
 halt(0); //Terminate program
 exit;
  end; }
end;

procedure TIMdFrm.btnTestClick(Sender: TObject);
begin
  FTestmode := True;
  btnHome.Tag := 2;
  Close;
end;

procedure TIMdFrm.FormActivate(Sender: TObject);
var
  secInfo: TSigInfoFrm;
begin
  Refresh;

  if FShow then
  begin
    FShow := False;
    if (sig = psNone) or (sig = psUntrusted) then
    begin
      secInfo := TSigInfoFrm.Create(nil);
      if sig = psNone then
        secInfo.LblPkgSigned.Caption := rsPkgUnsigned
      else
        secInfo.LblPkgSigned.Caption := rsPkgUntrusted;

      secInfo.ShowModal;
      secInfo.Free;
    end;
  end;
end;

procedure TIMdFrm.btnHomeClick(Sender: TObject);
begin
  btnHome.Tag := 2;
  Close;
end;

procedure TIMdFrm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if btnHome.Tag <= 0 then
  begin
    Application.Terminate;
    halt(0);
  end;
end;

procedure TIMdFrm.EnterLoadingState;
begin
  PkILabel.Visible := False;
  PkWarnImg.Visible := False;
  LoadProgress.Visible := True;
  btnInstallAll.Enabled := False;
  btnTest.Enabled := False;
  btnHome.Enabled := False;
  Show;
end;

procedure TIMdFrm.LeaveLoadingState;
begin
  PkILabel.Visible := True;
  PkWarnImg.Visible := True;
  LoadProgress.Visible := False;
  btnInstallAll.Enabled := True;
  btnTest.Enabled := True;
  btnHome.Enabled := True;
  Hide;
end;

procedure TIMdFrm.SetSigState(sigstate: PkgSignatureState);
begin
  FShow := True;
  sig := sigstate;
end;

end.

