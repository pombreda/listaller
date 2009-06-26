{ manager.pas
  Copyright (C) Listaller Project 2008-2009

  manager.pas is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  manager.pas is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License v3
  along with this program.  If not, see <http://www.gnu.org/licenses/>}
//** This unit contains the code to manage installed packages
unit manager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, ComCtrls,
  Inifiles, StdCtrls, process, LCLType, Buttons, ExtCtrls, distri, LEntries,
  uninstall, trstrings, FileUtil, CheckLst, xtypefm, ipkhandle, gifanimator,
  LiCommon, PackageKit, Contnrs, sqlite3ds, db, aboutbox, GetText, Spin;

type

  { TMnFrm }

  TMnFrm = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    AboutBtn: TButton;
    BitBtn5: TBitBtn;
    BitBtn6: TBitBtn;
    ThrobberBox: TPaintBox;
    RmUpdSrcBtn: TBitBtn;
    UpdCheckBtn: TBitBtn;
    CatButton: TSpeedButton;
    CBox: TComboBox;
    CbShowPkMon: TCheckBox;
    UListBox: TCheckListBox;
    UsILabel: TLabel;
    PageControl1: TPageControl;
    SysRepoSheet: TTabSheet;
    UpdRepoSheet: TTabSheet;
    WarnDistCb: TCheckBox;
    AutoDepLdCb: TCheckBox;
    EnableProxyCb: TCheckBox;
    Edit1: TEdit;
    edtFTPProxy: TLabeledEdit;
    edtPasswd: TLabeledEdit;
    edtUsername: TLabeledEdit;
    FilterEdt: TEdit;
    GroupBox1: TGroupBox;
    Image1: TImage;
    ImageList1: TImageList;
    InstallButton: TSpeedButton;
    InstAppButton: TSpeedButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Notebook1: TNotebook;
    OpenDialog1: TOpenDialog;
    MBar: TProgressBar;
    LeftBar: TPanel;
    InstalledAppsPage: TPage;
    CatalogPage: TPage;
    SpinEdit1: TSpinEdit;
    SpinEdit2: TSpinEdit;
    RepoPage: TPage;
    ConfigPage: TPage;
    SettingsButton: TSpeedButton;
    RepoButton: TSpeedButton;
    SWBox: TScrollBox;
    Process1: TProcess;
    StatusBar1: TStatusBar;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure BitBtn4Click(Sender: TObject);
    procedure BitBtn6Click(Sender: TObject);
    procedure btnInstallClick(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnCatClick(Sender: TObject);
    procedure AboutBtnClick(Sender: TObject);
    procedure CBoxChange(Sender: TObject);
    procedure AutoDepLdCbChange(Sender: TObject);
    procedure CbShowPkMonChange(Sender: TObject);
    procedure EnableProxyCbChange(Sender: TObject);
    procedure RmUpdSrcBtnClick(Sender: TObject);
    procedure UListBoxClick(Sender: TObject);
    procedure UpdCheckBtnClick(Sender: TObject);
    procedure WarnDistCbChange(Sender: TObject);
    procedure FilterEdtEnter(Sender: TObject);
    procedure FilterEdtExit(Sender: TObject);
    procedure FilterEdtKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure InstAppButtonClick(Sender: TObject);
    procedure RepoButtonClick(Sender: TObject);
  private
    { private declarations }
    blst: TStringList;
    procedure UninstallClick(Sender: TObject);
  public
    { public declarations }
    DInfo: TDistroInfo;
    //** Visual package list
    AList: TObjectList;
    //** Current id of package that should be uninstalled
    uID: Integer;
    //**
    dsApp: TSQLite3Dataset;
    {** Process .desktop-file and add info to list @param fname Name of the .desktop file
      @param tp Category name}
    procedure ProcessDesktopFile(fname: String; tp: String);
    //** Load software list entries
    procedure LoadEntries;
  end;

  //** Fill ImageList with category icons
  procedure FillImageList(IList: TImageList);

var
 //** Main formular instance
  MnFrm:   TMnFrm;
 //** List of installed application names
  instLst: TStringList;

implementation

uses pkgconvertdisp, swcatalog;

{ TListEntry }

procedure TMnFrm.UninstallClick(Sender: TObject);
begin
uID:=(Sender as TBitBtn).Tag;
RMForm.ShowModal;
dsApp.Active:=true;
end;

{ TMnFrm }

procedure RemoveDuplicates(s: TStrings);
var
  iLow, iHigh: integer;
begin
  for iLow := 0 to s.Count - 2 do
    for iHigh := Pred(s.Count) downto Succ(iLow) do
      if s[iLow] = s[iHigh] then
        s.Delete(iHigh);
end;

procedure TMnFrm.ProcessDesktopFile(fname: String; tp: String);
var d: TIniFile;entry: TListEntry;dt: TMOFile;lp: String;

//Translate string if possible/necessary
function ldt(s: String): String;
var h: String;
begin
 h:=s;
 try
 if dt<>nil then
 begin
  h:=dt.Translate(s);
  if h='' then h:=s;
 end;
 finally
  Result:=h;
 end;
 Result:=s;
end;

begin
       d:=TIniFile.Create(fname);
       StatusBar1.Panels[0].Text:=strLoading+'  '+ExtractFileName(fname);
       Application.ProcessMessages;

       if (not IsRoot)and(d.ReadString('Desktop Entry','Exec','')[1]<>'/')
       then
       else
       if (LowerCase(d.ReadString('Desktop Entry','NoDisplay','false'))<>'true')
       and (pos('yast',LowerCase(fname))<=0)
       and(LowerCase(d.ReadString('Desktop Entry','Hidden','false'))<>'true')
       and(not IsInList(d.ReadString('Desktop Entry','Name',''),blst))
       and((pos(tp,LowerCase(d.ReadString('Desktop Entry','Categories','')))>0)or(tp='all'))
      // and(pos('system',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(pos('core',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(pos('.hidden',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
      // and(pos('base',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(pos('wine',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(pos('wine',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(d.ReadString('Desktop Entry','X-KDE-ParentApp','#')='#')
       and(pos('screensaver',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(pos('setting',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
      // and(pos('utility',LowerCase(d.ReadString('Desktop Entry','Categories','')))<=0)
       and(d.ReadString('Desktop Entry','OnlyShowIn','')='')
       and(d.ReadString('Desktop Entry','X-AllowRemove','true')='true')then
       begin
       AList.Add(TListEntry.Create(MnFrm));
       entry:=TListEntry(AList.Items[AList.Count-1]);
       entry.UnButton.OnClick:=@UnInstallClick;
       entry.Parent:=SWBox;
       entry.UnButton.Tag:=AList.Count-1;

       //Check for Autopackage.org installation
       if pos('apkg-remove',LowerCase(d.ReadString('Desktop Entry','Actions','')))>0 then
       entry.srID:='!'+d.ReadString('Desktop Action Apkg-Remove','Exec','')
       else
       entry.srID:=fname;

       if d.ReadString('Desktop Entry','X-Ubuntu-Gettext-Domain','')<>'' then
       begin
       try
       lp:='/usr/share/locale-langpack/'+GetLangID+'/LC_MESSAGES/'+
                         d.ReadString('Desktop Entry','X-Ubuntu-Gettext-Domain','app-install-data')+'.mo';
       if not FileExists(lp) then
        lp:='/usr/share/locale/de/'+GetLangID+'/LC_MESSAGES/'
            +d.ReadString('Desktop Entry','X-Ubuntu-Gettext-Domain','app-install-data')+'.mo';
       if FileExists(lp) then
        dt:=TMOFile.Create(lp);
       finally
       end;

       end;

       with entry do
       begin
       if d.ReadString('Desktop Entry','Name['+GetLangID+']','') <> '' then
        AppName:=d.ReadString('Desktop Entry','Name['+GetLangID+']','<error>')
       else
        AppName:=ldt(d.ReadString('Desktop Entry','Name','<error>'));

         AppName:=StringReplace(AppName,'&','&&',[rfReplaceAll]);

         instLst.Add(Lowercase(d.ReadString('Desktop Entry','Name','<error>')));

        if d.ReadString('Desktop Entry','Comment['+GetLangID+']','')<>'' then
         AppDesc:=d.ReadString('Desktop Entry','Comment['+GetLangID+']','')
        else
         AppDesc:=ldt(d.ReadString('Desktop Entry','Comment',''));

        AppMn:=strAuthor+': '+d.ReadString('Desktop Entry','X-Publisher','<error>');
        if AppMn=strAuthor+': '+'<error>' then
        AppMn:='';
        AppVersion:='';
        if d.ReadString('Desktop Entry','X-AppVersion','')<>'' then
        AppVersion:=strVersion+': '+d.ReadString('Desktop Entry','X-AppVersion','');

        //Load the icons
        if (LowerCase(ExtractFileExt(d.ReadString('Desktop Entry','Icon','')))<>'.tiff') then
        begin
        try
        if (d.ReadString('Desktop Entry','Icon','')<>'')
        and(d.ReadString('Desktop Entry','Icon','')[1]<>'/') then
        begin
        if FileExists('/usr/share/icons/hicolor/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png') then
            SetImage('/usr/share/icons/hicolor/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png') else
        if FileExists('/usr/share/icons/hicolor/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')) then
            SetImage('/usr/share/icons/hicolor/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')) else
        if FileExists('/usr/share/icons/hicolor/48x48/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png') then
            SetImage('/usr/share/icons/hicolor/48x48/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png') else
        if FileExists('/usr/share/icons/hicolor/48x48/apps/'+d.ReadString('Desktop Entry','Icon','')) then
            SetImage('/usr/share/icons/hicolor/48x48/apps/'+d.ReadString('Desktop Entry','Icon',''));
        //
        if FileExists('/usr/share/pixmaps/'+ChangeFileExt(d.ReadString('Desktop Entry','Icon',''),'')+'.xpm')
        and (ExtractFileExt(d.ReadString('Desktop Entry','Icon',''))='.xpm')then
            SetImage('/usr/share/pixmaps/'+ChangeFileExt(d.ReadString('Desktop Entry','Icon',''),'')+'.xpm')
        else if FileExists('/usr/share/pixmaps/'+d.ReadString('Desktop Entry','Icon','')+'.xpm') then
             SetImage('/usr/share/pixmaps/'+d.ReadString('Desktop Entry','Icon','')+'.xpm');
        if (FileExists('/usr/share/pixmaps/'+ChangeFileExt(d.ReadString('Desktop Entry','Icon',''),'')+'.png'))
        and (ExtractFileExt(d.ReadString('Desktop Entry','Icon',''))='.png')then
            SetImage('/usr/share/pixmaps/'+ChangeFileExt(d.ReadString('Desktop Entry','Icon',''),'')+'.png')
        else if FileExists('/usr/share/pixmaps/'+d.ReadString('Desktop Entry','Icon','')+'.png') then
                SetImage('/usr/share/pixmaps/'+d.ReadString('Desktop Entry','Icon','')+'.png');

        { This code is EXPERIMENTAL!}
        //Load KDE4 Icons
          //GetEnvironmentVariable('KDEDIRS')

        if FileExists('/usr/share/icons/default.kde/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png') then
                SetImage('/usr/share/icons/default.kde/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png')
        else
        if FileExists('/usr/lib/kde4/share/icons/hicolor/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png') then
                SetImage('/usr/lib/kde4/share/icons/hicolor/64x64/apps/'+d.ReadString('Desktop Entry','Icon','')+'.png');
        end else
        begin
         if (FileExists(d.ReadString('Desktop Entry','Icon','')))
         and(LowerCase(ExtractFileExt(d.ReadString('Desktop Entry','Icon','')))<>'.svg') then
            SetImage(d.ReadString('Desktop Entry','Icon',''));
        end;
        //If icon loading failed
        except writeLn('ERROR: Unable to load icon!');ShowMessage(StringReplace(strCannotLoadIcon,'%a',AppName,[rfReplaceAll]));
        end;
       end;
        Application.ProcessMessages;
        end;

        if Assigned(dt) then dt.Free;

        end;
       d.Free;
end;

procedure TMnFrm.LoadEntries;
var ini: TIniFile;tmp,xtmp: TStringList;i,j,k: Integer;p,n: String;tp: String;
    gif: TGifThread;entry: TListEntry;
begin
j:=0;

MBar.Visible:=true;

AList.Clear;

LeftBar.Enabled:=false;

StatusBar1.Panels[0].Text:=strLoading;

//Create GIFThread for Throbber animation
gif:=TGifThread.Create(true);
gif.FileName:=GetDataFile('graphics/throbber.gif');
ThrobberBox.Width:=gif.Width;
ThrobberBox.Height:=gif.Height;
ThrobberBox.Top:=(InstalledAppsPage.Height div 2)-(ThrobberBox.Height div 2);
ThrobberBox.Left:=(InstalledAppsPage.Width div 2)-(ThrobberBox.Width div 2);
gif.Initialize(ThrobberBox.Canvas);

SwBox.Visible:=false;
if blst.Count<4 then
begin
blst.Clear;
blst.LoadFromFile('/etc/lipa/blacklist');
blst.Delete(0);
end;

//Set original names
case CBox.Itemindex of
0: tp:='all';
1: tp:='education';
2: tp:='office';
3: tp:='development';
4: tp:='graphic';
5: tp:='network';
6: tp:='games';
7: tp:='system';
8: tp:='multimedia';
9: tp:='additional';
10: tp:='other';
end;

if not DirectoryExists(RegDir) then
begin
CreateDir(ExtractFilePath(RegDir));
CreateDir(RegDir);
end;

dsApp.SQL:='SELECT * FROM AppInfo';
dsApp.Open;
dsApp.Filtered:=true;
dsApp.First;
while not dsApp.EOF do
begin
 if (LowerCase(dsApp.FieldByName('AGroup').AsString)=tp)
 or (tp='all') then
 begin
 AList.Add(TListEntry.Create(MnFrm));

 entry:=TListEntry(AList.Items[AList.Count-1]);
 entry.UnButton.OnClick:=@UnInstallClick;
 entry.Parent:=SWBox;
 entry.aId:=dsApp.RecNo;
 entry.UnButton.Tag:=AList.Count-1;

 entry.AppName:=dsApp.FieldByName('Name').AsString;

 blst.Add(entry.AppName);
 entry.srID:=dsApp.FieldByName('ID').AsString;

 entry.AppVersion:=strVersion+': '+dsApp.FieldByName('Version').AsString;
 entry.AppMn:=strAuthor+': '+dsApp.FieldByName('Publisher').AsString;
 if dsApp.FieldByName('Publisher').AsString='' then entry.AppMn:='';
 p:=RegDir+LowerCase(entry.AppName+'-'+entry.srID)+'/';

 InstLst.Add(LowerCase(dsApp.FieldByName('ID').AsString));
 entry.AppDesc:=dsApp.FieldByName('Description').AsString;
 if entry.AppDesc='#' then entry.AppDesc:='No description given';

 if FileExists(p+'icon.png') then
 entry.SetImage(p+'icon.png');

 Application.ProcessMessages;
 end;
 dsApp.Next;
end;
dsApp.Close;

{if (CBox.ItemIndex=0) or (CBox.ItemIndex=10) then
begin
tmp:=TStringList.Create;
xtmp:=TStringList.Create;

j:=0;
for i:=0 to xtmp.Count-1 do begin
try
ReadXMLFile(Doc, xtmp[i]);
xnode:=Doc.FindNode('product');
 SetLength(AList,ListLength+1);
 Inc(ListLength);
 AList[ListLength-1]:=TListEntry.Create(MnFrm);
 AList[ListLength-1].Parent:=SWBox;
 AList[ListLength-1].AppLabel.Caption:=xnode.Attributes.GetNamedItem('desc').NodeValue;
 instLst.Add(LowerCase(xnode.Attributes.GetNamedItem('desc').NodeValue));
 blst.Add(AList[ListLength-1].AppLabel.Caption);
xnode:=Doc.DocumentElement.FindNode('component');
 AList[ListLength-1].Vlabel.Caption:=strVersion+': '+xnode.Attributes.GetNamedItem('version').NodeValue;
IdList.Add(xtmp[i]);
//Unsupported
AList[ListLength-1].MnLabel.Visible:=false;
AList[ListLength-1].DescLabel.Visible:=false;
AList[Listlength-1].id:=IDList.Count-1;
AList[ListLength-1].SetPositions;
Application.ProcessMessages;
except
j:=101;
end;
end;

tmp.free;
xtmp.Free;

end; //End Autopackage  }

n:=ConfigDir;
ini:=TIniFile.Create(n+'config.cnf');

//Search for other applications that are installed on this system...
tmp:=TStringList.Create;
xtmp:=TStringList.Create;

if IsRoot then //Only if user is root
begin
tmp.Assign(FindAllFiles('/usr/share/applications/','*.desktop',true));
xtmp.Assign(FindAllFiles('/usr/local/share/applications/','*.desktop',true));
end else
tmp.Assign(FindAllFiles(GetEnvironmentVariable('HOME')+'/.local/share/applications','*.desktop',false));

for i:=0 to xtmp.Count-1 do tmp.Add(xtmp[i]);

xtmp.Free;

if tp='games' then tp:='game';
if tp='multimedia' then tp:='audiovideo';
for i:=0 to tmp.Count-1 do
       begin
       ProcessDesktopFile(tmp[i],tp);
       end;
       tmp.Free;
ini.Free;

//Check LOKI-success:
if j>100 then
StatusBar1.Panels[0].Text:=strLOKIError;

StatusBar1.Panels[0].Text:=strReady; //Loading list finished!

LeftBar.Enabled:=true;
SwBox.Visible:=true;
if Assigned(gif) then gif.Terminate;
gif := nil;
MBar.Visible:=false;
end;

var fAct: Boolean;
procedure TMnFrm.FormShow(Sender: TObject);
begin
fAct:=true;
end;

procedure TMnFrm.InstAppButtonClick(Sender: TObject);
begin
  Notebook1.ActivePageComponent:=InstalledAppsPage;
  CatButton.Down:=false;
  SettingsButton.Down:=false;
  RepoButton.Down:=false;
  InstAppButton.Down:=true;
end;

procedure TMnFrm.RepoButtonClick(Sender: TObject);
begin
  Notebook1.ActivePageComponent:=RepoPage;
  CatButton.Down:=false;
  SettingsButton.Down:=false;
  RepoButton.Down:=true;
  InstAppButton.Down:=false;
end;

procedure FillImageList(IList: TImageList);
var tm: TPicture;bmp: TBitmap;a: String;
begin
  //Add images to list
  tm:=TPicture.Create;
  a:=GetDataFile('graphics/categories/');

  bmp := TBitmap.Create;
  bmp.width := 24;
  bmp.height := 24;
  bmp.TransparentColor:=clWhite;
  bmp.Transparent:=true;

  with IList do begin
  tm.LoadFromFile(a+'all.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'science.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'office.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'development.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'graphics.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'internet.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'games.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'system.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'multimedia.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  tm.LoadFromFile(a+'other.png');
  bmp.canvas.draw(0,0,tm.Graphic);
  Add(bmp,nil);
  end;
  tm.Free;
  bmp.Free;
end;

procedure TMnFrm.btnInstallClick(Sender: TObject);
var p: TProcess;pkit: TPackageKit;
begin
  if OpenDialog1.Execute then
  if FileExists(OpenDialog1.Filename) then
  begin
  if (LowerCase(ExtractFileExt(OpenDialog1.FileName))='.ipk')
  or (LowerCase(ExtractFileExt(OpenDialog1.FileName))='.zip') then
  begin
  Process1.CommandLine := ExtractFilePath(Application.ExeName)+'listallgo '+OpenDialog1.Filename;
  Process1.Execute;
  MnFrm.Hide;
  while Process1.Running do Application.ProcessMessages;
  MnFrm.Show;
  end else
  begin
  if (LowerCase(ExtractFileExt(OpenDialog1.FileName))='.deb') then
  if DInfo.PackageSystem='DEB' then
  begin
  //Open DEB-File
   p:=TProcess.Create(nil);
   p.Options:=[poWaitOnExit,poNewConsole];
   Application.ProcessMessages;
   p.CommandLine:='xdg-open '+''''+OpenDialog1.FileName+'''';
   p.Execute;
   p.Free;
   exit;
  end else
   if Application.MessageBox(PAnsiChar(StringReplace(StringReplace(strConvertPkg,'%x','DEB',[rfReplaceAll]),'%y','RPM',[rfReplaceAll])),
                              PAnsiChar(strConvertPkgQ),MB_YESNO)=IDYES then
   begin
   with ConvDisp do
   begin
   if not FileExists('/usr/bin/alien') then
    if Application.MessageBox(PChar(strListallerAlien),PChar(strInstPkgQ),MB_YESNO)=IDYES then
    begin
      ShowMessage(strplWait);
      pkit:=TPackageKit.Create;
      if not pkit.InstallPkg('alien') then
      begin
       ShowMessage(StringReplace(strPkgInstFail,'%p','alien',[rfreplaceAll]));
       pkit.Free;
       exit;
       end;
      pkit.Free;
     end else exit;
   Application.ProcessMessages;
   Caption:=StringReplace(strConvTitle,'%p','DEB',[rfReplaceAll]);
   Process1.CommandLine:='alien --to-rpm -v -i --scripts '+''''+OpenDialog1.FileName+'''';
   GetOutPutTimer.Enabled:=true;
   Process1.Execute;
   ShowModal;
   end;
   exit;
   end;
  if (LowerCase(ExtractFileExt(OpenDialog1.FileName))='.rpm') then
  if DInfo.PackageSystem='RPM' then
  begin
   //Open RPM-File
   p:=TProcess.Create(nil);
   p.Options:=[poWaitOnExit,poNewConsole];
   Application.ProcessMessages;
   p.CommandLine:='xdg-open '+''''+OpenDialog1.FileName+'''';
   p.Execute;
   p.Free;
   exit;
  end else
   if Application.MessageBox(PAnsiChar(StringReplace(StringReplace(strConvertPkg,'%x','RPM',[rfReplaceAll]),'%y','DEB',[rfReplaceAll])),
                              PAnsiChar(strConvertPkgQ),MB_YESNO)=IDYES then
   begin
   with ConvDisp do
   begin

   if not FileExists('/usr/bin/alien') then
    if Application.MessageBox(PChar(strListallerAlien),PChar(strInstPkgQ),MB_YESNO)=IDYES then
    begin
      ShowMessage(strplWait);
      pkit:=TPackageKit.Create;
      if not pkit.InstallPkg('alien') then
      begin
       ShowMessage(StringReplace(strPkgInstFail,'%p','alien',[rfreplaceAll]));
       pkit.Free;
       exit;
       end;
      pkit.Free;
     end else exit;

   Application.ProcessMessages;
   Caption:=StringReplace(strConvTitle,'%p','RPM',[rfReplaceAll]);
   Process1.CommandLine:='alien --to-deb -v -i --scripts '+''''+OpenDialog1.FileName+'''';
   GetOutPutTimer.Enabled:=true;
   Process1.Execute;
   ShowModal;
   end;
   exit;
   end;
   
   end;
  end;
end;

procedure TMnFrm.BitBtn1Click(Sender: TObject);
begin
  SCForm.ShowModal;
end;

procedure TMnFrm.BitBtn3Click(Sender: TObject);
begin

end;

procedure TMnFrm.BitBtn4Click(Sender: TObject);
begin

end;

procedure TMnFrm.BitBtn6Click(Sender: TObject);
var p: TProcess;
begin
  p:=TProcess.Create(nil);
  p.Options:=[poUsePipes];
  if DInfo.DBase='KDE' then
  begin
     if FileExists('/usr/bin/kpackagekit') then
      p.CommandLine:='/usr/bin/kpackagekit --settings'
     else
      p.CommandLine:='/usr/bin/gpk-repo';
  end else
  begin
     if FileExists('/usr/bin/gpk-repo') then
      p.CommandLine:='/usr/bin/gpk-repo'
     else
      p.CommandLine:='/usr/bin/kpackagekit';
  end;
  Notebook1.Enabled:=false;
  LeftBar.Enabled:=false;
  MBar.Visible:=true;
  try
   p.Execute;
  except
   ShowMessage(strNoGUIPkgManFound);
   p.Free;
   exit;
  end;

  while p.Running do Application.ProcessMessages;
  p.Free;
  Notebook1.Enabled:=true;
  LeftBar.Enabled:=true;
  MBar.Visible:=false;
end;

procedure TMnFrm.BitBtn2Click(Sender: TObject);
var p: TProcess;
begin
  p:=TProcess.Create(nil);
  p.Options:=[poUsePipes];
  if DInfo.DBase='KDE' then
  begin
   if (DInfo.DName='Ubuntu') then
    if FileExists('/usr/bin/qappinstall') then
     p.CommandLine:='/usr/bin/qappinstall'
    else
     p.CommandLine:='/usr/bin/kpackagekit'
   else
     if FileExists('/usr/bin/kpackagekit') then
      p.CommandLine:='/usr/bin/kpackagekit'
     else
      p.CommandLine:='/usr/bin/gpk-application';
  end else
  begin
    if (DInfo.DName='Ubuntu') then
    if FileExists('/usr/bin/gnome-app-install') then
     p.CommandLine:='/usr/bin/gnome-app-install'
    else
     p.CommandLine:='/usr/bin/gpk-application'
   else
     if FileExists('/usr/bin/gpk-application') then
      p.CommandLine:='/usr/bin/gpk-application'
     else
      p.CommandLine:='/usr/bin/kpackagekit';
  end;
  if not FileExists(p.CommandLine) then
  begin
   ShowMessage(strNoGUIPkgManFound);
   p.Free;
   exit;
  end;
  Notebook1.Enabled:=false;
  LeftBar.Enabled:=false;
  MBar.Visible:=true;
  p.Execute;
  while p.Running do Application.ProcessMessages;
  p.Free;
  Notebook1.Enabled:=true;
  LeftBar.Enabled:=true;
  MBar.Visible:=false;
end;

procedure TMnFrm.btnSettingsClick(Sender: TObject);
var cnf:TIniFile;
begin
  Notebook1.ActivePageComponent:=ConfigPage;
  CatButton.Down:=false;
  SettingsButton.Down:=true;
  RepoButton.Down:=false;
  InstAppButton.Down:=false;
  //Now load the configuration

  cnf:=TIniFile.Create(ConfigDir+'config.cnf');
  EnableProxyCb.Checked:=cnf.ReadBool('Proxy','UseProxy',false);
  Edit1.Text:=cnf.ReadString('Proxy','Server','');
  SpinEdit1.Value:=cnf.ReadInteger('Proxy','Port',0);
  CbShowPkMon.Checked:=cnf.ReadBool('MainConf','ShowPkMon',false);
  cnf.free;
   if Edit1.Text='' then
   begin
   if (mnFrm.DInfo.DBase='GNOME')and(FileExists('/usr/bin/gconftool-2')) then
   begin
    if CmdResult('gconftool-2 -g /system/http_proxy/use_http_proxy')='true' then EnableProxyCb.Checked:=true
    else EnableProxyCb.Checked:=false;
    Edit1.Text:=CmdResult('gconftool-2 -g /system/http_proxy/host');
    SpinEdit1.Value:=StrToInt(CmdResult('gconftool-2 -g /system/http_proxy/port'));
   end;
   end;
end;

procedure TMnFrm.btnCatClick(Sender: TObject);
begin
  Notebook1.ActivePageComponent:=CatalogPage;
  CatButton.Down:=true;
  SettingsButton.Down:=false;
  RepoButton.Down:=false;
  InstAppButton.Down:=false;
end;

procedure TMnFrm.AboutBtnClick(Sender: TObject);
var abbox: TFmAbout;
begin
 abbox:=TFmAbout.Create(self);
 abbox.ShowModal;
 abbox.free;
end;

procedure TMnFrm.CBoxChange(Sender: TObject);
begin
  CBox.Enabled:=false;
  LoadEntries;
  CBox.Enabled:=true;
end;

procedure TMnFrm.AutoDepLdCbChange(Sender: TObject);
var h: String;ini: TIniFile;
begin
  h:=ConfigDir;
  ini:=TIniFile.Create(h+'config.cnf');
  ini.WriteBool('MainConf','AutoDepLoad',(Sender as TCheckBox).Checked);
  ini.Free;
end;

procedure TMnFrm.CbShowPkMonChange(Sender: TObject);
var h: String;ini: TIniFile;
begin
  h:=ConfigDir;
  ini:=TIniFile.Create(h+'config.cnf');
  ini.WriteBool('MainConf','ShowPkMon',(Sender as TCheckBox).Checked);
  ini.Free;
end;

procedure TMnFrm.EnableProxyCbChange(Sender: TObject);
var p: String;cnf: TIniFile;
begin
  if (Sender as TCheckBox).Checked then begin
  Label3.Enabled:=true;
  Edit1.Enabled:=true;
  SpinEdit1.Enabled:=true;
  edtUsername.Enabled:=true;
  edtPasswd.Enabled:=true;
  edtFTPProxy.Enabled:=true;
  spinEdit2.Enabled:=true;
  Label4.Enabled:=true;
  Label5.Enabled:=true;
  end else begin
  Label3.Enabled:=false;
  Edit1.Enabled:=false;
  SpinEdit1.Enabled:=false;
  Label4.Enabled:=false;
  edtUsername.Enabled:=false;
  edtPasswd.Enabled:=false;
  edtFTPProxy.Enabled:=false;
  spinEdit2.Enabled:=false;
  Label5.Enabled:=false;
  end;
  p:=ConfigDir;
  cnf:=TIniFile.Create(p+'config.cnf');
  cnf.WriteBool('Proxy','UseProxy',(Sender as TCheckBox).Checked);
  cnf.Free;
end;

procedure TMnFrm.RmUpdSrcBtnClick(Sender: TObject);
var uconf: TStringList;
begin
if UListBox.ItemIndex>-1 then
begin
 if Application.MessageBox(PChar(strRmSrcQ),PChar(strRmSrcQC),MB_YESNO)=IDYES then
 begin
  uconf:=tStringList.Create;
  uconf.LoadFromFile(RegDir+'updates.list');
  uconf.Delete(UListBox.ItemIndex+1);
  uconf.SaveToFile(RegDir+'updates.list');
  uconf.Free;
  UListBox.Items.Delete(UListBox.ItemIndex);
  ShowMessage(strSourceDeleted);
 end;
end else ShowMessage(strPleaseSelectListItem);
end;

procedure TMnFrm.UListBoxClick(Sender: TObject);
var uconf: TStringList;
    h: String;
begin
 uconf:=TStringList.Create;
 uconf.LoadFromFile(RegDir+'updates.list');
 h:=uconf[UListBox.ItemIndex+1];
 if UListBox.Checked[UListBox.ItemIndex] then
  h[1]:='-' else h[1]:='#';
 uconf[UListBox.ItemIndex+1]:=h;
 uconf.SaveToFile(RegDir+'updates.list');
 uconf.Free;
end;

procedure TMnFrm.UpdCheckBtnClick(Sender: TObject);
begin
if FileExists(ExtractFilePath(Application.ExeName)+'liupdate') then
begin
  Process1.CommandLine:=ExtractFilePath(Application.ExeName)+'liupdate -show';
  Process1.Execute;
end else ShowMessage(strLiUpdateAccessFailed);
end;

procedure TMnFrm.WarnDistCbChange(Sender: TObject);
var h: String;ini: TIniFile;
begin
  h:=ConfigDir;
  ini:=TIniFile.Create(h+'config.cnf');
  ini.WriteBool('MainConf','DistroWarning',(Sender as TCheckBox).Checked);
  ini.Free;
end;

procedure TMnFrm.FilterEdtEnter(Sender: TObject);
begin
  if FilterEdt.Text=strFilter then
   FilterEdt.Text:='';
end;

procedure TMnFrm.FilterEdtExit(Sender: TObject);
begin
  if (StringReplace(FilterEdt.Text,' ','',[rfReplaceAll])='') then
   FilterEdt.Text:=strFilter;
end;

procedure TMnFrm.FilterEdtKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var i: Integer;
begin
  if Key = VK_RETURN then
  begin
     if ((FilterEdt.Text=' ') or (FilterEdt.Text='*')or (FilterEdt.Text='')) then
     begin
     for i:=0 to AList.Count-1 do
     TListEntry(AList[i]).Visible:=true;
     end else
     begin
     Application.ProcessMessages;
     StatusBar1.Panels[0].Text:=strFiltering;
     for i:=0 to AList.Count-1 do
     begin
      TListEntry(AList[i]).Visible:=true;
       Application.ProcessMessages;
        if ((pos(LowerCase(FilterEdt.Text),LowerCase(TListEntry(AList[i]).AppName))<=0)
        or (pos(LowerCase(FilterEdt.Text),LowerCase(TListEntry(AList[i]).AppDesc))<=0))
         and (LowerCase(FilterEdt.Text)<>LowerCase(TListEntry(AList[i]).AppName)) then
         TListEntry(AList[i]).Visible:=false;
         end;
       end;
StatusBar1.Panels[0].Text:=strReady;
end;
end;

procedure TMnFrm.FormActivate(Sender: TObject);
begin
  if fAct then
  begin fAct:=false;LoadEntries;
  end;
end;

procedure TMnFrm.FormCreate(Sender: TObject);
var xFrm: TimdFrm;i: Integer;tmp: TStringList;
begin
if FileExists(paramstr(1)) then
begin
  Process1.Options:=[];
  Process1.CommandLine := ExtractFilePath(Application.ExeName)+'listallgo '+paramstr(1);
  Process1.Execute;
  Application.Terminate;
  exit;
end;

SWBox.DoubleBuffered:=true;
DoubleBuffered:=true;
DInfo:=GetDistro;

 if not DirectoryExists(RegDir) then SysUtils.CreateDir(RegDir);
  
 uID:=-1;

 AList:=TObjectList.Create(true); //Create object-list to store AppInfo-Panels

 if not IsRoot then
 begin
 xFrm:=TimdFrm.Create(nil);

 //Set reg-dir
 RegDir:=SyblToPath('$INST/app-reg/');


 with xFrm do
 begin
  Caption:=strSelMgrMode;
  btnTest.Visible:=false;
  CatButton.Caption:=strSWCatalogue;
  btnInstallAll.Caption:=strDispRootApps;
  btnHome.Caption:=strDispOnlyMyApps;
  Refresh;
  ShowModal;
 end;
xFrm.Free;
end else
RegDir:='/etc/lipa/app-reg/';

if not DirectoryExists(RegDir) then CreateDir(RegDir);

//Load update source settings
  PageControl1.ActivePageIndex:=0;

  tmp:=TStringList.Create;
  if not FileExists(RegDir+'updates.list') then
  begin
   tmp.Add('Listaller UpdateSources-pk0.8');
   tmp.SaveToFile(RegDir+'updates.list');
  end;
  tmp.LoadFromFile(RegDir+'updates.list');
  for i:=1 to tmp.Count-1 do begin
  UListBox.items.Add(copy(tmp[i],pos(' <',tmp[i])+2,length(tmp[i])-pos(' <',tmp[i])-2)+' ('+copy(tmp[i],3,pos(' <',tmp[i])-3)+')');
  UListBox.Checked[UListBox.Items.Count-1]:=tmp[i][1]='-';
  end;

 //Translate
 Caption:=strSoftwareManager;
 CatButton.Caption:=strSWCatalogue;
 Label1.Caption:=strShow;
 Label3.Caption:=strNoAppsFound;
 AboutBtn.Caption:=strAboutListaller;
 BitBtn1.Caption:=strBrowseLiCatalog;
 BitBtn2.Caption:=strOpenDistriCatalog;
 InstAppButton.Caption:=strInstalledApps;
 InstallButton.Caption:=strInstallPkg;
 CatButton.Caption:=strBrowseCatalog;
 RepoButton.Caption:=strRepositories;
 SettingsButton.Caption:=strSettings;
 FilterEdt.Text:=strFilter;
 //Translate config page
 edtUsername.Caption:=strUsername+':';
 edtPasswd.Caption:=strPassword+':';
 EnableProxyCb.Caption:=strEnableProxy;
 GroupBox1.Caption:=strProxySettings;
 AutoDepLdCb.Caption:=strAutoLoadDep;
 CbShowPkMon.Caption:=strShowPkMon;
 //Translate repo page(s)
 UpdRepoSheet.Caption:=strUpdSources;
 RmUpdSrcBtn.Caption:=strDelSrc;
 UpdCheckBtn.Caption:=strCheckForUpd;
 UsILabel.Caption:=strListofSrc;
 BitBtn6.Caption:=strChangePkgManSettings;

with CBox do
begin
 Items[0]:=strAll;
 Items[1]:=strEducation;
 Items[2]:=strOffice;
 Items[3]:=strDevelopment;
 Items[4]:=strGraphic;
 Items[5]:=strNetwork;
 Items[6]:=strGames;
 Items[7]:=strSystem;
 Items[8]:=strMultimedia;
 Items[9]:=strAddidional;
 Items[10]:=strOther;
end;
 Image1.Picture.LoadFromFile(GetDataFile('graphics/header.png'));
 Application.ShowMainForm:=true;
 instLst:=TStringList.Create;
 blst:=TStringList.Create; //Create Blacklist

 //Create uninstall panel
Application.CreateForm(TRMForm, RMForm);

{//Option check
if (Application.HasOption('u','uninstall'))and(IsRoot) then
begin
 if paramstr(2)[1]='/' then ProcessDesktopFile(paramstr(2),'all')
 else IdList.Add(paramstr(2));

 uId:=0;
 RMForm.ShowModal;
 Application.Terminate;
 halt(0);
end;     }

InstAppButton.Down:=true;

writeLn('Opening database...');
dsApp:= TSQLite3Dataset.Create(nil);
with dsApp do
 begin
   FileName:=RegDir+'applications.db';
   TableName:='AppInfo';
   if not FileExists(FileName) then
   begin
   with FieldDefs do
     begin
       Clear;
       Add('Name',ftString,0,true);
       Add('ID',ftString,0,true);
       Add('Type',ftString,0,true);
       Add('Description',ftString,0,False);
       Add('Version',ftFloat,0,true);
       Add('Publisher',ftString,0,False);
       Add('Icon',ftString,0,False);
       Add('Profile',ftString,0,False);
       Add('AGroup',ftString,0,true);
       Add('InstallDate',ftDateTime,0,False);
       Add('Dependencies',ftMemo,0,False);
     end;
   CreateTable;
 end;
end;
dsApp.Active:=true;
Notebook1.ActivePageComponent:=InstalledAppsPage;
 WriteLn('GUI loaded.');
end;

procedure TMnFrm.FormDestroy(Sender: TObject);
var i: Integer;
procedure WriteConfig;
 var p: String;cnf: TIniFile;
begin
  p:=ConfigDir;
  cnf:=TIniFile.Create(p+'config.cnf');
  cnf.WriteString('Proxy','hServer',Edit1.Text);
  cnf.WriteInteger('Proxy','hPort',SpinEdit1.Value);
  //
  cnf.WriteString('Proxy','Username',edtUsername.Caption);
  cnf.WriteString('Proxy','Password',edtPasswd.Caption);

  cnf.WriteString('Proxy','fServer',edtFTPProxy.Caption);
  cnf.WriteInteger('Proxy','fPort',SpinEdit2.Value);
  cnf.Free;
end;
begin
  //Write configuration which was not applied yet
  WriteConfig();
  if Assigned(blst) then blst.Free;       //Free blacklist
  if Assigned(InstLst) then InstLst.Free; //Free list of installed apps
  if Assigned(AList) then AList.Free;     //Free AppPanel store
  if Assigned(dsApp) then                 //Free databse connection
  begin
 { dsApp.ApplyUpdates;
  dsApp.Close; }
  writeLn('Database connection closed.');
  dsApp.Free;
  end;
end;

initialization
  {$I manager.lrs}

end.
