#!/bin/bash

#Looking for pasdoc
PDP=$(which pasdoc)
if ([ -e $PDP ]&&[ "$PDP" != '' ]); then
mkdir -p ../docs/html
cd ../docs/html/
pasdoc --write-uses-list --staronly --format html \
../../src/listallgo.lpr ../../src/lipa.lpr ../../src/listallmgr.lpr ../../src/liupdate.lpr \
../../src/libuild.lpr ../../src/unibuild.pas ../../src/litray.lpr \
../../licreator/licreator.lpr ../../licreator/editor.pas \
../../licreator/prjwizard.pas ../../src/igobase.pas ../../src/distri.pas ../../src/dgunit.pas \
../../src/litranslator.pas ../../lib/ipkinstall.pas ../../lib/limanageapp.pas \
../../src/ipkbuild.pas ../../src/ipkdef.pas ../../synapse/httpsend.pas \
../../synapse/ftpsend.pas ../../synapse/blcksock.pas ../../src/manager.pas \
../../src/pkgconvertdisp.pas ../../src/mnupdate.pas ../../src/licommon.pas ../../src/lentries.pas \
../../bindings/packagekit.pas ../../bindings/appman.pas ../../src/litypes.pas ../../src/libasic.pas \
../../bindings/installer.pas ../../src/RegExpr.pas ../../src/swcatalog.pas ../../src/xtypefm.pas \
../../src/trstrings.pas ../../src/uninstall.pas ../../src/updexec.pas ../../src/xtypefm.pas \
../../src/linotify.pas ../../licreator/editor.pas ../../licreator/prjwizard.pas \
../../opbitmap/gifanimator.pas ../../opbitmap/opbitmapformats.pas \
../../abbrevia/abunzper.pas ../../abbrevia/abarctyp.pas ../../lib/mtprocs.pas \
../../abbrevia/abzipper.pas ../../lib/libinstaller.lpr ../../lib/lidbusproc.pas \
../../src/aboutbox.pas ../../bindings/polkit.pas ../../bindings/pkdesktop.pas \
../../bindings/gext.pas ../../helper/listallerd.lpr ../../helper/djobs.pas
else
  echo " PasDoc was not found. Please PasDoc."
  exit 8
fi
