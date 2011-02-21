#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PROJECT="gmock"
VERSION="1.5.0"
SOURCE_DIR="$PROJECT-$VERSION"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            pushd msvc
            load_vsvars
            build_sln "$PROJECT.sln" "Debug|Win32"
            build_sln "$PROJECT.sln" "Release|Win32"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            cp Release/*\.lib $stage/lib/release/
            cp Debug/*\.lib $stage/lib/release/

            # copy headers
            mkdir -p "$stage/include/$PROJECT"
            popd
            cp -rv include "$stage/"

        ;;
        "darwin")
            # TODO: fix the mac build
            ./configure --prefix="$stage"
            make
            make install
        ;;
        "linux")
            # TODO: fix the linux build
            CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage"
            make
            make install
        ;;
    esac

	# copy license info
    mkdir -p "$stage/LICENSES"
    cp COPYING  "$stage/LICENSES/$PROJECT.txt"
popd

pass

