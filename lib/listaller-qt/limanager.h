/*
    libinstaller-qt - Qt4 wrapper for libListaller
    Copyright (C) 2010 Matthias Klumpp

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef LIAPPMANAGER_H
#define LIAPPMANAGER_H

#include<QtGui>
#include"li-types.h"

namespace Listaller {
  
struct AppData
{
  QString name;
  QString pkName;
  TPkgType PkType;
  QString shortDesc;
  QString version;
  QString author;
  QString iconName;
  QString profile;
  QString uId;
  AppCategory Category;
  double installDate;
  QString dependencies;
};

class LiAppManager : public QObject
{
  Q_OBJECT
  
public:
    LiAppManager();
    ~LiAppManager();
    
    bool loadApps();
    
    void setSuMode(bool b);
    
signals:
    void newApp(AppData app);
    
private:
    void* mgr;
};

};

#endif // LIMANAGER_H