{ distri.pas
  Copyright (C) Listaller Project 2008-2009

  distri.pas is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  distri.pas is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
}
//** Unit to research information about the current distribution (LSB-conform)
unit distri;

{$mode delphi}{$H+}

interface

uses SysUtils, Classes, Process, BaseUnix, pwd, Dialogs;

type
//** Contains information about the current Linux distribution
TDistroInfo = record
//** Name of the distro
DName: String;
//** Release number
Release: String;
//** Package management system
PackageSystem: String;
//
InstallCom:   String;
InstallDBCom: String;
DoRecheck:    Boolean;
//
//** The desktop environment (KDE/GNOME)
Desktop: String;
end;

//** Get the distro-infos
function GetDistro: TDistroInfo;
{** Check if user is root
 @returns If user is root (Bool)}
function IsRoot: Boolean;

implementation

function IsCommandRunning(cmd:String):Boolean;
var t:TProcess;
s:TStringList;
begin
 Result:=false;
 t:=tprocess.create(nil);
 t.CommandLine:='ps -A'+cmd;
 t.Options:=[poUsePipes,poWaitonexit];
 try
  t.Execute;
  s:=tstringlist.Create;
  try
   s.LoadFromStream(t.Output);
   Result:=Pos(cmd,s.Text)>0;
  finally
  s.free;
  end;
 finally
 t.Free;
 end;
end;

function IsRoot: Boolean;
var p : PPasswd;
begin
p:=fpgetpwuid(fpgetuid);
Result:=false;
 if assigned(p) then
    begin
       if p.pw_name<>'root' then
         Result:=false
        else  Result:=true;
     end else
   ShowMessage('Internal error');
end;

function GetDistro: TDistroInfo;
var uv: TStringList;i: Integer;
begin
//Check which Distribution is used
Result.DName:='';
uv:=TStringList.Create;
if FileExists('/etc/lsb-release') then
uv.LoadFromFile('/etc/lsb-release');
Result.InstallCom:='%';

for i:=0 to uv.Count-1 do begin
if pos('UBUNTU',UpperCase(uv[i]))>0 then
Result.DName:='Ubuntu';

if pos('SUSE',UpperCase(uv[i]))>0 then
Result.DName:='SuSE';;

if pos('DEBIAN',UpperCase(uv[i]))>0 then
Result.DName:='Debian';

if pos('MANDRIVA',UpperCase(uv[i]))>0 then
Result.DName:='Mandriva';

if pos('PCLINUXOS',UpperCase(uv[i]))>0 then
Result.DName:='PCLinuxOS';

if pos('XANDROS',UpperCase(uv[i]))>0 then
Result.DName:='Xandros';

if pos('FEDORA',UpperCase(uv[i]))>0 then
Result.DName:='Fedora';

end;
if Result.DName='' then begin
uv.LoadFromFile('/proc/version');
for i:=0 to uv.Count-1 do begin
if pos('UBUNTU',UpperCase(uv[i]))>0 then
Result.DName:='Ubuntu';

if pos('SUSE',UpperCase(uv[i]))>0 then
Result.DName:='openSUSE';

if pos('DEBIAN',UpperCase(uv[i]))>0 then
Result.DName:='Debian';

if pos('MANDRIVA',UpperCase(uv[i]))>0 then
Result.DName:='Mandriva';

if pos('PCLINUXOS',UpperCase(uv[i]))>0 then
Result.DName:='PCLinuxOS';

if pos('XANDROS',UpperCase(uv[i]))>0 then
Result.DName:='Xandros';

if pos('FEDORA',UpperCase(uv[i]))>0 then
Result.DName:='Fedora';

 end;
end;
if Result.DName='' then begin
uv.LoadFromFile('/etc/issure');
for i:=0 to uv.Count-1 do begin
if pos('UBUNTU',UpperCase(uv[i]))>0 then
Result.DName:='Ubuntu';

if pos('SUSE',UpperCase(uv[i]))>0 then
Result.DName:='openSUSE';

if pos('DEBIAN',UpperCase(uv[i]))>0 then
Result.DName:='Debian';

if pos('MANDRIVA',UpperCase(uv[i]))>0 then
Result.DName:='Mandriva';

if pos('PCLINUXOS',UpperCase(uv[i]))>0 then
Result.DName:='PCLinuxOS';

if pos('XANDROS',UpperCase(uv[i]))>0 then
Result.DName:='Xandros';

if pos('FEDORA',UpperCase(uv[i]))>0 then
Result.DName:='Fedora';

end;
 
end;
if Result.DName='Ubuntu' then begin
Result.PackageSystem:='DEB';
Result.InstallCom:='gdebi -n -q';
Result.InstallDBCom:='apt-get --assume-yes install';
Result.DoRecheck:=false;
end;

if Result.DName='openSUSE' then begin
Result.PackageSystem:='RPM';
Result.InstallCom:='/sbin/yast2 --install';
Result.InstallDBCom:='zypper install';
Result.DoRecheck:=true;
end;

if Result.DName='Debian' then begin
Result.PackageSystem:='DEB';
Result.InstallCom:='gdebi -n -q';
Result.InstallDBCom:='apt-get --assume-yes install';
Result.DoRecheck:=false;
end;

if Result.DName='Mandriva' then begin
Result.PackageSystem:='RPM';
Result.InstallCom:='urpmi';
Result.InstallDBCom:='urpmi';
Result.DoRecheck:=false;
end;

if Result.DName='PCLinuxOS' then begin
Result.PackageSystem:='RPM';
Result.InstallCom:='apt-get -yes install';
Result.InstallDBCom:='apt-get -yes install';
Result.DoRecheck:=false;
end;

if Result.DName='Xandros' then begin
Result.PackageSystem:='DEB';
Result.InstallCom:='gdebi -n -q';
Result.InstallDBCom:='apt-get --assume-yes install';
Result.DoRecheck:=false;
end;

if Result.DName='Fedora' then begin
Result.PackageSystem:='DEB';
Result.InstallCom:='yum localinstall';
Result.InstallDBCom:='yum -y install';
Result.DoRecheck:=false;
end;

if FileExists('/etc/lsb-release') then begin
uv.LoadFromFile('/etc/lsb-release');
for i:=0 to uv.Count-1 do
if pos('DISTRIB_RELEASE=',uv[i])>0 then break;
Result.Release:=copy(uv[i],pos('=',uv[i])+1,length(uv[i]));
end;

if (pos('kde',LowerCase(GetEnvironmentVariable('GDMSESSION')))>0)or (pos('kde',LowerCase(GetEnvironmentVariable('DESKTOP_SESSION')))>0)
or (GetEnvironmentVariable('KDE_FULL_SESSION')='true') then
Result.Desktop:='KDE' else
Result.Desktop:='GNOME'; //Gnome/Xfce/E17 ...

uv.Free;
end;

end.
