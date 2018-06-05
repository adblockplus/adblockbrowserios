#!/bin/sh

DOWNLOAD_FOLDER=$1

CORE_SUBFOLDER=core
mkdir $CORE_SUBFOLDER

for LOCFOLDER in $DOWNLOAD_FOLDER/*; do
  if [ -d "$LOCFOLDER" ]; then
    pushd $LOCFOLDER > /dev/null
    LOC_CODE=${PWD##*/}
    echo $LOC_CODE
    popd > /dev/null
    CORE_LOC=$CORE_SUBFOLDER/$LOC_CODE.lproj
    mkdir $CORE_LOC
    cp $LOCFOLDER/Core.strings $CORE_LOC/Localizable.strings
    cp $LOCFOLDER/UI.xliff ./$LOC_CODE.xliff
  fi
done
