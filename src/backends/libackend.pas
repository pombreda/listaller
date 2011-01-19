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
//** Defines backend interface class
unit libackend;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LiTypes, LiStatusObj, LiApp;

type
  TLiBackend = class(TLiStatusObject)
  private
  protected
    sumode: Boolean;
  public
    function Initialize(app: TLiAppItem): Boolean; virtual; abstract;
    function CanBeUsed: Boolean; virtual; abstract;
    function Run: Boolean; virtual; abstract;
    property RootMode: Boolean read sumode write sumode;
  end;

implementation

{ TLiBackend }

(* -o- *)

end.

