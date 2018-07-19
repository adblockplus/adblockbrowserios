#!/bin/sh

#
# REQUIRES!!! https://stedolan.github.io/jq/
# Build process is expected to run "brew install jq" or similar
#

THIS_FOLDER=$(dirname $0)
pushd $THIS_FOLDER > /dev/null
cd $1 # location of kitt-core root relative to this script
ROOT_FOLDER=$PWD
popd > /dev/null

# params expected relative paths
PACKAGE_JSON=$ROOT_FOLDER/$2
CI_BUILD_NUMBER=$3
INFO_PLIST=$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH

echo "Patch $PACKAGE_JSON -> $INFO_PLIST"

PLISTBUDDY=/usr/libexec/PlistBuddy
JSON_READER="/usr/local/bin/jq -r"

VERSION=`$JSON_READER .version $PACKAGE_JSON`
echo "Will replace CFBundleShortVersionString with $VERSION"
$PLISTBUDDY -c "Set :CFBundleShortVersionString $VERSION" $INFO_PLIST

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "CI not present, taking CFBundleVersion from User-Defined setting"
else
  echo "CI present, will replace CFBundleVersion with $CI_BUILD_NUMBER"
  $PLISTBUDDY -c "Set :CFBundleVersion $CI_BUILD_NUMBER" $INFO_PLIST
fi
