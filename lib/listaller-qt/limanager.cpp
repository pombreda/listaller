/*
    libinstaller-qt - Qt4 wrapper for libListaller
    Copyright (C) 2010 Matthias Klumpp

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "limanager.h"

#include <QtCore>
#include <Listaller>

using namespace Listaller;

#ifndef _LIMSGREDIRECT
#define _LIMSGREDIRECT

namespace Listaller {
class LiMsgRedirect : public QObject
{
  Q_OBJECT
  
public:
  void sendStatusMessage(QString s){ emit(statusMessage(s)); }
  void sendNewApp(LiAppInfo *ai){
    Listaller::Application app;
    app.author = ai->Author;
    app.name = ai->Name;
    app.pkName = ai->PkName;
    app.shortDesc = ai->ShortDesc;
    app.version = ai->Version;
    app.installDate = ai->InstallDate;
    app.iconName = ai->IconName;
    emit(newApp(app));  
  }
  
signals:
  void statusMessage(QString s);
  void newApp(Application app);
  
};
};
#endif // _LIMSGREDIRECT

/* Listaller Callbacks */
void manager_status_change_cb(LiStatusChange change, LiStatusData data, LiMsgRedirect *rd)
{
  rd->sendStatusMessage(QString(data.msg));
}

void manager_new_app_cb(char *name,LiAppInfo *obj,LiMsgRedirect *rd)
{
  rd->sendNewApp(obj);
}

LiRqResult manager_usr_request_cb(LiRqType mtype,char *msg,LiMsgRedirect *rd)
{
  //Say yes to everything, until we have a nice request handler
  return rqsYes;
}

/* AppManager Class */
AppManager::AppManager()
{
  mgr = li_mgr_new();
  
  msgRedir = new LiMsgRedirect();
  connect(msgRedir, SIGNAL(statusMessage(QString)), this, SLOT(emitStatusMessage(QString)));
  connect(msgRedir, SIGNAL(newApp(Application)), this, SLOT(emitNewApp(Application)));
  
  //Catch status messages
  li_mgr_register_status_call(&mgr, StatusChangeEvent(manager_status_change_cb), msgRedir);
  //Catch new apps
  li_mgr_register_app_call(&mgr, NewAppEvent(manager_new_app_cb), msgRedir);
  
  li_mgr_register_request_call(&mgr, UserRequestCall(manager_usr_request_cb), msgRedir);
  
  setSuMode(false);
}

AppManager::~AppManager()
{  
  li_mgr_free(&mgr);
  delete msgRedir;
}

bool AppManager::rescanApps()
{
  return li_mgr_load_apps(&mgr);
}

void AppManager::setSuMode(bool b)
{
  li_mgr_set_sumode(&mgr, b);
}

bool AppManager::suMode() const
{
  return li_mgr_sumode(&mgr);
}

bool AppManager::uninstallApp(Application app)
{
  struct local {
     static char *qStringToChar(QString s)
     {
       return (char*) qPrintable(s);
     }
  };
  
  LiAppInfo ai;
  ai.UId = local::qStringToChar(app.uId);
  ai.Author = local::qStringToChar(app.author);
  ai.Dependencies = local::qStringToChar(app.dependencies);
  ai.Name = local::qStringToChar(app.name);
  //ai.PkType = local::qStringToChar(app.pkType);
  ai.Profile = local::qStringToChar(app.profile);
  //TODO: Convert every part of Application to AppInfo

  li_mgr_remove_app(&mgr, ai);
}
