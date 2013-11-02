#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PROJECT="gmock"
SOURCE_DIR="$PROJECT"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            pushd msvc/2010
            load_vsvars
            build_sln "$PROJECT.sln" "Debug|Win32"
            build_sln "$PROJECT.sln" "Release|Win32"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            cp Release/*\.lib $stage/lib/release/
            cp Debug/*\.lib $stage/lib/debug/

            # copy headers
            mkdir -p "$stage/include/$PROJECT"
            mkdir -p "$stage/include/gtest"
            popd
            cp -rv include "$stage/"
            cp -rv gtest/include "$stage/"

        ;;

        "darwin")
            # TODO: fix the mac build
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" ./configure --prefix="$stage"
            make
            make install
            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi
            
            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;

        "linux")
            
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" CFLAGS="-m32 -O2" CXXFLAGS="-m32" ./configure --prefix="$stage" --libdir="$stage/lib/release"
            make
            make install
            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi
            
            make distclean
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" CFLAGS="-m32 -O0 -g" CXXFLAGS="-m32" ./configure --prefix="$stage" --libdir="$stage/lib/debug"
            make
            make install
            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi
            
        ;;
    esac

	# copy license info
    mkdir -p "$stage/LICENSES"
    cp COPYING  "$stage/LICENSES/$PROJECT.txt"
popd

pass

