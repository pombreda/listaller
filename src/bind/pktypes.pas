{ Copyright (C) 2010 Matthias Klumpp

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
//** Bind elementary PackageKit types and provide TPackageList structure
unit pktypes;

{$mode objfpc}{$H+}

interface

uses
  glib2, Classes, Contnrs;

const
  pklib2 = 'libpackagekit-glib2.so';

type
  // Define dummy pointers for PK
  PPkProgress = Pointer;
  PPkPackage = Pointer;
  PPkClient = Pointer;
  PPkResults = Pointer;
  PPkError = Pointer;
  PPkDetails = Pointer;
  //
  PPkUpdateDetail = Pointer;
  PPkCategory = Pointer;
  PPkDistroUpgrade = Pointer;
  PPkRequireRestart = Pointer;
  PPkTransactionPast = Pointer;
  PPkFiles = Pointer;
  PPkRepoSignatureRequired = Pointer;
  PPkEulaRequired = Pointer;
  PPkMediaChangeRequired = Pointer;
  PPkRepoDetail = Pointer;
  PPkMessage = Pointer;

  {$I pkenum.inc}
  {$I pkprogress.inc}

type
  TPkPackage = class
    Description: String;
    License: String;
    Summary: String;
    Url: String;
    Size: int64;
    Group: Integer;
    PackageId: String;
    Status: PkInfoEnum;

    constructor Create;
    constructor Create(id: String);
  end;

  TPackageList = class(TObjectList)
  protected
    function getItem(Index: Integer): TPkPackage; virtual;
    procedure setItem(Index: Integer; Objekt: TPkPackage); virtual;
  public
    function Add(Objekt: TPkPackage): Integer; virtual;
    function Remove(Objekt: TPkPackage): Integer; virtual;
    function IndexOf(Objekt: TPkPackage): Integer; virtual;
    procedure Insert(Index: Integer; Objekt: TPkPackage); virtual;
    function First: TPkPackage; virtual;
    function Last: TPkPackage; virtual;
    property Items[index: Integer]: TPkPackage read getItem write setItem; default;
  end;

implementation

constructor TPkPackage.Create;
begin
  inherited;
end;

constructor TPkPackage.Create(id: String);
begin
  inherited Create;
  PackageId := id;
end;

{ TPackageList }

function TPackageList.getItem(Index: Integer): TPkPackage;
begin
  Result := TPkPackage(inherited Items[Index]);
end;

procedure TPackageList.setItem(Index: Integer; Objekt: TPkPackage);
begin
  inherited Items[Index] := Objekt;
end;

function TPackageList.Add(Objekt: TPkPackage): Integer;
begin
  Result := inherited Add(Objekt);
end;

function TPackageList.First: TPkPackage;
begin
  Result := TPkPackage(inherited First);
end;

function TPackageList.IndexOf(Objekt: TPkPackage): Integer;
begin
  Result := inherited IndexOf(Objekt);
end;

procedure TPackageList.Insert(Index: Integer; Objekt: TPkPackage);
begin
  inherited Insert(Index, Objekt);
end;

function TPackageList.Last: TPkPackage;
begin
  Result := TPkPackage(inherited Last());
end;

function TPackageList.Remove(Objekt: TPkPackage): Integer;
begin
  Result := inherited Remove(Objekt);
end;

end.

