{ trstrings.pas
  Copyright (C) Listaller Project 2008-2009

  trstrings.pas is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  trstrings.pas is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.}
//** This unit contains the default strings for translation
unit trstrings;

{$mode objfpc}{$H+}

interface

resourcestring
rsBrokenDepsFixQ = 'You have missing dependencies. Should they be fixed now?';
rsCannotResolv = 'Cannot resolve dependencies';
rsCheckAppDepsQ = 'Do you want to check the applications''s dependencies?';
rsCheckRootAppsQ = 'Do you want to check global-installed applications too?';
rsCommands = 'Commands:';
rsCouldntFindUpdater = 'Couldn''t find updater applications!';
rsInternalError = 'An internal error occured';
rsLipaInfo2 = 'Resolve Listaller path variable';
rsLipaInfo3 = 'Installs an IPK package';
rsListallerMgrNotFound = 'Couldn''t find Listaller Manager!';
rsLiUpdaterNotFound = 'Unable to find liUpdater!';
rsOptions = 'Options:';
rsLipaInfo4 = 'Runs installation in testmode';
rsLipaInfo5 = 'Print all available log messages';
rsLipaInfo6 = 'Check if all installed applications have proper dependencies';
rsCMDInfoPkgBuild = 'Package build commands:';
rsLiBuildInfoA = 'Build ipk-package';
rsLiBuildInfoB = 'Create/Update update-repository';
rsLiBuildInfoC = 'Create DEB and RPM file from IPS';
rsDone = 'Done.';
rsDoYouAcceptLicenseCMD = 'Do you accept this license? (y/n):';
rsEnterNumber = 'You have to enter a number!';
rsInstAborted='Installation aborted.';
rsAppNInstall='The application %a was not installed.';
rsLipaAutoFixQ = 'Should lipa fix these problems automatically? [y/n]?';
rsLipaInfo1 = 'Listaller command-line tool to handle ipk-packages';
rsModeNumber = 'Mode number:';
rsN = 'n';
rsNo = 'no';
rsOkay = 'Okay';
rsPreparingInstall = 'Preparing installation (please wait)';
rsRootPassAdvancedPriv = 'Enter your password to run the application with '
  +'advanced privileges.';
rsRootPassQAppEveryone = 'Enter your password to install the application for '
  +'everyone.';
rsSelectListNumber = 'Please select a number shown in the list!';
rsSelectIModeA = 'Select the installation mode of this application:';
rsShowDetailedInfoCMD = 'Do you want to see detailed information [y/n]?';
rsViewLogQ = 'Do you want to view the logfile?';
rsWasInstalled='The application %a was installed successfully!';
rsInstallNow='Install now';
rsRunParam='Please run "listallgo" with path to install-package as first parameter!';
rsWelcome='Welcome!';
rsnToStart='Press "Next" to start the installation!';
rsProgDesc='Program description:';
rsLicense='Software license';
rspleaseRead='Please read the following information carefully:';
rsRunning='Running installation...';
rsplWait='Please wait.';
rsComplete='Installation completed!';
rsInstFailed='Installation failed.';
rsPrFinish='Press "Finish" to close.';
rsFinish='Finish';
rsAbort='Abort';
rsBack='Back';
rsNext='Next';
rsDispLog='Display installation log';
rsIagree='I agree with the above terms and conditions';
rsInagree='I don''t agree';
rsLDnSupported='Your Linux distribution is not supported by Listaller yet!';
rsnSupported='This package does not support your Linux distribution.';
rsDepNotFound='Found no package with the necessary library "%l" for your distribution.';
rsInClose='The installer will close now';
rsCnOverwrite='Unable to overwrite the file %f.';
rsNotifyDevs='Please notify the developers on http://launchpad.net/listaller';
rsExtractError='Error while extracting files!';
rsPkgDM='The IPK package could be damaged or you haven''t enough rights to acces required files/folders.';
rsAbLoad='Loading aborted.';
rsAlreadyInst='This application is already installed';
rsInstallAgain='Do you want to install it again?';
rsWelcomeTo='Welcome to the installation of %a';
rsInstOf='Installation of %a';
rsTestmode='Testmode';
rsTestFinished='Test of the application finished.';
rspkgInval='The package was invalid!';
rsCouldntSolve='Dependencies couldn''t be solved!';
rsViewLog='Please view the logfile at %p';
rsPKGError='Installation package is corrupt';
rsAppClose='The application will close now ';
rsStep1='Phase 1/4: Resolving dependencies...';
rsWDLdep='This application wants to download & install a dependency from %l';
rswAllow='Do you want confirm this action?';
rsLiCloseANI='Listaller will close now. The package couldn''t be installed.';
rsStep2='Phase 2/4: Installing files...';
rsStep3='Phase 3/4: Chmod new files...';
rsStep4='Phase 4/4: Registering application...';
rsAddUpdSrc='The installation tries to add the following update source: ';
rsQAddUpdSrc='Should this source be added to the update sources list?';
rsFinished='Finished';
rsinstAnyway='Do you want to install it anyway? (This could raise problems)';
rsInvarchitecture='The application which this package contains was not built for the current system architecture.';
rsWillDLFiles='(This program will download the needed files from the internet)';
rsInvalidDVersion='Package was not build for your Linux distribution release.';
rsFTPfailed='Problem while downloading the packages. Maybe the login on the FTP-Server failed.';
rsSuccess='Success!';
rsMain='Main';
rsDetails='Details';
rsInstallation='Installation';
rsNoLDSources='There are no sources available for your Linux distribution'#10'Try to install common packages?';
rsUseCompPQ='Use compatible packages?';
rsNoComp='No compatible packages found!';
rsActionNotPossiblePkg='The selected action is not possible with this package.'#10'Please contact the package maintainer to get more information.';
rsIDInvalid='This package has no valid ID'#10'The installer will close.';
rsReInstall='Re-install';
rsPkgDownload='The following packages will be downloaded:';
rsGetDependencyFrom='Get dependency from';
rsPlWait2='Please wait...';
rsDepDLProblem='Problem while downloading the dep-file.';
rsHashError='Hash doesn''t match!'#10'The package may be modified after creation.'#10'Please obtain a new copy';
rsInstallationMode='Installation mode:';
rsIModeInstruction='Select which parts of the application should be installed.';
rsMode='Mode';
rsCleanUp='Cleaning up...';
rsInstPerformError='Error while performing installation:';
rsYesNo1='Yes/No?:';
rsInstallLiBuild='You have to install the liBuild package before you can build packages!';
rsFileNotExists='The file "%f" does not exists!';

rsWantToDoQ='What do you want to do?';
rsPackageKitWarning='Your PackageKit version is %cp. Listaller needs PackageKit %np or higher to work correctly.'#10'Please update PackageKit!';
rsSpkWarning='Make sure that you have got this package from a save source and a serious publisher!';
rsInstallEveryone='Install application for everyone';
rsTestApp='Test application';
rsInstallHome='Install into my Home directory';
rsSelInstMode='Select installation mode';

rsSoftwareManager='Software Manager';
rsUpdSources='Update sources';
rsClose='Close';
rsDelSrc='Delete source';
rsListofSrc='The following update sources are installed:';
rsUninstall='Uninstall';
rsSWCatalogue='Browse catalogue';
rsShow='Show:';
rsAll='All';
rsEducation='Education';
rsOffice='Office';
rsDevelopment='Development';
rsGraphic='Graphic';
rsNetwork='Network';
rsGames='Games';
rsSystem='System';
rsMultimedia='Multimedia';
rsAddidional='Utilities';
rsOther='Other';
rsVersion='Version';
rsAuthor='Autor';
rsUsername='Username';
rsPassword='Password';
rsProxySettings='Proxy-Settings';
rsEnableProxy='Enable Proxy-Server';
rsLOKIError='Can''t load LOKI-Setup information.';
rsCannotLoadIcon='Unable to load the icon of %a. Please notify the developers of Listaller or this application!';
rsAutoLoadDep='Load dependencies from included webserver-urls automatically';
rsReady='Ready.';
rsConvertPkg='You want to install an %x-Package, but your Linux-distribution''s package system is %y.'#10'This package can be converted using "alien", but this will take some time and eventually the application won''t work'#10'Do you want to convert the package now?';
rsConvertPkgQ='Convert package?';
rsConvTitle='Converting %p package...';
rsFiltering='Filtering...';
rsFilter='Filter...';
rsLoading='Loading...';
rsInstalledApps='Installed applications';
rsInstallPkg='Install package';
rsBrowseCatalog='Browse catalog';
rsRepositories='Repositories';
rsSettings='Settings';
rsNoGUIPkgManFound='Could not find usable GUI package manager.'#10'Please install a PackageKit-GUI!';
rsUseLaunchpadForBugs='Please use https://bugs.launchpad.net/listaller for bug reports.';
rsDispRootApps='Display system applications';
rsDispOnlyMyApps='Display my applications';
rsSelMgrMode='Select software-manager mode:';
rsListallerAlien='Listaller uses "alien" to convert foreign packages, but the tool is not installed'#10'Do you want to install "alien" now to continue?';
rsInstPkgQ='Install package?';
rsPkgInstFail='Package %p could not be installed.';
rsShowPkMon='Start PackageKit monitor before running transactions';
rsAboutListaller='About Listaller';
rsBrowseLiCatalog='Browse Listaller''s software catalog';
rsOpenDirsiCatalog='Open your distribution''s package catalog';
rsAbout='About';
rsAuthors='Authors';
rsRmSrcQ='Are you really sure that you want to delete this source?';
rsRmSrcQC='Delete source?';
rsPkitProbPkMon='Problem while connecting PackageKit. Run "pkmon" to get further information.';
rsNoAppsFound='No applications found!';
rsSourceDeleted='Source was removed.';
rsPleaseSelectListItem='Please select an item from the list!';
rsLiUpdateAccessFailed='Cannot access the liUpdate tool. Maybe it is not installed?';
rsChangePkgManSettings='Change package manager settings';
//Catalogue
rsCategory='Category:';
rsWInstallDl='Select software you want to download and to install:';
rsNoInfo='No information available!';
rsDLSetUp='Downloading setup package...';
rsErrContactMan='Cannot download this package. Please contact the catalogue managers on %h';
rsInstalling='Running application installation...';
rsDownloadCTbase='Downloading catalogue base information...';
rsOpenPage='Loading catalogue page...';
rsctDLAbort='Do you really want to abort this download?';
//Uninstall
rsRealUninstQ='Do you really want to uninstall %a?';
rsUnistSuccess='Application uninstalled successfully!';
rsRMerror='Error while uninstalling!';
rsCannotHandleRM='This application is not a MoJo-Installation and no other package-type Listaller can handle.'#10'You have to remove it manually.';
rsRMUnsdDeps='Uninstalling unused deps...';
rsUninstalling='Uninstalling...';
rsRMPkg='Do you really want to remove "%p", containing %a?'#10'The following package(s) will be removed also: %pl'#10'If you aren''t sure that you won''t need those packages, press "No"!';
rsRmPkgQ='Really remove?';
rsWaiting='Waiting...';
rsRMAppC='Uninstalling %a';
rsLinDesk='Running under %de.';

rsNoUpdates='There are no updates available!';
rsLogUpdInfo='Update info:';
rsFilesChanged='%f files will be changed.';
rsUpdTo='The application will be updated to version %v';
rsCheckForUpd='Check for updates';
rsInstUpd='Install updates';
rsShowUpdater='Show';
rsQuitUpdater='Quit';
rsUpdInstalling='Applying updates...';
rsUpdConfError='Error while unpacking and configuring files.';
rsQuestion = 'Question:';
rsYes = 'yes';
rsY = 'y';
rsResolvingDep = 'Resolving dependencies...';
implementation
end.

