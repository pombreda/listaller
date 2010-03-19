#!/bin/bash
# Clean up all files which were used during the compile process or which are just backup files

for arg; do
  case $arg in
    ALL=*) ALL=${arg#ALL=};;
  esac;
done

rm -rf *.o
rm -rf *.ppu

rm -rf *.pas~
rm -rf *.sh~
rm -rf *.bak

rm -rf *.compiled
rm -rf *.lrt
rm -rf *.lrs
if [ "$ALL" == "1" ]; then
 rm -f Makefile
fi

rm -rf *~
rm -rf "../build"

rm -f ./libinstaller.so
rm -f ./libinstaller.so.0.4
rm -f ./libappmanager.so

#Clean liCreator directory
cd ../licreator
rm -rf *.o
rm -rf *.ppu

rm -rf *.pas~
rm -rf *.sh~
rm -rf *.bak
rm -rf *.lrs

rm -rf *.compiled

rm -rf *~

cd ..

#Clean root dir
if [ "$ALL" == "1" ]; then
 rm -f Makefile
fi

rm -rf *~
rm -rf *.bak

#Clean libs directory
cd ./lib
rm -rf *.o
rm -rf *.ppu

rm -rf *.pas~
rm -rf *.sh~
rm -rf *.bak

rm -rf *.compiled
rm -rf *.lrs

rm -rf *~

cd ..

#Clean helper daemon directory
cd ./helper
rm -rf *.o
rm -rf *.ppu

rm -rf *.pas~
rm -rf *.sh~
rm -rf *.bak

rm -rf *.compiled
rm -rf *.lrs

rm -rf *~

cd ../src

echo "Source code directories cleaned up."
