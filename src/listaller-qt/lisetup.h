/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*-
 *
 * listaller-qt - Qt4 wrapper for Listaller
 * Copyright (C) 2010-2011 Matthias Klumpp <matthias@nlinux.org>
 *
 * Licensed under the GNU Lesser General Public License Version 3+
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef LISETUP_H
#define LISETUP_H

#include<QtCore>
#include"litypes.h"

namespace Listaller {

  class Setup : public QObject
  {
    Q_OBJECT

  public:
      Setup (QString pkgFileName);
      ~Setup ();

      bool initialize ();

      void setSuMode (bool b);
      bool suMode () const;

      QString descriptionAsString () const;

      void setTestmode (bool b);
      bool testmode () const;

      bool runInstallation ();

  private:
      ListallerSettings *conf;
      ListallerSetup *setup;
      ListallerIPKControl *ipkmeta;
  };

};

#endif // LISETUP_H
