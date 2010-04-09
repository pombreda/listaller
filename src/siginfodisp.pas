{ Copyright (C) 2010 Matthias Klumpp

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
//** Display simple warning about the risk of installing untrusted packages
unit siginfodisp;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Dialogs,
  FileUtil, Forms, Graphics, LResources, StdCtrls, SysUtils, trStrings;

type

  { TSigInfoFrm }

  TSigInfoFrm = class(TForm)
    Button1: TButton;
    LblInfo: TLabel;
    LblPkgSigned: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

implementation

{$R siginfodisp.lfm}

{ TSigInfoFrm }

procedure TSigInfoFrm.Button1Click(Sender: TObject);
begin
  Close;
end;

procedure TSigInfoFrm.FormCreate(Sender: TObject);
begin
  LblInfo.Caption := rsSecurityInfo;
  Caption := rsSecurityWarning;
  Button1.Caption := rsIKnowTheRisk;
end;

end.

