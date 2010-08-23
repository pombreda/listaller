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

#include "lisetup.h"

#include<QtCore>
#include<listaller.h>

using namespace Listaller;

LiSetup::LiSetup()
{
  setup = li_setup_new();
}

LiSetup::~LiSetup()
{
  li_setup_free(setup);
}

void LiSetup::initialize(QString pkgName)
{
  li_setup_init(setup, (char*) qPrintable(pkgName));
}

void LiSetup::setSuMode(bool b)
{
  li_setup_set_sumode(setup, b);
}

QString LiSetup::getDisallows() const
{
  return li_setup_get_disallows(setup);
}

QString LiSetup::getSupportedDistributions() const
{
  return li_setup_get_supported_distributions(setup);
}

QString LiSetup::appName() const
{
  return li_setup_get_appname(setup);
}

QString LiSetup::appVersion() const
{
  return li_setup_get_appversion(setup);
}

QString LiSetup::description() const
{
  //return li_setup_get_long_description(setup);
  return "FIXME: Implement this!";
}

void LiSetup::setTestmode(bool b)
{
  li_set_testmode(b);
}
