#!/bin/sh

# XCode building sandbox PATH is very different from the system default PATH
# namely it does not contain /usr/local/bin as location of node (npm)
PATH=/usr/local/bin:$PATH

CORE_ROOT_RELATIVE=$1 # location of kitt-core root relative to this script
RUN_ENV=$2 # 'fromci' or 'xcode'
HAS_CI=$3 # unset or the specific CI env var saying "it's running in CI"

# 'fromci' is run before xcodebuild and does everything: npm install and build JS API
# 'xcode' is run as build step and depends on whether is being run from CI or not
# - from CI (HAS_CI is set) - does nothing because all was done in 'fromci'
# - from desktop (HAS_CI is undef) - just builds JS API to speed up.

CORE_ROOT=$(dirname $0)/$CORE_ROOT_RELATIVE
pushd $CORE_ROOT

case $RUN_ENV in
  fromci)
    echo "Installing npm in $CORE_ROOT"
    npm install
    DO_BUILD=1
  ;;
  xcode)
    if [ -z "$HAS_CI" ]; then
      DO_BUILD=1
    fi
  ;;
esac

if [ -z "$DO_BUILD" ]; then
 echo "XCode step in CI, skipping JS API build"
 exit 0
fi

if [ ! -d "node_modules/" ]; then
  echo "'node_modules' directory not found. You must run 'npm install' in the adblockbrowserios-core root directory before running this script again."
  exit 1
fi

# Build js API

tsc="node_modules/.bin/tsc"
rollup="node_modules/.bin/rollup"
jslint="node_modules/.bin/jshint"
uglifyjs="node_modules/.bin/uglifyjs"
src="src/JavaScriptBridge/TypeScriptInterface"
ts="build-jsapi/ts"
js="build-jsapi/js"
bundles="build-jsapi/bundles"

if [ ! "$HAS_CI" ] && [ "$(echo "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')" = "debug" ]
then
  debug=1
fi

mkdir -p "$ts"

# Check for source changes
if [ $debug ] && diff -q -r "$src" "$ts"
then
  printf "\e[0;32mNothing to be done\e[0m\n"
else
  # Remove old sources
  rm -r "$ts"

  printf "\e[0;32mExecuting TypeScript\e[0m\n"
  $tsc -p src/JavaScriptBridge/TypeScriptInterface || exit -1

  for wrapper in src/JavaScriptBridge/Wrappers/*
  do
    entry="${wrapper##*wrapper_}"
    bundle="$bundles/bundle_$entry"

    printf "Bundling \e[0;32m${entry}\e[0m\n"
    $rollup -c rollup.config.js -i "$js/main_$entry" -o "$bundle" --no-strict  || exit -1

    wrapperContent=`cat "$wrapper"`
    output="build-jsapi/api_$entry"
    echo "${wrapperContent%%__BROWSERIFIED_API__*}" > "$output"
    cat "$bundle" >> "$output"
    echo "${wrapperContent##*__BROWSERIFIED_API__}" >> "$output"

    printf "Linting \e[0;32m${entry}\e[0m\n"
    $jslint "$output" || exit -1

    if [ ! $debug ]
    then
      printf "Uglifying \e[0;32m${entry}\e[0m\n"
      $uglifyjs -q 1 "$output" > "${output}.out" || exit -1
      mv "${output}.out" "$output" || exit -1
    fi
  done

  [ $debug ] && cp -r "$src" "$ts"

  printf "\e[0;32mBundling is complete\e[0m\n"
fi

popd
